from typing import Literal
from uuid import uuid4

from fastapi import HTTPException
from pydantic import BaseModel, ConfigDict, Field

from .imagenes import limpiar_imagen
from . import prelectura_padron


class SolicitarRevision(BaseModel):
    model_config = ConfigDict(extra='forbid')
    id_organizacion: int = Field(gt=0)
    padron_base64: str | None = Field(default=None, min_length=16, max_length=2796204)
    tipo_documento: Literal['padron','permiso_circulacion'] = 'padron'
    autorizar_prelectura: bool = False


class RevisionConPadron(SolicitarRevision):
    padron_base64: str = Field(min_length=16, max_length=2796204)


def auditar_vinculo(cur, uid, vinculo, accion, motivo):
    cur.execute("""INSERT INTO evento_auditoria(id_usuario,accion,objeto_tipo,objeto_id,resultado,correlacion,resumen)
        VALUES(%s,%s,'vinculo_vehiculo',%s,'exito',%s,%s)""",
        (uid, accion, str(vinculo), uuid4(), motivo))


def preparar_padron(datos, patente, *, cotejar=True):
    if not datos or datos.padron_base64 is None:
        return None, None
    try:
        imagen = limpiar_imagen(datos.padron_base64, lado_maximo=2400)
    except ValueError:
        raise HTTPException(422, 'Adjunta una imagen legible del documento en JPEG, PNG o WebP, de hasta 2 MB.') from None
    if not (datos.tipo_documento == 'padron' and cotejar and datos.autorizar_prelectura and prelectura_padron.operativa()):
        return imagen, None
    try:
        lectura = prelectura_padron.leer(imagen)
    except HTTPException:
        return imagen, 'inconclusa'
    resultado = prelectura_padron.cotejar(lectura, patente)
    if resultado == 'difiere':
        raise HTTPException(422, 'La patente leída no coincide. Revisa el archivo y la patente ingresada. '
                                 'Si son correctos, vuelve a enviar el padrón para revisión directa del supervisor.')
    return imagen, resultado


def guardar_solicitud(cur, uid, vinculo, organizacion_actual, datos, imagen, prelectura):
    if organizacion_actual is not None and organizacion_actual != datos.id_organizacion:
        raise HTTPException(409, 'La solicitud ya está en otra organización. Coordina el cambio con su supervisor.')
    cur.execute('SELECT 1 FROM organizacion WHERE id_organizacion=%s AND estado=\'activa\'', (datos.id_organizacion,))
    if not cur.fetchone():
        raise HTTPException(422, 'Organización receptora no disponible.')
    if imagen is not None:
        cur.execute('SELECT contenido,tipo_documento FROM documento_vinculo_vehiculo WHERE id_vinculo_vehiculo=%s', (vinculo,))
        existente = cur.fetchone()
        if existente:
            if existente == (imagen, datos.tipo_documento):
                return
            raise HTTPException(409, 'El documento ya está en revisión. Si debes corregirlo, contacta al supervisor.')
        cur.execute('''INSERT INTO documento_vinculo_vehiculo(id_vinculo_vehiculo,contenido,tipo_documento)
            VALUES(%s,%s,%s)''', (vinculo, imagen, datos.tipo_documento))
    if organizacion_actual is None:
        cur.execute('UPDATE vinculo_vehiculo SET id_organizacion_revision=%s WHERE id_vinculo_vehiculo=%s',
                    (datos.id_organizacion, vinculo))
    if organizacion_actual is None or imagen is not None:
        auditar_vinculo(cur, uid, vinculo, 'solicitar_revision',
                       f'Documento privado recibido: {datos.tipo_documento}.' if imagen is not None else 'Revisión documental solicitada.')
    if prelectura is not None:
        auditar_vinculo(cur, uid, vinculo, 'prelectura_padron', prelectura)
    if imagen is not None:
        cur.execute('''INSERT INTO notificacion(id_usuario,tipo,titulo,mensaje,clave_deduplicacion)
            SELECT DISTINCT m.id_usuario,'general',%s,
                'Abre Verificar vínculos en Operaciones para revisar la solicitud.',%s
            FROM membresia m JOIN usuario u USING(id_usuario)
            WHERE m.id_organizacion=%s AND m.rol='supervisor' AND m.estado='activa'
                AND m.fin IS NULL AND m.inicio<=CURRENT_TIMESTAMP AND u.estado='activo' AND m.id_usuario<>%s
            ON CONFLICT(id_usuario,clave_deduplicacion) DO NOTHING''',
                    ('Permiso de circulación pendiente de revisión' if datos.tipo_documento == 'permiso_circulacion' else 'Padrón pendiente de revisión', f'padron:{vinculo}', datos.id_organizacion, uid))
