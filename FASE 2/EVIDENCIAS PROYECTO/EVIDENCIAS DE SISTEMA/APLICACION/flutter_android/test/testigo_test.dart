import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rutaalerta_movil/api.dart';
import 'package:rutaalerta_movil/session.dart';
import 'package:rutaalerta_movil/testigos.dart';

void main() {
  testWidgets(
    'pasajero sin auto envía aviso sin patente y recibe comprobante',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <String>[];
      final s = Session(
        RutaApi(
          client: MockClient((r) async {
            calls.add(r.url.path);
            if (r.url.path == '/organizaciones') {
              return http.Response(
                '[{"id_organizacion":7,"nombre":"Central de ensayo"}]',
                200,
              );
            }
            final body = jsonDecode(r.body);
            expect(body['perspectiva'], 'pasajero');
            expect(body['patente_observada'], isNull);
            expect(body['id_organizacion'], 7);
            expect(body.containsKey('id_vehiculo'), false);
            expect(r.headers['Idempotency-Key'], isNotEmpty);
            return http.Response('{"id_aviso":"comprobante-de-prueba"}', 201);
          }),
        ),
      )..identity = {'puede_participar': true};
      await tester.pumpWidget(MaterialApp(home: WitnessScreen(session: s)));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Central de ensayo').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Sector ficticio',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Lo observé desde el vehículo.',
      );
      await tester.tap(find.text('Enviar aviso privado'));
      await tester.pumpAndSettle();
      expect(find.text('Aviso recibido'), findsOneWidget);
      expect(calls, ['/organizaciones', '/avisos-testigo']);
    },
  );
}
