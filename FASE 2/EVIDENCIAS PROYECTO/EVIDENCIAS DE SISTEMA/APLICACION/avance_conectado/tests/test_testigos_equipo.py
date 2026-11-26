from datetime import datetime,timezone
from uuid import uuid4
from test_identidad_mvp import activar
from test_casos import _reporte

def prueba_aviso(oid=1):
    return {'id_organizacion':oid,'perspectiva':'pasajero','observado_en':datetime.now(timezone.utc).isoformat(),
            'zona':'Sector ficticio','descripcion':'Aviso de pasajero en un entorno de prueba.'}

def test_pasajero_sin_vehiculo_y_revision_privada(client,supervisor_org1,operador_org2,ciudadano):
    _,_,h,_=activar(client)
    assert client.get('/vehiculos',headers=h).json()==[]
    original=client.get('/mi-perfil',headers=h).json()
    assert original['modalidad_ciudadana']=='colaborador'
    assert client.put('/mi-perfil/modalidad',headers=h,json={'modalidad_ciudadana':'con_vehiculo'}).status_code==204
    perfil=client.get('/mi-perfil',headers=h).json()
    assert perfil['modalidad_ciudadana']=='con_vehiculo' and perfil['roles']==original['roles'] and not perfil['organizaciones']
    cab={**h,'Idempotency-Key':str(uuid4())};body=prueba_aviso()
    r=client.post('/avisos-testigo',headers=cab,json=body)
    assert r.status_code==201,r.text
    aid=r.json()['id_aviso'];retry=client.post('/avisos-testigo',headers=cab,json=body)
    assert retry.status_code==200 and retry.json()==r.json()
    assert client.post('/avisos-testigo',headers=cab,json={**body,'zona':'Otro sector'}).status_code==409
    assert client.get('/mis-casos',headers=h).json()==[] and client.get('/vehiculos',headers=h).json()==[]
    assert not any(a['id_aviso']==aid for a in client.get('/gestion/testigos',headers=operador_org2).json())
    assert client.get('/gestion/testigos',headers=h).status_code==403
    path=f'/gestion/testigos/{aid}/revision'
    decision={'decision':'asociado','motivo':'Coincidencia revisada en caso ficticio','id_caso':2}
    assert client.post(path,headers=operador_org2,json=decision).status_code==403
    assert client.post(path,headers=supervisor_org1,json=decision).status_code==403
    cid=client.post('/casos',headers={**ciudadano['headers'],'Idempotency-Key':str(uuid4())},json=_reporte()).json()['id_caso']
    assert client.post(path,headers=supervisor_org1,json={**decision,'id_caso':cid}).status_code==204
    assert client.post(path,headers=supervisor_org1,json={**decision,'id_caso':cid}).status_code==409
    row=client.get('/mis-avisos-testigo',headers=h).json()[0]
    assert row['estado']=='asociado' and 'id_caso' not in row
    assert client.get(f'/seguimiento/{cid}',headers=h).status_code==403
    assert client.post(f'/mis-casos/{cid}/colaboracion',headers=h).status_code==403
    assert client.get('/mis-avisos-testigo',headers=ciudadano['headers']).json()==[]

def test_asignar_responsable_y_registrar_derivacion(client,supervisor_org1,operador_org2,ciudadano):
    cid=client.post('/casos',headers={**ciudadano['headers'],'Idempotency-Key':str(uuid4())},json=_reporte()).json()['id_caso']
    base=f'/gestion/casos/{cid}'
    equipo=client.get(base+'/equipo',headers=supervisor_org1).json()
    member=equipo['opciones'][0]['id_membresia']
    payload={'id_membresia':member,'motivo':'Asignación de prueba supervisada'}
    assert client.post(base+'/asignacion',headers=operador_org2,json=payload).status_code==403
    assert client.post(base+'/asignacion',headers=supervisor_org1,json=payload).status_code==204
    assert client.post(base+'/gestiones',headers=supervisor_org1,json={'accion':'derivacion','descripcion':'Derivación ficticia para comprobar trazabilidad'}).status_code==204
    actual=client.get(base+'/equipo',headers=supervisor_org1).json()
    assert actual['responsable'] and actual['gestiones'][0]['accion']=='derivacion'
    assert client.get(base+'/equipo',headers=ciudadano['headers']).status_code==403

def test_renovar_solo_solicitud_vigente_y_propia(client,db,supervisor_org1,operador_org2,ciudadano):
    from test_beta_colaborativa import caso,publicacion
    cid=caso(client,ciudadano)
    sid=publicacion(client,cid,ciudadano['headers'],supervisor_org1)
    # Solicitudes anteriores conservan el plazo acordado.
    db("UPDATE solicitud_colaboracion SET vence_en=inicio+interval '24 hours' WHERE id_solicitud_colaboracion=%s",(sid,))
    path=f'/gestion/casos/{cid}/renovacion'
    payload={'motivo':'Revisión de vigencia de ensayo','horas':48,'id_solicitud_colaboracion':sid}
    assert client.post(path,headers=operador_org2,json=payload).status_code==403
    assert client.post(path,headers=supervisor_org1,json=payload).status_code==204
    assert client.post(path,headers=supervisor_org1,json={**payload,'horas':1}).status_code==409
    assert client.post(f'/gestion/casos/{cid}/retirar',headers=supervisor_org1,json={'motivo':'Retiro ficticio de ensayo'}).status_code==204
    assert client.post(path,headers=supervisor_org1,json=payload).status_code==409

