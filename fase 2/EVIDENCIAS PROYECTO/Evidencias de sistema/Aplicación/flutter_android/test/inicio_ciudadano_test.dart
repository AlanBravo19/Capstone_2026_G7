import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rutaalerta_movil/api.dart';
import 'package:rutaalerta_movil/main.dart';
import 'package:rutaalerta_movil/session.dart';

void main() {
  testWidgets(
    'Desde Inicio se pueden consultar mensajes y decisiones del operador',
    (tester) async {
      final rutas = <String>[];
      final api = RutaApi(
        client: MockClient((req) async {
          rutas.add(req.url.path);
          return http.Response('[]', 200);
        }),
      );
      final session = Session(api)
        ..profile = {'nombre_visible': 'Colaboradora'};
      await tester.pumpWidget(MaterialApp(home: MobileShell(session: session)));
      for (final paso in {
        'Mensajes del caso': '/notificaciones',
        'Mis avistamientos': '/mis-avistamientos',
      }.entries) {
        final accion = find.text(paso.key);
        await tester.scrollUntilVisible(
          accion.hitTestable(),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(accion);
        await tester.pumpAndSettle();
        expect(rutas, contains(paso.value));
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    },
  );
  testWidgets('una persona sin vehículo puede abrir Colaborar desde Inicio', (
    tester,
  ) async {
    final paths = <String>[];
    final api = RutaApi(
      client: MockClient((req) async {
        paths.add(req.url.path);
        final data = req.url.path == '/colaboracion'
            ? {'cercanos': [], 'otras_zonas': []}
            : [];
        return http.Response(jsonEncode(data), 200);
      }),
    );
    final session = Session(api)
      ..profile = {'nombre_visible': 'Pasajera', 'organizaciones': []};
    await tester.pumpWidget(MaterialApp(home: MobileShell(session: session)));
    await tester.pumpAndSettle();
    expect(paths, isNot(contains('/colaboracion')));
    expect(paths, isNot(contains('/organizaciones')));
    await tester.tap(find.text('Vi un vehículo'));
    await tester.pumpAndSettle();
    expect(find.text('Buscar comuna o sector'), findsOneWidget);
    expect(paths.where((p) => p.startsWith('/gestion/')), isEmpty);
    expect(find.text('Mi vehículo'), findsNothing);
    await tester.tap(find.text('Inicio').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vi un vehículo'));
    await tester.pumpAndSettle();
    expect(paths.where((p) => p == '/colaboracion'), hasLength(1));
  });
}
