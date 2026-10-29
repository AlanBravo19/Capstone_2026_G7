"""Contraseñas, tokens de sesión y autorización por organización (RNF01)."""
import base64
import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .config import config
from .db import fila_dict, obtener_conexion

_N, _R, _P = 2 ** 14, 8, 1


def cifrar_clave(clave: str) -> str:
    sal = secrets.token_bytes(16)
    h = hashlib.scrypt(clave.encode(), salt=sal, n=_N, r=_R, p=_P, dklen=32)
    return f"scrypt${_N}${_R}${_P}${base64.b64encode(sal).decode()}${base64.b64encode(h).decode()}"


def verificar_clave(clave: str, guardado: str | None) -> bool:
    if not guardado or not guardado.startswith("scrypt$"):
        return False
    _, n, r, p, sal, h = guardado.split("$")
    calc = hashlib.scrypt(clave.encode(), salt=base64.b64decode(sal), n=int(n), r=int(r), p=int(p), dklen=32)
    return hmac.compare_digest(calc, base64.b64decode(h))


def huella(token: str) -> bytes:
    """En la base sólo se guarda la huella SHA-256 (32 bytes), nunca el token."""
    return hashlib.sha256(token.encode()).digest()


def emitir_token(cur, id_usuario: int, proposito: str, minutos: int) -> tuple[str, datetime]:
    token = secrets.token_urlsafe(32)
    vence = datetime.now(timezone.utc) + timedelta(minutes=minutos)
    cur.execute(
        "INSERT INTO token_acceso(id_usuario, proposito, token_hash, vence_en) VALUES (%s, %s, %s, %s)",
        (id_usuario, proposito, huella(token), vence),
    )
    return token, vence


bearer = HTTPBearer(auto_error=False)


def usuario_actual(credentials: HTTPAuthorizationCredentials | None = Depends(bearer), conn=Depends(obtener_conexion)) -> dict:
    if not credentials or credentials.scheme.lower()!='bearer':
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Falta el token de sesión")
    cur = conn.cursor()
    cur.execute(
        """SELECT u.id_usuario, u.nombre_visible, u.estado
             FROM token_acceso t JOIN usuario u USING (id_usuario)
            WHERE t.token_hash = %s AND t.proposito = 'sesion'
              AND t.revocado_en IS NULL AND t.vence_en > CURRENT_TIMESTAMP""",
        (huella(credentials.credentials.strip()),),
    )
    u = fila_dict(cur, cur.fetchone())
    if u is None or u["estado"] in ("suspendido", "anonimizado"):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Sesión inválida o vencida")
    return u


def organizaciones_del_operador(cur, id_usuario: int) -> list[int]:
    """Ámbito institucional: membresías activas y vigentes del usuario."""
    cur.execute(
        """SELECT m.id_organizacion FROM membresia m JOIN organizacion o USING (id_organizacion)
            WHERE m.id_usuario = %s AND m.estado = 'activa' AND m.fin IS NULL
              AND m.inicio <= CURRENT_TIMESTAMP AND o.estado = 'activa'""",
        (id_usuario,),
    )
    return [r[0] for r in cur.fetchall()]
