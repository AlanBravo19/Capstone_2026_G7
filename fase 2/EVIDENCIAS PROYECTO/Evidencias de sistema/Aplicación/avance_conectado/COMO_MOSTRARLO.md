# Demostración para el profesor

1. Abrir https://rutaalerta-mvp-g7.vercel.app/.
2. Consultar localmente `ACCESO_DEMO_PRIVADO.txt`. Su primera clave controla el acceso al ensayo, no es la contraseña de Supabase. No subir ese archivo ni mostrarlo en una grabación pública.
3. Crear una cuenta ficticia con correo terminado en `example.invalid`, o ingresar con el operador ficticio de ese archivo.
4. Para una cuenta ciudadana nueva, solicitar y confirmar el token de correo de ensayo. Después solicitar y confirmar el OTP telefónico de ensayo usando únicamente números ficticios. La pantalla indica que no se enviaron mensajes.
5. Registrar marca, modelo, patente ficticia, color y año. El vínculo queda pendiente; no se declara propiedad validada.
6. Enviar un reporte privado con sector, fecha, descripción y coordenadas de ensayo. Mostrar su folio y la lista de casos propios.
7. Recargar la página, volver a ingresar y comprobar que el vehículo y el caso permanecen: se guardaron en Supabase, no solo en el navegador.
8. Con el operador ficticio, consultar la bandeja y marcar el caso en revisión con un motivo. Esto no lo publica ni genera una denuncia policial.

Explicación sugerida: “Este es un incremento conectado: interfaz web, API y base alojada. Ya guardamos y consultamos registros reales de prueba con permisos. La entrega de correo/SMS se simula de forma explícita y las funciones restantes no se presentan como terminadas”.

El repositorio del grupo conserva esta evidencia en `fase 2/EVIDENCIAS PROYECTO/Evidencias de sistema/Aplicación/avance_conectado`. Vercel despliega la copia privada `JORCEB/rutaalerta-avance-conectado`. Al modificar código, sincronizar ambos; una subida al repositorio del grupo no actualiza automáticamente la copia privada.

## Mapa de reportes

Después de entrar, pulsa **Explorar mapa**. Elige un punto haciendo clic: sus coordenadas pasan al formulario de nuevo reporte. También puedes escribirlas manualmente. Al guardar, el caso aparece en **Ver mis reportes**, con su ubicación leída desde PostGIS. Solo se consultan los casos de la cuenta actual; al salir se eliminan los puntos de la pantalla. Concepción y Santiago son accesos de navegación cartográfica, no zonas de riesgo. El mapa no incluye historial delictual, alertas predictivas ni rastreo GPS.

Cartografía OpenStreetMap y Leaflet 1.9.4; atribución visible, carga de teselas sólo tras pulsar el botón, sin descargas masivas. El proveedor recibe IP y área consultada, no la descripción ni las credenciales de los casos. Si la cartografía falla, el formulario permite escribir coordenadas. Reglas del proveedor: https://operations.osmfoundation.org/policies/tiles/ . Pruebas lógicas de interfaz: `node --test tests/test_mapa.cjs`; no sustituyen una revisión visual en navegador.

## Mapa vectorial 3D — 0.5.0

El mapa base utiliza MapLibre y OpenFreeMap (estilo Liberty), con edificios extruidos desde la capa cartográfica building-3d. Se confirmó que la capa usa render_height y render_min_height, a partir del nivel de zoom 14. La vista inicial usa zoom 16 e inclinación de 55 grados. Es posible alternar 2D/3D, girar, acercar, seleccionar el incidente y consultar puntos propios.

Los volúmenes y alturas dependen de la cobertura del proveedor y pueden ser aproximados. No son cámaras, imágenes en directo ni reconstrucciones verificadas de cada edificio. El proveedor recibe IP y área consultada; no se le transmiten los relatos, patentes o credenciales de los reportes. Las pruebas de lógica no equivalen a una validación visual de cobertura en todas las comunas.

Referencias: https://openfreemap.org/quick_start/ y https://maplibre.org/flutter-maplibre-gl/ . Las notas previas sobre cartografía raster describen versiones anteriores.

## Paleta azul urbano — 0.5.1

Cartografía vectorial personalizada: fondo azul muy claro, edificios azul grisáceo, agua celeste, calles claras y texto azul oscuro. Se ocultan etiquetas secundarias y paradas de transporte para reducir ruido; se conservan calles y puntos principales. La interfaz usa azul profundo #10213C, azul principal #2867D8 y fondo #F2F5FB. El estilo queda guardado en assets/mapa_azul.json (Android) y public/mapa-azul.json (web), con fuentes, alturas y atribución originales. El nombre de estilo es RutaAlerta Azul urbano; la referencia de claridad a apps de movilidad no implica afiliación con esas marcas.

## Ubicación del dispositivo — 0.6.0

En el mapa, pulsar Mi ubicación y autorizar ubicación de Android. Se muestra el punto nativo de ubicación y su precisión; el mapa recibe nuevas lecturas del proveedor del dispositivo. Mi ubicación vuelve a centrar y activa el seguimiento de cámara. Ocultar GPS apaga la capa. Al seleccionar un incidente se deja de seguir la cámara, manteniendo separados GPS y reporte. El botón no guarda ni cambia automáticamente el incidente.

El GPS del mapa se pausa al cambiar de pestaña o dejar la app en segundo plano; Modo trayecto es una función distinta, voluntaria, con notificación. No se envía un historial de ubicaciones a la plataforma. Al centrar el mapa, el proveedor cartográfico recibe solicitudes del área consultada. Android puede conceder sólo ubicación aproximada: la app muestra la precisión que recibe y no promete una ubicación exacta. Si pasan más de 30 segundos sin una lectura reciente, se indica última posición sin actualización reciente.

Web: el control de ubicación de MapLibre requiere permiso del navegador y HTTPS. Se retira al ocultar la página y debe reactivarse al volver. Las pruebas de lógica con lecturas simuladas no sustituyen la prueba con GPS físico. Fuente técnica: https://maplibre.org/flutter-maplibre-gl/advanced/user-location/ .
