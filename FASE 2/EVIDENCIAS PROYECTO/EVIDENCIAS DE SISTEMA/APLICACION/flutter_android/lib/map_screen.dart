import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as m;
import 'package:latlong2/latlong.dart';

import 'session.dart';
import 'ui.dart';

class MapScreen extends StatefulWidget {
  final Session session;
  final VoidCallback usePoint;
  final bool active;
  const MapScreen({
    super.key,
    required this.session,
    required this.usePoint,
    this.active = true,
  });
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  m.MapLibreMapController? controller;
  m.CameraPosition? lastCamera;
  late List<Map<String, dynamic>> lastCases;
  bool open = false, ready = false, perspective = true;
  LatLng? point;
  Future<void> updates = Future.value();
  static const style = 'assets/mapa_azul.json';
  static const gpsChannel = MethodChannel('cl.rutaalerta/trayecto');
  bool gps = false, foreground = true, requestingGps = false, follow = true;
  m.UserLocation? currentLocation;
  Timer? clock;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    lastCases = widget.session.cases;
  }

  @override
  void dispose() {
    clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() {
      foreground = state == AppLifecycleState.resumed;
      currentLocation = null;
    });
    if (foreground && gps) checkPermission();
  }

  Future<void> checkPermission() async {
    try {
      final allowed = await gpsChannel.invokeMethod<bool>('mapLocationAllowed');
      if (mounted && allowed != true) {
        setState(() {
          gps = false;
          currentLocation = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          gps = false;
          currentLocation = null;
        });
      }
    }
  }

  Future<void> locate() async {
    if (requestingGps) return;
    setState(() => requestingGps = true);
    try {
      final allowed = await gpsChannel.invokeMethod<bool>('requestMapLocation');
      if (!mounted) return;
      if (allowed != true) {
        setState(() {
          gps = false;
          currentLocation = null;
        });
        feedback(
          context,
          'Autoriza la ubicación en los ajustes de Android para ver tu GPS.',
        );
        return;
      }
      setState(() {
        gps = true;
        follow = true;
        point = null;
      });
      sync();
      if (hasRecentFix) {
        await fly(
          currentLocation!.position.latitude,
          currentLocation!.position.longitude,
        );
      }
    } catch (_) {
      if (mounted) {
        feedback(
          context,
          'No se pudo activar la ubicación. Revisa el permiso y el GPS del teléfono.',
        );
      }
    } finally {
      if (mounted) setState(() => requestingGps = false);
    }
  }

  void receiveLocation(m.UserLocation fix) {
    if (!mounted || !gps || !widget.active || !foreground) return;
    final previous = currentLocation;
    if (previous != null && !fix.timestamp.isAfter(previous.timestamp)) return;
    final wasFresh = hasRecentFix;
    currentLocation = fix;
    clock?.cancel();
    if (hasRecentFix) {
      clock = Timer(
        fix.timestamp
            .add(const Duration(seconds: 30))
            .difference(DateTime.now()),
        () {
          if (mounted && gps && widget.active && foreground) setState(() {});
        },
      );
      if (follow && (previous == null || previous.position != fix.position)) {
        controller?.moveCamera(m.CameraUpdate.newLatLng(fix.position));
      }
    }
    if (wasFresh != hasRecentFix || previous == null) setState(() {});
  }

  bool get hasRecentFix {
    final fix = currentLocation;
    if (!gps || !foreground || !widget.active || fix == null) return false;
    final age = DateTime.now().difference(fix.timestamp);
    return age >= const Duration(seconds: -5) &&
        age < const Duration(seconds: 30);
  }

  void useLocation() {
    final fix = currentLocation;
    if (point != null) {
      widget.session.selectPoint(point!);
    } else if (hasRecentFix && fix != null) {
      widget.session.selectPoint(
        LatLng(fix.position.latitude, fix.position.longitude),
      );
    } else {
      feedback(
        context,
        'Estamos esperando una ubicación reciente del teléfono.',
      );
      return;
    }
    widget.usePoint();
  }

  String gpsStatus() {
    if (!gps) {
      return 'GPS desactivado. Actívalo para ver la ubicación de este teléfono.';
    }
    if (currentLocation == null) {
      return 'Buscando señal. Activa la ubicación del teléfono y espera una posición.';
    }
    final age = DateTime.now()
        .difference(currentLocation!.timestamp)
        .inSeconds
        .clamp(0, 86400);
    final accuracy = currentLocation!.horizontalAccuracy;
    return '${age > 30 ? 'Última posición, sin actualización reciente' : 'GPS del teléfono'} · ${accuracy == null ? 'precisión no disponible' : '± ${accuracy.round()} m'} · hace ${age}s';
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && oldWidget.active) {
      lastCamera = controller?.cameraPosition ?? lastCamera;
      currentLocation = null;
      clock?.cancel();
      ready = false;
      controller = null;
    }
    if (widget.active && !oldWidget.active && gps) checkPermission();
    if (!identical(lastCases, widget.session.cases)) {
      lastCases = widget.session.cases;
      if (widget.active) sync();
    }
  }

  Map<String, dynamic> features() {
    final points = <Map<String, dynamic>>[];
    for (final c in widget.session.cases) {
      final lat = (c['latitud'] as num?)?.toDouble(),
          lng = (c['longitud'] as num?)?.toDouble();
      if (lat == null ||
          lng == null ||
          !lat.isFinite ||
          !lng.isFinite ||
          lat.abs() > 90 ||
          lng.abs() > 180) {
        continue;
      }
      points.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [lng, lat],
        },
        'properties': {'color': '#526f9a', 'folio': c['folio']},
      });
    }
    if (point != null) {
      points.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [point!.longitude, point!.latitude],
        },
        'properties': {'color': '#10213c'},
      });
    }
    return {'type': 'FeatureCollection', 'features': points};
  }

  void sync() {
    if (!ready || controller == null) return;
    updates = updates
        .then((_) async {
          if (mounted && ready) {
            await controller?.setGeoJsonSource('mis-reportes', features());
          }
        })
        .catchError((Object e) {
          if (mounted) {
            feedback(context, 'No se pudieron actualizar los puntos del mapa.');
          }
        });
  }

  Future<void> loaded() async {
    final map = controller;
    if (map == null || !widget.active) return;
    try {
      await map.addGeoJsonSource('mis-reportes', features());
      if (!mounted || controller != map) return;
      await map.addCircleLayer(
        'mis-reportes',
        'puntos-privados',
        const m.CircleLayerProperties(
          circleColor: ['get', 'color'],
          circleRadius: 8,
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 3,
        ),
      );
      if (mounted && controller == map) {
        ready = true;
        sync();
      }
    } catch (_) {
      if (mounted && controller == map) {
        feedback(
          context,
          'No se pudieron cargar los puntos. Puedes continuar con coordenadas manuales.',
        );
      }
    }
  }

  Future<void> fly(double lat, double lng) async {
    await controller?.animateCamera(
      m.CameraUpdate.newCameraPosition(
        m.CameraPosition(
          target: m.LatLng(lat, lng),
          zoom: 16,
          tilt: perspective ? 55 : 0,
          bearing: -20,
        ),
      ),
    );
  }

  Future<void> changeView() async {
    final c = controller?.cameraPosition;
    if (c == null) return;
    setState(() => perspective = !perspective);
    await controller?.animateCamera(
      m.CameraUpdate.newCameraPosition(
        m.CameraPosition(
          target: c.target,
          zoom: c.zoom,
          tilt: perspective ? 55 : 0,
          bearing: perspective ? -20 : 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    if (!open) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionTitle(
            'Tu ciudad en 3D',
            eyebrow: 'Mapa de reportes privados',
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [navy, Color(0xff294873)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.location_city_rounded,
                    size: 90,
                    color: Colors.white,
                  ),
                ),
                gap(20),
                const Text(
                  'Explora calles y edificios con perspectiva.',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                gap(12),
                const Text(
                  'Gira, inclina y acerca el mapa. Toca el lugar del incidente para usarlo en tu reporte.',
                  style: TextStyle(color: muted),
                ),
                gap(20),
                FilledButton.icon(
                  onPressed: () => setState(() => open = true),
                  icon: const Icon(Icons.view_in_ar_rounded),
                  label: const Text('Explorar mapa 3D'),
                ),
                const Note(
                  'Los edificios se muestran donde existen datos cartográficos. Sus alturas pueden ser aproximadas; no son imágenes de cámaras ni información en vivo. OpenFreeMap recibe tu IP y el área consultada; los textos de tus reportes permanecen en la plataforma.',
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              m.MapLibreMap(
                styleString: style,
                initialCameraPosition:
                    lastCamera ??
                    const m.CameraPosition(
                      target: m.LatLng(-36.827, -73.05),
                      zoom: 16,
                      tilt: 55,
                      bearing: -20,
                    ),
                myLocationEnabled: gps && widget.active && foreground,
                onUserLocationUpdated: receiveLocation,
                compassEnabled: true,
                tiltGesturesEnabled: true,
                rotateGesturesEnabled: true,
                trackCameraPosition: true,
                onMapCreated: (c) => setState(() => controller = c),
                onStyleLoadedCallback: loaded,
                onMapClick: (_, p) {
                  setState(() {
                    point = LatLng(p.latitude, p.longitude);
                    follow = false;
                  });
                  sync();
                },
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: const Color(0xf5ffffff),
                  elevation: 2,
                  borderRadius: BorderRadius.circular(18),
                  child: Wrap(
                    direction: Axis.vertical,
                    children: [
                      IconButton(
                        tooltip: 'Mi ubicación',
                        onPressed: requestingGps ? null : locate,
                        icon: Icon(
                          gps ? Icons.gps_fixed : Icons.my_location,
                          color: teal,
                        ),
                      ),
                      IconButton(
                        tooltip: perspective ? 'Ver en 2D' : 'Ver en 3D',
                        onPressed: controller == null ? null : changeView,
                        icon: Text(
                          perspective ? '2D' : '3D',
                          style: const TextStyle(
                            color: ink,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Más opciones de mapa',
                        icon: const Icon(Icons.more_horiz),
                        onSelected: (value) {
                          if (value == 'ocultar') {
                            setState(() {
                              gps = false;
                              currentLocation = null;
                              follow = false;
                            });
                            return;
                          }
                          if (value == 'gps') {
                            feedback(context, gpsStatus());
                            return;
                          }
                          setState(() => follow = false);
                          if (value == 'acercar') {
                            controller?.animateCamera(m.CameraUpdate.zoomIn());
                            return;
                          }
                          if (value == 'alejar') {
                            controller?.animateCamera(m.CameraUpdate.zoomOut());
                            return;
                          }
                          if (value == 'reportes') {
                            final c = widget.session.cases
                                .where(
                                  (c) =>
                                      c['latitud'] != null &&
                                      c['longitud'] != null,
                                )
                                .firstOrNull;
                            if (c == null) {
                              feedback(
                                context,
                                'Todavía no tienes reportes ubicados.',
                              );
                              return;
                            }
                            fly(
                              (c['latitud'] as num).toDouble(),
                              (c['longitud'] as num).toDouble(),
                            );
                            return;
                          }
                          final p = {
                            'Chillán': [-36.606, -72.104],
                            'Concepción': [-36.827, -73.05],
                            'Santiago': [-33.45, -70.66],
                          }[value];
                          if (p != null) fly(p[0], p[1]);
                        },
                        itemBuilder: (_) => [
                          for (final city in [
                            'Chillán',
                            'Concepción',
                            'Santiago',
                          ])
                            PopupMenuItem(value: city, child: Text(city)),
                          const PopupMenuItem(
                            value: 'reportes',
                            child: Text('Mis reportes'),
                          ),
                          const PopupMenuItem(
                            value: 'acercar',
                            child: Text('Acercar'),
                          ),
                          const PopupMenuItem(
                            value: 'alejar',
                            child: Text('Alejar'),
                          ),
                          const PopupMenuItem(
                            value: 'gps',
                            child: Text('Estado del GPS'),
                          ),
                          if (gps)
                            const PopupMenuItem(
                              value: 'ocultar',
                              child: Text('Ocultar GPS'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.place_outlined, color: teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    point != null
                        ? 'Lugar marcado en el mapa.'
                        : gps
                        ? (hasRecentFix
                              ? 'Ubicación actual del teléfono.'
                              : 'Esperando una señal GPS reciente…')
                        : 'Activa Mi ubicación o marca un punto.',
                  ),
                ),
                if (point != null || gps)
                  FilledButton(
                    onPressed: point != null || hasRecentFix
                        ? useLocation
                        : null,
                    child: Text(point != null ? 'Usar punto' : 'Usar mi GPS'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
