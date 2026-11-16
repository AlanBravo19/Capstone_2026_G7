import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import 'api.dart';
import 'biometric.dart';

import 'dart:async';

class Session extends ChangeNotifier {
  final RutaApi api;
  void Function()? onSessionEnded;
  Map<String, dynamic>? profile;
  Map<String, dynamic> identity = {};
  List<Map<String, dynamic>> vehicles = [], cases = [];
  LatLng? selectedPoint;
  String? _caseSignature, _caseKey;
  String? mfaChallenge;
  String? avisoAlta;
  bool showEmailStep = false;
  Session(this.api) {
    api.onExpired = clear;
  }
  bool get signedIn => profile != null;
  bool get canReport => identity['puede_participar'] == true;
  void clear({bool forgetBiometric = true}) {
    if (forgetBiometric) {
      unawaited(BiometricAccess.clear().catchError((Object _) {}));
    }
    onSessionEnded?.call();
    api.token = '';
    profile = null;
    mfaChallenge = null;
    avisoAlta = null;
    showEmailStep = false;
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
    String password, {
    String? name,
    String modalidad = 'colaborador',
  }) async {
    if (name != null) {
      await api.request(
        '/cuentas',
        method: 'POST',
        body: {
          'correo': email.trim(),
          'clave': password,
          'nombre_visible': name.trim(),
          'modalidad_ciudadana': modalidad,
        },
      );
    }
    final response = await api.request(
      '/sesiones',
      method: 'POST',
      body: {'correo': email.trim(), 'clave': password},
    );
    if (response['requiere_mfa'] == true) {
      mfaChallenge = response['id_desafio'] as String;
      return;
    }
    api.token = response['token'] as String;
    try {
      await refresh();
      if (name != null && signedIn && identity['transporte_correo'] == 'smtp') {
        final newSession = api.token;
        try {
          await api.request('/identidad/correo/solicitar', method: 'POST');
          if (api.token == newSession) {
            avisoAlta =
                'Revisa tu correo y pega el código en Verificar mi correo.';
          }
        } on ApiError {
          if (api.token == newSession) {
            avisoAlta =
                'Cuenta creada. Solicita un código desde Verificar mi correo.';
          }
        }
        if (api.token == newSession) {
          showEmailStep = true;
          notifyListeners();
        }
      }
    } catch (_) {
      clear();
      rethrow;
    }
  }

  Future<void> confirmMfa(String code) async {
    final response = await api.request(
      '/sesiones/mfa',
      method: 'POST',
      body: {'id_desafio': mfaChallenge, 'codigo': code.trim()},
    );
    api.token = response['token'] as String;
    mfaChallenge = null;
    try {
      await refresh();
    } catch (_) {
      clear();
      rethrow;
    }
  }

  Future<void> loginBiometric() async {
    final data = await BiometricAccess.unlock();
    if (data['token'] is! String) {
      await BiometricAccess.clear();
      throw const ApiError(
        'Ingresa con tu contraseña para configurar el acceso otra vez.',
      );
    }
    api.token = data['token'];
    try {
      await refresh();
      if (profile?['id_usuario'] != data['uid']) {
        clear();
        throw const ApiError('La cuenta guardada no coincide.');
      }
    } catch (_) {
      clear(forgetBiometric: false);
      rethrow;
    }
  }

  Future<void> enableBiometric() async {
    if (!signedIn || api.token.isEmpty) {
      throw const ApiError('Primero ingresa con tu cuenta.');
    }
    await BiometricAccess.save(api.token, profile!['id_usuario'] as int);
  }

  void lockLocally() {
    clear(forgetBiometric: false);
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
    }
  }
}
