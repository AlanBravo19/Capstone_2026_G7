"""Fotos públicas seleccionadas, consentidas y revocables; datos ficticios."""
import uuid

import pytest
from PIL import Image
import io

from test_beta_colaborativa import caso, foto_payload, publicacion
from test_casos import _reporte


PUBLICACION = {'zona': 'Sector ficticio', 'texto': 'Vehículo ficticio: datos mínimos revisados.',
               'motivo': 'Autorización ficticia para comprobar fotos públicas'}


def subir(client, cid, headers, autorizada=None):
    body = foto_payload()
    if autorizada is not None:
        body['autorizar_foto_publica'] = autorizada
    r = client.post(f'/casos/{cid}/fotos', headers=headers, json=body)
    assert r.status_code == 201, r.text
    return r.json()['id_evidencia']


def aceptar(client, eid, op):
    r = client.post(f'/gestion/evidencias/{eid}/revision', headers=op,
                    json={'decision': 'aceptada', 'motivo': 'Foto ficticia revisada y aceptada'})
    assert r.status_code == 204, r.text


def preparar(client, ciudadano, op):
    cid = caso(client, ciudadano)
    assert client.post(f'/mis-casos/{cid}/colaboracion', headers=ciudadano['headers']).status_code == 200
    r = client.post(f'/gestion/casos/{cid}/revision', headers=op,
                    json={'estado': 'en_revision', 'motivo': 'Revisión ficticia para publicación'})
    assert r.status_code == 200, r.text
    return cid


def publicar_foto(client, cid, eid, op):
    return client.post(f'/gestion/casos/{cid}/publicacion', headers=op,
                       json={**PUBLICACION, 'id_foto_vehiculo': eid})


def fila(client, sid, headers):
    r = client.get('/colaboracion', headers=headers)
    assert r.status_code == 200, r.text
    return next((v for v in r.json()['cercanos'] + r.json()['otras_zonas']
                 if v['id_solicitud_colaboracion'] == sid), None)


def test_foto_publica_aceptada_detalle_minimo_y_evidencia_privada(client, ciudadano, supervisor_org1, operador_org2):
    cid = preparar(client, ciudadano, supervisor_org1)
    eid = subir(client, cid, ciudadano['headers'], True)
    aceptar(client, eid, supervisor_org1)
    r = publicar_foto(client, cid, eid, supervisor_org1)
    assert r.status_code == 201, r.text
    sid = r.json()['id_solicitud_colaboracion']
    row = fila(client, sid, operador_org2)
    assert row['foto_disponible'] is True
    assert row['foto_url'] == f'/colaboracion/{sid}/foto-vehiculo'
    assert 'tipo_vehiculo' in row
    detail = client.get(f'/colaboracion/{sid}', headers=operador_org2)
    assert detail.status_code == 200 and detail.json() == row
    for private in ('id_caso', 'id_usuario_reportante', 'descripcion_privada', 'id_foto_vehiculo', 'clave_objeto', 'latitud', 'longitud'):
        assert private not in detail.json()
    image = client.get(row['foto_url'], headers=operador_org2)
    assert image.status_code == 200 and image.headers['content-type'] == 'image/jpeg'
    assert image.headers['cache-control'] == 'no-store'
    with Image.open(io.BytesIO(image.content)) as im:
        assert im.format == 'JPEG' and not im.getexif()
    assert client.get(row['foto_url']).status_code == 401
    assert client.get(f'/colaboracion/{sid}').status_code == 401
    assert client.get(f'/evidencias/{eid}/foto', headers=operador_org2).status_code == 403
    assert client.get(f'/evidencias/{eid}/foto', headers=ciudadano['headers']).status_code == 200
    equipo = client.get(f'/gestion/casos/{cid}/equipo', headers=supervisor_org1).json()
    assert equipo['publicacion']['id_foto_vehiculo'] == eid


