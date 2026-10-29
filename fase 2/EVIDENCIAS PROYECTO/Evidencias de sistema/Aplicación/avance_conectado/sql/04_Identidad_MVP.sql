-- Incremento propuesto 29/10/2026. Ejecutar UNA VEZ después del esquema original.
-- No borra datos. Añade 3 tablas: el modelo pasa de 56 a 59 tablas en esta copia.
BEGIN;
SET LOCAL search_path=rutaalerta,public,extensions;
CREATE TABLE contacto_telefono (
    id_usuario bigint PRIMARY KEY REFERENCES usuario(id_usuario),
    telefono varchar(16) NOT NULL UNIQUE CHECK (telefono ~ '^\+[1-9][0-9]{7,14}$'),
    verificado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE contacto_telefono IS 'Número controlado por OTP; no certifica identidad civil. No se reserva sin verificar.';
CREATE TABLE desafio_telefono (
    id_desafio uuid PRIMARY KEY,
    id_usuario bigint NOT NULL REFERENCES usuario(id_usuario),
    telefono varchar(16) NOT NULL CHECK (telefono ~ '^\+[1-9][0-9]{7,14}$'),
    codigo_hmac bytea NOT NULL CHECK (octet_length(codigo_hmac)=32),
    intentos smallint NOT NULL DEFAULT 0 CHECK(intentos BETWEEN 0 AND 5),
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    vence_en timestamptz NOT NULL,
    consumido_en timestamptz NULL,
    CHECK (vence_en>creado_en)
);
CREATE INDEX ix_desafio_usuario ON desafio_telefono(id_usuario);
CREATE TABLE limite_autenticacion (
    clave bytea NOT NULL CHECK(octet_length(clave)=32),
    ventana bigint NOT NULL,
    intentos integer NOT NULL CHECK(intentos>0),
    PRIMARY KEY(clave,ventana)
);
COMMENT ON TABLE limite_autenticacion IS 'Contadores compartidos por instancias; claves HMAC, no IP ni correo en texto. Depurar ventanas vencidas.';
COMMIT;
