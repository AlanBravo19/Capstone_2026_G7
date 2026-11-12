# RutaAlerta · Correo real, biometría y movilidad · 0.8.0+7

Incremento del 12/11/2026. API 0.8.0-beta, Flutter Android y PostgreSQL/PostGIS en Supabase. Código preparado con asistencia de IA. Conserva las funciones de casos, fotos, confianza y revisión de la versión 0.7; esa documentación se mantiene como historial.

## Correo real sin contratar SMS

Brevo Free quedó configurado mediante SMTP con TLS. Se comprobó el envío de un mensaje real y el panel de Brevo registró **Delivered**. El remitente es el elegido por el usuario; no se incluyen su contraseña ni la clave SMTP en el APK, fuentes o GitHub. Al usar un dominio gratuito, Brevo puede reescribir la dirección con su dominio de envío; el nombre visible conserva RutaAlerta.

La cuota publicada del plan gratuito es de 300 correos diarios; no se contrató un plan pagado. La clave exclusiva de envío vence el **12/02/2027**, o puede vencer por inactividad según Brevo. Debe renovarse antes de esa fecha. No equivale a un servicio ilimitado ni garantiza la entrega a todos los buzones.

Registro → ingresar → verificar el correo con el código recibido → activar autenticador TOTP → guardar los códigos de recuperación → volver a ingresar. La combinación de correo real y autenticador habilita la participación sin SMS. La recuperación por correo cambia la contraseña y revoca sesiones, pero conserva el segundo factor y las sanciones.

Los contactos previamente simulados siguen identificados en SQL como `prueba`: no se convierten automáticamente en verificaciones reales. El usuario debe confirmar otra vez su correo mediante envío real. SMS no está contratado; la API no devuelve códigos SMS simulados en modo operación. No se promete una cuenta por persona: correo y biometría no acreditan identidad civil y nuevos contactos pueden requerir moderación.

## Acceso con huella o biometría

Menú superior → Seguridad y segundo factor → Activar en este teléfono. Android muestra su diálogo de biometría fuerte. Guarda únicamente una sesión ya autenticada y su invitación, cifradas mediante AES-GCM con una clave Android Keystore que requiere autenticación para cada uso. Las plantillas biométricas permanecen en Android: RutaAlerta no las captura ni las sube.

El botón Ingresar con biometría aparece si hay un acceso guardado compatible. También existe Bloquear con biometría para salir de la vista local conservando ese acceso. El servidor siempre comprueba la sesión: si venció, fue revocada o la cuenta fue suspendida, la huella no permite entrar. Cerrar sesión elimina el acceso guardado. Agregar o cambiar biometría puede invalidar la clave y exigir contraseña y MFA nuevamente.

No se guarda la contraseña. No se renueva indefinidamente la sesión: mantiene el vencimiento del servidor (actualmente hasta 12 horas). Android 9 o superior con biometría compatible; Android 8 conserva el acceso por contraseña. La cancelación o falta de sensor no se presentan como éxito. **Pendiente de validar el sensor en un teléfono físico.**

## Casa, Trabajo, Favorito y rutas

Menú → Mi casa, trabajo y rutas. Guardar una dirección buscándola con el geocodificador del teléfono, confirmando un punto en el mapa o tomando una posición GPS reciente. Son destinos privados en la cuenta. El centro inicial del mapa nunca se guarda como ubicación elegida. Retirar un lugar limpia su dirección y coordenadas; no requiere borrado administrativo.

Seleccionar origen y destino o usar el GPS como origen. Calcular recorrido pide consentimiento para enviar coordenadas a RutaAlerta y al servicio público OSRM. Devuelve distancia, duración aproximada, geometría vial y hasta tres alternativas cuando el proveedor las ofrece. La prueba real entre puntos públicos de ensayo devolvió dos alternativas. No inventa una línea recta si el proveedor falla. El servicio público OSRM se usa como base de beta, sin garantía de disponibilidad; para escalar se necesita instancia propia o proveedor con capacidad acordada.

Ver recorrido en el mapa dibuja el trazado sobre el mapa azul. **Iniciar en Google Maps** abre las indicaciones con origen/destino; **Iniciar en Waze** navega al destino desde la posición actual. No requiere una clave de Google Maps para esos enlaces. Las aplicaciones externas pueden calcular otra ruta. RutaAlerta no lee ni modifica la ruta interna de Waze, no incluye tráfico en vivo ni declara rutas seguras.

## Fuentes históricas y avisos

Se incorporó una ficha real de prensa, con enlace y resumen propio de la publicación de BioBioChile del 03/07/2026 sobre el sector Francisco Coloane, San Pedro de la Paz. **Queda pendiente de revisión territorial y sin coordenadas ni aviso activo.** No se inventó una ubicación exacta, fecha del hecho distinta de la publicación, revisión humana o tasa de delitos.

Un operador con membresía puede abrir Revisar fuentes y avisos, leer la fuente original, comprobar fecha y duplicados, seleccionar un centro aproximado del sector, declarar incertidumbre y radio, justificar la revisión y activar un aviso por 1–90 días. También puede descartarlo o retirarlo. El radio no puede ser menor que la incertidumbre declarada. El historial de revisión se audita. Las fichas son resúmenes propios y enlaces, no copias de artículos completos.

