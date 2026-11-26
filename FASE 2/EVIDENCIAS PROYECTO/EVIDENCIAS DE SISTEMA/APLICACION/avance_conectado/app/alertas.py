"""Reglas de publicación que comparten el alta, la lectura y la revisión."""
from datetime import datetime, timedelta, timezone

from .config import config

# Además del vencimiento por reloj, una publicación provisional pierde difusión
# al perder el vínculo que la habilitó. La consulta también se usa para fotos y aportes.
VIGENTE = """s.estado='publicada' AND s.suspendida_en IS NULL
    AND s.inicio<=CURRENT_TIMESTAMP AND (s.vence_en IS NULL OR s.vence_en>CURRENT_TIMESTAMP)
    AND c.estado<>'cerrado' AND c.colaboracion_consentida_en IS NOT NULL
    AND (s.id_vinculo_verificado IS NULL OR EXISTS (
        SELECT 1 FROM vinculo_vehiculo vvf JOIN usuario uf ON uf.id_usuario=vvf.id_usuario
        JOIN organizacion og ON og.id_organizacion=vvf.id_organizacion_revision
        WHERE vvf.id_vinculo_vehiculo=s.id_vinculo_verificado AND vvf.id_vehiculo=c.id_vehiculo
        AND vvf.id_usuario=c.id_usuario_reportante AND vvf.id_organizacion_revision=c.id_organizacion
        AND vvf.estado='autorizado' AND vvf.fin IS NULL AND vvf.vence_revision_en>CURRENT_TIMESTAMP
        AND uf.estado='activo' AND og.estado='activa'
    ))"""

def entorno():
    return 'operacion' if config.entorno == 'operacion' else 'prueba'

def vinculo_vigente(cur, usuario, vehiculo, organizacion):
    cur.execute("""SELECT vv.id_vinculo_vehiculo FROM vinculo_vehiculo vv
        JOIN usuario u USING(id_usuario) WHERE vv.id_usuario=%s AND vv.id_vehiculo=%s
        AND vv.id_organizacion_revision=%s AND vv.estado='autorizado' AND vv.fin IS NULL
        AND vv.vence_revision_en>CURRENT_TIMESTAMP AND u.estado='activo'""",
        (usuario, vehiculo, organizacion))
    fila = cur.fetchone()
    return fila[0] if fila else None

