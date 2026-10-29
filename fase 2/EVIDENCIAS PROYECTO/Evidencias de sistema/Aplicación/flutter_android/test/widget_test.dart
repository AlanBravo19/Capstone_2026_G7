import 'package:flutter_test/flutter_test.dart';
import 'package:rutaalerta_movil/main.dart';
import 'package:rutaalerta_movil/api.dart';
import 'package:rutaalerta_movil/session.dart';

void main() {
  testWidgets('inicio muestra acceso e invitación sin pedir ubicación', (
    tester,
  ) async {
    await tester.pumpWidget(RutaAlertaApp(session: Session(RutaApi())));
    expect(find.text('RutaAlerta'), findsOneWidget);
    expect(find.text('Invitación a la beta'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Iniciar trayecto'), findsNothing);
  });
}
