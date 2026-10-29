import uuid
from test_identidad_mvp import activar
from test_casos import _reporte

def test_vehiculo_y_caso_conectados_y_aislamiento(client):
    _,_,h,_=activar(client)
    datos={'marca':'MARCA ENSAYO','modelo':'MODELO ENSAYO','patente':'T'+uuid.uuid4().hex[:8],'color':'gris','anio':2020}
    r=client.post('/vehiculos',headers=h,json=datos)
    assert r.status_code==201,r.text
    vid=r.json()['id_vehiculo']
    assert r.json()['estado_vinculo']=='pendiente'
    assert any(v['id_vehiculo']==vid for v in client.get('/vehiculos',headers=h).json())
    assert client.post('/vehiculos',headers=h,json=datos).status_code==409
    r=client.post('/casos',headers={**h,'Idempotency-Key':str(uuid.uuid4())},json=_reporte(id_vehiculo=vid))
    assert r.status_code==201,r.text
    assert any(c['id_caso']==r.json()['id_caso'] for c in client.get('/mis-casos',headers=h).json())
    _,_,otro,_=activar(client)
    assert client.get('/vehiculos',headers=otro).json()==[]
    assert client.get('/mis-casos',headers=otro).json()==[]

def test_revision_con_ambito_y_sin_publicacion(client,ciudadano,supervisor_org1,operador_org2):
    r=client.post('/casos',headers={**ciudadano['headers'],'Idempotency-Key':str(uuid.uuid4())},json=_reporte())
    cid=r.json()['id_caso']
    datos={'estado':'en_revision','motivo':'Revisión ficticia del avance conectado'}
    assert client.post(f'/gestion/casos/{cid}/revision',headers=ciudadano['headers'],json=datos).status_code==403
    assert client.post(f'/gestion/casos/{cid}/revision',headers=operador_org2,json=datos).status_code==403
    r=client.post(f'/gestion/casos/{cid}/revision',headers=supervisor_org1,json=datos)
    assert r.status_code==200,r.text
    assert r.json()['publicado'] is False

def test_frontend_y_clave_demo(client,monkeypatch):
    assert client.get('/').status_code==200
    assert 'RutaAlerta' in client.get('/').text
    monkeypatch.setenv('DEMO_ACCESS_KEY','clave-de-demo-no-es-una-clave-real')
    assert client.get('/health').status_code==403
    assert client.get('/health',headers={'X-Demo-Access':'clave-de-demo-no-es-una-clave-real'}).status_code==200
