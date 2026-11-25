import 'foto_aporte.dart';

import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'session.dart';
import 'huella.dart';

import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import 'movilidad.dart' show Mobility;
import 'ui.dart';
import 'location_picker.dart';
import 'commune_picker.dart';
import 'owner_note.dart';
import 'public_vehicle.dart';
import 'case_photos.dart';

import 'package:latlong2/latlong.dart';

// Formularios acotados: los permisos y reglas se vuelven a comprobar en el servidor.
Future<Map<String, String>?> ask(
  BuildContext context,
  String title,
  Map<String, String> labels, {
  Map<String, String> values = const {},
  Set<String> secrets = const {},
}) async {
  final controls = {
    for (final k in labels.keys)
      k: TextEditingController(text: values[k] ?? ''),
  };
  final result = await showDialog<Map<String, String>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final k in labels.keys)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextField(
                  controller: controls[k],
                  obscureText: secrets.contains(k),
                  maxLines: secrets.contains(k) ? 1 : null,
                  decoration: InputDecoration(labelText: labels[k]),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, {
            for (final k in labels.keys) k: controls[k]!.text.trim(),
          }),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
  // Esperar al cierre de la animación antes de liberar controles del diálogo.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  for (final c in controls.values) {
    c.dispose();
  }
  return result;
}

class DataScreen extends StatefulWidget {
  final Session session;
  final String title, path;
  final Widget Function(BuildContext, dynamic, VoidCallback) render;
  final int revision;
  const DataScreen({
    super.key,
    required this.session,
    required this.title,
    required this.path,
    required this.render,
    this.revision = 0,
  });
  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    setState(() {
      future = widget.session.api.request(widget.path);
    });
  }

  @override
  void didUpdateWidget(covariant DataScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision ||
        oldWidget.path != widget.path) {
      future = widget.session.api.request(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))],
    ),
    body: FutureBuilder(
      future: future,
      builder: (ctx, s) {
        if (s.connectionState != ConnectionState.done && !s.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${s.error}'),
                  gap(),
                  OutlinedButton(
                    onPressed: reload,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            reload();
            await future;
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [widget.render(context, s.data, reload)],
          ),
        );
      },
    ),
  );
}

Future<void> perform(BuildContext context, Future<void> Function() fn) async {
  try {
    await fn();
  } catch (e) {
    if (context.mounted) feedback(context, e);
  }
}

void openScreen(BuildContext context, Widget screen) =>
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

