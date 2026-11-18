import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'expanded.dart';
import 'session.dart';
import 'ui.dart';

class WitnessScreen extends StatefulWidget {
  final Session session;
  const WitnessScreen({super.key, required this.session});
  @override
  State<WitnessScreen> createState() => _WitnessScreenState();
}

class _WitnessScreenState extends State<WitnessScreen> {
  final form = GlobalKey<FormState>();
  final sector = TextEditingController(),
      story = TextEditingController(),
      plate = TextEditingController();
  late Future<dynamic> organizations;
  int? recipient;
  DateTime when = DateTime.now();
  String perspective = 'pasajero';
  String? key, signature, receipt;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    organizations = widget.session.api.request('/organizaciones');
  }

  @override
  void dispose() {
    sector.dispose();
    story.dispose();
    plate.dispose();
    super.dispose();
  }

  Future<void> pickTime() async {
    final day = await showDatePicker(
      context: context,
      initialDate: when,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(when),
    );
    if (time != null && mounted) {
      setState(
        () => when = DateTime(
          day.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> send() async {
    if (!form.currentState!.validate() || recipient == null || busy) return;
    if (when.isAfter(DateTime.now())) {
      feedback(context, 'Revisa la fecha y hora de la observación.');
      return;
    }
    final data = {
      'id_organizacion': recipient,
      'perspectiva': perspective,
      'observado_en': when.toUtc().toIso8601String(),
      'zona': sector.text.trim(),
      'descripcion': story.text.trim(),
      'patente_observada': plate.text.trim().isEmpty ? null : plate.text.trim(),
    };
    if (signature != data.toString()) {
      signature = data.toString();
      key = const Uuid().v4();
    }
    setState(() => busy = true);
    try {
      final result = await widget.session.api.request(
        '/avisos-testigo',
        method: 'POST',
        body: data,
        headers: {'Idempotency-Key': key!},
      );
      if (mounted) setState(() => receipt = result['id_aviso'] as String);
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Aviso de testigo')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (receipt != null)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Aviso recibido'),
                SelectableText('Comprobante: $receipt'),
                const Note(
                  'Puedes consultar la revisión desde Cuenta → Mis avisos de testigo.',
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Volver al inicio'),
                ),
              ],
            ),
          )
        else
          Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle('Presencié un incidente'),
                const Note(
                  'La organización que elijas recibirá este aviso privado. Puedes enviarlo aunque el vehículo sea de otra persona o desconozcas la patente.',
                ),
                DropdownButtonFormField<String>(
                  initialValue: perspective,
                  decoration: const InputDecoration(
                    labelText: '¿Desde dónde lo viste?',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'pasajero',
                      child: Text('Iba en el vehículo'),
                    ),
                    DropdownMenuItem(
                      value: 'testigo',
                      child: Text('Lo vi desde fuera'),
                    ),
                  ],
                  onChanged: busy
                      ? null
                      : (v) => setState(() => perspective = v!),
                ),
                gap(),
                FutureBuilder<dynamic>(
                  future: organizations,
                  builder: (context, s) {
                    if (s.hasError) {
                      return OutlinedButton(
                        onPressed: () => setState(
                          () => organizations = widget.session.api.request(
                            '/organizaciones',
                          ),
                        ),
                        child: const Text('Reintentar carga de organizaciones'),
                      );
                    }
                    if (!s.hasData) return const LinearProgressIndicator();
                    return DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: recipient,
                      decoration: const InputDecoration(
                        labelText: 'Organización receptora',
                      ),
                      items: [
                        for (final o in s.data as List)
                          DropdownMenuItem(
                            value: o['id_organizacion'] as int,
                            child: Text(o['nombre'] as String),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (v) => setState(() => recipient = v),
                      validator: (v) =>
                          v == null ? 'Selecciona una organización' : null,
                    );
                  },
                ),
                gap(),
                OutlinedButton.icon(
                  onPressed: busy ? null : pickTime,
                  icon: const Icon(Icons.schedule),
                  label: Text(
                    '${MaterialLocalizations.of(context).formatMediumDate(when)} · ${TimeOfDay.fromDateTime(when).format(context)}',
                  ),
                ),
                gap(),
                TextFormField(
                  controller: sector,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: '¿En qué sector ocurrió?',
                  ),
                  validator: (v) =>
                      (v?.trim().length ?? 0) < 3 ? 'Indica el sector' : null,
                ),
                TextFormField(
                  controller: plate,
                  maxLength: 16,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Patente completa (opcional)',
                    helperText: 'Si no la recuerdas, deja el campo vacío.',
                  ),
                ),
                TextFormField(
                  controller: story,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 3000,
                  decoration: const InputDecoration(labelText: '¿Qué viste?'),
                  validator: (v) => (v?.trim().length ?? 0) < 10
                      ? 'Describe lo observado en al menos 10 caracteres'
                      : null,
                ),
                if (!widget.session.canReport)
                  const Note(
                    'Verifica tu correo y configura el autenticador desde Inicio para enviar el aviso.',
                  ),
                FilledButton(
                  onPressed:
                      busy || !widget.session.canReport || recipient == null
                      ? null
                      : send,
                  child: Text(busy ? 'Enviando…' : 'Enviar aviso privado'),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

Widget witnessHistory(Session session) => DataScreen(
  session: session,
  title: 'Mis avisos de testigo',
  path: '/mis-avisos-testigo',
  render: (_, data, _) => Column(
    children: [
      if ((data as List).isEmpty)
        const Panel(child: Text('Todavía no has enviado avisos de testigo.')),
      for (final item in data)
        Panel(
          child: ListTile(
            title: Text(item['zona'] as String),
            subtitle: Text("Comprobante: ${item['id_aviso']}"),
            trailing: StateChip(item['estado']),
          ),
        ),
    ],
  ),
);
