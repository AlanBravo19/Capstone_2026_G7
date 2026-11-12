import 'package:flutter/services.dart';

import 'dart:convert';

class TripService {
  static const channel = MethodChannel('cl.rutaalerta/trayecto');
  static Future<void> start({
    List<dynamic> avisos = const [],
    DateTime? cacheHasta,
  }) => channel.invokeMethod<void>('start', {
    'alerts': jsonEncode({
      'avisos': avisos,
      'cacheUntil': cacheHasta?.millisecondsSinceEpoch ?? 0,
    }),
  });
  static Future<void> stop() => channel.invokeMethod<void>('stop');
  static Future<Map<String, dynamic>> status() async {
    final result = await channel.invokeMapMethod<String, dynamic>('status');
    return result ?? {'running': false};
  }
}
