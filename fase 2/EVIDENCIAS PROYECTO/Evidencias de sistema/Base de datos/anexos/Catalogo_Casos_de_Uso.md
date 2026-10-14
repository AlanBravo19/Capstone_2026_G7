# Catálogo detallado de casos de uso
Fuente: alcance consolidado del libro v4.1. Estado: especificación de diseño, no acreditación de funciones implementadas.

## CU01 Administrar cuenta
- Actor: Ciudadano.
- Objetivos: OE1, OE2, OE3, OE4, OE5, OE6.
- Precondición: La persona puede iniciar registro o recuperación sin sesión previa; para modificar datos debe autenticarse.
- Flujo principal: Registrar datos, verificar correo y entrar o recuperar acceso.
- Alternativa o excepción: Correo repetido, token vencido o cuenta suspendida: informar sin exponer datos de otras personas.
- Resultado observable: operación confirmada con estado y registro persistente; no se comunica éxito si no se confirmó el servidor.
- Entidades: usuario, rol, usuario_rol, token_acceso, preferencia, consentimiento.

## CU02 Registrar vehículo
- Actor: Ciudadano.
- Objetivos: OE2, OE3.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Ingresar datos y fotos; solicitar vínculo; consultar resultado de validación.
- Alternativa o excepción: Conocer la patente no autoriza seguimiento; el vínculo queda pendiente hasta revisión.
- Resultado observable: operación confirmada con estado y registro persistente; no se comunica éxito si no se confirmó el servidor.
- Entidades: marca, modelo, vehiculo, foto_vehiculo, vinculo_vehiculo.

## CU03 Reportar incidente
- Actor: Ciudadano.
- Objetivos: OE2, OE4.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Confirmar vehículo, relato, lugar y hora; enviar; recibir folio y estado.
- Alternativa o excepción: Sin red: mantener borrador local. Sin receptor: conservar caso sin asignar; no afirmar atención institucional.
- Resultado observable: operación confirmada con estado y registro persistente; no se comunica éxito si no se confirmó el servidor.
- Entidades: caso, vehiculo, usuario, organizacion, hecho_territorial, evento_salida.

## CU04 Aportar evidencia
- Actor: Ciudadano.
- Objetivos: OE2, OE3.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Seleccionar o capturar archivo desde una situación segura; subir; confirmar recepción.
- Alternativa o excepción: Carga fallida: reintentar con clave idempotente; no marcar el archivo como recibido antes de verificarlo.
- Resultado observable: operación confirmada con estado y registro persistente; no se comunica éxito si no se confirmó el servidor.
- Entidades: evidencia, caso, avistamiento.

## CU05 Comunicar avistamiento
- Actor: Ciudadano.
- Objetivos: OE3.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales. Solicitud vigente disponible.
- Flujo principal: Seleccionar solicitud vigente; informar observación, lugar y hora; recibir confirmación pendiente de revisión.
- Alternativa o excepción: Solicitud retirada o vencida: impedir nuevos aportes por ese canal; una foto no demuestra por sí sola identidad.
- Resultado observable: operación confirmada con estado y registro persistente; no se comunica éxito si no se confirmó el servidor.
- Entidades: solicitud_colaboracion, avistamiento, evidencia, evento_salida.

## CU06 Consultar seguimiento y orientación
- Actor: Ciudadano, Contacto de confianza.
- Objetivos: OE4.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Abrir caso autorizado; leer estado y gestiones comunicables; identificar siguiente paso y apoyo.
- Alternativa o excepción: Contacto revocado: denegar acceso. Mostrar sector y fecha, nunca indicaciones para perseguir el vehículo.
- Resultado observable: información autorizada presentada; consulta y exportación conservan el ámbito.
- Entidades: caso, gestion_caso, acceso_confianza, recurso_apoyo, notificacion.

## CU07 Autorizar contacto de confianza
- Actor: Ciudadano.
- Objetivos: OE4.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Elegir cuenta destinataria, alcance y vigencia; conceder acceso; revocarlo cuando corresponda.
- Alternativa o excepción: Destinatario idéntico al titular o sin cuenta: rechazar; comprobar titularidad del caso en la API.
- Resultado observable: operación confirmada con estado y registro persistente; no se comunica éxito si no se confirmó el servidor.
- Entidades: acceso_confianza, usuario, caso.

