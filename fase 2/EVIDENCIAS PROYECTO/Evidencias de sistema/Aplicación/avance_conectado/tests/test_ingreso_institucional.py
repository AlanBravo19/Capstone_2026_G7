import time

from app.routers.seguridad_cuenta import codigo_totp
from conftest import CLAVE


def test_ciudadano_no_recibe_sesion_institucional(client, ciudadano, db):
    credenciales = {"correo": ciudadano["correo"], "clave": CLAVE}
    tokens = "SELECT COUNT(*) FROM token_acceso WHERE id_usuario=%s AND proposito='sesion'"
    antes = db(tokens, (ciudadano["id"],), filas=True)
    respuesta = client.post("/institucional/sesiones", json=credenciales)
    assert respuesta.status_code == 401
    assert db(tokens, (ciudadano["id"],), filas=True) == antes
    assert client.post("/sesiones", json=credenciales).status_code == 201


def test_operador_habilitado_ingresa(client, supervisor_org1):
    login = client.post("/institucional/sesiones", json={"correo": "operador@example.invalid", "clave": CLAVE})
    assert login.status_code == 201
    perfil = client.get("/mi-perfil", headers={"Authorization": "Bearer " + login.json()["token"]})
    assert perfil.json()["organizaciones"]


def test_membresia_debe_seguir_vigente_al_confirmar_factor(client, ciudadano, db):
    uid, cabecera = ciudadano["id"], ciudadano["headers"]
    db("""INSERT INTO membresia(id_usuario,id_organizacion,rol,inicio)
          VALUES (%s,1,'operador',CURRENT_TIMESTAMP)""", (uid,))
    secreto = client.post("/seguridad/totp/preparar", headers=cabecera, json={"clave": CLAVE}).json()["secreto"]
    activar = client.post("/seguridad/totp/activar", headers=cabecera,
                          json={"codigo": codigo_totp(secreto, int(time.time())//30-1)})
    respaldo = activar.json()["codigos_recuperacion"][0]
    credenciales = {"correo": ciudadano["correo"], "clave": CLAVE}
    desafio = client.post("/institucional/sesiones", json=credenciales).json()["id_desafio"]
    db("UPDATE membresia SET estado='suspendida' WHERE id_usuario=%s", (uid,))
    factor = {"id_desafio": desafio, "codigo": respaldo}
    assert client.post("/institucional/sesiones/mfa", json=factor).status_code == 401
    assert client.post("/institucional/sesiones", json=credenciales).status_code == 401
    db("UPDATE membresia SET estado='activa' WHERE id_usuario=%s", (uid,))
    assert client.post("/institucional/sesiones/mfa", json=factor).status_code == 201

