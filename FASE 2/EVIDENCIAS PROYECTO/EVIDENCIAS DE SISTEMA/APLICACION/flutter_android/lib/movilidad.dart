import 'dart:math' as math;

import 'zonas_historicas.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as m;

import 'session.dart';
import 'ui.dart';
import 'expanded.dart';
import 'trip.dart';

class Mobility {
  static const channel = MethodChannel('cl.rutaalerta/movilidad');
  static Future<Map<String, dynamic>> location() async {
    final allowed = await TripService.channel.invokeMethod<bool>(
      'requestMapLocation',
    );
    if (allowed != true) {
      throw Exception('Autoriza la ubicación del teléfono para usar el GPS.');
    }
    final p = await channel.invokeMapMethod<String, dynamic>('location');
    if (p == null) throw Exception('No se obtuvo una ubicación actual.');
    return p;
  }

  static Future<void> source(String url) =>
      channel.invokeMethod('openSource', {'url': url});
  static Future<void> navigate(
    String provider,
    Map<String, dynamic> destination, {
    Map<String, dynamic>? origin,
  }) => channel.invokeMethod('openNavigation', {
    'provider': provider,
    'lat': destination['latitud'],
    'lon': destination['longitud'],
    'originLat': origin?['latitud'],
    'originLon': origin?['longitud'],
  });
}

class PlacesRoutesScreen extends StatefulWidget {
  final Session session;
  const PlacesRoutesScreen({super.key, required this.session});
  @override
  State<PlacesRoutesScreen> createState() => _PlacesRoutesScreenState();
}

class _PlacesRoutesScreenState extends State<PlacesRoutesScreen> {
  List<Map<String, dynamic>> places = [];
  Map<String, dynamic>? origin, destination;
  Map<String, dynamic>? result;
  String error = '';
  bool busy = false;
  bool avoidZones = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await widget.session.api.request('/lugares');
      if (mounted) {
        setState(
          () => places = (r as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> edit(String type) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceEditor(
          session: widget.session,
          type: type,
          initial: places.where((p) => p['tipo'] == type).firstOrNull,
        ),
      ),
    );
    await load();
  }