## CU08 Consultar antecedentes territoriales
- Actor: Ciudadano.
- Objetivos: OE1.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Seleccionar zona y período; consultar agregados con fuente, fecha, cobertura y límites.
- Alternativa o excepción: Datos insuficientes: declararlo; no convertir ausencia de registros en seguridad.
- Resultado observable: información autorizada presentada; consulta y exportación conservan el ámbito.
- Entidades: hecho_territorial, fuente_datos, lote_importacion, registro_fuente.

## CU09 Comparar alternativas de ruta
- Actor: Ciudadano.
- Objetivos: OE1.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Indicar origen y destino; consultar antecedentes; comparar distancia, tiempo y exposición relativa.
- Alternativa o excepción: Proveedor no disponible o cobertura parcial: informar y no afirmar que existe una ruta segura.
- Resultado observable: información autorizada presentada; consulta y exportación conservan el ámbito.
- Entidades: consulta_ruta, alternativa_ruta, hecho_territorial.

## CU10 Iniciar trayecto con avisos
- Actor: Ciudadano.
- Objetivos: OE1.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Activar trayecto y permisos; elegir modo de aviso; finalizarlo explícitamente.
- Alternativa o excepción: Permiso denegado o dato GPS antiguo: advertir límite y no presentar seguimiento como disponible.
- Resultado observable: operación confirmada con estado y registro persistente; no se comunica éxito si no se confirmó el servidor.
- Entidades: trayecto, alternativa_ruta, consulta_ruta, preferencia, consentimiento.

## CU11 Consultar solicitudes ciudadanas
- Actor: Ciudadano.
- Objetivos: OE3.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Ver catálogo vigente por sector; abrir información mínima autorizada; decidir si aportar observación.
- Alternativa o excepción: Caso cerrado o solicitud vencida: ocultar publicación; no mostrar relato privado ni coordenadas institucionales.
- Resultado observable: información autorizada presentada; consulta y exportación conservan el ámbito.
- Entidades: solicitud_colaboracion, vehiculo, modelo, marca.

## CU12 Configurar avisos y privacidad
- Actor: Ciudadano.
- Objetivos: OE1, OE4.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Elegir canales y horarios; revisar finalidades; otorgar o revocar permisos y consentimientos.
- Alternativa o excepción: La preferencia almacenada no sustituye el permiso del sistema operativo.
- Resultado observable: operación confirmada con estado y registro persistente; no se comunica éxito si no se confirmó el servidor.
- Entidades: preferencia, consentimiento, dispositivo.

## CU13 Consultar casos y alertas
- Actor: Operador.
- Objetivos: OE2.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Abrir bandeja de la organización; filtrar estado/prioridad; consultar expediente y antecedentes.
- Alternativa o excepción: Ámbito ajeno: denegar; urgencia y veracidad se muestran como conceptos separados.
- Resultado observable: información autorizada presentada; consulta y exportación conservan el ámbito.
- Entidades: caso, asignacion_caso, gestion_caso, avistamiento, evidencia, notificacion.

## CU14 Revisar aportes y duplicados
- Actor: Operador.
- Objetivos: OE2, OE3.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Examinar procedencia; aceptar, rechazar o pedir aclaración; justificar; conservar decisión e historial.
- Alternativa o excepción: Corrección posterior: agregar revisión y rectificación; un rechazo no prueba abuso deliberado.
- Resultado observable: operación confirmada con estado y registro persistente; no se comunica éxito si no se confirmó el servidor.
- Entidades: avistamiento, revision_avistamiento, evidencia, caso, vinculo_vehiculo, evento_auditoria, evento_salida.

## CU15 Asignar caso
- Actor: Supervisor.
- Objetivos: OE2.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Elegir responsable vigente de la misma organización; cerrar asignación anterior; registrar nueva asignación.
- Alternativa o excepción: Asignaciones simultáneas o miembro ajeno: rechazar mediante transacción e índice único.
- Resultado observable: operación confirmada con estado y registro persistente; no se comunica éxito si no se confirmó el servidor.
- Entidades: asignacion_caso, membresia, caso, organizacion.

## CU16 Registrar gestión y cierre
- Actor: Operador.
- Objetivos: OE2, OE4.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Registrar gestión o derivación; distinguir envío de recepción; cerrar con motivo y respaldo.
- Alternativa o excepción: No declarar recuperación por un avistamiento; reapertura requiere gestión motivada.
- Resultado observable: operación confirmada con estado y registro persistente; no se comunica éxito si no se confirmó el servidor.
- Entidades: gestion_caso, caso, derivacion_caso, canal_derivacion, evento_salida.

