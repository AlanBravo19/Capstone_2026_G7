"""Instancia local descartable. Sólo usa PGlite en memoria y puertos loopback."""
import argparse
import base64
from contextlib import contextmanager
from datetime import datetime, timezone
from hashlib import sha256
from io import BytesIO
import os
import json
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import time
from uuid import uuid4

import httpx
from PIL import Image, ImageDraw, ImageFont

BASE = Path(__file__).resolve().parents[1]

def conectado(puerto):
    with socket.socket() as s:
        s.settimeout(0.3)
        return s.connect_ex(('127.0.0.1', puerto)) == 0

@contextmanager
def proceso(args, env, puerto):
    if conectado(puerto):
        raise RuntimeError(f'El puerto local {puerto} ya está en uso.')
    with subprocess.Popen(args, cwd=BASE, env=env) as hijo:
        try:
            for _ in range(120):
                if hijo.poll() is not None:
                    raise RuntimeError(f'No se inició el servicio del puerto {puerto}.')
                if conectado(puerto):
                    break
                time.sleep(0.25)
            else:
                raise RuntimeError(f'El servicio del puerto {puerto} no inició a tiempo.')
            yield
        finally:
            hijo.terminate()
            hijo.wait(timeout=10)

def enviar(c, ruta, payload, h=None, codigo=200):
    r = c.post(ruta, json=payload, headers=h)
    if r.status_code != codigo:
        raise RuntimeError(f'Paso de ensayo {ruta}: HTTP {r.status_code}, esperado {codigo}.')
    return None if codigo == 204 else r.json()

def ingresar(c, correo, clave, institucional=False):
    ruta = '/institucional/sesiones' if institucional else '/sesiones'
    session = enviar(c, ruta, {'correo':correo,'clave':clave}, codigo=201)
    return {'Authorization': 'Bearer '+session['token']}

def ciudadano(c, nombre, correo, clave, numero):
    enviar(c, '/cuentas', {'nombre_visible':nombre,'correo':correo,'clave':clave}, codigo=201)
    h = ingresar(c, correo, clave)
    correo_demo = enviar(c, '/identidad/correo/solicitar', {}, h, 202)
    enviar(c, '/identidad/correo/confirmar', {'token':correo_demo['token_demo']})
    telefono = enviar(c, '/identidad/telefono/solicitar', {'telefono':numero}, h, 202)
    enviar(c, '/identidad/telefono/confirmar', {
        'id_desafio':telefono['id_desafio'], 'codigo':telefono['codigo_demo']}, h)
    return h

def registrar_auto(c, titular, patente, padron=None):
    r = enviar(c, '/vehiculos', {'marca':'TOYOTA','modelo':'YARIS',
        'patente':patente,'color':'Azul','anio':2020,
        'revision': {'id_organizacion':1,'padron_base64':padron} if padron else None}, titular, 201)
    vid = r['id_vehiculo']
    if not padron:
        enviar(c, f'/vehiculos/{vid}/revision-vinculo', {'id_organizacion':1}, titular, 204)
    return vid

def padron_prueba(patente):
    im = Image.new('RGB',(720,440),'#f5f8fd')
    d = ImageDraw.Draw(im)
    d.multiline_text((32,36), f'RUTAALERTA - PADRÓN FICTICIO\nSin validez documental\n\nPatente: {patente}\nTitular: Persona ficticia de ensayo\nVehículo: TOYOTA YARIS 2020',
                     font=ImageFont.load_default(size=26), fill='#132340', spacing=20)
    salida = BytesIO()
    im.save(salida, format='PNG')
    return base64.b64encode(salida.getvalue()).decode()

def imagen_prueba():
    im = Image.new('RGB',(360,180),'#d7eaff')
    dibujo = ImageDraw.Draw(im)
    dibujo.rounded_rectangle((39,74,322,130),radius=22,fill='#1d4e8d')
    dibujo.polygon([(92,77),(131,36),(240,36),(272,79)],fill='#1d4e8d')
    for x in (91,262):
        dibujo.ellipse((x-18,111,x+18,147),fill='#132340')
    dibujo.text((18,157),'RUTAALERTA - IMAGEN FICTICIA DE ENSAYO',fill='#132340')
    salida = BytesIO()
    im.save(salida,format='PNG')
    return salida.getvalue()


