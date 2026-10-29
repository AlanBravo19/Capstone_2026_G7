import 'package:flutter/services.dart';

class TripService {
  static const channel = MethodChannel('cl.rutaalerta/trayecto');
  static Future<void> start() => channel.invokeMethod<void>('start');
  static Future<void> stop() => channel.invokeMethod<void>('stop');
  static Future<Map<String, dynamic>> status() async {
    final result = await channel.invokeMapMethod<String, dynamic>('status');
    return result ?? {'running': false};
  }
}
