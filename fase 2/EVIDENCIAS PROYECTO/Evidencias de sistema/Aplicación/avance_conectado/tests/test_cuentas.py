"""HU01: CP40 y CP41."""
from datetime import datetime, timedelta, timezone
import uuid

from app.seguridad import huella


def test_health_conecta_con_postgis(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["tablas"] == 59


def test_cp40_registro_ciudadano_y_correo_repetido(client):
    correo = f"Persona-{uuid.uuid4().hex[:8]}@Example.invalid"
    r = client.post("/cuentas", json={"nombre_visible": "Primera cuenta", "correo": correo, "clave": "clave-segura-1"})
    assert r.status_code == 201
    assert r.json()["estado"] == "pendiente" and r.json()["roles"] == ["ciudadano"]
    # Mismo correo con otras mayúsculas y espacios: rechazado sin revelar la otra cuenta.
    r2 = client.post("/cuentas", json={"nombre_visible": "Otra", "correo": f"  {correo.upper()} ", "clave": "clave-segura-2"})
    assert r2.status_code == 409
    assert "Primera cuenta" not in r2.text


def test_cp40_registro_no_concede_ambito_institucional(client, ciudadano):
    r = client.get("/casos", headers=ciudadano["headers"])
    assert r.status_code == 403


def test_cp41_token_de_recuperacion_de_un_solo_uso(client, ciudadano):
    r = client.post("/cuentas/recuperacion", json={"correo": ciudadano["correo"]})
    assert r.status_code == 202
    token = r.json()["token_prueba"]
    ok = client.post("/cuentas/recuperacion/confirmar", json={"token": token, "nueva_clave": "nueva-clave-123"})
    assert ok.status_code == 204
    reuso = client.post("/cuentas/recuperacion/confirmar", json={"token": token, "nueva_clave": "otra-clave-456"})
    assert reuso.status_code == 400
    assert client.post("/sesiones", json={"correo": ciudadano["correo"], "clave": "nueva-clave-123"}).status_code == 201


def test_cp41_token_vencido_rechazado(client, ciudadano, db):
    token = "token-vencido-" + uuid.uuid4().hex
    ahora = datetime.now(timezone.utc)
    db("""INSERT INTO token_acceso(id_usuario, proposito, token_hash, creado_en, vence_en)
          VALUES (%s, 'recuperar_clave', %s, %s, %s)""",
       (ciudadano["id"], huella(token), ahora - timedelta(hours=2), ahora - timedelta(hours=1)))
    r = client.post("/cuentas/recuperacion/confirmar", json={"token": token, "nueva_clave": "nueva-clave-123"})
    assert r.status_code == 400


def test_sin_token_no_hay_acceso(client):
    assert client.get("/casos").status_code == 401
