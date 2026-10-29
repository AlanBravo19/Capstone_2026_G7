import 'dart:async';

import 'package:flutter/material.dart';

import 'trip.dart';
import 'ui.dart';

class TripScreen extends StatefulWidget {
  const TripScreen({super.key});
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
          'RutaAlerta utilizará la ubicación mientras el trayecto esté activo, incluso si abres Waze u otra app. Verás una notificación y podrás detenerlo desde allí.\n\nLa ubicación permanece en memoria en este teléfono; no se envía a la plataforma. Esta versión todavía no emite avisos por antecedentes históricos. No ofrece seguimiento del vehículo robado.',
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
      await TripService.start();
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
          eyebrow: 'Android · base de ubicación',
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
                'Servicio Android visible y control manual de ubicación. No lee la ruta de Waze. No hay avisos territoriales, predicción ni rastreo de vehículos. Su continuidad depende de los permisos y restricciones del teléfono.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