class SecurityScreen extends StatelessWidget {
  final Session session;
  const SecurityScreen({super.key, required this.session});
  @override
  Widget build(BuildContext context) => DataScreen(
    session: session,
    title: 'Seguridad de tu cuenta',
    path: '/seguridad/estado',
    render: (ctx, data, reload) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data['mfa_activo'] == true) HuellaPanel(session: session),
        const SectionTitle('Código de seguridad', eyebrow: 'Segundo factor'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StateChip(
                data['mfa_activo'] == true
                    ? 'Segundo factor activo'
                    : 'Segundo factor pendiente',
              ),
              const Note(
                'Vincula una aplicación autenticadora. Después de tu contraseña, RutaAlerta te pedirá el código de seis dígitos que aparece en esa aplicación.',
              ),
              if (data['mfa_activo'] != true)
                FilledButton.icon(
                  icon: const Icon(Icons.phonelink_lock),
                  label: const Text('Configurar autenticador'),
                  onPressed: () => perform(ctx, () async {
                    final pwd = await ask(
                      ctx,
                      'Confirma tu contraseña',
                      {'clave': 'Contraseña actual'},
                      secrets: {'clave'},
                    );
                    if (pwd == null) return;
                    final setup = await session.api.request(
                      '/seguridad/totp/preparar',
                      method: 'POST',
                      body: pwd,
                    );
                    if (!ctx.mounted) return;
                    final r = await showDialog<Map<String, dynamic>>(
                      context: ctx,
                      barrierDismissible: false,
                      builder: (_) => _TotpSetup(
                        secret: setup['secreto'] as String,
                        session: session,
                        uri: setup['uri'] as String,
                      ),
                    );
                    if (r == null || !ctx.mounted) return;
                    await showDialog<void>(
                      context: ctx,
                      barrierDismissible: false,
                      builder: (d) => AlertDialog(
                        title: const Text('Guarda tus códigos de recuperación'),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                r['token'] is String
                                    ? 'Guárdalos por si pierdes tu autenticador. Tu sesión sigue abierta.'
                                    : 'Guárdalos por si pierdes tu autenticador. Inicia sesión para continuar.',
                              ),
                              if (session.storageNotice != null)
                                Text(session.storageNotice!),
                              gap(),
                              SelectableText(
                                (r['codigos_recuperacion'] as List).join('\n'),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          FilledButton(
                            onPressed: () => Navigator.pop(d),
                            child: const Text('Ya los guardé'),
                          ),
                        ],
                      ),
                    );
                    if (r['token'] is! String) {
                      session.clear();
                    } else {
                      await session.refresh();
                      if (ctx.mounted) reload();
                    }
                  }),
                ),
              if (data['mfa_activo'] == true)
                OutlinedButton(
                  onPressed: () => perform(ctx, () async {
                    final d = await ask(
                      ctx,
                      'Desactivar segundo factor',
                      {
                        'clave': 'Contraseña actual',
                        'codigo': 'Código del autenticador o recuperación',
                      },
                      secrets: {'clave'},
                    );
                    if (d == null) return;
                    await session.api.request(
                      '/seguridad/totp/desactivar',
                      method: 'POST',
                      body: d,
                    );
                    session.clear();
                  }),
                  child: const Text('Desactivar y cerrar sesiones'),
                ),
            ],
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Contraseña y sesiones',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              gap(),
              OutlinedButton(
                onPressed: () => perform(ctx, () async {
                  final d = await ask(
                    ctx,
                    'Cambiar contraseña',
                    {
                      'clave': 'Contraseña actual',
                      'nueva_clave': 'Nueva contraseña (12 o más caracteres)',
                      if (data['mfa_activo'] == true)
                        'codigo': 'Código del autenticador o recuperación',
                    },
                    secrets: {'clave', 'nueva_clave'},
                  );
                  if (d == null) return;
                  await session.api.request(
                    '/seguridad/clave',
                    method: 'POST',
                    body: d,
                  );
                  session.clear();
                }),
                child: const Text('Cambiar contraseña'),
              ),
              OutlinedButton(
                onPressed: () => openScreen(
                  ctx,
                  DataScreen(
                    session: session,
                    title: 'Sesiones activas',
                    path: '/seguridad/sesiones',
                    render: (c, r, refresh) => Column(
                      children: [
                        for (final s in r)
                          Panel(
                            child: ListTile(
                              leading: const Icon(Icons.devices),
                              title: Text(
                                s['actual'] == true
                                    ? 'Esta sesión'
                                    : 'Otra sesión',
                              ),
                              subtitle: Text(
                                'Inicio: ${s['creado_en']}\nVence: ${s['vence_en']}',
                              ),
                            ),
                          ),
                        FilledButton(
                          onPressed: () => perform(c, () async {
                            await session.api.request(
                              '/seguridad/sesiones/cerrar-otras',
                              method: 'POST',
                            );
                            refresh();
                          }),
                          child: const Text('Cerrar las otras sesiones'),
                        ),
                      ],
                    ),
                  ),
                ),
                child: const Text('Revisar sesiones'),
              ),
            ],
          ),
        ),
        if (data['mfa_activo'] != true) HuellaPanel(session: session),
      ],
    ),
  );
}

class _TotpSetup extends StatefulWidget {
  final String secret;
  final String uri;
  final Session session;
  const _TotpSetup({
    required this.secret,
    required this.uri,
    required this.session,
  });
  @override
  State<_TotpSetup> createState() => _TotpSetupState();
}

class _TotpSetupState extends State<_TotpSetup> {
  final code = TextEditingController();
  bool busy = false;
  String? error;
  Future<void> confirm() async {
    if (!RegExp(r'^\d{6}$').hasMatch(code.text)) {
      setState(
        () => error = 'Escribe los seis dígitos que ves en el autenticador.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await widget.session.api.request(
        '/seguridad/totp/activar',
        method: 'POST',
        body: {
          'codigo': code.text,
          'continuar_sesion': true,
          'recordar_telefono': widget.session.rememberPhone,
        },
      );
      if (r['token'] is String) {
        await widget.session.saveValidated(r['token'] as String);
      }
      if (mounted) Navigator.pop(context, Map<String, dynamic>.from(r as Map));
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Vincula tu autenticador'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. Abre la aplicación autenticadora que utilizas y guarda la cuenta RutaAlerta.',
          ),
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () => perform(
                    context,
                    () => Mobility.channel.invokeMethod<void>(
                      'openAuthenticator',
                      {'uri': widget.uri},
                    ),
                  ),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Abrir mi autenticador'),
          ),
          ExpansionTile(
            title: const Text('Agregar con clave manual'),
            children: [
              const Note(
                'En tu autenticador, elige agregar una cuenta con clave basada en tiempo. Mantén presionada la clave para copiarla.',
              ),
              SelectableText(widget.secret),
            ],
          ),
          const Note(
            '2. Vuelve aquí y escribe el código de RutaAlerta. La configuración vence en diez minutos.',
          ),
          CheckboxListTile(
            value: widget.session.rememberPhone,
            title: const Text('Recordar este teléfono'),
            subtitle: const Text('Hasta 30 días en tu cuenta ciudadana.'),
            onChanged: busy
                ? null
                : (value) => setState(
                    () => widget.session.rememberPhone = value == true,
                  ),
          ),
          TextField(
            controller: code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            enabled: !busy,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Código de seis dígitos',
            ),
          ),
          if (error != null) Semantics(liveRegion: true, child: Text(error!)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: busy ? null : confirm,
        child: const Text('Activar'),
      ),
    ],
  );
}

