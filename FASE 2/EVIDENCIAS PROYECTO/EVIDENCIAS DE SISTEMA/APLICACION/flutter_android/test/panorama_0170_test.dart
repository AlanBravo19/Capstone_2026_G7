import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rutaalerta_movil/api.dart';
import 'package:rutaalerta_movil/session.dart';
import 'package:rutaalerta_movil/panorama.dart';
import 'package:rutaalerta_movil/expanded.dart';

void main() {
  testWidgets(
    'La alerta de aproximación es local y el historial mantiene la fuente',
    (t) async {
      final metodos = <String>[];
      final session = Session(
        RutaApi(
          client: MockClient((r) async {
            metodos.add(r.method);
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'solicitudes': [],
                  'antecedentes': [
                    {
                      'latitud': -36.60,
                      'longitud': -72.10,
                      'radio_m': 300,
                      'titulo': 'Antecedente para prueba',
                      'zona': 'Sector de ensayo',
                      'nombre_fuente': 'Fuente de ensayo',
                      'fecha_publicacion': '2026-11-01',
                      'resumen': 'Antecedente revisado.',
                      'url_fuente': 'https://example.invalid/archivo',
                    },
                  ],
                }),
              ),
              200,
            );
          }),
        ),
      );
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(children: [PanoramaZonal(session: session)]),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Simular alerta de proximidad'));
      await t.pump(const Duration(seconds: 4));
      expect(find.textContaining('Dentro del radio de aviso'), findsOneWidget);
      await t.tap(find.text('Terminar simulación'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Antecedente para prueba'));
      await t.tap(find.text('Antecedente para prueba'));
      await t.pumpAndSettle();
      expect(find.textContaining('Fuente de ensayo'), findsOneWidget);
      expect(metodos, ['GET']);
    },
  );
  testWidgets('Un aporte de práctica no escribe en casos públicos', (t) async {
    final session = Session(
      RutaApi(
        client: MockClient((_) async => throw StateError('Envío inesperado')),
      ),
    );
    await t.pumpWidget(
      MaterialApp(home: SightingScreen(session: session, sid: null)),
    );
    await t.pumpAndSettle();
    await t.enterText(
      find.widgetWithText(
        TextField,
        'Describe lo observado (mínimo 10 caracteres)',
      ),
      'Observación del vehículo de ensayo',
    );
    await t.scrollUntilVisible(
      find.text('Completar ensayo').hitTestable(),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.text('Completar ensayo'));
    await t.pumpAndSettle();
    expect(find.text('Ensayo completado'), findsOneWidget);
  });
}
