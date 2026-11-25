BEGIN;
SET LOCAL search_path=rutaalerta,public,extensions;
CREATE TABLE IF NOT EXISTS autenticador_totp (
 id_usuario bigint PRIMARY KEY REFERENCES usuario,
 secreto_cifrado text NOT NULL,
 activo boolean NOT NULL DEFAULT false,
 ultimo_paso bigint NOT NULL DEFAULT -1,
 vence_alta_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP+interval '10 minutes',
 creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS desafio_mfa (
 id_desafio uuid PRIMARY KEY,
 id_usuario bigint NOT NULL REFERENCES usuario,
 vence_en timestamptz NOT NULL,
 intentos integer NOT NULL DEFAULT 0 CHECK(intentos>=0),
 consumido_en timestamptz
);
CREATE TABLE IF NOT EXISTS recuperacion_mfa (
 id_usuario bigint NOT NULL REFERENCES usuario,
 codigo_hash bytea NOT NULL CHECK(octet_length(codigo_hash)=32),
 consumido_en timestamptz,
 PRIMARY KEY(id_usuario,codigo_hash)
);
CREATE TABLE IF NOT EXISTS archivo_evidencia (
 id_evidencia bigint PRIMARY KEY REFERENCES evidencia,
 contenido bytea NOT NULL CHECK(octet_length(contenido) BETWEEN 1 AND 2097152)
);
ALTER TABLE caso ADD COLUMN IF NOT EXISTS colaboracion_consentida_en timestamptz;
ALTER TABLE solicitud_colaboracion ADD COLUMN IF NOT EXISTS centro_publico geography(Point,4326);
CREATE UNIQUE INDEX IF NOT EXISTS ux_solicitud_caso_vigente ON solicitud_colaboracion(id_caso) WHERE estado='publicada';
REVOKE ALL ON autenticador_totp,desafio_mfa,recuperacion_mfa,archivo_evidencia FROM PUBLIC;
COMMENT ON TABLE autenticador_totp IS 'Segundo factor RFC6238 cifrado; no acredita identidad civil';
COMMENT ON TABLE archivo_evidencia IS 'Almacenamiento privado transitorio de fotos saneadas; migrar a objetos privados al escalar';
COMMIT;