class CaseScreen extends StatelessWidget {
  final Session session;
  final int cid;
  const CaseScreen({super.key, required this.session, required this.cid});
  Future<void> cambiarDifusion(
    BuildContext context,
    VoidCallback reload,
    String accion,
  ) async {
    final recuperacion = accion == 'informar_recuperacion';
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          recuperacion ? '¿Informar recuperación?' : '¿Retirar consentimiento?',
        ),
        content: Text(
          recuperacion
              ? 'La difusión se suspenderá y la organización revisará tu aviso. El encargo se gestiona por el canal oficial.'
              : 'La difusión se suspenderá y el expediente seguirá disponible para revisión.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !context.mounted) return;
    await perform(context, () async {
      await session.api.request(
        '/mis-casos/$cid/alerta',
        method: 'POST',
        body: {'accion': accion},
      );
      if (context.mounted) reload();
    });
  }

  @override
  Widget build(BuildContext context) => DataScreen(
    session: session,
    title: 'Seguimiento del caso',
    path: '/seguimiento/$cid',
    render: (ctx, d, reload) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          '${d['folio']}',
          eyebrow: '${d['patente']} · ${d['zona']}',
        ),
        StateChip('${d['estado']}'),
        OutlinedButton.icon(
          onPressed: () {
            final comuna = '${d['zona']}'.split(' · ').first;
            openScreen(
              ctx,
              DataScreen(
                session: session,
                title: 'Recursos de apoyo',
                path:
                    '/recursos-apoyo?territorio=${Uri.encodeQueryComponent(comuna)}',
                render: (context, data, reload) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionTitle('Orientación en $comuna'),
                    if ((data as List).isEmpty)
                      const Note(
                        'El equipo todavía no ha publicado canales vigentes para esta comuna.',
                      ),
                    for (final recurso in data)
                      Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${recurso['titulo']}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            gap(),
                            Text('${recurso['descripcion']}'),
                            gap(),
                            SelectableText('Canal: ${recurso['canal']}'),
                            if (recurso['url_oficial'] != null)
                              SelectableText('${recurso['url_oficial']}'),
                            gap(),
                            Text('Responsable: ${recurso['responsable']}'),
                            Text('Verificado: ${recurso['verificado_en']}'),
                            Text('Vigente hasta: ${recurso['vence_en']}'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
          icon: const Icon(Icons.support_agent),
          label: const Text('Ver recursos de apoyo de la comuna'),
        ),
        const Note(
          'Los aportes son antecedentes sujetos a revisión. Este reporte no reemplaza una denuncia.',
        ),
        if (d['es_propietario'] == true)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: d['estado'] == 'cerrado'
                      ? null
                      : () async {
                          final saved = await Navigator.of(ctx).push<bool>(
                            MaterialPageRoute(
                              builder: (_) =>
                                  OwnerNoteScreen(session: session, cid: cid),
                            ),
                          );
                          if (saved == true && ctx.mounted) reload();
                        },
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('Agregar antecedente privado'),
                ),
                gap(),
                OutlinedButton.icon(
                  onPressed: d['estado'] == 'cerrado'
                      ? null
                      : () => perform(ctx, () async {
                          final r = await ask(
                            ctx,
                            'Antecedentes de denuncia',
                            {
                              'estado': 'no_informada, pendiente o declarada',
                              'referencia':
                                  'Referencia (requerida si está declarada)',
                            },
                            values: {'estado': '${d['denuncia_estado']}'},
                          );
                          if (r == null) return;
                          await session.api.request(
                            '/mis-casos/$cid/denuncia',
                            method: 'POST',
                            body: r,
                          );
                          reload();
                        }),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Actualizar denuncia declarada'),
                ),

                FilledButton.icon(
                  onPressed:
                      d['estado'] == 'cerrado' ||
                          d['colaboracion_consentida_en'] != null
                      ? null
                      : () => perform(ctx, () async {
                          final confirm = await showDialog<bool>(
                            context: ctx,
                            builder: (c) => AlertDialog(
                              title: const Text('Autorizar colaboración'),
                              content: const Text(
                                'Un operador podrá publicar patente, características del vehículo, sector aproximado y un texto revisado. Tu relato y coordenada exacta no se publican. ¿Solicitar revisión?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Autorizar'),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                          final r = await session.api.request(
                            '/mis-casos/$cid/colaboracion',
                            method: 'POST',
                          );
                          if (ctx.mounted) feedback(ctx, r['mensaje']);
                          reload();
                        }),
                  icon: const Icon(Icons.groups_outlined),
                  label: Text(
                    d['colaboracion_consentida_en'] == null
                        ? 'Solicitar colaboración'
                        : 'Colaboración autorizada',
                  ),
                ),
                gap(),
                if (d['estado_colaboracion'] != null)
                  Note('Alertas de vehículos · ${d['estado_colaboracion']}'),
                if (d['encargo'] case final Map consulta)
                  Note(
                    (consulta['simulada'] == true ? 'Simulación · ' : '') +
                        (switch (consulta['resultado']) {
                          'encontrado' =>
                            'Encargo encontrado en la consulta registrada.',
                          'sin_resultado' => 'La consulta no encontró un encargo en ese momento.',
                          _ => 'Fuente de consulta no disponible.',
                        }),
                  ),
                if (d['estado'] != 'cerrado')
                  Wrap(
                    spacing: 8,
                    children: [
                      if (d['colaboracion_consentida_en'] != null)
                        TextButton(
                          onPressed: () => cambiarDifusion(
                            ctx,
                            reload,
                            'retirar_consentimiento',
                          ),
                          child: const Text('Retirar consentimiento'),
                        ),
                      TextButton(
                        onPressed: () => cambiarDifusion(
                          ctx,
                          reload,
                          'informar_recuperacion',
                        ),
                        child: const Text('Informar recuperación'),
                      ),
                    ],
                  ),
                OutlinedButton.icon(
                  onPressed: d['estado'] == 'cerrado'
                      ? null
                      : () => perform(ctx, () async {
                          final saved = await showDialog<bool>(
                            context: ctx,
                            barrierDismissible: false,
                            builder: (_) => CasePhotoUpload(
                              api: session.api,
                              cid: cid,
                              collaborationRequested:
                                  d['colaboracion_consentida_en'] != null,
                            ),
                          );
                          if (saved == true && ctx.mounted) reload();
                        }),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Adjuntar foto al caso'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      openScreen(ctx, TrustScreen(session: session, cid: cid)),
                  icon: const Icon(Icons.people_outline),
                  label: const Text('Contactos de confianza'),
                ),
              ],
            ),
          ),
        if (d['evidencias'] != null &&
            (d['evidencias'] as List).isNotEmpty) ...[
          const SectionTitle('Fotos del caso'),
          for (final e in d['evidencias'])
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    leading: const Icon(Icons.image_outlined),
                    title: Text('Foto #${e['id_evidencia']}'),
                    subtitle: Text('${e['estado_revision']}'),
                    onTap: () => openScreen(
                      ctx,
                      PhotoScreen(
                        session: session,
                        id: e['id_evidencia'] as int,
                      ),
                    ),
                  ),
                  if (d['es_propietario'] == true)
                    PhotoPublicationControl(
                      api: session.api,
                      cid: cid,
                      eid: e['id_evidencia'] as int,
                      authorized: e['autorizada_publicacion_en'] != null,
                      canGrant:
                          d['estado'] != 'cerrado' &&
                          d['colaboracion_consentida_en'] != null,
                      onChanged: reload,
                    ),
                ],
              ),
            ),
        ],
        const SectionTitle('Historial del caso'),
        if ((d['historial'] as List).isEmpty)
          const Panel(
            child: Text(
              'Reporte recibido. Todavía no hay novedades publicadas.',
            ),
          ),
        for (final event in d['historial'])
          Panel(
            child: ListTile(
              leading: const Icon(Icons.timeline),
              title: Text('${event['descripcion']}'),
              subtitle: Text('${event['creada_en']}'),
            ),
          ),
        for (final a in (d['aportes'] ?? []))
          Panel(
            child: ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: Text('${a['resumen_para_afectado']}'),
              subtitle: Text('${a['zona']} · ${a['observado_en']}'),
            ),
          ),
      ],
    ),
  );
}

