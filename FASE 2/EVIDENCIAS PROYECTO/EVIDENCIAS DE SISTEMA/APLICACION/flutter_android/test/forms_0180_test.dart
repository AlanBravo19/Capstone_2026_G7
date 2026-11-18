import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:rutaalerta_movil/api.dart';
import 'package:rutaalerta_movil/expanded.dart';
import 'package:rutaalerta_movil/commune_picker.dart';
import 'package:rutaalerta_movil/location_picker.dart';
import 'package:rutaalerta_movil/owner_note.dart';
import 'package:rutaalerta_movil/report.dart';
import 'package:rutaalerta_movil/session.dart';
import 'package:rutaalerta_movil/ui.dart';
import 'package:rutaalerta_movil/vehicles.dart';

void main() {
  test(
    'comuna obligatoria y zona normalizada por servidor, sin alterar códigos',
    () async {
      final calls = <http.Request>[];
      final api = RutaApi(
        client: MockClient((r) async {
          calls.add(r);
          expect(r.url.path, '/territorio/validacion');
          final body = jsonDecode(r.body);
          expect(body['codigo_comuna'], '08101');
          expect(body['sector'], 'Centro');
          expect(body['latitud'], -36.827);
          expect(body['longitud'], -73.05);
          return http.Response('{"zona":"Concepcion · Centro"}', 200);
        }),
      );
      await expectLater(
        validatedZone(api, null, 'Centro', const LatLng(-36.827, -73.05)),
        throwsA(isA<ApiError>()),
      );
      expect(calls, isEmpty);
      expect(
        await validatedZone(
          api,
          '08101',
          ' Centro ',
          const LatLng(-36.827, -73.05),
        ),
        'Concepcion · Centro',
      );
    },
  );
  testWidgets('abrir y cancelar mapa no selecciona; tocar y confirmar sí', (
    t,
  ) async {
    LatLng? selected;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationPicker(value: null, onChanged: (p) => selected = p),
        ),
      ),
    );
    await t.tap(find.text('Elegir lugar en el mapa'));
    await t.pumpAndSettle();
    expect(selected, isNull);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(selected, isNull);
    await t.tap(find.text('Elegir lugar en el mapa'));
    await t.pumpAndSettle();
    await t.tapAt(t.getCenter(find.byType(FlutterMap)));
    await t.pump(const Duration(milliseconds: 500));
    expect(selected, isNull);
    await t.tap(find.text('Usar este lugar'));
    await t.pumpAndSettle();
    expect(validLocation(selected), isTrue);
  });

  for (final allowed in [false, true]) {
    testWidgets('picker GPS permiso $allowed sin coordenadas inventadas', (
      t,
    ) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const permission = MethodChannel('cl.rutaalerta/trayecto');
      const gps = MethodChannel('cl.rutaalerta/movilidad');
      messenger.setMockMethodCallHandler(permission, (_) async => allowed);
      messenger.setMockMethodCallHandler(
        gps,
        (_) async => {'lat': -36.61, 'lon': -72.10},
      );
      addTearDown(() {
        messenger.setMockMethodCallHandler(permission, null);
        messenger.setMockMethodCallHandler(gps, null);
      });
      LatLng? selected;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationPicker(value: null, onChanged: (p) => selected = p),
          ),
        ),
      );
      await t.tap(find.text('Usar mi ubicación actual'));
      await t.pumpAndSettle();
      expect(selected?.latitude, allowed ? -36.61 : null);
    });
  }

  testWidgets('reporte requiere lugar sin campos de coordenadas', (t) async {
    final paths = <String>[];
    final session =
        Session(
            RutaApi(
              client: MockClient((r) async {
                paths.add(r.url.path);
                return http.Response(
                  r.url.path == '/catalogo/comunas'
                      ? '[{"codigo_comuna":"16101","nombre":"Chillan"}]'
                      : '[{"id_organizacion":7,"nombre":"Central"}]',
                  200,
                );
              }),
            ),
          )
          ..vehicles = [
            {'id_vehiculo': 1, 'patente': 'BCDF12', 'modelo': 'YARIS'},
          ];
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportScreen(session: session, openMap: () {}),
        ),
      ),
    );
    await t.pumpAndSettle();
    final dynamic state = t.state(find.byType(ReportScreen));
    for (final pair in [(0, 'BCDF12 · YARIS'), (1, 'Central')]) {
      final field = find.byType(DropdownButtonFormField<int>).at(pair.$1);
      await t.ensureVisible(field);
      await t.tap(field);
      await t.pumpAndSettle();
      await t.tap(find.text(pair.$2).last);
      await t.pumpAndSettle();
    }
    final communeField = find.byType(DropdownButtonFormField<String>);
    await t.ensureVisible(communeField);
    await t.tap(communeField);
    await t.pumpAndSettle();
    await t.tap(find.text('Chillan').last);
    await t.pumpAndSettle();
    state.zone.text = 'Ecuador con 18 de Septiembre';
    state.description.text = 'Descripción del incidente para revisión.';
    await state.save();
    await t.pump();
    expect(
      find.text('Selecciona el lugar en el mapa o usa tu ubicación actual.'),
      findsOneWidget,
    );
    expect(find.text('Latitud'), findsNothing);
    expect(find.text('Longitud'), findsNothing);
    expect(paths, ['/organizaciones', '/catalogo/comunas']);
  });

  for (final blocked in [false, true]) {
    testWidgets('quitar vehículo confirma y conserva casos; bloqueo $blocked', (
      t,
    ) async {
      final calls = <http.Request>[];
      final session =
          Session(
              RutaApi(
                client: MockClient((r) async {
                  calls.add(r);
                  if (r.method == 'DELETE') {
                    return http.Response(
                      blocked
                          ? '{"detail":"El vehículo tiene un caso abierto."}'
                          : '',
                      blocked ? 409 : 204,
                    );
                  }
                  return http.Response(
                    '{"catalogo":{},"formatos":{"cuatro_ruedas":"[A-Z]{4}[0-9]{2}"}}',
                    200,
                  );
                }),
              ),
            )
            ..vehicles = [
              {
                'id_vehiculo': 3,
                'patente': 'BCDF12',
                'marca': 'TOYOTA',
                'modelo': 'YARIS',
                'estado_vinculo': 'declarado',
              },
            ]
            ..cases = [
              {'id_caso': 9, 'folio': 'CASO-9'},
            ];
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: session,
              builder: (_, _) => VehiclesScreen(session: session),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Quitar vehículo'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
      expect(calls.where((r) => r.method == 'DELETE'), isEmpty);
      await t.tap(find.byTooltip('Quitar vehículo'));
      await t.pumpAndSettle();
      await t.tap(find.text('Quitar vínculo'));
      await t.pumpAndSettle();
      expect(
        calls.where((r) => r.method == 'DELETE').single.url.path,
        '/vehiculos/3/vinculo',
      );
      expect(session.vehicles.length, blocked ? 1 : 0);
      expect(session.cases.single['folio'], 'CASO-9');
      if (blocked) {
        expect(find.text('El vehículo tiene un caso abierto.'), findsOneWidget);
      }
    });
  }

  for (final withLocation in [false, true]) {
    testWidgets(
      'antecedente privado valida y conserva UUID al reintentar; lugar $withLocation',
      (t) async {
        final bodies = <Map<String, dynamic>>[];
        final session = Session(
          RutaApi(
            client: MockClient((r) async {
              expect(r.url.path, '/mis-casos/9/antecedentes');
              expect(r.method, 'POST');
              bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
              return http.Response('{"detail":"Reintenta"}', 503);
            }),
          ),
        );
        await t.pumpWidget(
          MaterialApp(
            theme: appTheme(),
            home: OwnerNoteScreen(session: session, cid: 9),
          ),
        );
        final dynamic state = t.state(find.byType(OwnerNoteScreen));
        state.description.text = 'Corto';
        await state.save();
        expect(bodies, isEmpty);
        state.description.text = 'Información adicional privada para el caso.';
        if (withLocation) {
          state.location = const LatLng(-36.61, -72.10);
          state.photo = base64Decode('aGVsbG8=');
        }
        await state.save();
        await state.save();
        expect(bodies, hasLength(2));
        expect(bodies[0]['clave_envio'], matches(RegExp(r'^[a-f0-9-]{36}$')));
        expect(bodies[1]['clave_envio'], bodies[0]['clave_envio']);
        expect(bodies[0].containsKey('latitud'), withLocation);
        expect(bodies[0].containsKey('longitud'), withLocation);
        expect(bodies[0].containsKey('foto_base64'), withLocation);
        await t.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('caso propio ofrece seguimiento y oculta Aportar', (t) async {
    final session = Session(
      RutaApi(client: MockClient((r) async => http.Response('{}', 200))),
    );
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: collaborationAction(context, session, {
              'es_mi_caso': true,
              'id_caso': 9,
            }),
          ),
        ),
      ),
    );
    expect(find.text('Aportar avistamiento'), findsNothing);
    expect(find.text('Ir al seguimiento de mi caso'), findsOneWidget);
  });
}
