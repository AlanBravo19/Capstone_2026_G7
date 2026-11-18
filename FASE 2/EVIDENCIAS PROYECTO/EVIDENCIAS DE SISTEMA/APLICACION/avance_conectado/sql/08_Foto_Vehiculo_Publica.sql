BEGIN;
SET LOCAL search_path=rutaalerta,public,extensions;
ALTER TABLE evidencia ADD COLUMN IF NOT EXISTS autorizada_publicacion_en timestamptz;
ALTER TABLE solicitud_colaboracion ADD COLUMN IF NOT EXISTS id_foto_vehiculo bigint;
DO $$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint
                WHERE conrelid='solicitud_colaboracion'::regclass
                  AND conname='fk_solicitud_foto_vehiculo_caso') THEN
  ALTER TABLE solicitud_colaboracion ADD CONSTRAINT fk_solicitud_foto_vehiculo_caso
   FOREIGN KEY (id_foto_vehiculo,id_caso) REFERENCES evidencia(id_evidencia,id_caso);
 END IF;
END $$;
COMMENT ON COLUMN evidencia.autorizada_publicacion_en IS 'Consentimiento explícito revocable del reportante; NULL mantiene la foto privada.';
COMMENT ON COLUMN solicitud_colaboracion.id_foto_vehiculo IS 'Foto del mismo caso seleccionada por el operador; su elegibilidad se revalida en cada lectura.';
COMMIT;
