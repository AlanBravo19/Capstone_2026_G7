import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:rutaalerta_movil/api.dart';
import 'package:rutaalerta_movil/session.dart';

void main() {
  test('envía invitación y sesión sólo a la API HTTPS', () async {
    final api =
        RutaApi(
            client: MockClient((request) async {
              expect(request.url.scheme, 'https');
              expect(request.headers['X-Demo-Access'], 'invitacion-ficticia');
              expect(
                request.headers['Authorization'],
                'Bearer sesion-ficticia',
              );
              return http.Response('{"ok":true}', 200);
            }),
          )
          ..invitation = 'invitacion-ficticia'
          ..token = 'sesion-ficticia';
    expect((await api.request('/mi-perfil'))['ok'], true);
  });

  test('sesión revocada limpia los datos privados', () async {
    final api = RutaApi(
      client: MockClient(
        (_) async => http.Response('{"detail":"Sesión inválida"}', 401),
      ),
    )..token = 'sesion-ficticia';
    final session = Session(api)
      ..profile = {'nombre_visible': 'Ensayo'}
      ..cases = [
        {'folio': 'ENSAYO-1'},
      ]
      ..selectedPoint = const LatLng(-36, -73);
    await expectLater(api.request('/mi-perfil'), throwsA(isA<ApiError>()));
    expect(session.cases, isEmpty);
    expect(session.profile, isNull);
    expect(session.selectedPoint, isNull);
    expect(api.token, isEmpty);
  });

  test('el error del servidor se presenta sin HTML ni trazas', () async {
    final api = RutaApi(
      client: MockClient(
        (_) async => http.Response('<html>Error interno</html>', 500),
      ),
    );
    await expectLater(
      api.request('/mi-perfil'),
      throwsA(
        isA<ApiError>().having(
          (e) => e.message,
          'mensaje',
          isNot(contains('<html>')),
        ),
      ),
    );
  });

  test('un reintento del mismo reporte conserva la idempotencia', () async {
    final keys = <String>[];
    var calls = 0;
    final api = RutaApi(
      client: MockClient((request) async {
        keys.add(request.headers['Idempotency-Key']!);
        calls++;
        if (calls == 1) {
          throw http.ClientException('ensayo de fallo de red');
        }
        return http.Response(jsonEncode({'folio': 'ENSAYO-1'}), 201);
      }),
    );
    final session = Session(api);
    final body = {'id_vehiculo': 1, 'latitud': -36.82, 'longitud': -73.05};
    await expectLater(session.report(body), throwsA(isA<ApiError>()));
    expect(await session.report(body), 'ENSAYO-1');
    expect(keys[0], keys[1]);
  });

  test('el cierre elimina también la invitación aunque falle la red', () async {
    final api =
        RutaApi(
            client: MockClient((_) async {
              throw http.ClientException('sin red');
            }),
          )
          ..token = 'sesion-ficticia'
          ..invitation = 'invitacion-ficticia';
    final session = Session(api)..profile = {'nombre_visible': 'Ensayo'};
    await expectLater(session.logout(), throwsA(isA<ApiError>()));
    expect(api.token, isEmpty);
    expect(api.invitation, isEmpty);
    expect(session.signedIn, false);
  });
}
