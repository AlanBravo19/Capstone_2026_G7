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
  bool voz = true;
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
          'RutaAlerta usa el GPS mientras el trayecto está activo, incluso con otra app abierta o la pantalla apagada. Puedes detenerlo desde la notificación.\n\nAl iniciar se consulta un área aproximada de 30 km. Luego el teléfono calcula la cercanía a las zonas descargadas durante un máximo de dos horas.',
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
      List<dynamic>? zonas;
      DateTime? expiry;
      var ensayo = false;
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
          zonas = r['zonas'] as List?;
          expiry = DateTime.tryParse(r['cache_hasta'] as String);
          ensayo = r['simulacion'] == true;
        } catch (_) {
          if (mounted) {
            feedback(
              context,
              'No se descargaron antecedentes. El trayecto puede continuar sin avisos.',
            );
          }
        }
      }
      await TripService.start(
        avisos: notices,
        zonas: zonas,
        cacheHasta: expiry,
        voz: voz,
        ensayo: ensayo,
      );
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
    return Scaffold(
      appBar: AppBar(title: const Text('Modo trayecto')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          running ? 'Trayecto activo' : 'Listo para salir',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: ink,
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
                  if (!running)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Avisos por voz'),
                      subtitle: const Text(
                        'Al acercarte a zonas con antecedentes de encerronas.',
                      ),
                      secondary: const Icon(Icons.volume_up_outlined),
                      value: voz,
                      onChanged: busy
                          ? null
                          : (value) => setState(() => voz = value),
                    ),
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
                      '${status['noticeCount'] ?? 0} ${status['grouped'] == true ? 'zonas descargadas' : 'antecedentes descargados'} · Área inicial de 30 km.',
                    ),
                  if (running && status['voiceState'] != 'off')
                    Note(switch (status['voiceState']) {
                      'ready' => 'Voz en español disponible.',
                      'unavailable' => 'Voz no disponible. Instala una voz en español sin conexión desde los ajustes de Android. Las notificaciones siguen activas.',
                      _ => 'Preparando la voz del teléfono…',
                    }),
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
                    'Avisos durante el trayecto',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                  Note(
                    'Los avisos usan antecedentes revisados del último año. Para consultar nuevas zonas, inicia otro trayecto cuando estés estacionado. Ajusta el volumen antes de salir.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