class PhotoScreen extends StatefulWidget {
  final Session session;
  final int id;
  const PhotoScreen({super.key, required this.session, required this.id});
  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  late final Future<Uint8List> photo = widget.session.api.photo(widget.id);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Evidencia privada')),
    body: FutureBuilder<Uint8List>(
      future: photo,
      builder: (_, s) => s.hasData
          ? InteractiveViewer(child: Center(child: Image.memory(s.data!)))
          : Center(
              child: s.hasError
                  ? Text('${s.error}')
                  : const CircularProgressIndicator(),
            ),
    ),
  );
}

class TrustScreen extends StatelessWidget {
  final Session session;
  final int cid;
  const TrustScreen({super.key, required this.session, required this.cid});
  @override
  Widget build(BuildContext context) => DataScreen(
    session: session,
    title: 'Contactos de confianza',
    path: '/mis-casos/$cid/confianza',
    render: (ctx, data, reload) => Column(
      children: [
        const Note(
          'Sólo compartes el estado y las novedades autorizadas. El contacto debe tener una cuenta activa. No accede al relato privado, fotos ni coordenadas exactas.',
        ),
        FilledButton.icon(
          onPressed: () => perform(ctx, () async {
            final d = await ask(
              ctx,
              'Autorizar contacto',
              {'correo': 'Correo de la cuenta', 'dias': 'Días (1 a 30)'},
              values: {'dias': '7'},
            );
            if (d == null) return;
            await session.api.request(
              '/mis-casos/$cid/confianza',
              method: 'POST',
              body: {
                'correo': d['correo'],
                'dias': int.tryParse(d['dias'] ?? '') ?? 7,
              },
            );
            reload();
          }),
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Agregar contacto'),
        ),
        gap(),
        for (final c in data)
          Panel(
            child: ListTile(
              title: Text('${c['nombre_visible']}'),
              subtitle: Text(
                c['revocado_en'] != null
                    ? 'Revocado'
                    : 'Vence ${c['vence_en']}',
              ),
              trailing: c['revocado_en'] != null
                  ? null
                  : IconButton(
                      tooltip: 'Revocar acceso',
                      icon: const Icon(Icons.link_off),
                      onPressed: () => perform(ctx, () async {
                        await session.api.request(
                          '/mis-casos/$cid/confianza/${c['id_acceso_confianza']}/revocar',
                          method: 'POST',
                        );
                        reload();
                      }),
                    ),
            ),
          ),
      ],
    ),
  );
}

