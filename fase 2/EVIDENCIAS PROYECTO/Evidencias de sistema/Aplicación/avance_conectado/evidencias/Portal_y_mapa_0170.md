# Colaboración ciudadana y mapa zonal · Beta 0.17.0

## Del reporte privado a la solicitud pública

El titular elige su vehículo, describe el incidente, puede adjuntar una foto y decide si solicita colaboración. En Android puede tomar la foto o elegirla en la galería. El servicio comprueba la imagen, elimina sus metadatos y guarda el reporte, la foto y la autorización en una transacción. Si la imagen es inválida, el titular puede corregirla y volver a enviar el formulario.

El operador revisa los antecedentes, elige qué sector y descripción publicar y fija la vigencia. La publicación dura 24 horas por defecto y admite entre 1 y 72 horas. La persona que reportó puede consultar el estado de publicación desde el seguimiento móvil. Un reporte privado, una solicitud vencida o un caso cerrado quedan fuera de la lista activa.

En **Colaborar** y en el portal web **Vehículos con solicitud activa**, una persona con participación habilitada puede seleccionar una solicitud y enviar un avistamiento. Indica cuándo y dónde vio el vehículo, qué observó y, si dispone de ella, adjunta una imagen de hasta 2 MB. El operador consulta la foto desde la ficha. La comunidad ve la descripción aprobada y el sector aproximado. Las fotos del reporte y del avistamiento permanecen como evidencia privada.

## Cómo leer el mapa móvil

El mapa de inicio y su vista ampliada consultan un radio de 30 km alrededor del centro elegido. Puede usarse el GPS, una ciudad de referencia o un nuevo centro en la vista ampliada. El punto azul de un vehículo representa el sector publicado del incidente. Una zona roja representa el radio de aviso de un antecedente histórico revisado y vigente. Al tocarla se pueden consultar su fuente y fecha. Un sector vacío indica que la consulta no tiene registros que mostrar.

**Simular alerta de proximidad** reproduce dentro de la app la entrada a un radio ficticio de 500 m. **DEMO01** permite practicar un avistamiento si la lista está vacía. Ambos ejercicios son locales y mantienen separados los datos de ensayo y los reportes de los ciudadanos.

## Comprobaciones del 16 de noviembre de 2026

- Servicio y base temporal: 73 pruebas aprobadas, incluidas las de imagen inválida, reintento del reporte, consentimiento, visibilidad y revisión del avistamiento.
- Flutter: 30 pruebas aprobadas y una omitida. Se comprobó que el antecedente conserva su fuente, que aparece el aviso por proximidad y que el ejercicio DEMO01 se completa sin enviar datos al servidor.
- Navegador con base de prueba: dos cuentas ciudadanas y una institucional recorrieron el reporte con imagen y autorización, su publicación y el envío de un avistamiento con una segunda imagen. El operador abrió ambas fotos.
- La captura directa con una cámara física y la precisión del GPS en terreno quedan pendientes de prueba en Android.
