-- Ejecutar después de 01. Vistas internas: NO conceder acceso SQL a usuarios finales.
BEGIN;
SET LOCAL search_path=rutaalerta,public;
CREATE VIEW v_bandeja_institucional AS
SELECT c.id_caso,c.id_organizacion,c.folio,c.estado,c.prioridad,c.entorno,c.creado_en,
  a.id_membresia,
  (SELECT count(*) FROM avistamiento av WHERE av.id_caso=c.id_caso AND av.estado_revision='pendiente') AS aportes_pendientes,
  (SELECT min(g.creada_en) FROM gestion_caso g WHERE g.id_caso=c.id_caso AND g.accion='primera_revision') AS primera_revision_en
FROM caso c LEFT JOIN asignacion_caso a ON a.id_caso=c.id_caso AND a.fin IS NULL;
CREATE VIEW v_solicitudes_publicables AS
SELECT s.id_solicitud_colaboracion,s.zona_publicable,s.texto_aprobado,s.inicio,s.vence_en,
  v.patente_normalizada,v.color,m.nombre AS modelo,ma.nombre AS marca
FROM solicitud_colaboracion s JOIN caso c USING(id_caso)
JOIN vehiculo v USING(id_vehiculo) JOIN modelo m USING(id_modelo) JOIN marca ma USING(id_marca)
WHERE s.estado='publicada' AND s.inicio<=CURRENT_TIMESTAMP AND s.vence_en>CURRENT_TIMESTAMP
  AND c.estado<>'cerrado';
-- No filtra por destinatario: sólo la API autorizada puede usar esta proyección interna.
-- No contiene dirección privada, coordenadas, descripción original ni recomendaciones de búsqueda.
CREATE VIEW v_seguimiento_limitado AS
SELECT id_caso,folio,id_usuario_reportante,estado,motivo_cierre,zona,fecha_hecho,actualizado_en
FROM caso;
CREATE VIEW v_revisiones_oportunas AS
SELECT a.id_avistamiento,a.id_caso,c.id_organizacion,c.entorno,a.recibido_en,
 a.estado_revision,
 (SELECT min(r.creada_en) FROM revision_avistamiento r WHERE r.id_avistamiento=a.id_avistamiento) AS primera_decision_en,
 extract(epoch FROM ((SELECT min(r.creada_en) FROM revision_avistamiento r WHERE r.id_avistamiento=a.id_avistamiento)-a.recibido_en)) AS segundos_primera_decision
FROM avistamiento a JOIN caso c USING(id_caso);
CREATE VIEW v_casos_por_marca AS
SELECT c.id_organizacion,c.entorno,date_trunc('month',c.fecha_hecho AT TIME ZONE 'America/Santiago') AS mes,
 ma.nombre AS marca,m.nombre AS modelo,count(*) AS casos_reportados,
 count(*) FILTER (WHERE c.motivo_cierre='recuperado') AS recuperaciones_registradas
FROM caso c JOIN vehiculo v USING(id_vehiculo) JOIN modelo m USING(id_modelo) JOIN marca ma USING(id_marca)
WHERE c.id_caso_principal IS NULL AND c.motivo_cierre IS DISTINCT FROM 'duplicado'
GROUP BY c.id_organizacion,c.entorno,mes,ma.nombre,m.nombre;
-- Historial inalterable por el uso normal; el propietario de despliegue siempre conserva capacidad administrativa.
CREATE FUNCTION impedir_edicion_historial() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'El historial admite inserciones, no modificaciones ni borrado'; END $$;
CREATE TRIGGER tr_auditoria_append BEFORE UPDATE OR DELETE ON evento_auditoria FOR EACH ROW EXECUTE FUNCTION impedir_edicion_historial();
CREATE TRIGGER tr_revision_append BEFORE UPDATE OR DELETE ON revision_avistamiento FOR EACH ROW EXECUTE FUNCTION impedir_edicion_historial();
CREATE TRIGGER tr_gestion_append BEFORE UPDATE OR DELETE ON gestion_caso FOR EACH ROW EXECUTE FUNCTION impedir_edicion_historial();
CREATE TRIGGER tr_recomendacion_append BEFORE UPDATE OR DELETE ON revision_recomendacion FOR EACH ROW EXECUTE FUNCTION impedir_edicion_historial();

-- Operación transaccional. El identificador del actor DEBE proceder de la sesión autenticada de FastAPI.
-- No exponer esta función a clientes SQL ni aceptar p_revisor desde el formulario ciudadano.
CREATE FUNCTION revisar_avistamiento(p_id bigint,p_revisor bigint,p_decision text,p_motivo text)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path=rutaalerta,public AS $$
DECLARE v_caso bigint; v_org bigint; v_ahora timestamptz:=clock_timestamp();
BEGIN
 IF p_decision NOT IN ('aceptado','rechazado','requiere_aclaracion') OR p_decision IS NULL
 OR p_motivo IS NULL OR length(trim(p_motivo))=0 THEN RAISE EXCEPTION 'Decisión o motivo inválidos'; END IF;
 SELECT a.id_caso,c.id_organizacion INTO v_caso,v_org FROM avistamiento a JOIN caso c USING(id_caso)
 WHERE a.id_avistamiento=p_id FOR UPDATE OF a;
 IF NOT FOUND THEN RAISE EXCEPTION 'Avistamiento inexistente'; END IF;
 IF NOT EXISTS(SELECT 1 FROM membresia m JOIN usuario u USING(id_usuario)
 WHERE m.id_usuario=p_revisor AND u.estado='activo' AND m.id_organizacion=v_org
 AND m.estado='activa' AND m.inicio<=v_ahora AND m.fin IS NULL) THEN
 RAISE EXCEPTION 'Actor sin membresía activa en la organización del caso'; END IF;
 INSERT INTO revision_avistamiento(id_avistamiento,id_usuario_revisor,decision,motivo,creada_en)
 VALUES(p_id,p_revisor,p_decision,p_motivo,v_ahora);
 UPDATE avistamiento SET estado_revision=p_decision,revisado_por=p_revisor,revisado_en=v_ahora,motivo_revision=p_motivo
 WHERE id_avistamiento=p_id;
 INSERT INTO evento_salida(tipo,agregado_tipo,agregado_id,clave_evento,payload)
 VALUES('avistamiento_revisado','avistamiento',p_id,gen_random_uuid()::text,
 jsonb_build_object('id_caso',v_caso,'id_avistamiento',p_id,'decision',p_decision));
 INSERT INTO evento_auditoria(id_usuario,accion,objeto_tipo,objeto_id,resultado,correlacion,resumen)
 VALUES(p_revisor,'revisar_avistamiento','avistamiento',p_id::text,'exito',gen_random_uuid(),'Decisión persistida con historial');
END $$;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA rutaalerta FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA rutaalerta FROM PUBLIC;
COMMIT;
