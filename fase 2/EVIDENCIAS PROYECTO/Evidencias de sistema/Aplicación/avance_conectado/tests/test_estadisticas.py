"""SQL real: autorización, límites locales, deduplicación y cámaras sin PII."""
from uuid import uuid4

import pytest


URL = '/gestion/estadisticas'


@pytest.fixture
def cohorte_estadisticas(db):
    zona = 'Zona analítica ' + uuid4().hex
    casos, hechos, registros, camaras = [], [], [], []

    def caso(fecha, org=1, entorno='prueba', principal=None, cierre=None, punto=True):
        row = db("""INSERT INTO caso(folio,id_usuario_reportante,id_vehiculo,id_organizacion,
            fecha_hecho,zona,descripcion_privada,clave_envio,entorno,id_caso_principal,
            estado,motivo_cierre,cerrado_en,ubicacion)
            VALUES(%s,1,1,%s,%s,%s,'NO EXPONER descripción privada',%s,%s,%s,%s,%s,
            CASE WHEN %s::text IS NULL THEN NULL ELSE CURRENT_TIMESTAMP END,
            CASE WHEN %s THEN ST_SetSRID(ST_Point(-73,-36),4326)::geography ELSE NULL END)
            RETURNING id_caso""", ('ANA-'+uuid4().hex[:20], org, fecha, zona, str(uuid4()),
                entorno, principal, 'cerrado' if cierre else 'reportado', cierre, cierre, punto), filas=True)[0][0]
        casos.append(row)
        return row

    try:
        # En enero Chile es UTC-3: límites inclusivos locales, no UTC.
        caso('2031-01-01T02:59:59Z')
        primero = caso('2031-01-01T03:00:00Z')
        caso('2031-02-01T02:59:59Z', punto=False)
        caso('2031-02-01T03:00:00Z')
        caso('2031-01-15T15:00:00Z', principal=primero)
        caso('2031-01-15T15:00:00Z', cierre='duplicado')
        caso('2031-01-15T15:00:00Z', org=2)
        caso('2031-01-15T15:00:00Z', entorno='operacion')

        for estado in ['validado', 'pendiente', 'descartado']:
            hid = db("""INSERT INTO hecho_territorial(tipo,ocurrido_en,zona,estado,
                validado_por,validado_en,entorno) VALUES('otro','2031-01-10T12:00:00Z',%s,%s,
                2,CURRENT_TIMESTAMP,'prueba') RETURNING id_hecho_territorial""", (zona, estado), filas=True)[0][0]
            hechos.append(hid)
        # Tres registros de fuente aceptados para UN hecho; un cuarto es pendiente.
        for hid, revision in [(hechos[0], 'aceptado')]*3 + [(hechos[1], 'aceptado'), (hechos[2], 'aceptado')]:
            rid = db("""INSERT INTO registro_fuente(id_lote_importacion,id_fuente_datos,
                identificador_origen,id_hecho_territorial,estado_revision,revisado_por,revisado_en,motivo_revision)
                VALUES(1,1,%s,%s,%s,2,CURRENT_TIMESTAMP,'Ensayo ficticio revisado')
                RETURNING id_registro_fuente""", (uuid4().hex, hid, revision), filas=True)[0][0]
            registros.append(rid)
        # Cámara cercana y polígono que NO cubre el reporte: proximidad no es cobertura.
        for org, estado, lon in [(1, 'disponible', -73), (1, 'fuera_servicio', -73), (2, 'disponible', -73)]:
            kid = db("""INSERT INTO camara(id_organizacion,nombre,ubicacion,cobertura,
                estado,referencia_autorizacion,referencia_secreto,entorno)
                VALUES(%s,%s,ST_SetSRID(ST_Point(%s,-36),4326),
                ST_GeomFromText('MULTIPOLYGON(((-70 -30,-70.01 -30,-70.01 -30.01,-70 -30.01,-70 -30)))',4326),
                %s,'Autorización ficticia','NO EXPONER secreto','prueba') RETURNING id_camara""",
                (org, uuid4().hex, lon, estado), filas=True)[0][0]
            camaras.append(kid)
        yield {'zona': zona, 'casos': casos, 'camaras': camaras}
    finally:
        for rid in registros:
            db('DELETE FROM registro_fuente WHERE id_registro_fuente=%s', (rid,))
        for cid in reversed(casos):
            db('DELETE FROM caso WHERE id_caso=%s', (cid,))
        for hid in hechos:
            db('DELETE FROM hecho_territorial WHERE id_hecho_territorial=%s', (hid,))
        for kid in camaras:
            db('DELETE FROM camara WHERE id_camara=%s', (kid,))


