import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rutaalerta_movil/api.dart';
import 'package:rutaalerta_movil/session.dart';

void main() {
  test(
    'cliente Flutter registra cuenta, vehículo y reporte en Vercel/Supabase',
    () async {
      final invitation = Platform.environment['RUTA_INVITACION'];
      expect(invitation, isNotEmpty);
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      final api = RutaApi();
      final session = Session(api);
      await session.login(
        'flutter-$stamp@example.invalid',
        'Ensayo-flutter-$stamp!',
        invitation!,
        name: 'Ensayo Flutter ficticio',
      );
      expect(session.signedIn, true);
      expect(session.canReport, false);
      final mail = await api.request(
        '/identidad/correo/solicitar',
        method: 'POST',
      );
      expect(
        mail['canal'],
        'prueba',
        reason: 'Esta prueba no envía correos ni usa contactos reales',
      );
      await api.request(
        '/identidad/correo/confirmar',
        method: 'POST',
        body: {'token': mail['token_demo']},
      );
      final sms = await api.request(
        '/identidad/telefono/solicitar',
        method: 'POST',
        body: {'telefono': '+569${stamp.substring(stamp.length - 8)}'},
      );
      await api.request(
        '/identidad/telefono/confirmar',
        method: 'POST',
        body: {'id_desafio': sms['id_desafio'], 'codigo': sms['codigo_demo']},
      );
      await session.refresh();
      expect(session.canReport, true);
      final plate = 'FL${stamp.substring(stamp.length - 8)}';
      final vehicle = await api.request(
        '/vehiculos',
        method: 'POST',
        body: {
          'marca': 'MARCA FICTICIA',
          'modelo': 'ENSAYO FLUTTER',
          'patente': plate,
          'color': 'Gris',
          'anio': 2020,
        },
      );
      await session.refresh();
      expect(session.vehicles.any((v) => v['patente'] == plate), true);
      final folio = await session.report({
        'id_vehiculo': vehicle['id_vehiculo'],
        'id_organizacion': 1,
        'fecha_hecho': DateTime.now().toUtc().toIso8601String(),
        'zona': 'Sector ficticio de prueba Flutter',
        'descripcion': 'Comprobación técnica de datos ficticios. No corresponde a un robo.',
        'latitud': -36.82,
        'longitud': -73.05,
      });
      await session.refresh();
      final saved = session.cases.singleWhere((c) => c['folio'] == folio);
      expect(saved['latitud'], closeTo(-36.82, .000001));
      expect(saved['longitud'], closeTo(-73.05, .000001));
      final bearer = api.token;
      await session.logout();
      expect(session.signedIn, false);
      api.token = bearer;
      api.invitation = invitation;
      await expectLater(
        api.request('/mi-perfil'),
        throwsA(isA<ApiError>().having((e) => e.status, 'estado', 401)),
      );
      api.client.close();
    },
    skip: Platform.environment['RUTA_EJECUTAR_REMOTO'] != '1',
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
