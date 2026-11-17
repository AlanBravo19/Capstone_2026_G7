import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rutaalerta_movil/api.dart';
import 'package:rutaalerta_movil/public_vehicle.dart';
import 'package:rutaalerta_movil/vehicle_photo.dart';

void main() {
  test('la foto usa la sesión en cabecera y una ruta propia del servicio', () async {
    final api = RutaApi(client: MockClient((request) async {
      expect(request.url.path, '/colaboracion/45/foto-vehiculo');
      expect(request.url.query, isEmpty);
      expect(request.headers['Authorization'], 'Bearer sesion-de-ensayo');
      return http.Response.bytes([255, 216, 255], 200);
    }))..token = 'sesion-de-ensayo';
    expect(await api.vehiclePhoto(45), [255, 216, 255]);
  });

  testWidgets('sin foto autorizada muestra referencia del tipo sin descargar', (tester) async {
    final api = RutaApi(client: MockClient((_) async => throw StateError('Descarga inesperada')));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: VehiclePhoto(api: api, sid: 4, tipoVehiculo: 'motocicleta'))));
    expect(find.text('Imagen de referencia'), findsOneWidget);
    expect(find.text('Motocicleta'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('una foto revocada vuelve a la referencia', (tester) async {
    final api = RutaApi(client: MockClient((_) async => http.Response('{}', 404)));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: VehiclePhoto(api: api, sid: 4, fotoDisponible: true))));
    await tester.pumpAndSettle();
    expect(find.text('Imagen de referencia'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('un detalle vencido conserva el aviso de actualización', (tester) async {
    final api = RutaApi(client: MockClient((_) async => http.Response('{"detail":"Publicación no disponible"}', 404)));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PublicVehicleHeader(api: api, sid: 4))));
    await tester.pumpAndSettle();
    expect(find.textContaining('ya no está disponible o venció'), findsOneWidget);
  });
}