Widget mySightings(Session session) => DataScreen(
  session: session,
  title: 'Mis avistamientos',
  path: '/mis-avistamientos',
  render: (_, data, _) => Column(
    children: [
      if ((data as List).isEmpty)
        const Panel(child: Text('Todavía no has enviado avistamientos.')),
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
);

class InboxScreen extends StatelessWidget {
  final Session session;
  const InboxScreen({super.key, required this.session});
  @override
  Widget build(BuildContext context) => DataScreen(
    session: session,
    title: 'Notificaciones',
    path: '/notificaciones',
    render: (ctx, data, reload) => Column(
      children: [
        const Note(
          'Avisos internos guardados en tu cuenta. No son notificaciones push en segundo plano.',
        ),
        if ((data as List).isEmpty)
          const Panel(child: Text('Todavía no hay avisos.')),
        for (final n in data)
          Panel(
            child: ListTile(
              leading: Icon(
                n['leida_en'] == null
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none,
              ),
              title: Text('${n['titulo']}'),
              subtitle: Text('${n['mensaje']}'),
              onTap: () => perform(ctx, () async {
                await session.api.request(
                  '/notificaciones/${n['id_notificacion']}/leer',
                  method: 'POST',
                );
                reload();
                if (ctx.mounted && n['destino'] == 'avistamientos') {
                  openScreen(ctx, mySightings(session));
                } else if (ctx.mounted && n['id_caso'] != null) {
                  openScreen(
                    ctx,
                    CaseScreen(session: session, cid: n['id_caso'] as int),
                  );
                }
              }),
            ),
          ),
      ],
    ),
  );
}

class CommunityScreen extends StatefulWidget {
  final Session session;
  final bool active;
  final VoidCallback? openMap;
  const CommunityScreen({
    super.key,
    required this.session,
    this.active = true,
    this.openMap,
  });
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int revision = 0;
  DateTime consultado = DateTime.now();
  Timer? actualizacion;
  Timer? busquedaPendiente;
  @override
  void initState() {
    super.initState();
    actualizacion = Timer.periodic(const Duration(seconds: 20), (_) {
      if (widget.active &&
          (ModalRoute.of(context)?.isCurrent ?? false) &&
          !searchFocus.hasFocus) {
        setState(() {
          revision++;
          consultado = DateTime.now();
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant CommunityScreen anterior) {
    super.didUpdateWidget(anterior);
    if (widget.active &&
        !anterior.active &&
        DateTime.now().difference(consultado).inSeconds >= 15) {
      revision++;
      consultado = DateTime.now();
    }
  }

  final zone = TextEditingController();
  final searchFocus = FocusNode();
  String query = '';
  String sectorBuscado = '';
  Map<String, String> proximity = {};
  void search([Map<String, String>? area]) {
    busquedaPendiente?.cancel();
    setState(() {
      if (area != null) proximity = area;
      sectorBuscado = zone.text.trim();
      query = Uri(
        queryParameters: {
          ...proximity,
          if (sectorBuscado.isNotEmpty) 'zona': sectorBuscado,
        },
      ).query;
      consultado = DateTime.now();
      revision++;
    });
  }

  @override
  void dispose() {
    actualizacion?.cancel();
    busquedaPendiente?.cancel();
    searchFocus.dispose();
    zone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (widget.openMap != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.openMap,
              icon: const Icon(Icons.layers_outlined),
              label: const Text('Ver mapa de zonas históricas'),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: zone,
                focusNode: searchFocus,
                textInputAction: TextInputAction.search,
                maxLength: 200,
                onChanged: (_) {
                  busquedaPendiente?.cancel();
                  busquedaPendiente = Timer(
                    const Duration(milliseconds: 350),
                    search,
                  );
                },
                onSubmitted: (_) => search(),
                decoration: InputDecoration(
                  labelText: 'Buscar comuna o sector',
                  counterText: '',
                  suffixIcon: ListenableBuilder(
                    listenable: zone,
                    builder: (context, _) => zone.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            tooltip: 'Limpiar búsqueda',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              zone.clear();
                              search();
                            },
                          ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Buscar',
              onPressed: () => search(),
              icon: const Icon(Icons.search),
            ),
            IconButton(
              tooltip: 'Buscar a 30 km de mi GPS',
              icon: const Icon(Icons.my_location),
              onPressed: () => perform(context, () async {
                final p = await Mobility.location();
                if (mounted) {
                  search({
                    'lat': (p['lat'] as num).toStringAsFixed(2),
                    'lon': (p['lon'] as num).toStringAsFixed(2),
                    'radio_km': '30',
                  });
                }
              }),
            ),
            IconButton(
              tooltip: 'Definir ubicación de búsqueda',
              icon: const Icon(Icons.near_me_outlined),
              onPressed: () => perform(context, () async {
                final d = await ask(
                  context,
                  'Ubicación para ordenar cercanía',
                  {
                    'lat': 'Latitud',
                    'lon': 'Longitud',
                    'radio_km': 'Radio en kilómetros',
                  },
                  values: {'radio_km': '30'},
                );
                if (d == null) return;
                if (double.tryParse(d['lat'] ?? '') == null ||
                    double.tryParse(d['lon'] ?? '') == null) {
                  throw Exception('Ingresa coordenadas válidas.');
                }
                if (mounted) search(d);
              }),
            ),
          ],
        ),
      ),
      Expanded(
        child: DataScreen(
          key: ValueKey(query),
          revision: revision,
          session: widget.session,
          title: 'Alertas de vehículos',
          path: query.isEmpty ? '/colaboracion' : '/colaboracion?$query',
          render: (ctx, data, reload) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (data['demo_alertas'] == true)
                const Note('DEMOSTRACIÓN AISLADA · Vehículos ficticios'),
              if (sectorBuscado.isNotEmpty)
                Note('Resultados para «$sectorBuscado»'),
              Text(
                'Actualizado ${TimeOfDay.now().format(ctx)}',
                style: const TextStyle(color: muted),
              ),
              const Note(
                'Sólo aparecen solicitudes revisadas y vigentes. No sigas vehículos ni confrontes a nadie.',
              ),
              if ((data['cercanos'] as List).isEmpty &&
                  (data['otras_zonas'] as List).isEmpty)
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sin solicitudes vigentes para esta búsqueda',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        sectorBuscado.isEmpty
                            ? 'Aquí aparecen las solicitudes públicas mientras estén vigentes.'
                            : 'Prueba con otra comuna o sector, o limpia la búsqueda para ver todas las solicitudes vigentes.',
                      ),
                    ],
                  ),
                ),
              for (final group in ['cercanos', 'otras_zonas']) ...[
                if ((data[group] as List).isNotEmpty)
                  SectionTitle(
                    group == 'cercanos'
                        ? 'Dentro de 30 km'
                        : proximity.isEmpty
                        ? 'Solicitudes publicadas'
                        : 'Otras zonas',
                  ),
                for (final s in data[group])
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PublicVehicleDetails(
                          api: widget.session.api,
                          data: Map<String, dynamic>.from(s as Map),
                        ),
                        if (s['distancia_km'] != null)
                          Note(
                            'Sector a ~${s['distancia_km']} km. No es posición actual del vehículo.',
                          ),
                        Note('Vigencia: ${s['vence_en']}'),
                        collaborationAction(ctx, widget.session, s),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

class SightingScreen extends StatefulWidget {
  final Session session;
  final int sid;
  const SightingScreen({super.key, required this.session, required this.sid});
  @override
  State<SightingScreen> createState() => _SightingScreenState();
}

class _SightingScreenState extends State<SightingScreen> {
  final zone = TextEditingController(), description = TextEditingController();
  LatLng? location;
  String? commune;
  final key = const Uuid().v4();
  Uint8List? photo;
  DateTime date = DateTime.now();
  bool busy = false;
  @override
  void dispose() {
    for (final c in [zone, description]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Aportar avistamiento')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        PublicVehicleHeader(api: widget.session.api, sid: widget.sid),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle('Lo que observaste'),
              const Note(
                'Indica una observación real y su lugar. Nunca es una orden de búsqueda o persecución.',
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        final day = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (day == null || !context.mounted) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(date),
                        );
                        if (time != null && mounted) {
                          setState(
                            () => date = DateTime(
                              day.year,
                              day.month,
                              day.day,
                              time.hour,
                              time.minute,
                            ),
                          );
                        }
                      },
                child: Text('Observado: ${date.toLocal()}'),
              ),
              gap(),
              const FormSection('Lugar observado', icon: Icons.place_outlined),
              CommunePicker(
                api: widget.session.api,
                value: commune,
                enabled: !busy,
                onChanged: (value) => setState(() => commune = value),
              ),
              gap(),
              TextField(
                controller: zone,
                enabled: !busy,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Calle o sector del avistamiento',
                  hintText: 'Ej.: calle, cruce o punto de referencia y comuna',
                  helperText: 'Describe el lugar que marcarás en el mapa.',
                  helperMaxLines: 2,
                ),
              ),
              LocationPicker(
                value: location,
                center: widget.session.centroZonal,
                enabled: !busy,
                onChanged: (value) => setState(() => location = value),
              ),
              gap(24),
              const FormSection(
                'Detalles del avistamiento',
                icon: Icons.visibility_outlined,
              ),
              TextField(
                controller: description,
                enabled: !busy,
                maxLength: 3000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Describe lo observado (mínimo 10 caracteres)',
                  alignLabelWithHint: true,
                ),
              ),
              gap(),
              FotoAporte(
                foto: photo,
                ocupado: busy,
                cambiar: (v) => setState(() => photo = v),
              ),
              const Note(
                'La foto es opcional. Solo el equipo que revisa el caso puede consultarla.',
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () => perform(context, () async {
                        setState(() => busy = true);
                        try {
                          if (!validLocation(location)) {
                            throw Exception(
                              'Selecciona el lugar observado en el mapa o usa tu ubicación actual.',
                            );
                          }
                          if (date.isAfter(
                            DateTime.now().add(const Duration(minutes: 1)),
                          )) {
                            throw Exception(
                              'La fecha del avistamiento no puede ser futura.',
                            );
                          }
                          if (zone.text.trim().length < 3 ||
                              description.text.trim().length < 10) {
                            throw Exception(
                              'Completa el sector y describe lo observado en al menos 10 caracteres.',
                            );
                          }
                          final validated = await validatedZone(
                            widget.session.api,
                            commune,
                            zone.text,
                            location!,
                          );
                          await widget.session.api.request(
                            '/colaboracion/${widget.sid}/avistamientos',
                            method: 'POST',
                            headers: {'Idempotency-Key': key},
                            body: {
                              'zona': validated,
                              'descripcion': description.text.trim(),
                              'observado_en': date.toUtc().toIso8601String(),
                              if (photo != null)
                                'foto_base64': base64Encode(photo!),
                              'latitud': location!.latitude,
                              'longitud': location!.longitude,
                            },
                          );
                          if (context.mounted) {
                            feedback(
                              context,
                              'Aporte recibido para revisión humana.',
                            );
                            Navigator.pop(context);
                          }
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      }),
                child: Text(busy ? 'Procesando…' : 'Enviar para revisión'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class OperatorScreen extends StatelessWidget {
  final Session session;
  const OperatorScreen({super.key, required this.session});
  @override
  Widget build(BuildContext context) => DataScreen(
    session: session,
    title: 'Gestión institucional',
    path: '/casos',
    render: (ctx, data, reload) => Column(
      children: [
        OutlinedButton.icon(
          onPressed: () => openScreen(
            ctx,
            DataScreen(
              session: session,
              title: 'Cámaras del ámbito',
              path: '/gestion/camaras',
              render: (_, r, _) => Column(
                children: [
                  Note('${r['nota']}'),
                  if ((r['camaras'] as List).isEmpty)
                    const Panel(
                      child: Text('No hay cámaras autorizadas registradas.'),
                    ),
                  for (final cam in r['camaras'])
                    Panel(
                      child: ListTile(
                        leading: const Icon(Icons.videocam_outlined),
                        title: Text('${cam['nombre']}'),
                        subtitle: Text(
                          '${cam['estado']} · Entorno ${cam['entorno']}\nAutorización: ${cam['referencia_autorizacion']}',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          icon: const Icon(Icons.videocam_outlined),
          label: const Text('Cámaras autorizadas'),
        ),

        FilledButton.tonal(
          onPressed: () => openScreen(
            ctx,
            DataScreen(
              session: session,
              title: 'Métricas del ámbito',
              path: '/gestion/metricas',
              render: (_, r, _) => Column(
                children: [
                  for (final m in r)
                    Panel(
                      child: ListTile(
                        title: Text('${m['estado']}'),
                        trailing: Text('${m['cantidad']}'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          child: const Text('Ver métricas'),
        ),
        gap(),
        if ((data as List).isEmpty)
          const Panel(child: Text('Sin casos asignados a tu organización.')),
        for (final c in data)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${c['folio']}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                StateChip('${c['estado']}'),
                Note(
                  'Prioridad ${c['prioridad']} · aportes pendientes: ${c['aportes_pendientes']}',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => openScreen(
                        ctx,
                        CaseScreen(session: session, cid: c['id_caso'] as int),
                      ),
                      child: const Text('Seguimiento y fotos'),
                    ),
                    OutlinedButton(
                      onPressed: () => openScreen(
                        ctx,
                        ReviewScreen(
                          session: session,
                          cid: c['id_caso'] as int,
                        ),
                      ),
                      child: const Text('Revisar aportes'),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (action) => perform(ctx, () async {
                        final cid = c['id_caso'];
                        if (action == 'publicar') {
                          final d = await ask(
                            ctx,
                            'Publicar colaboración revisada',
                            {
                              'zona':
                                  'Sector publicable (sin dirección exacta)',
                              'texto': 'Texto aprobado (sin datos privados)',
                              'motivo': 'Motivo de autorización',
                              'horas': 'Vigencia en horas (1 a 72)',
                            },
                            values: {'horas': '24'},
                          );
                          if (d == null) return;
                          await session.api.request(
                            '/gestion/casos/$cid/publicacion',
                            method: 'POST',
                            body: {
                              ...d,
                              'horas': int.tryParse(d['horas'] ?? '') ?? 24,
                            },
                          );
                        } else if (action == 'retirar') {
                          final d = await ask(ctx, 'Retirar publicación', {
                            'motivo': 'Motivo de retiro',
                          });
                          if (d == null) return;
                          await session.api.request(
                            '/gestion/casos/$cid/retirar',
                            method: 'POST',
                            body: d,
                          );
                        } else if (action == 'cerrar') {
                          final d = await ask(ctx, 'Cerrar caso', {
                            'motivo_cierre': 'recuperado, duplicado, informacion_insuficiente u otro',
                            'motivo': 'Explicación del cierre',
                            'id_evidencia':
                                'ID evidencia aceptada (sólo recuperado)',
                            'id_caso_principal':
                                'ID caso principal (sólo duplicado)',
                          });
                          if (d == null) return;
                          await session.api.request(
                            '/gestion/casos/$cid/cerrar',
                            method: 'POST',
                            body: {
                              ...d,
                              'id_evidencia': int.tryParse(
                                d['id_evidencia'] ?? '',
                              ),
                              'id_caso_principal': int.tryParse(
                                d['id_caso_principal'] ?? '',
                              ),
                            },
                          );
                        } else {
                          final d = await ask(ctx, 'Registrar revisión', {
                            'motivo': 'Motivo (10 o más caracteres)',
                          });
                          if (d == null) return;
                          await session.api.request(
                            '/gestion/casos/$cid/revision',
                            method: 'POST',
                            body: {...d, 'estado': action},
                          );
                        }
                        reload();
                        if (ctx.mounted) feedback(ctx, 'Gestión guardada.');
                      }),
                      itemBuilder: (_) => [
                        for (final m in {
                          'en_revision': 'Marcar en revisión',
                          'en_gestion': 'Marcar en gestión',
                          'publicar': 'Publicar colaboración',
                          'retirar': 'Retirar publicación',
                          'cerrar': 'Cerrar caso',
                        }.entries)
                          PopupMenuItem(value: m.key, child: Text(m.value)),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Gestionar ▾'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class ReviewScreen extends StatelessWidget {
  final Session session;
  final int cid;
  const ReviewScreen({super.key, required this.session, required this.cid});
  @override
  Widget build(BuildContext context) => DataScreen(
    session: session,
    title: 'Revisión de aportes',
    path: '/gestion/casos/$cid/aportes',
    render: (ctx, data, reload) => Column(
      children: [
        if ((data as List).isEmpty)
          const Panel(child: Text('No hay aportes para este caso.')),
        for (final a in data)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${a['zona']} · ${a['observado_en']}'),
                gap(8),
                Text('${a['descripcion']}'),
                Note('Ubicación privada: ${a['latitud']}, ${a['longitud']}'),
                StateChip('${a['estado_revision']}'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final decision in [
                      'aceptado',
                      'rechazado',
                      'requiere_aclaracion',
                    ])
                      OutlinedButton(
                        onPressed: () => perform(ctx, () async {
                          final d = await ask(ctx, 'Evaluar aporte', {
                            'motivo': 'Motivo de decisión',
                            if (decision == 'aceptado') 'resumen': 'Resumen para el afectado (sin datos privados del colaborador)',
                          });
                          if (d == null) return;
                          await session.api.request(
                            '/gestion/aportes/${a['id_avistamiento']}/revision',
                            method: 'POST',
                            body: {...d, 'decision': decision},
                          );
                          reload();
                        }),
                        child: Text(decision.replaceAll('_', ' ')),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Ownership is supplied by the server; owners contribute through private follow-up.
Widget collaborationAction(
  BuildContext context,
  Session session,
  dynamic item,
) {
  final own = item['es_mi_caso'] == true;
  return FilledButton.icon(
    onPressed: own
        ? () {
            final match = session.cases
                .where((c) => c['patente'] == item['patente'])
                .firstOrNull;
            final cid = item['id_caso'] ?? match?['id_caso'];
            if (cid is int) {
              openScreen(context, CaseScreen(session: session, cid: cid));
            } else {
              openScreen(
                context,
                DataScreen(
                  session: session,
                  title: 'Mis casos',
                  path: '/mis-casos',
                  render: (ctx, data, _) => Column(
                    children: [
                      for (final c in data)
                        Panel(
                          child: ListTile(
                            title: Text('${c['folio']}'),
                            subtitle: Text('${c['patente']} · ${c['estado']}'),
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
          }
        : session.canReport
        ? () => openScreen(
            context,
            SightingScreen(
              session: session,
              sid: item['id_solicitud_colaboracion'] as int,
            ),
          )
        : null,
    icon: Icon(own ? Icons.assignment_outlined : Icons.visibility_outlined),
    label: Text(own ? 'Ir al seguimiento de mi caso' : 'Aportar avistamiento'),
  );
}
