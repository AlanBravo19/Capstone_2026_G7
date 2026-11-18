# Verificación de la entrega

Fecha: 29 de septiembre de 2026.

PostgreSQL 18.3 (PGlite 0.5.8) on wasm32-unknown-emscripten, compiled by emcc (Emscripten gcc/clang-like replacement + linker emulating GNU ld) 3.1.74 (1092ec30a3fb1d46b1782ff1b4db5094d3d06ae5), 32-bit

POSTGIS="3.6.2 0" [EXTENSION] PGSQL="180" GEOS="3.14.0-CAPI-1.20.4" PROJ="9.7.0 NETWORK_ENABLED=OFF URL_ENDPOINT=https://cdn.proj.org USER_WRITABLE_DIRECTORY=/home/postgres/.local/share/proj DATABASE_PATH=/pglite/share/proj/proj.db" (compiled against PROJ 9.7.0) LIBXML="2.14.5" LIBJSON="0.18"

- T01 correo normalizado único: CORRECTO
- T02 patente normalizada única: CORRECTO
- T03 referencia a modelo inexistente: CORRECTO
- T04 asignación de organización ajena: CORRECTO
- T05 una asignación vigente por caso: CORRECTO
- T06 evidencia no puede mezclar casos: CORRECTO
- T07 fotografía recibida requiere metadatos: CORRECTO
- T08 hash debe tener 32 bytes: CORRECTO
- T09 confianza no se concede al mismo usuario: CORRECTO
- T10 confianza requiere vencimiento posterior: CORRECTO
- T11 historial de revisión no se sobrescribe: CORRECTO
- T12 cámara ajena no se consulta dentro del caso: CORRECTO
- T13 una fuente por soporte de afirmación: CORRECTO
- T14 soporte no puede quedar sin destino: CORRECTO
- T15 candidato no mezcla evidencia de otro caso: CORRECTO
- T16 rango visual no puede ser negativo: CORRECTO
- T17 decisión de candidato exige motivo: CORRECTO
- T18 revisión exige miembro de la organización: CORRECTO
- T19 no se envía push a dispositivo de otro usuario: CORRECTO
- T20 avistamiento futuro rechazado: CORRECTO
- T21 hipótesis necesita ventana temporal positiva: CORRECTO
- T22 cerrar caso requiere motivo y fecha: CORRECTO
- T23 ruta no publica exposición con datos insuficientes: CORRECTO
- T24 se impide autorreferencia de caso duplicado: CORRECTO
- T25 geometría exige SRID declarado: CORRECTO
- T26 destino de soporte pertenece a la misma sesión: CORRECTO
- T27 consulta de indicador exige intervalo: CORRECTO
- T28 estado de objetivo admite OE5 y OE6: CORRECTO
- T29 distancia PostGIS en metros: CORRECTO
- T30 cruce de geometrías: CORRECTO
- T31 56 tablas creadas: CORRECTO
- T32 110 claves foráneas creadas: CORRECTO
- T33 revisión con historial y evento transaccional: CORRECTO
- T34 objetivos ampliados presentes: CORRECTO
- T35 recuperación requiere fecha y respaldo: CORRECTO
- T36 respaldo de recuperación pertenece al caso: CORRECTO

Limitaciones: entorno PGlite/WebAssembly, sin servidor PostgreSQL nativo ni ensayos de concurrencia, rendimiento, restauración o permisos de la API. El prototipo visual no está conectado por esta entrega.
