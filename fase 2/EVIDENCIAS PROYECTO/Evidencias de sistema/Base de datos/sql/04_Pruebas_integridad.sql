-- Ejecutar después de 01, 02 y 03 en la base de DEMOSTRACIÓN.
-- Cada prueba negativa debe ser rechazada por el código SQLSTATE indicado.
-- Las operaciones se revierten. Las secuencias pueden avanzar aunque se revierta una transacción.
BEGIN;
SET LOCAL search_path=rutaalerta,public;
CREATE TEMP TABLE resultado_pruebas (prueba text,resultado text);
DO $prueba$ BEGIN
 BEGIN
  INSERT INTO usuario(nombre_visible,correo) VALUES('Duplicado',' PERSONA-A@EXAMPLE.INVALID ');
  RAISE EXCEPTION 'FALLO: se aceptó T01 correo normalizado único';
 EXCEPTION WHEN SQLSTATE '23505' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T01 correo normalizado único','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  INSERT INTO vehiculo(id_modelo,patente,color) VALUES(1,'de-mo01','gris');
  RAISE EXCEPTION 'FALLO: se aceptó T02 patente normalizada única';
 EXCEPTION WHEN SQLSTATE '23505' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T02 patente normalizada única','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  INSERT INTO vehiculo(id_modelo,color) VALUES(999999,'gris');
  RAISE EXCEPTION 'FALLO: se aceptó T03 referencia a modelo inexistente';
 EXCEPTION WHEN SQLSTATE '23503' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T03 referencia a modelo inexistente','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  INSERT INTO asignacion_caso(id_caso,id_organizacion,id_membresia,asignado_por,motivo) VALUES(2,2,1,2,'Inválida');
  RAISE EXCEPTION 'FALLO: se aceptó T04 asignación de organización ajena';
 EXCEPTION WHEN SQLSTATE '23503' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T04 asignación de organización ajena','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  INSERT INTO asignacion_caso(id_caso,id_organizacion,id_membresia,asignado_por,motivo) VALUES(1,1,1,2,'Repetida');
  RAISE EXCEPTION 'FALLO: se aceptó T05 una asignación vigente por caso';
 EXCEPTION WHEN SQLSTATE '23505' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T05 una asignación vigente por caso','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  INSERT INTO evidencia(id_caso,id_avistamiento,id_usuario_autor,tipo,origen,mime,clave_envio) VALUES(2,1,3,'foto','archivo_adjuntado','image/jpeg','40000000-0000-4000-8000-000000000099');
  RAISE EXCEPTION 'FALLO: se aceptó T06 evidencia no puede mezclar casos';
 EXCEPTION WHEN SQLSTATE '23503' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T06 evidencia no puede mezclar casos','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  UPDATE evidencia SET estado_carga='recibido' WHERE id_evidencia=1;
  RAISE EXCEPTION 'FALLO: se aceptó T07 fotografía recibida requiere metadatos';
 EXCEPTION WHEN SQLSTATE '23514' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T07 fotografía recibida requiere metadatos','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  UPDATE evidencia SET sha256=decode('00','hex') WHERE id_evidencia=1;
  RAISE EXCEPTION 'FALLO: se aceptó T08 hash debe tener 32 bytes';
 EXCEPTION WHEN SQLSTATE '23514' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T08 hash debe tener 32 bytes','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  INSERT INTO acceso_confianza(id_caso,otorgado_por,id_usuario_destinatario,vence_en) VALUES(1,1,1,CURRENT_TIMESTAMP+interval '1 day');
  RAISE EXCEPTION 'FALLO: se aceptó T09 confianza no se concede al mismo usuario';
 EXCEPTION WHEN SQLSTATE '23514' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T09 confianza no se concede al mismo usuario','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  INSERT INTO acceso_confianza(id_caso,otorgado_por,id_usuario_destinatario,vence_en) VALUES(1,1,4,CURRENT_TIMESTAMP-interval '1 day');
  RAISE EXCEPTION 'FALLO: se aceptó T10 confianza requiere vencimiento posterior';
 EXCEPTION WHEN SQLSTATE '23514' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T10 confianza requiere vencimiento posterior','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  UPDATE revision_avistamiento SET motivo='Reescrito' WHERE id_revision_avistamiento=1;
  RAISE EXCEPTION 'FALLO: se aceptó T11 historial de revisión no se sobrescribe';
 EXCEPTION WHEN SQLSTATE 'P0001' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T11 historial de revisión no se sobrescribe','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  INSERT INTO consulta_video(id_caso,id_organizacion,id_camara,id_usuario,modalidad,desde,resultado,motivo) VALUES(1,1,2,2,'en_vivo',CURRENT_TIMESTAMP,'autorizado','Ensayo');
  RAISE EXCEPTION 'FALLO: se aceptó T12 cámara ajena no se consulta dentro del caso';
 EXCEPTION WHEN SQLSTATE '23503' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T12 cámara ajena no se consulta dentro del caso','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  INSERT INTO soporte_afirmacion(id_afirmacion_copiloto,id_sesion_busqueda,id_observacion_busqueda,id_candidato_visual) VALUES(1,1,1,1);
  RAISE EXCEPTION 'FALLO: se aceptó T13 una fuente por soporte de afirmación';
 EXCEPTION WHEN SQLSTATE '23514' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T13 una fuente por soporte de afirmación','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  INSERT INTO soporte_afirmacion(id_afirmacion_copiloto,id_sesion_busqueda) VALUES(1,1);
  RAISE EXCEPTION 'FALLO: se aceptó T14 soporte no puede quedar sin destino';
 EXCEPTION WHEN SQLSTATE '23514' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T14 soporte no puede quedar sin destino','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  UPDATE candidato_visual SET id_caso=2 WHERE id_candidato_visual=1;
  RAISE EXCEPTION 'FALLO: se aceptó T15 candidato no mezcla evidencia de otro caso';
 EXCEPTION WHEN SQLSTATE '23503' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T15 candidato no mezcla evidencia de otro caso','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  UPDATE candidato_visual SET rango=-1 WHERE id_candidato_visual=1;
  RAISE EXCEPTION 'FALLO: se aceptó T16 rango visual no puede ser negativo';
 EXCEPTION WHEN SQLSTATE '23514' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T16 rango visual no puede ser negativo','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  UPDATE candidato_visual SET decision='compatible',revisado_por=2,revisado_en=CURRENT_TIMESTAMP WHERE id_candidato_visual=1;
  RAISE EXCEPTION 'FALLO: se aceptó T17 decisión de candidato exige motivo';
 EXCEPTION WHEN SQLSTATE '23514' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T17 decisión de candidato exige motivo','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  SELECT revisar_avistamiento(1,5,'aceptado','Actor ajeno');
  RAISE EXCEPTION 'FALLO: se aceptó T18 revisión exige miembro de la organización';
 EXCEPTION WHEN SQLSTATE 'P0001' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T18 revisión exige miembro de la organización','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  INSERT INTO entrega_notificacion(id_notificacion,id_usuario,id_dispositivo,canal,clave_entrega) VALUES(1,4,1,'push','invalida');
  RAISE EXCEPTION 'FALLO: se aceptó T19 no se envía push a dispositivo de otro usuario';
 EXCEPTION WHEN SQLSTATE '23503' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T19 no se envía push a dispositivo de otro usuario','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  UPDATE avistamiento SET observado_en=CURRENT_TIMESTAMP+interval '1 day' WHERE id_avistamiento=1;
  RAISE EXCEPTION 'FALLO: se aceptó T20 avistamiento futuro rechazado';
 EXCEPTION WHEN SQLSTATE '23514' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T20 avistamiento futuro rechazado','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  UPDATE hipotesis_ruta SET hasta=desde WHERE id_hipotesis_ruta=1;
  RAISE EXCEPTION 'FALLO: se aceptó T21 hipótesis necesita ventana temporal positiva';
 EXCEPTION WHEN SQLSTATE '23514' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T21 hipótesis necesita ventana temporal positiva','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  UPDATE caso SET estado='cerrado' WHERE id_caso=1;
  RAISE EXCEPTION 'FALLO: se aceptó T22 cerrar caso requiere motivo y fecha';
 EXCEPTION WHEN SQLSTATE '23514' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T22 cerrar caso requiere motivo y fecha','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  UPDATE alternativa_ruta SET exposicion_relativa=0.5 WHERE id_alternativa_ruta=1;
  RAISE EXCEPTION 'FALLO: se aceptó T23 ruta no publica exposición con datos insuficientes';
 EXCEPTION WHEN SQLSTATE '23514' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T23 ruta no publica exposición con datos insuficientes','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  UPDATE caso SET id_caso_principal=1 WHERE id_caso=1;
  RAISE EXCEPTION 'FALLO: se aceptó T24 se impide autorreferencia de caso duplicado';
 EXCEPTION WHEN SQLSTATE '23514' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T24 se impide autorreferencia de caso duplicado','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  UPDATE alternativa_ruta SET geometria=ST_GeomFromText('LINESTRING(0 0,1 1)',3857) WHERE id_alternativa_ruta=1;
  RAISE EXCEPTION 'FALLO: se aceptó T25 geometría exige SRID declarado';
 EXCEPTION WHEN SQLSTATE '22023' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T25 geometría exige SRID declarado','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  INSERT INTO soporte_afirmacion(id_afirmacion_copiloto,id_sesion_busqueda,id_observacion_busqueda) VALUES(1,999,1);
  RAISE EXCEPTION 'FALLO: se aceptó T26 destino de soporte pertenece a la misma sesión';
 EXCEPTION WHEN SQLSTATE '23503' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T26 destino de soporte pertenece a la misma sesión','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  UPDATE consulta_indicador SET periodo_hasta=periodo_desde WHERE id_consulta_indicador=1;
  RAISE EXCEPTION 'FALLO: se aceptó T27 consulta de indicador exige intervalo';
 EXCEPTION WHEN SQLSTATE '23514' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T27 consulta de indicador exige intervalo','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  INSERT INTO escenario_prueba(codigo,objetivo,version,instrucciones,resultado_esperado,datos_sinteticos) VALUES('invalido','OE7',1,'x','x','{}');
  RAISE EXCEPTION 'FALLO: se aceptó T28 estado de objetivo admite OE5 y OE6';
 EXCEPTION WHEN SQLSTATE '23514' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T28 estado de objetivo admite OE5 y OE6','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  UPDATE caso SET estado='cerrado',motivo_cierre='recuperado',cerrado_en=CURRENT_TIMESTAMP WHERE id_caso=1;
  RAISE EXCEPTION 'FALLO: se aceptó T35 recuperación requiere fecha y respaldo';
 EXCEPTION WHEN SQLSTATE '23514' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T35 recuperación requiere fecha y respaldo','CORRECTO');
 END;
