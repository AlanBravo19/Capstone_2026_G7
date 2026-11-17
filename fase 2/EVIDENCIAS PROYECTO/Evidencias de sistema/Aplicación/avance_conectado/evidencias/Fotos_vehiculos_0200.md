# Fotografía del vehículo en colaboración

La tarjeta de colaboración y el formulario de avistamiento permiten reconocer el vehículo mediante una fotografía autorizada por el titular y seleccionada por el operador. La foto se consulta con la sesión ciudadana y permanece asociada a la solicitud vigente.

## Publicación de la imagen

1. El titular adjunta una fotografía de su vehículo al reporte, solicita colaboración y marca la autorización específica para mostrar esa foto.
2. El operador abre la imagen, revisa su contenido y acepta la evidencia. Debe comprobar que sea apropiada para la comunidad, incluyendo la presencia de personas, documentos u otros datos ajenos a la identificación del vehículo.
3. Al publicar la solicitud, el operador elige esa fotografía entre las autorizadas y aceptadas del caso.
4. La comunidad ve la foto en la tarjeta y al abrir el formulario de colaboración.

La autorización general para solicitar colaboración y la autorización de imagen se registran por separado. Los reportes anteriores pueden autorizar una foto desde el seguimiento antes de su selección por el operador.

## Imagen de referencia

Mientras falte una fotografía habilitada, la interfaz muestra una referencia genérica del tipo de vehículo. Su etiqueta permite reconocer ese carácter ilustrativo. La referencia carece de identificación exacta de marca, modelo o color y se genera localmente mediante los elementos gráficos de la aplicación.

## Vigencia y acceso

El servicio vuelve a comprobar el estado de la solicitud, del caso, de la revisión de la evidencia y de la autorización del titular en cada descarga. Una solicitud vencida o retirada y un caso cerrado dejan de habilitar nuevas descargas. El titular puede revocar la autorización de imagen desde el seguimiento.

La revisión o aceptación de otras evidencias, como fotografías de avistamientos, conserva su propio circuito de acceso privado. El vínculo público de la solicitud identifica únicamente la fotografía seleccionada para mostrar el vehículo.

## Modelo

La migración aditiva 08 incorpora la fecha de autorización de imagen en evidencia y el identificador de foto seleccionada en solicitud_colaboracion. La clave foránea compuesta exige que fotografía y solicitud pertenezcan al mismo caso. El modelo mantiene 66 tablas.

## Comprobación del 17 de noviembre de 2026

Se aprobaron 158 pruebas del servicio sobre una base temporal y 44 pruebas de Flutter, con una prueba remota omitida. El análisis de Flutter terminó sin incidencias. Se comprobaron fotografías privadas, autorización expresa, selección de foto del mismo caso, rechazo de fotos de avistamientos, revocación, vencimiento y cierre.

La prueba en navegador publicó una foto ficticia autorizada, la mostró a otra cuenta ciudadana en la tarjeta y en el formulario de colaboración, y completó un avistamiento con una segunda imagen privada. La captura de interfaz del ensayo distingue la fotografía aportada de la referencia genérica.
