# Verificación del avance conectado

Fecha: 29/10/2026. Proyecto Supabase: `fmqlijkowxxplltkjoey`. Sitio: https://rutaalerta-mvp-g7.vercel.app/

## Qué está comprobado

- Esquema PostgreSQL/PostGIS cargado en Supabase con 59 tablas de RutaAlerta.
- Conexión cifrada con validación de CA y hostname, mediante usuario de API sin permisos administrativos.
- 18 escenarios completados y marcados PASSED en `pytest_supabase.txt`, antes de que la ejecución alcanzara el tiempo máximo. El archivo es un registro parcial, no un reporte de suite finalizada.
- Los otros siete escenarios se ejecutaron por separado: **7 passed, 18 deselected**, sin fallos, en `pytest_supabase_restantes.txt` y su JUnit XML. Estos siete incluyen baneo, reutilización de teléfono restringido y revocación de acceso.
- Los grupos cubren los 25 escenarios distintos de este incremento, pero **no se afirma que exista una ejecución única completa de 25 pruebas**.
- La prueba HTTP contra el sitio publicado completó **15 operaciones**, todas con el código esperado: página, conexión a Supabase, registro, ingreso, verificación simulada, vehículo, reporte, idempotencia, consulta, cierre y rechazo de sesión revocada. Ver `prueba_http_vercel.json`.

## Incidencias resueltas y límites

El primer controlador tuvo incompatibilidades con el pooler. Se cambió la API a Psycopg, se desactivó la preparación automática de sentencias y se agregó un reintento acotado únicamente para inicializar conexiones, antes de cualquier escritura de negocio. También se observó un cierre de conexión durante un intento anterior de la suite. El XML de ese intento se conserva en `historico/`, identificado como fallido.

El primer despliegue Vercel no tenía FastAPI instalado porque las dependencias no estaban declaradas en pyproject.toml. Se corrigió el manifiesto y se verificó la versión reconstruida por HTTP. El primer intento del verificador HTTP intentó interpretar HTML como JSON; se corrigió el verificador y se ejecutó nuevamente.

La entrega de correo/SMS es simulada; no demuestra recepción de mensajes ni identidad civil. MFA de los operadores, app Flutter, panel React definitivo, cámaras, IA, navegación, archivos, difusión/revisión completa y reclamaciones siguen pendientes. Las pruebas no miden recuperación de vehículos, reducción del delito ni rendimiento bajo carga concurrente.

## Autoría y datos

Código y documentación preparados con asistencia de IA. Los datos son ficticios y los resultados son ejecuciones reales, no una simulación de pruebas. No hay aprobaciones docentes, convenios, firmas ni aportes individuales inventados. Las credenciales están excluidas de los repositorios.
