import time
from datetime import datetime, timezone, timedelta

from app.routers.seguridad_cuenta import codigo_totp
from test_identidad_mvp import cuenta, CLAVE


def test_activar_y_recordar_telefono(client):
    _, correo, anterior = cuenta(client)
    secreto = client.post('/seguridad/totp/preparar', headers=anterior, json={'clave': CLAVE}).json()['secreto']
    datos = {'codigo': codigo_totp(secreto, int(time.time()) // 30), 'continuar_sesion': True, 'recordar_telefono': True}
    respuesta = client.post('/seguridad/totp/activar', headers=anterior, json=datos)
    assert respuesta.status_code == 200
    sesion = respuesta.json()
    assert len(sesion['codigos_recuperacion']) == 8
    assert datetime.fromisoformat(sesion['vence_en']) > datetime.now(timezone.utc) + timedelta(days=29)
    actual = {'Authorization': 'Bearer ' + sesion['token']}
    assert client.get('/mi-perfil', headers=anterior).status_code == 401
    assert client.get('/mi-perfil', headers=actual).status_code == 200
    assert client.get('/seguridad/estado', headers=actual).json()['mfa_activo']
    assert client.post('/sesiones', json={'correo': correo, 'clave': CLAVE}).json()['requiere_mfa']
    assert client.post('/sesiones/cerrar', headers=actual).status_code == 204
    assert client.get('/mi-perfil', headers=actual).status_code == 401
