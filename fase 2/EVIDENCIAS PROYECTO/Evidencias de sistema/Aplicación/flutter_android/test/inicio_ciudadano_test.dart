import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rutaalerta_movil/api.dart';
import 'package:rutaalerta_movil/main.dart';
import 'package:rutaalerta_movil/session.dart';

void main() {
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
