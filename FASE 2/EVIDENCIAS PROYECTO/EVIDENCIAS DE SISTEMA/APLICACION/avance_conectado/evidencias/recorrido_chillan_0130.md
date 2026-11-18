# Ensayo de colaboración en Chillán

Este ejercicio utiliza un titular, un colaborador y un operador ficticios en una base temporal. El punto de referencia de Chillán es aproximado. No representa un robo ocurrido allí.

| Paso | Participante y acción | Qué comprobar |
| --- | --- | --- |
| 1 | El titular crea el reporte y solicita colaboración. | La solicitud queda pendiente de revisión. |
| 2 | El operador abre la ficha, pasa a revisión y publica el texto autorizado. | La solicitud figura entre las búsquedas vigentes. |
| 3 | El colaborador abre Colaborar y usa el GPS, o define manualmente −36.606, −72.104 y 30 km. | En el ensayo, la solicitud aparece entre los cercanos en Chillán y en otras zonas desde Santiago. |
| 4 | El colaborador indica sector, hora y ubicación del avistamiento. Puede tomar una foto o elegirla de la galería. | El servidor guarda la imagen y el aporte juntos. Un reintento conserva un solo aporte. Una imagen inválida permite corregir y reenviar. |
| 5 | En Avistamientos pendientes, el operador abre la ficha y la foto. Evalúa el aporte e ingresa un resumen para el titular. | El aporte sale de pendientes. El titular ve el resumen y el colaborador puede consultar la decisión. |
| 6 | El operador abre Notificar al afectado y envía un mensaje. | La campana del titular muestra el mensaje en la app y permite marcarlo como leído. |

**Reproducción automática.** En el servidor de pruebas, con el esquema y las semillas de la suite cargados, ejecutar `python -m pytest tests/test_recorrido_chillan.py -q`. Las cuentas de la suite y los datos de referencia son exclusivos de la base de ensayo.

**Alcance.** El radio se calcula con PostGIS desde el centro aproximado de la publicación. La foto de ensayo es sintética. La fotografía privada y las coordenadas del avistamiento se revisan en la organización responsable. Los mensajes de casos se consultan en la bandeja interna al abrirla o actualizarla.

**Resultado del 16 de noviembre de 2026.** La suite del servidor aprobó 72 pruebas. Flutter aprobó 23 y omitió una integración remota que crea datos. En una ejecución separada, Edge abrió el portal contra la base temporal, publicó la solicitud, mostró la imagen del avistamiento enviado por la API, aceptó el aporte y notificó al titular. Se comprobaron las bandejas del titular y del colaborador. En un emulador Android se verificaron los lugares guardados, el regreso del modo trayecto y las vistas 3D y 2D de Chillán. El emulador mostró un bloqueo al comenzar la primera revisión y permitió completar el recorrido al reiniciar la aplicación con renderizado alternativo. Queda pendiente comprobar la cámara y un trayecto con GPS y Waze en un teléfono físico.

