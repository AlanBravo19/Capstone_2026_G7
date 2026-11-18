import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import 'foto_aporte.dart';
import 'location_picker.dart';
import 'session.dart';
import 'ui.dart';

class OwnerNoteScreen extends StatefulWidget {
  final Session session;
  final int cid;
  const OwnerNoteScreen({super.key, required this.session, required this.cid});

  @override
  State<OwnerNoteScreen> createState() => _OwnerNoteScreenState();
}

class _OwnerNoteScreenState extends State<OwnerNoteScreen> {
  final form = GlobalKey<FormState>();
  final description = TextEditingController();
  LatLng? location;
  Uint8List? photo;
  bool busy = false;
  String? signature, sendKey;

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    if (location != null && !validLocation(location)) {
      feedback(context, 'Elige una ubicación válida o quítala para continuar.');
      return;
    }
    final body = <String, dynamic>{
      'descripcion': description.text.trim(),
      if (location != null) ...{
        'latitud': location!.latitude,
        'longitud': location!.longitude,
      },
      if (photo != null) 'foto_base64': base64Encode(photo!),
    };
    // Retry an unchanged submission with the same UUID after a network failure.
    final current = jsonEncode(body);
    if (signature != current) {
      signature = current;
      sendKey = const Uuid().v4();
    }
    body['clave_envio'] = sendKey;
    setState(() => busy = true);
    try {
      await widget.session.api.request(
        '/mis-casos/${widget.cid}/antecedentes',
        method: 'POST',
        body: body,
      );
      if (!mounted) return;
      feedback(context, 'Antecedente privado guardado para revisión.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Antecedente privado')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionTitle('Agregar información a mi caso'),
        const Note(
          'Comparte novedades con el equipo que revisa tu caso. El relato, la foto y la ubicación se guardan de forma privada.',
        ),
        Panel(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FormSection(
                  'Qué necesitas agregar',
                  icon: Icons.notes_rounded,
                ),
                TextFormField(
                  controller: description,
                  enabled: !busy,
                  minLines: 4,
                  maxLines: 7,
                  maxLength: 3000,
                  decoration: const InputDecoration(
                    labelText: 'Descripción del antecedente',
                    hintText:
                        'Indica qué cambió o qué información nueva tienes.',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v?.trim().length ?? 0) < 10
                      ? 'Describe el antecedente en al menos 10 caracteres.'
                      : (v!.trim().length > 3000
                            ? 'Usa hasta 3000 caracteres.'
                            : null),
                ),
                gap(),
                const FormSection(
                  'Foto y lugar (opcionales)',
                  icon: Icons.add_photo_alternate_outlined,
                ),
                FotoAporte(
                  foto: photo,
                  ocupado: busy,
                  cambiar: (value) => setState(() => photo = value),
                ),
                gap(),
                LocationPicker(
                  value: location,
                  center: widget.session.centroZonal,
                  enabled: !busy,
                  requiredLocation: false,
                  onChanged: (value) => setState(() => location = value),
                ),
                gap(24),
                FilledButton.icon(
                  onPressed: busy ? null : save,
                  icon: const Icon(Icons.lock_outline),
                  label: Text(
                    busy ? 'Guardando…' : 'Guardar antecedente privado',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
