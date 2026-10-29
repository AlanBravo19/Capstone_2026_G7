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
