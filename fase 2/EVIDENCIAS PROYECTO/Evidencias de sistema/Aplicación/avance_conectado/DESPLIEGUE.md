# RutaAlerta - Avance conectado 0.3

Avance académico del Grupo 7, preparado con asistencia de IA el 29/10/2026. Interfaz web de ensayo, API FastAPI y PostgreSQL/PostGIS. No es la entrega final ni un servicio de emergencias. No atribuye trabajo ni commits a compañeros.

## Comportamiento

- Registro e ingreso; contraseñas con scrypt y sesiones de token aleatorio cuya huella se conserva en SQL.
- Token de correo y OTP telefónico de un uso, vencimiento y límite de intentos. **La entrega de correo/SMS es simulada y está señalada en pantalla.** No acredita identidad civil.
- Correo y teléfono verificado únicos. Sanciones motivadas con revocación de sesiones; recuperar la contraseña no elimina la sanción. Otros contactos nuevos pueden superar el registro: no se garantiza una cuenta por persona.
- Alta y consulta de vehículos propios, vínculo declarado pendiente y rechazo de patentes repetidas sin revelar el dueño.
- Reporte privado con geometría PostGIS, consulta de casos propios, reintentos idempotentes y bandeja institucional restringida por organización.
- Administrador ficticio con membresía puede marcar un caso en revisión. No lo publica ni confirma un encargo policial.

Esta interfaz es HTML/CSS/JavaScript conectada a la API del mismo origen. El panel final React y app Flutter están pendientes. El prototipo anterior permanece separado. Cámaras, IA, navegación, archivos y difusión ciudadana aún no están conectados aquí.

## Estructura y modelo

`app/`: API. `web/index.html` y `public/`: interfaz. `sql/`: esquema Supabase. `certs/`: CA pública oficial, no una clave privada. `tests/`: pruebas. `scripts/`: preparación y comprobaciones.

El esquema `rutaalerta` tiene **59 tablas**: 56 originales y tres nuevas de identidad. Los diagramas anteriores de 56 tablas no reflejan esta ampliación. Aplicar los scripts una sola vez en un proyecto dedicado nuevo; no reinicializar uno existente.

## Supabase

PostGIS está en `extensions`. La API usa **Psycopg 3**, TLS con CA y hostname verificados y preparación automática desactivada para compatibilidad con el pooler. El cargador de SQL conserva pg8000 para ejecutar lotes. Nunca se entrega la conexión administrativa al navegador.

`ra_api` permite leer/escribir datos del esquema, pero no crear tablas, roles o bases. FastAPI aplica autorización por usuario y organización. Los roles públicos `anon` y `authenticated` no reciben acceso al esquema. No añadir `rutaalerta` a los esquemas expuestos de Data API. No se integra Supabase Auth en este avance.

`scripts/cargar_supabase.py` carga esquema, indicadores, datos sintéticos y migración. Se detiene si el esquema existe. Las pruebas solo se ejecutan en la base dedicada de ensayo: crean datos ficticios y modifican la credencial del operador ficticio.

## Configuración

Variables: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_SSL=1`, `ENTORNO=prueba`, `CANALES_DEMO=1`, `OTP_SECRET` estable y `DEMO_ACCESS_KEY` privada. Las contraseñas quedan en archivos ignorados y variables de Vercel; no en la interfaz ni en GitHub.

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
# Configurar las variables indicadas antes de arrancar:
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Página: `/`. El navegador manda `X-Demo-Access`. Con la clave configurada no se permiten operaciones sin ella. El token de sesión se mantiene en memoria, no en localStorage. Al recargar se vuelve a ingresar y consultar los datos persistidos.

## Vercel

Framework FastAPI; raíz esta carpeta; entrada `app.main:app` en `pyproject.toml`. `public/` sirve recursos estáticos y `/` entrega HTML. Configurar las variables anteriores y desplegar. El arranque en Vercel exige secretos estables y TLS para no publicar por accidente códigos de prueba sin control de acceso.

No subir `.env*`, `.vercel`, `ACCESO_DEMO_PRIVADO.txt`, entornos Python o node_modules. Las pruebas locales o en Supabase no acreditan un despliegue en Vercel: verificar URL y operaciones después de publicar.

## Cuatro semanas restantes

Plan propuesto por validar con equipo y pauta: integrar proveedores de mensajes y MFA; terminar revisión/publicación, aportes y reclamaciones; conectar app/panel y permisos; probar aislamiento, concurrencia, retención y despliegue. No representa trabajo pasado ni aprobación docente.

Fuentes: [Supabase PostGIS](https://supabase.com/docs/guides/database/extensions/postgis), [conexión SQL](https://supabase.com/docs/guides/database/connecting-to-postgres), [Psycopg y poolers](https://www.psycopg.org/psycopg3/docs/advanced/prepare.html), [FastAPI en Vercel](https://vercel.com/docs/frameworks/backend/fastapi).

## Incremento de autenticación por correo

Ver AUTENTICACION_REAL.md: implementación SMTP y recuperación incorporadas, pendientes de proveedor y recepción externa. La beta conserva sus canales de prueba hasta configurar y validar el servicio.
