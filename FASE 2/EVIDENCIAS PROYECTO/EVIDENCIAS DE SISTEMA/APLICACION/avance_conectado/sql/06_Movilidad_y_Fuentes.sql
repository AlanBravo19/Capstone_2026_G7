BEGIN;
SET LOCAL search_path=rutaalerta,public,extensions;
CREATE TABLE IF NOT EXISTS lugar_guardado (
 id_usuario bigint NOT NULL REFERENCES usuario,
 tipo text NOT NULL CHECK(tipo IN ('casa','trabajo','favorito')),
 nombre varchar(100) NOT NULL,
 direccion varchar(300) NOT NULL DEFAULT '',
 ubicacion geography(Point,4326),
 activo boolean NOT NULL DEFAULT true,
 actualizado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY(id_usuario,tipo),
 CHECK(NOT activo OR ubicacion IS NOT NULL)
);
CREATE TABLE IF NOT EXISTS antecedente_publico (
 id_antecedente uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 id_organizacion bigint NOT NULL REFERENCES organizacion,
 url_fuente varchar(1500) NOT NULL UNIQUE,
 nombre_fuente varchar(150) NOT NULL,
 titulo varchar(250) NOT NULL,
 resumen varchar(700) NOT NULL,
 tipo text NOT NULL CHECK(tipo IN ('portonazo','encerrona','robo_vehiculo','otro')),
 fecha_publicacion date NOT NULL,
 fecha_hecho date,
 zona varchar(200) NOT NULL,
 centro geography(Point,4326),
 precision_m integer NOT NULL DEFAULT 1000 CHECK(precision_m BETWEEN 100 AND 10000),
 radio_m integer NOT NULL DEFAULT 1500 CHECK(radio_m BETWEEN 100 AND 15000),
 vence_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP+interval '90 days',
 estado text NOT NULL DEFAULT 'pendiente' CHECK(estado IN ('pendiente','validado','descartado')),
 revisado_por bigint REFERENCES usuario,
 revisado_en timestamptz,
 motivo_revision varchar(1000),
 entorno text NOT NULL DEFAULT 'operacion' CHECK(entorno IN ('prueba','operacion')),
 creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CHECK(radio_m>=precision_m),
 CHECK(estado<>'validado' OR (centro IS NOT NULL AND revisado_por IS NOT NULL AND revisado_en IS NOT NULL AND length(trim(motivo_revision))>=10)),
 CHECK(fecha_hecho IS NULL OR fecha_hecho<=fecha_publicacion)
);
CREATE INDEX IF NOT EXISTS ix_antecedente_centro ON antecedente_publico USING gist(centro);
ALTER TABLE usuario ADD COLUMN IF NOT EXISTS canal_correo_verificado text NOT NULL DEFAULT 'prueba' CHECK(canal_correo_verificado IN ('prueba','smtp','brevo'));
ALTER TABLE contacto_telefono ADD COLUMN IF NOT EXISTS canal_verificado text NOT NULL DEFAULT 'prueba' CHECK(canal_verificado IN ('prueba','sms'));
REVOKE ALL ON lugar_guardado,antecedente_publico FROM PUBLIC;
COMMENT ON TABLE lugar_guardado IS 'Destinos privados; retirar limpia coordenada y dirección. No se publican ni se usan como incidentes.';
COMMENT ON TABLE antecedente_publico IS 'Ficha editorial con enlace y resumen propio. La validación confirma el tratamiento de la fuente y su localización, no certifica el delito ni una frecuencia.';
COMMIT;
