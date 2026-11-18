import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'api.dart';

/// No image URLs or credentials are passed to Flutter's network image cache.
class VehiclePhoto extends StatefulWidget {
  final RutaApi api;
  final int sid;
  final String? tipoVehiculo;
  final bool fotoDisponible;
  final String? fotoUrl;
  final double height;

  const VehiclePhoto({
    super.key,
    required this.api,
    required this.sid,
    this.tipoVehiculo,
    this.fotoDisponible = false,
    this.fotoUrl,
    this.height = 180,
  });

  @override
  State<VehiclePhoto> createState() => _VehiclePhotoState();
}

class _VehiclePhotoState extends State<VehiclePhoto> {
  Future<Uint8List>? _photo;
  late String _session;

  void _load() {
    _session = widget.api.token;
    _photo = widget.fotoDisponible ? widget.api.vehiclePhoto(widget.sid) : null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VehiclePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api || oldWidget.sid != widget.sid ||
        oldWidget.fotoDisponible != widget.fotoDisponible ||
        oldWidget.fotoUrl != widget.fotoUrl || _session != widget.api.token) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: SizedBox(
      height: widget.height,
      width: double.infinity,
      child: FutureBuilder<Uint8List>(
        key: ValueKey((widget.api, widget.sid, widget.fotoDisponible, widget.fotoUrl, _session)),
        future: _photo,
        builder: (context, snapshot) {
          if (_photo != null && snapshot.hasData && _session == widget.api.token) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: widget.height,
              semanticLabel: 'Foto autorizada del vehículo',
              errorBuilder: (_, _, _) => _reference(),
            );
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              _reference(),
              if (_photo != null && snapshot.connectionState != ConnectionState.done)
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: LinearProgressIndicator(minHeight: 3),
                ),
            ],
          );
        },
      ),
    ),
  );

  Widget _reference() {
    final (icon, label) = switch (widget.tipoVehiculo?.toLowerCase()) {
      'motocicleta' || 'moto' => (Icons.two_wheeler_rounded, 'Motocicleta'),
      'camion' || 'camión' => (Icons.local_shipping_rounded, 'Camión'),
      'camioneta' => (Icons.local_shipping_outlined, 'Camioneta'),
      'furgon' || 'furgón' => (Icons.airport_shuttle_rounded, 'Furgón'),
      'automovil' || 'automóvil' || 'auto' => (Icons.directions_car_rounded, 'Automóvil'),
      _ => (Icons.directions_car_rounded, 'Vehículo'),
    };
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF143E76), Color(0xFF227EC1), Color(0xFF60B9DF)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: Colors.white),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Imagen de referencia', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
