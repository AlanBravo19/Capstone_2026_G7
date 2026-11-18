# Reproducir la verificación

La opción principal es ejecutar los scripts con PostgreSQL/PostGIS nativo según el README y conservar el resultado obtenido por el equipo.

Para repetir el entorno de esta entrega, con Node.js y npm instalados, entrar en esta carpeta y ejecutar `npm install`, seguido de `npm test`. Las dependencias están fijadas a PGlite 0.5.8 y su extensión PostGIS 0.2.8. Se usa una base temporal en memoria, sin credenciales ni servicios externos. No subir node_modules al repositorio.

Resultado esperado: 36 pruebas correctas. El esquema, el catálogo, los ejemplos y los scripts de prueba contienen datos sintéticos o definiciones; no representan resultados reales de usuarios. La versión compilada de PostgreSQL/PostGIS queda en resultado_sql.json.

La revisión estática confirma cobertura de 31 casos, seis objetivos y 56 tablas. Los SVG fueron renderizados y los PDF revisados. El JavaScript del visor pasó una comprobación de sintaxis; no se ejecutó una prueba automatizada de navegador por falta de un navegador local disponible.
