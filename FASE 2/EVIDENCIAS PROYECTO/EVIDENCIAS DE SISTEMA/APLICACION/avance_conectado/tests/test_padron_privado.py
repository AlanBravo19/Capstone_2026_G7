from dataclasses import replace
from hashlib import sha256
from uuid import uuid4

from app import alertas, prelectura_padron
from fastapi import HTTPException
import httpx
from test_alertas_provisionales import reportar
from test_beta_colaborativa import foto_payload
from test_identidad_mvp import activar


def vehiculo():
    placa = uuid4().hex[:4].translate(str.maketrans('0123456789', 'GHIJKLMNOP')).upper()+'85'
    return {'marca':'TOYOTA', 'modelo':'YARIS', 'patente':placa, 'color':'Azul', 'anio':2020}


def test_padron_privado_habilita_alerta_tras_revision(client, db, supervisor_org1, operador_org2, monkeypatch):
    monkeypatch.setattr(alertas, 'config', replace(alertas.config, alertas_automaticas=True))
    _, _, titular, _ = activar(client)
    ope_id, _, colaborador, _ = activar(client)
    datos = vehiculo()
    padron = foto_payload()['contenido_base64']
    db("UPDATE organizacion SET alertas_provisionales_habilitadas=TRUE WHERE id_organizacion=1")
    alta = client.post('/vehiculos', headers=titular, json={**datos, 'revision': {'id_organizacion':1, 'padron_base64':padron}})
    assert alta.status_code == 201, alta.text
    assert alta.json()['revision_solicitada']
    vid = alta.json()['id_vehiculo']
    tarjeta = next(v for v in client.get('/vehiculos', headers=titular).json() if v['id_vehiculo']==vid)
    assert tarjeta['padron_recibido_en'] and tarjeta['estado_vinculo']=='pendiente'
    item = next(v for v in client.get('/gestion/vinculos', headers=supervisor_org1).json() if v['patente']==datos['patente'])
    assert item['padron_disponible'] and item['puede_revisar']
    vinculo = item['id_vinculo_vehiculo']
    assert any(n['titulo'] == 'Padrón pendiente de revisión' for n in client.get('/notificaciones', headers=supervisor_org1).json())
    url = f'/gestion/vinculos/{vinculo}'
    cuerpo = {'decision':'autorizado', 'estado_esperado':'pendiente', 'motivo':'padron_y_coincidencia', 'confirmar_padron':True}
    assert client.get(url+'/padron', headers=titular).status_code == 404
    assert client.get(url+'/padron', headers=operador_org2).status_code == 404
    db("INSERT INTO membresia(id_usuario,id_organizacion,rol,inicio) VALUES(%s,1,'operador',CURRENT_TIMESTAMP)", (ope_id,))
    assert client.get(url+'/padron', headers=colaborador).status_code == 404
    assert client.post(url+'/decision', headers=colaborador, json=cuerpo).status_code == 403
    assert client.post(url+'/decision', headers=supervisor_org1, json=cuerpo).status_code == 422
    archivo = client.get(url+'/padron', headers=supervisor_org1)
    assert archivo.status_code == 200 and archivo.content.startswith(b'\xff\xd8')
    assert archivo.headers['content-type'] == 'image/jpeg' and 'no-store' in archivo.headers['cache-control']
    assert client.post(url+'/decision', headers=supervisor_org1, json={**cuerpo,'confirmar_padron':False}).status_code == 422
    decision = client.post(url+'/decision', headers=supervisor_org1, json=cuerpo)
    assert decision.status_code == 204, decision.text
    assert client.get(url+'/padron', headers=supervisor_org1).status_code == 404
    resultado = db('SELECT contenido IS NULL FROM documento_vinculo_vehiculo WHERE id_vinculo_vehiculo=%s', (vinculo,), filas=True)
    assert resultado == [(True,)]
    caso = reportar(client, (titular,colaborador,supervisor_org1,vid,vinculo))
    assert caso.status_code == 201 and caso.json()['publicacion'] == 'provisional', caso.text
    listado = client.get('/colaboracion', headers=colaborador).json()
    alerta = next(a for a in listado['cercanos']+listado['otras_zonas'] if a['patente']==datos['patente'])
    assert alerta['modo_alerta']=='provisional' and not alerta['foto_disponible']
    assert not {'padron_base64', 'padron_recibido_en', 'referencia_revision'} & alerta.keys()


