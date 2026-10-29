import 'package:flutter/material.dart';

import 'session.dart';
import 'ui.dart';

class ReportScreen extends StatefulWidget {
  final Session session;
  final VoidCallback openMap;
  const ReportScreen({super.key, required this.session, required this.openMap});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final form = GlobalKey<FormState>();
  final zone = TextEditingController(),
      description = TextEditingController(),
      latitude = TextEditingController(),
      longitude = TextEditingController();
  int? vehicle;
  bool busy = false;
  DateTime date = DateTime.now();
  @override
  void initState() {
    super.initState();
    syncPoint();
  }

  @override
  void didUpdateWidget(covariant ReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncPoint();
  }

  void syncPoint() {
    final p = widget.session.selectedPoint;
    if (p != null) {
      latitude.text = p.latitude.toStringAsFixed(6);
      longitude.text = p.longitude.toStringAsFixed(6);
    }
  }

  @override
  void dispose() {
    for (final c in [zone, description, latitude, longitude]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> chooseDate() async {
    final day = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (day == null || !mounted) return;
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
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (date.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      feedback(context, 'La fecha del incidente no puede ser futura.');
      return;
    }
    setState(() => busy = true);
    try {
      final folio = await widget.session.report({
        'id_vehiculo': vehicle,
        'id_organizacion': 1,
        'fecha_hecho': date.toUtc().toIso8601String(),
        'zona': zone.text.trim(),
        'descripcion': description.text.trim(),
        'latitud': double.parse(latitude.text.replaceAll(',', '.')),
        'longitud': double.parse(longitude.text.replaceAll(',', '.')),
      });
      if (!mounted) return;
      zone.clear();
      description.clear();
      latitude.clear();
      longitude.clear();
      setState(() {
        vehicle = null;
        date = DateTime.now();
      });
      feedback(context, 'Reporte $folio guardado y pendiente de revisión.');
      try {
        await widget.session.refresh();
      } catch (_) {
        if (mounted) {
          feedback(
            context,
            'El reporte se guardó. Actualiza Inicio para consultar su estado.',
          );
        }
      }
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String? coordinate(String? v, double max) {
    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
    return n != null && n.isFinite && n.abs() <= max
        ? null
        : 'Elige o escribe una coordenada válida';
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const SectionTitle('Nuevo reporte', eyebrow: 'Un punto de partida'),
      Panel(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Note(
                'El reporte es privado y queda pendiente de revisión. No reemplaza una denuncia ni genera un encargo policial.',
              ),
              DropdownButtonFormField<int>(
                key: ValueKey(vehicle),
                initialValue: vehicle,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Mi vehículo'),
                items: widget.session.vehicles
                    .map(
                      (v) => DropdownMenuItem<int>(
                        value: v['id_vehiculo'] as int,
                        child: Text(
                          '${v['patente']} · ${v['modelo']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: busy ? null : (v) => setState(() => vehicle = v),
                validator: (v) => v == null ? 'Selecciona tu vehículo' : null,
              ),
              gap(),
              OutlinedButton.icon(
                onPressed: busy ? null : chooseDate,
                icon: const Icon(Icons.schedule_rounded),
                label: Text(
                  'Fecha: ${date.day}/${date.month}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                ),
              ),
              gap(),
              TextFormField(
                controller: zone,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Sector o comuna'),
                validator: (v) =>
                    (v?.trim().length ?? 0) >= 2 ? null : 'Indica el sector',
              ),
              gap(),
              OutlinedButton.icon(
                onPressed: busy ? null : widget.openMap,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Elegir lugar en el mapa'),
              ),
              gap(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: latitude,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Latitud'),
                      validator: (v) => coordinate(v, 90),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: longitude,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Longitud'),
                      validator: (v) => coordinate(v, 180),
                    ),
                  ),
                ],
              ),
              gap(),
              TextFormField(
                controller: description,
                maxLines: 4,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: '¿Qué ocurrió?',
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v?.trim().length ?? 0) >= 5
                    ? null
                    : 'Agrega antecedentes del incidente',
              ),
              gap(12),
              FilledButton.icon(
                onPressed: busy || !widget.session.canReport ? null : save,
                icon: const Icon(Icons.send_outlined),
                label: Text(busy ? 'Guardando…' : 'Registrar reporte privado'),
              ),
              if (!widget.session.canReport)
                const Note(
                  'Completa los pasos de contactos y registra tu vehículo antes de reportar.',
                ),
            ],
          ),
        ),
      ),
    ],
  );
}
