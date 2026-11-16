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
          WelcomeBanner(
            name: name.toString(),
            onCollaborate: () => navigate(4),
          ),
          if (session.storageNotice != null) Note(session.storageNotice!),
          if (!session.canReport)
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user_outlined, color: teal),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          session.identity['correo_verificado'] == true
                              ? 'Paso 2 de 2'
                              : 'Paso 1 de 2',
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
                        : session.avisoAlta ?? 'Confirma tu correo para poder participar. Luego vincularás tu autenticador.',
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
          ActionGroup(
            title: 'Reportar un incidente',
            children: [
              ActionRow(
                icon: Icons.forum_outlined,
                title: 'Presencié un incidente',
                detail: 'Envía un aviso como pasajero o testigo.',
                onTap: () =>
                    openScreen(context, WitnessScreen(session: session)),
              ),
              ActionRow(
                icon: Icons.directions_car_outlined,
                title: 'Reportar el robo de mi vehículo',
                detail: session.vehicles.isEmpty
                    ? 'Registra primero tu vehículo.'
                    : 'Selecciona uno de tus vehículos.',
                onTap: () => navigate(session.vehicles.isEmpty ? 1 : 2),
              ),
            ],
          ),
          ActionGroup(
            title: 'Seguimiento',
            children: [
              ActionRow(
                icon: Icons.mark_email_unread_outlined,
                title: 'Mensajes del caso',
                detail:
                    'Lee las actualizaciones del equipo que revisa tu caso.',
                onTap: () => openScreen(context, InboxScreen(session: session)),
              ),
              ActionRow(
                icon: Icons.fact_check_outlined,
                title: 'Mis avistamientos',
                detail: 'Consulta la revisión de los aportes que enviaste.',
                onTap: () => openScreen(context, mySightings(session)),
              ),
            ],
          ),
          ActionGroup(
            title: 'Mis trayectos',
            children: [
              ActionRow(
                icon: Icons.route_outlined,
                title: 'Planificar una ruta',
                detail: 'Casa, trabajo y lugares guardados',
                onTap: () =>
                    openScreen(context, PlacesRoutesScreen(session: session)),
              ),
              ActionRow(
                icon: Icons.navigation_outlined,
                title: 'Iniciar modo trayecto',
                onTap: () => openScreen(context, TripScreen(session: session)),
              ),
              ActionRow(
                icon: Icons.layers_outlined,
                title: 'Antecedentes de mi zona',
                onTap: () =>
                    openScreen(context, HistoricalNewsScreen(session: session)),
              ),
            ],
          ),
          ActionGroup(
            title: 'Mi garaje',
            children: [
              ActionRow(
                icon: Icons.garage_outlined,
                title: 'Mis vehículos',
                detail: 'Administra los vehículos que has registrado.',
                onTap: () => navigate(1),
              ),
            ],
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

class WelcomeBanner extends StatelessWidget {
  final String name;
  final VoidCallback onCollaborate;
  const WelcomeBanner({
    super.key,
    required this.name,
    required this.onCollaborate,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0xff112d51), Color(0xff205a91)],
      ),
    ),
    child: Stack(
      children: [
        const Positioned(
          right: -16,
          top: 0,
          bottom: 0,
          width: 124,
          child: ExcludeSemantics(child: CustomPaint(painter: _RoutePattern())),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 70, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Colaboración ciudadana',
                style: TextStyle(
                  color: Color(0xffc5e4ff),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                name.isEmpty ? 'Te damos la bienvenida' : 'Hola, $name',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xff164977),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 19),
                label: const Text('Vi un vehículo'),
                onPressed: onCollaborate,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RoutePattern extends CustomPainter {
  const _RoutePattern();
  @override
  void paint(Canvas canvas, Size size) {
    final lines = Paint()
      ..color = const Color(0x294bdcff)
      ..strokeWidth = 1.3;
    for (double x = -size.height; x < size.width; x += 23) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        lines,
      );
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        lines,
      );
    }
    final dot = Offset(size.width * .48, size.height * .52);
    final route = Path()
      ..moveTo(size.width, size.height * .2)
      ..lineTo(size.width * .72, size.height * .2)
      ..lineTo(dot.dx, dot.dy)
      ..lineTo(size.width * .48, size.height);
    canvas.drawPath(
      route,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 3
        ..color = const Color(0xaa8dd8ff),
    );
    canvas.drawCircle(dot, 11, Paint()..color = const Color(0x5076cfff));
    canvas.drawCircle(dot, 5, Paint()..color = const Color(0xffe1f7ff));
  }

  @override
  bool shouldRepaint(_RoutePattern oldDelegate) => false;
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
    message = 'Correo confirmado.';
    if (mounted && widget.session.identity['transporte_correo'] == 'smtp') {
      final session = widget.session;
      final nav = Navigator.of(context);
      nav.pop();
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => SecurityScreen(session: session),
        ),
      );
    }
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
      title: Text(smtp ? 'Confirmar correo' : 'Verificación de contactos'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Note(
                smtp
                    ? 'Escribe el código del correo de RutaAlerta. Si aún no lo tienes, puedes solicitar otro.'
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
                  child: const Text('Confirmar código'),
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