def validar_groq(c, operador, vinculo):
    from app.prelectura_padron import PATENTE_ENSAYO, TIEMPO_GROQ_SEGUNDOS

    ruta = f'/gestion/vinculos/{vinculo}/prelectura'
    lectura = c.post(ruta, headers=operador, json={'archivo_ficticio': True},
                     timeout=TIEMPO_GROQ_SEGUNDOS + 10)
    filas = c.get('/gestion/vinculos', headers=operador).raise_for_status().json()
    fila = next(f for f in filas if f['id_vinculo_vehiculo'] == vinculo)
    if fila['estado'] != 'pendiente':
        raise RuntimeError('La prelectura no debe cambiar el estado de la solicitud.')
    if lectura.status_code != 200:
        detalle = lectura.json().get('detail', '') if lectura.status_code == 503 else ''
        raise RuntimeError(f'Prelectura fallida (HTTP {lectura.status_code}). {detalle}')
    resultado = lectura.json()
    if resultado != {'resultado': 'coincide', 'modo': 'ensayo'}:
        raise RuntimeError(f'GroqCloud respondió con {resultado["resultado"]}. Se esperaba coincidencia.')
    print(f'Respuesta real de GroqCloud: la patente del padrón ficticio coincide ({PATENTE_ENSAYO}).')
    print('Estado comprobado en el panel de operador: pendiente de revisión.')

def validar(c, titular, colaborador, operador, vid, foto):
    payload = {'id_vehiculo':vid,'id_organizacion':1,'zona':'Chillán · Ensayo ficticio',
        'fecha_hecho':datetime.now(timezone.utc).isoformat(),'descripcion':'Sustracción ficticia para ensayo aislado',
        'latitud':-36.61,'longitud':-72.10,'confirmar_sustraccion':True,'solicitar_colaboracion':True,
        'foto_base64':foto,'autorizar_foto_publica':True}
    h={**titular,'Idempotency-Key':str(uuid4())}
    inicio=time.perf_counter()
    caso=enviar(c,'/casos',payload,h,201)
    guardado=(time.perf_counter()-inicio)*1000
    if caso['publicacion']!='provisional':
        raise RuntimeError('El vehículo aprobado no produjo una alerta provisional.')
    cid=caso['id_caso']
    alertas=c.get('/colaboracion',headers=colaborador).raise_for_status().json()
    alerta=next(a for a in alertas['otras_zonas']+alertas['cercanos'] if a['patente']=='ZQXT91')
    visible=(time.perf_counter()-inicio)*1000
    if alerta['modo_alerta']!='provisional' or alerta['foto_disponible']:
        raise RuntimeError('La vista provisional debe reservar la foto hasta su revisión.')
    aporte=enviar(c,f"/colaboracion/{alerta['id_solicitud_colaboracion']}/avistamientos",
        {'zona':'Chillán · ensayo','observado_en':datetime.now(timezone.utc).isoformat(),
         'descripcion':'Avistamiento ficticio con imagen de prueba','latitud':-36.6020,'longitud':-72.0960,'foto_base64':foto},
        {**colaborador,'Idempotency-Key':str(uuid4())},201)
    enviar(c,f"/gestion/aportes/{aporte['id_avistamiento']}/revision",
        {'decision':'aceptado','motivo':'Resultado del ensayo funcional','resumen':'Foto y ubicación revisadas en el ensayo.'},operador)
    for resultado in ('sin_resultado','no_disponible','encontrado'):
        ficha=c.get(f'/seguimiento/{cid}',headers=operador).raise_for_status().json()
        enviar(c,f'/gestion/casos/{cid}/encargo',{'revision':ficha['revision_alerta'],
            'resultado':resultado,'simulada':True,'referencia':'AS-DEMO-001',
            'motivo':'Resultado generado para la demostración aislada.'},operador,204)
    avisos=c.get('/notificaciones',headers=titular).raise_for_status().json()
    if not any(a['id_caso']==cid and a['mensaje'].startswith('Simulación · Encargo encontrado') for a in avisos):
        raise RuntimeError('El titular no recibió el aviso interno de simulación.')
    print(f'Ensayo local: alta {guardado:.1f} ms, consulta visible {visible:.1f} ms desde el envío.')
    print('Comprobados vínculo, provisional, aporte revisado, tres resultados simulados y buzón interno.')

