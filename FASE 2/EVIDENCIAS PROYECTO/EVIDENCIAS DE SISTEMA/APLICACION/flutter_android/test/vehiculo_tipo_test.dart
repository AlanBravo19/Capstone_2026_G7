import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:rutaalerta_movil/api.dart';
import 'package:rutaalerta_movil/session.dart';
import 'package:rutaalerta_movil/vehicles.dart';

void main() {
  testWidgets('la moto ofrece sus modelos y rechaza la patente de automóvil', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <String>[];
    final session = Session(
      RutaApi(
        client: MockClient((r) async {
          calls.add(r.method);
          return http.Response(
            jsonEncode({
              'catalogo': {
                'motocicleta': {
                  'HONDA': ['125CC'],
                },
                'automovil': {
                  'TOYOTA': ['YARIS'],
                },
              },
              'formatos': {
                'motocicleta': r'[A-Z]{3}[0-9]{2}',
                'cuatro_ruedas': r'[A-Z]{4}[0-9]{2}',
              },
            }),
            200,
          );
        }),
      ),
    )..identity = {'puede_participar': true};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VehiclesScreen(session: session)),
      ),
    );
    await tester.pumpAndSettle();
    for (final (index, option) in [
      (0, 'Motocicleta'),
      (1, 'HONDA'),
      (2, '125CC'),
      (3, 'Negro'),
    ]) {
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(index));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byType(TextFormField).at(0), 'BCDF12');
    await tester.enterText(find.byType(TextFormField).at(1), '2020');
    await tester.tap(find.text('Guardar vehículo'));
    await tester.pumpAndSettle();
    expect(
      find.text('Revisa el formato de la patente para este tipo.'),
      findsOneWidget,
    );
    expect(calls, ['GET']);
  });
}
