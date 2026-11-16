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
