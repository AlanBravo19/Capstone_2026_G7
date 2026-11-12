# RutaAlerta · Beta colaborativa 0.7.0

Incremento del 12/11/2026. Aplicación nativa Flutter Android y API FastAPI sobre PostgreSQL/PostGIS en Supabase. Preparado con asistencia de IA; el equipo debe revisar y explicar el código. No acredita aprobación docente ni aportes individuales.

## Funciones disponibles

| Función | Implementación y límites |
|---|---|
| Cuenta y contraseña | Registro ciudadano, hash scrypt, sesión revocable, límites persistentes. No acredita identidad civil. |
| Segundo factor real | TOTP RFC6238 con autenticador, clave cifrada, confirmación de alta, desafío de 5 minutos, cinco intentos, rechazo de reutilización y ocho códigos de recuperación de un uso. Activarlo revoca las sesiones anteriores. |
| Seguridad de cuenta | Cambio de contraseña actual, segundo factor cuando está activo, listado y cierre de otras sesiones. La recuperación de contraseña no elimina el MFA ni una sanción. |
| Correo y SMS | Envío todavía de prueba en esta instalación. SMTP real preparado, sin proveedor contratado/configurado. SMS real pendiente. No sustituir este estado por verificación real. |
| Vehículos | Alta propia, patente única, vínculo declarado pendiente. Conflictos requieren revisión asistida, no se revela el propietario ajeno. |
| Reportes | Fecha, relato, vehículo y coordenada del incidente. Privados, con reintento idempotente. El GPS del teléfono no rastrea el vehículo robado. |
| Seguimiento | Historial visible al afectado; los comentarios internos no se entregan. Antecedentes de denuncia declarados por el usuario no equivalen a consulta de Carabineros. |
| Evidencias | Hasta cinco fotos privadas por caso; JPEG/PNG/WebP de entrada de hasta 2 MB y 16 MP. Recodificación a JPEG, eliminación de EXIF, huella y revisión humana. Descarga autenticada. Video y documentos pendientes de almacenamiento de objetos. |
| Colaboración | Consentimiento del afectado y autorización institucional explícita. Publicación separada del relato, vigencia de 1 a 72 horas y retiro automático al cerrar el caso. |
| Cercanía | Sector publicable redondeado, distancias aproximadas y radio configurable. Ordena cercanos y otras zonas. No muestra la posición actual del vehículo ni la coordenada privada. Búsqueda por comuna/sector y coordenadas opcionales de consulta. |
| Avistamientos | Fecha y lugar observados, descripción, idempotencia, bandeja del autor y evaluación motivada. Sólo un resumen aceptado se entrega al afectado. No habilita persecuciones. |
| Contactos de confianza | Acceso de otra cuenta activa por hasta 30 días, máximo cinco accesos activos por caso. Se revoca y no permite ver fotos, relato ni coordenadas privadas. |
| Notificaciones | Buzón interno persistente, lectura y acceso a seguimiento. No es push del sistema ni mensajería en segundo plano. |
| Gestión institucional | Bandeja por membresía vigente, revisión, publicación/retiro, evaluación de aportes/fotos, cierre, prioridad por API y métricas acotadas al ámbito. Sin convenios institucionales inferidos. |
| Cierre | Recuperación requiere evidencia aceptada del mismo caso. Duplicado exige caso principal del mismo ámbito. Cierra y retira publicaciones. |
| Mapa y trayecto | MapLibre vectorial azul 2D/3D, selección de incidente y GPS voluntario. Servicio Android de trayecto ya existente; no se probó un viaje físico ni alertas con Waze. |
| Antecedentes históricos | Consulta sólo hechos de operación validados con registros aceptados, fuente autorizada y lote completado. Si no hay esos datos, devuelve vacío; no muestra noticias ficticias como hechos reales. |
| Cámaras | Consulta privada del inventario institucional con entorno y referencia de autorización. No hay transmisión ni reconocimiento conectado. |
| Asistencia al operador | Resumen determinista con referencias a caso, aportes aceptados y evidencias aceptadas. No utiliza un modelo de IA, no deduce rutas ni sospechosos. |

## Modelo y almacenamiento

El esquema de esta beta tiene **63 tablas**: 56 del diseño original, tres de identidad y cuatro de este incremento (`autenticador_totp`, `desafio_mfa`, `recuperacion_mfa`, `archivo_evidencia`). Se agregan consentimiento de colaboración al caso y centro territorial público a la solicitud. Los MER históricos de 56 tablas se conservan como versiones anteriores.

