"""HU01 / RF01 / CU01: registro, inicio de sesión y recuperación de acceso."""
from fastapi import APIRouter, Depends, HTTPException, status
import pg8000.dbapi

from ..config import config
from ..db import fila_dict, obtener_conexion
from ..esquemas import (CuentaSalida, RecuperacionConfirmar, RecuperacionEntrada, RecuperacionSalida,
                        RegistroEntrada, SesionEntrada, SesionSalida)
from ..seguridad import cifrar_clave, emitir_token, huella, verificar_clave

router = APIRouter(tags=["cuentas"])


@router.post("/cuentas", response_model=CuentaSalida, status_code=status.HTTP_201_CREATED)
def registrar(datos: RegistroEntrada, conn=Depends(obtener_conexion)):
    """El registro público crea sólo cuentas ciudadanas, pendientes de verificación de correo."""
    cur = conn.cursor()
    cur.execute("SELECT id_rol FROM rol WHERE codigo = 'ciudadano'")
    rol = cur.fetchone()
    if rol is None:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Falta el rol 'ciudadano' en la base")
    try:
        cur.execute(
            """INSERT INTO usuario(nombre_visible, correo, password_hash, estado)
               VALUES (%s, %s, %s, 'pendiente') RETURNING id_usuario, nombre_visible, estado""",
            (datos.nombre_visible, datos.correo, cifrar_clave(datos.clave)),
        )
    except pg8000.dbapi.DatabaseError as e:
        if "ck_usuario_1" in str(e):
            # Mensaje genérico: no revela datos de la otra cuenta.
            raise HTTPException(status.HTTP_409_CONFLICT, "No fue posible registrar la cuenta con ese correo")
        raise
    u = fila_dict(cur, cur.fetchone())
    cur.execute("INSERT INTO usuario_rol(id_usuario, id_rol, asignado_por) VALUES (%s, %s, %s)",
                (u["id_usuario"], rol[0], u["id_usuario"]))
    return CuentaSalida(**u, roles=["ciudadano"])


@router.post("/sesiones", response_model=SesionSalida, status_code=status.HTTP_201_CREATED)
def iniciar_sesion(datos: SesionEntrada, conn=Depends(obtener_conexion)):
    cur = conn.cursor()
    cur.execute("SELECT id_usuario, password_hash, estado FROM usuario WHERE correo_normalizado = LOWER(TRIM(%s))",
                (datos.correo,))
    fila = cur.fetchone()
    if fila is None or not verificar_clave(datos.clave, fila[1]) or fila[2] in ("suspendido", "anonimizado"):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Credenciales inválidas")
    token, vence = emitir_token(cur, fila[0], "sesion", config.sesion_horas * 60)
    return SesionSalida(token=token, vence_en=vence)


@router.post("/cuentas/recuperacion", response_model=RecuperacionSalida, status_code=status.HTTP_202_ACCEPTED)
def solicitar_recuperacion(datos: RecuperacionEntrada, conn=Depends(obtener_conexion)):
    """Responde igual exista o no la cuenta, para no revelar correos registrados."""
    cur = conn.cursor()
    cur.execute("SELECT id_usuario FROM usuario WHERE correo_normalizado = LOWER(TRIM(%s))", (datos.correo,))
    fila = cur.fetchone()
    token = None
    if fila is not None:
        token, _ = emitir_token(cur, fila[0], "recuperar_clave", config.recuperacion_minutos)
    return RecuperacionSalida(
        mensaje="Si el correo está registrado, se enviarán instrucciones.",
        token_prueba=token if config.entorno == "prueba" else None,
    )


@router.post("/cuentas/recuperacion/confirmar", status_code=status.HTTP_204_NO_CONTENT)
def confirmar_recuperacion(datos: RecuperacionConfirmar, conn=Depends(obtener_conexion)):
    """El token es de un solo uso y vence: un token consumido o vencido se rechaza (CP41)."""
    cur = conn.cursor()
    cur.execute(
        """UPDATE token_acceso SET consumido_en = CURRENT_TIMESTAMP
            WHERE token_hash = %s AND proposito = 'recuperar_clave' AND consumido_en IS NULL
              AND revocado_en IS NULL AND vence_en > CURRENT_TIMESTAMP
        RETURNING id_usuario""",
        (huella(datos.token),),
    )
    fila = cur.fetchone()
    if fila is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Token inválido, vencido o ya utilizado")
    cur.execute("UPDATE usuario SET password_hash = %s, actualizado_en = CURRENT_TIMESTAMP WHERE id_usuario = %s",
                (cifrar_clave(datos.nueva_clave), fila[0]))
    # Cerrar las sesiones abiertas tras cambiar la contraseña.
    cur.execute("""UPDATE token_acceso SET revocado_en = CURRENT_TIMESTAMP
                    WHERE id_usuario = %s AND proposito = 'sesion' AND revocado_en IS NULL""", (fila[0],))
