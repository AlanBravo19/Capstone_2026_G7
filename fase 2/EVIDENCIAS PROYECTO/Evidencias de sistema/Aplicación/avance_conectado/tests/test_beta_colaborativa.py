"""Pruebas del incremento 0.7 contra PostgreSQL desechable; todos los datos son ficticios."""
import base64, io, time, uuid
from datetime import datetime, timezone
from PIL import Image
from app.routers.seguridad_cuenta import codigo_totp
from test_casos import _reporte
from test_identidad_mvp import cuenta, activar, CLAVE

def caso(client,ciudadano):
 r=client.post('/casos',headers={**ciudadano['headers'],'Idempotency-Key':str(uuid.uuid4())},json=_reporte());assert r.status_code==201,r.text;return r.json()['id_caso']
def publicacion(client,cid,h,op):
 assert client.post(f'/mis-casos/{cid}/colaboracion',headers=h).status_code==200
 assert client.post(f'/gestion/casos/{cid}/revision',headers=op,json={'estado':'en_revision','motivo':'Revisión de datos ficticios para prueba'}).status_code==200
 r=client.post(f'/gestion/casos/{cid}/publicacion',headers=op,json={'zona':'Sector ficticio','texto':'Solicitud ficticia revisada para prueba de colaboración.','motivo':'Publicación autorizada de datos ficticios'});assert r.status_code==201,r.text;return r.json()['id_solicitud_colaboracion']
def foto_payload():
 out=io.BytesIO();Image.new('RGB',(20,20),(30,70,120)).save(out,'PNG');return {'contenido_base64':base64.b64encode(out.getvalue()).decode(),'clave_envio':str(uuid.uuid4())}

