import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'session.dart';
import 'ui.dart';
import 'login.dart';
import 'home.dart';
import 'vehicles.dart';
import 'report.dart';
import 'panorama.dart';
import 'trip.dart';
import 'expanded.dart';
import 'biometric.dart';
import 'huella.dart';
import 'testigos.dart';

final rootNavigator = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session(RutaApi())
    ..onSessionEnded = () {
      rootNavigator.currentState?.popUntil((route) => route.isFirst);
      unawaited(TripService.stop().catchError((Object _) {}));
    };
  unawaited(session.restore());
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
      builder: (_, _) => session.restoring || session.restoreError != null
          ? Scaffold(
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: session.restoring
                        ? const CircularProgressIndicator()
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(session.restoreError ?? ''),
                              FilledButton(
                                onPressed: session.restore,
                                child: const Text('Reintentar'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  try {
                                    await session.logout();
                                  } on ApiError {
                                    // El cierre local se completa aunque no haya conexión.
                                  }
                                },
                                child: const Text(
                                  'Cerrar sesión en este teléfono',
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            )
          : session.signedIn
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
  @override
  void initState() {
    super.initState();
    checkRegistration();
  }

  @override
  void didUpdateWidget(covariant MobileShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    checkRegistration();
  }

  void checkRegistration() {
    final session = widget.session;
    if (!session.showEmailStep) return;
    session.showEmailStep = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          session.signedIn &&
          session.identity['correo_verificado'] != true) {
        showDialog<void>(
          context: context,
          builder: (_) => ContactsDialog(session: session),
        );
      }
    });
  }

  int index = 0;
  final visited = <int>{0};
  void navigate(int i, {bool seleccionarPunto = false}) {
    if (i == index) return;
    setState(() {
      visited.add(i);
      index = i;
    });
  }

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
          if (mounted) {
            openScreen(
              context,
              Scaffold(
                appBar: AppBar(title: const Text('Huella')),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [HuellaPanel(session: session)],
                ),
              ),
            );
          }
          return;
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
      openScreen(context, mySightings(session));
    }
  }

  Widget accountEntry(String key, IconData icon, String name) =>
      ActionRow(icon: icon, title: name, onTap: () => accountAction(key));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: index == 1 || index == 2
          ? BackButton(onPressed: () => navigate(0))
          : null,
      title: const Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: blueHighlight,
              borderRadius: BorderRadius.all(Radius.circular(11)),
            ),
            child: Padding(
              padding: EdgeInsets.all(7),
              child: Icon(Icons.radar_rounded, color: teal, size: 20),
            ),
          ),
          SizedBox(width: 10),
          Text(
            'RutaAlerta',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 21,
              letterSpacing: -.6,
            ),
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
        HomeScreen(
          session: widget.session,
          navigate: navigate,
          active: index == 0,
        ),
        if (visited.contains(1))
          VehiclesScreen(session: widget.session)
        else
          const SizedBox.shrink(),
        if (visited.contains(2))
          ReportScreen(
            session: widget.session,
            openMap: () => navigate(3, seleccionarPunto: true),
          )
        else
          const SizedBox.shrink(),
        if (index == 3)
          ListView(
            padding: const EdgeInsets.all(16),
            children: [PanoramaZonal(session: widget.session)],
          )
        else
          const SizedBox.shrink(),
        if (visited.contains(4))
          CommunityScreen(
            session: widget.session,
            active: index == 4,
            openMap: () => navigate(3),
          )
        else
          const SizedBox.shrink(),
        ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Panel(
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: blueHighlight,
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: teal,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.session.profile?['nombre_visible'] ??
                              'Mi cuenta',
                          style: const TextStyle(
                            color: ink,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.session.profile?['modalidad_ciudadana'] ==
                                  'con_vehiculo'
                              ? 'Con vehículo y colaborador'
                              : 'Colaborador',
                          style: const TextStyle(color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ActionGroup(
              title: 'Participación',
              children: [
                ActionRow(
                  icon: Icons.record_voice_over_outlined,
                  title: 'Mis avisos de testigo',
                  onTap: () =>
                      openScreen(context, witnessHistory(widget.session)),
                ),
                ActionRow(
                  icon: Icons.person_outline,
                  title: 'Cómo participo',
                  onTap: () => perform(context, () async {
                    final choice = await showDialog<String>(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        title: const Text('Cómo participo'),
                        children: [
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(ctx, 'colaborador'),
                            child: const Text(
                              'Colaborar sin registrar vehículo',
                            ),
                          ),
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(ctx, 'con_vehiculo'),
                            child: const Text(
                              'Registrar mi vehículo y colaborar',
                            ),
                          ),
                        ],
                      ),
                    );
                    if (choice == null) return;
                    await widget.session.api.request(
                      '/mi-perfil/modalidad',
                      method: 'PUT',
                      body: {'modalidad_ciudadana': choice},
                    );
                    await widget.session.refresh();
                  }),
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
              ],
            ),
            ActionGroup(
              title: 'Seguridad',
              children: [
                accountEntry(
                  'security',
                  Icons.shield_outlined,
                  'Seguridad y segundo factor',
                ),
                accountEntry(
                  'lock',
                  Icons.fingerprint,
                  'Bloquear con biometría',
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: logout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ],
    ),
    bottomNavigationBar: GlassDock(
      child: NavigationBar(
        selectedIndex: [0, 4, 3, 5].contains(index)
            ? [0, 4, 3, 5].indexOf(index)
            : 0,
        onDestinationSelected: (tab) => navigate([0, 4, 3, 5][tab]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: 'Colaborar',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Cuenta',
          ),
        ],
      ),
    ),
  );
}
