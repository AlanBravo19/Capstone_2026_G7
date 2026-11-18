# Registro y vehículos · Verificación del 15 de noviembre de 2026

Revisión funcional del repositorio del curso: 14db63b. API pública: 0.10.0-beta. Android: 0.10.0+9.

| Entorno | Comprobación realizada | Resultado |
|---|---|---|
| API local con PGlite y PostGIS desechables | Suite de 65 pruebas. Incluye registro sin invitación, orden correo → autenticador, segundo factor, catálogos y patentes. | 65 aprobadas. |
| Integración en la base desechable | Dos ciudadanos crean cuentas independientes. El transporte de correo se sustituye por un capturador de pruebas. El conductor declara una moto, reporta el incidente y consiente la publicación. Un operador del ámbito la autoriza. La segunda cuenta aporta un avistamiento sin tener vehículo. El operador lo acepta y el afectado ve el resumen. | Secuencia completada por API, con datos ficticios. |
| Flutter | Suite de 20 pruebas, incluida selección de motocicleta, marca y modelo y rechazo de una placa de automóvil antes del envío. | 20 aprobadas. Una prueba remota opcional omitida. Análisis sin incidencias. |
| Android | Compilación del APK de desarrollo y verificación de su firma. | Completadas. |
| Web publicada con Supabase | Navegador de escritorio sobre /ciudadania. Alta de una cuenta técnica sin invitación, petición de código por correo, selección de moto y modelo, error por patente incompatible y reinicio de las selecciones al cambiar el tipo. Intento de acceso al panel con la misma cuenta ciudadana. | El servicio de correo respondió 202 en modo real. Acceso institucional denegado. En esta prueba no se abrió el buzón ni se guardó un incidente en producción. |

Queda pendiente repetir la secuencia con dos teléfonos físicos y un operador en escritorio. La consulta de dispositivos Android de esta sesión no mostró teléfonos conectados.

