BEGIN;
SET LOCAL search_path=rutaalerta,public,extensions;
ALTER TABLE solicitud_colaboracion ALTER COLUMN vence_en DROP NOT NULL;
CREATE OR REPLACE VIEW v_solicitudes_publicables AS
SELECT s.id_solicitud_colaboracion,s.zona_publicable,s.texto_aprobado,s.inicio,s.vence_en,
  v.patente_normalizada,v.color,m.nombre AS modelo,ma.nombre AS marca
FROM solicitud_colaboracion s JOIN caso c USING(id_caso)
JOIN vehiculo v USING(id_vehiculo) JOIN modelo m USING(id_modelo) JOIN marca ma USING(id_marca)
WHERE s.estado='publicada' AND s.suspendida_en IS NULL
    AND s.inicio<=CURRENT_TIMESTAMP AND (s.vence_en IS NULL OR s.vence_en>CURRENT_TIMESTAMP)
    AND c.estado<>'cerrado' AND c.colaboracion_consentida_en IS NOT NULL
    AND (s.id_vinculo_verificado IS NULL OR EXISTS (
        SELECT 1 FROM vinculo_vehiculo vvf JOIN usuario uf ON uf.id_usuario=vvf.id_usuario
        JOIN organizacion og ON og.id_organizacion=vvf.id_organizacion_revision
        WHERE vvf.id_vinculo_vehiculo=s.id_vinculo_verificado AND vvf.id_vehiculo=c.id_vehiculo
        AND vvf.id_usuario=c.id_usuario_reportante AND vvf.id_organizacion_revision=c.id_organizacion
        AND vvf.estado='autorizado' AND vvf.fin IS NULL AND vvf.vence_revision_en>CURRENT_TIMESTAMP
        AND uf.estado='activo' AND og.estado='activa'
    ));
COMMIT;
