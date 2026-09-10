import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'vpn_foreground.dart';

// ══════════════════════════════════════════════════════════════
//  Implementación real (Android / iOS).
//  En Android habla con VpnForegroundPlugin (Kotlin) que gestiona
//  el Foreground Service y el Tile de Ajustes Rápidos.
// ══════════════════════════════════════════════════════════════

/// Fábrica seleccionada por el import condicional en vpn_foreground.dart.
VpnForegroundBridge createBridge() => VpnForegroundBridgeImpl();

class VpnForegroundBridgeImpl implements VpnForegroundBridge {
  static const MethodChannel _channel = MethodChannel(
    'com.starkgo.net.cardenCode/vpn_foreground',
  );
  static const EventChannel _events = EventChannel(
    'com.starkgo.net.cardenCode/vpn_foreground/events',
  );

  Stream<String>? _actions;

  bool get _esAndroid => !kIsWeb && Platform.isAndroid;

  @override
  Stream<String> get actions {
    if (!_esAndroid) return const Stream.empty();
    return _actions ??= _events
        .receiveBroadcastStream()
        .map((event) => event.toString());
  }

  @override
  Future<bool> start() => _invoke('start');

  @override
  Future<bool> stop() => _invoke('stop');

  @override
  Future<void> setTunnelActive(bool active) =>
      _invoke('setTunnelActive', active);

  /// true si el canal respondió sin excepción (o si no aplica, p. ej. iOS).
  Future<bool> _invoke(String method, [Object? arguments]) async {
    if (!_esAndroid) return true;
    try {
      await _channel.invokeMethod<void>(method, arguments);
      debugPrint('[VpnForeground] OK nativo: "$method"');
      return true;
    } catch (e) {
      debugPrint('[VpnForeground] Error nativo en "$method": $e');
      return false;
    }
  }
}
