"""API RutaAlerta: incremento inicial del Sprint 1 (HT01, HU01, HU03 y HU13)."""
from fastapi import Depends, FastAPI, Request
from fastapi.responses import FileResponse, JSONResponse
from pathlib import Path
import os
import secrets

from .db import obtener_conexion
from .routers import casos, cuentas, identidad, avance
from .antifraude import DEMO, SECRET
from .correo import correo_real, configuracion_smtp

# Esta entrega falla cerrada: no es una API de producción con códigos expuestos.
if not DEMO:
    if not correo_real():
        raise RuntimeError('Configura el envío SMTP real para operar sin códigos de prueba.')
    configuracion_smtp()
if len(SECRET)<32:
    raise RuntimeError('OTP_SECRET debe tener al menos 32 bytes')
if os.getenv('VERCEL'):
    if len(os.getenv('DEMO_ACCESS_KEY',''))<24 or len(os.getenv('OTP_SECRET',''))<32:
        raise RuntimeError('Configura claves privadas estables de acceso demo y OTP antes de publicar')
    if os.getenv('DB_SSL')!='1':
        raise RuntimeError('La conexión remota exige DB_SSL=1')

app = FastAPI(
    title="RutaAlerta API",
    version="0.3.0-demo",
    description="Avance local 29/10/2026. Verificación de contactos SIMULADA, base SQL real. No usar datos personales reales.",
)
app.include_router(cuentas.router)
app.include_router(casos.router)
app.include_router(identidad.router)
app.include_router(avance.router)

BASE=Path(__file__).resolve().parents[1]

@app.middleware('http')
async def proteger_demo(request:Request,call_next):
    clave=os.getenv('DEMO_ACCESS_KEY','')
    libre=request.url.path in ('/','/site.css','/site.js','/mapa.js','/favicon.ico')
    if clave and not libre and not secrets.compare_digest(request.headers.get('x-demo-access',''),clave):
        return JSONResponse({'detail':'Ingresa una clave de invitación válida a la beta.'},status_code=403)
    response=await call_next(request)
    response.headers['Cache-Control']='no-store'
    response.headers['X-Content-Type-Options']='nosniff'
    response.headers['Referrer-Policy']='same-origin'
    return response

@app.get('/',include_in_schema=False)
def inicio():return FileResponse(BASE/'web/index.html')

@app.get('/site.css',include_in_schema=False)
def css():return FileResponse(BASE/'public/site.css',media_type='text/css')

@app.get('/site.js',include_in_schema=False)
def js():return FileResponse(BASE/'public/site.js',media_type='text/javascript')


@app.get('/mapa.js',include_in_schema=False)
def mapa_js():return FileResponse(BASE/'public/mapa.js',media_type='text/javascript')


@app.get("/health", tags=["operación"])
def health(conn=Depends(obtener_conexion)):
    cur = conn.cursor()
    cur.execute("SELECT postgis_lib_version(), (SELECT count(*) FROM information_schema.tables WHERE table_schema = 'rutaalerta' AND table_type = 'BASE TABLE')")
    postgis, tablas = cur.fetchone()
    return {"estado": "ok", "postgis": postgis, "tablas": tablas}