## CU17 Publicar solicitud de colaboración
- Actor: Operador.
- Objetivos: OE3.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Revisar caso; aprobar información mínima, sector y vigencia; publicar, renovar o retirar.
- Alternativa o excepción: No publicar detalles privados ni una búsqueda sin fundamento revisado.
- Resultado observable: operación confirmada con estado y registro persistente; no se comunica éxito si no se confirmó el servidor.
- Entidades: solicitud_colaboracion, caso, vehiculo.

## CU18 Consultar indicadores y exportar informe
- Actor: Operador.
- Objetivos: OE2, OE6.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Aplicar ámbito, período y entorno; leer numerador, denominador y procedencia; exportar la misma consulta.
- Alternativa o excepción: Sin registros suficientes: devolver estado sin datos; no mezclar demostración con operación real.
- Resultado observable: información autorizada presentada; consulta y exportación conservan el ámbito.
- Entidades: version_indicador, consulta_indicador, caso, vehiculo, modelo, marca, revision_avistamiento, gestion_caso, ejecucion_modelo, candidato_visual, ejecucion_prueba, medicion.

## CU19 Administrar usuarios y permisos
- Actor: Administrador.
- Objetivos: OE2, OE3, OE4.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Conceder o revocar roles; administrar membresías; resolver moderaciones y reclamaciones con motivo.
- Alternativa o excepción: El registro público no crea operadores; una sanción debe distinguir error de buena fe de abuso.
- Resultado observable: operación confirmada con estado y registro persistente; no se comunica éxito si no se confirmó el servidor.
- Entidades: usuario, rol, usuario_rol, membresia, organizacion, moderacion_usuario, vinculo_vehiculo, evento_auditoria.

## CU20 Gestionar fuentes históricas
- Actor: Administrador.
- Objetivos: OE1.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Documentar procedencia, cobertura y condiciones; cargar lote versionado; revisar resultados.
- Alternativa o excepción: Fuente no autorizada o identificador repetido: detener o registrar duplicado sin inflar conteos.
- Resultado observable: operación confirmada con estado y registro persistente; no se comunica éxito si no se confirmó el servidor.
- Entidades: fuente_datos, lote_importacion, registro_fuente.

## CU21 Revisar datos territoriales
- Actor: Administrador.
- Objetivos: OE1, OE3.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Relacionar registros con hechos consolidados; validar, descartar o deduplicar conservando procedencia.
- Alternativa o excepción: Un mismo hecho con varias fuentes cuenta una vez; reportes sin revisión no son hechos validados.
- Resultado observable: operación confirmada con estado y registro persistente; no se comunica éxito si no se confirmó el servidor.
- Entidades: registro_fuente, hecho_territorial, caso.

## CU22 Mantener recursos de apoyo
- Actor: Administrador.
- Objetivos: OE4.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Registrar canal y territorio; verificar contenido; renovar vigencia o desactivarlo.
- Alternativa o excepción: Recurso vencido: no presentarlo como vigente; orientación no equivale a atención clínica.
- Resultado observable: operación confirmada con estado y registro persistente; no se comunica éxito si no se confirmó el servidor.
- Entidades: recurso_apoyo, usuario.

## CU23 Consultar auditoría
- Actor: Administrador.
- Objetivos: OE2, OE3, OE4.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Filtrar actor, objeto y fecha; revisar acciones y resultados autorizados.
- Alternativa o excepción: No exportar secretos ni relatos innecesarios; la bitácora técnica no acredita cadena de custodia judicial.
- Resultado observable: información autorizada presentada; consulta y exportación conservan el ámbito.
- Entidades: evento_auditoria, consulta_video, revision_avistamiento, revision_recomendacion.

## CU24 Ejecutar escenarios de evaluación
- Actor: Evaluador.
- Objetivos: OE1, OE2, OE3, OE4, OE5, OE6.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Seleccionar versión de escenario; alternar modalidades cuando corresponda; registrar tiempo, acierto y fallos.
- Alternativa o excepción: No eliminar intentos difíciles; conservar invalidaciones justificadas y el conjunto de prueba congelado.
- Resultado observable: operación confirmada con estado y registro persistente; no se comunica éxito si no se confirmó el servidor.
- Entidades: escenario_prueba, ejecucion_prueba, medicion.

