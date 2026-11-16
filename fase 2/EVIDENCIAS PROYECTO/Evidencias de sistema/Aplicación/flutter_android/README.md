# RutaAlerta · Beta 0.8.0

## Beta 0.9 · Aplicación ciudadana y escritorio institucional

En Android, Inicio permite consultar solicitudes con «Vi un vehículo» y colaborar sin tener auto. Las cuatro secciones son Inicio, Colaborar, Mapa y Cuenta. El registro de un vehículo vinculado se utiliza al reportar su robo. El afectado selecciona qué organización recibirá ese reporte.

El escritorio está en https://rutaalerta-mvp-g7.vercel.app/operaciones. Se ingresa con invitación, credenciales y el segundo factor cuando está activo. La membresía vigente determina qué casos puede consultar el operador. El panel permite filtrar por estado y folio, leer el relato privado, revisar aportes y fotos, gestionar publicaciones consentidas, cerrar casos, revisar fuentes territoriales y consultar el inventario de cámaras. La web de acceso ciudadano anterior sigue en /ciudadania.

El panel usa la API de RutaAlerta y la base existente de 65 tablas. Su interfaz usa HTML, CSS y JavaScript. La aprobación de un antecedente, una publicación o una evidencia exige una decisión humana.


Documentación vigente: [ESTADO_FUNCIONAL_080.md](ESTADO_FUNCIONAL_080.md). Correo real por Brevo, TOTP, desbloqueo biométrico Android, lugares privados, rutas con apertura Google Maps/Waze y avisos locales basados en fuentes revisadas. El esquema actual tiene 65 tablas. SMS no contratado; no se simula en operación.

El contenido siguiente documenta la versión anterior:

# RutaAlerta · Flutter Android 0.7.0+6

Aplicación nativa Flutter conectada por HTTPS a la beta existente. Código editable en `lib/`, servicio Android en `android/app/src/main/kotlin/`. El APK no contiene claves privadas. Instalar en Android 8 o superior; firma de desarrollo, no publicación en tienda.

Consultar [ESTADO_FUNCIONAL_070.md](ESTADO_FUNCIONAL_070.md) para todos los flujos incorporados, pasos de prueba, autenticación y pendientes reales. La app mantiene el mapa azul 3D, GPS y servicio voluntario de trayecto de las versiones anteriores.

Nuevo: autenticador TOTP real, códigos de recuperación, gestión de sesiones/contraseña, seguimiento con fotos, confianza revocable, colaboración con consentimiento y revisión, avistamientos, notificaciones internas y gestión institucional. Correo/SMS reales pendientes de proveedor. No hay cámaras en vivo, análisis de IA, navegación ni alertas históricas en segundo plano.

Compilar: ejecutar `Compilar_Android.ps1`, o `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --debug`. La API debe tener aplicada la migración 05 y el servidor 0.7.0. Versiones fijadas en `pubspec.lock`.

Los resultados en `evidencias/` distinguen pruebas locales con datos controlados de las verificaciones remotas. No se afirma una validación en teléfono físico ni un trayecto real.
