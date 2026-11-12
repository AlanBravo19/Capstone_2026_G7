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
import 'expanded.dart';

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
        IconButton(
          tooltip: 'Notificaciones',
          icon: const Icon(Icons.notifications_none),
          onPressed: () =>
              openScreen(context, InboxScreen(session: widget.session)),
        ),
        PopupMenuButton<String>(
          tooltip: 'Más opciones',
          onSelected: (value) {
            final session = widget.session;
            if (value == 'security') {
              openScreen(context, SecurityScreen(session: session));
            }
            if (value == 'history') {
              openScreen(
                context,
                DataScreen(
                  session: session,
                  title: 'Antecedentes territoriales',
                  path: '/territorio/antecedentes',
                  render: (_, r, _) => Column(
                    children: [
                      Note('${r['nota']}'),
                      if ((r['registros'] as List).isEmpty)
                        const Panel(
                          child: Text(
                            'Todavía no hay antecedentes reales autorizados y validados.',
                          ),
                        ),
                      for (final h in r['registros'])
                        Panel(
                          child: ListTile(
                            title: Text('${h['tipo']} · ${h['zona']}'),
                            subtitle: Text(
                              '${h['ocurrido_en']} · Fuentes: ${(h['fuentes'] as List).join(', ')}',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }
            if (value == 'trip') openScreen(context, const TripScreen());
            if (value == 'operator') {
              openScreen(context, OperatorScreen(session: session));
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
                          child: Text(
                            'No tienes accesos compartidos vigentes.',
                          ),
                        ),
                      for (final c in data)
                        Panel(
                          child: ListTile(
                            title: Text('${c['folio']}'),
                            subtitle: Text('${c['zona']} · ${c['estado']}'),
                            onTap: () => openScreen(
                              ctx,
                              CaseScreen(
                                session: session,
                                cid: c['id_caso'] as int,
                              ),
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
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'history',
              child: Text('Antecedentes territoriales'),
            ),
            const PopupMenuItem(
              value: 'security',
              child: Text('Seguridad y segundo factor'),
            ),
            const PopupMenuItem(
              value: 'contributions',
              child: Text('Mis avistamientos'),
            ),
            const PopupMenuItem(
              value: 'shared',
              child: Text('Casos compartidos conmigo'),
            ),
            const PopupMenuItem(value: 'trip', child: Text('Modo trayecto')),
            if ((widget.session.profile?['organizaciones'] as List? ?? [])
                .isNotEmpty)
              const PopupMenuItem(
                value: 'operator',
                child: Text('Gestión institucional'),
              ),
          ],
        ),
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
        MapScreen(
          session: widget.session,
          active: index == 3,
          usePoint: () => navigate(2),
        ),
        CommunityScreen(session: widget.session),
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
          icon: Icon(Icons.groups_outlined),
          label: 'Colaborar',
        ),
      ],
    ),
  );
}
