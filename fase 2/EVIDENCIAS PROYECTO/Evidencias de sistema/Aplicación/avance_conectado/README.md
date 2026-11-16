# RutaAlerta · Beta 0.8.0

## Beta 0.9 · Aplicación ciudadana y escritorio institucional

En Android, Inicio permite consultar solicitudes con «Vi un vehículo» y colaborar sin tener auto. Las cuatro secciones son Inicio, Colaborar, Mapa y Cuenta. El registro de un vehículo vinculado se utiliza al reportar su robo. El afectado selecciona qué organización recibirá ese reporte.

El escritorio está en https://rutaalerta-mvp-g7.vercel.app/operaciones. Se ingresa con invitación, credenciales y el segundo factor cuando está activo. La membresía vigente determina qué casos puede consultar el operador. El panel permite filtrar por estado y folio, leer el relato privado, revisar aportes y fotos, gestionar publicaciones consentidas, cerrar casos, revisar fuentes territoriales y consultar el inventario de cámaras. La web de acceso ciudadano anterior sigue en /ciudadania.

El panel usa la API de RutaAlerta y la base existente de 65 tablas. Su interfaz usa HTML, CSS y JavaScript. La aprobación de un antecedente, una publicación o una evidencia exige una decisión humana.


Documentación vigente: [ESTADO_FUNCIONAL_080.md](ESTADO_FUNCIONAL_080.md). Correo real por Brevo, TOTP, desbloqueo biométrico Android, lugares privados, rutas con apertura Google Maps/Waze y avisos locales basados en fuentes revisadas. El esquema actual tiene 65 tablas. SMS no contratado; no se simula en operación.

El contenido siguiente documenta la versión anterior:

# RutaAlerta · Beta colaborativa 0.7.0

La documentación vigente de alcance, funcionamiento, límites y puesta en marcha está en [ESTADO_FUNCIONAL_070.md](ESTADO_FUNCIONAL_070.md).

API FastAPI conectada a PostgreSQL/PostGIS en Supabase, con app Flutter Android. Incluye TOTP real, casos privados, seguimiento, fotos privadas, confianza revocable, colaboración revisada, avistamientos, gestión y buzón interno. El correo y SMS no tienen proveedor real configurado; las cámaras, rutas e IA requieren integraciones adicionales detalladas en el estado funcional.

Migración nueva: `sql/05_Beta_Colaborativa.sql` (63 tablas en total, sin borrar datos previos). No recargar el esquema inicial sobre un proyecto existente.

Código preparado con asistencia de IA. Las pruebas reales y sus límites están en `evidencias/`. No atribuye aportes ni aprobación a los integrantes o docentes.
