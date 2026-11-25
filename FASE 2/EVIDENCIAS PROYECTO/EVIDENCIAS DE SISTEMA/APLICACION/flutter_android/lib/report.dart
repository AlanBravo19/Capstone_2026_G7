import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'foto_aporte.dart';
import 'case_photos.dart';

import 'session.dart';
import 'location_picker.dart';
import 'commune_picker.dart';
import 'movilidad.dart' show Mobility;

import 'package:latlong2/latlong.dart';

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
  final zone = TextEditingController(), description = TextEditingController();
  int? vehicle;
  int? organization;
  String? commune;
  List<String> suggestedCommunes = [];
  int locationRequest = 0;
  late Future<List<dynamic>> recipients;
  Future<List<dynamic>> loadRecipients() async =>
      await widget.session.api.request('/organizaciones') as List<dynamic>;
  bool busy = false;
  Uint8List? foto;
  bool colaborar = false;
  bool confirmaSustraccion = false;
  bool autorizarFotoPublica = false;
  LatLng? appliedPoint;
  DateTime date = DateTime.now();
  @override
  void initState() {
    super.initState();
    recipients = loadRecipients();
    syncPoint();
  }

  @override
  void didUpdateWidget(covariant ReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncPoint();
    if (!widget.session.vehicles.any((v) => v['id_vehiculo'] == vehicle)) {
      vehicle = null;
    }
  }

  void syncPoint() {
    final p = widget.session.selectedPoint;
    if (p != null) appliedPoint = p;
  }

  Future<void> useIncidentPoint(LatLng? point) async {
    final call = ++locationRequest;
    setState(() {
      appliedPoint = point;
      suggestedCommunes = [];
    });
    widget.session.selectedPoint = point;
    if (point == null || commune != null) return;
    try {
      final names = await Mobility.channel.invokeListMethod<String>(
        'reverseGeocode',
        {'lat': point.latitude, 'lon': point.longitude},
      );
      if (mounted && call == locationRequest) {
        setState(() => suggestedCommunes = names ?? []);
      }
    } catch (_) {
      // El punto sigue disponible aunque el proveedor no sugiera una comuna.
    }
  }

  @override
  void dispose() {
    for (final c in [zone, description]) {
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
    if (busy) return;
    if (!form.currentState!.validate()) return;
    if (!confirmaSustraccion) {
      feedback(context, 'Confirma que reportas una sustracción real.');
      return;
    }
    if (!validLocation(appliedPoint)) {
      feedback(
        context,
        'Selecciona el lugar en el mapa o usa tu ubicación actual.',
      );
      return;
    }
    if (date.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      feedback(context, 'La fecha del incidente no puede ser futura.');
      return;
    }
    setState(() => busy = true);
    try {
      final validated = await validatedZone(
        widget.session.api,
        commune,
        zone.text,
        appliedPoint!,
      );
      final receipt = await widget.session.reportReceipt({
        'id_vehiculo': vehicle,
        'id_organizacion': organization,
        'fecha_hecho': date.toUtc().toIso8601String(),
        'zona': validated,
        'descripcion': description.text.trim(),
        if (foto != null) 'foto_base64': base64Encode(foto!),
        'solicitar_colaboracion': colaborar,
        'confirmar_sustraccion': confirmaSustraccion,
        'autorizar_foto_publica':
            foto != null && colaborar && autorizarFotoPublica,
        'latitud': appliedPoint!.latitude,
        'longitud': appliedPoint!.longitude,
      });
      if (!mounted) return;
      zone.clear();
      description.clear();
      appliedPoint = null;
      widget.session.selectedPoint = null;
      ++locationRequest;
      setState(() {
        foto = null;
        colaborar = false;
        confirmaSustraccion = false;
        autorizarFotoPublica = false;
        vehicle = null;
        commune = null;
        suggestedCommunes = [];
        date = DateTime.now();
      });
      feedback(
        context,
        'Reporte ${receipt['folio']} recibido. ${receipt['siguiente_paso'] ?? 'Consulta el seguimiento del caso.'}',
      );
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
                'Si autorizas la colaboración, un vínculo vigente puede publicar una alerta provisional. La denuncia y el encargo se tramitan por el canal oficial.',
              ),
              const FormSection(
                'Vehículo y destinatario',
                icon: Icons.directions_car_outlined,
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
                onChanged: busy
                    ? null
                    : (v) => setState(() {
                        vehicle = v;
                        final selected = widget.session.vehicles.firstWhere(
                          (item) => item['id_vehiculo'] == v,
                          orElse: () => {},
                        );
                        final validUntil = DateTime.tryParse(
                          '${selected['vence_revision_en']}',
                        );
                        if (selected['estado_vinculo'] == 'autorizado' &&
                            validUntil != null &&
                            validUntil.isAfter(DateTime.now())) {
                          organization =
                              selected['id_organizacion_revision'] as int?;
                        }
                      }),
                validator: (v) => v == null ? 'Selecciona tu vehículo' : null,
              ),
              gap(),
              FutureBuilder<List<dynamic>>(
                future: recipients,
                builder: (context, result) {
                  if (result.hasError) {
                    return TextButton(
                      onPressed: () => setState(() {
                        recipients = loadRecipients();
                      }),
                      child: const Text('Reintentar carga de organizaciones'),
                    );
                  }
                  if (!result.hasData) return const LinearProgressIndicator();
                  return DropdownButtonFormField<int>(
                    key: ValueKey('receptora/$vehicle'),
                    initialValue:
                        result.data!.any(
                          (o) => o['id_organizacion'] == organization,
                        )
                        ? organization
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Organización que recibirá el reporte',
                    ),
                    items: [
                      for (final org in result.data!)
                        DropdownMenuItem<int>(
                          value: org['id_organizacion'] as int,
                          child: Text(org['nombre'] as String),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setState(() => organization = v),
                    validator: (v) => v == null
                        ? 'Selecciona quién revisará tu reporte'
                        : null,
                  );
                },
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
              const FormSection(
                'Lugar del incidente',
                icon: Icons.place_outlined,
              ),
              LocationPicker(
                value: appliedPoint,
                center: widget.session.centroZonal,
                enabled: !busy,
                onChanged: useIncidentPoint,
              ),
              gap(),
              CommunePicker(
                api: widget.session.api,
                value: commune,
                enabled: !busy,
                suggestions: suggestedCommunes,
                onChanged: (value) => setState(() => commune = value),
              ),
              gap(),
              TextFormField(
                controller: zone,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Calle o referencia (opcional)',
                  hintText: 'Ej. cruce, número o lugar cercano',
                  prefixIcon: Icon(Icons.signpost_outlined),
                ),
              ),
              gap(24),
              const FormSection(
                'Detalles del incidente',
                icon: Icons.notes_rounded,
              ),
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
              const Text(
                'Foto del reporte (opcional)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              FotoAporte(
                foto: foto,
                ocupado: busy,
                cambiar: (v) => setState(() {
                  foto = v;
                  autorizarFotoPublica = false;
                }),
              ),
              const Text(
                'Opcional. La foto queda como evidencia privada.',
                style: TextStyle(color: muted),
              ),
              CheckboxListTile(
                value: confirmaSustraccion,
                onChanged: busy
                    ? null
                    : (v) => setState(() => confirmaSustraccion = v == true),
                contentPadding: EdgeInsets.zero,
                title: const Text('Declaro que reporto una sustracción real'),
                subtitle: const Text(
                  'El reporte ciudadano y la denuncia policial son trámites separados.',
                ),
              ),
              CheckboxListTile(
                value: colaborar,
                onChanged: busy
                    ? null
                    : (v) => setState(() {
                        colaborar = v == true;
                        if (!colaborar) autorizarFotoPublica = false;
                      }),
                contentPadding: EdgeInsets.zero,
                title: const Text('Solicitar colaboración ciudadana'),
                subtitle: const Text(
                  'Autorizo publicar patente, características y sector aproximado. RutaAlerta mostrará el estado de la revisión.',
                ),
              ),
              if (foto != null && colaborar)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: autorizarFotoPublica,
                  onChanged: busy
                      ? null
                      : (v) => setState(() => autorizarFotoPublica = v == true),
                  title: const Text(publicPhotoConsentText),
                  subtitle: const Text(publicPhotoReviewText),
                ),
              FilledButton.icon(
                onPressed:
                    busy || !widget.session.canReport || organization == null
                    ? null
                    : save,
                icon: const Icon(Icons.send_outlined),
                label: Text(busy ? 'Guardando…' : 'Enviar reporte'),
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
