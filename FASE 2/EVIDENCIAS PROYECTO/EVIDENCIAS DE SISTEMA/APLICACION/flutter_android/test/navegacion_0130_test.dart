import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rutaalerta_movil/api.dart';
import 'package:rutaalerta_movil/expanded.dart';
import 'package:rutaalerta_movil/movilidad.dart';
import 'package:rutaalerta_movil/session.dart';
import 'package:rutaalerta_movil/trip_screen.dart';
import 'package:rutaalerta_movil/ui.dart';

void main() {
  testWidgets('El trayecto se abre con barra propia y vuelve al origen', (
    t,
  ) async {
    const channel = MethodChannel('cl.rutaalerta/trayecto');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {'running': false},
    );
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await t.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => openScreen(ctx, const TripScreen()),
              child: const Text('Abrir trayecto'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Abrir trayecto'));
    await t.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Iniciar trayecto'), findsOneWidget);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(find.text('Abrir trayecto'), findsOneWidget);
  });

  testWidgets(
    'El planificador muestra origen y destino primero en un teléfono estrecho',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(320, 600);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final session = Session(
        RutaApi(client: MockClient((_) async => http.Response('[]', 200))),
      );
      await t.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: PlacesRoutesScreen(session: session),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Guardar mi primer destino'), findsOneWidget);
      expect(find.text('Origen guardado').hitTestable(), findsOneWidget);
      await t.scrollUntilVisible(find.text('Lugares guardados'), 170);
      await t.pumpAndSettle();
      expect(find.text('Lugares guardados').hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