@pytest.mark.parametrize('invalid', ['sin_consentimiento', 'pendiente', 'otro_caso', 'avistamiento', 'otro_autor', 'sin_bytes', 'carga_error'])
def test_seleccion_rechaza_foto_no_elegible(client, db, ciudadano, supervisor_org1, invalid):
    cid = preparar(client, ciudadano, supervisor_org1)
    photo_cid = caso(client, ciudadano) if invalid == 'otro_caso' else cid
    eid = subir(client, photo_cid, ciudadano['headers'], invalid != 'sin_consentimiento')
    if invalid != 'pendiente':
        aceptar(client, eid, supervisor_org1)
    if invalid == 'avistamiento':
        sid = publicacion(client, cid, ciudadano['headers'], supervisor_org1)
        aid = db("""INSERT INTO avistamiento(id_solicitud_colaboracion,id_caso,id_usuario_autor,observado_en,zona,descripcion,clave_envio)
                    VALUES(%s,%s,%s,CURRENT_TIMESTAMP,'Sector ficticio','Avistamiento ficticio',%s) RETURNING id_avistamiento""",
                 (sid, cid, ciudadano['id'], str(uuid.uuid4())), filas=True)[0][0]
        db('UPDATE evidencia SET id_avistamiento=%s WHERE id_evidencia=%s', (aid, eid))
        assert client.post(f'/gestion/casos/{cid}/retirar', headers=supervisor_org1,
                           json={'motivo': 'Retirada ficticia para nueva selección'}).status_code == 204
    if invalid == 'otro_autor':
        db("UPDATE evidencia SET id_usuario_autor=(SELECT id_usuario FROM usuario WHERE correo_normalizado='externo@example.invalid') WHERE id_evidencia=%s", (eid,))
    if invalid == 'sin_bytes':
        db('DELETE FROM archivo_evidencia WHERE id_evidencia=%s', (eid,))
    if invalid == 'carga_error':
        db("UPDATE evidencia SET estado_carga='error' WHERE id_evidencia=%s", (eid,))
    r = publicar_foto(client, cid, eid, supervisor_org1)
    assert r.status_code == 422, r.text


@pytest.mark.parametrize('change', ['revocada', 'rechazada', 'vencida', 'cerrado', 'retirada', 'futura', 'sin_bytes', 'carga_error', 'avistamiento'])
def test_lectura_revalida_cada_vez(client, db, ciudadano, supervisor_org1, operador_org2, change):
    cid = preparar(client, ciudadano, supervisor_org1)
    eid = subir(client, cid, ciudadano['headers'], True)
    aceptar(client, eid, supervisor_org1)
    r = publicar_foto(client, cid, eid, supervisor_org1)
    assert r.status_code == 201, r.text
    sid = r.json()['id_solicitud_colaboracion']
    url = f'/colaboracion/{sid}/foto-vehiculo'
    assert client.get(url, headers=operador_org2).status_code == 200
    if change == 'revocada':
        assert client.post(f'/mis-casos/{cid}/fotos/{eid}/publicacion', headers=ciudadano['headers'], json={'autorizada': False}).status_code == 204
    elif change == 'rechazada':
        assert client.post(f'/gestion/evidencias/{eid}/revision', headers=supervisor_org1,
                           json={'decision': 'rechazada', 'motivo': 'Revisión ficticia invalida la foto'}).status_code == 204
    elif change == 'vencida':
        db("UPDATE solicitud_colaboracion SET inicio=CURRENT_TIMESTAMP-interval '2 hours',vence_en=CURRENT_TIMESTAMP-interval '1 hour' WHERE id_solicitud_colaboracion=%s", (sid,))
    elif change == 'cerrado':
        # Do not rely on closure retiring the solicitud: the read must check the case itself.
        db("UPDATE caso SET estado='cerrado',cerrado_en=CURRENT_TIMESTAMP,motivo_cierre='otro' WHERE id_caso=%s", (cid,))
    elif change == 'retirada':
        assert client.post(f'/gestion/casos/{cid}/retirar', headers=supervisor_org1, json={'motivo': 'Retirada ficticia de publicación'}).status_code == 204
    elif change == 'futura':
        db("UPDATE solicitud_colaboracion SET inicio=CURRENT_TIMESTAMP+interval '1 hour' WHERE id_solicitud_colaboracion=%s", (sid,))
    elif change == 'sin_bytes':
        db('DELETE FROM archivo_evidencia WHERE id_evidencia=%s', (eid,))
    elif change == 'carga_error':
        db("UPDATE evidencia SET estado_carga='error' WHERE id_evidencia=%s", (eid,))
    elif change == 'avistamiento':
        aid = db("""INSERT INTO avistamiento(id_solicitud_colaboracion,id_caso,id_usuario_autor,observado_en,zona,descripcion,clave_envio)
                    VALUES(%s,%s,%s,CURRENT_TIMESTAMP,'Sector ficticio','Avistamiento ficticio',%s) RETURNING id_avistamiento""",
                 (sid, cid, ciudadano['id'], str(uuid.uuid4())), filas=True)[0][0]
        db('UPDATE evidencia SET id_avistamiento=%s WHERE id_evidencia=%s', (aid, eid))
    r = client.get(url, headers=operador_org2)
    assert r.status_code == 404 and r.headers['cache-control'] == 'no-store'
    row = fila(client, sid, operador_org2)
    detail = client.get(f'/colaboracion/{sid}', headers=operador_org2)
    if change in ('vencida', 'cerrado', 'retirada', 'futura'):
        assert row is None and detail.status_code == 404
    else:
        assert row['foto_disponible'] is False and row['foto_url'] is None
        assert detail.json()['foto_disponible'] is False and detail.json()['foto_url'] is None


