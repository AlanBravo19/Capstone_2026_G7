# Autenticación: avance de integración de correo real

29/10/2026. El inicio de sesión ya valida contraseñas con scrypt y sesiones revocables en PostgreSQL. Este incremento incorpora envío SMTP con TLS de códigos de verificación y recuperación, y formularios de recuperación en la interfaz.

## Estado de esta publicación

- El envío real NO está activado: falta un proveedor y un remitente autorizado.
- No se ha enviado ni recibido un correo externo de comprobación.
- La beta conserva sus canales de prueba identificados. Sus códigos no acreditan control de correo o teléfono ni identidad civil.
- SMS real no está integrado. Fuera del modo de prueba la solicitud de SMS responde 503, sin generar una confirmación ficticia. La participación continúa requiriendo correo y teléfono; no se retira ese requisito para aparentar que está resuelto.

## Configuración privada que falta

Elegir un proveedor SMTP y autorizar un remitente. Guardar solamente en variables privadas de Vercel: CORREO_TRANSPORTE=smtp, SMTP_HOST, SMTP_PORT, SMTP_TLS=starttls (o ssl), SMTP_USER, SMTP_PASSWORD, SMTP_FROM. Nunca subir valores a GitHub. El proveedor puede exigir verificar dominio y DNS.

Los códigos reales se copian desde el correo a la pantalla de RutaAlerta: no se entregan en la respuesta de la API. Vencen y son de un solo uso. La recuperación responde de la misma manera exista o no la cuenta. Un error SMTP no expone credenciales ni simula una entrega exitosa de verificación.

## Antes de habilitar usuarios reales

1. Separar el entorno beta de pruebas del entorno con datos reales. No reutilizar como prueba de identidad las verificaciones simuladas existentes. Preparar la migración o una base limpia y revocar tokens de prueba antes del cambio; este incremento no ejecuta esa migración ni borra registros.
2. Configurar el proveedor y probar envío, recepción, vencimiento, reuso y recuperación con un buzón autorizado. La aceptación SMTP por sí sola no prueba recepción en bandeja de entrada.
3. Desactivar CANALES_DEMO y usar ENTORNO=operacion únicamente después de completar la transición. El arranque exige SMTP configurado; la participación seguirá bloqueada sin SMS real. No anunciar operación pública hasta resolver ese canal y su transición.
4. Definir recuperación asistida, retención y tratamiento de datos personales para esa versión.

## Evidencias de este incremento

Pruebas unitarias aisladas en tests/test_correo_unitario.py, ejecutadas con unittest, sin base externa ni mensajes reales. Cubren TLS obligatorio, errores sin secretos, ausencia de tokens reales en respuestas, respuesta de recuperación no enumeradora y rechazo del SMS ficticio en modo operativo. Resultado real en evidencias/correo_unitario.txt. No constituyen una prueba de entrega externa ni una certificación de seguridad.

Documentación consultada: https://docs.python.org/3.12/library/smtplib.html y https://supabase.com/docs/guides/auth/auth-smtp . El correo SMTP propio mantiene las cuentas existentes; no se ha migrado la identidad a Supabase Auth.