def sembrar_zonas(c, operador, titular):
    fecha = datetime.now(timezone.utc).date().isoformat()
    for i, (lat, lon, sector) in enumerate([
        (-36.829, -73.050, 'Sector ficticio A'), (-36.831, -73.049, 'Sector ficticio A'),
        (-36.829, -73.051, 'Sector ficticio A'), (-36.830, -73.050, 'Sector ficticio A'),
        (-36.810, -73.063, 'Sector ficticio B'), (-36.809, -73.061, 'Sector ficticio B'),
    ], start=1):
        id_ficha = enviar(c, '/gestion/antecedentes', {
            'id_organizacion': 1, 'url_fuente': f'https://example.invalid/ensayo/{i}',
            'nombre_fuente': 'Datos ficticios de RutaAlerta', 'titulo': f'Antecedente ficticio {i}',
            'resumen': 'Registro simulado para mostrar el mapa a los profesores.', 'tipo': 'otro',
            'fecha_publicacion': fecha, 'fecha_hecho': fecha, 'zona': sector,
        }, operador, 201)['id_antecedente']
        enviar(c, f'/gestion/antecedentes/{id_ficha}/revision', {
            'decision': 'validado', 'latitud': lat, 'longitud': lon, 'precision_m': 300,
            'radio_m': 800, 'dias_vigencia': 7, 'motivo': 'Validación de un dato ficticio para la demostración.',
        }, operador, 204)
    for tipo, nombre, lat, lon in [('casa', 'Casa de ensayo', -36.830, -73.058),
                                    ('trabajo', 'Trabajo de ensayo', -36.830, -73.042)]:
        c.put(f'/lugares/{tipo}', headers=titular, json={
            'nombre':nombre, 'latitud':lat, 'longitud':lon,
        }).raise_for_status()


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--puerto-api',type=int,default=5580)
    p.add_argument('--puerto-bd',type=int,default=55529)
    p.add_argument('--servidor-pglite',type=Path,default=BASE/'scripts/servidor_prueba_pglite.mjs')
    p.add_argument('--validar',action='store_true',help='Ejecuta el recorrido y termina.')
    p.add_argument('--validar-groq',action='store_true',help='Prueba GroqCloud con el padrón ficticio y termina.')
    p.add_argument('--guion-web',type=Path,help='Ejecuta un guion Node local con las cuentas efímeras vía entrada estándar.')
    args=p.parse_args()
    if args.validar_groq and not os.getenv('GROQ_API_KEY'):
        p.error('Configura la clave de GroqCloud para ejecutar la prueba.')
    env={k:v for k,v in os.environ.items() if k not in {'VERCEL','VERCEL_ENV'}}
    env.update(DB_HOST='127.0.0.1',DB_PORT=str(args.puerto_bd),DB_NAME='postgres',DB_USER='postgres',
        DB_PASSWORD='',DB_SSL='0',ENTORNO='prueba',CANALES_DEMO='1',CORREO_TRANSPORTE='demo',
        DEMO_ACCESS_KEY='',OTP_SECRET=secrets.token_urlsafe(48),ALERTAS_AUTOMATICAS='1',
        ALERTA_MINUTOS='60',ALERTAS_DEMO='1')
    comando=['node',str(args.servidor_pglite.resolve()),str(BASE/'sql'),str(args.puerto_bd)]
    entorno_bd = {k:v for k,v in env.items() if k != 'GROQ_API_KEY'}
    with proceso(comando,entorno_bd,args.puerto_bd):
        os.environ.update({k:env[k] for k in ('DB_HOST','DB_PORT','DB_NAME','DB_USER','DB_PASSWORD','DB_SSL')})
        sys.path.insert(0,str(BASE))
        from app.db import conectar
        from app.imagenes import limpiar_imagen
        from app.prelectura_padron import PATENTE_ENSAYO
        from app.seguridad import cifrar_clave
        padron = padron_prueba(PATENTE_ENSAYO)
        env['GROQ_PADRON_ENSAYO_SHA256'] = sha256(limpiar_imagen(padron, lado_maximo=2400)).hexdigest()
        clave=secrets.token_urlsafe(14)+'A7!'
        operador='operador@example.invalid'
        with conectar() as conn:
            cur=conn.cursor()
            cur.execute("UPDATE organizacion SET alertas_provisionales_habilitadas=TRUE WHERE id_organizacion=1")
            cur.execute("UPDATE usuario SET password_hash=%s WHERE correo=%s RETURNING id_usuario",(cifrar_clave(clave),operador))
            uid=cur.fetchone()[0]
            cur.execute("INSERT INTO usuario_rol(id_usuario,id_rol,asignado_por) SELECT %s,id_rol,%s FROM rol WHERE codigo='administrador' ON CONFLICT DO NOTHING",(uid,uid))
        api=['-m','uvicorn','app.main:app','--host','127.0.0.1','--port',str(args.puerto_api),'--log-level','warning']
        with proceso([sys.executable,*api],env,args.puerto_api):
            base=f'http://127.0.0.1:{args.puerto_api}'
            with httpx.Client(base_url=base,timeout=20,trust_env=False) as c:
                mail_a='titular.alerta@example.invalid'
                mail_b='colaborador.alerta@example.invalid'
                h=ciudadano(c,'Profesor 1 · Titular ficticio',mail_a,clave,'+56915270971')
                b=ciudadano(c,'Profesor 2 · Colaborador ficticio',mail_b,clave,'+56915270972')
                op=ingresar(c,operador,clave,institucional=True)
                vid=registrar_auto(c,h,'ZQXT91',padron_prueba('ZQXT91'))
                registrar_auto(c,h,PATENTE_ENSAYO,padron)
                vinculos=c.get('/gestion/vinculos',headers=op).raise_for_status().json()
                if args.validar or args.validar_groq:
                    fila = next(v for v in vinculos if v['patente'] == PATENTE_ENSAYO)
                    pendiente = fila['id_vinculo_vehiculo']
                    imagen = c.get(f'/gestion/vinculos/{pendiente}/padron',headers=op).raise_for_status().content
                    if sha256(imagen).hexdigest() != env['GROQ_PADRON_ENSAYO_SHA256']:
                        raise RuntimeError('El padrón guardado no coincide con el padrón ficticio generado.')
                    if fila['prelectura_disponible'] != bool(env.get('GROQ_API_KEY')):
                        raise RuntimeError('El panel no refleja la disponibilidad de la prelectura.')
                if args.validar_groq:
                    validar_groq(c,op,pendiente)
                    return
                idv=next(v['id_vinculo_vehiculo'] for v in vinculos if v['patente']=='ZQXT91')
                c.get(f'/gestion/vinculos/{idv}/padron',headers=op).raise_for_status()
                enviar(c,f'/gestion/vinculos/{idv}/decision',{'decision':'autorizado','estado_esperado':'pendiente',
                    'motivo':'padron_y_coincidencia','confirmar_padron':True},op,204)
                sembrar_zonas(c, op, h)
                foto=imagen_prueba()
                if args.guion_web:
                    subprocess.run(['node',str(args.guion_web.resolve())],check=True,input=json.dumps({
                        'base':base,'titular':mail_a,'colaborador':mail_b,'operador':operador,'clave':clave,
                        'vehiculo':vid,'foto':base64.b64encode(foto).decode(),'padron':padron_prueba('ZQXT93'),
                    }).encode())
                    return
                if args.validar:
                    zonas = c.get('/territorio/zonas?lat=-36.83&lon=-73.05', headers=b).raise_for_status().json()
                    if not zonas['simulacion'] or [z['antecedentes'] for z in zonas['zonas']] != [4, 2]:
                        raise RuntimeError('El mapa de ensayo no devolvió las dos zonas ficticias esperadas.')
                    print('PostGIS comprobó dos zonas históricas ficticias, con 4 y 2 antecedentes revisados.')
                    validar(c,h,b,op,vid,base64.b64encode(foto).decode())
                    return
                (BASE/'Foto_ficticia_alertas.png').write_bytes(foto)
                print(f'\nDemostración aislada: {base}/ciudadania y {base}/operaciones')
                print(f'Titular: {mail_a}\nColaborador: {mail_b}\nOperador: {operador}')
                print(f'Clave temporal de la instancia local: {clave}')
                print('ZQXT91 aprobado mediante padrón ficticio. ZQXT92 pendiente con padrón visible para supervisión.')
                print('Mapa de Concepción: dos zonas y seis antecedentes ficticios. Casa y Trabajo de ensayo guardados.')
                print('Foto_ficticia_alertas.png disponible para los reportes y avistamientos del ensayo.')
                print('Cierra con Ctrl+C para descartar la base en memoria.')
                while True:
                    time.sleep(1)

if __name__=='__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
    except RuntimeError as error:
        sys.exit(str(error))
