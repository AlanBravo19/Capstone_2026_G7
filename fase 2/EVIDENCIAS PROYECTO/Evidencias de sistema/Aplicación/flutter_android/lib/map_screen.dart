import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
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
  final controller = MapController();
  bool open = false;
  LatLng? point;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  List<Marker> markers() {
    final result = <Marker>[];
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
      result.add(
        Marker(
          point: LatLng(lat, lng),
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('${c['folio']}'),
                content: Text(
                  '${c['zona']}\nEstado: ${c['estado']}\nEste reporte continúa siendo privado.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xffbf7545),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8),
                ],
              ),
              child: const Icon(
                Icons.directions_car_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      );
    }
    if (point != null) {
      result.add(
        Marker(
          point: point!,
          width: 48,
          height: 48,
          child: Container(
            decoration: BoxDecoration(
              color: teal,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Icon(Icons.location_on, color: Colors.white),
          ),
        ),
      );
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (!open) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionTitle(
            'Tu territorio',
            eyebrow: 'Mapa de reportes privados',
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 170,
                  decoration: BoxDecoration(
                    color: const Color(0xffe3f1eb),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.travel_explore_rounded,
                    size: 90,
                    color: teal,
                  ),
                ),
                gap(20),
                const Text(
                  'Cada reporte comienza con un lugar.',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: navy,
                  ),
                ),
                gap(10),
                const Text(
                  'Toca el mapa para elegir el lugar del incidente. Los puntos guardados pertenecen únicamente a tu cuenta.',
                  style: TextStyle(color: muted),
                ),
                gap(20),
                FilledButton.icon(
                  onPressed: () => setState(() => open = true),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Explorar mapa'),
                ),
                const Note(
                  'Al abrir el mapa, OpenStreetMap recibe tu IP y el área consultada. No recibe tus descripciones ni tus credenciales. No hay seguimiento automático ni capas de riesgo.',
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      controller.move(const LatLng(-36.827, -73.05), 12),
                  child: const Text('Concepción'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      controller.move(const LatLng(-33.45, -70.66), 12),
                  child: const Text('Santiago'),
                ),
              ),
              IconButton(
                tooltip: 'Ver mis reportes',
                onPressed: () {
                  final valid = widget.session.cases
                      .where(
                        (c) => c['latitud'] != null && c['longitud'] != null,
                      )
                      .toList();
                  if (valid.isEmpty) {
                    feedback(context, 'Todavía no tienes reportes ubicados.');
                    return;
                  }
                  controller.fitCamera(
                    CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(
                        valid
                            .map(
                              (c) => LatLng(
                                (c['latitud'] as num).toDouble(),
                                (c['longitud'] as num).toDouble(),
                              ),
                            )
                            .toList(),
                      ),
                      padding: const EdgeInsets.all(40),
                      maxZoom: 14,
                    ),
                  );
                },
                icon: const Icon(Icons.center_focus_strong_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: FlutterMap(
            mapController: controller,
            options: MapOptions(
              initialCenter: const LatLng(-36.827, -73.05),
              initialZoom: 12,
              minZoom: 3,
              maxZoom: 19,
              onTap: (_, p) => setState(
                () => point = LatLng(
                  p.latitude,
                  ((p.longitude + 180) % 360) - 180,
                ),
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'cl.rutaalerta.rutaalerta_movil',
                tileProvider: NetworkTileProvider(
                  headers: {
                    'User-Agent': 'RutaAlertaBeta/0.4 (+https://rutaalerta-mvp-g7.vercel.app/)',
                  },
                ),
                keepBuffer: 0,
              ),
              MarkerLayer(markers: markers()),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () async {
                      try {
                        await const MethodChannel('cl.rutaalerta/trayecto')
                            .invokeMethod<void>('openAttribution');
                      } catch (_) {
                        if (context.mounted) {
                          feedback(
                            context,
                            'https://www.openstreetmap.org/copyright',
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  point == null
                      ? 'Toca un lugar para ubicar el nuevo reporte.'
                      : '${point!.latitude.toStringAsFixed(5)}, ${point!.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: navy,
                  ),
                ),
                gap(10),
                FilledButton.icon(
                  onPressed: point == null
                      ? null
                      : () {
                          widget.session.selectPoint(point!);
                          widget.usePoint();
                        },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Usar esta ubicación'),
                ),
                const Text(
                  'Verde: selección · Naranja: tus reportes privados',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