def test_prelectura_solo_ensayo_y_sin_aprobar(client, supervisor_org1, monkeypatch):
    _, _, titular, _ = activar(client)
    datos = {**vehiculo(), 'patente': prelectura_padron.PATENTE_ENSAYO}
    revision = {'id_organizacion': 1, 'padron_base64': foto_payload()['contenido_base64']}
    assert client.post('/vehiculos', headers=titular, json={**datos, 'revision': revision}).status_code == 201
    fila = next(r for r in client.get('/gestion/vinculos', headers=supervisor_org1).json() if r['patente']==datos['patente'])
    url = f"/gestion/vinculos/{fila['id_vinculo_vehiculo']}/prelectura"
    assert client.post(url, headers=supervisor_org1, json={'archivo_ficticio': True}).status_code == 404
    monkeypatch.setattr(prelectura_padron, 'config', replace(prelectura_padron.config, alertas_demo=True))
    monkeypatch.setenv('GROQ_API_KEY', 'credencial-ficticia-de-prueba')
    monkeypatch.setenv('GROQ_PADRON_ENSAYO_SHA256', '0' * 64)
    solicitudes = []

    def provider(endpoint, **kwargs):
        solicitudes.append(endpoint)
        assert endpoint == 'https://api.groq.com/openai/v1/chat/completions'
        assert kwargs['headers']['Authorization'] == 'Bearer credencial-ficticia-de-prueba'
        assert kwargs['json']['model'] == 'qwen/qwen3.8-27b'
        assert kwargs['json']['response_format'] == {'type': 'json_object'}
        assert kwargs['json']['reasoning_effort'] == 'none'
        assert kwargs['follow_redirects'] is False
        imagen = kwargs['json']['messages'][0]['content'][1]['image_url']['url']
        assert imagen.startswith('data:image/jpeg;base64,')
        assert datos['patente'] not in kwargs['json']['messages'][0]['content'][0]['text']
        return httpx.Response(200, request=httpx.Request('POST', endpoint), json={'choices': [
            {'finish_reason': 'stop', 'message': {'content':
                '{"legible":true,"parece_padron":true,"placa":"ZQXT-92"}'}},
        ]})

    monkeypatch.setattr(prelectura_padron.httpx, 'post', provider)
    assert client.post(url, headers=titular, json={'archivo_ficticio': True}).status_code == 404
    assert client.post(url, headers=supervisor_org1, json={'archivo_ficticio': False}).status_code == 422
    assert client.post(url, headers=supervisor_org1, json={'archivo_ficticio': True}).status_code == 422
    assert solicitudes == []
    jpeg = client.get(url.removesuffix('/prelectura') + '/padron', headers=supervisor_org1).content
    monkeypatch.setenv('GROQ_PADRON_ENSAYO_SHA256', sha256(jpeg).hexdigest())
    assert client.post(url, headers=supervisor_org1, json={'archivo_ficticio': True}).json() == {'resultado':'coincide','modo':'ensayo'}
    assert len(solicitudes) == 1
    actual = next(r for r in client.get('/gestion/vinculos', headers=supervisor_org1).json() if r['patente']==datos['patente'])
    assert actual['estado'] == 'pendiente' and actual['padron_disponible']


