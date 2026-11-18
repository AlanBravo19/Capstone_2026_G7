# RutaAlerta · API (incremento inicial del Sprint 1)

API FastAPI sobre el esquema PostgreSQL/PostGIS `rutaalerta` (carpeta `../../Base de datos/sql`). Implementa la primera parte del Sprint 1:

| Historia | Endpoint | Qué hace |
|---|---|---|
| HT01 | `GET /health` | Verifica conexión, PostGIS y número de tablas |
| HU01 | `POST /cuentas`, `POST /sesiones` | Registro ciudadano (pendiente de verificación) e inicio de sesión con token; en la base sólo se guarda la huella SHA-256 |
| HU01 | `POST /cuentas/recuperacion`, `POST /cuentas/recuperacion/confirmar` | Recuperación con token de un solo uso y vencimiento |
| HU03 | `POST /casos` (encabezado `Idempotency-Key`) | Reporte con folio, ubicación PostGIS y evento en la cola transaccional; un reintento no duplica el caso |
| HU13 | `GET /casos`, `GET /casos/{id}` | Bandeja y detalle restringidos a la organización del operador |

No incluye todavía: app Flutter, panel React, verificación de correo, carga de evidencia ni despliegue en Azure.

## Ejecutar las pruebas (sin instalar PostgreSQL)

Requisitos: Python 3.12 o superior y Node.js 20 o superior.

Desde la carpeta `backend`:

```
python -m venv .venv
.venv\Scripts\activate            (Windows)   ·   source .venv/bin/activate (Linux/macOS)
pip install -r requirements.txt
cd scripts && npm install && cd ..
node scripts/servidor_prueba_pglite.mjs "../../Base de datos/sql" 54329
```

En otra terminal, en la carpeta `backend` y con el entorno activado:

```
pytest -v
```

Resultado registrado el 14/10/2026 (Windows 11, Python 3.14.5): **10 pruebas aprobadas** (`../resultados/pytest_backend_sprint1.txt`). Corresponden a CP40–CP44 del Plan de Pruebas (C2). El servidor de prueba es PostgreSQL compilado en WebAssembly con datos ficticios; para un PostgreSQL real, cargar los scripts según el Manual Técnico (C3) y definir `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` y `DB_PASSWORD`.

## Levantar la API

```
uvicorn app.main:app --reload
```

Documentación interactiva (OpenAPI): http://127.0.0.1:8000/docs

## Autoría

Código inicial preparado con asistencia de IA a partir del diseño del equipo (libro v4.1 y entrega del 29/09/2026). Quien lo suba debe revisarlo, ejecutar las pruebas y poder explicarlo; los siguientes cambios del Sprint 1 los realiza cada integrante desde su propia cuenta.
