import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as m;
import 'package:rutaalerta_movil/api.dart';
import 'package:rutaalerta_movil/session.dart';
import 'package:rutaalerta_movil/map_screen.dart';

void main() {
  const channel=MethodChannel('cl.rutaalerta/trayecto');
  TestWidgetsFlutterBinding.ensureInitialized();
  bool permission=true;
  setUp((){permission=true;TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,(call)async=>permission);});
  tearDown(()=>TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel,null));
  Future<dynamic> screen(WidgetTester t)async{
    await t.pumpWidget(MaterialApp(home:Scaffold(body:MapScreen(session:Session(RutaApi()),usePoint:(){}))));
    return t.state(find.byType(MapScreen));
  }
  m.UserLocation fix()=>m.UserLocation(position:const m.LatLng(-36.82,-73.05),altitude:null,bearing:null,speed:null,horizontalAccuracy:12,verticalAccuracy:null,timestamp:DateTime.now(),heading:null);
  testWidgets('denegar permiso no habilita GPS ni fabrica una posición',(t)async{
    permission=false;dynamic s=await screen(t);await s.locate();await t.pump();expect(s.gps,false);expect(s.currentLocation,isNull);await t.pumpWidget(const SizedBox());
  });
  testWidgets('lectura GPS muestra precisión sin elegir incidente',(t)async{
    dynamic s=await screen(t);await s.locate();s.receiveLocation(fix());await t.pump();expect(s.gps,true);expect(s.point,isNull);expect(s.currentLocation.position.latitude,-36.82);expect(s.gpsStatus(),contains('12 m'));await t.pumpWidget(const SizedBox());
  });
  testWidgets('pausar y revocar permiso limpia posición y desactiva GPS',(t)async{
    dynamic s=await screen(t);await s.locate();s.receiveLocation(fix());s.didChangeAppLifecycleState(AppLifecycleState.paused);await t.pump();expect(s.foreground,false);expect(s.currentLocation,isNull);permission=false;await s.checkPermission();await t.pump();expect(s.gps,false);await t.pumpWidget(const SizedBox());
  });
}
