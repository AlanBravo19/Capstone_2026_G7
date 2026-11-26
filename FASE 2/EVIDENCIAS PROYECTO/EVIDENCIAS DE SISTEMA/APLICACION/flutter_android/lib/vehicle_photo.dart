import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'api.dart';
import 'movilidad.dart' show Mobility;

/// No image URLs or credentials are passed to Flutter's network image cache.
class VehiclePhoto extends StatefulWidget {
  final RutaApi api;
  final int sid;
  final String? tipoVehiculo, modeloCompleto;
  final bool fotoDisponible;
  final String? fotoUrl, fotoVersion;
  final int? anio;
  final double height;

  const VehiclePhoto({
    super.key,
    required this.api,
    required this.sid,
    this.tipoVehiculo,
    this.modeloCompleto,
    this.fotoDisponible = false,
    this.fotoUrl,
    this.fotoVersion,
    this.anio,
    this.height = 180,
  });

  @override
  State<VehiclePhoto> createState() => _VehiclePhotoState();
}

class _VehiclePhotoState extends State<VehiclePhoto> {
  Future<Uint8List>? _photo;
  late String _session;
  bool _showExample = false;

  void _load() {
    _showExample = false;
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
    if (oldWidget.api != widget.api ||
        oldWidget.sid != widget.sid ||
        oldWidget.fotoDisponible != widget.fotoDisponible ||
        oldWidget.fotoUrl != widget.fotoUrl ||
        oldWidget.modeloCompleto != widget.modeloCompleto ||
        oldWidget.fotoVersion != widget.fotoVersion ||
        _session != widget.api.token) {
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
        key: ValueKey((
          widget.api,
          widget.sid,
          widget.fotoDisponible,
          widget.fotoUrl,
          widget.fotoVersion,
          _session,
        )),
        future: _photo,
        builder: (context, snapshot) {
          if (_photo != null &&
              snapshot.hasData &&
              _session == widget.api.token) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
              width: double.infinity,
              height: widget.height,
              semanticLabel: 'Foto autorizada del vehículo',
              errorBuilder: (_, _, _) => _fallback(),
            );
          }
          if (_photo != null && snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(semanticsLabel: 'Cargando foto del titular'));
          }
          return _fallback();
        },
      ),
    ),
  );

  Widget _fallback() {
    final (icon, label) = switch (widget.tipoVehiculo?.toLowerCase()) {
      'motocicleta' || 'moto' => (Icons.two_wheeler_rounded, 'Motocicleta'),
      'camion' || 'camión' => (Icons.local_shipping_rounded, 'Camión'),
      'camioneta' => (Icons.local_shipping_outlined, 'Camioneta'),
      'furgon' || 'furgón' => (Icons.airport_shuttle_rounded, 'Furgón'),
      'automovil' ||
      'automóvil' ||
      'auto' => (Icons.directions_car_rounded, 'Automóvil'),
      _ => (Icons.directions_car_rounded, 'Vehículo'),
    };
    final model = widget.modeloCompleto?.trim() ?? '';
    final hasExample = RegExp(r'^BMW\s+320(?:\s?I)?$', caseSensitive: false).hasMatch(model)
        && (widget.anio == null || (widget.anio! >= 2012 && widget.anio! <= 2018));
    if (_showExample && hasExample) {
      return Column(children: [
        Expanded(child: Image.asset('assets/bmw_320i_f30.jpg', fit: BoxFit.contain,
            semanticLabel: 'Ejemplo de catálogo, BMW 320i F30')),
        TextButton(onPressed: () => setState(() => _showExample = false),
            child: const Text('Cerrar ejemplo · BMW 320i F30')),
        InkWell(onTap: () async {
          try { await Mobility.source('https://commons.wikimedia.org/wiki/File:BMW_320i_(F30)_front.JPG'); }
          catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fuente no disponible.'))); }
        }, child: const Text('Tokumeigakarinoaoshima · CC BY-SA 4.0')),
      ]);
    }
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
          Icon(icon, size: 36, color: Colors.white),
          const SizedBox(height: 4),
          Text(
            model.isEmpty ? label : model,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sin foto pública del titular',
            style: TextStyle(color: Colors.white),
          ),
          if (hasExample) TextButton(
            onPressed: () => setState(() => _showExample = true),
            child: const Text('Ver BMW 320i F30 de ejemplo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