  Future<void> chooseAddress({required bool forOrigin}) async {
    final selected = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceEditor(
          session: widget.session,
          type: forOrigin ? 'origen' : 'destino',
          temporal: true,
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (forOrigin) {
        origin = selected;
      } else {
        destination = selected;
      }
      result = null;
      error = '';
    });
  }

  Future<void> gps() async {
    setState(() => busy = true);
    try {
      final p = await Mobility.location();
      if (mounted) {
        setState(() {
          origin = {
            'nombre': 'Mi ubicación actual',
            'latitud': p['lat'],
            'longitud': p['lon'],
          };
          result = null;
          error = '';
        });
      }
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> calculate() async {
    if (origin == null || destination == null) {
      feedback(context, 'Elige origen y destino.');
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Calcular recorrido'),
        content: const Text(
          'Se enviarán las coordenadas de origen y destino al servidor de RutaAlerta y al servicio público OSRM para calcular alternativas. No se guardará tu recorrido. El tiempo es estimado y no incluye tráfico en vivo ni garantiza seguridad.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Calcular'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      final r = await widget.session.api.request(
        '/rutas/calcular',
        method: 'POST',
        body: {
          'origen': {
            'latitud': origin!['latitud'],
            'longitud': origin!['longitud'],
          },
          'destino': {
            'latitud': destination!['latitud'],
            'longitud': destination!['longitud'],
          },
          'consentimiento_proveedor': true,
          'evitar_zonas': avoidZones,
        },
      );
      if (mounted) {
        setState(() {
          result = Map<String, dynamic>.from(r as Map);
          error = '';
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final casa = places.where((p) => p['tipo'] == 'casa').firstOrNull;
    final trabajo = places.where((p) => p['tipo'] == 'trabajo').firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis lugares y rutas')),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('¿A dónde vas?'),
                  if (casa != null && trabajo != null)
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              origin = casa;
                              destination = trabajo;
                              result = null;
                            }),
                      icon: const Icon(Icons.work_outline),
                      label: const Text('De Casa a Trabajo'),
                    ),
                  if (places.isEmpty)
                    TextButton.icon(
                      onPressed: () => edit('casa'),
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Guardar mi primer destino'),
                    ),
                  DropdownButtonFormField<String>(
                    key: ValueKey('origen/${origin?['tipo']}'),
                    initialValue:
                        places.any((item) => item['tipo'] == origin?['tipo'])
                        ? (origin?['tipo'] as String?)
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Origen guardado',
                    ),
                    items: [
                      for (final p in places)
                        DropdownMenuItem(
                          value: p['tipo'] as String,
                          child: Text('${p['nombre']}'),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                            origin = places.firstWhere((p) => p['tipo'] == v);
                            result = null;
                          }),
                  ),
                  if (origin != null && origin?['tipo'] == null)
                    Text('Origen · ${origin!['nombre']}'),
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () => chooseAddress(forOrigin: true),
                    icon: const Icon(Icons.search),
                    label: const Text('Buscar dirección de origen'),
                  ),
                  gap(),
                  OutlinedButton.icon(
                    onPressed: busy ? null : gps,
                    icon: const Icon(Icons.my_location),
                    label: Text(
                      origin?['nombre'] == 'Mi ubicación actual'
                          ? 'Origen: mi GPS actual'
                          : 'Usar mi ubicación como origen',
                    ),
                  ),
                  gap(),
                  DropdownButtonFormField<String>(
                    key: ValueKey('destino/${destination?['tipo']}'),
                    initialValue:
                        places.any(
                          (item) => item['tipo'] == destination?['tipo'],
                        )
                        ? (destination?['tipo'] as String?)
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Destino'),
                    items: [
                      for (final p in places)
                        DropdownMenuItem(
                          value: p['tipo'] as String,
                          child: Text('${p['nombre']}'),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                            destination = places.firstWhere(
                              (p) => p['tipo'] == v,
                            );
                            result = null;
                          }),
                  ),
                  if (destination != null && destination?['tipo'] == null)
                    Text('Destino · ${destination!['nombre']}'),
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () => chooseAddress(forOrigin: false),
                    icon: const Icon(Icons.search),
                    label: const Text('Buscar dirección de destino'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Priorizar menos cruces con históricos y alertas',
                    ),
                    value: avoidZones,
                    onChanged: busy
                        ? null
                        : (value) => setState(() {
                            avoidZones = value;
                            result = null;
                          }),
                  ),
                  gap(),
                  FilledButton.icon(
                    onPressed: busy ? null : calculate,
                    icon: const Icon(Icons.route),
                    label: Text(
                      busy ? 'Calculando…' : 'Ver alternativas de ruta',
                    ),
                  ),
                  if (destination != null) ...[
                    gap(),
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => perform(
                              context,
                              () => Mobility.navigate(
                                'google',
                                destination!,
                                origin: origin,
                              ),
                            ),
                      icon: const Icon(Icons.navigation_outlined),
                      label: const Text('Iniciar en Google Maps'),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => perform(
                              context,
                              () => Mobility.navigate('waze', destination!),
                            ),
                      icon: const Icon(Icons.directions_car_outlined),
                      label: const Text('Iniciar en Waze'),
                    ),
                    const Note(
                      'Google Maps recibe origen y destino. Waze navega desde la posición actual del teléfono. Cada aplicación decide su propio recorrido; RutaAlerta no lee la ruta de Waze.',
                    ),
                  ],
                  if (error.isNotEmpty) Note(error),
                ],
              ),
            ),
            if (result != null) ...[
              if (result!['simulacion'] == true)
                const Note('ENSAYO · zonas históricas ficticias.'),
              Note('${result!['proveedor']}'),
              for (final route in result!['rutas'])
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${((route['distancia_m'] as num) / 1000).toStringAsFixed(1)} km · ${((route['duracion_s'] as num) / 60).round()} min aprox.',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      if (route['cruces_zonas'] != null)
                        Text(
                          route['cruces_zonas'] == 0
                              ? 'Sin cruces con los sectores con antecedentes o alertas'
                              : '${route['cruces_zonas']} sectores con antecedentes o alertas en el recorrido',
                        ),
                      gap(),
                      OutlinedButton(
                        onPressed: () => openScreen(
                          context,
                          RouteMap(
                            route: Map<String, dynamic>.from(route as Map),
                            zones: result!['zonas'] as List? ?? [],
                          ),
                        ),
                        child: const Text('Ver recorrido en el mapa'),
                      ),
                    ],
                  ),
                ),
              Note('${result!['nota']}'),
            ],
            ActionGroup(
              title: 'Lugares guardados',
              children: [
                for (final entry in {
                  'casa': ('Casa', Icons.home_outlined),
                  'trabajo': ('Trabajo', Icons.work_outline),
                  'favorito': ('Favorito', Icons.star_outline),
                }.entries)
                  ActionRow(
                    icon: entry.value.$2,
                    title: entry.value.$1,
                    detail:
                        places
                            .where((p) => p['tipo'] == entry.key)
                            .firstOrNull?['nombre'] ??
                        'Agregar lugar',
                    onTap: () => edit(entry.key),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PlaceEditor extends StatefulWidget {
  final Session session;
  final String type;
  final Map<String, dynamic>? initial;
  final bool temporal;
  const PlaceEditor({
    super.key,
    required this.session,
    required this.type,
    this.initial,
    this.temporal = false,
  });
  @override
  State<PlaceEditor> createState() => _PlaceEditorState();
}

class _PlaceEditorState extends State<PlaceEditor> {
  late final name = TextEditingController(
    text: widget.initial?['nombre'] ?? (widget.temporal ? '' : widget.type),
  );
  late final address = TextEditingController(
    text: widget.initial?['direccion'] ?? '',
  );
  late final lat = TextEditingController(
    text: widget.initial?['latitud']?.toString() ?? '',
  );
  late final lon = TextEditingController(
    text: widget.initial?['longitud']?.toString() ?? '',
  );
  List<Map<String, dynamic>> candidates = [];
  bool busy = false;
  @override
  void dispose() {
    for (final c in [name, address, lat, lon]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> search() async {
    setState(() => busy = true);
    try {
      final r = await Mobility.channel.invokeListMethod<Map>('geocode', {
        'query': address.text.trim(),
      });
      if (mounted) {
        setState(
          () => candidates = (r ?? [])
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        );
      }
      if (mounted && candidates.isEmpty) {
        feedback(
          context,
          'No hubo resultados; selecciona el lugar en el mapa.',
        );
      }
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      final a = double.tryParse(lat.text), b = double.tryParse(lon.text);
      if (a == null || b == null) {
        throw Exception('Confirma el punto de tu destino.');
      }
      if (widget.temporal) {
        Navigator.pop(context, <String, dynamic>{
          'nombre': address.text.trim().isEmpty
              ? 'Punto en el mapa'
              : address.text.trim(),
          'latitud': a,
          'longitud': b,
        });
        return;
      }
      await widget.session.api.request(
        '/lugares/${widget.type}',
        method: 'PUT',
        body: {
          'nombre': name.text.trim(),
          'direccion': address.text.trim(),
          'latitud': a,
          'longitud': b,
        },
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.temporal ? 'Elegir ${widget.type}' : 'Guardar ${widget.type}',
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (!widget.temporal) ...[
          const Note(
            'Se guarda de forma privada en tu cuenta. Confirma el resultado antes de guardar.',
          ),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Nombre del lugar'),
          ),
        ],
        gap(),
        TextField(
          controller: address,
          decoration: const InputDecoration(
            labelText: 'Dirección, comuna y país',
          ),
        ),
        gap(),
        OutlinedButton.icon(
          onPressed: busy ? null : search,
          icon: const Icon(Icons.search),
          label: const Text('Buscar dirección'),
        ),
        for (final p in candidates)
          Card(
            child: ListTile(
              title: Text('${p['address']}'),
              onTap: () {
                setState(() {
                  lat.text = '${p['lat']}';
                  lon.text = '${p['lon']}';
                  address.text = '${p['address']}';
                  candidates = [];
                });
              },
            ),
          ),
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () async {
                  final point = await Navigator.push<Map<String, double>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PointPicker(
                        initialLat: double.tryParse(lat.text),
                        initialLon: double.tryParse(lon.text),
                      ),
                    ),
                  );
                  if (point != null && mounted) {
                    setState(() {
                      lat.text = '${point['lat']}';
                      lon.text = '${point['lon']}';
                    });
                  }
                },
          icon: const Icon(Icons.pin_drop_outlined),
          label: const Text('Seleccionar punto en el mapa'),
        ),
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () => perform(context, () async {
                  final p = await Mobility.location();
                  if (mounted) {
                    setState(() {
                      lat.text = '${p['lat']}';
                      lon.text = '${p['lon']}';
                    });
                  }
                }),
          icon: const Icon(Icons.my_location),
          label: const Text('Usar mi GPS actual'),
        ),
        gap(),
        TextField(
          controller: lat,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: const InputDecoration(labelText: 'Latitud confirmada'),
        ),
        gap(),
        TextField(
          controller: lon,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: const InputDecoration(labelText: 'Longitud confirmada'),
        ),
        gap(),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(
            busy
                ? 'Procesando…'
                : widget.temporal
                ? 'Usar este punto'
                : 'Guardar lugar privado',
          ),
        ),
        if (widget.initial != null)
          TextButton(
            onPressed: busy
                ? null
                : () => perform(context, () async {
                    final yes = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Retirar lugar'),
                        content: const Text(
                          'Se quitarán la dirección y coordenadas de este destino guardado.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Retirar'),
                          ),
                        ],
                      ),
                    );
                    if (yes != true) return;
                    await widget.session.api.request(
                      '/lugares/${widget.type}/retirar',
                      method: 'POST',
                    );
                    if (context.mounted) Navigator.pop(context);
                  }),
            child: const Text('Retirar lugar de mi cuenta'),
          ),
      ],
    ),
  );
}