## CU25 Recibir aviso territorial
- Actor: Ciudadano.
- Objetivos: OE1.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Durante trayecto activo, presentar aviso relevante con fecha y límite; registrar si fue presentado.
- Alternativa o excepción: Sin permisos, sin proximidad o aviso repetido: omitir; proveedor acepta envío no significa lectura.
- Resultado observable: información autorizada presentada; consulta y exportación conservan el ámbito.
- Entidades: aviso_territorial, trayecto, hecho_territorial, notificacion, entrega_notificacion, dispositivo.

## CU26 Administrar cámaras autorizadas
- Actor: Administrador.
- Objetivos: OE5.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Registrar autorización, ubicación, cobertura y capacidades; comprobar estado y referencias de acceso.
- Alternativa o excepción: Sin autorización o fuera de servicio: no habilitar consulta; credenciales en gestor de secretos.
- Resultado observable: operación confirmada con estado y registro persistente; no se comunica éxito si no se confirmó el servidor.
- Entidades: camara, organizacion, evento_auditoria.

## CU27 Consultar video autorizado
- Actor: Operador.
- Objetivos: OE2, OE5.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales.
- Flujo principal: Seleccionar cámara e intervalo; verificar ámbito; abrir recurso; registrar acceso o fallo y exportación autorizada.
- Alternativa o excepción: Sin grabación histórica no existe recuperación retrospectiva; distinguir simulación de conexión real.
- Resultado observable: información autorizada presentada; consulta y exportación conservan el ámbito.
- Entidades: consulta_video, camara, caso, evidencia.

## CU28 Explorar recorridos posibles
- Actor: Operador.
- Objetivos: OE5.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales. Sesión de búsqueda del caso y evidencia autorizada; CU28 requiere observación ancla revisada.
- Flujo principal: Elegir observación ancla revisada; definir ventana; generar corredores; revisar supuestos y cámaras sugeridas.
- Alternativa o excepción: Sin ancla fiable: solicitar antecedente; un corredor alcanzable no predice intención ni confirma posición.
- Resultado observable: información autorizada presentada; consulta y exportación conservan el ámbito.
- Entidades: sesion_busqueda, observacion_busqueda, hipotesis_ruta, recomendacion_camara, camara.

## CU29 Comparar candidatos visuales
- Actor: Operador.
- Objetivos: OE5.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales. Sesión de búsqueda del caso y evidencia autorizada; CU28 requiere observación ancla revisada.
- Flujo principal: Elegir referencia autorizada; ordenar candidatos; contrastar evidencia y registrar decisión humana.
- Alternativa o excepción: Imagen insuficiente o candidatos ambiguos: declarar indeterminado; similitud no es probabilidad de identidad.
- Resultado observable: información autorizada presentada; consulta y exportación conservan el ámbito.
- Entidades: version_modelo, ejecucion_modelo, candidato_visual, evidencia, observacion_busqueda.

## CU30 Consultar copiloto del caso
- Actor: Operador.
- Objetivos: OE2, OE5.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales. Sesión de búsqueda del caso y evidencia autorizada; CU28 requiere observación ancla revisada.
- Flujo principal: Preguntar dentro del caso; recuperar soportes autorizados; distinguir hechos, hipótesis y límites.
- Alternativa o excepción: Sin soporte: responder información insuficiente; el texto aportado no puede cambiar permisos ni ejecutar acciones.
- Resultado observable: información autorizada presentada; consulta y exportación conservan el ámbito.
- Entidades: consulta_copiloto, afirmacion_copiloto, soporte_afirmacion, ejecucion_modelo.

## CU31 Revisar recomendaciones de búsqueda
- Actor: Operador.
- Objetivos: OE5.
- Precondición: Cuenta activa y autorización del recurso; ámbito de organización válido para acciones institucionales. Sesión de búsqueda del caso y evidencia autorizada; CU28 requiere observación ancla revisada.
- Flujo principal: Abrir fundamento de cámara e intervalo; aceptar revisión, descartar o dejar indeterminado; registrar motivo.
- Alternativa o excepción: Disponibilidad o evidencia nueva cambia prioridad: conservar versiones y revisión humana.
- Resultado observable: operación confirmada con estado y registro persistente; no se comunica éxito si no se confirmó el servidor.
- Entidades: recomendacion_camara, revision_recomendacion, hipotesis_ruta, camara.
