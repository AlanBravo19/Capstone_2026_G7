import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rutaalerta_movil/api.dart';
import 'package:rutaalerta_movil/session.dart';
import 'package:rutaalerta_movil/expanded.dart';
import 'package:rutaalerta_movil/biometric.dart';

void main() {
  test(
    'un desafío MFA no abre la sesión antes de validar el segundo factor',
    () async {
      final calls = <String>[];
      final session = Session(
        RutaApi(
          client: MockClient((r) async {
            calls.add(r.url.path);
            final data = switch (r.url.path) {
              '/sesiones' => {
                'requiere_mfa': true,
                'id_desafio': 'desafio-ficticio',
              },
              '/sesiones/mfa' => {'token': 'sesion-completada'},
              '/mi-perfil' => {
                'nombre_visible': 'Persona ficticia',
                'roles': ['ciudadano'],
                'organizaciones': [],
              },
              '/identidad/mi-estado' => {'puede_participar': false},
              _ => [],
            };
            return http.Response(jsonEncode(data), 200);
          }),
        ),
      );
      await session.login('prueba@example.invalid', 'clave-ficticia');
      expect(session.signedIn, false);
      expect(session.api.token, isEmpty);
      expect(calls, ['/sesiones']);
      await session.confirmMfa('123456');
      expect(session.signedIn, true);
      expect(session.mfaChallenge, isNull);
    },
  );
  for (final page in ['security', 'case', 'community', 'operator']) {
    testWidgets('vista $page carga sin desbordes con datos controlados', (
      tester,
    ) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session =
          Session(
              RutaApi(
                client: MockClient((r) async {
                  final data = switch (r.url.path) {
                    '/seguridad/estado' => {'mfa_activo': false},
                    '/seguimiento/1' => {
                      'folio': 'ENSAYO-1',
                      'patente': 'DEMO01',
                      'zona': 'Sector ficticio',
                      'estado': 'en_revision',
                      'es_propietario': true,
                      'es_operador': false,
                      'historial': [],
                      'aportes': [],
                      'evidencias': [],
                    },
                    '/colaboracion' => {'cercanos': [], 'otras_zonas': []},
                    _ => [],
                  };
                  return http.Response.bytes(
                    utf8.encode(jsonEncode(data)),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
                  );
                }),
              ),
            )
            ..profile = {
              'nombre_visible': 'Persona ficticia',
              'organizaciones': [1],
            };
      final Widget screen = switch (page) {
        'security' => SecurityScreen(session: session),
        'case' => CaseScreen(session: session, cid: 1),
        'community' => Scaffold(body: CommunityScreen(session: session)),
        _ => OperatorScreen(session: session),
      };
      if (page == 'security') {
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          BiometricAccess.channel,
          (_) async => {
            'available': false,
            'saved': false,
            'reason': 'Sin lector de prueba',
          },
        );
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(BiometricAccess.channel, null),
        );
      }
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