class PointPicker extends StatefulWidget {
  final double? initialLat, initialLon;
  const PointPicker({super.key, this.initialLat, this.initialLon});
  @override
  State<PointPicker> createState() => _PointPickerState();
}

class _PointPickerState extends State<PointPicker> {
  m.LatLng? selected;
  m.MapLibreMapController? controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Selecciona el lugar')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Toca el lugar exacto y confirma. El centro inicial no se guarda automáticamente.',
          ),
        ),
        Expanded(
          child: m.MapLibreMap(
            styleString: 'assets/mapa_azul.json',
            initialCameraPosition: m.CameraPosition(
              target: m.LatLng(
                widget.initialLat ?? -36.827,
                widget.initialLon ?? -73.05,
              ),
              zoom: 15,
            ),
            onMapCreated: (c) => controller = c,
            onMapClick: (_, p) async {
              setState(() => selected = p);
              try {
                await controller?.clearCircles();
                await controller?.addCircle(
                  m.CircleOptions(
                    geometry: p,
                    circleColor: '#2867d8',
                    circleRadius: 9,
                    circleStrokeColor: '#ffffff',
                    circleStrokeWidth: 3,
                  ),
                );
              } catch (_) {}
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (selected != null)
                Text(
                  '${selected!.latitude.toStringAsFixed(5)}, ${selected!.longitude.toStringAsFixed(5)}',
                ),
              FilledButton(
                onPressed: selected == null
                    ? null
                    : () => Navigator.pop(context, {
                        'lat': selected!.latitude,
                        'lon': selected!.longitude,
                      }),
                child: const Text('Confirmar este punto'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class RouteMap extends StatefulWidget {
  final Map<String, dynamic> route;
  final List zones;
  const RouteMap({super.key, required this.route, this.zones = const []});
  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  m.MapLibreMapController? controller;
  String? error;
  Future<void> loaded() async {
    try {
      final geo = Map<String, dynamic>.from(widget.route['geometria'] as Map);
      if (widget.zones.isNotEmpty) {
        await controller!.addGeoJsonSource('zonas-historicas', {
          'type': 'FeatureCollection',
          'features': [
            for (final z in widget.zones)
              {
                'type': 'Feature',
                'properties': {
                  'color':
                      '#${(z['origen'] == 'alerta'
                          ? zonaActiva
                          : concentracionAlta(z)
                          ? zonaAlta
                          : zonaModerada).toARGB32().toRadixString(16).substring(2)}',
                },
                'geometry': z['geometria'],
              },
          ],
        });
        await controller!.addFillLayer(
          'zonas-historicas',
          'manchas-historicas',
          const m.FillLayerProperties(
            fillColor: ['get', 'color'],
            fillOpacity: .42,
            fillOutlineColor: ['get', 'color'],
          ),
        );
      }
      await controller!.addGeoJsonSource('recorrido', {
        'type': 'Feature',
        'properties': {},
        'geometry': geo,
      });
      await controller!.addLineLayer(
        'recorrido',
        'trazo',
        const m.LineLayerProperties(
          lineColor: '#64caff',
          lineWidth: 6,
          lineOpacity: 0.9,
        ),
      );
      final pts = geo['coordinates'] as List;
      final lats = pts.map((p) => (p[1] as num).toDouble());
      final lons = pts.map((p) => (p[0] as num).toDouble());
      await controller!.animateCamera(
        m.CameraUpdate.newLatLngBounds(
          m.LatLngBounds(
            southwest: m.LatLng(lats.reduce(math.min), lons.reduce(math.min)),
            northeast: m.LatLng(lats.reduce(math.max), lons.reduce(math.max)),
          ),
          left: 35,
          right: 35,
          top: 50,
          bottom: 50,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'No se pudo dibujar el recorrido. Puedes abrir la navegación externa.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.route['geometria']['coordinates'] as List;
    return Scaffold(
      appBar: AppBar(title: const Text('Recorrido estimado')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Recorrido vial calculado. No incluye tráfico en vivo ni calificación de seguridad.',
            ),
          ),
          if (widget.zones.isNotEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: LeyendaZonas(),
            ),
          if (error != null) Note(error!),
          Expanded(
            child: m.MapLibreMap(
              styleString: 'assets/mapa_azul.json',
              initialCameraPosition: m.CameraPosition(
                target: m.LatLng(
                  (points[0][1] as num).toDouble(),
                  (points[0][0] as num).toDouble(),
                ),
                zoom: 13,
              ),
              onMapCreated: (c) => controller = c,
              onStyleLoadedCallback: loaded,
            ),
          ),
        ],
      ),
    );
  }
}

class HistoricalReviewScreen extends StatelessWidget {
  final Session session;
  const HistoricalReviewScreen({super.key, required this.session});
  @override
  Widget build(BuildContext context) => DataScreen(
    session: session,
    title: 'Fuentes y avisos históricos',
    path: '/gestion/antecedentes',
    render: (ctx, data, reload) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Note(
          'Revisa la fuente original, la fecha, duplicados y el sector. La posición debe ser aproximada; una noticia no determina frecuencia ni delito en curso.',
        ),
        FilledButton.icon(
          onPressed: () => perform(ctx, () async {
            final d = await ask(ctx, 'Proponer antecedente de prensa', {
              'url_fuente': 'Enlace HTTPS de la fuente',
              'nombre_fuente': 'Medio o institución',
              'titulo': 'Título breve propio',
              'resumen': 'Resumen propio (sin copiar el artículo completo)',
              'tipo': 'portonazo, encerrona, robo_vehiculo u otro',
              'fecha_publicacion': 'Fecha de publicación YYYY-MM-DD',
              'zona': 'Sector o comuna',
            });
            if (d == null) return;
            final orgs = session.profile?['organizaciones'] as List? ?? [];
            if (orgs.isEmpty) return;
            await session.api.request(
              '/gestion/antecedentes',
              method: 'POST',
              body: {...d, 'id_organizacion': orgs.first},
            );
            reload();
          }),
          icon: const Icon(Icons.add_link),
          label: const Text('Agregar fuente para revisión'),
        ),
        gap(),
        for (final a in data)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${a['titulo']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                gap(8),
                StateChip('${a['estado']}'),
                Note(
                  '${a['nombre_fuente']} · ${a['fecha_publicacion']} · ${a['zona']}',
                ),
                Text('${a['resumen']}'),
                TextButton.icon(
                  onPressed: () => perform(
                    ctx,
                    () => Mobility.source(a['url_fuente'] as String),
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir fuente original'),
                ),
                OutlinedButton(
                  onPressed: () => perform(ctx, () async {
                    final point = await Navigator.push<Map<String, double>>(
                      ctx,
                      MaterialPageRoute(builder: (_) => const PointPicker()),
                    );
                    if (point == null || !ctx.mounted) return;
                    final d = await ask(
                      ctx,
                      'Validar sector y aviso',
                      {
                        'precision_m':
                            'Incertidumbre de ubicación en metros (mínimo 100)',
                        'radio_m': 'Radio del aviso (no menor a incertidumbre)',
                        'dias_vigencia': 'Vigencia en días (1 a 90)',
                        'motivo': 'Qué se revisó: fuente, fecha, ubicación y duplicados',
                      },
                      values: {
                        'precision_m': '1000',
                        'radio_m': '1500',
                        'dias_vigencia': '30',
                      },
                    );
                    if (d == null) return;
                    await session.api.request(
                      '/gestion/antecedentes/${a['id_antecedente']}/revision',
                      method: 'POST',
                      body: {
                        ...d,
                        'latitud': point['lat'],
                        'longitud': point['lon'],
                        'decision': 'validado',
                        'precision_m': int.tryParse(d['precision_m'] ?? ''),
                        'radio_m': int.tryParse(d['radio_m'] ?? ''),
                        'dias_vigencia': int.tryParse(d['dias_vigencia'] ?? ''),
                      },
                    );
                    reload();
                  }),
                  child: const Text(
                    'Confirmar ubicación aproximada y activar aviso',
                  ),
                ),
                OutlinedButton(
                  onPressed: () => perform(ctx, () async {
                    final d = await ask(ctx, 'Descartar o retirar aviso', {
                      'motivo':
                          'Motivo de descarte o retiro (15 caracteres o más)',
                    });
                    if (d == null) return;
                    await session.api.request(
                      '/gestion/antecedentes/${a['id_antecedente']}/revision',
                      method: 'POST',
                      body: {
                        ...d,
                        'decision': 'descartado',
                        'latitud': a['latitud'],
                        'longitud': a['longitud'],
                      },
                    );
                    reload();
                  }),
                  child: const Text('Descartar / retirar'),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class HistoricalNewsScreen extends StatelessWidget {
  final Session session;
  const HistoricalNewsScreen({super.key, required this.session});
  @override
  Widget build(BuildContext context) => DataScreen(
    session: session,
    title: 'Antecedentes y sus fuentes',
    path: '/territorio/noticias',
    render: (ctx, data, reload) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Note('${data['nota']}'),
        if ((data['noticias'] as List).isEmpty)
          const Panel(
            child: Text(
              'Todavía no hay fuentes incorporadas para este territorio.',
            ),
          ),
        for (final n in data['noticias'])
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${n['titulo']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Note(
                  '${n['nombre_fuente']} · publicado ${n['fecha_publicacion']}',
                ),
                Text('${n['resumen']}'),
                gap(),
                StateChip(
                  n['estado'] == 'validado'
                      ? 'Sector revisado'
                      : 'Sin avisos: pendiente de revisión',
                ),
                TextButton.icon(
                  onPressed: () => perform(
                    ctx,
                    () => Mobility.source(n['url_fuente'] as String),
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Leer fuente original'),
                ),
              ],
            ),
          ),
        const Note(
          'Para recibir avisos: inicia Modo trayecto con permiso de ubicación y notificaciones. Sólo se descargan los antecedentes revisados, geolocalizados y vigentes de tu área. Un listado vacío nunca se interpreta como zona segura.',
        ),
      ],
    ),
  );
}
