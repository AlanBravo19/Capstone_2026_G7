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
import 'expanded.dart';
import 'biometric.dart';

final rootNavigator = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session(RutaApi())
    ..onSessionEnded = () {
      rootNavigator.currentState?.popUntil((route) => route.isFirst);
      unawaited(TripService.stop().catchError((Object _) {}));
    };
  runApp(RutaAlertaApp(session: session));
}

class RutaAlertaApp extends StatelessWidget {
  final Session session;
  const RutaAlertaApp({super.key, required this.session});
  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: rootNavigator,
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

  void accountAction(String value) {
    final session = widget.session;
    if (value == 'security') {
      openScreen(context, SecurityScreen(session: session));
    }
    if (value == 'lock') {
      perform(context, () async {
        final s = await BiometricAccess.status();
        if (s['saved'] != true) {
          throw Exception('Activa primero la biometría en Seguridad.');
        }
        session.lockLocally();
      });
    }
    if (value == 'shared') {
      openScreen(
        context,
        DataScreen(
          session: session,
          title: 'Casos compartidos conmigo',
          path: '/seguimiento/compartidos',
          render: (ctx, data, _) => Column(
            children: [
              if ((data as List).isEmpty)
                const Panel(
                  child: Text('No tienes accesos compartidos vigentes.'),
                ),
              for (final c in data)
                Panel(
                  child: ListTile(
                    title: Text('${c['folio']}'),
                    subtitle: Text('${c['zona']} · ${c['estado']}'),
                    onTap: () => openScreen(
                      ctx,
                      CaseScreen(session: session, cid: c['id_caso'] as int),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    if (value == 'contributions') {
      openScreen(
        context,
        DataScreen(
          session: session,
          title: 'Mis avistamientos',
          path: '/mis-avistamientos',
          render: (_, data, _) => Column(
            children: [
              if ((data as List).isEmpty)
                const Panel(
                  child: Text('Todavía no has enviado avistamientos.'),
                ),
              for (final a in data)
                Panel(
                  child: ListTile(
                    title: Text('${a['zona']}'),
                    subtitle: Text(
                      '${a['estado_revision']} · ${a['motivo_revision'] ?? 'Pendiente de revisión'}',
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
  }

  Widget accountEntry(String key, IconData icon, String name) => ListTile(
    leading: Icon(icon),
    title: Text(name),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => accountAction(key),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: index == 1 || index == 2
          ? BackButton(onPressed: () => navigate(0))
          : null,
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
        IconButton(
          tooltip: 'Notificaciones',
          icon: const Icon(Icons.notifications_none),
          onPressed: () =>
              openScreen(context, InboxScreen(session: widget.session)),
        ),
      ],
    ),
    body: IndexedStack(
      index: index,
      children: [
        HomeScreen(session: widget.session, navigate: navigate),
        VehiclesScreen(session: widget.session),
        ReportScreen(session: widget.session, openMap: () => navigate(3)),
        MapScreen(
          session: widget.session,
          active: index == 3,
          usePoint: () => navigate(2),
        ),
        CommunityScreen(session: widget.session),
        ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SectionTitle(
              widget.session.profile?['nombre_visible'] ?? 'Mi cuenta',
              eyebrow: 'Mi cuenta',
            ),
            Panel(
              child: Column(
                children: [
                  accountEntry(
                    'security',
                    Icons.security,
                    'Seguridad y segundo factor',
                  ),
                  accountEntry(
                    'lock',
                    Icons.fingerprint,
                    'Bloquear con biometría',
                  ),
                  accountEntry(
                    'contributions',
                    Icons.visibility_outlined,
                    'Mis avistamientos',
                  ),
                  accountEntry(
                    'shared',
                    Icons.group_outlined,
                    'Casos compartidos conmigo',
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Cerrar sesión'),
                    onTap: logout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: [0, 4, 3, 5].contains(index)
          ? [0, 4, 3, 5].indexOf(index)
          : 0,
      onDestinationSelected: (tab) => navigate([0, 4, 3, 5][tab]),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Inicio'),
        NavigationDestination(
          icon: Icon(Icons.groups_outlined),
          label: 'Colaborar',
        ),
        NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Mapa'),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Cuenta',
        ),
      ],
    ),
  );
}
