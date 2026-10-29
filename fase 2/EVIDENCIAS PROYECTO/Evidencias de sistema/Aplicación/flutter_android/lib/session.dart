import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import 'api.dart';

class Session extends ChangeNotifier {
  final RutaApi api;
  void Function()? onSessionEnded;
  Map<String, dynamic>? profile;
  Map<String, dynamic> identity = {};
  List<Map<String, dynamic>> vehicles = [], cases = [];
  LatLng? selectedPoint;
  String? _caseSignature, _caseKey;
  Session(this.api) {
    api.onExpired = clear;
  }
  bool get signedIn => profile != null;
  bool get canReport => identity['puede_participar'] == true;
  void clear() {
    onSessionEnded?.call();
    api.token = '';
    profile = null;
    identity = {};
    vehicles = [];
    cases = [];
    selectedPoint = null;
    _caseKey = null;
    _caseSignature = null;
    notifyListeners();
  }

  Future<void> login(
    String email,
    String password,
    String invite, {
    String? name,
  }) async {
    api.invitation = invite.trim();
    if (name != null) {
      await api.request(
        '/cuentas',
        method: 'POST',
        body: {
          'correo': email.trim(),
          'clave': password,
          'nombre_visible': name.trim(),
        },
      );
    }
    final response = await api.request(
      '/sesiones',
      method: 'POST',
      body: {'correo': email.trim(), 'clave': password},
    );
    api.token = response['token'] as String;
    try {
      await refresh();
    } catch (_) {
      clear();
      rethrow;
    }
  }

  Future<void> refresh() async {
    final session = api.token;
    final data = await Future.wait([
      api.request('/mi-perfil'),
      api.request('/identidad/mi-estado'),
      api.request('/vehiculos'),
      api.request('/mis-casos'),
    ]);
    if (session.isEmpty || api.token != session) return;
    profile = Map<String, dynamic>.from(data[0] as Map);
    identity = Map<String, dynamic>.from(data[1] as Map);
    vehicles = (data[2] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    cases = (data[3] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    notifyListeners();
  }

  void selectPoint(LatLng point) {
    selectedPoint = point;
    notifyListeners();
  }

  Future<String> report(Map<String, dynamic> body) async {
    // Conservar la misma clave ante un fallo de red evita duplicar el reporte.
    final signature = body.toString();
    if (_caseSignature != signature || _caseKey == null) {
      _caseSignature = signature;
      _caseKey = const Uuid().v4();
    }
    final response = await api.request(
      '/casos',
      method: 'POST',
      body: body,
      headers: {'Idempotency-Key': _caseKey!},
    );
    _caseSignature = null;
    _caseKey = null;
    selectedPoint = null;
    notifyListeners();
    return response['folio'] as String;
  }

  Future<void> logout() async {
    try {
      await api.request('/sesiones/cerrar', method: 'POST');
    } finally {
      clear();
      api.invitation = '';
    }
  }
}
