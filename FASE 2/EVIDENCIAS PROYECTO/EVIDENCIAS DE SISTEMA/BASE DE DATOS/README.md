# RutaAlerta — entrega de modelos Capstone

Grupo 7 · Jorge Ceballos, Juan Marinan y Alan Bravo. DUOC UC, sede San Andrés, Concepción.
Docentes: Juan Pablo Mellado Alarcón y Mabel Alejandra Herrera Pino.
Consolidación: **29 de septiembre de 2026**. Corresponde al material solicitado para el 25 de septiembre; no se declara una entrega retroactiva.

## Qué revisar primero

1. `RutaAlerta_Entrega_Capstone.pdf`: alcance, objetivos medibles, actores, relaciones UML, trazabilidad, decisiones, validación y guía de defensa. También se entrega Word editable.
2. `Diagramas_UML.pdf`: UML general y cinco vistas por ámbito. Actores clasificados, límite de RutaAlerta, include/extend y generalización.
3. `Modelo_Conceptual_MER.pdf`: entidades, identificadores, atributos, asociaciones, cardinalidad y participación; general y ocho módulos.
4. `Modelo_Fisico_PostgreSQL.pdf`: columnas, PK, FK y tipos; corresponde al SQL entregado.
5. `Visor_RutaAlerta.html`: descargar y abrir en el navegador. Funciona sin conexión; permite elegir vista, ampliar y buscar. No conecta a una base ni envía información.

Los PDF de diagramas son planos vectoriales grandes: usar zoom. No imprimir el plano general reducido a una hoja carta, porque el texto quedará demasiado pequeño. Las vistas por módulo facilitan la revisión. SVG conserva resolución; PNG sirve para presentaciones.

## Contenido completo

- 31 casos de uso; seis objetivos de resultado; seis actores primarios y cuatro secundarios externos.
- 56 tablas, 549 columnas, 110 claves foráneas y cinco vistas internas.
- Ocho módulos de datos y 24 vistas gráficas entre UML, MER y ER.
- `anexos/Trazabilidad_CU_OE_Datos.csv`: todas las relaciones caso–objetivo–datos.
- `anexos/Catalogo_Casos_de_Uso.md`: actores, precondiciones, flujo, alternativas y resultados.
- `anexos/Diccionario_completo.md` y `Diccionario_columnas.csv`: atributos, tipos, nulabilidad y referencias.
- `anexos/Relaciones_cardinalidad.csv`: todas las FK, multiplicidades y participación.
- `anexos/Indicadores_y_datos.md`: M01 a M18, denominadores y fuentes de información.
- `fuentes/`: DOT, PlantUML y catálogos JSON editables.
- `verificacion/`: pruebas y resultados reales de esta versión.

## Crear la base PostgreSQL y ver las conexiones

Requisito: un servidor PostgreSQL con el paquete PostGIS disponible y una cuenta de despliegue habilitada para crear la extensión. No usar MySQL ni Oracle. La ejecución comprobada en esta entrega fue PostgreSQL 18.3 / PostGIS 3.6.2 mediante PGlite; validar por separado la combinación del servidor nativo elegido por el equipo.

1. Crear una **base vacía**, por ejemplo `rutaalerta_demo`, en el servidor local o de desarrollo. Crear la base desde la herramienta administrativa, fuera de una transacción SQL.
2. Conectarse a ella en DBeaver o pgAdmin. Abrir y ejecutar como script `sql/RutaAlerta_PostgreSQL_Completo.sql`. Alternativamente, ejecutar `01_Esquema_PostgreSQL_PostGIS.sql` y `02_Vistas_y_operaciones.sql` en ese orden. **Elegir sólo una alternativa.**
3. Ejecutar `sql/06_Catalogo_indicadores.sql` para cargar las definiciones M01 a M18, sin resultados inventados.
4. Para el ensayo, ejecutar `sql/03_Datos_demo.sql` una sola vez y únicamente en una base nueva de demostración. Contiene identidades, vehículos, cámaras y hechos ficticios. Los correos usan el dominio reservado `example.invalid`; no hay credenciales válidas ni archivos reales.
5. Ejecutar `sql/04_Pruebas_integridad.sql`. Deben obtenerse 36 filas CORRECTO. Las pruebas revierten sus cambios, pero los contadores de secuencia pueden avanzar.
6. En DBeaver, actualizar el navegador de bases, abrir el esquema `rutaalerta` y la vista de diagrama; también se pueden seleccionar tablas para crear un diagrama personalizado. Se dibujan las conexiones a partir de las claves foráneas reales.
7. `sql/05_Consultas_espaciales.sql` muestra proximidad de cámaras, cruce de coberturas y agregación territorial con datos de prueba.

Con psql ya conectado a la base elegida, se puede ejecutar cada archivo mediante `\i ruta/del/archivo.sql`; usar `\set ON_ERROR_STOP on` para detenerse ante un error. No repetir el esquema inicial en una base que ya lo contiene. Los scripts no borran tablas ni migran automáticamente datos antiguos.

## Qué asegura la base y qué falta implementar en la aplicación

La base asegura existencia de referencias, ámbitos compuestos, unicidad, reglas locales y algunas operaciones transaccionales. FastAPI debe autenticar al actor y autorizar cada caso, organización, contacto, evidencia y exportación. No basta con entregar un identificador de usuario desde la app.

No se entregan cuentas productivas ni políticas RLS. No conceder permisos SQL a ciudadanos. Configurar una cuenta de servicio limitada, almacenamiento privado, gestor de secretos, transporte seguro, retención y respaldos antes de una operación real. La bitácora no constituye por sí sola una cadena de custodia judicial.

Los hechos sin revisión no alimentan automáticamente el mapa como datos confirmados. El asistente no publica alertas ni cierra casos. El ciudadano ve seguimiento limitado; las coordenadas precisas y recorridos de búsqueda permanecen en el ámbito institucional.

## Consistencia de versiones

Esta entrega concreta el diseño del libro v4.1: 41 tablas anteriores + 12 de búsqueda/IA + 3 soportes para consulta de video y métricas = 56. Sustituye los tipos anteriores MySQL/Oracle por PostgreSQL/PostGIS. No altera los documentos históricos del repositorio. Los nombres largos `id_observacion_busqueda`, `id_hipotesis_ruta` y similares normalizan las abreviaturas del libro.

OE5 y OE6 son ampliaciones que se deben ratificar en el control de alcance. La presencia de tablas no prueba implementación de cámaras, modelos IA o resultados de usuarios. El informe separa diseño, prueba SQL y despliegue.

## Subir al GitHub del equipo

Copiar la carpeta `documentacion/RutaAlerta` de este paquete en la raíz de `Capstone_2026_G7`. Revisar diferencias antes de confirmar y conservar los archivos anteriores. No subir contraseñas, tokens, archivos reales de víctimas ni la carpeta de dependencias de herramientas.

Cada integrante realiza su revisión y sus cambios con su cuenta. No fabricar tres commits vacíos ni usar el nombre de otra persona para aparentar participación. El documento `anexos/Reparto_y_revision.md` propone qué revisar y cómo justificar las decisiones. Esta entrega no acredita commits realizados por los compañeros ni publicación en GitHub.

## Fuentes técnicas

- PostgreSQL, restricciones: https://www.postgresql.org/docs/18/ddl-constraints.html
- PostGIS, ST_DWithin: https://postgis.net/docs/ST_DWithin.html
- DBeaver, diagramas: https://dbeaver.com/docs/dbeaver/ER-Diagrams/
- PGlite, extensiones: https://pglite.dev/extensions/
