BEGIN;
SET LOCAL search_path=rutaalerta,public,extensions;
ALTER TABLE usuario ADD COLUMN IF NOT EXISTS modalidad_ciudadana text
 CHECK (modalidad_ciudadana IN ('colaborador','con_vehiculo'));
CREATE TABLE IF NOT EXISTS aviso_testigo (
 id_aviso uuid PRIMARY KEY,
 id_usuario bigint NOT NULL REFERENCES usuario,
 id_organizacion bigint NOT NULL REFERENCES organizacion,
 clave_envio uuid NOT NULL,
 perspectiva text NOT NULL CHECK (perspectiva IN ('pasajero','testigo')),
 observado_en timestamptz NOT NULL,
 zona varchar(200) NOT NULL,
 descripcion text NOT NULL,
 patente_observada varchar(6),
 recibido_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 estado text NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente','asociado','revisado','descartado')),
 revisado_por bigint REFERENCES usuario,
 revisado_en timestamptz,
 motivo_revision varchar(500),
 id_caso bigint,
 UNIQUE (id_usuario,clave_envio),
 FOREIGN KEY (id_caso,id_organizacion) REFERENCES caso(id_caso,id_organizacion),
 CHECK ((estado='asociado')=(id_caso IS NOT NULL)),
 CHECK ((estado='pendiente' AND revisado_por IS NULL AND revisado_en IS NULL AND motivo_revision IS NULL)
     OR (estado<>'pendiente' AND revisado_por IS NOT NULL AND revisado_en IS NOT NULL AND motivo_revision IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS ix_aviso_testigo_bandeja ON aviso_testigo(id_organizacion,estado,recibido_en DESC);
COMMIT;
