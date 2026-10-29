import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'session.dart';
import 'ui.dart';
import 'login.dart';
import 'home.dart';
import 'vehicles.dart';
import 'report.dart';
import 'map_screen.dart';
import 'trip.dart';
import 'trip_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session(RutaApi())
    ..onSessionEnded = () {
      unawaited(TripService.stop().catchError((Object _) {}));
    };
  runApp(RutaAlertaApp(session: session));
}

class RutaAlertaApp extends StatelessWidget {
  final Session session;
  const RutaAlertaApp({super.key, required this.session});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'RutaAlerta Beta',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    home: ListenableBuilder(
      listenable: session,
      builder: (_, _) => session.signedIn
          ? MobileShell(key: const ValueKey('authenticated'), session: session)
          : LoginScreen(session: session),
    ),
  );
}

class MobileShell extends StatefulWidget {
  final Session session;
  const MobileShell({super.key, required this.session});
  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  int index = 0;
  void navigate(int i) => setState(() => index = i);
  Future<void> logout() async {
    try {
      await TripService.stop();
    } catch (_) {
      /* El canal es exclusivo de Android; la sesión igualmente se revoca. */
    }
    try {
      await widget.session.logout();
    } catch (e) {
      if (mounted) feedback(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(
        children: [
          Icon(Icons.radar_rounded, color: teal),
          SizedBox(width: 8),
          Text(
            'RutaAlerta',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 23),
          ),
        ],
      ),
      actions: [
        const StateChip('Beta'),
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () async {
            try {
              await widget.session.refresh();
            } catch (e) {
              if (context.mounted) feedback(context, e);
            }
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: logout,
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    ),
    body: IndexedStack(
      index: index,
      children: [
        HomeScreen(session: widget.session, navigate: navigate),
        VehiclesScreen(session: widget.session),
        ReportScreen(session: widget.session, openMap: () => navigate(3)),
        MapScreen(session: widget.session, usePoint: () => navigate(2)),
        const TripScreen(),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: navigate,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.grid_view_rounded),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.directions_car_outlined),
          label: 'Vehículos',
        ),
        NavigationDestination(
          icon: Icon(Icons.add_circle_outline_rounded),
          label: 'Reportar',
        ),
        NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Mapa'),
        NavigationDestination(
          icon: Icon(Icons.route_rounded),
          label: 'Trayecto',
        ),
      ],
    ),
  );
}
