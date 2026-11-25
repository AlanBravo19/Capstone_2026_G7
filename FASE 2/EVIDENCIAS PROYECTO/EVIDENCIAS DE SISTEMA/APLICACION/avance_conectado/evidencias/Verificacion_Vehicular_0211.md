# Verificación vehicular en RutaAlerta 0.21.1

## Registro y revisión

1. En Android o en el portal ciudadano, activa **Adjuntar padrón y verificar vínculo** al registrar el vehículo. Elige organización y adjunta una foto legible en JPEG, PNG o WebP de hasta 2 MB. También puedes enviar el documento más adelante desde **Mis vehículos**.
2. El padrón permite cotejar la patente y el titular. La comparación del titular con la identidad del solicitante corresponde al procedimiento institucional. Los datos de cuenta por sí solos no acreditan la identidad civil. [Ficha del padrón de ChileAtiende](https://www.chileatiende.gob.cl/fichas/3412-certificados-asociados-a-vehiculos-motorizados-y-hoja-de-vida-del-conductor)
3. En el portal institucional, un **supervisor de la organización receptora** abre **Verificar vínculos** y selecciona **Ver padrón privado**. Para aprobar debe haber solicitado la imagen con su cuenta, confirmar que cotejó los datos y guardar su decisión. Puede rechazar por datos inconsistentes o documentación insuficiente. Un operador ordinario puede atender el caso y revisar avistamientos. Solo supervisión resuelve la verificación vehicular y accede al padrón.
4. El titular ve el estado del vínculo y recibe una novedad. El archivo se elimina del registro activo al resolver la solicitud o retirar el vínculo. Se conserva la bitácora de recepción, acceso y decisión. Las políticas de respaldo o conservación institucional se gobiernan fuera de este flujo.

## Qué pasa cuando el titular reporta un robo

Si el vínculo está vigente en la organización receptora, el titular solicita colaboración y se cumplen las reglas de la beta 0.21, la API registra una **alerta provisional** en la misma operación que recibe el reporte. El portal colaborativo y la app pueden mostrarla en la siguiente consulta. El operador puede revisar la ficha, contrastar el encargo por un canal oficial, revisar los aportes y suspender la difusión cuando corresponda. Si falta la aprobación o alguna condición, el reporte sigue privado para revisión. Una alerta provisional no certifica un encargo policial.

La alerta provisional muestra datos acotados del vehículo y ubicación aproximada. Las fotos destinadas a colaboración siguen el flujo de consentimiento y revisión. El padrón queda fuera de las solicitudes y del expediente público.

## Migración y habilitación

- Sobre un entorno que ya tenga las migraciones `01–09`, aplicar `sql/10_Padron_Privado.sql` antes de la API 0.21.1. El esquema suma `documento_vinculo_vehiculo` y queda en 68 tablas. El rol de servicio accede a la tabla y la API autoriza cada lectura según organización y rol.
- Mantener las habilitaciones global y por organización de la beta 0.21. La publicación provisional funciona solo en un entorno con ambas habilitadas y el resto de los controles vigentes. La instancia desechable de ensayo las activa con datos ficticios.
- Las solicitudes anteriores que se revisaron en un canal institucional conservan su referencia e historial. Las pendientes pueden adjuntar el padrón a la organización que ya las recibió.
- Para probar con una base desechable de PGlite y PostGIS, usar `scripts/demostrar_alertas.py`. La opción `--validar` completa el recorrido y termina. Ambos vehículos de la demostración usan un padrón ficticio. ZQXT91 queda aprobado durante la preparación y ZQXT92 disponible para revisar en el panel.

## Evidencia del ensayo del 18 de noviembre de 2026

- En Edge local, una cuenta titular registró ZQXT93 con una imagen ficticia, el supervisor abrió el padrón privado y resolvió el vínculo, y otra cuenta ciudadana vio la alerta provisional tras un reporte consentido. La tarjeta mostró una imagen de referencia y omitió el documento.
- Aprobaron 174 pruebas de la API sobre PGlite y PostGIS. Las pruebas específicas cubrieron documento inválido sin reserva de patente, acceso denegado a cuentas ajenas y a operador ordinario, consulta previa a la aprobación, retiro del archivo y visibilidad de la alerta.
- La verificación de permisos en una base desechable comprobó que la migración se puede ejecutar dos veces y que el rol anónimo no obtiene filas, aun con un permiso de lectura heredado. El rol de servicio puede guardar, consultar y retirar la imagen.
- Flutter aprobó 44 pruebas y dejó omitida la prueba remota. La comprobación de este flujo completo se realizó en navegador. La captura física del padrón desde Android queda por probar con un teléfono.
