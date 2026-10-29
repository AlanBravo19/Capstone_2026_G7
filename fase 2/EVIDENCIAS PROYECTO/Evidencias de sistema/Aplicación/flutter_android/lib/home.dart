import 'package:flutter/material.dart';

import 'session.dart';
import 'ui.dart';

class HomeScreen extends StatelessWidget {
  final Session session;
  final void Function(int) navigate;
  const HomeScreen({super.key, required this.session, required this.navigate});
  @override
  Widget build(BuildContext context) {
    final name = session.profile?['nombre_visible'] ?? '';
    return RefreshIndicator(
      onRefresh: session.refresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SectionTitle('Hola, $name', eyebrow: 'Tu comunidad, conectada'),
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [navy, Color(0xff166667)]),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: Color(0xff9edac8),
                  size: 40,
                ),
                gap(),
                const Text(
                  'Información que ayuda\na dar el siguiente paso.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                gap(12),
                const Text(
                  'Registra antecedentes y consulta el estado de tus reportes privados.',
                  style: TextStyle(color: Color(0xffc2ded8)),
                ),
                gap(18),
                FilledButton.tonalIcon(
                  onPressed: () => navigate(2),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Nuevo reporte'),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  'Vehículos',
                  session.vehicles.length,
                  Icons.directions_car_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Metric(
                  'Reportes',
                  session.cases.length,
                  Icons.description_outlined,
                ),
              ),
            ],
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, color: teal),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Prepara tu cuenta',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    StateChip(session.canReport ? 'Completado' : 'Pendiente'),
                  ],
                ),
                gap(12),
                Text(
                  session.canReport ? 'Puedes registrar vehículos y reportes.' : 'Completa los pasos de correo y teléfono para participar.',
                  style: const TextStyle(color: muted),
                ),
                gap(12),
                OutlinedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => ContactsDialog(session: session),
                  ),
                  child: const Text('Revisar verificación'),
                ),
              ],
            ),
          ),
          Panel(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.map_outlined, color: teal, size: 32),
              title: const Text(
                'Tu territorio, en contexto',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Ubica un incidente y consulta tus reportes.',
              ),
              trailing: const Icon(Icons.arrow_forward_rounded),
              onTap: () => navigate(3),
            ),
          ),
          const SectionTitle(
            'Últimos reportes',
            eyebrow: 'Seguimiento privado',
          ),
          if (session.cases.isEmpty)
            const Panel(
              child: Text(
                'Todavía no tienes reportes. Cuando registres uno, su estado aparecerá aquí.',
                style: TextStyle(color: muted),
              ),
            ),
          for (final c in session.cases.take(6))
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${c['folio']} · ${c['patente']}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      StateChip(c['estado'] as String),
                    ],
                  ),
                  gap(8),
                  Text('${c['zona']}', style: const TextStyle(color: muted)),
                  const Note(
                    'Reporte privado. Su registro no constituye un encargo policial.',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  const _Metric(this.title, this.count, this.icon);
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: teal),
        gap(8),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: navy,
          ),
        ),
        Text(title, style: const TextStyle(color: muted)),
      ],
    ),
  );
}

class ContactsDialog extends StatefulWidget {
  final Session session;
  const ContactsDialog({super.key, required this.session});
  @override
  State<ContactsDialog> createState() => _ContactsDialogState();
}

class _ContactsDialogState extends State<ContactsDialog> {
  final emailCode = TextEditingController(),
      phone = TextEditingController(),
      phoneCode = TextEditingController();
  String? challenge;
  String message = '';
  bool busy = false;
  @override
  void dispose() {
    emailCode.dispose();
    phone.dispose();
    phoneCode.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() fn) async {
    setState(() => busy = true);
    try {
      await fn();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> emailRequest() async {
    final r = await widget.session.api.request(
      '/identidad/correo/solicitar',
      method: 'POST',
    );
    message = r['mensaje'] as String;
    if (r['token_demo'] != null) emailCode.text = r['token_demo'] as String;
  }

  Future<void> emailConfirm() async {
    await widget.session.api.request(
      '/identidad/correo/confirmar',
      method: 'POST',
      body: {'token': emailCode.text.trim()},
    );
    await widget.session.refresh();
    emailCode.clear();
    message = 'Paso de correo completado.';
  }

  Future<void> phoneRequest() async {
    final r = await widget.session.api.request(
      '/identidad/telefono/solicitar',
      method: 'POST',
      body: {'telefono': phone.text.trim()},
    );
    challenge = r['id_desafio'] as String;
    message = r['mensaje'] as String;
    if (r['codigo_demo'] != null) phoneCode.text = r['codigo_demo'] as String;
  }

  Future<void> phoneConfirm() async {
    if (challenge == null) {
      throw Exception('Solicita primero un código.');
    }
    await widget.session.api.request(
      '/identidad/telefono/confirmar',
      method: 'POST',
      body: {'id_desafio': challenge, 'codigo': phoneCode.text.trim()},
    );
    await widget.session.refresh();
    phoneCode.clear();
    challenge = null;
    message = 'Pasos completados. Ya puedes participar en la beta.';
  }

  @override
  Widget build(BuildContext context) {
    final emailDone = widget.session.identity['correo_verificado'] == true;
    final phoneDone = widget.session.identity['telefono_verificado'] == true;
    final smtp = widget.session.identity['transporte_correo'] == 'smtp';
    return AlertDialog(
      title: const Text('Verificación de contactos'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Note(
                smtp
                    ? 'El código de correo llega a tu buzón. El teléfono aún está en fase de prueba.'
                    : 'En esta beta los códigos se muestran aquí. No se envían correos ni SMS y no acreditan la titularidad de tus contactos. Utiliza datos de prueba.',
              ),
              Text(
                '1. Correo · ${emailDone ? 'completado' : 'pendiente'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (!emailDone) ...[
                gap(10),
                OutlinedButton(
                  onPressed: busy ? null : () => run(emailRequest),
                  child: Text(
                    smtp ? 'Enviar código por correo' : 'Generar código beta',
                  ),
                ),
                TextField(
                  controller: emailCode,
                  decoration: const InputDecoration(
                    labelText: 'Código de correo',
                  ),
                ),
                gap(10),
                FilledButton(
                  onPressed: busy ? null : () => run(emailConfirm),
                  child: const Text('Confirmar paso'),
                ),
              ],
              const Divider(height: 32),
              Text(
                '2. Teléfono · ${phoneDone ? 'completado' : 'pendiente'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (!phoneDone) ...[
                gap(10),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono de prueba',
                    hintText: '+56900000000',
                  ),
                ),
                OutlinedButton(
                  onPressed: busy || !emailDone
                      ? null
                      : () => run(phoneRequest),
                  child: const Text('Generar código beta'),
                ),
                TextField(
                  controller: phoneCode,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Código de seis dígitos',
                  ),
                ),
                gap(10),
                FilledButton(
                  onPressed: busy || challenge == null
                      ? null
                      : () => run(phoneConfirm),
                  child: const Text('Confirmar paso'),
                ),
              ],
              Note(message),
              if (busy) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
