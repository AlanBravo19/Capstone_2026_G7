import uuid
from dataclasses import replace
import pytest
from test_identidad_mvp import activar
from test_casos import _reporte


def test_acceso_y_asignacion_no_elevan_el_rol(client, db, ciudadano, supervisor_org1):
    uid, _, operador, _ = activar(client)
    db("""INSERT INTO membresia(id_usuario,id_organizacion,rol,inicio)
          VALUES(%s,1,'operador',CURRENT_TIMESTAMP)""", (uid,))
    assert client.get('/gestion/mi-acceso',headers=ciudadano['headers']).status_code == 403
    acceso = client.get('/gestion/mi-acceso',headers=operador).json()
    assert acceso['organizaciones'][0]['rol'] == 'operador'
    assert acceso['organizaciones'][0]['puede_asignar'] is False
    assert not acceso['administrador_global']
    assert client.get('/gestion/mi-acceso',headers=supervisor_org1).json()['organizaciones'][0]['puede_asignar']
    cid = client.post('/casos',headers={**ciudadano['headers'],'Idempotency-Key':str(uuid.uuid4())},json=_reporte()).json()['id_caso']
    member = db('SELECT id_membresia FROM membresia WHERE id_usuario=%s AND id_organizacion=1',(uid,),filas=True)[0][0]
    ruta = f'/gestion/casos/{cid}/asignacion'
    datos = {'id_membresia':member,'motivo':'Asignación supervisada del ensayo'}
    assert client.post(ruta,headers=operador,json=datos).status_code == 403
    assert client.post(ruta,headers=supervisor_org1,json=datos).status_code == 204
    assert client.post(ruta,headers=operador,json=datos).status_code == 403


def test_admin_global_sin_membresia_no_gana_acceso_institucional(client, db):
    uid, _, headers, _ = activar(client)
    db("""INSERT INTO usuario_rol(id_usuario,id_rol,asignado_por)
          SELECT %s,id_rol,%s FROM rol WHERE codigo='administrador'""",(uid,uid))
    assert 'administrador' in client.get('/mi-perfil',headers=headers).json()['roles']
    assert client.get('/gestion/mi-acceso',headers=headers).status_code == 403
    assert client.get('/gestion/metricas',headers=headers).status_code == 403


@pytest.mark.parametrize('entorno',['operacion','prueba'])
def test_reporte_registra_el_entorno_configurado(client,db,ciudadano,monkeypatch,entorno):
    from app.routers import casos
    monkeypatch.setattr(casos,'config',replace(casos.config,entorno=entorno))
    r=client.post('/casos',headers={**ciudadano['headers'],'Idempotency-Key':str(uuid.uuid4())},json=_reporte())
    assert r.status_code==201,r.text
    assert db('SELECT entorno FROM caso WHERE id_caso=%s',(r.json()['id_caso'],),filas=True)[0][0]==entorno
