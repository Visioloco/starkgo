import 'vpn_foreground.dart';

// ══════════════════════════════════════════════════════════════
//  Stub para web / plataformas sin dart:io.
//  Mantiene compilable el build web: el canal nativo solo existe en Android.
// ══════════════════════════════════════════════════════════════

/// Fábrica seleccionada por el import condicional en vpn_foreground.dart.
VpnForegroundBridge createBridge() => VpnForegroundBridgeStub();

class VpnForegroundBridgeStub implements VpnForegroundBridge {
  @override
  Stream<String> get actions => const Stream.empty();

  @override
  Future<bool> start() async => true;

  @override
  Future<bool> stop() async => true;

  @override
  Future<void> setTunnelActive(bool active) async {}
}
