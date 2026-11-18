"""Entrega SMTP con TLS obligatorio. Nunca devuelve ni registra credenciales."""
import os
import smtplib
import ssl
from email.message import EmailMessage
from email.utils import parseaddr


class CorreoNoDisponible(Exception):
    pass


def correo_real():
    return os.getenv('CORREO_TRANSPORTE', 'demo') == 'smtp'


def configuracion_smtp():
    host = os.getenv('SMTP_HOST', '').strip()
    usuario = os.getenv('SMTP_USER', '')
    clave = os.getenv('SMTP_PASSWORD', '')
    remitente = os.getenv('SMTP_FROM', '').strip()
    tls = os.getenv('SMTP_TLS', 'starttls')
    try:
        puerto = int(os.getenv('SMTP_PORT', '587'))
    except ValueError:
        raise CorreoNoDisponible('Configuración de correo incompleta') from None
    if (not all((host, usuario, clave, remitente)) or tls not in ('starttls', 'ssl')
            or not 1 <= puerto <= 65535 or '\n' in remitente or '\r' in remitente
            or '@' not in parseaddr(remitente)[1]):
        raise CorreoNoDisponible('Configuración de correo incompleta')
    return host, puerto, usuario, clave, remitente, tls


def enviar_codigo(destinatario, token, proposito, minutos):
    host, puerto, usuario, clave, remitente, tls = configuracion_smtp()
    if '\r' in destinatario or '\n' in destinatario or '@' not in destinatario:
        raise CorreoNoDisponible('Destinatario inválido')
    mensaje = EmailMessage()
    mensaje['From'] = remitente
    mensaje['To'] = destinatario
    mensaje['Subject'] = ('RutaAlerta: verifica tu correo' if proposito == 'verificar_correo'
                          else 'RutaAlerta: recupera tu contraseña')
    mensaje.set_content(
        f'Copia este código en RutaAlerta:\n\n{token}\n\n'
        f'Vence en {minutos} minutos y solo se puede utilizar una vez.\n'
        'No compartas este código. Si no lo solicitaste, ignora este mensaje.\n'
        'RutaAlerta nunca te pedirá tu contraseña por correo.\n')
    contexto = ssl.create_default_context()
    try:
        if tls == 'ssl':
            cliente = smtplib.SMTP_SSL(host, puerto, timeout=10, context=contexto)
        else:
            cliente = smtplib.SMTP(host, puerto, timeout=10)
        with cliente as smtp:
            if tls == 'starttls':
                smtp.ehlo()
                smtp.starttls(context=contexto)
                smtp.ehlo()
            smtp.login(usuario, clave)
            if smtp.send_message(mensaje):
                raise CorreoNoDisponible('No fue posible entregar el correo')
    except (smtplib.SMTPException, OSError, ValueError):
        raise CorreoNoDisponible('No fue posible entregar el correo') from None
