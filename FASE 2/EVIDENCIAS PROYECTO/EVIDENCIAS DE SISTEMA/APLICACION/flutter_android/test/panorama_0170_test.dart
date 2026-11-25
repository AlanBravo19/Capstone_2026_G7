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
    'El mapa mantiene la fuente histórica y excluye el control de simulación',
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
      expect(find.text('Simular alerta de proximidad'), findsNothing);
      final source = find.text('Antecedente para prueba');
      await t.ensureVisible(source);
      await t.pumpAndSettle();
      await t.tap(source);
      await t.pumpAndSettle();
      expect(find.textContaining('Fuente de ensayo'), findsOneWidget);
      expect(metodos, ['GET']);
    },
  );
  testWidgets('La lista vacía no ofrece un vehículo ficticio', (t) async {
    final session = Session(
      RutaApi(
        client: MockClient((r) async {
          expect(r.method, 'GET');
          return http.Response('{"cercanos":[],"otras_zonas":[]}', 200);
        }),
      ),
    );
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CommunityScreen(session: session)),
      ),
    );
    await t.pumpAndSettle();
    expect(
      find.text('Sin solicitudes vigentes para esta búsqueda'),
      findsOneWidget,
    );
    expect(find.textContaining('DEMO01'), findsNothing);
  });
}
