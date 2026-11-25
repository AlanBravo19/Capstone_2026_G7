import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'movilidad.dart' show Mobility;
import 'ui.dart';

bool validLocation(LatLng? point) =>
    point != null &&
    point.latitude.isFinite &&
    point.longitude.isFinite &&
    point.latitude.abs() <= 90 &&
    point.longitude.abs() <= 180;

/// Shared street map for the home preview, zonal view and location picker.
/// Supplying onSelected enables explicit location selection; browsing never does.
class RutaMap extends StatelessWidget {
  final MapController controller;
  final LatLng center;
  final double zoom;
  final bool interactive;
  final ValueChanged<LatLng>? onSelected;
  final List<Marker> markers;
  final List<CircleMarker> circles;
  const RutaMap({
    super.key,
    required this.controller,
    required this.center,
    this.zoom = 12,
    this.interactive = true,
    this.onSelected,
    this.markers = const [],
    this.circles = const [],
  });

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      FlutterMap(
        mapController: controller,
        options: MapOptions(
          backgroundColor: const Color(0xff0b1d32),
          initialCenter: center,
          initialZoom: zoom,
          onTap: onSelected == null ? null : (_, point) => onSelected!(point),
          interactionOptions: InteractionOptions(
            flags: interactive
                ? InteractiveFlag.all & ~InteractiveFlag.rotate
                : InteractiveFlag.none,
          ),
        ),
        children: [
          ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              -.19,
              -.06,
              -.025,
              0,
              86,
              -.21,
              -.08,
              -.045,
              0,
              115,
              -.22,
              -.10,
              -.06,
              0,
              150,
              0,
              0,
              0,
              1,
              0,
            ]),
            child: TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'cl.rutaalerta.rutaalerta_movil',
              maxNativeZoom: 19,
            ),
          ),
          CircleLayer(circles: circles),
          MarkerLayer(markers: markers),
        ],
      ),
      Positioned(
        left: 8,
        bottom: 7,
        child: Material(
          color: const Color(0xff102a46),
          borderRadius: BorderRadius.circular(5),
          child: InkWell(
            onTap: () async {
              try {
                await const MethodChannel('cl.rutaalerta/trayecto')
                    .invokeMethod<void>('openAttribution');
              } catch (e) {
                if (context.mounted) feedback(context, e);
              }
            },
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Text(
                '© OpenStreetMap',
                style: TextStyle(fontSize: 10, color: Color(0xffddebff)),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class LocationPicker extends StatefulWidget {
  final LatLng? value;
  final LatLng? center;
  final ValueChanged<LatLng?> onChanged;
  final bool enabled;
  final bool requiredLocation;
  const LocationPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.center,
    this.enabled = true,
    this.requiredLocation = true,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  bool locating = false;

  Future<void> locate() async {
    setState(() => locating = true);
    try {
      final fix = await Mobility.location();
      final point = LatLng(
        (fix['lat'] as num).toDouble(),
        (fix['lon'] as num).toDouble(),
      );
      if (!validLocation(point)) {
        throw Exception('No se obtuvo una ubicación válida.');
      }
      if (mounted && widget.enabled) widget.onChanged(point);
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Icon(
            validLocation(widget.value)
                ? Icons.location_on
                : Icons.location_off_outlined,
            color: teal,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              validLocation(widget.value)
                  ? 'Lugar seleccionado'
                  : 'Ubicación sin seleccionar',
              style: const TextStyle(color: navy, fontWeight: FontWeight.w700),
            ),
          ),
          if (widget.value != null)
            IconButton(
              tooltip: 'Quitar ubicación',
              onPressed: widget.enabled && !locating
                  ? () => widget.onChanged(null)
                  : null,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      Note(
        widget.requiredLocation
            ? 'Marca el lugar del hecho. Usa el GPS si todavía estás allí.'
            : 'Opcional. Marca un lugar solo si aporta información a este antecedente.',
      ),
      OutlinedButton.icon(
        onPressed: !widget.enabled || locating
            ? null
            : () async {
                final point = await Navigator.of(context).push<LatLng>(
                  MaterialPageRoute(
                    builder: (_) => _LocationMapPage(
                      initial: widget.value,
                      center: widget.center,
                    ),
                  ),
                );
                if (mounted && widget.enabled && point != null) {
                  widget.onChanged(point);
                }
              },
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(
          widget.value == null
              ? 'Elegir lugar en el mapa'
              : 'Cambiar lugar en el mapa',
        ),
      ),
      OutlinedButton.icon(
        onPressed: !widget.enabled || locating ? null : locate,
        icon: const Icon(Icons.my_location),
        label: Text(
          locating ? 'Buscando ubicación…' : 'Usar mi ubicación actual',
        ),
      ),
    ],
  );
}

class _LocationMapPage extends StatefulWidget {
  final LatLng? initial, center;
  const _LocationMapPage({this.initial, this.center});
  @override
  State<_LocationMapPage> createState() => _LocationMapPageState();
}

class _LocationMapPageState extends State<_LocationMapPage> {
  final controller = MapController();
  late LatLng? point = widget.initial;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Elegir el lugar')),
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Acerca el mapa y toca la calle o el lugar exacto. Mover el mapa no selecciona una ubicación.',
            ),
          ),
          Expanded(
            child: RutaMap(
              controller: controller,
              center:
                  widget.initial ??
                  widget.center ??
                  const LatLng(-36.606, -72.104),
              zoom: widget.initial == null ? 13 : 16,
              onSelected: (value) => setState(() => point = value),
              markers: [
                if (point != null)
                  Marker(
                    point: point!,
                    width: 48,
                    height: 48,
                    child: const Icon(Icons.location_on, color: teal, size: 44),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: validLocation(point)
                    ? () => Navigator.pop(context, point)
                    : null,
                icon: const Icon(Icons.check),
                label: Text(
                  point == null
                      ? 'Toca el mapa para marcar el lugar'
                      : 'Usar este lugar',
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
