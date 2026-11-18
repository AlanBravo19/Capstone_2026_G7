"""Fixtures de prueba. Requieren una base RutaAlerta con 01/02 (o el script completo), 06 y 03_Datos_demo.sql.

Por defecto apuntan al servidor de prueba PGlite (scripts/servidor_prueba_pglite.mjs, puerto 54329).
Para usar un PostgreSQL real, definir DB_HOST, DB_PORT, DB_NAME, DB_USER y DB_PASSWORD antes de ejecutar pytest.
"""
import os
import uuid

os.environ.setdefault("DB_PORT", "54329")
os.environ.setdefault("DB_NAME", "postgres")
os.environ.setdefault("ENTORNO", "prueba")
os.environ.setdefault("CANALES_DEMO", "1")

import pytest
from fastapi.testclient import TestClient

from app.db import conectar
from app.main import app
from app.seguridad import cifrar_clave

CLAVE = "clave-de-prueba-123"


@pytest.fixture(scope="session")
def client():
    h={'X-Demo-Access':os.environ['DEMO_ACCESS_KEY']} if os.environ.get('DEMO_ACCESS_KEY') else {}
    return TestClient(app,headers=h)


def ejecutar(sql, params=(), filas=False):
    """Abre y cierra una conexión por consulta: el servidor PGlite atiende una sesión a la vez."""
    conn = conectar()
    try:
        cur = conn.cursor()
        cur.execute(sql, params)
        res = cur.fetchall() if filas else None
        conn.commit()
        return res
    finally:
        conn.close()


@pytest.fixture()
def db():
    return ejecutar


@pytest.fixture(autouse=True)
def aislar_contadores(db):
    # Sólo sobre la base desechable de pruebas. Dentro de cada prueba sí persisten.
    db('DELETE FROM limite_autenticacion')


def _login(client, correo, clave=CLAVE):
    r = client.post("/sesiones", json={"correo": correo, "clave": clave})
    assert r.status_code == 201, r.text
    return {"Authorization": f"Bearer {r.json()['token']}"}


@pytest.fixture()
def ciudadano(client, db):
    """Cuenta ciudadana nueva (vía API) con vínculo pendiente al vehículo ficticio 1."""
    correo = f"ciudadano-{uuid.uuid4().hex[:8]}@example.invalid"
    r = client.post("/cuentas", json={"nombre_visible": "Ciudadano de prueba", "correo": correo, "clave": CLAVE})
    assert r.status_code == 201, r.text
    # Fixture heredada de casos. Las pruebas nuevas verifican contactos vía API.
    uid=r.json()['id_usuario']
    db("UPDATE usuario SET estado='activo',correo_verificado_en=CURRENT_TIMESTAMP WHERE id_usuario=%s",(uid,))
    db('INSERT INTO contacto_telefono(id_usuario,telefono) VALUES(%s,%s)',(uid,'+569'+str(uid).zfill(8)))
    db("INSERT INTO vinculo_vehiculo(id_usuario, id_vehiculo, tipo) VALUES (%s, 1, 'propietario')",
       (r.json()["id_usuario"],))
    return {"correo": correo, "id": r.json()["id_usuario"], "headers": _login(client, correo)}


def _operador(client, db, correo):
    db("UPDATE usuario SET password_hash = %s WHERE correo_normalizado = %s", (cifrar_clave(CLAVE), correo))
    return _login(client, correo)


@pytest.fixture()
def supervisor_org1(client, db):
    """Usuario ficticio de 03_Datos_demo.sql con membresía de supervisor en la organización 1."""
    return _operador(client, db, "operador@example.invalid")


@pytest.fixture()
def operador_org2(client, db):
    """Usuario ficticio de 03_Datos_demo.sql con membresía de operador en la organización 2."""
    return _operador(client, db, "externo@example.invalid")
