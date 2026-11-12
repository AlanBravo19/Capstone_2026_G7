import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rutaalerta_movil/api.dart';
import 'package:rutaalerta_movil/session.dart';
import 'package:rutaalerta_movil/biometric.dart';
import 'package:rutaalerta_movil/movilidad.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BiometricAccess.channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(Mobility.channel, null);
  });
  test('cancelar biometría no abre sesión ni llama al servidor', () async {
    var requests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BiometricAccess.channel, (call) async {
          throw PlatformException(code: 'cancelled');
        });
    final s = Session(
      RutaApi(
        client: MockClient((r) async {
          requests++;
          return http.Response('{}', 200);
        }),
      ),
    );
    await expectLater(s.loginBiometric(), throwsA(isA<PlatformException>()));
    expect(s.signedIn, false);
    expect(s.api.token, isEmpty);
    expect(requests, 0);
  });
  test('biometría restaura sólo una sesión que el servidor confirma', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          BiometricAccess.channel,
          (call) async => call.method == 'unlock'
              ? jsonEncode({
                  'token': 'sesion-ficticia',
                  'invitation': 'invitacion-ficticia',
                  'uid': 99,
                })
              : null,
        );
    final s = Session(
      RutaApi(
        client: MockClient((r) async {
          expect(r.headers['Authorization'], 'Bearer sesion-ficticia');
          final data = switch (r.url.path) {
            '/mi-perfil' => {'id_usuario': 99, 'nombre_visible': 'Ensayo'},
            '/identidad/mi-estado' => {'puede_participar': false},
            _ => [],
          };
          return http.Response(jsonEncode(data), 200);
        }),
      ),
    );
    await s.loginBiometric();
    expect(s.signedIn, true);
  });
  test('sesión biométrica revocada no se acepta localmente', () async {
    var cleared = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BiometricAccess.channel, (call) async {
          if (call.method == 'clear') {
            cleared = true;
            return null;
          }
          return jsonEncode({
            'token': 'revocada',
            'invitation': 'invitacion-ficticia',
            'uid': 99,
          });
        });
    final s = Session(
      RutaApi(
        client: MockClient(
          (r) async => http.Response('{"detail":"Sesión revocada"}', 401),
        ),
      ),
    );
    await expectLater(s.loginBiometric(), throwsA(isA<ApiError>()));
    expect(s.signedIn, false);
    expect(s.api.token, isEmpty);
    expect(cleared, true);
  });
  test('Waze recibe destino y Google puede recibir origen explícito', () async {
    final args = <Map>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(Mobility.channel, (call) async {
          args.add(call.arguments as Map);
          return null;
        });
    final dest = {'latitud': -36.84, 'longitud': -73.08};
    await Mobility.navigate('waze', dest);
    await Mobility.navigate(
      'google',
      dest,
      origin: {'latitud': -36.82, 'longitud': -73.05},
    );
    expect(args[0]['provider'], 'waze');
    expect(args[0]['originLat'], isNull);
    expect(args[1]['originLat'], -36.82);
    expect(args[1]['lat'], -36.84);
  });
}