Aplicar `sql/05_Beta_Colaborativa.sql` después de 01–04. Es aditiva y no borra datos. En un proyecto existente no volver a cargar 01 ni los datos de muestra. El rol `ra_api` requiere SELECT/INSERT/UPDATE en las cuatro tablas nuevas; no requiere DELETE ni permisos administrativos. No exponer el esquema en Supabase Data API.

Las fotografías saneadas se guardan temporalmente en SQL privado para que este incremento funcione sin entregar credenciales de Storage al cliente. Antes de escalar debe migrarse a un almacén privado de objetos con políticas de retención, límites de cuota, eliminación y respaldo. La fotografía recodificada es un derivado; su huella no certifica el archivo original ni la verdad del hecho.

## Ejecución y pruebas

Requisitos del backend: Python 3.12 para despliegue. Instalar `requirements.txt`. Configurar variables privadas DB_*, `DB_SSL=1` para conexión remota, `OTP_SECRET` estable (al menos 32 bytes), invitación privada y canales. Ejecutar `uvicorn app.main:app`. No usar contraseñas, invitaciones ni códigos de recuperación en el repositorio.

Pruebas locales: `cd scripts`, `npm install`, `node servidor_prueba_pglite.mjs ../sql 54329`; en otra consola configurar DB_HOST=127.0.0.1, DB_PORT=54329, DB_NAME=postgres, DB_USER=postgres, DB_SSL=0, ENTORNO=prueba y CANALES_DEMO=1; ejecutar `pytest`. La base de prueba es desechable. No ejecutar toda la suite en la base compartida: modifica usuarios ficticios y contadores.

`GET /version` informa la versión del servidor; `/health` requiere la invitación cuando está habilitada. OpenAPI describe los endpoints tras autenticación de la beta.

Flutter: `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --debug`, o `Compilar_Android.ps1`. Credenciales sólo en memoria; APK sin contraseñas de base. La firma de desarrollo no es la definitiva para una tienda.

## Uso de la app

1. Instalar APK en Android 8 o superior e ingresar con la invitación privada de la beta y una cuenta propia.
2. Inicio: completar contactos de prueba; registrar vehículo y reporte. Abrir el seguimiento para fotos, denuncia declarada, confianza y consentimiento de colaboración.
3. Menú superior → Seguridad y segundo factor: introducir contraseña actual, agregar la clave manual en el autenticador, confirmar código y guardar los ocho códigos de recuperación en privado. Volver a ingresar con contraseña y segundo factor. Esperar al siguiente código si el anterior ya se usó.
4. Un operador con membresía vigente abre Gestión institucional, revisa el caso y autoriza una publicación con texto mínimo. El rol evaluador no permite por sí solo gestionar casos.
5. Colaborar: filtrar zona o coordenadas de búsqueda y aportar observación. El operador la evalúa y redacta el resumen para el afectado. El aviso aparece en Notificaciones.
6. Mapa mantiene Mi ubicación, precisión y pausa en segundo plano. Modo trayecto se abre desde el menú superior y requiere consentimiento independiente.

## Pendientes externos y trabajo restante

- Configurar proveedor real de correo y SMS; revisar la transición desde contactos previamente simulados. MFA protege el acceso pero no identifica civilmente a una persona ni impide que otra use nuevos contactos.
- Conectar fuentes históricas autorizadas, importar con trazabilidad, deduplicar y validar; no se ha cargado historia real de robos ni raspado sitios de noticias.
- Integrar proveedor de rutas, comparación de alternativas y avisos territoriales; no hay alertas reales de portonazos ni garantía de rutas seguras.
- Integrar push mediante FCM, retención/eliminación de evidencias, video y objetos privados.
- Cámaras con autorización y proveedor/credenciales concretos; modelo de visión y copiloto de IA con fuentes y revisión humana. El inventario y el resumen no reemplazan estas integraciones.
- Recepción asistida de patentes ya vinculadas, apelaciones a sanciones, asignación de responsables, edición avanzada de vehículos, pruebas de carga y accesibilidad.
- Completar el panel React; la gestión de este incremento se ofrece en Flutter y mediante API. La web conserva sus flujos anteriores y compatibilidad de ingreso MFA.
- Validación física Android, permisos precisos/aproximados, pérdida de señal, batería, fabricantes, trayecto con otras aplicaciones y distribución con firma definitiva.

## Evidencia y referencias

Resultados reales guardados en `evidencias/`; las pruebas de interfaz y GPS usan datos controlados y no acreditan un viaje físico. La publicación sólo se considera completada al verificar la URL y sus operaciones.

- TOTP: https://www.rfc-editor.org/rfc/rfc6238
- Cifrado autenticado: https://cryptography.io/en/latest/fernet/
- MapLibre Flutter: https://maplibre.org/flutter-maplibre-gl/
- Supabase PostGIS: https://supabase.com/docs/guides/database/extensions/postgis
