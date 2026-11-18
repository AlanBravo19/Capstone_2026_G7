# Verificación reproducible del esquema SQL

`run.mjs` crea una base PostgreSQL temporal en memoria con PGlite y PostGIS, ejecuta los scripts de la carpeta `../sql/` y guarda un JSON con el entorno, los conteos del esquema, las 36 pruebas de integridad, las consultas espaciales y una muestra de las vistas.

```
npm install
node run.mjs ../sql ../resultados completo   # script completo + 06 + 03 + 04 + 05
node run.mjs ../sql ../resultados modular    # 01 + 02 + 06 + 03 + 04 + 05
```

- Dependencias fijadas: `@electric-sql/pglite` 0.5.8 y `@electric-sql/pglite-postgis` 0.2.8.
- Ejecución registrada el 14/10/2026 en Windows 11 con Node.js v24.16.0: 36/36 pruebas correctas en ambas rutas.
- Es una ejecución de PostgreSQL compilado en WebAssembly: no reemplaza la prueba en un servidor nativo, ni pruebas de concurrencia, rendimiento o restauración.
- No subir `node_modules/` al repositorio.
- El script fue preparado con asistencia de IA a partir de `../verificacion/verificar_sql.mjs`; el equipo debe repetir la ejecución y conservar su propio resultado.
