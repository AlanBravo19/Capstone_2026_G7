import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'api.dart';

class CommunePicker extends StatefulWidget {
  final RutaApi api;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  const CommunePicker({
    super.key,
    required this.api,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<CommunePicker> createState() => _CommunePickerState();
}

class _CommunePickerState extends State<CommunePicker> {
  late Future<dynamic> communes = widget.api.request('/catalogo/comunas');

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: communes,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return TextButton.icon(
          onPressed: widget.enabled
              ? () => setState(() {
                  communes = widget.api.request('/catalogo/comunas');
                })
              : null,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar carga de comunas'),
        );
      }
      if (!snapshot.hasData) return const LinearProgressIndicator();
      return DropdownButtonFormField<String>(
        key: ValueKey(widget.value),
        initialValue: widget.value,
        isExpanded: true,
        menuMaxHeight: 360,
        decoration: const InputDecoration(
          labelText: 'Comuna del hecho',
          prefixIcon: Icon(Icons.location_city_outlined),
        ),
        items: [
          for (final commune in snapshot.data as List)
            DropdownMenuItem(
              value: commune['codigo_comuna'] as String,
              child: Text(
                commune['nombre'] as String,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: widget.enabled ? widget.onChanged : null,
        validator: (value) =>
            value == null ? 'Selecciona una comuna del catálogo' : null,
      );
    },
  );
}

Future<String> validatedZone(
  RutaApi api,
  String? commune,
  String sector,
  LatLng point,
) async {
  if (commune == null) {
    throw const ApiError('Selecciona una comuna del catálogo.');
  }
  final result = await api.request(
    '/territorio/validacion',
    method: 'POST',
    body: {
      'codigo_comuna': commune,
      'sector': sector.trim(),
      'latitud': point.latitude,
      'longitud': point.longitude,
    },
  );
  if (result is! Map ||
      result['zona'] is! String ||
      (result['zona'] as String).trim().isEmpty) {
    throw const ApiError('No se pudo validar la comuna. Intenta de nuevo.');
  }
  return result['zona'] as String;
}
