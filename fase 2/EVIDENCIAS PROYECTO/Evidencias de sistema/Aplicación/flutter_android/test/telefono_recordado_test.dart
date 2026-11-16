import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rutaalerta_movil/api.dart';
import 'package:rutaalerta_movil/session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Recupera una sesión validada al reabrir, admite reintento sin red y respeta el cierre', () async {
    String? stored;
    bool offline = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(Session.device, (call) async {
      if (call.method == 'save') stored = call.arguments['token'];
      if (call.method == 'clear') stored = null;
      return call.method == 'read' ? stored : null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(Session.device, null));
    Session open() => Session(
      RutaApi(
        client: MockClient((r) async {
          if (offline) throw http.ClientException('sin red');
          if (r.url.path == '/sesiones/mfa') {
            expect(jsonDecode(r.body)['recordar_telefono'], isTrue);
            return http.Response('{"token":"sesion-ficticia"}', 201);
          }
          expect(r.headers['Authorization'], 'Bearer sesion-ficticia');
          return http.Response(switch (r.url.path) {
            '/mi-perfil' => '{"id_usuario":12}',
            '/identidad/mi-estado' => '{}',
            '/sesiones/cerrar' => '',
            _ => '[]',
          }, 200);
        }),
      ),
    );
    await (open()..mfaChallenge = 'prueba').confirmMfa('123456');
    final reinicio = open();
    offline = true;
    await reinicio.restore();
    expect(reinicio.restoreError, isNotNull);
    expect(stored, 'sesion-ficticia');
    offline = false;
    await reinicio.restore();
    expect(reinicio.profile?['id_usuario'], 12);
    await reinicio.logout();
    final despues = open();
    await despues.restore();
    expect(despues.signedIn, isFalse);
    expect(stored, isNull);
  });
}