END $prueba$;
DO $prueba$ BEGIN
 BEGIN
  UPDATE caso SET estado='cerrado',motivo_cierre='recuperado',cerrado_en=CURRENT_TIMESTAMP,recuperado_en=CURRENT_TIMESTAMP,id_evidencia_recuperacion=1 WHERE id_caso=2;
  RAISE EXCEPTION 'FALLO: se aceptó T36 respaldo de recuperación pertenece al caso';
 EXCEPTION WHEN SQLSTATE '23503' THEN
  IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
  INSERT INTO resultado_pruebas VALUES ('T36 respaldo de recuperación pertenece al caso','CORRECTO');
 END;
END $prueba$;
DO $prueba$ DECLARE d double precision; BEGIN
 SELECT ST_Distance(ST_SetSRID(ST_Point(0,0),4326)::geography,ST_SetSRID(ST_Point(0,0.001),4326)::geography) INTO d;
 IF d NOT BETWEEN 110 AND 112 THEN RAISE EXCEPTION 'FALLO: distancia geográfica inesperada %',d; END IF;
 INSERT INTO resultado_pruebas VALUES ('T29 distancia PostGIS en metros','CORRECTO');
 IF NOT ST_Intersects(ST_GeomFromText('LINESTRING(0 0,2 2)',4326),ST_GeomFromText('POLYGON((0 0,1 0,1 1,0 1,0 0))',4326)) THEN RAISE EXCEPTION 'FALLO: intersección'; END IF;
 INSERT INTO resultado_pruebas VALUES ('T30 cruce de geometrías','CORRECTO');
 IF (SELECT count(*) FROM information_schema.tables WHERE table_schema='rutaalerta' AND table_type='BASE TABLE')<>56 THEN RAISE EXCEPTION 'FALLO: número de tablas'; END IF;
 INSERT INTO resultado_pruebas VALUES ('T31 56 tablas creadas','CORRECTO');
 IF (SELECT count(*) FROM pg_constraint WHERE connamespace='rutaalerta'::regnamespace AND contype='f')<>110 THEN RAISE EXCEPTION 'FALLO: número de FK'; END IF;
 INSERT INTO resultado_pruebas VALUES ('T32 110 claves foráneas creadas','CORRECTO');
 IF NOT EXISTS(SELECT 1 FROM evento_salida WHERE tipo='avistamiento_revisado') OR NOT EXISTS(SELECT 1 FROM revision_avistamiento) THEN RAISE EXCEPTION 'FALLO: revisión incompleta'; END IF;
 INSERT INTO resultado_pruebas VALUES ('T33 revisión con historial y evento transaccional','CORRECTO');
 IF NOT EXISTS(SELECT 1 FROM escenario_prueba WHERE objetivo='OE6') THEN RAISE EXCEPTION 'FALLO: OE6'; END IF;
 INSERT INTO resultado_pruebas VALUES ('T34 objetivos ampliados presentes','CORRECTO');
END $prueba$;
SELECT * FROM resultado_pruebas ORDER BY prueba;
ROLLBACK;