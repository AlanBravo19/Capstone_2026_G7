import 'dart:convert';

import 'package:flutter/services.dart';

class BiometricAccess {
  static const channel = MethodChannel('cl.rutaalerta/biometria');
  static Future<Map<String, dynamic>> status() async =>
      await channel.invokeMapMethod<String, dynamic>('status') ??
      {'available': false, 'saved': false};
  static Future<void> save(String token, int uid) async {
    await channel.invokeMethod('save', {
      'payload': jsonEncode({'token': token, 'uid': uid}),
    });
  }

  static Future<Map<String, dynamic>> unlock() async {
    final raw = await channel.invokeMethod<String>('unlock');
    if (raw == null) {
      throw PlatformException(
        code: 'cancelled',
        message: 'No se completó el acceso biométrico.',
      );
    }
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  static Future<void> clear() async {
    await channel.invokeMethod('clear');
  }
}
