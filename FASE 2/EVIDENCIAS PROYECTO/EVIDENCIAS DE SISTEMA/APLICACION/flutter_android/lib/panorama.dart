import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'session.dart';
import 'expanded.dart';
import 'movilidad.dart' show Mobility;
import 'ui.dart';
import 'location_picker.dart';

class PanoramaZonal extends StatefulWidget {
  final Session session;
  final bool compacto;
  final VoidCallback? ampliar;
  const PanoramaZonal({
    super.key,
    required this.session,
    this.compacto = false,
    this.ampliar,
  });
  @override
  State<PanoramaZonal> createState() => _PanoramaZonalState();
}

class _PanoramaZonalState extends State<PanoramaZonal> {
  static const ciudades = {
    'Chillán': LatLng(-36.606, -72.104),
    'Concepción': LatLng(-36.827, -73.05),
    'Santiago': LatLng(-33.45, -70.66),
  };
  final mapa = MapController();
  late LatLng centro;
  late String sector;
  List<dynamic> solicitudes = [], historia = [];
  String? error;
  bool cargando = false, gpsOcupado = false;
  int peticion = 0, paso = 0;
  Timer? animacion;
  LatLng get centroPrueba =>
      LatLng(centro.latitude + .005, centro.longitude + .005);
  LatLng get movilPrueba =>
      LatLng(centroPrueba.latitude + .009 * (3 - paso), centroPrueba.longitude);
  @override
  void initState() {
    super.initState();
    centro = widget.session.centroZonal ?? ciudades['Chillán']!;
    sector = widget.session.nombreZona;
    cargar();
  }

  @override
  void dispose() {
    animacion?.cancel();
    mapa.dispose();
    super.dispose();
  }

  Future<void> cargar() async {
    final turno = ++peticion;
    setState(() {
      cargando = true;
      error = null;
      solicitudes = [];
      historia = [];
    });
    try {
      final data = await widget.session.api.request(
        '/territorio/panorama?lat=${centro.latitude.toStringAsFixed(2)}&lon=${centro.longitude.toStringAsFixed(2)}',
      );
      if (!mounted || turno != peticion) return;
      setState(() {
        solicitudes = List.of(data['solicitudes']);
        historia = List.of(data['antecedentes']);
      });
    } catch (_) {
      if (mounted && turno == peticion) {
        setState(() => error = 'No se pudieron cargar los eventos.');
      }
    } finally {
      if (mounted && turno == peticion) setState(() => cargando = false);
    }
  }

  void cambiar(String nombre, LatLng posicion) {
    animacion?.cancel();
    setState(() {
      sector = nombre;
      centro = posicion;
      paso = 0;
    });
    widget.session.centroZonal = centro;
    widget.session.nombreZona = sector;
    mapa.move(centro, 12);
    cargar();
  }

