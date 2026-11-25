import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rutaalerta_movil/api.dart';
import 'package:rutaalerta_movil/session.dart';
import 'package:rutaalerta_movil/panorama.dart';
import 'package:rutaalerta_movil/expanded.dart';
import 'package:rutaalerta_movil/zonas_historicas.dart';

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
                  'zonas': [
                    {
                      'latitud': -36.60,
                      'longitud': -72.10,
                      'radio_m': 800,
                      'antecedentes': 4,
                      'encerronas': 1,
                      'nivel': 'alta',
                    },
                    {
                      'latitud': -36.62,
                      'longitud': -72.10,
                      'radio_m': 800,
                      'antecedentes': 2,
                      'encerronas': 1,
                      'nivel': 'moderada',
                    },
                  ],
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
      final circles = t
          .widget<CircleLayer<Object>>(find.byType(CircleLayer<Object>))
          .circles;
      expect(circles.map((c) => c.color.withValues(alpha: 1)).toSet(), {
        zonaModerada,
        zonaAlta,
      });
      expect(find.text('2–3 antecedentes'), findsOneWidget);
      expect(find.text('4 o más antecedentes'), findsOneWidget);
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
    var abrioMapa = false;
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
        home: Scaffold(
          body: CommunityScreen(
            session: session,
            openMap: () => abrioMapa = true,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(
      find.text('Sin solicitudes vigentes para esta búsqueda'),
      findsOneWidget,
    );
    expect(find.textContaining('DEMO01'), findsNothing);
    await t.tap(find.text('Ver mapa de zonas históricas'));
    expect(abrioMapa, isTrue);
  });

  testWidgets('Buscar por texto, enviar con el teclado y limpiar el filtro', (
    t,
  ) async {
    final queries = <String?>[];
    final session = Session(
      RutaApi(
        client: MockClient((request) async {
          queries.add(request.url.queryParameters['zona']);
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
    final field = find.byType(TextField);
    await t.enterText(field, 'concepcion centro');
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(queries, [null, 'concepcion centro']);
    expect(find.text('Resultados para «concepcion centro»'), findsOneWidget);
    await t.enterText(field, 'Sector A');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
    expect(queries, [null, 'concepcion centro', 'Sector A']);
    await t.tap(find.byTooltip('Limpiar búsqueda'));
    await t.pumpAndSettle();
    expect(queries, [null, 'concepcion centro', 'Sector A', null]);
  });
}
