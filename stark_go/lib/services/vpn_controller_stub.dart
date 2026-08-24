import 'dart:async';

import 'vpn_controller.dart';

// ══════════════════════════════════════════════════════════════
//  Stub para web / plataformas sin dart:io.
//  Mantiene compilable el build web: wireguard_flutter solo se
//  importa en vpn_controller_io.dart (no compilado en web).
// ══════════════════════════════════════════════════════════════

/// Fábrica seleccionada por el import condicional en vpn_controller.dart.
VpnControllerPlatform createVpnController() => VpnControllerStub();

class VpnControllerStub implements VpnControllerPlatform {
  @override
  bool get isSupportedPlatform => false;

  @override
  String get unsupportedMessage =>
      'El túnel WireGuard no está disponible en la web. Usá la app en Android o iOS.';

  @override
  bool get needsExtraSetup => false;

  @override
  String? get setupNote => null;

  @override
  String get providerBundleIdentifier => '';

  @override
  Stream<VpnStatus> get statusStream => const Stream.empty();

  @override
  Future<void> initialize() async => throw UnsupportedError(unsupportedMessage);

  @override
  Future<VpnStatus> status() async => VpnStatus.disconnected;

  @override
  Future<StartVpnResult> start(VpnConfig config) async =>
      StartVpnResult.fail(StartVpnResultKind.unsupported, unsupportedMessage);

  @override
  Future<void> stop() async {}
}
