# RutaAlerta móvil · Flutter Android beta

Aplicación Flutter real, no un WebView. Utiliza la misma API HTTPS y PostgreSQL/PostGIS que la beta web, sin incluir contraseñas de base de datos, invitaciones ni cuentas dentro del APK.

## Funciones incorporadas

- Inicio de sesión, registro ciudadano y recuperación de contraseña mediante la API existente.
- Consulta de cuenta, contactos, vehículos propios y reportes privados.
- Registro de vehículos y reportes con clave de idempotencia conservada ante un fallo de red.
- Mapa interactivo OpenStreetMap con selección manual de ubicación y puntos de casos propios leídos desde PostGIS. El mapa se carga al solicitarlo, con atribución y caché de la biblioteca; no descarga mapas en bloque.
- Base Android de modo trayecto: inicio visible y voluntario, permisos de ubicación y notificaciones, servicio de tipo location, notificación con acción Detener y coordenada local en memoria. No envía recorridos al servidor, no reinicia al encender el teléfono y se detiene al retirar la tarea.

## Límites que se mantienen

Correo/SMS de la beta siguen siendo de prueba: la app indica cuándo los códigos se muestran en pantalla. El envío SMTP real está preparado en el backend, pero no tiene un proveedor configurado. Completar esos pasos no acredita identidad civil.

No se han integrado avisos históricos, cámaras, IA, rutas de navegación ni rastreo de vehículos robados. El servicio de trayecto es una base de ubicación del dispositivo, no una implementación terminada de alertas. La continuidad en segundo plano depende de Android, permisos, fabricante y batería. No se promete funcionamiento después de forzar la detención o revocar permisos.

## Instalación

Usar el APK de desarrollo que se entregue junto al proyecto, en Android 8 o superior. Android puede pedir autorización para instalar desde la aplicación utilizada para abrir el archivo. No desactivar protecciones del teléfono. No se ha publicado en Google Play y la firma de desarrollo no es una firma definitiva de distribución.

Ingresar la invitación privada de la beta y una cuenta de la plataforma; no usar la contraseña de GitHub, Vercel o Supabase. La invitación se introduce en el teléfono, nunca se compila. Sesión e invitación se conservan sólo en memoria: cerrar el proceso requiere volver a ingresar. La misma cuenta de la beta web permite consultar sus datos desde Android.

Para el trayecto: ingresar, abrir Trayecto, leer la explicación, pulsar Iniciar y autorizar permisos. Se puede abrir otra app, como Waze, manteniendo la notificación visible. Detener desde RutaAlerta o desde la notificación. Esta versión no lee la ruta de Waze ni emite avisos territoriales. No operar el teléfono mientras se conduce.

## Desarrollo

Flutter 3.47.8 / Dart 3.13.7, Java 21, Android SDK 36. Dependencias resueltas en pubspec.lock. `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --debug`. Alternativamente ejecutar Compilar_Android.ps1, que evita problemas de rutas con espacios de Windows y sockets temporales de Java. API_BASE puede configurarse mediante --dart-define con una URL HTTPS; nunca pasar claves privadas como dart-define.

Las pruebas locales de API usan respuestas controladas. La prueba remota live_api_test.dart se omite salvo autorización explícita mediante RUTA_EJECUTAR_REMOTO=1 y RUTA_INVITACION en el entorno. Sólo crea datos ficticios y utiliza contactos simulados. Sus credenciales no deben ponerse en archivos públicos.

Código Flutter en lib/, servicio Android en android/app/src/main/kotlin/cl/rutaalerta/rutaalerta_movil/. Los resultados de pruebas y de compilación reales se conservan en evidencias/. Una compilación correcta no demuestra por sí sola que la ubicación funcione durante un viaje real; debe verificarse en el teléfono.

## Referencias

- https://docs.flutter.dev/platform-integration/platform-channels
- https://developer.android.com/develop/background-work/services/fgs/service-types#location
- https://pub.dev/packages/flutter_map
- https://operations.osmfoundation.org/policies/tiles/
