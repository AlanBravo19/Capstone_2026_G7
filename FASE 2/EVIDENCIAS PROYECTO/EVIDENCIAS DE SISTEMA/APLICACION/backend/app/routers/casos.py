"""HU03 / RF03 / CU03 (reportar incidente) y HU13 / RF13 / CU13 (bandeja institucional)."""
import json
import secrets
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Header, HTTPException, Response, status
import pg8000.dbapi

from ..db import fila_dict, obtener_conexion
from ..esquemas import BandejaItem, CasoEntrada, CasoSalida
from ..seguridad import organizaciones_del_operador, usuario_actual

router = APIRouter(tags=["casos"])


def _caso_existente(cur, id_usuario, clave):
    cur.execute("""SELECT id_caso, folio, estado, creado_en FROM caso
                    WHERE id_usuario_reportante = %s AND clave_envio = %s::uuid""", (id_usuario, clave))
    return fila_dict(cur, cur.fetchone())


@router.post("/casos", response_model=CasoSalida, status_code=status.HTTP_201_CREATED)
def reportar_caso(datos: CasoEntrada, response: Response, idempotency_key: str = Header(...),
                  usuario=Depends(usuario_actual), conn=Depends(obtener_conexion)):
    try:
        clave = str(uuid.UUID(idempotency_key))
    except ValueError:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Idempotency-Key debe ser un UUID")
    cur = conn.cursor()
    previo = _caso_existente(cur, usuario["id_usuario"], clave)
    if previo:
        # Reintento con la misma clave: se devuelve el mismo caso, sin duplicarlo (CP43).
        response.status_code = status.HTTP_200_OK
        return CasoSalida(id_caso=previo["id_caso"], folio=previo["folio"], estado=previo["estado"],
                          recibido_en=previo["creado_en"], reintento=True)
    fecha = datos.fecha_hecho if datos.fecha_hecho.tzinfo else datos.fecha_hecho.replace(tzinfo=timezone.utc)
    if fecha > datetime.now(timezone.utc):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "La fecha del hecho no puede ser futura")
    # Conocer un vehículo no basta: el usuario debe tener un vínculo no rechazado ni revocado.
    cur.execute("""SELECT 1 FROM vinculo_vehiculo WHERE id_usuario = %s AND id_vehiculo = %s
                    AND estado IN ('pendiente', 'autorizado')""", (usuario["id_usuario"], datos.id_vehiculo))
    if cur.fetchone() is None:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "El vehículo no está vinculado a la cuenta")
    if datos.id_organizacion is not None:
        cur.execute("SELECT 1 FROM organizacion WHERE id_organizacion = %s AND estado = 'activa'", (datos.id_organizacion,))
        if cur.fetchone() is None:
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Organización receptora no habilitada")
    folio = f"RA-{datetime.now(timezone.utc):%Y%m%d}-{secrets.token_hex(3).upper()}"
    try:
        cur.execute(
            """INSERT INTO caso(folio, id_usuario_reportante, id_vehiculo, id_organizacion, fecha_hecho, zona,
                                ubicacion, precision_m, descripcion_privada, clave_envio, tipo_incidente)
               VALUES (%s, %s, %s, %s, %s, %s, ST_SetSRID(ST_Point(%s, %s), 4326)::geography, %s, %s, %s::uuid, %s)
               RETURNING id_caso, folio, estado, creado_en""",
            (folio, usuario["id_usuario"], datos.id_vehiculo, datos.id_organizacion, fecha, datos.zona,
             datos.longitud, datos.latitud, datos.precision_m, datos.descripcion, clave, datos.tipo_incidente),
        )
    except pg8000.dbapi.DatabaseError as e:
        if "ck_caso_17" in str(e):
            # Dos envíos simultáneos con la misma clave: gana el primero.
            conn.rollback()
            cur = conn.cursor()
            cur.execute("SET search_path TO rutaalerta, public")
            previo = _caso_existente(cur, usuario["id_usuario"], clave)
            response.status_code = status.HTTP_200_OK
            return CasoSalida(id_caso=previo["id_caso"], folio=previo["folio"], estado=previo["estado"],
                              recibido_en=previo["creado_en"], reintento=True)
        raise
    caso = fila_dict(cur, cur.fetchone())
    # Evento en la misma transacción (cola transaccional): el trabajador avisará al panel.
    cur.execute(
        """INSERT INTO evento_salida(tipo, agregado_tipo, agregado_id, clave_evento, payload)
           VALUES ('caso_reportado', 'caso', %s, %s, %s::jsonb)""",
        (caso["id_caso"], f"caso_reportado:{caso['id_caso']}", json.dumps({"folio": caso["folio"]})),
    )
    return CasoSalida(id_caso=caso["id_caso"], folio=caso["folio"], estado=caso["estado"], recibido_en=caso["creado_en"])


@router.get("/casos", response_model=list[BandejaItem])
def bandeja(estado: str | None = None, prioridad: str | None = None,
            usuario=Depends(usuario_actual), conn=Depends(obtener_conexion)):
    """Sólo casos de las organizaciones donde el operador tiene membresía activa."""
    cur = conn.cursor()
    orgs = organizaciones_del_operador(cur, usuario["id_usuario"])
    if not orgs:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "La cuenta no tiene ámbito institucional")
    sql = """SELECT id_caso, id_organizacion, folio, estado, prioridad, creado_en, aportes_pendientes, primera_revision_en
               FROM v_bandeja_institucional WHERE id_organizacion = ANY(%s)"""
    params = [orgs]
    if estado:
        sql += " AND estado = %s"; params.append(estado)
    if prioridad:
        sql += " AND prioridad = %s"; params.append(prioridad)
    cur.execute(sql + " ORDER BY creado_en ASC", params)
    return [BandejaItem(**fila_dict(cur, f)) for f in cur.fetchall()]


@router.get("/casos/{id_caso}", response_model=BandejaItem)
def detalle_institucional(id_caso: int, usuario=Depends(usuario_actual), conn=Depends(obtener_conexion)):
    cur = conn.cursor()
    orgs = organizaciones_del_operador(cur, usuario["id_usuario"])
    cur.execute("""SELECT id_caso, id_organizacion, folio, estado, prioridad, creado_en, aportes_pendientes, primera_revision_en
                     FROM v_bandeja_institucional WHERE id_caso = %s""", (id_caso,))
    caso = fila_dict(cur, cur.fetchone())
    # Se responde 403 tanto si no existe como si es de otra organización, para no filtrar información (CP44).
    if caso is None or caso["id_organizacion"] not in orgs:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Caso fuera del ámbito autorizado")
    return BandejaItem(**caso)
