"""Pruebas aisladas: python -m unittest discover -s tests -p test_correo_unitario.py -v.
No usan la base remota ni envían mensajes externos.
"""
import os
import smtplib
import unittest
from unittest.mock import MagicMock, patch
from app import correo


class CorreoTests(unittest.TestCase):
    def setUp(self):
        self.env = patch.dict(os.environ, {
            'CORREO_TRANSPORTE':'smtp', 'SMTP_HOST':'smtp.example.invalid',
            'SMTP_USER':'ensayo', 'SMTP_PASSWORD':'clave-ficticia',
            'SMTP_FROM':'RutaAlerta <no-responder@example.invalid>',
            'SMTP_TLS':'starttls', 'SMTP_PORT':'587'})
        self.env.start()
        self.addCleanup(self.env.stop)

    @patch('app.correo.smtplib.SMTP')
    def test_starttls_antes_de_autenticar(self, constructor):
        smtp = constructor.return_value.__enter__.return_value
        smtp.send_message.return_value = {}
        correo.enviar_codigo('persona@example.invalid', 'secreto-unico', 'verificar_correo', 15)
        nombres = [x[0] for x in smtp.method_calls]
        self.assertLess(nombres.index('starttls'), nombres.index('login'))
        mensaje = smtp.send_message.call_args.args[0]
        self.assertIn('secreto-unico', mensaje.get_content())
        self.assertIn('15 minutos', mensaje.get_content())

    @patch('app.correo.smtplib.SMTP_SSL')
    def test_ssl_con_validador_de_certificado(self, constructor):
        os.environ['SMTP_TLS'] = 'ssl'
        constructor.return_value.__enter__.return_value.send_message.return_value = {}
        correo.enviar_codigo('persona@example.invalid', 'codigo', 'recuperar_clave', 30)
        self.assertTrue(constructor.call_args.kwargs['context'].check_hostname)

    def test_rechaza_transporte_sin_tls(self):
        os.environ['SMTP_TLS'] = 'ninguno'
        with self.assertRaises(correo.CorreoNoDisponible):
            correo.enviar_codigo('persona@example.invalid', 'codigo', 'verificar_correo', 15)

    def test_rechaza_credenciales_incompletas(self):
        os.environ['SMTP_PASSWORD'] = ''
        with self.assertRaises(correo.CorreoNoDisponible):
            correo.configuracion_smtp()

    def test_rechaza_inyeccion_en_destinatario(self):
        with self.assertRaises(correo.CorreoNoDisponible):
            correo.enviar_codigo('a@example.invalid\r\nBcc: x@example.invalid', 'codigo', 'verificar_correo', 15)

    @patch('app.correo.smtplib.SMTP', side_effect=smtplib.SMTPAuthenticationError(535, b'clave-ficticia'))
    def test_error_no_expone_credenciales(self, constructor):
        with self.assertRaises(correo.CorreoNoDisponible) as error:
            correo.enviar_codigo('persona@example.invalid', 'codigo', 'verificar_correo', 15)
        self.assertNotIn('clave-ficticia', str(error.exception))

    def test_api_correo_real_no_devuelve_token(self):
        from app.routers import identidad
        conn = MagicMock()
        conn.cursor.return_value.fetchone.side_effect = [(None,), ('pendiente',), ('persona@example.invalid',)]
        with patch.object(identidad, 'limitar_ip'), patch.object(identidad, 'limitar'), \
             patch.object(identidad, 'emitir_token', return_value=('secreto-unico', None)), \
             patch.object(identidad, 'enviar_codigo') as envio:
            respuesta = identidad.solicitar_correo(MagicMock(), {'id_usuario':1}, conn)
        self.assertNotIn('secreto-unico', str(respuesta))
        self.assertNotIn('token_demo', respuesta)
        self.assertEqual(respuesta['canal'], 'correo')
        envio.assert_called_once()

    def test_api_no_finge_envio_si_smtp_falla(self):
        from app.routers import identidad
        from fastapi import HTTPException
        conn = MagicMock()
        conn.cursor.return_value.fetchone.side_effect = [(None,), ('pendiente',), ('persona@example.invalid',)]
        with patch.object(identidad, 'limitar_ip'), patch.object(identidad, 'limitar'), \
             patch.object(identidad, 'emitir_token', return_value=('secreto-unico', None)), \
             patch.object(identidad, 'enviar_codigo', side_effect=correo.CorreoNoDisponible()):
            with self.assertRaises(HTTPException) as error:
                identidad.solicitar_correo(MagicMock(), {'id_usuario':1}, conn)
        self.assertEqual(error.exception.status_code, 503)

    def test_recuperacion_real_no_revela_cuenta_ni_codigo(self):
        from app.routers import cuentas
        from app.esquemas import RecuperacionEntrada
        for filas in [[(1,), ('persona@example.invalid',)], [None]]:
            conn = MagicMock()
            conn.cursor.return_value.fetchone.side_effect = filas
            with patch.object(cuentas, 'limitar_ip'), patch.object(cuentas, 'limitar'), \
                 patch.object(cuentas, 'emitir_token', return_value=('secreto-unico', None)), \
                 patch.object(cuentas, 'enviar_codigo'):
                resultado = cuentas.solicitar_recuperacion(
                    RecuperacionEntrada(correo='persona@example.invalid'), MagicMock(), conn)
            self.assertIsNone(resultado.token_prueba)
            self.assertEqual(resultado.mensaje, 'Si el correo está registrado, se enviarán instrucciones.')

    def test_sin_demo_no_ofrece_sms_simulado(self):
        from app.routers import identidad
        from fastapi import HTTPException
        with patch.object(identidad, 'DEMO', False):
            with self.assertRaises(HTTPException) as error:
                identidad.solicitar_telefono(
                    identidad.TelefonoEntrada(telefono='+56900000000'), {'id_usuario':1}, MagicMock())
        self.assertEqual(error.exception.status_code, 503)

    def test_correo_real_rechaza_tokens_anteriores_de_prueba(self):
        from app.routers import identidad, cuentas
        from app.esquemas import RecuperacionConfirmar
        from fastapi import HTTPException
        for funcion, datos in [
            (identidad.confirmar_correo, identidad.TokenEntrada(token='token-ficticio-anterior-123456')),
            (cuentas.confirmar_recuperacion, RecuperacionConfirmar(
                token='token-ficticio-anterior-123456', nueva_clave='otra-clave-ficticia')),
        ]:
            with self.assertRaises(HTTPException) as error:
                if funcion is identidad.confirmar_correo:
                    funcion(datos, MagicMock(), MagicMock())
                else:
                    funcion(datos, MagicMock())
            self.assertEqual(error.exception.status_code, 400)


if __name__ == '__main__':
    unittest.main()
