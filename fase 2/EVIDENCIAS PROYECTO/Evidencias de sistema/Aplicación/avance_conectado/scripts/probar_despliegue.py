"""Prueba HTTP pública del despliegue autorizado, sin registrar claves ni tokens."""
from config_local import BASE
import httpx
import json
import sys
import uuid
from datetime import datetime,timezone
from urllib.parse import urlparse

url=sys.argv[1].rstrip('/')
if urlparse(url).scheme!='https' or not urlparse(url).hostname.endswith('.vercel.app'):
    raise SystemExit('Indica la URL HTTPS vercel.app del despliegue verificado.')
v=dict(l.split('=',1) for l in (BASE/'.env.runtime.local').read_text(encoding='utf-8').splitlines() if '=' in l and not l.startswith('#'))
c=httpx.Client(base_url=url,headers={'X-Demo-Access':v['DEMO_ACCESS_KEY']},timeout=40)
res=[]
def paso(nombre,metodo,ruta,codigo,**kwargs):
    r=c.request(metodo,ruta,**kwargs)
    res.append({'paso':nombre,'ruta':ruta,'esperado':codigo,'obtenido':r.status_code,'correcto':r.status_code==codigo})
    if r.status_code!=codigo:raise RuntimeError(f'{nombre}: HTTP {r.status_code}')
    if r.status_code==204:return None
    return r.json() if 'application/json' in r.headers.get('content-type','') else r.text

try:
    paso('Página disponible','GET','/',200)
    health=paso('Conexión Supabase','GET','/health',200)
    assert health['tablas']==59
    clave=uuid.uuid4().hex+'-DEMO';correo='web-'+uuid.uuid4().hex[:10]+'@example.invalid'
    paso('Crear cuenta ficticia','POST','/cuentas',201,json={'nombre_visible':'Ensayo web ficticio','correo':correo,'clave':clave})
    token=paso('Ingresar','POST','/sesiones',201,json={'correo':correo,'clave':clave})['token']
    c.headers['Authorization']='Bearer '+token
    t=paso('Solicitar token simulado','POST','/identidad/correo/solicitar',202)['token_demo']
    paso('Verificar correo','POST','/identidad/correo/confirmar',200,json={'token':t})
    d=paso('Solicitar OTP simulado','POST','/identidad/telefono/solicitar',202,json={'telefono':'+569'+str(uuid.uuid4().int%100000000).zfill(8)})
    paso('Verificar teléfono','POST','/identidad/telefono/confirmar',200,json={'id_desafio':d['id_desafio'],'codigo':d['codigo_demo']})
    veh=paso('Persistir vehículo','POST','/vehiculos',201,json={'marca':'MARCA FICTICIA','modelo':'ENSAYO','patente':'W'+uuid.uuid4().hex[:7],'color':'gris','anio':2020})
    paso('Consultar vehículo','GET','/vehiculos',200)
    datos={'id_vehiculo':veh['id_vehiculo'],'id_organizacion':1,'fecha_hecho':datetime.now(timezone.utc).isoformat(),'zona':'Zona ficticia de demostración','descripcion':'Prueba controlada sin robo real','latitud':-36.82,'longitud':-73.05}
    h={'Idempotency-Key':str(uuid.uuid4())}
    caso=paso('Persistir caso','POST','/casos',201,json=datos,headers=h)
    repetir=paso('Reintentar sin duplicar','POST','/casos',200,json=datos,headers=h)
    assert caso['id_caso']==repetir['id_caso']
    casos=paso('Consultar casos guardados','GET','/mis-casos',200)
    guardado=next(x for x in casos if x['id_caso']==caso['id_caso'])
    if '--mapa' in sys.argv:
        correcto=abs(guardado['latitud']-datos['latitud'])<0.000001 and abs(guardado['longitud']-datos['longitud'])<0.000001
        res.append({'paso':'Coordenadas PostGIS del caso propio','ruta':'/mis-casos','correcto':correcto,'obtenido':200 if correcto else 500})
        assert correcto

    paso('Cerrar sesión','POST','/sesiones/cerrar',204)
    paso('Rechazar sesión revocada','GET','/mi-perfil',401)
finally:
    c.close()
    p=BASE/'evidencias';p.mkdir(exist_ok=True)
    (p/('prueba_http_mapa.json' if '--mapa' in sys.argv else 'prueba_http_vercel.json')).write_text(json.dumps({'fecha_utc':datetime.now(timezone.utc).isoformat(),'url':url,'nota':'Datos ficticios; correo y SMS simulados. Ejecución HTTP real contra Vercel y Supabase.','resultados':res},ensure_ascii=False,indent=2),encoding='utf-8')
    for r in res:print(r['obtenido'],r['paso'])
