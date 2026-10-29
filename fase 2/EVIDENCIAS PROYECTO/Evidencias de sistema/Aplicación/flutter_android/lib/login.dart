import 'package:flutter/material.dart';

import 'session.dart';
import 'ui.dart';

class LoginScreen extends StatefulWidget {
  final Session session;
  const LoginScreen({super.key, required this.session});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController();
  final invitation = TextEditingController(), name = TextEditingController();
  bool register = false, busy = false, obscure = true;
  @override
  void dispose() {
    for (final c in [email, password, invitation, name]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.session.login(
        email.text,
        password.text,
        invitation.text,
        name: register ? name.text : null,
      );
      password.clear();
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: teal,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.radar_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'RutaAlerta',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: navy,
                      ),
                    ),
                    const Spacer(),
                    const StateChip('Beta'),
                  ],
                ),
                gap(32),
                const Text(
                  'Un reporte.\nUn punto de partida\npara colaborar.',
                  style: TextStyle(
                    fontSize: 34,
                    height: 1.12,
                    color: navy,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                  ),
                ),
                gap(12),
                const Text(
                  'Tus vehículos, reportes y ubicaciones en un mismo lugar.',
                  style: TextStyle(color: muted, fontSize: 15),
                ),
                gap(28),
                Panel(
                  child: Form(
                    key: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              label: Text('Ingresar'),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text('Crear cuenta'),
                            ),
                          ],
                          selected: {register},
                          onSelectionChanged: busy
                              ? null
                              : (s) => setState(() => register = s.first),
                        ),
                        gap(22),
                        if (register) ...[
                          TextFormField(
                            controller: name,
                            decoration: const InputDecoration(
                              labelText: 'Nombre visible',
                            ),
                            validator: requiredText,
                          ),
                          gap(),
                        ],
                        TextFormField(
                          controller: invitation,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            labelText: 'Invitación a la beta',
                            prefixIcon: Icon(Icons.key_rounded),
                          ),
                          validator: requiredText,
                        ),
                        gap(),
                        TextFormField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                          ),
                          validator: (v) => v != null && v.contains('@')
                              ? null
                              : 'Ingresa un correo válido',
                        ),
                        gap(),
                        TextFormField(
                          controller: password,
                          obscureText: obscure,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => obscure = !obscure),
                              icon: Icon(
                                obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (v) => v != null && v.length >= 8
                              ? null
                              : 'Utiliza al menos 8 caracteres',
                        ),
                        gap(22),
                        FilledButton(
                          onPressed: busy ? null : submit,
                          child: busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  register
                                      ? 'Crear cuenta e ingresar'
                                      : 'Ingresar',
                                ),
                        ),
                        TextButton(
                          onPressed: busy ? null : recovery,
                          child: const Text('Olvidé mi contraseña'),
                        ),
                      ],
                    ),
                  ),
                ),
                const Note(
                  'Beta cerrada. Los reportes requieren revisión y no reemplazan una denuncia. La verificación de contactos de esta beta sigue identificada como de prueba.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> recovery() async {
    if (invitation.text.trim().isEmpty) {
      feedback(context, 'Primero completa tu invitación a la beta.');
      return;
    }
    widget.session.api.invitation = invitation.text.trim();
    await showDialog<void>(
      context: context,
      builder: (context) => RecoveryDialog(session: widget.session),
    );
  }
}

class RecoveryDialog extends StatefulWidget {
  final Session session;
  const RecoveryDialog({super.key, required this.session});
  @override
  State<RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends State<RecoveryDialog> {
  final email = TextEditingController(),
      code = TextEditingController(),
      password = TextEditingController();
  bool busy = false;
  String message = '';
  @override
  void dispose() {
    email.dispose();
    code.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> action(bool confirm) async {
    if (confirm && (code.text.isEmpty || password.text.length < 8)) {
      feedback(
        context,
        'Ingresa el código y una contraseña de al menos 8 caracteres.',
      );
      return;
    }
    if (!confirm && !email.text.contains('@')) {
      feedback(context, 'Ingresa un correo válido.');
      return;
    }
    setState(() => busy = true);
    try {
      if (!confirm) {
        final r = await widget.session.api.request(
          '/cuentas/recuperacion',
          method: 'POST',
          body: {'correo': email.text.trim()},
        );
        if (!mounted) return;
        setState(() {
          message = r['mensaje'];
          if (r['token_prueba'] != null) {
            code.text = r['token_prueba'];
            message = 'Código beta mostrado aquí. No se envió un correo.';
          }
        });
      } else {
        await widget.session.api.request(
          '/cuentas/recuperacion/confirmar',
          method: 'POST',
          body: {'token': code.text.trim(), 'nueva_clave': password.text},
        );
        if (mounted) {
          feedback(context, 'Contraseña actualizada. Ya puedes ingresar.');
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Recuperar acceso'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo de tu cuenta'),
          ),
          gap(),
          OutlinedButton(
            onPressed: busy ? null : () => action(false),
            child: const Text('Solicitar código'),
          ),
          Note(message),
          TextField(
            controller: code,
            decoration: const InputDecoration(
              labelText: 'Código de recuperación',
            ),
          ),
          gap(),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Nueva contraseña'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
      FilledButton(
        onPressed: busy ? null : () => action(true),
        child: const Text('Actualizar'),
      ),
    ],
  );
}