def consulta(client, headers, zona, **extra):
    return client.get(URL, headers=headers, params={
        'desde': '2031-01-01', 'hasta': '2031-01-31',
        'zona': zona, 'entorno': 'prueba', 'id_organizacion': 1, **extra})


def test_estadisticas_exige_sesion_y_membresia_incluso_vacio(client, ciudadano, operador_org2, db):
    assert client.get(URL).status_code == 401
    assert client.get(URL, headers=ciudadano['headers'], params={'anio': 2099}).status_code == 403
    assert client.get(URL, headers=operador_org2, params={'id_organizacion': 1, 'anio': 2099}).status_code == 403
    uid = ciudadano['id']
    db("""INSERT INTO usuario_rol(id_usuario,id_rol,asignado_por)
        SELECT %s,id_rol,2 FROM rol WHERE codigo='administrador'""", (uid,))
    try:
        assert client.get(URL, headers=ciudadano['headers']).status_code == 403
    finally:
        db("DELETE FROM usuario_rol WHERE id_usuario=%s AND id_rol IN (SELECT id_rol FROM rol WHERE codigo='administrador')", (uid,))


@pytest.mark.parametrize('cambio', [
    "estado='suspendida'", "inicio=CURRENT_TIMESTAMP+interval '1 day'",
    "estado='finalizada',fin=CURRENT_TIMESTAMP",
])
def test_estadisticas_membresia_no_vigente(client, supervisor_org1, db, cambio):
    anterior = db('SELECT estado,inicio,fin FROM membresia WHERE id_usuario=2 AND id_organizacion=1', filas=True)[0]
    try:
        db('UPDATE membresia SET '+cambio+' WHERE id_usuario=2 AND id_organizacion=1')
        assert client.get(URL, headers=supervisor_org1).status_code == 403
    finally:
        db('UPDATE membresia SET estado=%s,inicio=%s,fin=%s WHERE id_usuario=2 AND id_organizacion=1', anterior)


@pytest.mark.parametrize('params', [
    {'desde': '2031-01-01'}, {'hasta': '2031-01-31'},
    {'desde': '2031-02-01', 'hasta': '2031-01-01'},
    {'desde': '2030-01-01', 'hasta': '2031-01-02'},
    {'anio': 1899}, {'anio': 2101}, {'radio_m': 49}, {'radio_m': 2001},
    {'desde': '2031-02-29', 'hasta': '2031-03-01'}, {'zona': '   '},
])
def test_estadisticas_filtros_invalidos(client, supervisor_org1, params):
    assert client.get(URL, headers=supervisor_org1, params=params).status_code == 422


def test_estadisticas_vacio_completo_sin_tasas_inventadas(client, supervisor_org1):
    r = client.get(URL, headers=supervisor_org1, params={'anio': 2032, 'zona': uuid4().hex})
    assert r.status_code == 200, r.text
    d = r.json()
    assert d['internos']['total'] == d['territorial']['total'] == 0
    assert d['internos']['recuperacion']['porcentaje_cohorte'] is None
    assert d['internos']['recuperacion']['denominador'] == 0
    assert len(d['internos']['mensual']) == 12
    assert len(d['internos']['diaria']) == 366
    assert len(d['territorial']['horas']) == 24
    assert len(d['internos']['dias_semana']) == 7
    assert not any(x['total'] for x in d['internos']['diaria'])
    assert d['filtros']['entorno'] == 'operacion'
    assert d['camaras']['zonas'] == []


