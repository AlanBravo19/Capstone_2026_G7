import time

from fastapi.testclient import TestClient

from app.main import app
from app.routers.seguridad_cuenta import codigo_totp
from app.seguridad import COOKIE_OPERADOR, huella
from conftest import CLAVE

PORTAL = {'X-RutaAlerta-Portal': '1', 'Sec-Fetch-Site': 'same-origin'}
INSTITUCIONAL = '/institucional/sesiones'


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
    assert 'set-cookie' not in login.headers
    perfil = client.get("/mi-perfil", headers={"Authorization": "Bearer " + login.json()["token"]})
    assert perfil.json()["organizaciones"]


def test_portal_conserva_sesion_en_https_y_revoca_al_salir(supervisor_org1):
    with TestClient(app, base_url='https://testserver') as navegador:
        assert navegador.post(INSTITUCIONAL+'/continuar', headers=PORTAL).status_code == 204
        login = navegador.post(INSTITUCIONAL, headers=PORTAL,
                               json={'correo':'operador@example.invalid', 'clave':CLAVE})
        assert login.status_code == 201
        cookie = login.headers['set-cookie']
        for propiedad in ('Secure', 'HttpOnly', 'Path=/institucional/sesiones', 'SameSite=strict'):
            assert propiedad in cookie
        token = login.json()['token']
        continuar = navegador.post(INSTITUCIONAL+'/continuar', headers=PORTAL)
        assert continuar.json() == {'token': token}
        assert navegador.post(INSTITUCIONAL+'/continuar', headers={**PORTAL, 'Sec-Fetch-Site':'cross-site'}).status_code == 403
        assert navegador.get('/mi-perfil').status_code == 401
        autorizado = {'Authorization':'Bearer '+token}
        cierre = navegador.post(INSTITUCIONAL+'/cerrar', headers={**PORTAL, **autorizado})
        assert cierre.status_code == 204 and 'Max-Age=0' in cierre.headers['set-cookie']
        assert navegador.post(INSTITUCIONAL+'/continuar', headers=PORTAL).status_code == 204
        assert navegador.get('/mi-perfil', headers=autorizado).status_code == 401


def test_portal_limpia_cookie_de_sesion_vencida(supervisor_org1, db):
    with TestClient(app, base_url='https://testserver') as navegador:
        login = navegador.post(INSTITUCIONAL, headers=PORTAL,
                               json={'correo':'operador@example.invalid', 'clave':CLAVE})
        assert login.status_code == 201
        db("UPDATE token_acceso SET vence_en=CURRENT_TIMESTAMP WHERE token_hash=%s",
           (huella(login.json()['token']),))
        vencida = navegador.post(INSTITUCIONAL+'/continuar', headers=PORTAL)
        assert vencida.status_code == 204 and 'Max-Age=0' in vencida.headers['set-cookie']


def test_membresia_debe_seguir_vigente_al_confirmar_factor(client, ciudadano, db):
    uid, cabecera = ciudadano["id"], ciudadano["headers"]
    db("""INSERT INTO membresia(id_usuario,id_organizacion,rol,inicio)
          VALUES (%s,1,'operador',CURRENT_TIMESTAMP)""", (uid,))
    secreto = client.post("/seguridad/totp/preparar", headers=cabecera, json={"clave": CLAVE}).json()["secreto"]
    activar = client.post("/seguridad/totp/activar", headers=cabecera,
                          json={"codigo": codigo_totp(secreto, int(time.time())//30-1)})
    respaldo = activar.json()["codigos_recuperacion"][0]
    credenciales = {"correo": ciudadano["correo"], "clave": CLAVE}
    with TestClient(app, base_url='https://testserver', headers=PORTAL) as navegador:
        inicio = navegador.post(INSTITUCIONAL, json=credenciales)
        desafio = inicio.json()["id_desafio"]
        assert COOKIE_OPERADOR not in navegador.cookies
        assert navegador.post(INSTITUCIONAL+'/continuar').status_code == 204
        db("UPDATE membresia SET estado='suspendida' WHERE id_usuario=%s", (uid,))
        factor = {"id_desafio": desafio, "codigo": respaldo}
        assert navegador.post(INSTITUCIONAL+'/mfa', json=factor).status_code == 401
        assert navegador.post(INSTITUCIONAL, json=credenciales).status_code == 401
        db("UPDATE membresia SET estado='activa' WHERE id_usuario=%s", (uid,))
        mfa = navegador.post(INSTITUCIONAL+'/mfa', json=factor)
        assert mfa.status_code == 201
        assert navegador.post(INSTITUCIONAL+'/continuar').json() == {'token':mfa.json()['token']}
        db("UPDATE membresia SET estado='suspendida' WHERE id_usuario=%s", (uid,))
        assert navegador.post(INSTITUCIONAL+'/continuar').status_code == 204
        assert COOKIE_OPERADOR not in navegador.cookies

