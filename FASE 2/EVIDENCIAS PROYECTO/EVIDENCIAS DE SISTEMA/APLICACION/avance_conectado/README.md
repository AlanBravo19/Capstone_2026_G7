# RutaAlerta

La versión 0.27.0 conecta la aplicación Android y el portal institucional con el esquema `rutaalerta` de Supabase. El esquema tiene 68 tablas. La migración 07 dejó 66, la 09 agregó `consulta_encargo` y la 10 agregó `documento_vinculo_vehiculo`. La migración 11 incorpora el tipo documental en esa última tabla. [Descargar RutaAlerta para Android](https://github.com/AlanBravo19/Capstone_2026_G7/releases/tag/v0.27.0)

En **Mis vehículos** se puede adjuntar una imagen del padrón o del permiso de circulación. El supervisor revisa el documento en **Verificar vínculos**, coteja la patente y la relación con el solicitante, y pide respaldo adicional si corresponde. La lectura externa de patente se ofrece sólo para padrones con autorización expresa. Para habilitarla se configuran `GROQ_PADRON_OPERACION=1` y `GROQ_API_KEY` en las variables privadas del servidor.

Con permiso de ubicación, Inicio consulta el GPS. Un antecedente revisado y vigente ya aparece en el mapa. El naranjo agrupa de uno a tres por celda y el rojo histórico agrupa cuatro o más. Un halo con un icono de vehículo marca el sector público aproximado de cada alerta vigente. Para Casa y Trabajo, PostGIS compara los sectores que cruzan los recorridos ofrecidos por el proveedor. Las fichas públicas muestran la vigencia de la búsqueda y las distancias aproximadas cuando se dispone de las ubicaciones.

## Portal de pruebas y mapa de calor

Con las dependencias de Python y `scripts/package.json` instaladas, ejecuta `python scripts/demostrar_alertas.py --poblar-portal` desde la carpeta de la API. El script muestra el enlace y la cuenta temporal. Carga diez vehículos ficticios, aprueba sus vínculos y publica diez alertas tras la revisión institucional simulada. También acepta tres avistamientos. La base funciona en memoria y se descarta al cerrar el proceso.

En **Mapa operativo**, la capa de calor cuenta los reportes con una alerta vigente dentro de los filtros seleccionados. Los avistamientos aceptados se muestran como puntos. En el ensayo, los reportes se concentran en tres sectores ficticios con cinco, tres y dos alertas.

El [portal de ensayo en línea](https://rutaalerta-ensayo-g7.vercel.app/operaciones/mapa) tiene su propia base PostgreSQL y cuentas ficticias preparadas. El [portal de uso real](https://rutaalerta-mvp-g7.vercel.app/operaciones/mapa) concentra las alertas vigentes de cada organización autorizada.

[Flujo, datos ficticios y pruebas de la beta 0.22](evidencias/Zonas_Historicas_y_Verificacion_0220.md)

Android y el portal ciudadano permiten adjuntar una foto del padrón al registrar un vehículo o enviarla después desde Mis vehículos. El supervisor de la organización receptora abre y resuelve la solicitud en **Verificar vínculos**. La imagen queda disponible únicamente durante la revisión. El historial conserva el momento de recepción y la decisión.

[Verificación vehicular y publicación provisional](evidencias/Verificacion_Vehicular_0211.md)

Un reporte de sustracción reciente de un vehículo con vínculo vigente se publica de inmediato como alerta provisional en **Colaborar** al autorizar la difusión. El caso llega al equipo de la organización en la misma operación. Con un vínculo pendiente, el reporte queda en la bandeja institucional para revisión. La app muestra el resultado al guardar y permite consultar el seguimiento.

La publicación automática requiere `ALERTAS_AUTOMATICAS=1`, una organización receptora habilitada con equipo activo y la [migración 09](sql/09_Alertas_Provisionales.sql). El servidor verifica el consentimiento, descarta duplicados activos y permite una provisional por cuenta en 24 horas. El operador conserva la revisión del caso, la consulta del encargo y la suspensión de la alerta.

[Flujo, estados, configuración y guion de demostración](evidencias/Alertas_Provisionales_0210.md)

La comunidad puede ver la foto del vehículo autorizada por el titular y seleccionada por el operador, tanto en la tarjeta como al abrir el avistamiento. Cuando falta una imagen habilitada se muestra una referencia genérica del tipo de vehículo.

[Fotos del vehículo, consentimiento y revisión](evidencias/Fotos_vehiculos_0200.md)

En **Estadísticas** puedes filtrar el año o un rango de fechas, organización, sector y entorno. Se muestran series mensuales, días y horarios, marcas y modelos, desenlaces, aportes y proximidad al inventario de cámaras. El historial territorial revisado se consulta en una serie propia. En **Mi cuenta** se muestran las membresías y permisos institucionales.

[Definición de métricas, fuentes y roles](evidencias/Estadisticas_y_roles_0190.md)

El registro protege la exclusividad de la patente entre cuentas y permite retirar el vínculo cuando el vehículo carece de casos abiertos. El titular añade antecedentes privados desde su seguimiento. El portal institucional incluye dashboard y fichas con dirección propia.

[Checklist de cierre y alcance de plataformas](evidencias/Cierre_Capstone_0180.md)

El titular puede adjuntar una foto al reporte y autorizar la colaboración. Al publicar el operador, el vehículo aparece en el portal ciudadano y Android. Los colaboradores pueden enviar un avistamiento con una segunda foto privada.

[Mapa ciudadano, estados de publicación y pruebas](evidencias/Portal_y_mapa_0170.md)

## Beta 0.16.0

El panel institucional abre el mapa de casos abiertos de la organización. Se distinguen reportes y avistamientos aceptados y se puede abrir el folio para revisarlo. En Inicio de Android se accede a Vi un vehículo, Mensajes del caso y Mis avistamientos.

[Alcance documental y ensayo de Chillán](evidencias/Mapa_operativo_y_recorrido_0160.md)

## Historial

# RutaAlerta · Beta 0.15.0

Al activar el autenticador, el servidor revoca las sesiones anteriores y entrega una nueva al cliente que presentó el código. La opción «Recordar este teléfono» conserva el acceso ciudadano hasta 30 días después de verificar el segundo factor. Android cifra el acceso en el dispositivo. Si se usa huella, se requiere el desbloqueo biométrico. La app revalida la sesión al abrir y ofrece reintento si falta conexión. Las cuentas con membresía institucional conservan su plazo habitual.

## Historial

# RutaAlerta · Beta 0.13.0

El mapa móvil concentra los controles de GPS, perspectiva y ciudades junto a la cartografía. El planificador prioriza origen y destino. Modo trayecto dispone de navegación de regreso. En Colaborar se puede buscar a 30 km del GPS o fijar otra zona. Un colaborador puede adjuntar una foto opcional al avistamiento. Texto y foto se guardan en una sola operación.

En el escritorio, Avistamientos pendientes reúne los aportes de la organización. En la ficha se revisa la fotografía privada, se decide sobre el aporte y se puede enviar una actualización al titular. Los mensajes llegan a la bandeja interna. El ensayo de Chillán se reproduce en una base temporal con tests/test_recorrido_chillan.py del servidor.

## Historial

# RutaAlerta · Beta 0.12.0

En Android cualquier persona puede crear una cuenta ciudadana. Desde Inicio puede buscar vehículos con solicitud activa, informar como testigo o reportar el robo de un vehículo propio. Mapa, Colaborar y Cuenta están en la barra inferior.

El escritorio de operaciones admite cuentas personales previamente habilitadas. La administración asigna la organización y el rol de operador o supervisor por un canal interno. El servidor comprueba la cuenta activa y la membresía al ingresar y al confirmar el segundo factor, si está configurado. El dominio del correo no concede permisos. Las solicitudes de acceso se dirigen a la administración de la institución. La beta utiliza una organización de ensayo.

## Historial

# RutaAlerta · Beta 0.11.0

Alta ciudadana con modalidad de colaboración, aviso privado de pasajero o testigo sin vehículo ni patente, y revisión del aviso en el escritorio. La ficha institucional incorpora responsable, gestiones internas y renovación de publicaciones. Cámaras admite inventario y reproducción local de clips autorizados. La migración 07 amplía el esquema a 66 tablas. El documento alcance_mvp_0110.md en las evidencias del servidor detalla prioridades y pruebas de cierre.

## Historial

# RutaAlerta · Beta 0.10.0

## Registro ciudadano y vehículos

Desde Android o /ciudadania, selecciona Crear cuenta, indica tu nombre, correo y contraseña y confirma el código recibido. Configura una aplicación autenticadora y conserva los códigos de recuperación. El alta pública asigna el rol ciudadano. /operaciones comprueba la membresía institucional. Un acompañante puede colaborar sin registrar un vehículo.

El catálogo de altas admite automóvil, camioneta, furgón, motocicleta y camión. Bus no figura como tipo específico en el esquema. Otro y sin_dato siguen disponibles en los registros históricos. Los 65 objetos de tipo tabla se mantienen. El servidor verifica la combinación de tipo, marca y modelo contra una extracción de las nóminas livianos y pesados del SII 2026. En total hay 6.470 combinaciones distintas. La extracción usa los rótulos de carrocería definidos en scripts/importar_catalogo_sii.py. Omite categorías ambiguas, accesorios y carrocerías sin equivalencia en el MVP. Un modelo ausente no podrá darse de alta hasta actualizar el catálogo. Esta restricción no afecta los registros ya guardados.

La validación de PPU revisa estructura y normaliza separadores. Para cuatro ruedas contempla AA1234, BBBB12 y BBBBB1. Para motocicleta contempla AA123, BBB12 y BBBB1. La introducción de nuevas series depende de la determinación del Registro Civil prevista en el decreto. La app no verifica la emisión de la serie, la existencia de la placa o la propiedad.

Fuentes: [Nóminas SII](https://www.sii.cl/servicios_online/1049-2612.html) y [Decreto 53, artículos 2 y 2 bis](https://www.bcn.cl/leychile/navegar?idNorma=133287&idVersion=2026-01-16).

## Historial de versiones

## Beta 0.9 · Aplicación ciudadana y escritorio institucional

En Android, Inicio permite consultar solicitudes con «Vi un vehículo» y colaborar sin tener auto. Las cuatro secciones son Inicio, Colaborar, Mapa y Cuenta. El registro de un vehículo vinculado se utiliza al reportar su robo. El afectado selecciona qué organización recibirá ese reporte.

El escritorio está en https://rutaalerta-mvp-g7.vercel.app/operaciones. Se ingresa con invitación, credenciales y el segundo factor cuando está activo. La membresía vigente determina qué casos puede consultar el operador. El panel permite filtrar por estado y folio, leer el relato privado, revisar aportes y fotos, gestionar publicaciones consentidas, cerrar casos, revisar fuentes territoriales y consultar el inventario de cámaras. La web de acceso ciudadano anterior sigue en /ciudadania.

El panel usa la API de RutaAlerta y la base existente de 65 tablas. Su interfaz usa HTML, CSS y JavaScript. La aprobación de un antecedente, una publicación o una evidencia exige una decisión humana.


Documentación de la versión 0.8: [ESTADO_FUNCIONAL_080.md](ESTADO_FUNCIONAL_080.md). Correo real por Brevo, TOTP, desbloqueo biométrico Android, lugares privados, rutas con apertura Google Maps/Waze y avisos locales basados en fuentes revisadas. El esquema actual tiene 65 tablas. SMS no contratado; no se simula en operación.

El contenido siguiente documenta la versión anterior:

# RutaAlerta · Beta colaborativa 0.7.0

La documentación vigente de alcance, funcionamiento, límites y puesta en marcha está en [ESTADO_FUNCIONAL_070.md](ESTADO_FUNCIONAL_070.md).

API FastAPI conectada a PostgreSQL/PostGIS en Supabase, con app Flutter Android. Incluye TOTP real, casos privados, seguimiento, fotos privadas, confianza revocable, colaboración revisada, avistamientos, gestión y buzón interno. El correo y SMS no tienen proveedor real configurado; las cámaras, rutas e IA requieren integraciones adicionales detalladas en el estado funcional.

Migración nueva: `sql/05_Beta_Colaborativa.sql` (63 tablas en total, sin borrar datos previos). No recargar el esquema inicial sobre un proyecto existente.

Código preparado con asistencia de IA. Las pruebas reales y sus límites están en `evidencias/`. No atribuye aportes ni aprobación a los integrantes o docentes.
