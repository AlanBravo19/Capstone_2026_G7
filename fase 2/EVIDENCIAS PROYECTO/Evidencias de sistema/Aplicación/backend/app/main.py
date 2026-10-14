"""API RutaAlerta: incremento inicial del Sprint 1 (HT01, HU01, HU03 y HU13)."""
from fastapi import Depends, FastAPI

from .db import obtener_conexion
from .routers import casos, cuentas

app = FastAPI(
    title="RutaAlerta API",
    version="0.1.0",
    description="Incremento inicial del Sprint 1. Los clientes nunca acceden directamente a la base de datos.",
)
app.include_router(cuentas.router)
app.include_router(casos.router)


@app.get("/health", tags=["operación"])
def health(conn=Depends(obtener_conexion)):
    cur = conn.cursor()
    cur.execute("SELECT postgis_lib_version(), (SELECT count(*) FROM information_schema.tables WHERE table_schema = 'rutaalerta')")
    postgis, tablas = cur.fetchone()
    return {"estado": "ok", "postgis": postgis, "tablas": tablas}
