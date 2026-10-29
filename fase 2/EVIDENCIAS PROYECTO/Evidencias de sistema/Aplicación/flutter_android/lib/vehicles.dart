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
  final brand = TextEditingController(),
      model = TextEditingController(),
      plate = TextEditingController(),
      color = TextEditingController(),
      year = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    for (final c in [brand, model, plate, color, year]) {
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
          'marca': brand.text.trim(),
          'modelo': model.text.trim(),
          'patente': plate.text.trim(),
          'color': color.text.trim(),
          'anio': int.parse(year.text),
        },
      );
      if (!mounted) return;
      feedback(context, 'Vehículo guardado. Vínculo pendiente de revisión.');
      for (final c in [brand, model, plate, color, year]) {
        c.clear();
      }
      await widget.session.refresh();
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
                  color: const Color(0xffeaf4f0),
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
              if (!widget.session.canReport)
                const Note(
                  'Primero completa los pasos de contactos en Inicio.',
                ),
              TextFormField(
                controller: brand,
                decoration: const InputDecoration(labelText: 'Marca'),
                validator: (v) =>
                    (v?.trim().length ?? 0) >= 2 ? null : 'Ingresa la marca',
              ),
              gap(),
              TextFormField(
                controller: model,
                decoration: const InputDecoration(labelText: 'Modelo'),
                validator: requiredText,
              ),
              gap(),
              TextFormField(
                controller: plate,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Patente',
                  hintText: 'ABCD12',
                ),
                validator: (v) =>
                    RegExp(r'^[A-Za-z0-9\s-]{4,16}$').hasMatch(v ?? '')
                    ? null
                    : 'Revisa la patente',
              ),
              gap(),
              TextFormField(
                controller: color,
                decoration: const InputDecoration(labelText: 'Color'),
                validator: (v) =>
                    (v?.trim().length ?? 0) >= 2 ? null : 'Ingresa el color',
              ),
              gap(),
              TextFormField(
                controller: year,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Año'),
                validator: (v) {
                  final y = int.tryParse(v ?? '');
                  return y != null && y >= 1900 && y <= DateTime.now().year + 1
                      ? null
                      : 'Revisa el año';
                },
              ),
              gap(20),
              FilledButton.icon(
                onPressed: busy || !widget.session.canReport ? null : save,
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
