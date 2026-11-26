BEGIN;
SET LOCAL search_path=rutaalerta,public,extensions;
ALTER TABLE documento_vinculo_vehiculo ADD COLUMN IF NOT EXISTS tipo_documento text NOT NULL DEFAULT 'padron'
    CHECK (tipo_documento IN ('padron','permiso_circulacion'));
COMMIT;
