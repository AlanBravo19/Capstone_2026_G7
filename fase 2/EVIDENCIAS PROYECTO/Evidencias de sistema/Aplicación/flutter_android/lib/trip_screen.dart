import 'dart:async';

import 'package:flutter/material.dart';

import 'trip.dart';
import 'ui.dart';
import 'session.dart';
import 'movilidad.dart';

class TripScreen extends StatefulWidget {
  final Session? session;
  const TripScreen({super.key, this.session});
  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> with WidgetsBindingObserver {
  Map<String, dynamic> status = {'running': false};
  Timer? timer;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    timer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh();
      timer ??= Timer.periodic(const Duration(seconds: 3), (_) => refresh());
    } else {
      timer?.cancel();
      timer = null;
    }
  }

  Future<void> refresh() async {
    try {
      final s = await TripService.status();
      if (mounted) setState(() => status = s);
    } catch (_) {
      if (mounted) {
        setState(
          () => status = {
            'running': false,
            'error': 'El modo trayecto está disponible en Android.',
          },
        );
      }
    }
  }

  Future<void> start() async {
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Iniciar trayecto'),
        content: const Text(
          'RutaAlerta utilizará la ubicación mientras el trayecto esté activo, incluso si abres Waze u otra app. Verás una notificación y podrás detenerlo desde allí.\n\nLa ubicación permanece en memoria en este teléfono; no se envía a la plataforma. Se consultará una vez el área actual para descargar antecedentes revisados; los avisos de cercanía se calculan después en este teléfono por hasta dos horas. No se lee la ruta de Waze ni se envía un historial continuo de ubicación. No ofrece seguimiento del vehículo robado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (consent != true || !mounted) return;
    setState(() => busy = true);
    try {
      List<dynamic> notices = [];
      DateTime? expiry;
      if (widget.session != null) {
        try {
          final p = await Mobility.location();
          final r = await widget.session!.api.request(
            '/territorio/avisos/descargar',
            method: 'POST',
            body: {
              'latitud': double.parse((p['lat'] as num).toStringAsFixed(2)),
              'longitud': double.parse((p['lon'] as num).toStringAsFixed(2)),
            },
          );
          notices = r['avisos'] as List;
          expiry = DateTime.tryParse(r['cache_hasta'] as String);
        } catch (_) {
          if (mounted) {
            feedback(
              context,
              'No se descargaron antecedentes. El trayecto puede continuar sin avisos.',
            );
          }
        }
      }
      await TripService.start(avisos: notices, cacheHasta: expiry);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await refresh();
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> stop() async {
    setState(() => busy = true);
    try {
      await TripService.stop();
      await refresh();
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final running = status['running'] == true;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionTitle(
          'Modo trayecto',
          eyebrow: 'Android · ubicación y antecedentes',
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 145,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [navy, teal]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: Colors.white,
                  size: 75,
                ),
              ),
              gap(20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      running
                          ? 'Trayecto activo'
                          : 'Tú decides cuándo comenzar',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: navy,
                      ),
                    ),
                  ),
                  StateChip(running ? 'Activo' : 'Detenido'),
                ],
              ),
              gap(),
              const Text(
                'Puedes abrir Waze mientras el servicio de ubicación de RutaAlerta permanece activo. Detén el trayecto cuando termines.',
                style: TextStyle(color: muted),
              ),
              gap(),
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : running
                    ? stop
                    : start,
                icon: Icon(
                  running
                      ? Icons.stop_circle_outlined
                      : Icons.play_arrow_rounded,
                ),
                label: Text(
                  busy
                      ? 'Espera…'
                      : running
                      ? 'Detener trayecto'
                      : 'Iniciar trayecto',
                ),
              ),
              if (running)
                Note(
                  'Antecedentes descargados: ${status['noticeCount'] ?? 0}. ${((status['noticeCount'] ?? 0) as num) == 0 ? 'No hay avisos disponibles para este trayecto.' : 'Se avisará al acercarte a un sector revisado mientras el caché esté vigente.'}',
                ),
              if (status['lat'] != null)
                Note(
                  'Última ubicación del dispositivo: ${(status['lat'] as num).toStringAsFixed(5)}, ${(status['lng'] as num).toStringAsFixed(5)}. Precisión aproximada: ${status['accuracy']} m.',
                ),
              if (running && status['lat'] == null)
                const Note(
                  'Esperando una posición del dispositivo. El GPS puede tardar o no estar disponible en interiores.',
                ),
              if (status['error'] != null) Note('${status['error']}'),
            ],
          ),
        ),
        const Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Qué incluye esta versión',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              Note(
                'Los avisos se basan sólo en antecedentes revisados descargados al iniciar: no son delitos en curso ni predicción. El caché vence en un máximo de dos horas; fuera del área descargada pueden faltar antecedentes. No lee Waze ni rastrea vehículos. Depende del GPS, permisos y batería.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
