# Cierre del Capstone y alcance verificable

## Decisiones de funcionamiento solicitadas

- Una patente chilena normalizada identifica un vehículo. Mientras mantenga un vínculo activo o pendiente, su registro en otra cuenta se rechaza. El titular puede retirar voluntariamente el vínculo cuando el vehículo carece de casos abiertos. Los registros históricos del vehículo y del caso se conservan. La nueva asociación declarada requiere el mismo proceso de revisión que la inicial.
- El titular envía nuevos antecedentes privados por el seguimiento. Los avistamientos públicos de colaboración corresponden a otras personas y requieren revisión del operador. El servicio bloquea el aporte ciudadano del propio caso.
- La ubicación elegida en el mapa se envía como coordenadas. La persona puede colocar un punto o usar el GPS. El punto seleccionado representa el lugar observado y puede diferir de su ubicación actual.
- La revisión institucional conserva el alcance de la organización y sus cuentas asignadas. Cada caso debe poder abrirse mediante una dirección propia en el portal.

## Evidencias pendientes

Verificación del 17 de noviembre de 2026: 114 pruebas del servicio aprobadas sobre una base temporal. La prueba de navegador comprobó el dashboard, el enlace de la ficha y el recorrido de reporte con foto, publicación y avistamiento con segunda foto. Flutter aprobó 40 pruebas y dejó omitida una prueba remota.

El catálogo de 346 comunas usa la publicación EIS de MINSAL. Se valida la comuna seleccionada y el formato de la coordenada. El sector es una referencia descriptiva. La comprobación espacial entre punto y límite comunal requiere incorporar polígonos oficiales.

| Entregable | Estado y siguiente comprobación |
| --- | --- |
| Propuesta aprobada | Conservar la referencia y revisar diferencias con el comportamiento actualizado. |
| Código versionado | Registrar el commit de la actualización una vez verificado y publicado. |
| Capturas del recorrido por rol | Generar con cuentas y datos de ensayo, incluyendo reporte, publicación, foto y respuesta del operador. |
| Casos borde por rol | Adjuntar resultados reales de duplicados, retiro con caso abierto, acceso ajeno, rechazo del aporte del titular y reintentos. |
| Android en terreno | Pendiente completar cámara, foto recibida por operador, GPS y permisos de cámara/ubicación denegados. La instalación y el inicio de sesión acreditados en ambos teléfonos no completan esta prueba. |
| Revisión final de alcance | Pendiente validación del equipo y acuerdo docente sobre iOS. |

## Plataformas

La versión instalable disponible es Android. La ejecución del recorrido en un iPhone sigue pendiente. El equipo debe acordar con los docentes si mantiene iOS como compromiso de entrega o ajusta formalmente la entrega a Android. El acuerdo debe reflejarse en propuesta, informe y presentación.

## Recursos de apoyo

Los canales de orientación deben incluir territorio, responsable, fuente y fecha de revisión o vigencia. El equipo debe mantenerlos y comprobar qué recibe el titular. La disponibilidad de una pantalla o de un registro técnico requiere complementarse con contactos reales revisados por el equipo.

## Prueba completa de cierre

1. El titular registra un vehículo de ensayo y reporta el incidente con imagen y autorización de colaboración.
2. El operador revisa la imagen y la ubicación y publica una solicitud.
3. Otra cuenta ciudadana abre la solicitud desde Android, selecciona el lugar en el mapa y envía el avistamiento con foto.
4. El operador revisa el avistamiento y envía una actualización al titular.
5. El titular consulta el mensaje y envía un antecedente privado complementario.
6. Repetir los pasos relevantes con permisos denegados y documentar los mensajes exactos y los resultados observados.
