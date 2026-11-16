import 'package:flutter/material.dart';

import 'session.dart';
import 'ui.dart';
import 'expanded.dart';
import 'movilidad.dart';
import 'trip_screen.dart';
import 'testigos.dart';

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
          SectionTitle('Hola, $name', eyebrow: 'Inicio'),
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [navy, Color(0xff244e8c)]),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: Color(0xffb6d0ff),
                  size: 40,
                ),
                gap(),
                const Text(
                  '¿Viste un vehículo reportado?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                gap(12),
                const Text(
                  'Consulta solicitudes de tu zona y envía un avistamiento, aunque no tengas vehículo.',
                  style: TextStyle(color: Color(0xffccdfff)),
                ),
                gap(18),
                FilledButton.tonalIcon(
                  onPressed: () => navigate(4),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Vi un vehículo'),
                ),
              ],
            ),
          ),
          if (!session.canReport)
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
                    session.canReport
                        ? 'Puedes registrar vehículos y reportes.'
                        : session.identity['correo_verificado'] == true
                        ? 'Tu correo ya está confirmado. Activa el segundo factor para poder participar.'
                        : session.avisoAlta ?? 'Verifica tu correo y configura el autenticador para participar.',
                    style: const TextStyle(color: muted),
                  ),
                  gap(12),
                  OutlinedButton(
                    onPressed:
                        session.identity['correo_verificado'] == true &&
                            session.identity['transporte_correo'] == 'smtp'
                        ? () => openScreen(
                            context,
                            SecurityScreen(session: session),
                          )
                        : () => showDialog<void>(
                            context: context,
                            builder: (_) => ContactsDialog(session: session),
                          ),
                    child: Text(
                      session.identity['correo_verificado'] == true &&
                              session.identity['transporte_correo'] == 'smtp'
                          ? 'Configurar autenticador'
                          : 'Verificar mi correo',
                    ),
                  ),
                ],
              ),
            ),
          Panel(
            child: ListTile(
              leading: const Icon(Icons.record_voice_over_outlined),
              title: const Text('Presencié un incidente'),
              subtitle: const Text('Iba como pasajero o lo vi desde fuera.'),
              onTap: () => openScreen(context, WitnessScreen(session: session)),
            ),
          ),
          const SectionTitle('Mis trayectos'),
          Panel(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.alt_route),
                  title: const Text('Planificar una ruta'),
                  subtitle: const Text('Casa, trabajo y lugares guardados'),
                  onTap: () =>
                      openScreen(context, PlacesRoutesScreen(session: session)),
                ),
                ListTile(
                  leading: const Icon(Icons.navigation_outlined),
                  title: const Text('Iniciar modo trayecto'),
                  onTap: () =>
                      openScreen(context, TripScreen(session: session)),
                ),
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: const Text('Antecedentes de mi zona'),
                  onTap: () => openScreen(
                    context,
                    HistoricalNewsScreen(session: session),
                  ),
                ),
              ],
            ),
          ),
          SectionTitle(
            session.profile?['modalidad_ciudadana'] == 'con_vehiculo'
                ? 'Mis vehículos y reportes'
                : 'Si también tienes vehículo',
          ),
          Panel(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.directions_car_outlined),
                  title: const Text('Mis vehículos'),
                  subtitle: const Text('Opcional para colaborar'),
                  onTap: () => navigate(1),
                ),
                ListTile(
                  leading: const Icon(Icons.add_location_alt_outlined),
                  title: const Text('Reportar el robo de mi vehículo'),
                  onTap: () => navigate(session.vehicles.isEmpty ? 1 : 2),
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
                  OutlinedButton.icon(
                    onPressed: () => openScreen(
                      context,
                      CaseScreen(session: session, cid: c['id_caso'] as int),
                    ),
                    icon: const Icon(Icons.timeline),
                    label: const Text('Abrir seguimiento'),
                  ),
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
                    ? 'El código de correo llega a tu buzón. Para participar, activa después el autenticador en Seguridad. No necesitas pagar SMS.'
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
              if (!smtp)
                Text(
                  '2. Teléfono · ${phoneDone ? 'completado' : 'pendiente'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              if (!phoneDone && !smtp) ...[
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
              if (smtp)
                Note(
                  widget.session.identity['mfa_activo'] == true
                      ? 'Autenticador activo.'
                      : 'Después de confirmar el correo, abre Seguridad y segundo factor para activar tu autenticador.',
                ),
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
