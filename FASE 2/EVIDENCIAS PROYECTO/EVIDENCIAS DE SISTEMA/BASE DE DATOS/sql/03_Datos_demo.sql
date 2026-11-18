-- DATOS FICTICIOS. Sólo en una base de demostración vacía. No hay contraseñas utilizables.
BEGIN;
SET LOCAL search_path=rutaalerta,public;
INSERT INTO rol(codigo,nombre) VALUES ('ciudadano','Ciudadano'),('administrador','Administrador'),('evaluador','Evaluador');
INSERT INTO usuario(nombre_visible,correo,estado) VALUES
 ('Persona de prueba A','persona-a@example.invalid','activo'),
 ('Operador de prueba','operador@example.invalid','activo'),
 ('Colaborador de prueba','colaborador@example.invalid','activo'),
 ('Contacto de prueba','contacto@example.invalid','activo'),
 ('Operador externo de prueba','externo@example.invalid','activo');
INSERT INTO usuario_rol(id_usuario,id_rol,asignado_por) VALUES(1,1,1),(2,2,2),(2,3,2),(3,1,3),(4,1,4);
INSERT INTO preferencia(id_usuario) SELECT id_usuario FROM usuario;
INSERT INTO consentimiento(id_usuario,finalidad,version_texto,otorgado_en) VALUES(1,'piloto ficticio','1',CURRENT_TIMESTAMP);
INSERT INTO dispositivo(id_usuario,instalacion_uuid,plataforma) VALUES(1,'10000000-0000-4000-8000-000000000001','android');
INSERT INTO organizacion(nombre,tipo,territorio_cobertura,estado) VALUES
 ('Central demostración Concepción','demostracion','Sector sintético','activa'),('Otra central de prueba','demostracion','Otro sector','activa');
INSERT INTO membresia(id_usuario,id_organizacion,rol,inicio) VALUES(2,1,'supervisor',CURRENT_TIMESTAMP-interval '1 day'),(5,2,'operador',CURRENT_TIMESTAMP-interval '1 day');
INSERT INTO marca(nombre) VALUES('Marca ficticia');
INSERT INTO modelo(id_marca,nombre) VALUES(1,'Modelo piloto');
INSERT INTO vehiculo(id_modelo,patente,color,anio) VALUES(1,'DEMO01','gris',2020),(1,'DEMO02','blanco',2022);
INSERT INTO vinculo_vehiculo(id_usuario,id_vehiculo,tipo) VALUES(1,1,'propietario');
INSERT INTO hecho_territorial(tipo,ocurrido_en,zona,ubicacion,precision_m,estado,validado_por,validado_en)
 VALUES('robo_vehiculo',CURRENT_TIMESTAMP-interval '1 day','Zona sintética A',ST_SetSRID(ST_Point(-73.05,-36.82),4326),30,'validado',2,CURRENT_TIMESTAMP);
INSERT INTO caso(folio,id_usuario_reportante,id_vehiculo,id_organizacion,id_hecho_territorial,fecha_hecho,zona,ubicacion,descripcion_privada,clave_envio)
 VALUES('DEMO-001',1,1,1,1,CURRENT_TIMESTAMP-interval '1 day','Zona sintética A',ST_SetSRID(ST_Point(-73.05,-36.82),4326),'Ejercicio controlado sin incidente real','20000000-0000-4000-8000-000000000001'),
 ('DEMO-002',1,2,2,NULL,CURRENT_TIMESTAMP-interval '1 day','Zona sintética B',ST_SetSRID(ST_Point(-73.06,-36.83),4326),'Otro caso ficticio','20000000-0000-4000-8000-000000000002');
INSERT INTO asignacion_caso(id_caso,id_organizacion,id_membresia,asignado_por,motivo) VALUES(1,1,1,2,'Asignación del ejercicio');
INSERT INTO gestion_caso(id_caso,id_usuario,accion,descripcion) VALUES(1,2,'primera_revision','Revisión en demostración');
INSERT INTO solicitud_colaboracion(id_caso,autorizada_por,zona_publicable,texto_aprobado,motivo_autorizacion,inicio,vence_en)
 VALUES(1,2,'Sector sintético','Vehículo ficticio DEMO01. No es una búsqueda real.','Ejercicio',CURRENT_TIMESTAMP-interval '1 hour',CURRENT_TIMESTAMP+interval '1 day');
