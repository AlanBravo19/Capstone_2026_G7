import 'package:flutter/material.dart';

import 'session.dart';
import 'ui.dart';
import 'biometric.dart';

class LoginScreen extends StatefulWidget {
  final Session session;
  const LoginScreen({super.key, required this.session});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController();
  final name = TextEditingController(), factor = TextEditingController();
  String modalidad = 'colaborador';
  bool register = false, busy = false, obscure = true;
  bool savedBiometric = false;
  @override
  void initState() {
    super.initState();
    BiometricAccess.status()
        .then((s) {
          if (mounted) {
            setState(
              () =>
                  savedBiometric = s['available'] == true && s['saved'] == true,
            );
          }
        })
        .catchError((Object _) {});
  }

  Future<void> biometricLogin() async {
    setState(() => busy = true);
    try {
      await widget.session.loginBiometric();
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in [email, password, name, factor]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (widget.session.mfaChallenge == null && !form.currentState!.validate()) {
      return;
    }
    setState(() => busy = true);
    try {
      if (widget.session.mfaChallenge != null) {
        await widget.session.confirmMfa(factor.text);
        factor.clear();
      } else {
        await widget.session.login(
          email.text,
          password.text,
          name: register ? name.text : null,
          modalidad: modalidad,
        );
        password.clear();
      }
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
                        color: paper,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'RutaAlerta',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: ink,
                      ),
                    ),
                  ],
                ),
                gap(32),
                const Text(
                  'Bienvenido a RutaAlerta',
                  style: TextStyle(
                    fontSize: 34,
                    height: 1.12,
                    color: ink,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                  ),
                ),
                gap(12),
                const Text(
                  'Consulta avisos de tu zona o informa un avistamiento, con o sin vehículo.',
                  style: TextStyle(color: muted, fontSize: 15),
                ),
                gap(28),
                Panel(
                  child: Form(
                    key: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.session.mfaChallenge == null) ...[
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
                            DropdownButtonFormField<String>(
                              initialValue: modalidad,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: '¿Cómo vas a participar?',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'colaborador',
                                  child: Text(
                                    'Colaborar sin registrar vehículo',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'con_vehiculo',
                                  child: Text(
                                    'Registrar mi vehículo y colaborar',
                                  ),
                                ),
                              ],
                              onChanged: busy
                                  ? null
                                  : (v) => setState(() => modalidad = v!),
                            ),
                            gap(),
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
                        ] else ...[
                          const Text(
                            'Verifica tu ingreso',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Note(
                            'Abre tu autenticador y escribe el código actual de RutaAlerta. También puedes usar uno de tus códigos de recuperación.',
                          ),
                          TextFormField(
                            controller: factor,
                            decoration: const InputDecoration(
                              labelText:
                                  'Código del autenticador o de recuperación',
                            ),
                            validator: requiredText,
                          ),
                          CheckboxListTile(
                            value: widget.session.rememberPhone,
                            title: const Text('Recordar este teléfono'),
                            subtitle: const Text(
                              'Hasta 30 días en tu cuenta ciudadana.',
                            ),
                            onChanged: busy
                                ? null
                                : (value) => setState(
                                    () => widget.session.rememberPhone =
                                        value == true,
                                  ),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => setState(
                                    () => widget.session.mfaChallenge = null,
                                  ),
                            child: const Text('Volver al ingreso'),
                          ),
                        ],
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
                                  widget.session.mfaChallenge != null
                                      ? 'Verificar segundo factor'
                                      : register
                                      ? 'Crear cuenta e ingresar'
                                      : 'Ingresar',
                                ),
                        ),
                        if (savedBiometric &&
                            !register &&
                            widget.session.mfaChallenge == null)
                          OutlinedButton.icon(
                            onPressed: busy ? null : biometricLogin,
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Ingresar con biometría'),
                          ),
                        if (widget.session.mfaChallenge == null)
                          TextButton(
                            onPressed: busy ? null : recovery,
                            child: const Text('Olvidé mi contraseña'),
                          ),
                      ],
                    ),
                  ),
                ),
                const Note(
                  'Verifica tu correo y configura el autenticador para participar. Los reportes requieren revisión y no reemplazan una denuncia.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> recovery() async {
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
