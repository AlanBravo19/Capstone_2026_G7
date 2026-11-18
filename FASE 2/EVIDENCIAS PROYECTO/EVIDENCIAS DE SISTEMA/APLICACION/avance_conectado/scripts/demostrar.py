"""Demostración reproducible por API en proceso; sólo datos ficticios, sin interfaz gráfica."""
import json
import os
from pathlib import Path
import secrets
import sys
import uuid
from datetime import datetime, timezone

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
if os.getenv('ENTORNO')!='prueba' or os.getenv('CANALES_DEMO')!='1':
    raise SystemExit('Usa la configuración local de demostración descrita en el README.')
from fastapi.testclient import TestClient
from app.main import app
from app.db import conectar
from app.seguridad import cifrar_clave

client=TestClient(app)
resultados=[]
def llamar(paso,metodo,ruta,esperado,**kwargs):
    r=client.request(metodo,ruta,**kwargs)
    resultados.append({'paso':paso,'metodo':metodo,'ruta':ruta,'esperado':esperado,'obtenido':r.status_code,'correcto':r.status_code==esperado})
    if r.status_code!=esperado:raise RuntimeError(f'{paso}: {r.status_code} {r.text}')
    return r

def registrar(mail,clave):
    r=llamar('Registro','POST','/cuentas',201,json={'nombre_visible':'Persona ficticia de ensayo','correo':mail,'clave':clave})
    uid=r.json()['id_usuario']
    token=llamar('Ingreso','POST','/sesiones',201,json={'correo':mail,'clave':clave}).json()['token']
    return uid,{'Authorization':'Bearer '+token}

def verificar_correo(h):
    token=llamar('Solicitar correo simulado','POST','/identidad/correo/solicitar',202,headers=h).json()['token_demo']
    llamar('Confirmar correo','POST','/identidad/correo/confirmar',200,json={'token':token})

def telefono(h,n,esperado=200):
    ch=llamar('Solicitar SMS simulado','POST','/identidad/telefono/solicitar',202,headers=h,json={'telefono':n}).json()
    llamar('Asociar teléfono' if esperado==200 else 'Rechazar teléfono duplicado','POST','/identidad/telefono/confirmar',esperado,headers=h,json={'id_desafio':ch['id_desafio'],'codigo':ch['codigo_demo']})

try:
    llamar('Conexión SQL/PostGIS','GET','/health',200)
    clave=secrets.token_urlsafe(20);mail='demo-'+uuid.uuid4().hex[:10]+'@example.invalid'
    uid,h=registrar(mail,clave)
    llamar('Rechazar correo duplicado','POST','/cuentas',409,json={'nombre_visible':'Intento duplicado','correo':mail.upper(),'clave':clave})
    verificar_correo(h);n='+569'+str(uuid.uuid4().int%100000000).zfill(8);telefono(h,n)
    llamar('Consultar permisos','GET','/identidad/mi-estado',200,headers=h)
    conn=conectar()
    try:
        cur=conn.cursor()
        # Sólo habilita credencial de la cuenta ficticia ya sembrada; no crea roles por API.
        cur.execute("SELECT 1 FROM usuario WHERE id_usuario=2 AND correo_normalizado='operador@example.invalid'")
        if cur.fetchone() is None:raise RuntimeError('Faltan los datos ficticios originales')
        adminclave=secrets.token_urlsafe(24)
        cur.execute('UPDATE usuario SET password_hash=%s WHERE id_usuario=2',(cifrar_clave(adminclave),))
        cur.execute("INSERT INTO vinculo_vehiculo(id_usuario,id_vehiculo,tipo) VALUES(%s,1,'propietario')",(uid,))
        conn.commit()
    finally:conn.close()
    caso={'id_vehiculo':1,'id_organizacion':1,'fecha_hecho':datetime.now(timezone.utc).isoformat(),
          'zona':'Zona ficticia de ensayo','descripcion':'Demostración sin robo real','latitud':-36.82,'longitud':-73.05}
    headers={**h,'Idempotency-Key':str(uuid.uuid4())}
    llamar('Guardar caso en SQL','POST','/casos',201,headers=headers,json=caso)
    llamar('Reintentar sin duplicar caso','POST','/casos',200,headers=headers,json=caso)
    at=llamar('Ingreso administrador ficticio','POST','/sesiones',201,json={'correo':'operador@example.invalid','clave':adminclave}).json()['token']
    llamar('Sancionar y revocar sesiones','POST',f'/moderacion/usuarios/{uid}/sanciones',201,headers={'Authorization':'Bearer '+at},json={'accion':'bloqueo','motivo':'Abuso ficticio para demostrar una sanción'})
    llamar('Rechazar sesión revocada','GET','/identidad/mi-estado',401,headers=h)
    llamar('Rechazar ingreso suspendido','POST','/sesiones',401,json={'correo':mail,'clave':clave})
    _,h2=registrar('demo-'+uuid.uuid4().hex[:10]+'@example.invalid',clave)
    verificar_correo(h2);telefono(h2,n,409)
finally:
    destino=Path(__file__).resolve().parents[1]/'evidencias/demostracion_api.json'
    destino.parent.mkdir(exist_ok=True)
    destino.write_text(json.dumps({'fecha_utc':datetime.now(timezone.utc).isoformat(),'entorno':'local, FastAPI TestClient, PGlite/PostGIS; códigos simulados','resultados':resultados},ensure_ascii=False,indent=2),encoding='utf-8')
    for item in resultados:print(f'{item["obtenido"]} | {item["paso"]}')
    print('Evidencia:',destino)
