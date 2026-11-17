"""Catálogo oficial, compatibilidad de zonas y CRUD con permisos reales sobre SQL."""
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest

from app.routers.recursos_territorio import COMUNAS
from test_casos import _reporte


def entrada(**cambios):
    ahora = datetime.now(timezone.utc)
    return {'categoria': 'apoyo_victima', 'territorio': 'Territorio legado de prueba',
            'titulo': f'Orientación ficticia {uuid4().hex}', 'descripcion': 'Información de ensayo sin atención real.',
            'canal': 'Canal ficticio de prueba', 'url_oficial': 'https://example.invalid/ayuda',
            'verificado_en': (ahora - timedelta(hours=1)).isoformat(),
            'vence_en': (ahora + timedelta(days=1)).isoformat(), **cambios}


@pytest.fixture
def recurso_creado(client, supervisor_org1, db):
    r = client.post('/gestion/recursos-apoyo', headers=supervisor_org1, json=entrada())
    assert r.status_code == 201, r.text
    rid = r.json()['id_recurso_apoyo']
    yield r.json()
    db('DELETE FROM recurso_apoyo WHERE id_recurso_apoyo=%s', (rid,))


def test_catalogo_completo_codigos_y_busqueda(client, ciudadano):
    assert len(COMUNAS) == 346
    assert all(len(c) == 5 and c.isdigit() for c in COMUNAS)
    h = ciudadano['headers']
    r = client.get('/catalogo/comunas', headers=h)
    assert r.status_code == 200 and len(r.json()) == 346
    assert client.get('/catalogo/comunas?q=CONCEPCION', headers=h).json() == [
        {'codigo_comuna': '08101', 'nombre': 'Concepción'}]
    assert client.get('/catalogo/comunas?q=08101', headers=h).json() == [
        {'codigo_comuna': '08101', 'nombre': 'Concepción'}]
    nombres = {r['nombre'] for r in client.get('/catalogo/comunas?q=chillan', headers=h).json()}
    assert nombres == {'Chillán', 'Chillán Viejo'}
    assert client.get('/catalogo/comunas?q=%27%20OR%201=1', headers=h).json() == []


@pytest.mark.parametrize('body,codigo,nombre', [
    ({'codigo_comuna': '8101'}, '08101', 'Concepción'),
    ({'codigo_comuna': '08101'}, '08101', 'Concepción'),
    ({'comuna': ' chillan '}, '16101', 'Chillán'),
    ({'codigo_comuna': '16103', 'comuna': 'CHILLÁN VIEJO'}, '16103', 'Chillán Viejo')])
def test_comuna_exacta_y_sector_complementario(client, ciudadano, body, codigo, nombre):
    r = client.post('/territorio/validacion', headers=ciudadano['headers'],
                    json={**body, 'sector': 'Sector libre heredado', 'latitud': -36.6, 'longitud': -72.1})
    assert r.status_code == 200, r.text
    datos = r.json()
    assert datos['codigo_comuna'] == codigo and datos['comuna'] == nombre
    assert datos['zona'] == f'{nombre} · Sector libre heredado'
    assert datos['comuna_validada'] is True
    assert datos['sector_validado'] is False
    assert datos['limites_geograficos_verificados'] is False
    assert datos['relacion_comuna_sector_disponible'] is False


@pytest.mark.parametrize('body', [
    {'codigo_comuna': '99999'}, {'codigo_comuna': 8101}, {'codigo_comuna': 'abcde'},
    {'comuna': 'Nombre inventado'}, {'codigo_comuna': '16101', 'comuna': 'Concepción'},
    {'latitud': -36.6}, {'longitud': -72.1}, {'latitud': 91, 'longitud': 0},
    {'latitud': 0, 'longitud': 181}, {'latitud': 'NaN', 'longitud': 0},
    {'latitud': 0, 'longitud': 'Infinity'}, {'sector': '   '}])
def test_geografia_rechaza_codigos_y_coordenadas_invalidos(client, ciudadano, body):
    assert client.post('/territorio/validacion', headers=ciudadano['headers'], json=body).status_code == 422


def test_geografia_no_inventa_poligonos_y_preserva_sector_solo(client, ciudadano):
    h = ciudadano['headers']
    r = client.post('/territorio/validacion', headers=h,
                    json={'codigo_comuna': '16101', 'latitud': 0, 'longitud': 0})
    assert r.status_code == 200 and r.json()['limites_geograficos_verificados'] is False
    r = client.post('/territorio/validacion', headers=h, json={'sector': 'Texto libre heredado'})
    assert r.status_code == 200 and r.json()['comuna_validada'] is False


