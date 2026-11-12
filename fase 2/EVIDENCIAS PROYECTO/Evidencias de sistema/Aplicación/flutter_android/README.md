# RutaAlerta · Flutter Android 0.7.0+6

Aplicación nativa Flutter conectada por HTTPS a la beta existente. Código editable en `lib/`, servicio Android en `android/app/src/main/kotlin/`. El APK no contiene claves privadas. Instalar en Android 8 o superior; firma de desarrollo, no publicación en tienda.

Consultar [ESTADO_FUNCIONAL_070.md](ESTADO_FUNCIONAL_070.md) para todos los flujos incorporados, pasos de prueba, autenticación y pendientes reales. La app mantiene el mapa azul 3D, GPS y servicio voluntario de trayecto de las versiones anteriores.

Nuevo: autenticador TOTP real, códigos de recuperación, gestión de sesiones/contraseña, seguimiento con fotos, confianza revocable, colaboración con consentimiento y revisión, avistamientos, notificaciones internas y gestión institucional. Correo/SMS reales pendientes de proveedor. No hay cámaras en vivo, análisis de IA, navegación ni alertas históricas en segundo plano.

Compilar: ejecutar `Compilar_Android.ps1`, o `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --debug`. La API debe tener aplicada la migración 05 y el servidor 0.7.0. Versiones fijadas en `pubspec.lock`.

Los resultados en `evidencias/` distinguen pruebas locales con datos controlados de las verificaciones remotas. No se afirma una validación en teléfono físico ni un trayecto real.