def publicar_provisional(cur, caso, datos, usuario, ambiente):
    from .routers.colaboracion import aviso, bitacora
    from .routers.recursos_territorio import COMUNAS, normalizar
    cid, org, vehiculo = caso['id_caso'], datos.id_organizacion, datos.id_vehiculo
    if not datos.solicitar_colaboracion:
        return 'privada', 'Puedes autorizar colaboración desde el seguimiento.'
    causas = []
    if not config.alertas_automaticas:
        causas.append('Publicación automática deshabilitada')
    vinculo = vinculo_vigente(cur, usuario, vehiculo, org)
    if not vinculo:
        causas.append('Vínculo sin aprobación vigente en la organización receptora')
    cur.execute("""SELECT 1 FROM organizacion o WHERE o.id_organizacion=%s
        AND o.estado='activa' AND o.alertas_provisionales_habilitadas AND EXISTS (
          SELECT 1 FROM membresia m JOIN usuario u USING(id_usuario)
          WHERE m.id_organizacion=o.id_organizacion AND m.estado='activa' AND m.fin IS NULL
          AND m.inicio<=CURRENT_TIMESTAMP AND u.estado='activo' AND u.id_usuario<>%s)""",(org,usuario))
    if not cur.fetchone():
        causas.append('Organización sin revisión operativa habilitada')
    cur.execute("""SELECT id_usuario_reportante,folio FROM caso WHERE id_vehiculo=%s AND entorno=%s
        AND id_caso<>%s AND estado<>'cerrado'
        ORDER BY (id_usuario_reportante=%s) DESC,id_caso DESC LIMIT 1""",(vehiculo,ambiente,cid,usuario))
    expediente = cur.fetchone()
    if expediente:
        causas.append('Existe otro expediente activo del vehículo')
    fecha = datos.fecha_hecho
    if fecha.tzinfo is None:
        fecha = fecha.replace(tzinfo=timezone.utc)
    if fecha < datetime.now(timezone.utc) - timedelta(hours=24):
        causas.append('El hecho fue informado con más de 24 horas de antigüedad')
    if not causas:
        # Serializa la cuota por cuenta también si reporta vehículos distintos.
        cur.execute("SELECT pg_advisory_xact_lock(hashtextextended(%s,0))",
                    (f'rutaalerta:publicacion_provisional:{usuario}',))
        cur.execute("""SELECT 1 FROM gestion_caso g JOIN caso c USING(id_caso)
            WHERE c.id_usuario_reportante=%s AND c.entorno=%s AND g.accion='publicacion_provisional'
            AND g.creada_en>CURRENT_TIMESTAMP-interval '24 hours' LIMIT 1""",(usuario,ambiente))
        if cur.fetchone():
            causas.append('Ya se difundió una provisional para la cuenta en las últimas 24 horas')
    if causas:
        cur.execute("UPDATE caso SET prioridad='alta' WHERE id_caso=%s",(cid,))
        bitacora(cur,cid,usuario,'prioridad_alerta',' · '.join(causas),'interna')
        if expediente and expediente[0] == usuario:
            return 'pendiente', f'Ya tienes el expediente {expediente[1]} abierto para este vehículo. Consulta su seguimiento.'
        if not vinculo:
            return 'pendiente', 'La organización receptora revisará el vínculo con el vehículo antes de publicarlo.'
        return 'pendiente', 'La organización revisará el reporte antes de publicarlo.'

    # Solo se publican texto fijo, comuna reconocida y centro aproximado.
    # El relato, dirección y foto requieren revisión humana.
    nombre = normalizar(datos.zona.split(' · ', 1)[0])
    zona = next((comuna for comuna in COMUNAS.values() if normalizar(comuna)==nombre),'Sector aproximado')
    motivo = 'Cuenta habilitada, vínculo vigente, consentimiento, revisión receptora, incidente reciente y sin duplicados activos.'
    cur.execute("""INSERT INTO solicitud_colaboracion
        (id_caso,autorizada_por,zona_publicable,texto_aprobado,motivo_autorizacion,inicio,
         vence_en,centro_publico,modo_alerta,id_vinculo_verificado)
        SELECT id_caso,%s,%s,%s,%s,CURRENT_TIMESTAMP,
        NULL,ST_SnapToGrid(ubicacion::geometry,0.02)::geography,
        'provisional',%s FROM caso WHERE id_caso=%s RETURNING id_solicitud_colaboracion""",
        (usuario,zona,'Sustracción reportada por una persona con vínculo revisado.',motivo,
         vinculo,cid))
    sid = cur.fetchone()[0]
    cur.execute("UPDATE caso SET prioridad='alta',revision_alerta=revision_alerta+1 WHERE id_caso=%s",(cid,))
    bitacora(cur,cid,usuario,'publicacion_provisional',motivo,'interna')
    aviso(cur,usuario,cid,'Alerta provisional publicada','La organización revisará el caso y el encargo policial.',f'provisional:{sid}')
    avisar_equipo(cur,org,cid,'Alerta provisional nueva','Revisa el expediente y registra la consulta del encargo.',f'provisional:{sid}')
    return 'provisional', 'Alerta publicada en Colaborar hasta el cierre o la recuperación. Puedes retirar tu autorización desde Mis casos.'

def avisar_equipo(cur, org, cid, titulo, mensaje, clave):
    cur.execute("""INSERT INTO notificacion(id_usuario,id_caso,tipo,titulo,mensaje,clave_deduplicacion)
        SELECT DISTINCT m.id_usuario,%s,'caso',%s,%s,%s FROM membresia m JOIN usuario u USING(id_usuario)
        WHERE m.id_organizacion=%s AND m.estado='activa' AND m.fin IS NULL
        AND m.inicio<=CURRENT_TIMESTAMP AND u.estado='activo' ON CONFLICT DO NOTHING""",
        (cid,titulo,mensaje,clave,org))
