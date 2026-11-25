import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'api.dart';
import 'foto_aporte.dart';
import 'session.dart';
import 'ui.dart';

typedef ReviewOrganizations = ({List<dynamic> items, bool prelectura});

class VehiclesScreen extends StatefulWidget {
  final Session session;
  const VehiclesScreen({super.key, required this.session});
  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final form = GlobalKey<FormState>();
  String? type, brand, model;
  late Future<dynamic> catalog;
  int? revisionOrg;
  Uint8List? padron;
  Future<ReviewOrganizations>? organizations;
  bool verifyNow = false;
  bool authorizePrecheck = false;
  static const labels = {
    'automovil': 'Automóvil',
    'motocicleta': 'Motocicleta',
    'camioneta': 'Camioneta',
    'furgon': 'Furgón',
    'camion': 'Camión',
  };
  @override
  void initState() {
    super.initState();
    catalog = widget.session.api.request('/catalogo/vehiculos');
  }

  Widget choice(
    String label,
    String? value,
    List<String> choices,
    ValueChanged<String?> change, {
    Map<String, String> names = const {},
  }) => DropdownButtonFormField<String>(
    key: ValueKey('$label/$type/$brand/$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final item in choices)
        DropdownMenuItem(
          value: item,
          child: Text(names[item] ?? item, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: busy || choices.isEmpty ? null : change,
    validator: (v) => v == null ? 'Selecciona $label' : null,
  );
  final plate = TextEditingController(),
      color = TextEditingController(),
      year = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    for (final c in [plate, color, year]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final proof = padron;
    final org = revisionOrg;
    if (verifyNow && (org == null || proof == null)) {
      feedback(context, 'Selecciona la organización y adjunta el padrón.');
      return;
    }
    setState(() => busy = true);
    try {
      final result = await widget.session.api.request(
        '/vehiculos',
        method: 'POST',
        body: {
          'tipo_vehiculo': type,
          'marca': brand,
          'modelo': model,
          'patente': plate.text.trim(),
          'color': color.text.trim(),
          'anio': int.parse(year.text),
          if (verifyNow && proof != null)
            'revision': {
              'id_organizacion': org,
              'padron_base64': base64Encode(proof),
              if (authorizePrecheck) 'autorizar_prelectura': true,
            },
        },
      );
      if (!mounted) return;
      final revisionSent =
          result is Map && result['revision_solicitada'] == true;
      feedback(
        context,
        revisionSent
            ? 'Vehículo guardado y padrón enviado al supervisor.'
            : 'Vehículo guardado. Puedes enviar el padrón desde Mis vehículos.',
      );
      for (final c in [plate, color, year]) {
        c.clear();
      }
      setState(() {
        type = brand = model = null;
        verifyNow = false;
        authorizePrecheck = false;
        revisionOrg = null;
        padron = null;
      });
      await widget.session.refresh();
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<ReviewOrganizations> loadReviewOrganizations() async {
    final release = await widget.session.api.request('/version');
    if (release is! Map || release['padron_privado'] != true) {
      throw const ApiError(
        'La carga de padrones no está disponible en este momento. Puedes guardar el vehículo y adjuntar el padrón más tarde.',
      );
    }
    final items = await widget.session.api.request('/organizaciones') as List;
    return (items: items, prelectura: release['padron_prelectura'] == true);
  }

  Future<void> unlink(Map<String, dynamic> vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Quitar ${vehicle['patente']} de mis vehículos?'),
        content: const Text(
          'Se quitará tu vínculo con el vehículo. Los casos, antecedentes y fotos se conservan. Si tiene un caso abierto, primero debes resolverlo con el equipo a cargo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar vínculo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || busy) return;
    setState(() => busy = true);
    try {
      await widget.session.unlinkVehicle(vehicle['id_vehiculo'] as int);
      if (mounted) {
        feedback(
          context,
          'Vehículo quitado de tu lista. Los datos de los casos se conservan.',
        );
      }
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> requestReview(Map<String, dynamic> vehicle) async {
    try {
      final options = await loadReviewOrganizations();
      if (!mounted) return;
      int? org = vehicle['id_organizacion_revision'] as int?;
      Uint8List? document;
      bool authorize = false;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialog) => StatefulBuilder(
          builder: (dialog, update) => AlertDialog(
            title: const Text('Enviar padrón a revisión'),
            scrollable: true,
            content: reviewFields(
              options.items,
              org,
              document,
              (v) => update(() => org = v),
              (v) => update(() => document = v),
              fixedOrg: vehicle['id_organizacion_revision'] != null,
              precheck: options.prelectura,
              authorized: authorize,
              onAuthorize: (v) => update(() => authorize = v),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: org == null || document == null
                    ? null
                    : () => Navigator.pop(dialog, true),
                child: const Text('Enviar a revisión'),
              ),
            ],
          ),
        ),
      );
      if (accepted != true || !mounted || document == null || busy) return;
      setState(() => busy = true);
      await widget.session.api.request(
        '/vehiculos/${vehicle['id_vehiculo']}/revision-vinculo',
        method: 'POST',
        body: {
          'id_organizacion': org,
          'padron_base64': base64Encode(document!),
          if (authorize) 'autorizar_prelectura': true,
        },
      );
      await widget.session.refresh();
      if (mounted) feedback(context, 'Solicitud de revisión recibida.');
    } catch (error) {
      if (mounted) feedback(context, error);
    } finally {
      if (mounted && busy) setState(() => busy = false);
    }
  }

  Widget reviewFields(
    List options,
    int? selected,
    Uint8List? document,
    ValueChanged<int?> select,
    ValueChanged<Uint8List?> attach, {
    bool fixedOrg = false,
    required bool precheck,
    required bool authorized,
    required ValueChanged<bool> onAuthorize,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      DropdownButtonFormField<int>(
        isExpanded: true,
        initialValue: options.any((o) => o['id_organizacion'] == selected)
            ? selected
            : null,
        decoration: const InputDecoration(labelText: 'Organización revisora'),
        items: [
          for (final o in options)
            DropdownMenuItem(
              value: o['id_organizacion'] as int,
              child: Text(
                o['nombre'] as String,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: busy || fixedOrg || options.isEmpty ? null : select,
      ),
      const Note(
        'Adjunta una foto legible del padrón con nombre del titular y patente. La organización seleccionada lo recibe para revisión privada.',
      ),
      FotoAporte(
        foto: document,
        ocupado: busy,
        cambiar: attach,
        ladoMaximo: 2400,
      ),
      if (precheck)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Revisar si la patente coincide'),
          subtitle: const Text(
            'Si marcas esta opción, enviaremos la foto a un servicio externo (GroqCloud) para comparar la patente del padrón con la que escribiste. Si la dejas desmarcada, el supervisor revisará el padrón directamente.',
          ),
          value: authorized,
          onChanged: busy ? null : (value) => onAuthorize(value ?? false),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const SectionTitle('Mis vehículos', eyebrow: 'Antecedentes privados'),
      for (final v in widget.session.vehicles)
        Panel(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xffe8effb),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.directions_car_rounded, color: teal),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${v['patente']}',
                      style: const TextStyle(
                        fontSize: 20,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800,
                        color: navy,
                      ),
                    ),
                    Text(
                      '${v['marca']} ${v['modelo']}',
                      style: const TextStyle(color: muted),
                    ),
                    gap(6),
                    StateChip(
                      v['estado_vinculo'] == 'autorizado'
                          ? 'Vínculo aprobado'
                          : 'Vínculo pendiente',
                    ),
                    if (v['estado_vinculo'] == 'pendiente' &&
                        v['padron_recibido_en'] == null)
                      TextButton.icon(
                        onPressed: busy ? null : () => requestReview(v),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('Adjuntar padrón'),
                      ),
                    if (v['estado_vinculo'] == 'pendiente' &&
                        v['padron_recibido_en'] != null)
                      Text(
                        v['padron_prelectura'] == 'coincide'
                            ? 'Patente cotejada. Pendiente de revisión del supervisor.'
                            : 'Padrón enviado al supervisor',
                      ),
                    if (v['vence_revision_en'] case final String fecha)
                      Text(
                        'Revisión interna válida hasta ${fecha.split('T').first}',
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Quitar vehículo',
                onPressed: busy ? null : () => unlink(v),
                icon: const Icon(Icons.link_off_rounded, color: muted),
              ),
            ],
          ),
        ),
      if (widget.session.vehicles.isEmpty)
        const Panel(
          child: Note(
            'Aún no has registrado vehículos. Completa tus contactos y agrega el primero.',
          ),
        ),
      Panel(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle('Agregar vehículo'),
              const FormSection(
                'Identificación del vehículo',
                icon: Icons.directions_car_outlined,
              ),
              if (!widget.session.canReport)
                const Note(
                  'Primero completa los pasos de contactos en Inicio.',
                ),
              FutureBuilder<dynamic>(
                future: catalog,
                builder: (context, snapshot) {
                  if (snapshot.hasError ||
                      (snapshot.hasData && snapshot.data is! Map)) {
                    return TextButton(
                      onPressed: () => setState(() {
                        catalog = widget.session.api.request(
                          '/catalogo/vehiculos',
                        );
                      }),
                      child: const Text('Reintentar carga del catálogo'),
                    );
                  }
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  final all = snapshot.data['catalogo'] as Map;
                  final brands = all[type] as Map? ?? {};
                  final models = (brands[brand] as List? ?? []).cast<String>();
                  final format =
                      snapshot.data['formatos'][type == 'motocicleta'
                              ? 'motocicleta'
                              : 'cuatro_ruedas']
                          as String;
                  return Column(
                    children: [
                      choice(
                        'Tipo de vehículo',
                        type,
                        labels.keys.toList(),
                        (v) => setState(() {
                          type = v;
                          brand = model = null;
                        }),
                        names: labels,
                      ),
                      gap(),
                      choice(
                        'Marca',
                        brand,
                        brands.keys.cast<String>().toList(),
                        (v) => setState(() {
                          brand = v;
                          model = null;
                        }),
                      ),
                      gap(),
                      choice(
                        'Modelo',
                        model,
                        models,
                        (v) => setState(() => model = v),
                      ),
                      gap(),
                      TextFormField(
                        controller: plate,
                        enabled: !busy,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Patente chilena',
                          hintText: type == 'motocicleta' ? 'ABC12' : 'BCDF12',
                        ),
                        validator: (v) {
                          final normalized = (v ?? '').toUpperCase().replaceAll(
                            RegExp(r'[ .-]'),
                            '',
                          );
                          return RegExp('^$format\$').hasMatch(normalized)
                              ? null
                              : 'Revisa el formato de la patente para este tipo.';
                        },
                      ),
                    ],
                  );
                },
              ),
              gap(),
              TextFormField(
                controller: color,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Color',
                  prefixIcon: Icon(Icons.palette_outlined),
                ),
                validator: (v) =>
                    (v?.trim().length ?? 0) >= 2 ? null : 'Ingresa el color',
              ),
              gap(),
              TextFormField(
                controller: year,
                enabled: !busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Año',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                validator: (v) {
                  final y = int.tryParse(v ?? '');
                  return y != null && y >= 1900 && y <= DateTime.now().year + 1
                      ? null
                      : 'Revisa el año';
                },
              ),
              gap(20),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Adjuntar padrón y verificar vínculo'),
                subtitle: const Text(
                  'Una revisión vigente puede habilitar alertas provisionales.',
                ),
                value: verifyNow,
                onChanged: busy
                    ? null
                    : (value) => setState(() {
                        verifyNow = value;
                        if (value) {
                          organizations ??= loadReviewOrganizations();
                        } else {
                          revisionOrg = null;
                          padron = null;
                          authorizePrecheck = false;
                        }
                      }),
              ),
              if (verifyNow)
                FutureBuilder<ReviewOrganizations>(
                  future: organizations,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Note('${snapshot.error}'),
                          TextButton(
                            onPressed: () => setState(
                              () => organizations = loadReviewOrganizations(),
                            ),
                            child: const Text(
                              'Reintentar carga de organizaciones',
                            ),
                          ),
                        ],
                      );
                    }
                    if (!snapshot.hasData) {
                      return const LinearProgressIndicator();
                    }
                    return reviewFields(
                      snapshot.data!.items,
                      revisionOrg,
                      padron,
                      (v) => setState(() => revisionOrg = v),
                      (v) => setState(() => padron = v),
                      precheck: snapshot.data!.prelectura,
                      authorized: authorizePrecheck,
                      onAuthorize: (v) => setState(() => authorizePrecheck = v),
                    );
                  },
                ),
              gap(),
              FilledButton.icon(
                onPressed: busy || model == null || !widget.session.canReport
                    ? null
                    : save,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  busy
                      ? 'Guardando…'
                      : verifyNow
                      ? 'Guardar y enviar a revisión'
                      : 'Guardar vehículo',
                ),
              ),
              const Note(
                'El vínculo queda pendiente hasta que un supervisor lo apruebe.',
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
