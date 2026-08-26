import 'package:flutter/services.dart';

/// Jembatan Flutter <-> Android native untuk LAN broadcasting.
/// Saat user tap JOIN, world remote "diiklankan" sebagai world LAN lokal.
class LanBridge {
  static const _channel = MethodChannel('mc_hub/lan');

  /// Mulai broadcast world remote di jaringan lokal.
  /// Setelah ini, buka Minecraft -> tab World/LAN -> world muncul!
  static Future<bool> startBroadcast({
    required String name,
    required String ip,
    required int port,
    int players = 0,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('startBroadcast', {
        'name': name,
        'ip': ip,
        'port': port,
        'players': players,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Hentikan broadcast (hilangkan dari tab LAN).
  static Future<void> stopBroadcast() async {
    try {
      await _channel.invokeMethod('stopBroadcast');
    } on PlatformException {}
  }

  /// Cek apakah sedang broadcast
  static Future<bool> get isBroadcasting async {
    try {
      return await _channel.invokeMethod<bool>('isBroadcasting') ?? false;
    } on PlatformException {
      return false;
    }
  }
}
