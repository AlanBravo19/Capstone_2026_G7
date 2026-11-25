import 'package:flutter/material.dart';

import 'api.dart';
import 'ui.dart';
import 'vehicle_photo.dart';

/// Only consumes the public collaboration response, never private case details.
class PublicVehicleDetails extends StatelessWidget {
  final RutaApi api;
  final Map<String, dynamic> data;
  const PublicVehicleDetails({
    super.key,
    required this.api,
    required this.data,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (data['modo_alerta'] != null) ...[
        StateChip(switch (data['modo_alerta']) {
          'provisional' => 'Alerta ciudadana provisional',
          'encargo_comprobado' =>
            data['simulada'] == true
                ? 'Simulación · Encargo encontrado'
                : 'Encargo comprobado',
          _ => 'Publicación revisada',
        }),
        if (data['modo_alerta'] != 'encargo_comprobado')
          const Note('Encargo policial pendiente de comprobación.'),
        if (DateTime.tryParse('${data['reportada_en']}')
            case final DateTime time)
          Text(
            'Reportado hace ${DateTime.now().difference(time).inMinutes.clamp(0, 1000000)} min',
          ),
        gap(8),
      ],
      VehiclePhoto(
        api: api,
        sid: data['id_solicitud_colaboracion'] as int,
        tipoVehiculo: data['tipo_vehiculo'] as String?,
        fotoDisponible:
            data['foto_disponible'] == true ||
            (data['foto_disponible'] == null &&
                data['foto_url'] is String &&
                (data['foto_url'] as String).isNotEmpty),
        fotoUrl: data['foto_url'] as String?,
      ),
      gap(12),
      Text(
        '${data['patente'] ?? ''} · ${data['marca'] ?? ''} ${data['modelo'] ?? ''}',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      gap(8),
      Text('${data['color'] ?? ''} · ${data['zona_publicable'] ?? ''}'),
      gap(8),
      Text('${data['texto_aprobado'] ?? ''}'),
    ],
  );
}

class PublicVehicleHeader extends StatefulWidget {
  final RutaApi api;
  final int sid;
  const PublicVehicleHeader({super.key, required this.api, required this.sid});

  @override
  State<PublicVehicleHeader> createState() => _PublicVehicleHeaderState();
}

class _PublicVehicleHeaderState extends State<PublicVehicleHeader> {
  late Future<Map<String, dynamic>> _detail;

  Future<Map<String, dynamic>> _load() async {
    final data = await widget.api.request('/colaboracion/${widget.sid}');
    if (data is! Map<String, dynamic>) {
      throw const ApiError('No se pudo cargar la descripción pública.');
    }
    return {...data, 'id_solicitud_colaboracion': widget.sid};
  }

  @override
  void initState() {
    super.initState();
    _detail = _load();
  }

  @override
  void didUpdateWidget(covariant PublicVehicleHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api || oldWidget.sid != widget.sid) {
      _detail = _load();
    }
  }

  @override
  Widget build(BuildContext context) => Panel(
    child: FutureBuilder<Map<String, dynamic>>(
      future: _detail,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return PublicVehicleDetails(api: widget.api, data: snapshot.data!);
        }
        if (snapshot.hasError) {
          final expired =
              snapshot.error is ApiError &&
              (snapshot.error as ApiError).status == 404;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                expired
                    ? 'Esta solicitud ya no está disponible o venció. Vuelve a Colaborar para actualizar la lista.'
                    : 'No se pudo cargar la descripción pública. Puedes seguir completando tu avistamiento.',
              ),
              TextButton.icon(
                onPressed: () => setState(() => _detail = _load()),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar detalle'),
              ),
            ],
          );
        }
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Cargando vehículo…'),
            SizedBox(height: 8),
            LinearProgressIndicator(),
          ],
        );
      },
    ),
  );
}
