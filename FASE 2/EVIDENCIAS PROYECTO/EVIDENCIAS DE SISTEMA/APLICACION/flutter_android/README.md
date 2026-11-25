# RutaAlerta · Beta 0.24.0

La interfaz usa una paleta oscura, tipografía Manrope y una barra de navegación compartida. Inicio prioriza los avisos y el mapa. Cuenta agrupa las opciones de participación y seguridad. La fuente está incluida con su [licencia SIL Open Font License](assets/fonts/Manrope-OFL.txt).

El mapa de Inicio se puede tocar para ampliarlo. El color rojo muestra concentraciones de antecedentes históricos revisados. En **Mis lugares y rutas** se puede buscar una dirección puntual, seleccionar un punto en el mapa o usar Casa y Trabajo guardados. La API 0.22 prioriza las alternativas que cruzan menos zonas consultadas. En **Reportar**, se selecciona primero el punto del hecho y después se confirma la comuna sugerida o se busca en el catálogo. La referencia de calle del reporte es opcional.

En **Mis vehículos**, activa **Adjuntar padrón y verificar vínculo** para seleccionar la organización revisora y tomar o elegir una foto del documento. También puedes enviar el padrón más adelante para un vínculo pendiente. La opción **Revisar si la patente coincide** autoriza que la foto se envíe a un servicio externo (GroqCloud) para comparar la patente del padrón con la registrada. Una discrepancia legible devuelve el envío para corrección y puedes elegir la revisión directa. El supervisor toma la decisión en la web institucional.

La versión incluye la solicitud de revisión del vínculo, la declaración de sustracción, el estado de la alerta en el seguimiento y la actualización de la lista de alertas en primer plano. La prueba de las zonas y el padrón en Android requiere una instancia de la API 0.22 accesible por HTTPS. La demostración de tres roles se ejecuta en el navegador con el script local de la API.

Las solicitudes de colaboración muestran la fotografía del vehículo autorizada por el titular y elegida por el operador. El formulario de avistamiento mantiene esa foto y la descripción pública. Desde el seguimiento se puede autorizar una fotografía anterior o revocar su publicación. Mientras falte una foto habilitada, la app presenta una referencia genérica por tipo de vehículo.

La ubicación del reporte y del avistamiento se selecciona en el mapa compartido o mediante GPS. En un avistamiento, selecciona la comuna del catálogo y añade la referencia del sector. Desde **Mis vehículos** puedes quitar el vínculo cuando el vehículo carece de casos abiertos. El titular puede añadir antecedentes privados desde su seguimiento.

En **Reportar** puedes adjuntar una foto y autorizar que el operador publique una solicitud. En **Colaborar** selecciona el vehículo para informar dónde y cuándo lo viste y adjuntar una imagen. Desde el mapa de **Inicio** puedes consultar los vehículos publicados y antecedentes históricos del sector.

## Beta 0.16.0

El panel institucional abre el mapa de casos abiertos de la organización. Se distinguen reportes y avistamientos aceptados y se puede abrir el folio para revisarlo. En Inicio de Android se accede a Vi un vehículo, Mensajes del caso y Mis avistamientos.

## Historial

# RutaAlerta · Beta 0.15.0

Al activar el autenticador, el servidor revoca las sesiones anteriores y entrega una nueva al cliente que presentó el código. La opción «Recordar este teléfono» conserva el acceso ciudadano hasta 30 días después de verificar el segundo factor. Android cifra el acceso en el dispositivo. Si se usa huella, se requiere el desbloqueo biométrico. La app revalida la sesión al abrir y ofrece reintento si falta conexión. Las cuentas con membresía institucional conservan su plazo habitual.

## Historial

# RutaAlerta · Android 0.14.0

La entrega móvil se compila en modo release con el mismo identificador y certificado de la beta anterior. La API compatible continúa en 0.13.0.

## Ubicación y navegación

En Mapa, pulsa el icono de ubicación, concede el permiso y espera una lectura reciente. **Usar mi GPS** lleva las coordenadas al formulario. También puedes usar **Usar mi ubicación actual** directamente desde el reporte o seleccionar otro lugar a mano. El mapa conserva la última perspectiva al cambiar de pestaña. Las pantallas de vehículos, reporte y colaboración cargan sus datos cuando se visitan por primera vez.

## Registro y acceso rápido

1. Crea tu cuenta y confirma el código del correo. Si sales del paso, puedes retomarlo desde Inicio.
2. Con tu contraseña, prepara el autenticador. Ábrelo desde la app o agrega la clave manual como cuenta basada en tiempo. Vuelve a RutaAlerta y escribe los seis dígitos. Si vence el código, usa uno nuevo en la misma pantalla.
3. Guarda los códigos de recuperación. Ingresa otra vez con tu contraseña y un código nuevo.
4. Para habilitar la huella, abre Cuenta → Seguridad y segundo factor → Activar huella. Android confirma la lectura. Bloquear con biometría permite probar el siguiente ingreso. Cerrar sesión elimina el acceso local.

La huella protege una sesión ya verificada en ese teléfono. Cuando el servidor revoca o vence la sesión es necesario autenticarse de nuevo. Al faltar un lector o una huella registrada, la pantalla muestra el motivo y permite abrir los ajustes de Android.

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

# RutaAlerta · Flutter Android 0.7.0+6

Aplicación nativa Flutter conectada por HTTPS a la beta existente. Código editable en `lib/`, servicio Android en `android/app/src/main/kotlin/`. El APK no contiene claves privadas. Instalar en Android 8 o superior; firma de desarrollo, no publicación en tienda.

Consultar [ESTADO_FUNCIONAL_070.md](ESTADO_FUNCIONAL_070.md) para todos los flujos incorporados, pasos de prueba, autenticación y pendientes reales. La app mantiene el mapa azul 3D, GPS y servicio voluntario de trayecto de las versiones anteriores.

Nuevo: autenticador TOTP real, códigos de recuperación, gestión de sesiones/contraseña, seguimiento con fotos, confianza revocable, colaboración con consentimiento y revisión, avistamientos, notificaciones internas y gestión institucional. Correo/SMS reales pendientes de proveedor. No hay cámaras en vivo, análisis de IA, navegación ni alertas históricas en segundo plano.

Compilar: ejecutar `Compilar_Android.ps1`, o `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --debug`. La API debe tener aplicada la migración 05 y el servidor 0.7.0. Versiones fijadas en `pubspec.lock`.

Los resultados en `evidencias/` distinguen pruebas locales con datos controlados de las verificaciones remotas. No se afirma una validación en teléfono físico ni un trayecto real.
