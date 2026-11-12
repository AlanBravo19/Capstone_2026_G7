import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'session.dart';
import 'biometric.dart';
import 'ui.dart';

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
  const DataScreen({
    super.key,
    required this.session,
    required this.title,
    required this.path,
    required this.render,
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))],
    ),
    body: FutureBuilder(
      future: future,
      builder: (ctx, s) {
        if (s.connectionState != ConnectionState.done) {
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
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Acceso con huella o biometría',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Note(
                'Android protege una sesión ya autenticada. No guardamos tu contraseña ni tus huellas. Si vence la sesión, cambia la biometría o cierras sesión, debes ingresar de nuevo con contraseña y segundo factor.',
              ),
              FilledButton.icon(
                onPressed: () => perform(ctx, () async {
                  await session.enableBiometric();
                  if (ctx.mounted) {
                    feedback(
                      ctx,
                      'Acceso biométrico activado en este teléfono.',
                    );
                  }
                }),
                icon: const Icon(Icons.fingerprint),
                label: const Text('Activar en este teléfono'),
              ),
              TextButton(
                onPressed: () => perform(ctx, () async {
                  await BiometricAccess.clear();
                  if (ctx.mounted) {
                    feedback(
                      ctx,
                      'Acceso biométrico eliminado de este teléfono.',
                    );
                  }
                }),
                child: const Text('Desactivar acceso biométrico'),
              ),
            ],
          ),
        ),

        const SectionTitle(
          'Protege tu acceso',
          eyebrow: 'Contraseña + autenticador',
        ),
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
                'Usa una aplicación autenticadora compatible con TOTP. Los códigos cambian cada 30 segundos. Este método funciona sin correo ni SMS y no acredita identidad civil.',
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
                    final confirm = await showDialog<String>(
                      context: ctx,
                      builder: (_) =>
                          _TotpSetup(secret: setup['secreto'] as String),
                    );
                    if (confirm == null) return;
                    final r = await session.api.request(
                      '/seguridad/totp/activar',
                      method: 'POST',
                      body: {'codigo': confirm},
                    );
                    if (!ctx.mounted) return;
                    await showDialog<void>(
                      context: ctx,
                      barrierDismissible: false,
                      builder: (d) => AlertDialog(
                        title: const Text('Guarda tus códigos de recuperación'),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Cada código permite un acceso. Guárdalos en un lugar privado; no volverán a mostrarse.',
                              ),
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
                    session.clear();
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
      ],
    ),
  );
}

class _TotpSetup extends StatefulWidget {
  final String secret;
  const _TotpSetup({required this.secret});
  @override
  State<_TotpSetup> createState() => _TotpSetupState();
}

class _TotpSetupState extends State<_TotpSetup> {
  final code = TextEditingController();
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Vincular autenticador'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'En tu autenticador elige agregar clave manual. Nombre: RutaAlerta. Tipo: basado en tiempo. Copia esta clave privada:',
          ),
          gap(),
          SelectableText(widget.secret),
          const Note(
            'No compartas ni fotografíes esta clave. Configuración válida por 10 minutos.',
          ),
          TextField(
            controller: code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Código de seis dígitos',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, code.text.trim()),
        child: const Text('Activar'),
      ),
    ],
  );
}

