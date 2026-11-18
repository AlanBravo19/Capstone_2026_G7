# Mapa operativo y recorrido ciudadano · Beta 0.16.0

## Qué puede explicar el equipo

La organización receptora ve dónde se declaró un incidente y dónde se situaron los avistamientos que su equipo aceptó. Ambas ubicaciones tienen una fecha y se refieren a hechos relatados. La posición actual del vehículo robado sigue siendo desconocida.

| Decisión de interfaz | Respaldo documental o técnico | Aplicación en esta beta |
| --- | --- | --- |
| Mantener una vista propia para el operador | Libro del Proyecto v4.1, p. 9, bandeja institucional y p. 30, acceso a coordenadas dentro del ámbito del operador | El mapa es una presentación adicional de los casos abiertos de una organización en la que el operador tiene membresía vigente. La bandeja sigue disponible. |
| Diferenciar el incidente del avistamiento | Libro v4.1, p. 8, hora de observación y coordenada precisa institucional | El azul identifica el lugar del reporte. El verde identifica una observación aceptada tras revisión humana. Las observaciones pendientes se revisan en su bandeja. |
| Identificar la zona de trabajo | Esquema SQL, tabla organización, campo territorio_cobertura | El selector muestra el nombre de la organización y la cobertura declarada. El encuadre incluye los eventos filtrados. La cobertura es texto y la beta carece de polígonos oficiales de jurisdicción. |
| Consultar un punto y seguir el caso | Libro v4.1, pp. 8–9, gestión y seguimiento | Desde un punto o una fila se abre la ficha. Allí se revisan aportes, se deja una decisión y se puede comunicar una novedad al titular. |

El mapa general de eventos, sus colores, la lista lateral y sus filtros son decisiones de interfaz de esta versión. El libro respalda el acceso a los datos y el flujo institucional. La visualización histórica y la exploración con cámaras que también trata el libro tienen finalidades distintas. Este mapa no dibuja niveles de criminalidad, una ruta atribuida al vehículo ni imágenes de cámaras.

## Uso en escritorio

1. Ingresar a **Operaciones → Mapa operativo** con la cuenta institucional. Si la cuenta tiene varias membresías, seleccionar una organización.
2. Elegir el tipo de evento o buscar por texto de sector o folio. Se consideran hasta 300 eventos recientes de casos abiertos en la organización elegida. Los eventos sin coordenadas siguen disponibles en la lista.
3. Seleccionar una marca o abrir el folio desde la lista. **Centrar vista** vuelve a encuadrar los resultados. **Actualizar** consulta nuevamente el servidor. La visualización corresponde al momento de esa consulta.
4. En ausencia de eventos se muestra un estado vacío. La cartografía usa Leaflet y teselas de OpenStreetMap con atribución visible. La lista sigue disponible si la red no entrega las teselas. Los marcadores proceden de la API de RutaAlerta.

## Uso en Android

**Vi un vehículo** lleva desde Inicio a las solicitudes de colaboración. **Mis avistamientos** permite consultar los aportes propios. **Mensajes del caso** abre la bandeja privada del usuario. Un conductor puede reportar el robo de un vehículo vinculado y un pasajero puede enviar un aviso de testigo.

## Ensayo reproducible de Chillán

El ensayo usa una base temporal con cuentas separadas para titular, colaborador y operador. El caso, la foto y el mensaje son ficticios. La prueba del servidor está en `tests/test_recorrido_chillan.py`.

| Paso | Resultado que comprueba la prueba |
| --- | --- |
| El titular reporta y consiente la colaboración | El caso figura en el mapa de su organización. La consulta del colaborador y la de otro operador sin esa membresía se rechazan. |
| El operador revisa y publica | La solicitud aparece entre los casos cercanos al consultar desde Chillán con un radio de 30 km. Desde Santiago aparece en otras zonas. |
| El colaborador adjunta una foto | Una imagen inválida se rechaza. Reintentar el mismo envío válido conserva un único aporte. |
| El operador revisa la fotografía | La foto queda restringida. El marcador del avistamiento se incorpora al mapa después de la aceptación. |
| El operador comunica una novedad | El titular recibe el mensaje una sola vez y puede marcarlo como leído. El colaborador recibe la decisión sobre su aporte. |

La validación en dispositivos físicos, la conectividad real de terreno y la cobertura que declararía una institución corresponden a un piloto posterior.

## Resultado del 16 de noviembre de 2026

Pasaron 73 pruebas del servidor sobre PostgreSQL temporal con PostGIS y 28 pruebas de Flutter. La prueba móvil remota, que requiere habilitación explícita, quedó omitida. En el ensayo adicional con un navegador real, el operador abrió el caso desde el mapa, revisó la foto y envió el mensaje. Se comprobó mediante la API que llegó al titular y que el colaborador recibió la decisión. El envío ciudadano del ensayo se hizo mediante la API; los accesos de Inicio se probaron por separado en Flutter.

Se verificaron la carga de cartografía, los filtros de folio y tipo, la lista de dos eventos y la vista estrecha de 390 píxeles. La ficha de cada evento identifica si se trata del lugar declarado del reporte o del lugar de una observación aceptada.

La cartografía base y sus condiciones de uso están documentadas por sus proveedores. [Referencia de Leaflet](https://leafletjs.com/reference.html) y [política de teselas de OpenStreetMap](https://operations.osmfoundation.org/policies/tiles/).
