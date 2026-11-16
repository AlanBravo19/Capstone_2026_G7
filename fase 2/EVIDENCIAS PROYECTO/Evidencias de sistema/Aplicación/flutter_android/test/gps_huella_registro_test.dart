import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as m;
import 'package:rutaalerta_movil/api.dart';
import 'package:rutaalerta_movil/biometric.dart';
import 'package:rutaalerta_movil/expanded.dart';
import 'package:rutaalerta_movil/huella.dart';
import 'package:rutaalerta_movil/map_screen.dart';
import 'package:rutaalerta_movil/session.dart';

void main() {
  testWidgets('Usar mi GPS transfiere una posición vigente sin tocar el mapa', (
    t,
  ) async {
    const channel = MethodChannel('cl.rutaalerta/trayecto');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => true);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final session = Session(RutaApi());
    var transfers = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapScreen(session: session, usePoint: () => transfers++),
        ),
      ),
    );
    final dynamic state = t.state(find.byType(MapScreen));
    m.UserLocation fix(DateTime time) => m.UserLocation(
      position: const m.LatLng(-36.61, -72.1),
      altitude: null,
      bearing: null,
      speed: null,
      horizontalAccuracy: 12,
      verticalAccuracy: null,
      timestamp: time,
      heading: null,
    );
    await state.locate();
    state.receiveLocation(
      fix(DateTime.now().subtract(const Duration(minutes: 1))),
    );
    state.useLocation();
    expect(transfers, 0);
    expect(session.selectedPoint, isNull);
    state.receiveLocation(fix(DateTime.now()));
    state.useLocation();
    expect(transfers, 1);
    expect(session.selectedPoint!.latitude, -36.61);
    expect(state.point, isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('La huella muestra el motivo de Android y permite reintentar', (
    t,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var attempts = 0;
    messenger.setMockMethodCallHandler(BiometricAccess.channel, (c) async {
      if (c.method == 'status') {
        return {'available': true, 'saved': attempts == 2};
      }
      if (c.method == 'save' && ++attempts == 1) {
        throw PlatformException(
          code: 'android_7',
          message: 'Demasiados intentos. Espera y vuelve a probar la huella.',
        );
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(BiometricAccess.channel, null),
    );
    final s = Session(RutaApi()..token = 'ficticio')
      ..profile = {'id_usuario': 1};
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HuellaPanel(session: s)),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Activar huella'));
    await t.pumpAndSettle();
    expect(find.textContaining('Demasiados intentos'), findsOneWidget);
    await t.tap(find.text('Activar huella'));
    await t.pumpAndSettle();
    expect(find.text('Desactivar huella'), findsOneWidget);
  });

  testWidgets(
    'Un código incorrecto conserva el alta del autenticador para reintentar',
    (t) async {
      var prepared = 0, attempts = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        BiometricAccess.channel,
        (_) async => {'available': false, 'saved': false},
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(BiometricAccess.channel, null),
      );
      final s = Session(
        RutaApi(
          client: MockClient((req) async {
            Object data = {};
            var status = 200;
            switch (req.url.path) {
              case '/seguridad/estado':
                data = {'mfa_activo': false};
              case '/seguridad/totp/preparar':
                prepared++;
                data = {
                  'secreto': 'SECRETOFICTICIO',
                  'uri': 'otpauth://totp/RutaAlerta?issuer=RutaAlerta',
                };
              case '/seguridad/totp/activar':
                attempts++;
                if (attempts == 1) {
                  status = 400;
                  data = {'detail': 'Código incorrecto o vencido'};
                } else {
                  data = {
                    'codigos_recuperacion': ['RECUPERACION-FICTICIA'],
                  };
                }
            }
            return http.Response.bytes(
              utf8.encode(jsonEncode(data)),
              status,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      await t.pumpWidget(MaterialApp(home: SecurityScreen(session: s)));
      await t.pumpAndSettle();
      await t.tap(find.text('Configurar autenticador'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'clave-ficticia');
      await t.tap(find.text('Continuar'));
      await t.pumpAndSettle();
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '123456');
      await t.tap(find.text('Activar'));
      await t.pumpAndSettle();
      expect(find.text('Código incorrecto o vencido'), findsOneWidget);
      await t.enterText(find.byType(TextField), '654321');
      await t.tap(find.text('Activar'));
      await t.pumpAndSettle();
      expect(prepared, 1);
      expect(find.text('RECUPERACION-FICTICIA'), findsOneWidget);
    },
  );
}
