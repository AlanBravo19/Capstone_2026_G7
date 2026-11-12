# RutaAlerta · Beta colaborativa 0.7.0

La documentación vigente de alcance, funcionamiento, límites y puesta en marcha está en [ESTADO_FUNCIONAL_070.md](ESTADO_FUNCIONAL_070.md).

API FastAPI conectada a PostgreSQL/PostGIS en Supabase, con app Flutter Android. Incluye TOTP real, casos privados, seguimiento, fotos privadas, confianza revocable, colaboración revisada, avistamientos, gestión y buzón interno. El correo y SMS no tienen proveedor real configurado; las cámaras, rutas e IA requieren integraciones adicionales detalladas en el estado funcional.

Migración nueva: `sql/05_Beta_Colaborativa.sql` (63 tablas en total, sin borrar datos previos). No recargar el esquema inicial sobre un proyecto existente.

Código preparado con asistencia de IA. Las pruebas reales y sus límites están en `evidencias/`. No atribuye aportes ni aprobación a los integrantes o docentes.
