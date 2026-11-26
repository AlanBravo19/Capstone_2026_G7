"""Movilidad y confianza territorial: pruebas con datos controlados."""
from datetime import datetime,timezone,timedelta
import uuid,json
import httpx
from app.routers import movilidad
from app import correo
from app.routers.seguridad_cuenta import codigo_totp
from test_identidad_mvp import cuenta,CLAVE
import time

def ficha():
 return {'id_organizacion':1,'url_fuente':'https://example.invalid/noticia/'+uuid.uuid4().hex,'nombre_fuente':'Fuente ficticia','titulo':'Antecedente ficticio para ensayos','resumen':'Resumen sintético de prueba, no corresponde a un delito real.','tipo':'portonazo','fecha_publicacion':datetime.now(timezone.utc).date().isoformat(),'zona':'Sector ficticio'}

def test_lugares_privados_actualizacion_y_retiro_limpia_coordenadas(client,ciudadano,db):
 h=ciudadano['headers'];d={'nombre':'Casa ficticia','direccion':'Dirección de ensayo, no real','latitud':-36.82,'longitud':-73.05}
 assert client.put('/lugares/casa',headers=h,json=d).status_code==200
 assert client.put('/lugares/casa',headers=h,json={**d,'nombre':'Otro nombre'}).status_code==200
 rows=client.get('/lugares',headers=h).json();assert len(rows)==1 and rows[0]['nombre']=='Otro nombre'
 _,_,other=cuenta(client);assert client.get('/lugares',headers=other).json()==[]
 assert client.post('/lugares/casa/retirar',headers=other).status_code==204
 assert len(client.get('/lugares',headers=h).json())==1
 assert client.post('/lugares/casa/retirar',headers=h).status_code==204
 assert client.get('/lugares',headers=h).json()==[]
 assert db('SELECT ubicacion,direccion FROM lugar_guardado WHERE id_usuario=%s',(ciudadano['id'],),filas=True)[0]==(None,'')

def test_fuente_no_alerta_sin_revision_y_no_otro_ambito(client,ciudadano,supervisor_org1,operador_org2):
 payload=ficha();r=client.post('/gestion/antecedentes',headers=supervisor_org1,json=payload);assert r.status_code==201,r.text;aid=r.json()['id_antecedente']
 assert client.post('/gestion/antecedentes',headers=ciudadano['headers'],json=ficha()).status_code==403
 assert client.post('/gestion/antecedentes',headers=supervisor_org1,json=payload).status_code==409
 data=client.get('/territorio/avisos?lat=-36.82&lon=-73.05',headers=ciudadano['headers']).json();assert all(n['id_antecedente']!=aid for n in data['avisos'])
 rev={'decision':'validado','latitud':-36.82,'longitud':-73.05,'precision_m':1000,'radio_m':1500,'motivo':'Revisión ficticia de fuente, sector y duplicados.'}
 assert client.post(f'/gestion/antecedentes/{aid}/revision',headers=operador_org2,json=rev).status_code==403
 assert client.post(f'/gestion/antecedentes/{aid}/revision',headers=supervisor_org1,json={**rev,'radio_m':500}).status_code==422
 assert client.post(f'/gestion/antecedentes/{aid}/revision',headers=supervisor_org1,json=rev).status_code==204
 found=client.get('/territorio/avisos?lat=-36.82&lon=-73.05',headers=ciudadano['headers']).json()['avisos'];assert any(n['id_antecedente']==aid for n in found)
 assert client.post(f'/gestion/antecedentes/{aid}/revision',headers=supervisor_org1,json={'decision':'descartado','motivo':'Retiro del aviso sintético por prueba de estado'}).status_code==204
 found=client.get('/territorio/avisos?lat=-36.82&lon=-73.05',headers=ciudadano['headers']).json()['avisos'];assert all(n['id_antecedente']!=aid for n in found)