def test_padron_invalido_no_reserva_patente_y_puede_agregarse_despues(client, db):
    _, _, titular, _ = activar(client)
    datos = vehiculo()
    fallo = client.post('/vehiculos', headers=titular, json={**datos, 'revision': {'id_organizacion':1, 'padron_base64':'not-an-image-00000'}})
    assert fallo.status_code == 422
    assert db('SELECT count(*) FROM vehiculo WHERE patente_normalizada=%s', (datos['patente'],), filas=True) == [(0,)]
    alta = client.post('/vehiculos', headers=titular, json=datos)
    assert alta.status_code == 201, alta.text
    vid = alta.json()['id_vehiculo']
    ruta = f'/vehiculos/{vid}/revision-vinculo'
    cuerpo = {'id_organizacion':1, 'padron_base64':foto_payload()['contenido_base64']}
    assert client.post(ruta, headers=titular, json={'id_organizacion':1}).status_code == 204
    assert client.post(ruta, headers=titular, json=cuerpo).status_code == 204
    assert client.post(ruta, headers=titular, json=cuerpo).status_code == 204
    assert client.post(ruta, headers=titular, json={**cuerpo, 'id_organizacion':2}).status_code == 409
    assert client.delete(f'/vehiculos/{vid}/vinculo', headers=titular).status_code == 204
    assert db('''SELECT d.contenido IS NULL FROM documento_vinculo_vehiculo d JOIN vinculo_vehiculo v
        USING(id_vinculo_vehiculo) WHERE v.id_vehiculo=%s''', (vid,), filas=True) == [(True,)]


def test_cotejo_optativo_devuelve_discrepancia_y_conserva_revision_manual(client, supervisor_org1, monkeypatch):
    _, _, titular, _ = activar(client)
    datos = vehiculo()
    documento = {'id_organizacion': 1, 'padron_base64': foto_payload()['contenido_base64']}
    monkeypatch.setattr(prelectura_padron, 'operativa', lambda: True)
    solicitudes = []

    def leer(imagen):
        assert imagen.startswith(b'\xff\xd8')
        solicitudes.append(True)
        return prelectura_padron.Lectura(parece_padron=True, legible=True, placa='ABCD12')

    monkeypatch.setattr(prelectura_padron, 'leer', leer)
    enviado = {**documento, 'autorizar_prelectura': True}
    alta = client.post('/vehiculos', headers=titular, json={**datos, 'revision': enviado})
    assert alta.status_code == 422 and 'no coincide' in alta.json()['detail']
    assert all(v['patente'] != datos['patente'] for v in client.get('/vehiculos', headers=titular).json())

    alta = client.post('/vehiculos', headers=titular, json=datos)
    assert alta.status_code == 201
    ruta = f"/vehiculos/{alta.json()['id_vehiculo']}/revision-vinculo"
    assert client.post(ruta, headers=titular, json=enviado).status_code == 422
    assert client.post(ruta, headers=titular, json=documento).status_code == 204
    assert solicitudes == [True, True]
    fila = next(v for v in client.get('/gestion/vinculos', headers=supervisor_org1).json() if v['patente'] == datos['patente'])
    assert fila['estado'] == 'pendiente' and fila['padron_disponible'] and fila['padron_prelectura'] is None


def test_cotejo_registra_coincidencia_y_respaldo_si_proveedor_falla(client, supervisor_org1, monkeypatch):
    _, _, titular, _ = activar(client)
    datos = vehiculo()
    documento = {'id_organizacion': 1, 'padron_base64': foto_payload()['contenido_base64'], 'autorizar_prelectura': True}
    monkeypatch.setattr(prelectura_padron, 'operativa', lambda: True)
    monkeypatch.setattr(prelectura_padron, 'leer', lambda imagen: prelectura_padron.Lectura(
        parece_padron=True, legible=True, placa=datos['patente']))
    assert client.post('/vehiculos', headers=titular, json={**datos, 'revision': documento}).status_code == 201
    lista = client.get('/vehiculos', headers=titular).json()
    assert any(f['patente'] == datos['patente'] and f['padron_prelectura'] == 'coincide' for f in lista)

    def sin_servicio(imagen):
        raise HTTPException(503)

    otro = vehiculo()
    monkeypatch.setattr(prelectura_padron, 'leer', sin_servicio)
    assert client.post('/vehiculos', headers=titular, json={**otro, 'revision': documento}).status_code == 201
    fila = next(v for v in client.get('/gestion/vinculos', headers=supervisor_org1).json() if v['patente'] == otro['patente'])
    assert fila['estado'] == 'pendiente' and fila['padron_disponible'] and fila['padron_prelectura'] == 'inconclusa'
