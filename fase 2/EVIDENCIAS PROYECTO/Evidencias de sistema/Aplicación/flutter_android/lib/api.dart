import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiError implements Exception {
  final String message;
  final int? status;
  const ApiError(this.message, [this.status]);
  @override
  String toString() => message;
}

class RutaApi {
  static const base = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://rutaalerta-mvp-g7.vercel.app',
  );
  final http.Client client;
  String invitation = '';
  String token = '';
  void Function()? onExpired;
  RutaApi({http.Client? client}) : client = client ?? http.Client();

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    final uri = Uri.parse('$base$path');
    if (uri.scheme != 'https') {
      throw const ApiError('La conexión debe utilizar HTTPS.');
    }
    final session = token;
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Accept': 'application/json',
        if (invitation.isNotEmpty) 'X-Demo-Access': invitation,
        if (session.isNotEmpty) 'Authorization': 'Bearer $session',
        ...headers,
      });
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final response = await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 35)),
      ).timeout(const Duration(seconds: 35));
      dynamic data;
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(response.body);
        } on FormatException {
          throw const ApiError(
            'El servicio no respondió correctamente. Intenta de nuevo.',
          );
        }
      }
      if (response.statusCode >= 400) {
        if (response.statusCode == 401 &&
            session.isNotEmpty &&
            token == session) {
          token = '';
          onExpired?.call();
        }
        final detail = data is Map ? data['detail'] : null;
        throw ApiError(
          detail is String ? detail : 'Revisa los datos e intenta de nuevo.',
          response.statusCode,
        );
      }
      return data;
    } on TimeoutException {
      throw const ApiError(
        'La conexión tardó demasiado. Puedes volver a intentar.',
      );
    } on http.ClientException {
      throw const ApiError('No se pudo conectar. Revisa tu acceso a internet.');
    }
  }
}
