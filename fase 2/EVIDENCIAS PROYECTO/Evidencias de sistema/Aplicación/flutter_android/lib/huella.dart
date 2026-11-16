import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'biometric.dart';
import 'session.dart';
import 'ui.dart';

class HuellaPanel extends StatefulWidget {
  final Session session;
  const HuellaPanel({super.key, required this.session});
  @override
  State<HuellaPanel> createState() => _HuellaPanelState();
}

class _HuellaPanelState extends State<HuellaPanel> with WidgetsBindingObserver {
  Map<String, dynamic>? status;
  bool busy = false;
  String? problem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) refresh();
  }

  Future<void> refresh() async {
    try {
      final s = await BiometricAccess.status().timeout(const Duration(seconds:5));
      if (mounted) setState(() => status = s);
    } catch (_) {
      if (mounted) {
        setState(
          () => status = {
            'available': false,
            'reason': 'No se pudo consultar el sensor de este dispositivo.',
          },
        );
      }
    }
  }

  Future<void> change(bool remove) async {
    if (busy) return;
    setState(() {
      busy = true;
      problem = null;
    });
    try {
      if (remove) {
        await BiometricAccess.clear();
      } else {
        await widget.session.enableBiometric();
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(
          () => problem =
              e.message ?? 'Android no completó la operación (${e.code}).',
        );
      }
    } catch (e) {
      if (mounted) setState(() => problem = e.toString());
    } finally {
      if (mounted) {
        await refresh();
        if (mounted) setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = status?['saved'] == true;
    final available = status?['available'] == true;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Huella en este teléfono',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Note(
            enabled
                ? 'Acceso rápido activado. Usa Bloquear con biometría en Cuenta para probarlo. Cerrar sesión elimina el acceso guardado.'
                : 'Opcional. Guarda tu sesión en este teléfono para volver con la huella. Cuando venza, ingresa con tu contraseña.',
          ),
          if (status == null) const Note('Consultando el sensor…'),
          if (status != null && !available) ...[
            Text(
              status?['reason'] as String? ?? 'El sensor no está disponible. Puedes ingresar con contraseña.',
            ),
            TextButton(
              onPressed: () => BiometricAccess.channel
                  .invokeMethod<void>('settings')
                  .catchError((Object e) {
                    if (context.mounted) feedback(context, e);
                  }),
              child: const Text('Abrir ajustes de seguridad'),
            ),
          ],
          if (problem != null)
            Semantics(
              liveRegion: true,
              child: Text(
                problem!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (enabled || available)
            OutlinedButton.icon(
              onPressed: busy ? null : () => change(enabled),
              icon: const Icon(Icons.fingerprint),
              label: Text(
                busy
                    ? 'Esperando a Android…'
                    : enabled
                    ? 'Desactivar huella'
                    : 'Activar huella',
              ),
            ),
        ],
      ),
    );
  }
}
