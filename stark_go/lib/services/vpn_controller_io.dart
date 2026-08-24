import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';

import 'vpn_controller.dart';

// ══════════════════════════════════════════════════════════════
//  Implementación real del controlador VPN (Android / iOS / desktop)
//  Usa el plugin `wireguard_flutter` (plataformas Android/iOS).
// ══════════════════════════════════════════════════════════════

/// Fábrica seleccionada por el import condicional en vpn_controller.dart.
VpnControllerPlatform createVpnController() => VpnControllerImpl();

class VpnControllerImpl implements VpnControllerPlatform {
  static const String _interfaceName = 'wg0';
  static const String _bundleIdAndroid = 'com.starkgo.net.cardenCode';
  static const String _bundleIdIosExtension = 'com.starkgo.net.cardenCode.WGExtension';

  // ⚠️ iOS: el túnel necesita el target "Network Extension" (Packet Tunnel
  // Provider) configurado en Xcode ANTES de habilitar iOS. Mientras esté en
  // `false`, la app usa WireGuard solo en Android y la UI muestra un aviso.
  // Cambiar a `true` SOLO cuando el paso "iOS / Xcode" de VPN_INSTRUCCIONES.md
  // esté completo.
  static const bool _iosNetworkExtensionConfigurado = false;

  bool _initialized = false;

  final StreamController<VpnStatus> _statusController =
      StreamController<VpnStatus>.broadcast();
  VpnStatus _currentStatus = VpnStatus.disconnected;
  StreamSubscription<VpnStage>? _stageSubscription;

  @override
  String get providerBundleIdentifier {
    if (Platform.isIOS && _iosNetworkExtensionConfigurado) {
      return _bundleIdIosExtension;
    }
    return _bundleIdAndroid;
  }

  @override
  bool get isSupportedPlatform => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  bool get needsExtraSetup => Platform.isIOS && !_iosNetworkExtensionConfigurado;

  @override
  String? get setupNote {
    if (!needsExtraSetup) return null;
    return 'En iOS el túnel necesita el target Network Extension '
        '(Packet Tunnel Provider) en Xcode. Mientras tanto usá Android. '
        'Detalle: VPN_INSTRUCCIONES.md';
  }

  @override
  String get unsupportedMessage =>
      'La VPN WireGuard está disponible solo en Android e iOS.';

  @override
  Stream<VpnStatus> get statusStream => _statusController.stream;

  // ══════════════════════════════════════════════════════════
  //  initialize() — crea la interfaz wg0 y escucha el estado
  // ══════════════════════════════════════════════════════════
  @override
  Future<void> initialize() async {
    if (kIsWeb) throw UnsupportedError(unsupportedMessage);
    if (_initialized) return;

    await WireGuardFlutter.instance.initialize(interfaceName: _interfaceName);

    _stageSubscription ??= WireGuardFlutter.instance.vpnStageSnapshot
        .listen((stage) => _setStatus(_mapStage(stage)));

    // Estado inicial real (puede seguir conectado de una sesión anterior).
    _setStatus(_mapStage(await WireGuardFlutter.instance.stage()));
    _initialized = true;
    debugPrint('[VpnControllerImpl] Interfaz $_interfaceName inicializada.');
  }

  // ══════════════════════════════════════════════════════════
  //  start() — levanta el túnel con la config ya parseada
  // ══════════════════════════════════════════════════════════
  @override
  Future<StartVpnResult> start(VpnConfig config) async {
    if (kIsWeb) {
      return const StartVpnResult.fail(
        StartVpnResultKind.unsupported,
        'Plataforma no soportada.',
      );
    }
    if (needsExtraSetup) {
      return const StartVpnResult.fail(
        StartVpnResultKind.error,
        'iOS requiere configurar el Network Extension en Xcode primero. '
        'Ver VPN_INSTRUCCIONES.md',
      );
    }
    try {
      if (!_initialized) await initialize();

      // ┌─────────────────────────────────────────────────────────────┐
      // │  iOS — Network Extension (WireGuardKit + Packet Tunnel      │
      // │  Provider). Este es el flujo que requiere configuración     │
      // │  adicional en Xcode (se hace por separado). Cuando          │
      // │  _iosNetworkExtensionConfigurado = true, wireguard_flutter  │
      // │  usa providerBundleIdentifier = "...WGExtension" y entrega  │
      // │  el wgQuickConfig vía NETunnelProviderProtocol.providerConf-│
      // │  iguration, que el extension "PacketTunnelProvider.swift"   │
      // │  parsea con WireGuardKit (TunnelConfiguration(fromWgQuick-  │
      // │  Config:)). No se requiere ningún cambio aquí: el plugin    │
      // │  gestiona NEVPNManager por nosotros.                        │
      // └─────────────────────────────────────────────────────────────┘
      await WireGuardFlutter.instance.startVpn(
        serverAddress: config.serverAddress,
        wgQuickConfig: config.wgQuickConfig,
        providerBundleIdentifier: config.providerBundleIdentifier,
      );

      // startVpn no dispara el stream en todos los casos; forzamos refresh.
      final stage = await WireGuardFlutter.instance.stage();
      _setStatus(_mapStage(stage));
      return const StartVpnResult.ok();
    } catch (e) {
      _setStatus(VpnStatus.error);
      debugPrint('[VpnControllerImpl] Error iniciando túnel: ${e.runtimeType}');
      return StartVpnResult.fail(
        StartVpnResultKind.error,
        'No se pudo iniciar el túnel (revisá que el permiso VPN esté aceptado '
        'y que el endpoint sea alcanzable).',
      );
    }
  }

