import uuid
from test_identidad_mvp import activar
from test_beta_colaborativa import foto_payload
from test_casos import _reporte


def test_retirar_y_registrar_en_otra_cuenta(client):
    _, _, titular, _ = activar(client)
    _, _, otro, _ = activar(client)
    patente = 'ZX' + str(int(uuid.uuid4().hex[:6], 16) % 10000).zfill(4)
    datos = dict(tipo_vehiculo='automovil', marca='TOYOTA', modelo='YARIS',
                 patente=patente, color='Azul', anio=2020)
    r = client.post('/vehiculos', headers=titular, json=datos)
    assert r.status_code == 201, r.text
    vid = r.json()['id_vehiculo']
    assert client.post('/vehiculos', headers=otro, json=datos).status_code == 409
    ruta = f'/vehiculos/{vid}/vinculo'
    assert client.delete(ruta, headers=otro).status_code == 403
    assert client.delete(ruta, headers=titular).status_code == 204
    nuevo = client.post('/vehiculos', headers=otro, json=datos)
    assert nuevo.status_code == 201, nuevo.text
    assert nuevo.json()['id_vehiculo'] == vid
    assert client.get('/vehiculos', headers=titular).json() == []


def test_antecedente_privado_del_titular(client, ciudadano, supervisor_org1):
    h = ciudadano['headers']
    r = client.post('/casos', headers={**h, 'Idempotency-Key': str(uuid.uuid4())},
                    json=_reporte())
    assert r.status_code == 201
    cid = r.json()['id_caso']
    assert client.delete('/vehiculos/1/vinculo', headers=h).status_code == 409
    _, _, ajeno, _ = activar(client)
    datos = dict(descripcion='Antecedente adicional reservado del titular',
                 clave_envio=str(uuid.uuid4()),
                 foto_base64=foto_payload()['contenido_base64'])
    ruta = f'/mis-casos/{cid}/antecedentes'
    assert client.post(ruta, headers=ajeno, json=datos).status_code == 403
    assert client.post(ruta, headers=h, json=datos).status_code == 201
    assert client.post(ruta, headers=h, json=datos).status_code == 200
    ficha = client.get(f'/seguimiento/{cid}', headers=h).json()
    assert len(ficha['evidencias']) == 1