def test_catalogo_sector_solo_datos_validados_sin_zonas_privadas(client, ciudadano, db):
    nombre = f'Sector-catalogo-{uuid4().hex}'
    pendientes = f'Sector-pendiente-{uuid4().hex}'
    ids = db("""INSERT INTO hecho_territorial(tipo,ocurrido_en,zona,estado,nivel_agregacion,validado_por,validado_en)
                VALUES('otro',CURRENT_TIMESTAMP,%s,'validado','sector',2,CURRENT_TIMESTAMP),
                      ('otro',CURRENT_TIMESTAMP,%s,'pendiente','sector',NULL,NULL)
                RETURNING id_hecho_territorial""", (nombre, pendientes), filas=True)
    try:
        h = ciudadano['headers']
        r = client.get('/catalogo/territorios?tipo=sector&q=Sector-catalogo', headers=h)
        assert r.status_code == 200 and nombre in [i['nombre'] for i in r.json()['items']]
        assert not client.get(f'/catalogo/territorios?q={pendientes}', headers=h).json()['items']
        assert client.get('/catalogo/territorios?tipo=comuna&limite=1', headers=h).json()['hay_mas'] is True
        assert client.get('/catalogo/territorios?tipo=sector', headers=h).json()['limites_geograficos_verificados'] is False
        coberturas = client.get('/catalogo/territorios?tipo=cobertura', headers=h).json()['items']
        assert any(i['nombre'] == 'Sector sintético' for i in coberturas)
    finally:
        for (hid,) in ids:
            db('DELETE FROM hecho_territorial WHERE id_hecho_territorial=%s', (hid,))


def test_recursos_crud_autorizado_lectura_y_desactivacion(client, ciudadano, supervisor_org1, operador_org2, recurso_creado):
    rid = recurso_creado['id_recurso_apoyo']
    path = f'/gestion/recursos-apoyo/{rid}'
    publico = f'/recursos-apoyo/{rid}'
    assert recurso_creado['mantenido_por'] == 2 and recurso_creado['responsable']
    assert recurso_creado['puede_editar'] is True and recurso_creado['vigente'] is True
    assert client.get(publico, headers=ciudadano['headers']).status_code == 200
    assert client.get('/gestion/recursos-apoyo', headers=ciudadano['headers']).status_code == 403
    assert client.put(path, headers=operador_org2, json=entrada()).status_code == 403
    assert client.delete(path, headers=operador_org2).status_code == 403
    assert rid not in [i['id_recurso_apoyo'] for i in client.get('/gestion/recursos-apoyo', headers=operador_org2).json()]
    r = client.put(path, headers=supervisor_org1, json=entrada(codigo_comuna='8101'))
    assert r.status_code == 200, r.text
    assert r.json()['territorio'] == 'Concepción' and r.json()['mantenido_por'] == 2
    items = client.get('/recursos-apoyo?territorio=concepcion&categoria=apoyo_victima', headers=ciudadano['headers']).json()
    assert rid in [i['id_recurso_apoyo'] for i in items]
    assert client.delete(path, headers=supervisor_org1).status_code == 204
    assert client.get(publico, headers=ciudadano['headers']).status_code == 404
    item = next(i for i in client.get('/gestion/recursos-apoyo', headers=supervisor_org1).json() if i['id_recurso_apoyo'] == rid)
    assert item['activo'] is False and item['vigente'] is False
    assert client.put(path, headers=supervisor_org1, json=entrada()).status_code == 200
    assert client.get(publico, headers=ciudadano['headers']).status_code == 200


def test_equipo_reasigna_responsable_sin_cruzar_organizacion(client, ciudadano, supervisor_org1, operador_org2, db, recurso_creado):
    uid = ciudadano['id']
    db("INSERT INTO membresia(id_usuario,id_organizacion,rol,inicio) VALUES(%s,1,'operador',CURRENT_TIMESTAMP)", (uid,))
    path = f"/gestion/recursos-apoyo/{recurso_creado['id_recurso_apoyo']}"
    try:
        r = client.put(path, headers=ciudadano['headers'], json=entrada())
        assert r.status_code == 200 and r.json()['mantenido_por'] == 2
        r = client.put(path, headers=supervisor_org1, json=entrada(mantenido_por=uid))
        assert r.status_code == 200 and r.json()['mantenido_por'] == uid
        assert client.put(path, headers=supervisor_org1, json=entrada(mantenido_por=5)).status_code == 403
        assert client.post('/gestion/recursos-apoyo', headers=operador_org2, json=entrada(mantenido_por=uid)).status_code == 403
        opciones = client.get('/gestion/recursos-apoyo/responsables', headers=supervisor_org1).json()
        assert {2, uid} <= {i['id_usuario'] for i in opciones} and 5 not in {i['id_usuario'] for i in opciones}
    finally:
        db('UPDATE recurso_apoyo SET mantenido_por=2 WHERE id_recurso_apoyo=%s', (recurso_creado['id_recurso_apoyo'],))
        db('DELETE FROM membresia WHERE id_usuario=%s', (uid,))