def test_estadisticas_fechas_locales_duplicados_y_fuentes_separadas(client, supervisor_org1, cohorte_estadisticas):
    f = cohorte_estadisticas
    r = consulta(client, supervisor_org1, f['zona'].upper().replace('Í', 'I'))
    assert r.status_code == 200, r.text
    d = r.json()
    i, h = d['internos'], d['territorial']
    assert i['total'] == 2 and i['reportes_total'] == 4 and i['duplicados_excluidos'] == 2
    assert i['recuperacion'] == {'documentados': 0, 'abiertos': 2, 'cerrados_sin_recuperacion': 0,
                                'denominador': 2, 'porcentaje_cohorte': 0.0}
    assert i['diaria'][0] == {'periodo': '2031-01-01', 'total': 1}
    assert i['diaria'][-1] == {'periodo': '2031-01-31', 'total': 1}
    assert i['horas'][0]['total'] == i['horas'][23]['total'] == 1
    assert sum(x['total'] for x in i['marcas']) == 2
    assert i['modelos'] == [{'marca': 'Marca ficticia', 'modelo': 'Modelo piloto', 'total': 2}]
    assert h['total'] == 1  # varias noticias nunca se vuelven varios hechos
    assert h['ambito'] == 'historial_revisado_compartido_sin_adscripcion_organizacional'
    assert 'marcas' not in h and 'modelos' not in h
    assert d['filtros']['zona_horaria'] == 'America/Santiago'
    assert consulta(client, supervisor_org1, f['zona'], entorno='operacion').json()['internos']['total'] == 1
    assert consulta(client, supervisor_org1, f['zona']+'%').json()['internos']['total'] == 0
    anual = client.get(URL, headers=supervisor_org1, params={'anio': 2031, 'zona': f['zona'], 'entorno': 'prueba'}).json()
    assert anual['internos']['total'] == 3
    assert anual['filtros']['organizaciones'] == [1]
    for privado in ['id_usuario_reportante', 'direccion_privada', 'descripcion_privada', 'patente',
                    'referencia_secreto', 'referencia_autorizacion', 'NO EXPONER']:
        assert privado not in r.text


def test_estadisticas_camaras_proximidad_distinta_de_poligono(client, supervisor_org1, cohorte_estadisticas, db):
    f = cohorte_estadisticas
    d = consulta(client, supervisor_org1, f['zona']).json()
    z = d['camaras']['zonas'][0]
    assert z == {'zona': f['zona'], 'reportes': 2, 'con_ubicacion': 1,
                 'cerca_de_camara': 1, 'en_cobertura_declarada': 0, 'sin_camara_cercana': 0}
    # La cámara cercana autorizada deja de estar disponible. Las de org ajena no cuentan.
    db("UPDATE camara SET estado='fuera_servicio' WHERE id_camara=%s", (f['camaras'][0],))
    z = consulta(client, supervisor_org1, f['zona']).json()['camaras']['zonas'][0]
    assert z['cerca_de_camara'] == 0 and z['sin_camara_cercana'] == 1
    db("""UPDATE camara SET estado='disponible',cobertura=ST_GeomFromText(
        'MULTIPOLYGON(((-73.01 -36.01,-72.99 -36.01,-72.99 -35.99,-73.01 -35.99,-73.01 -36.01)))',4326)
        WHERE id_camara=%s""", (f['camaras'][0],))
    z = consulta(client, supervisor_org1, f['zona']).json()['camaras']['zonas'][0]
    assert z['en_cobertura_declarada'] == 1