INSERT INTO avistamiento(id_solicitud_colaboracion,id_caso,id_usuario_autor,observado_en,zona,ubicacion,descripcion,clave_envio)
 VALUES(1,1,3,CURRENT_TIMESTAMP-interval '10 min','Sector sintético',ST_SetSRID(ST_Point(-73.049,-36.819),4326),'Observación simulada','30000000-0000-4000-8000-000000000001');
INSERT INTO evidencia(id_caso,id_avistamiento,id_usuario_autor,tipo,origen,mime,clave_envio)
 VALUES(1,1,3,'foto','archivo_adjuntado','image/jpeg','40000000-0000-4000-8000-000000000001');
SELECT revisar_avistamiento(1,2,'aceptado','Antecedente útil dentro del ejercicio; no confirma recuperación');
INSERT INTO acceso_confianza(id_caso,otorgado_por,id_usuario_destinatario,vence_en) VALUES(1,1,4,CURRENT_TIMESTAMP+interval '1 day');
INSERT INTO recurso_apoyo(categoria,territorio,titulo,descripcion,canal,mantenido_por,verificado_en,vence_en)
 VALUES('orientacion','Piloto','Orientación de demostración','Recurso ficticio sin atención real','Canal de prueba',2,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP+interval '30 days');
INSERT INTO fuente_datos(nombre,procedencia,condiciones_uso,cobertura,estado) VALUES('Datos sintéticos','Equipo Grupo 7','Sólo demostración','Sector de ensayo','autorizada');
INSERT INTO lote_importacion(id_fuente_datos,importado_por,sha256,cantidad,estado) VALUES(1,2,decode(repeat('00',32),'hex'),1,'completado');
INSERT INTO registro_fuente(id_lote_importacion,id_fuente_datos,identificador_origen,id_hecho_territorial) VALUES(1,1,'sintetico-001',1);
INSERT INTO consulta_ruta(id_usuario,origen,destino,version_metodo,cobertura)
 VALUES(1,ST_SetSRID(ST_Point(-73.05,-36.82),4326),ST_SetSRID(ST_Point(-73.04,-36.81),4326),'reglas-demo-1','parcial');
INSERT INTO alternativa_ruta(id_consulta_ruta,numero,geometria,duracion_seg,distancia_m,explicacion)
 VALUES(1,1,ST_GeomFromText('LINESTRING(-73.05 -36.82,-73.04 -36.81)',4326),180,1450,'Ejemplo geométrico sin navegación real');
INSERT INTO trayecto(id_usuario,id_consulta_ruta,id_alternativa_ruta,permisos_disponibles) VALUES(1,1,1,'{"ubicacion":true}');
INSERT INTO aviso_territorial(id_trayecto,id_hecho_territorial,zona,motivo) VALUES(1,1,'Sector sintético','Antecedente histórico de prueba');
INSERT INTO notificacion(id_usuario,id_caso,tipo,titulo,mensaje,clave_deduplicacion)
 VALUES(1,1,'caso','Actualización del ejercicio','Existe una revisión del caso ficticio','demo-notificacion-001');
INSERT INTO entrega_notificacion(id_notificacion,id_usuario,id_dispositivo,canal,clave_entrega) VALUES(1,1,1,'push','demo-entrega-001');
INSERT INTO canal_derivacion(id_organizacion,institucion_destino,tipo,descripcion_canal) VALUES(1,'Institución ficticia','manual','Sin convenio ni canal real');
INSERT INTO derivacion_caso(id_caso,id_organizacion,id_canal_derivacion,id_usuario_responsable) VALUES(1,1,1,2);
INSERT INTO escenario_prueba(codigo,objetivo,version,instrucciones,resultado_esperado,datos_sinteticos)
 SELECT 'ESC-'||v,'OE'||v,1,'Realizar tarea controlada','Respuesta definida antes del ensayo','{}' FROM generate_series(1,6) v;
INSERT INTO ejecucion_prueba(id_escenario_prueba,id_usuario_evaluador,modalidad,condicion_red,dispositivo,inicio,pareja_codigo,orden_presentacion)
 VALUES(5,2,'plataforma','Local','Equipo de prueba',CURRENT_TIMESTAMP,'PAR-01',1);
