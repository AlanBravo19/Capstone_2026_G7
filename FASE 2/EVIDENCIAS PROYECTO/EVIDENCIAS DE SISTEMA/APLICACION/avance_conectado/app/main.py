"""API RutaAlerta: incremento inicial del Sprint 1 (HT01, HU01, HU03 y HU13)."""
from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.responses import FileResponse, JSONResponse
from pathlib import Path
import os
import secrets

from .db import ErrorBD, conectar, obtener_conexion
from .prelectura_padron import operativa
from .routers import casos, cuentas, identidad, avance, seguridad_cuenta, colaboracion, movilidad, testigos, gestion_equipo
from .routers import recursos_territorio
from .routers import estadisticas
from .routers import alertas
from .config import config
from .antifraude import DEMO, SECRET
from .correo import correo_real, configuracion_smtp

ENSAYO_PUBLICADO = os.getenv('RUTAALERTA_ENSAYO_PUBLICADO') == '1'
if ENSAYO_PUBLICADO and (
    not DEMO or not config.alertas_demo or config.db_name != 'rutaalerta_ensayo'
    or config.db_user.split('.', 1)[0] != 'ra_ensayo' or not config.db_ssl
    or os.getenv('GROQ_API_KEY')
):
    raise RuntimeError('El ensayo publicado exige la base y el usuario exclusivos de pruebas.')

# La beta operativa exige correo real y una conexión TLS.
if not DEMO:
    if not correo_real():
        raise RuntimeError('Configura el envío SMTP real para operar sin códigos de prueba.')
    configuracion_smtp()
if len(SECRET)<32:
    raise RuntimeError('OTP_SECRET debe tener al menos 32 bytes')
if os.getenv('VERCEL') and not ENSAYO_PUBLICADO:
    if os.getenv('ENTORNO')!='operacion' or DEMO or len(os.getenv('OTP_SECRET',''))<32:
        raise RuntimeError('El registro público requiere correo operativo y una clave OTP estable.')
    if os.getenv('DB_SSL')!='1':
        raise RuntimeError('La conexión remota exige DB_SSL=1')
if config.alertas_demo and (not DEMO or (os.getenv('VERCEL') and not ENSAYO_PUBLICADO)):
    raise RuntimeError('La simulación de encargos requiere una instancia aislada de prueba.')

app = FastAPI(
    title="RutaAlerta API",
    version="0.25.4-beta",
    description="Beta colaborativa: TOTP, seguimiento, publicación revisada y fotos privadas. Correo y SMS dependen de la configuración de proveedores.",
)
app.include_router(cuentas.router)
app.include_router(casos.router)
app.include_router(identidad.router)
app.include_router(avance.router)
app.include_router(seguridad_cuenta.router)
app.include_router(colaboracion.router)
app.include_router(movilidad.router)
app.include_router(testigos.router)
app.include_router(gestion_equipo.router)
app.include_router(recursos_territorio.router)
app.include_router(estadisticas.router)
app.include_router(alertas.router)

BASE=Path(__file__).resolve().parents[1]

@app.middleware('http')
async def cabeceras_respuesta(request:Request,call_next):
    ruta=request.url.path.rstrip('/')
    if ENSAYO_PUBLICADO and request.method=='POST' and (
        ruta == '/cuentas' or ruta.startswith(('/cuentas/recuperacion', '/identidad/'))
    ):
        response=JSONResponse({'detail':'Usa las cuentas ficticias preparadas para este ensayo.'},status_code=403)
    else:
        response=await call_next(request)
    response.headers['Cache-Control']='no-store'
    response.headers['X-Content-Type-Options']='nosniff'
    response.headers['Referrer-Policy']='same-origin'
    return response

@app.get('/',include_in_schema=False)
@app.get('/operaciones',include_in_schema=False)
@app.get('/operaciones/{ruta:path}',include_in_schema=False)
def inicio():return FileResponse(BASE/'web/operaciones.html')

@app.get('/ciudadania',include_in_schema=False)
def ciudadania():return FileResponse(BASE/'web/index.html')

@app.get('/operaciones.css',include_in_schema=False)
def estilos_operaciones():return FileResponse(BASE/'public/operaciones.css',media_type='text/css')

@app.get('/clip-practica.mp4',include_in_schema=False)
def video_practica():return FileResponse(BASE/'public/clip-practica.mp4',media_type='video/mp4')

@app.get('/operaciones.js',include_in_schema=False)
def codigo_operaciones():return FileResponse(BASE/'public/operaciones.js',media_type='text/javascript')

@app.get('/site.css',include_in_schema=False)
def css():return FileResponse(BASE/'public/site.css',media_type='text/css')

@app.get('/site.js',include_in_schema=False)
def js():return FileResponse(BASE/'public/site.js',media_type='text/javascript')


@app.get('/mapa.js',include_in_schema=False)
def mapa_js():return FileResponse(BASE/'public/mapa.js',media_type='text/javascript')


@app.get('/mapa-azul.json',include_in_schema=False)
def mapa_estilo():return FileResponse(BASE/'public/mapa-azul.json',media_type='application/json')

@app.get("/health", tags=["operación"])
def health(request:Request,conn=Depends(obtener_conexion)):
    # Compatibilidad con el monitor privado anterior. Ningún cliente necesita esta clave.
    clave_sonda=os.getenv('DEMO_ACCESS_KEY','')
    if clave_sonda and not secrets.compare_digest(clave_sonda,request.headers.get('x-demo-access','')):
        raise HTTPException(403,'Diagnóstico interno restringido')
    cur = conn.cursor()
    cur.execute("SELECT postgis_lib_version(), (SELECT count(*) FROM information_schema.tables WHERE table_schema = 'rutaalerta' AND table_type = 'BASE TABLE')")
    postgis, tablas = cur.fetchone()
    return {"estado": "ok", "postgis": postgis, "tablas": tablas}

@app.get("/version",include_in_schema=False)
def version_beta():
    try:
        with conectar() as conn:
            cur = conn.cursor()
            cur.execute("""SELECT COALESCE(bool_and(has_table_privilege(
                to_regclass('rutaalerta.documento_vinculo_vehiculo'), permiso)), false)
                FROM unnest(ARRAY['SELECT','INSERT','UPDATE']) permiso""")
            padron_privado = cur.fetchone()[0]
    except ErrorBD:
        padron_privado = False
    return {"version": app.version, "modelo_tablas": 68, "cliente": "Flutter Android",
            "panel": "/operaciones", "padron_privado": padron_privado,
            "padron_prelectura": bool(padron_privado and operativa()),
            "alertas_automaticas": config.alertas_automaticas,
            "ensayo": ENSAYO_PUBLICADO}

@app.get('/leaflet/leaflet.css', include_in_schema=False)
def estilos_cartografia(): return FileResponse(BASE/'public/leaflet/leaflet.css', media_type='text/css')

@app.get('/leaflet/leaflet.js', include_in_schema=False)
def motor_cartografico(): return FileResponse(BASE/'public/leaflet/leaflet.js', media_type='text/javascript')

@app.get('/mapa-operador.js', include_in_schema=False)
def mapa_operador(): return FileResponse(BASE/'public/mapa-operador.js', media_type='text/javascript')