El área de avisos entrega sólo antecedentes de operación validados, vigentes y publicados dentro del último año. No incluye fuentes de prueba ni pendientes. Una noticia acredita que hubo una publicación; no certifica por sí sola el delito ni su frecuencia. La app muestra fuente, fecha y sector, y permite abrir el original. No hay raspado masivo ni actualización automática de todas las noticias. Una automatización posterior debe ingresar candidatos desde RSS o fuentes autorizadas y mantener esta revisión, deduplicación y trazabilidad.

Las estadísticas comunales CEAD sirven para comparar períodos y comunas; no permiten asignar automáticamente un riesgo a una esquina. El portal CEAD devolvió un error de acceso durante esta sesión, por lo que no se inventaron ni importaron cifras. Una única noticia no se etiqueta como “alta frecuencia de portonazos”.

## Avisos durante un trayecto, incluso con otra app abierta

Modo trayecto requiere consentimiento, ubicación y notificaciones. Al iniciar se consulta una vez un centro redondeado del área (en cuerpo JSON, sin coordenada precisa en la URL) y se descargan hasta 50 antecedentes dentro de 30 km. Después, las comprobaciones de cercanía se hacen en el servicio Android con ubicación local; no se transmite un historial continuo.

El caché vive como máximo dos horas y cada antecedente conserva su vencimiento. No se alerta con posición de más de 30 segundos, precisión peor de 250 m, caché vencido, antecedente vencido o distancia fuera del radio. Hay un límite de un aviso por antecedente cada 30 minutos y una separación global mínima de dos minutos. La notificación dice antecedente histórico cercano, fuente y fecha; no anuncia un delito en curso ni ordena perseguir a nadie. Consultar el detalle sólo cuando esté detenido.

Si no hay fuentes revisadas para el área, la app indica cero antecedentes: **no significa zona segura**. Al salir del área descargada pueden faltar antecedentes. La continuidad depende de Android, batería, permisos y fabricante; no funciona después de forzar la detención y no sustituye una prueba física con Waze.

## Modelo, publicación y credenciales

El esquema pasa de 63 a **65 tablas**, agregando `lugar_guardado` y `antecedente_publico`, más la procedencia real/de prueba de los contactos. Migración `sql/06_Movilidad_y_Fuentes.sql`, aditiva y aplicada en el Supabase existente. No recargar 01 ni los datos de ejemplo en una base existente.

Rol limitado `ra_api`: SELECT, INSERT, UPDATE en las tablas nuevas, sin administración ni DELETE. Variables de correo privadas en Vercel; `ENTORNO=operacion`, `CANALES_DEMO=0`. `OTP_SECRET` y credenciales de base conservados. Ni la invitación de beta ni secretos SMTP se compilan. `GET /version` permite comprobar versión del servidor. La invitación privada de beta sigue vigente.

## Verificación

- 52 pruebas backend aprobadas sobre PostgreSQL/PostGIS desechable.
- 18 pruebas Flutter aprobadas; una prueba remota anterior se omite por diseño. Cancelación biométrica, sesión revocada y argumentos de navegación usan canales controlados, no un sensor físico.
- Ocho pruebas nativas JVM de proximidad aprobadas: vigencia, caché, precisión, distancia y control de repetición.
- Análisis Flutter sin incidencias y APK de desarrollo compilado.
- Integración local real contra Supabase, SMTP y OSRM: confirmación por correo de un uso, participación con TOTP, recuperación con revocación, lugar privado y dos rutas reales entre puntos públicos de ensayo.
- Publicación y comprobación HTTP se registran por separado en `evidencias/`. No atribuir una prueba local al despliegue ni afirmar viaje físico.

## Referencias verificadas

- Brevo Free: https://help.brevo.com/hc/en-us/articles/208580669-FAQs-What-are-the-limits-of-the-Free-plan
- Remitentes: https://help.brevo.com/hc/en-us/articles/208836149-Create-a-new-sender-From-name-and-From-email
- Biometría Android: https://developer.android.com/identity/sign-in/biometric-auth
- Google Maps URLs: https://developers.google.com/maps/documentation/urls/get-started
- Waze: https://developers.google.com/waze/deeplinks
- OSRM: https://project-osrm.org/docs/v5.24.0/api/
- Fuente de prensa: https://www.biobiochile.cl/noticias/nacional/region-del-bio-bio/2026/07/03/captan-violento-portonazo-en-san-pedro-de-la-paz-vecinos-acusan-abandono-de-autoridades.shtml
- CEAD: https://cead.spd.gov.cl/estadisticas-delictuales/

### Publicación comprobada

12/11/2026: Vercel 0.8.0-beta publicado en https://rutaalerta-mvp-g7.vercel.app y verificado por HTTP real. Registro, sesión, solicitud de correo SMTP sin token de prueba, SMS explícitamente no disponible, guardar/retirar lugar privado, dos alternativas OSRM reales, fuente de prensa pendiente visible, descarga de área y permisos institucionales comprobados. Evidencia `vercel_beta_080.json`.