def test_avisos_excluyen_vencidos_y_prueba(client,ciudadano,supervisor_org1,db):
 aid=client.post('/gestion/antecedentes',headers=supervisor_org1,json=ficha()).json()['id_antecedente']
 rev={'decision':'validado','latitud':-36.82,'longitud':-73.05,'motivo':'Ensayo sintético de vigencia y entorno de prueba.'}
 client.post(f'/gestion/antecedentes/{aid}/revision',headers=supervisor_org1,json=rev)
 db("UPDATE antecedente_publico SET entorno='prueba' WHERE id_antecedente=%s",(aid,))
 found=client.get('/territorio/avisos?lat=-36.82&lon=-73.05',headers=ciudadano['headers']).json()['avisos'];assert all(n['id_antecedente']!=aid for n in found)
 db("UPDATE antecedente_publico SET entorno='operacion',vence_en=CURRENT_TIMESTAMP-interval '1 minute' WHERE id_antecedente=%s",(aid,))
 found=client.get('/territorio/avisos?lat=-36.82&lon=-73.05',headers=ciudadano['headers']).json()['avisos'];assert all(n['id_antecedente']!=aid for n in found)

def test_ruta_consentimiento_y_respuesta_realista_controlada(client,ciudadano,monkeypatch):
 request={'origen':{'latitud':-36.82,'longitud':-73.05},'destino':{'latitud':-36.84,'longitud':-73.08},'consentimiento_proveedor':False}
 assert client.post('/rutas/calcular',headers=ciudadano['headers'],json=request).status_code==422
 real_client=httpx.Client
 def respond(req):
  assert req.url.host=='router.project-osrm.org'
  return httpx.Response(200,json={'code':'Ok','routes':[{'distance':4200,'duration':600,'geometry':{'type':'LineString','coordinates':[[-73.05,-36.82],[-73.08,-36.84]]}}]})
 monkeypatch.setattr(movilidad.httpx,'Client',lambda **kw:real_client(transport=httpx.MockTransport(respond),**kw))
 r=client.post('/rutas/calcular',headers=ciudadano['headers'],json={**request,'consentimiento_proveedor':True});assert r.status_code==200,r.text
 assert r.json()['rutas'][0]['distancia_m']==4200

def test_ruta_error_no_inventa_trazado(client,ciudadano,monkeypatch):
 real_client=httpx.Client
 monkeypatch.setattr(movilidad.httpx,'Client',lambda **kw:real_client(transport=httpx.MockTransport(lambda req:httpx.Response(200,json={'code':'NoRoute'})),**kw))
 body={'origen':{'latitud':-36.82,'longitud':-73.05},'destino':{'latitud':-36.84,'longitud':-73.08},'consentimiento_proveedor':True}
 r=client.post('/rutas/calcular',headers=ciudadano['headers'],json=body);assert r.status_code==503
 assert 'rutas' not in r.json()