  // ══════════════════════════════════════════════════════════
  //  stop() — baja el túnel
  // ══════════════════════════════════════════════════════════
  @override
  Future<void> stop() async {
    try {
      await WireGuardFlutter.instance.stopVpn();
    } catch (e) {
      debugPrint('[VpnControllerImpl] Error deteniendo túnel: ${e.runtimeType}');
    }
    _setStatus(VpnStatus.disconnected);
  }

  // ══════════════════════════════════════════════════════════
  //  status() — estado actual
  // ══════════════════════════════════════════════════════════
  @override
  Future<VpnStatus> status() async {
    if (!_initialized) return _currentStatus;
    try {
      final stage = await WireGuardFlutter.instance.stage();
      _setStatus(_mapStage(stage));
    } catch (_) {}
    return _currentStatus;
  }

  // ── Mapeo de VpnStage (plugin) → VpnStatus (UI) ──────────────
  VpnStatus _mapStage(VpnStage stage) {
    switch (stage) {
      case VpnStage.connected:
        return VpnStatus.connected;
      case VpnStage.connecting:
      case VpnStage.preparing:
      case VpnStage.waitingConnection:
      case VpnStage.authenticating:
      case VpnStage.reconnect:
        return VpnStatus.connecting;
      case VpnStage.disconnecting:
      case VpnStage.exiting:
        return VpnStatus.disconnecting;
      case VpnStage.denied:
        return VpnStatus.error;
      case VpnStage.disconnected:
      case VpnStage.noConnection:
        return VpnStatus.disconnected;
    }
  }

  void _setStatus(VpnStatus status) {
    _currentStatus = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  /// Libera recursos (llamar al salir de la app si se desea).
  void dispose() {
    _stageSubscription?.cancel();
    _statusController.close();
  }
}

// ══════════════════════════════════════════════════════════════
//  FLUJO iOS PREPARADO (WireGuardKit + Packet Tunnel Provider)
//  ══════════════════════════════════════════════════════════════
//  Este bloque documenta los pasos que se deben completar en Xcode
//  para habilitar iOS. NO modifica nada del código Dart actual.
//
//  1) Crear un target "App Extension" → "Packet Tunnel Provider"
//     llamado `WGExtension`, con bundle id:
//        com.starkgo.net.cardenCode.WGExtension
//     (debe coincidir con `_bundleIdIosExtension`).
//
//  2) En el proyecto, agregar el pod WireGuardKit (Swift Package:
//     https://github.com/wireguard/wireguard-apple) al target
//     WGExtension.
//
//  3) WGExtension/Info.plist:
//        NSExtensionPointIdentifier = com.apple.networkextension.packet-tunnel
//        NSExtensionPrincipalClass  = $(PRODUCT_MODULE_NAME).PacketTunnelProvider
//
//  4) WGExtension/entitlements:
//        com.apple.developer.networking.networkextension = [packet-tunnel-provider]
//        com.apple.security.application-groups = [group.com.starkgo.net.cardenCode]
//
//  5) Runner/entitlements (mismo application-group + networkextension).
//
//  6) WGExtension/PacketTunnelProvider.swift:
//     ```swift
//     import Foundation
//     import NetworkExtension
//     import WireGuardKit
//
//     class PacketTunnelProvider: NEPacketTunnelProvider {
//       private lazy var adapter = WireGuardAdapter(with: self) { _, m in NSLog(m) }
//       override func startTunnel(options: [String: NSObject]?,
//                                 completionHandler: @escaping (Error?) -> Void) {
//         guard let pc = protocolConfiguration as? NETunnelProviderProtocol,
//               let cfg = pc.providerConfiguration?["wgQuickConfig"] as? String,
//               let tunnel = try? TunnelConfiguration(fromWgQuickConfig: cfg) else {
//           completionHandler(NSError(domain: "wg", code: 1)); return
//         }
//         adapter.start(tunnelConfiguration: tunnel) { error in
//           completionHandler(error)
//         }
//       }
//       override func stopTunnel(with reason: NEProviderStopReason,
//                                completionHandler: @escaping () -> Void) {
//         adapter.stop { _ in completionHandler() }
//       }
//     }
//     ```
//
//  7) En vpn_controller_io.dart poner `_iosNetworkExtensionConfigurado = true`.
//
//  El plugin wireguard_flutter (lado Dart) ya entrega `providerBundleIdentifier`
//  = "...WGExtension" y el wgQuickConfig completo; con el target creado,
//  `startVpn` funciona igual que en Android sin más cambios en la app.

