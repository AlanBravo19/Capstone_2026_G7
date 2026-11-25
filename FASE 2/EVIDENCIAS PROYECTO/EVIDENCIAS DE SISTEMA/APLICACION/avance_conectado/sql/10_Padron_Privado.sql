BEGIN;
SET LOCAL search_path=rutaalerta,public,extensions;

CREATE TABLE IF NOT EXISTS documento_vinculo_vehiculo (
    id_vinculo_vehiculo bigint PRIMARY KEY REFERENCES vinculo_vehiculo,
    recibido_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    contenido bytea CHECK (octet_length(contenido) BETWEEN 1 AND 2097152)
);
REVOKE ALL ON documento_vinculo_vehiculo FROM PUBLIC;
ALTER TABLE documento_vinculo_vehiculo ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ra_api') THEN
        GRANT SELECT,INSERT,UPDATE ON documento_vinculo_vehiculo TO ra_api;
        DROP POLICY IF EXISTS acceso_api_padron ON documento_vinculo_vehiculo;
        CREATE POLICY acceso_api_padron ON documento_vinculo_vehiculo TO ra_api USING (true) WITH CHECK (true);
    END IF;
END $$;
COMMIT;
