import 'package:flutter/material.dart';

import 'session.dart';
import 'ui.dart';

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
    setState(() => busy = true);
    try {
      await widget.session.api.request(
        '/vehiculos',
        method: 'POST',
        body: {
          'tipo_vehiculo': type,
          'marca': brand,
          'modelo': model,
          'patente': plate.text.trim(),
          'color': color.text.trim(),
          'anio': int.parse(year.text),
        },
      );
      if (!mounted) return;
      feedback(context, 'Vehículo guardado. Vínculo pendiente de revisión.');
      for (final c in [plate, color, year]) {
        c.clear();
      }
      setState(() {
        type = brand = model = null;
      });
      await widget.session.refresh();
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
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
                    StateChip('Vínculo ${v['estado_vinculo']}'),
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
              FilledButton.icon(
                onPressed: busy || model == null || !widget.session.canReport
                    ? null
                    : save,
                icon: const Icon(Icons.add_rounded),
                label: Text(busy ? 'Guardando…' : 'Guardar vehículo'),
              ),
              const Note(
                'El vínculo queda declarado y pendiente de revisión. Registrarlo no acredita propiedad.',
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