  Future<void> ubicar() async {
    setState(() => gpsOcupado = true);
    try {
      final gps = await Mobility.location();
      if (mounted) {
        cambiar(
          'Mi ubicación',
          LatLng(
            (gps['lat'] as num).toDouble(),
            (gps['lon'] as num).toDouble(),
          ),
        );
      }
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => gpsOcupado = false);
    }
  }

  void simular() {
    animacion?.cancel();
    if (paso != 0) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      setState(() => paso = 0);
      return;
    }
    setState(() => paso = 1);
    mapa.move(centroPrueba, 13);
    animacion = Timer.periodic(const Duration(seconds: 2), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => paso++);
      if (const Distance().as(LengthUnit.Meter, movilPrueba, centroPrueba) <=
          500) {
        t.cancel();
        if (ModalRoute.of(context)?.isCurrent == true) {
          feedback(
            context,
            'Simulación · Entraste al radio de aviso de 500 m.',
          );
        }
      }
    });
  }

  LatLng? punto(dynamic d, String lat, String lon) {
    if (d[lat] is! num || d[lon] is! num) return null;
    return LatLng((d[lat] as num).toDouble(), (d[lon] as num).toDouble());
  }

  void detalle(dynamic item, bool historico) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
          children: [
            Text(
              historico ? 'Antecedente histórico' : 'Solicitud de colaboración',
              style: TextStyle(
                color: historico ? Colors.deepOrange : teal,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              historico
                  ? '${item['titulo']}'
                  : '${item['patente']} · ${item['marca']} ${item['modelo']}',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            Text(
              historico
                  ? '${item['zona']} · ${item['nombre_fuente']} · ${item['fecha_publicacion']}'
                  : 'Sector aproximado: ${item['zona_publicable']} · ${item['color']}',
            ),
            gap(),
            Text('${historico ? item['resumen'] : item['texto_aprobado']}'),
            if (historico)
              SelectableText('${item['url_fuente']}')
            else
              collaborationAction(ctx, widget.session, item),
            if (!historico &&
                item['es_mi_caso'] != true &&
                !widget.session.canReport)
              const Text('Verifica tu cuenta para aportar.'),
          ],
        ),
      ),
    );
  }

  Marker marca(
    LatLng p,
    IconData icon,
    Color color,
    String texto,
    VoidCallback? tocar,
  ) => Marker(
    point: p,
    width: 40,
    height: 40,
    child: Semantics(
      label: texto,
      button: tocar != null,
      child: InkWell(
        onTap: tocar,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    const rojo = Color(0xffb84438);
    final circulos = <CircleMarker>[], marcas = <Marker>[];
    if (sector == 'Mi ubicación') {
      marcas.add(
        marca(
          centro,
          Icons.my_location,
          const Color(0xff1468bf),
          'Última ubicación consultada del teléfono',
          null,
        ),
      );
    }
    for (final h in historia) {
      final p = punto(h, 'latitud', 'longitud');
      if (p == null) continue;
      circulos.add(
        CircleMarker(
          point: p,
          radius: (h['radio_m'] as num).toDouble(),
          useRadiusInMeter: true,
          color: rojo.withValues(alpha: .15),
          borderColor: rojo,
          borderStrokeWidth: 1,
        ),
      );
      marcas.add(
        marca(
          p,
          Icons.history,
          rojo,
          'Antecedente histórico',
          () => detalle(h, true),
        ),
      );
    }
    for (final s in solicitudes) {
      final p = punto(s, 'latitud_sector', 'longitud_sector');
      if (p != null) {
        marcas.add(
          marca(
            p,
            Icons.directions_car,
            navy,
            'Solicitud en ${s['zona_publicable']}',
            () => detalle(s, false),
          ),
        );
      }
    }
    if (paso > 0) {
      circulos.add(
        CircleMarker(
          point: centroPrueba,
          radius: 500,
          useRadiusInMeter: true,
          color: rojo.withValues(alpha: .23),
          borderColor: rojo,
          borderStrokeWidth: 2,
        ),
      );
      marcas.add(
        marca(movilPrueba, Icons.navigation, teal, 'Recorrido simulado', null),
      );
    }
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: widget.compacto ? 205 : 320,
            child: Stack(
              children: [
                RutaMap(
                  controller: mapa,
                  center: centro,
                  interactive: !widget.compacto,
                  circles: circulos,
                  markers: marcas,
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Material(
                    color: navy,
                    borderRadius: BorderRadius.circular(18),
                    child: PopupMenuButton<String>(
                      tooltip: 'Cambiar zona',
                      onSelected: (n) => cambiar(n, ciudades[n]!),
                      itemBuilder: (_) => ciudades.keys
                          .map((n) => PopupMenuItem(value: n, child: Text(n)))
                          .toList(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.place,
                              color: Colors.white,
                              size: 16,
                            ),
                            Text(
                              sector,
                              style: const TextStyle(color: Colors.white),
                            ),
                            const Icon(
                              Icons.expand_more,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton.filledTonal(
                    onPressed: gpsOcupado ? null : ubicar,
                    icon: const Icon(Icons.my_location),
                    tooltip: 'Centrar en mi GPS',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Actividad en tu zona',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: navy,
                        ),
                      ),
                    ),
                    if (widget.ampliar != null)
                      IconButton(
                        onPressed: widget.ampliar,
                        tooltip: 'Ampliar mapa zonal',
                        icon: const Icon(Icons.open_in_full),
                      ),
                    IconButton(
                      onPressed: cargando ? null : cargar,
                      tooltip: 'Actualizar zona',
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                Text(
                  cargando
                      ? 'Consultando el sector…'
                      : error ??
                            '${solicitudes.length} solicitudes · ${historia.length} antecedentes históricos en 30 km',
                ),
                if (!widget.compacto)
                  const Text(
                    'Azul: sector de una solicitud. Rojo: radio de aviso de un antecedente revisado.',
                    style: TextStyle(color: muted),
                  ),
                if (paso > 0)
                  Text(
                    paso == 3
                        ? 'SIMULACIÓN · Dentro del radio de aviso'
                        : 'SIMULACIÓN · Acercándose al sector',
                    style: const TextStyle(
                      color: rojo,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                TextButton.icon(
                  onPressed: simular,
                  icon: const Icon(Icons.play_circle_outline),
                  label: Text(
                    paso == 0
                        ? 'Simular alerta de proximidad'
                        : 'Terminar simulación',
                  ),
                ),
                if (!widget.compacto) ...[
                  OutlinedButton.icon(
                    onPressed: () =>
                        cambiar('Zona seleccionada', mapa.camera.center),
                    icon: const Icon(Icons.travel_explore),
                    label: const Text('Consultar el centro del mapa'),
                  ),
                  for (final h in historia)
                    ListTile(
                      leading: const Icon(Icons.history, color: rojo),
                      title: Text('${h['titulo']}'),
                      subtitle: Text(
                        '${h['zona']} · ${h['fecha_publicacion']}',
                      ),
                      onTap: () => detalle(h, true),
                    ),
                  for (final s in solicitudes)
                    ListTile(
                      leading: const Icon(Icons.directions_car),
                      title: Text('${s['patente']} · ${s['modelo']}'),
                      subtitle: Text('${s['zona_publicable']}'),
                      onTap: () => detalle(s, false),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