INSERT INTO camara(id_organizacion,nombre,ubicacion,referencia_autorizacion,estado)
 VALUES(1,'Cámara ficticia A',ST_SetSRID(ST_Point(-73.049,-36.819),4326),'Ejercicio sin cámara municipal','disponible'),
 (2,'Cámara ficticia externa',ST_SetSRID(ST_Point(-73.06,-36.83),4326),'Ejercicio','disponible');
INSERT INTO sesion_busqueda(id_caso,id_organizacion,creada_por,version_mapa,version_metodo) VALUES(1,1,2,'sintetico-1','corredores-demo-1');
INSERT INTO observacion_busqueda(id_sesion_busqueda,id_caso,id_organizacion,id_avistamiento,origen,observado_en,ubicacion,precision_m)
 VALUES(1,1,1,1,'avistamiento',CURRENT_TIMESTAMP-interval '10 min',ST_SetSRID(ST_Point(-73.049,-36.819),4326),30);
UPDATE sesion_busqueda SET id_observacion_ancla=1 WHERE id_sesion_busqueda=1;
INSERT INTO hipotesis_ruta(id_sesion_busqueda,id_observacion_ancla,version,geometria,desde,hasta,supuestos,factores,motivo_actualizacion)
 VALUES(1,1,1,ST_GeomFromText('MULTILINESTRING((-73.049 -36.819,-73.04 -36.81))',4326),CURRENT_TIMESTAMP-interval '10 min',CURRENT_TIMESTAMP,'{"demostracion":true}','{}','Hipótesis inicial ficticia');
INSERT INTO recomendacion_camara(id_hipotesis_ruta,id_sesion_busqueda,id_camara,id_organizacion,desde,hasta,prioridad,factores,disponibilidad)
 VALUES(1,1,1,1,CURRENT_TIMESTAMP-interval '10 min',CURRENT_TIMESTAMP,10,'{"criterio":"ensayo"}','sin_confirmar');
INSERT INTO revision_recomendacion(id_recomendacion_camara,id_usuario,decision,motivo) VALUES(1,2,'aceptar_revision','Revisar en escenario de ensayo');
INSERT INTO consulta_video(id_caso,id_organizacion,id_camara,id_usuario,modalidad,desde,hasta,resultado,motivo)
 VALUES(1,1,1,2,'simulacion',CURRENT_TIMESTAMP-interval '10 min',CURRENT_TIMESTAMP,'autorizado','Ejercicio sin transmisión real');
INSERT INTO version_modelo(nombre,version,sha256,licencia,finalidad,limitaciones)
 VALUES('Modelo ficticio','demo-1',decode(repeat('11',32),'hex'),'No aplica a pesos reales','Demostrar persistencia','No ejecuta IA');
INSERT INTO ejecucion_modelo(id_sesion_busqueda,id_version_modelo,id_evidencia_referencia,id_caso) VALUES(1,1,1,1);
INSERT INTO candidato_visual(id_ejecucion_modelo,id_sesion_busqueda,id_caso,id_evidencia,rango,puntaje,factores)
 VALUES(1,1,1,1,1,0.65,'{"simulado":true}');
INSERT INTO consulta_copiloto(id_sesion_busqueda,id_usuario,pregunta) VALUES(1,2,'¿Qué antecedente revisar en el ejercicio?');
INSERT INTO afirmacion_copiloto(id_consulta_copiloto,id_sesion_busqueda,orden,texto,tipo)
 VALUES(1,1,1,'Revisar la cámara ficticia A','hipotesis');
INSERT INTO soporte_afirmacion(id_afirmacion_copiloto,id_sesion_busqueda,id_recomendacion_camara) VALUES(1,1,1);
INSERT INTO version_indicador(codigo,version,nombre,definicion,numerador_def,denominador_def,unidad,fuentes,limitaciones)
 VALUES('CASOS',1,'Casos reportados','Cantidad de casos distintos en el período','Casos sin duplicados','No aplica a conteo','casos','caso','No mide incidencia poblacional');
INSERT INTO consulta_indicador(id_version_indicador,id_usuario,id_organizacion,periodo_desde,periodo_hasta,filtros,numerador,resultado,estado)
 VALUES(1,2,1,CURRENT_TIMESTAMP-interval '30 days',CURRENT_TIMESTAMP,'{"entorno":"prueba"}',1,'{"casos":1}','calculado');
COMMIT;