class CaseScreen extends StatelessWidget {
  final Session session;
  final int cid;
  const CaseScreen({super.key, required this.session, required this.cid});
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
        const Note(
          'Los aportes son antecedentes sujetos a revisión. Este reporte no reemplaza una denuncia.',
        ),
        if (d['es_operador'] == true)
          OutlinedButton.icon(
            onPressed: () => openScreen(
              ctx,
              DataScreen(
                session: session,
                title: 'Resumen verificable',
                path: '/gestion/casos/$cid/resumen',
                render: (_, r, _) => Column(
                  children: [
                    Note('${r['metodo']}'),
                    for (final f in r['hechos'])
                      Panel(
                        child: ListTile(
                          title: Text('${f['texto']}'),
                          subtitle: Text('Referencia: ${f['fuente']}'),
                        ),
                      ),
                    Note('${r['limites']}'),
                  ],
                ),
              ),
            ),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Resumen con referencias'),
          ),
        if (d['es_propietario'] == true)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                  onPressed: d['estado'] == 'cerrado'
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
                        : 'Renovar solicitud de revisión',
                  ),
                ),
                gap(),
                OutlinedButton.icon(
                  onPressed: d['estado'] == 'cerrado'
                      ? null
                      : () => perform(ctx, () async {
                          final file = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1800,
                            maxHeight: 1800,
                            imageQuality: 85,
                          );
                          if (file == null) return;
                          final bytes = await file.readAsBytes();
                          if (bytes.length > 2097152) {
                            throw Exception(
                              'Selecciona una foto de hasta 2 MB.',
                            );
                          }
                          await session.api.request(
                            '/casos/$cid/fotos',
                            method: 'POST',
                            body: {
                              'contenido_base64': base64Encode(bytes),
                              'clave_envio': const Uuid().v4(),
                            },
                          );
                          reload();
                        }),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Adjuntar foto privada'),
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
          const SectionTitle('Evidencias privadas'),
          for (final e in d['evidencias'])
            Panel(
              child: ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text('Foto #${e['id_evidencia']}'),
                subtitle: Text('${e['estado_revision']}'),
                onTap: () => openScreen(
                  ctx,
                  PhotoScreen(session: session, id: e['id_evidencia'] as int),
                ),
                trailing: d['es_operador'] == true
                    ? PopupMenuButton<String>(
                        onSelected: (decision) => perform(ctx, () async {
                          final r = await ask(ctx, 'Motivo de evaluación', {
                            'motivo': 'Motivo (mínimo 10 caracteres)',
                          });
                          if (r == null) return;
                          await session.api.request(
                            '/gestion/evidencias/${e['id_evidencia']}/revision',
                            method: 'POST',
                            body: {...r, 'decision': decision},
                          );
                          reload();
                        }),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'aceptada',
                            child: Text('Aceptar'),
                          ),
                          const PopupMenuItem(
                            value: 'rechazada',
                            child: Text('Rechazar'),
                          ),
                        ],
                      )
                    : null,
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
                if (ctx.mounted && n['id_caso'] != null) {
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
  const CommunityScreen({super.key, required this.session});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final zone = TextEditingController(),
      lat = TextEditingController(),
      lon = TextEditingController();
  String query = '';
  @override
  void dispose() {
    zone.dispose();
    lat.dispose();
    lon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: zone,
                decoration: const InputDecoration(
                  labelText: 'Buscar comuna o sector',
                ),
              ),
            ),
            IconButton(
              tooltip: 'Buscar',
              onPressed: () => setState(
                () => query = Uri(queryParameters: {'zona': zone.text}).query,
              ),
              icon: const Icon(Icons.search),
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
                setState(
                  () =>
                      query = Uri(queryParameters: {...d, 'zona': zone.text})
                          .query,
                );
              }),
            ),
          ],
        ),
      ),
      Expanded(
        child: DataScreen(
          key: ValueKey(query),
          session: widget.session,
          title: 'Colaborar',
          path: '/colaboracion?$query',
          render: (ctx, data, reload) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Note(
                'Sólo aparecen solicitudes revisadas y vigentes. No sigas vehículos ni confrontes a nadie.',
              ),
              for (final group in ['cercanos', 'otras_zonas']) ...[
                SectionTitle(
                  group == 'cercanos' ? 'Cerca de tu búsqueda' : 'Otras zonas',
                ),
                if ((data[group] as List).isEmpty)
                  const Panel(child: Text('Sin solicitudes en este grupo.')),
                for (final s in data[group])
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s['patente']} · ${s['marca']} ${s['modelo']}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        gap(8),
                        Text('${s['color']} · ${s['zona_publicable']}'),
                        if (s['distancia_km'] != null)
                          Note(
                            'Sector a ~${s['distancia_km']} km. No es posición actual del vehículo.',
                          ),
                        Text('${s['texto_aprobado']}'),
                        Note('Vigencia: ${s['vence_en']}'),
                        FilledButton.icon(
                          onPressed: widget.session.canReport
                              ? () => openScreen(
                                  ctx,
                                  SightingScreen(
                                    session: widget.session,
                                    sid: s['id_solicitud_colaboracion'] as int,
                                  ),
                                )
                              : null,
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('Aportar avistamiento'),
                        ),
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
  final zone = TextEditingController(),
      description = TextEditingController(),
      lat = TextEditingController(),
      lon = TextEditingController();
  final key = const Uuid().v4();
  DateTime date = DateTime.now();
  bool busy = false;
  @override
  void dispose() {
    for (final c in [zone, description, lat, lon]) {
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
        const SectionTitle('Lo que observaste'),
        const Note(
          'Indica una observación real y su lugar. Nunca es una orden de búsqueda o persecución.',
        ),
        OutlinedButton(
          onPressed: () async {
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
        for (final item in [
          (zone, 'Comuna o sector'),
          (description, 'Describe lo observado (mínimo 10 caracteres)'),
          (lat, 'Latitud del avistamiento'),
          (lon, 'Longitud del avistamiento'),
        ]) ...[
          TextField(
            controller: item.$1,
            decoration: InputDecoration(labelText: item.$2),
            maxLines: item.$1 == description ? 4 : 1,
          ),
          gap(),
        ],
        FilledButton(
          onPressed: busy
              ? null
              : () => perform(context, () async {
                  setState(() => busy = true);
                  try {
                    final la = double.tryParse(lat.text),
                        lo = double.tryParse(lon.text);
                    if (la == null || lo == null) {
                      throw Exception(
                        'Indica las coordenadas del lugar observado.',
                      );
                    }
                    await widget.session.api.request(
                      '/colaboracion/${widget.sid}/avistamientos',
                      method: 'POST',
                      headers: {'Idempotency-Key': key},
                      body: {
                        'zona': zone.text,
                        'descripcion': description.text,
                        'observado_en': date.toUtc().toIso8601String(),
                        'latitud': la,
                        'longitud': lo,
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
          child: Text(busy ? 'Enviando…' : 'Enviar para revisión'),
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