def test_zonas_agregadas_y_rutas_con_menos_cruces(client, ciudadano, supervisor_org1, db, monkeypatch):
 ids = []
 rev = {'decision':'validado','latitud':-39.82,'longitud':-73.05,'precision_m':300,
        'radio_m':800,'motivo':'Ubicación y fuente ficticias revisadas para la prueba.'}
 for tipo in ('encerrona','portonazo','encerrona'):
  r = client.post('/gestion/antecedentes', headers=supervisor_org1, json={**ficha(),'tipo':tipo})
  assert r.status_code == 201, r.text
  ids.append(r.json()['id_antecedente'])
 for aid in ids[:2]:
  assert client.post(f'/gestion/antecedentes/{aid}/revision', headers=supervisor_org1, json=rev).status_code == 204
 h = ciudadano['headers']
 try:
  data = client.get('/territorio/zonas?lat=-39.82&lon=-73.05', headers=h).json()
  assert len(data['zonas']) == 1 and not data['simulacion']
  assert data['zonas'][0]['antecedentes'] == 2 and data['zonas'][0]['radio_m'] == 800
  assert data['zonas'][0]['geometria']['type'] == 'Polygon'
  zona = data['zonas'][0]
  assert zona['nivel'] == 'moderada' and zona['encerronas'] == 1
  ubicacion = {'latitud':-39.82,'longitud':-73.05}
  descarga = client.post('/territorio/avisos/descargar',headers=h,json=ubicacion)
  assert descarga.status_code == 200, descarga.text
  assert descarga.json()['zonas'] == [{k:v for k,v in zona.items() if k != 'geometria'}]
  assert datetime.fromisoformat(descarga.json()['cache_hasta']) < datetime.fromisoformat(zona['vigente_hasta'])
  real_client = httpx.Client
  def responder(_):
   def ruta(pts, segundos):
    return {'distance':4200,'duration':segundos,'geometry':{'type':'LineString','coordinates':pts}}
   return httpx.Response(200, json={'code':'Ok','routes':[
       ruta([[-73.07,-39.82],[-73.03,-39.82]],360),
       ruta([[-73.07,-39.82],[-73.06,-39.84],[-73.04,-39.84],[-73.03,-39.82]],480),
   ]})
  monkeypatch.setattr(movilidad.httpx,'Client',lambda **kw:real_client(transport=httpx.MockTransport(responder),**kw))
  body = {'origen':{'latitud':-39.82,'longitud':-73.07},'destino':{'latitud':-39.82,'longitud':-73.03},'consentimiento_proveedor':True}
  r = client.post('/rutas/calcular', headers=h, json=body)
  assert r.status_code == 200, r.text
  assert [r['cruces_zonas'] for r in r.json()['rutas']] == [0, 1]
  r = client.post('/rutas/calcular', headers=h, json={**body,'evitar_zonas':False})
  assert [r['cruces_zonas'] for r in r.json()['rutas']] == [1, 0]
  db("UPDATE antecedente_publico SET entorno='prueba' WHERE id_antecedente=%s", (ids[0],))
  assert client.get('/territorio/zonas?lat=-39.82&lon=-73.05', headers=h).json()['zonas'][0]['antecedentes'] == 1
  assert client.post('/territorio/avisos/descargar',headers=h,json=ubicacion).json()['zonas'][0]['encerronas'] == 0
  # Un tercer y cuarto registro aprobado eleva el nivel de la misma zona.
  r = client.post('/gestion/antecedentes', headers=supervisor_org1, json=ficha())
  assert r.status_code == 201, r.text
  ids.append(r.json()['id_antecedente'])
  for aid in ids[2:]:
   assert client.post(f'/gestion/antecedentes/{aid}/revision', headers=supervisor_org1, json=rev).status_code == 204
  db("UPDATE antecedente_publico SET entorno='operacion' WHERE id_antecedente=%s", (ids[0],))
  alta = client.post('/territorio/avisos/descargar',headers=h,json=ubicacion).json()['zonas'][0]
  assert (alta['id_zona'],alta['nivel'],alta['antecedentes'],alta['encerronas']) == (zona['id_zona'],'alta',4,2)
 finally:
  db("UPDATE antecedente_publico SET estado='descartado' WHERE id_antecedente=ANY(%s::uuid[])", (ids,))

def test_participacion_real_no_acepta_contactos_simulados(client,ciudadano,db,monkeypatch):
 # Correo real + TOTP evita depender de SMS y no reetiqueta contactos de prueba.
 monkeypatch.setenv('CORREO_TRANSPORTE','smtp')
 h=ciudadano['headers'];uid=ciudadano['id']
 r=client.get('/identidad/mi-estado',headers=h);assert not r.json()['correo_verificado'] and not r.json()['puede_participar']
 assert client.post('/vehiculos',headers=h,json={'marca':'Ensayo','modelo':'Ficticio','patente':uuid.uuid4().hex[:10],'color':'azul','anio':2020}).status_code==403
 db("UPDATE usuario SET canal_correo_verificado='smtp' WHERE id_usuario=%s",(uid,))
 assert not client.get('/identidad/mi-estado',headers=h).json()['puede_participar']
 # Fixture ciudadano utiliza otra clave; no simular una confirmación SMTP.
 from conftest import CLAVE as citizen_password
 secret=client.post('/seguridad/totp/preparar',headers=h,json={'clave':citizen_password}).json()['secreto']
 r=client.post('/seguridad/totp/activar',headers=h,json={'codigo':codigo_totp(secret,int(time.time())//30-1)});assert r.status_code==200,r.text
 recovery=r.json()['codigos_recuperacion'][0];login=client.post('/sesiones',json={'correo':ciudadano['correo'],'clave':citizen_password}).json()
 token=client.post('/sesiones/mfa',json={'id_desafio':login['id_desafio'],'codigo':recovery}).json()['token']
 assert client.get('/identidad/mi-estado',headers={'Authorization':'Bearer '+token}).json()['puede_participar']
