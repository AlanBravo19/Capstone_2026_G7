"""Controles de este avance local: límites persistentes y permisos de participación."""
import hashlib
import hmac
import os
import secrets
import time
from fastapi import Depends, HTTPException, Request
from .db import obtener_conexion
from .seguridad import usuario_actual

DEMO = os.getenv('ENTORNO') == 'prueba' and os.getenv('CANALES_DEMO') == '1'
_secret = os.getenv('OTP_SECRET', '')
if not _secret and DEMO:
    _secret = secrets.token_urlsafe(48)
SECRET = _secret.encode()

def resumen(valor):
    return hmac.new(SECRET, valor.encode(), hashlib.sha256).digest()

def limitar(conn, clave, maximo, segundos=600):
    """Usar antes de mutaciones. Confirmar contadores para persistir errores HTTP."""
    ahora = int(time.time())
    ventana = ahora // segundos
    cur = conn.cursor()
    cur.execute('''INSERT INTO limite_autenticacion(clave,ventana,intentos) VALUES (%s,%s,1)
          ON CONFLICT(clave,ventana) DO UPDATE SET intentos=limite_autenticacion.intentos+1
          RETURNING intentos''', (resumen(clave), ventana))
    n = cur.fetchone()[0]
    conn.commit()
    if n > maximo:
        raise HTTPException(429, 'Demasiados intentos. Vuelve a intentarlo más tarde.',
                            headers={'Retry-After': str(segundos-ahora%segundos)})

def limitar_ip(conn, request: Request, accion, maximo):
    # No confiar en X-Forwarded-For aportado por el cliente. Proxy pendiente de configuración.
    limitar(conn,f'ip:{accion}:{request.client.host if request.client else "desconocida"}',maximo)

def participante(usuario=Depends(usuario_actual), conn=Depends(obtener_conexion)):
    cur=conn.cursor()
    cur.execute('''SELECT 1 FROM usuario u JOIN contacto_telefono t USING(id_usuario)
        WHERE u.id_usuario=%s AND u.estado='activo' AND u.correo_verificado_en IS NOT NULL FOR UPDATE OF u''',
        (usuario['id_usuario'],))
    if cur.fetchone() is None:
        raise HTTPException(403,'Verifica el correo y un teléfono para participar. La recepción asistida está pendiente.')
    return usuario

def administrador(usuario=Depends(usuario_actual), conn=Depends(obtener_conexion)):
    cur=conn.cursor()
    cur.execute('''SELECT 1 FROM usuario_rol ur JOIN rol r USING(id_rol)
        WHERE ur.id_usuario=%s AND ur.revocado_en IS NULL AND r.codigo='administrador' ''',
        (usuario['id_usuario'],))
    if cur.fetchone() is None:
        raise HTTPException(403,'Se requiere rol administrador')
    return usuario
