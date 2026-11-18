# Verificación del avance Flutter Android

29/10/2026. Flutter 3.47.8, Dart 3.13.7, Java 21.0.7 y Android SDK 36 en Windows.

- Análisis Flutter: sin incidencias. Registro en flutter_analyze.txt.
- Pruebas locales: 6 aprobadas. La prueba remota se omite deliberadamente en la ejecución local (1 omitida); no se cuentan 7 éxitos en ese lote. Registro en flutter_test.txt.
- Ejecución remota separada: 1 prueba de flujo completo aprobada contra Vercel/Supabase. Crea datos ficticios, completa contactos simulados, guarda vehículo y reporte, comprueba coordenadas PostGIS y revoca sesión. Registro en flutter_api_real.txt.
- APK debug 0.4.0+1 compilado correctamente y firma APK v2 verificada. Registro de compilación en compilacion_apk.txt; tamaño y SHA-256 en resumen_android.json. Es una firma de desarrollo, no una publicación de Google Play.
- Instalación Android: `Success`; apertura de MainActivity observada. Pantalla Flutter revisada visualmente y capturada en android_login.png.
- Servicio: prueba técnica directa con ADB y permisos concedidos únicamente en el emulador. Se detectó TripLocationService con `isForeground=true`, tipo location `0x00000008`, notificación 731 y pantalla NexusLauncher activa después de enviar HOME. Salida real en android_segundo_plano.txt. No equivale a haber probado el flujo completo del botón Trayecto ni un viaje con Waze.
- Limitación real: el emulador presentó ANR del sistema y de Google FusedLocationService por recursos limitados. La escritura en el formulario de acceso no fue fiable y no se validó el inicio de sesión desde esa interfaz. Se conserva captura de la incidencia en android_sistema_anr.png. El acceso y guardado desde el cliente Dart se verificaron por separado contra la API real.
- La continuidad prolongada del servicio no quedó validada. Al final ya no había servicio activo; la orden de detener informó que no estaba ejecutándose. La salida se conserva en android_servicio_detenido.txt. No se atribuye a esta prueba un resultado de detención mediante el botón de la interfaz.
- No se ha probado en teléfono físico ni con Waze. No se ha verificado funcionamiento durante un viaje real.

El primer empaquetado sufrió un error de memoria de Java con el emulador abierto. Se cerró el emulador, se redujo Gradle a dos trabajadores y 1536 MB de heap, y la compilación posterior terminó correctamente. También se ajustaron las rutas cortas de Windows y el directorio de sockets temporales de Java. No se alteraron las medidas de seguridad del teléfono.

Correo/SMS aún son de prueba. El modo trayecto es una base local de ubicación con servicio Android y notificación, no un sistema terminado de avisos por historial, seguimiento de vehículos, cámaras ni IA.