def test_rfc6238_vector():
 # Vector oficial RFC6238 SHA1 a 59 segundos, ocho dígitos.
 assert codigo_totp(base64.b32encode(b'12345678901234567890').decode(),59//30,8)=='94287082'

def test_mfa_no_sesion_sin_codigo_no_replay_y_recuperacion(client,db):
 uid,mail,h=cuenta(client)
 r=client.post('/seguridad/totp/preparar',headers=h,json={'clave':CLAVE});assert r.status_code==200,r.text
 secret=r.json()['secreto'];step=int(time.time())//30
 r=client.post('/seguridad/totp/activar',headers=h,json={'codigo':codigo_totp(secret,step-1)});assert r.status_code==200,r.text
 codes=r.json()['codigos_recuperacion'];assert len(codes)==8
 assert client.get('/mi-perfil',headers=h).status_code==401
 stored=db('SELECT secreto_cifrado FROM autenticador_totp WHERE id_usuario=%s',(uid,),filas=True)[0][0];assert secret not in stored
 login=client.post('/sesiones',json={'correo':mail,'clave':CLAVE}).json();assert login['requiere_mfa'] and login['token'] is None
 r=client.post('/sesiones/mfa',json={'id_desafio':login['id_desafio'],'codigo':codigo_totp(secret,step)});assert r.status_code==201,r.text
 assert client.post('/sesiones/mfa',json={'id_desafio':login['id_desafio'],'codigo':codes[0]}).status_code==400
 login2=client.post('/sesiones',json={'correo':mail,'clave':CLAVE}).json()
 assert client.post('/sesiones/mfa',json={'id_desafio':login2['id_desafio'],'codigo':codigo_totp(secret,step)}).status_code==400
 assert client.post('/sesiones/mfa',json={'id_desafio':login2['id_desafio'],'codigo':codes[0]}).status_code==201
 login3=client.post('/sesiones',json={'correo':mail,'clave':CLAVE}).json()
 assert client.post('/sesiones/mfa',json={'id_desafio':login3['id_desafio'],'codigo':codes[0]}).status_code==400

def test_mfa_agota_y_desafio_no_transferible(client,db):
 uid,mail,h=cuenta(client)
 secret=client.post('/seguridad/totp/preparar',headers=h,json={'clave':CLAVE}).json()['secreto']
 client.post('/seguridad/totp/activar',headers=h,json={'codigo':codigo_totp(secret,int(time.time())//30-1)})
 login=client.post('/sesiones',json={'correo':mail,'clave':CLAVE}).json()
 for _ in range(5):assert client.post('/sesiones/mfa',json={'id_desafio':login['id_desafio'],'codigo':'incorrecto'}).status_code==400
 assert db('SELECT intentos FROM desafio_mfa WHERE id_desafio=%s',(login['id_desafio'],),filas=True)[0][0]==5
 assert client.post('/sesiones/mfa',json={'id_desafio':login['id_desafio'],'codigo':codigo_totp(secret,int(time.time())//30)}).status_code==400

def test_publicacion_consentimiento_ambito_y_campos_minimos(client,ciudadano,supervisor_org1,operador_org2):
 cid=caso(client,ciudadano);payload={'zona':'Sector ficticio','texto':'Texto ficticio para revisión y publicación.','motivo':'Motivo ficticio de autorización'}
 assert client.post(f'/gestion/casos/{cid}/publicacion',headers=supervisor_org1,json=payload).status_code==409
 assert client.post(f'/gestion/casos/{cid}/publicacion',headers=operador_org2,json=payload).status_code==403
 sid=publicacion(client,cid,ciudadano['headers'],supervisor_org1)
 assert client.post(f'/gestion/casos/{cid}/publicacion',headers=supervisor_org1,json=payload).status_code==409
 data=client.get('/colaboracion?lat=-36.82&lon=-73.05',headers=ciudadano['headers']).json()
 row=next(r for r in data['cercanos']+data['otras_zonas'] if r['id_solicitud_colaboracion']==sid)
 for private in ['latitud','longitud','id_usuario_reportante','descripcion_privada','direccion_privada']:assert private not in row
 assert row['distancia_km'] is not None

def test_aporte_reintento_revision_y_notificacion(client,ciudadano,supervisor_org1,operador_org2):
 cid=caso(client,ciudadano);sid=publicacion(client,cid,ciudadano['headers'],supervisor_org1)
 _,_,h,_=activar(client)
 body={'observado_en':datetime.now(timezone.utc).isoformat(),'zona':'Zona ficticia','descripcion':'Avistamiento totalmente ficticio de prueba','latitud':-36.82,'longitud':-73.05}
 head={**h,'Idempotency-Key':str(uuid.uuid4())}
 r=client.post(f'/colaboracion/{sid}/avistamientos',headers=head,json=body);assert r.status_code==201,r.text;aid=r.json()['id_avistamiento']
 assert client.post(f'/colaboracion/{sid}/avistamientos',headers=head,json=body).status_code==200
 assert not client.get(f'/seguimiento/{cid}',headers=ciudadano['headers']).json()['aportes']
 rev={'decision':'aceptado','motivo':'Antecedente contrastado en prueba ficticia','resumen':'Aporte ficticio revisado por el operador.'}
 assert client.post(f'/gestion/aportes/{aid}/revision',headers=operador_org2,json=rev).status_code==403
 assert client.post(f'/gestion/aportes/{aid}/revision',headers=supervisor_org1,json=rev).status_code==200
 assert client.get(f'/seguimiento/{cid}',headers=ciudadano['headers']).json()['aportes'][0]['id_avistamiento']==aid
 notes=client.get('/notificaciones',headers=ciudadano['headers']).json();assert any(n['titulo']=='Nuevo antecedente revisado' for n in notes)


def test_fotos_privadas_saneadas_idempotentes_y_revision(client,ciudadano,supervisor_org1,operador_org2):
 cid=caso(client,ciudadano);payload=foto_payload()
 r=client.post(f'/casos/{cid}/fotos',headers=ciudadano['headers'],json=payload);assert r.status_code==201,r.text;eid=r.json()['id_evidencia']
 assert client.post(f'/casos/{cid}/fotos',headers=ciudadano['headers'],json=payload).status_code==200
 assert client.get(f'/evidencias/{eid}/foto',headers=operador_org2).status_code==403
 r=client.get(f'/evidencias/{eid}/foto',headers=ciudadano['headers']);assert r.status_code==200
 with Image.open(io.BytesIO(r.content)) as im:assert im.format=='JPEG' and not im.getexif()
 assert client.post(f'/gestion/evidencias/{eid}/revision',headers=supervisor_org1,json={'decision':'aceptada','motivo':'Foto ficticia evaluada en prueba'}).status_code==204
 assert client.post(f'/casos/{cid}/fotos',headers=ciudadano['headers'],json={'contenido_base64':base64.b64encode(b'NO ES FOTO'*20).decode(),'clave_envio':str(uuid.uuid4())}).status_code==422

def test_confianza_revocacion_y_sin_fotos(client,ciudadano,supervisor_org1):
 cid=caso(client,ciudadano);uid,mail,h,_=activar(client)
 eid=client.post(f'/casos/{cid}/fotos',headers=ciudadano['headers'],json=foto_payload()).json()['id_evidencia']
 assert client.get(f'/seguimiento/{cid}',headers=h).status_code==403
 r=client.post(f'/mis-casos/{cid}/confianza',headers=ciudadano['headers'],json={'correo':mail,'dias':1});assert r.status_code==201,r.text;aid=r.json()['id_acceso_confianza']
 data=client.get(f'/seguimiento/{cid}',headers=h).json();assert 'evidencias' not in data and 'aportes' not in data and 'descripcion_privada' not in data
 assert client.get(f'/evidencias/{eid}/foto',headers=h).status_code==403
 assert client.post(f'/mis-casos/{cid}/confianza/{aid}/revocar',headers=h).status_code==403
 assert client.post(f'/mis-casos/{cid}/confianza/{aid}/revocar',headers=ciudadano['headers']).status_code==204
 assert client.get(f'/seguimiento/{cid}',headers=h).status_code==403

def test_cierre_retira_y_recuperacion_requiere_evidencia(client,ciudadano,supervisor_org1):
 cid=caso(client,ciudadano);sid=publicacion(client,cid,ciudadano['headers'],supervisor_org1)
 close={'motivo_cierre':'recuperado','motivo':'Vehículo ficticio recuperado en prueba'}
 assert client.post(f'/gestion/casos/{cid}/cerrar',headers=supervisor_org1,json=close).status_code==422
 eid=client.post(f'/casos/{cid}/fotos',headers=ciudadano['headers'],json=foto_payload()).json()['id_evidencia']
 client.post(f'/gestion/evidencias/{eid}/revision',headers=supervisor_org1,json={'decision':'aceptada','motivo':'Evidencia de recuperación ficticia revisada'})
 assert client.post(f'/gestion/casos/{cid}/cerrar',headers=supervisor_org1,json={**close,'id_evidencia':eid}).status_code==204
 data=client.get('/colaboracion',headers=ciudadano['headers']).json();assert all(r['id_solicitud_colaboracion']!=sid for r in data['cercanos']+data['otras_zonas'])
 assert client.get(f'/seguimiento/{cid}',headers=ciudadano['headers']).json()['estado']=='cerrado'

def test_cerrar_otras_sesiones_y_clave_actual(client):
 uid,mail,h=cuenta(client)
 other={'Authorization':'Bearer '+client.post('/sesiones',json={'correo':mail,'clave':CLAVE}).json()['token']}
 assert len(client.get('/seguridad/sesiones',headers=h).json())==2
 assert client.post('/seguridad/sesiones/cerrar-otras',headers=h).status_code==204
 assert client.get('/mi-perfil',headers=other).status_code==401
 assert client.post('/seguridad/clave',headers=h,json={'clave':'incorrecta','nueva_clave':'Clave-nueva-prueba-2026'}).status_code==403
 assert client.post('/seguridad/clave',headers=h,json={'clave':CLAVE,'nueva_clave':'Clave-nueva-prueba-2026'}).status_code==204
 assert client.get('/mi-perfil',headers=h).status_code==401


def test_fuentes_reales_no_mezclan_datos_de_prueba_y_camaras_privadas(client,ciudadano,supervisor_org1):
 assert client.get('/territorio/antecedentes',headers=ciudadano['headers']).json()['registros']==[]
 assert client.get('/gestion/camaras',headers=ciudadano['headers']).status_code==403
 r=client.get('/gestion/camaras',headers=supervisor_org1);assert r.status_code==200,r.text
 for c in r.json()['camaras']:assert 'referencia_secreto' not in c
 cid=caso(client,ciudadano)
 r=client.get(f'/gestion/casos/{cid}/resumen',headers=supervisor_org1);assert r.status_code==200
 assert r.json()['hechos'][0]['fuente']==f'caso:{cid}'
 assert client.get(f'/gestion/casos/{cid}/resumen',headers=ciudadano['headers']).status_code==403
