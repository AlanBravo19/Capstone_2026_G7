import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'api.dart';

class CommunePicker extends StatefulWidget {
  final RutaApi api;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final List<String> suggestions;
  const CommunePicker({
    super.key,
    required this.api,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.suggestions = const [],
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
      final catalog = (snapshot.data as List).cast<Map>();
      final current = catalog
          .where((row) => row['codigo_comuna'] == widget.value)
          .firstOrNull;
      final suggestion = widget.suggestions
          .map(
            (name) => catalog
                .where(
                  (row) =>
                      searchKey(row['nombre'] as String) == searchKey(name),
                )
                .firstOrNull,
          )
          .whereType<Map>()
          .firstOrNull;
      return FormField<String>(
        key: ValueKey(widget.value),
        initialValue: widget.value,
        validator: (value) =>
            value == null ? 'Elige una comuna del catálogo' : null,
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.search),
              label: Text(current?['nombre'] as String? ?? 'Buscar comuna'),
              onPressed: !widget.enabled
                  ? null
                  : () async {
                      final code = await showDialog<String>(
                        context: context,
                        builder: (_) => _CommuneSearch(catalog),
                      );
                      if (mounted && code != null) widget.onChanged(code);
                    },
            ),
            if (suggestion != null && current == null)
              TextButton.icon(
                onPressed: !widget.enabled
                    ? null
                    : () => widget.onChanged(
                        suggestion['codigo_comuna'] as String,
                      ),
                icon: const Icon(Icons.near_me_outlined),
                label: Text('Usar comuna sugerida: ${suggestion['nombre']}'),
              ),
            if (field.errorText case final String message)
              Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      );
    },
  );
}

String searchKey(String value) {
  const accents = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  return value.trim().toLowerCase().replaceAllMapped(
    RegExp('[áéíóúüñ]'),
    (m) => accents[m[0]]!,
  );
}

class _CommuneSearch extends StatefulWidget {
  final List<Map> catalog;
  const _CommuneSearch(this.catalog);
  @override
  State<_CommuneSearch> createState() => _CommuneSearchState();
}

class _CommuneSearchState extends State<_CommuneSearch> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final matching = query.isEmpty
        ? <Map>[]
        : widget.catalog
              .where(
                (row) =>
                    searchKey(row['nombre'] as String).contains(query) ||
                    (row['codigo_comuna'] as String).contains(query),
              )
              .take(30)
              .toList();
    return AlertDialog(
      title: const Text('Comuna del hecho'),
      content: SizedBox(
        width: 420,
        height: 305,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (value) => setState(() => query = searchKey(value)),
              decoration: const InputDecoration(
                labelText: 'Escribe una comuna',
                hintText: 'Ej. Concepción',
              ),
            ),
            Expanded(
              child: matching.isEmpty
                  ? Center(
                      child: Text(
                        query.isEmpty
                            ? 'Escribe parte del nombre.'
                            : 'No se encontraron comunas.',
                      ),
                    )
                  : ListView(
                      children: [
                        for (final row in matching)
                          ListTile(
                            title: Text(row['nombre'] as String),
                            onTap: () => Navigator.pop(
                              context,
                              row['codigo_comuna'] as String,
                            ),
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
      if (sector.trim().isNotEmpty) 'sector': sector.trim(),
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
