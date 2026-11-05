import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as m;
import 'package:latlong2/latlong.dart';

import 'session.dart';
import 'ui.dart';

class MapScreen extends StatefulWidget {
  final Session session;
  final VoidCallback usePoint;
  const MapScreen({super.key, required this.session, required this.usePoint});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  m.MapLibreMapController? controller;
  bool open = false, ready = false, perspective = true;
  LatLng? point;
  Future<void> updates = Future.value();
  static const style = 'assets/mapa_azul.json';
  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    sync();
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
        'properties': {'color': '#2867d8'},
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
    try {
      await controller!.addGeoJsonSource('mis-reportes', features());
      await controller!.addCircleLayer(
        'mis-reportes',
        'puntos-privados',
        const m.CircleLayerProperties(
          circleColor: ['get', 'color'],
          circleRadius: 8,
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 3,
        ),
      );
      if (mounted) setState(() => ready = true);
    } catch (_) {
      if (mounted) {
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
                    gradient: const LinearGradient(colors: [navy, teal]),
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
                    color: navy,
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Tu ciudad en perspectiva',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: navy,
                  ),
                ),
              ),
              FilledButton.tonal(
                onPressed: controller == null ? null : changeView,
                child: Text(perspective ? 'Ver en 2D' : 'Ver en 3D'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: controller == null
                      ? null
                      : () => fly(-36.827, -73.05),
                  child: const Text('Concepción'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: controller == null
                      ? null
                      : () => fly(-33.45, -70.66),
                  child: const Text('Santiago'),
                ),
              ),
              IconButton(
                tooltip: 'Mis reportes',
                onPressed: controller == null
                    ? null
                    : () {
                        final c = widget.session.cases
                            .where(
                              (c) =>
                                  c['latitud'] != null && c['longitud'] != null,
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
                      },
                icon: const Icon(Icons.center_focus_strong),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  m.MapLibreMap(
                    styleString: style,
                    initialCameraPosition: const m.CameraPosition(
                      target: m.LatLng(-36.827, -73.05),
                      zoom: 16,
                      tilt: 55,
                      bearing: -20,
                    ),
                    myLocationEnabled: false,
                    compassEnabled: true,
                    tiltGesturesEnabled: true,
                    rotateGesturesEnabled: true,
                    trackCameraPosition: true,
                    onMapCreated: (c) => setState(() => controller = c),
                    onStyleLoadedCallback: loaded,
                    onMapClick: (_, p) {
                      setState(() => point = LatLng(p.latitude, p.longitude));
                      sync();
                    },
                  ),
                  Positioned(
                    right: 12,
                    top: 72,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 4,
                      child: Column(
                        children: [
                          IconButton(
                            tooltip: 'Acercar',
                            onPressed: () => controller?.animateCamera(
                              m.CameraUpdate.zoomIn(),
                            ),
                            icon: const Icon(Icons.add, color: teal),
                          ),
                          IconButton(
                            tooltip: 'Alejar',
                            onPressed: () => controller?.animateCamera(
                              m.CameraUpdate.zoomOut(),
                            ),
                            icon: const Icon(Icons.remove, color: teal),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                point == null
                    ? 'Toca un lugar para ubicar el incidente.'
                    : '${point!.latitude.toStringAsFixed(5)}, ${point!.longitude.toStringAsFixed(5)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              gap(10),
              FilledButton.icon(
                onPressed: point == null
                    ? null
                    : () {
                        widget.session.selectPoint(point!);
                        widget.usePoint();
                      },
                icon: const Icon(Icons.check),
                label: const Text('Usar esta ubicación'),
              ),
              const Note(
                'Verde: selección · Naranja: tus reportes privados. Edificios según cobertura cartográfica.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