def test_legacy_privada_y_consentimiento_solo_titular(client, db, ciudadano, supervisor_org1, operador_org2):
    cid = preparar(client, ciudadano, supervisor_org1)
    eid = subir(client, cid, ciudadano['headers'])
    path = f'/mis-casos/{cid}/fotos/{eid}/publicacion'
    evidence = client.get(f'/seguimiento/{cid}', headers=ciudadano['headers']).json()['evidencias'][0]
    assert evidence['autorizada_publicacion_en'] is None
    assert client.post(path, headers=operador_org2, json={'autorizada': True}).status_code == 403
    assert client.post(path, headers=supervisor_org1, json={'autorizada': True}).status_code == 403
    assert client.post(path, headers=ciudadano['headers'], json={'autorizada': True}).status_code == 204
    assert client.get(f'/seguimiento/{cid}', headers=ciudadano['headers']).json()['evidencias'][0]['autorizada_publicacion_en'] is not None
    other = caso(client, ciudadano)
    assert client.post(f'/mis-casos/{other}/fotos/{eid}/publicacion', headers=ciudadano['headers'], json={'autorizada': False}).status_code == 404
    aceptar(client, eid, supervisor_org1)
    r = client.post(f'/gestion/casos/{cid}/publicacion', headers=supervisor_org1, json=PUBLICACION)
    assert r.status_code == 201, r.text
    sid = r.json()['id_solicitud_colaboracion']
    assert fila(client, sid, ciudadano['headers'])['foto_disponible'] is False
    assert client.get(f'/colaboracion/{sid}/foto-vehiculo', headers=ciudadano['headers']).status_code == 404


@pytest.mark.parametrize('photo,collaboration,consent,status', [(False, True, True, 422), (True, False, True, 422), (True, True, True, 201), (True, True, False, 201), (True, False, False, 201)])
def test_reporte_consentimiento_explicito_transaccional(client, db, ciudadano, photo, collaboration, consent, status):
    body = _reporte(solicitar_colaboracion=collaboration, autorizar_foto_publica=consent)
    if photo:
        body['foto_base64'] = foto_payload()['contenido_base64']
    key = str(uuid.uuid4())
    h = {**ciudadano['headers'], 'Idempotency-Key': key}
    r = client.post('/casos', headers=h, json=body)
    assert r.status_code == status, r.text
    if status == 422:
        assert db('SELECT count(*) FROM caso WHERE clave_envio=%s::uuid', (key,), filas=True)[0][0] == 0
    else:
        cid = r.json()['id_caso']
        records = db('SELECT autorizada_publicacion_en FROM evidencia WHERE id_caso=%s', (cid,), filas=True)
        assert len(records) == 1 and (records[0][0] is not None) == consent
        assert client.post('/casos', headers=h, json=body).status_code == 200
        assert db('SELECT count(*) FROM evidencia WHERE id_caso=%s', (cid,), filas=True)[0][0] == 1
