# Revisión colaborativa y commits reales

| Integrante | Responsabilidad de revisión | Evidencia esperada |
|---|---|---|
| Jorge Ceballos | Objetivos, UML, alcance institucional, métricas y defensa | Cambios o decisiones justificadas en informe, casos y matriz |
| Juan Marinan | Ciudadano, cuenta, vehículo, avistamiento, contacto, trayecto y desconexión | Revisión de precondiciones, estados y datos necesarios para Flutter |
| Alan Bravo | PostgreSQL/PostGIS, cardinalidades, integridad y ejecución nativa | Resultado del ensayo en el entorno del equipo, cambios SQL y diagramas concordantes |

El reparto no declara aportes realizados. Los tres deben leer también las áreas de los demás y estar preparados para explicarlas.

## Flujo de trabajo

1. Cada persona actualiza su copia del repositorio y crea una rama para su tarea.
2. Revisa los archivos a su cargo, realiza correcciones reales y explica decisiones que haya comprobado. Una revisión puede documentarse con observaciones concretas; no basta cambiar espacios para aumentar el número de commits.
3. Selecciona únicamente sus archivos modificados con `git add` y realiza un commit descriptivo desde su cuenta.
4. Sube la rama, solicita revisión de un compañero y combina los cambios con la rama principal cuando corresponda.
5. Si se modifica el modelo, mantener en concordancia SQL, JSON, diagramas, diccionario y trazabilidad. No cambiar sólo la imagen.

Mensajes sugeridos después de realizar el trabajo:
- Jorge: `docs: validar casos de uso y trazabilidad de RutaAlerta`
- Juan: `docs: revisar flujos ciudadanos y participación del MER`
- Alan: `db: validar esquema PostgreSQL y relaciones de RutaAlerta`

No se fija una fecha de commit anterior ni se atribuye autoría ajena. Antes de la clase, comprobar que el profesor pueda abrir los PDF y descargar el SQL en la carpeta de documentación del repositorio.