@pytest.mark.parametrize('estado,inicio,fin', [
    ('suspendida', '-1 day', None), ('activa', '1 day', None), ('finalizada', '-2 days', '-1 day')])
def test_membresia_suspendida_futura_o_finalizada_no_habilita_crud(client, ciudadano, db, estado, inicio, fin):
    db("""INSERT INTO membresia(id_usuario,id_organizacion,rol,estado,inicio,fin)
           VALUES(%s,1,'operador',%s,CURRENT_TIMESTAMP+%s::interval,
                  CASE WHEN %s::text IS NULL THEN NULL ELSE CURRENT_TIMESTAMP+%s::interval END)""",
       (ciudadano['id'], estado, inicio, fin, fin))
    try:
        assert client.post('/gestion/recursos-apoyo', headers=ciudadano['headers'], json=entrada()).status_code == 403
        assert client.get('/gestion/recursos-apoyo', headers=ciudadano['headers']).status_code == 403
    finally:
        db('DELETE FROM membresia WHERE id_usuario=%s', (ciudadano['id'],))


def test_organizacion_inactiva_no_habilita_crud(client, operador_org2, db):
    db("UPDATE organizacion SET estado='inactiva' WHERE id_organizacion=2")
    try:
        assert client.post('/gestion/recursos-apoyo', headers=operador_org2, json=entrada()).status_code == 403
    finally:
        db("UPDATE organizacion SET estado='activa' WHERE id_organizacion=2")


@pytest.mark.parametrize('cambios', [
    {'activo': False},
    {'verificado_en': (datetime.now(timezone.utc) - timedelta(days=2)).isoformat(),
     'vence_en': (datetime.now(timezone.utc) - timedelta(days=1)).isoformat()},
    {'verificado_en': (datetime.now(timezone.utc) + timedelta(days=1)).isoformat(),
     'vence_en': (datetime.now(timezone.utc) + timedelta(days=2)).isoformat()}])
def test_ciudadania_no_ve_recursos_inactivos_vencidos_o_futuros(client, ciudadano, supervisor_org1, recurso_creado, cambios):
    rid = recurso_creado['id_recurso_apoyo']
    assert client.put(f'/gestion/recursos-apoyo/{rid}', headers=supervisor_org1, json=entrada(**cambios)).status_code == 200
    assert client.get(f'/recursos-apoyo/{rid}', headers=ciudadano['headers']).status_code == 404
    assert rid not in [i['id_recurso_apoyo'] for i in client.get('/recursos-apoyo', headers=ciudadano['headers']).json()]


@pytest.mark.parametrize('cambios', [
    {'categoria': 'salud'}, {'titulo': '   '}, {'territorio': None}, {'canal': '   '},
    {'url_oficial': 'javascript:alert(1)'}, {'codigo_comuna': '99999'},
    {'verificado_en': '2026-01-02T12:00:00Z', 'vence_en': '2026-01-01T12:00:00Z'},
    {'verificado_en': '2026-01-02T12:00:00'}, {'mantenido_por': -1}])
def test_validacion_de_recursos(client, supervisor_org1, cambios):
    assert client.post('/gestion/recursos-apoyo', headers=supervisor_org1, json=entrada(**cambios)).status_code == 422


def test_creacion_por_operador_y_codigo_sin_territorio(client, operador_org2, db):
    datos = entrada(codigo_comuna='16101')
    datos.pop('territorio')
    r = client.post('/gestion/recursos-apoyo', headers=operador_org2, json=datos)
    assert r.status_code == 201, r.text
    try:
        assert r.json()['territorio'] == 'Chillán' and r.json()['mantenido_por'] == 5
    finally:
        db('DELETE FROM recurso_apoyo WHERE id_recurso_apoyo=%s', (r.json()['id_recurso_apoyo'],))


def test_autenticacion_obligatoria_y_compatibilidad_zona_libre(client, ciudadano):
    for path in ('/recursos-apoyo', '/recursos-apoyo/1', '/gestion/recursos-apoyo',
                 '/gestion/recursos-apoyo/responsables', '/catalogo/comunas', '/catalogo/territorios'):
        assert client.get(path).status_code == 401
    assert client.post('/territorio/validacion', json={}).status_code == 401
    assert client.post('/gestion/recursos-apoyo', json=entrada()).status_code == 401
    assert client.put('/gestion/recursos-apoyo/1', json=entrada()).status_code == 401
    assert client.delete('/gestion/recursos-apoyo/1').status_code == 401
    datos = _reporte()
    datos['zona'] = 'Zona histórica válida sin código de comuna'
    r = client.post('/casos', headers={**ciudadano['headers'], 'Idempotency-Key': str(uuid4())}, json=datos)
    assert r.status_code == 201, r.text
