import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// ══════════════════════════════════════════════════════════════
//  Import condicional de plataforma:
//    - Web  → vpn_controller_stub.dart (sin plugin, no rompe el build web)
//    - IO (Android/iOS/desktop) → vpn_controller_io.dart (wireguard_flutter)
// ══════════════════════════════════════════════════════════════
import 'vpn_controller_stub.dart'
    if (dart.library.io) 'vpn_controller_io.dart' as impl;

// ══════════════════════════════════════════════════════════════
//  Tipos compartidos (independientes de la plataforma)
// ══════════════════════════════════════════════════════════════

/// Estados simplificados del túnel para la UI.
enum VpnStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

enum StartVpnResultKind { ok, error, noAuth, noConfig, unsupported }

class StartVpnResult {
  const StartVpnResult.ok()
      : kind = StartVpnResultKind.ok,
        errorMessage = null;

  const StartVpnResult.fail(this.kind, [this.errorMessage]);

  final StartVpnResultKind kind;
  final String? errorMessage;

  bool get ok => kind == StartVpnResultKind.ok;
}

/// Configuración del túnel WireGuard ya parseada (solo en memoria).
class VpnConfig {
  const VpnConfig({
    required this.wgQuickConfig,
    required this.serverAddress,
    required this.providerBundleIdentifier,
  });

  final String wgQuickConfig;
  final String serverAddress;
  final String providerBundleIdentifier;

  /// Representación SEGURA para logs: nunca expone la private key.
  String toDebugString() {
    final pk = RegExp(r'PrivateKey\s*=\s*([^\s]+)')
            .firstMatch(wgQuickConfig)
            ?.group(1) ??
        '';
    return 'VpnConfig(server=$serverAddress, conf.length=${wgQuickConfig.length}, '
        'privateKey=${_mask(pk)})';
  }

  static String _mask(String s) =>
      s.length < 8 ? '***' : '${s.substring(0, 4)}…${s.substring(s.length - 4)}';
}

/// Contrato de la implementación por plataforma.
abstract class VpnControllerPlatform {
  bool get isSupportedPlatform;
  String get unsupportedMessage;

  /// true cuando la plataforma requiere setup extra aún no hecho (iOS).
  bool get needsExtraSetup;
  String? get setupNote;
  String get providerBundleIdentifier;

  Stream<VpnStatus> get statusStream;

  Future<void> initialize();
  Future<VpnStatus> status();
  Future<StartVpnResult> start(VpnConfig config);
  Future<void> stop();
}

// ══════════════════════════════════════════════════════════════
//  VpnController — fachada usada por la UI
// ══════════════════════════════════════════════════════════════
class VpnController {
  VpnController._();

  static final VpnController instance = VpnController._();

  final VpnControllerPlatform _impl = impl.createVpnController();

  static const String _coleccionConfig = 'vpn_config';

  // ── Delegación a la implementación de plataforma ──────────────
  bool get isSupportedPlatform => _impl.isSupportedPlatform;
  String get unsupportedMessage => _impl.unsupportedMessage;
  bool get needsExtraSetup => _impl.needsExtraSetup;
  String? get setupNote => _impl.setupNote;
  String get providerBundleIdentifier => _impl.providerBundleIdentifier;

  Stream<VpnStatus> get statusStream => _impl.statusStream;

  /// Inicializa la interfaz WireGuard (idempotente).
  Future<void> initialize() => _impl.initialize();

  Future<VpnStatus> status() => _impl.status();

  Future<void> stop() => _impl.stop();

  // ── Carga segura de la configuración desde Firestore ──────────
  /// Lee `vpn_config/{uid}`. No loguea ningún valor sensible.
  Future<Map<String, dynamic>?> loadTunnelConfig() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('[VpnController] Sin usuario autenticado.');
      return null;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_coleccionConfig)
          .doc(uid)
          .get();
      if (!doc.exists) return null;
      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[VpnController] Error leyendo vpn_config: ${e.runtimeType}');
      return null;
    }
  }

  /// Arranca el túnel: carga config → parsea → delega a la plataforma.
  Future<StartVpnResult> start() async {
    if (!isSupportedPlatform) {
      return const StartVpnResult.fail(
        StartVpnResultKind.unsupported,
        'Plataforma no soportada.',
      );
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const StartVpnResult.fail(
        StartVpnResultKind.noAuth,
        'Inicia sesión para usar la VPN.',
      );
    }
    final config = parseTunnelConfig(
      await loadTunnelConfig(),
      bundleId: providerBundleIdentifier,
    );
    if (config == null) {
      return const StartVpnResult.fail(
        StartVpnResultKind.noConfig,
        'No se encontró configuración del túnel. Crea el documento '
        'vpn_config/<uid> en Firestore.',
      );
    }
    debugPrint('[VpnController] Iniciando túnel… ${config.toDebugString()}');
    return _impl.start(config);
  }

  /// Parsea el doc de Firestore. Soporta dos formatos:
  ///   1. `wgQuickConfig` (string con [Interface]+[Peer] completo).
  ///   2. Campos sueltos: privateKey, address, dns, peerPublicKey,
  ///      allowedIps, endpoint, persistentKeepalive.
  /// Devuelve null si falta algo. La private key SOLO existe en memoria.
  VpnConfig? parseTunnelConfig(
    Map<String, dynamic>? data, {
    required String bundleId,
  }) {
    if (data == null) return null;

    // Formato 1: wg-quick completo.
    final wgQuick = (data['wgQuickConfig'] ?? '').toString().trim();
    if (wgQuick.isNotEmpty) {
      final minimo = wgQuick.contains('[Interface]') &&
          wgQuick.contains('PrivateKey') &&
          wgQuick.contains('[Peer]') &&
          wgQuick.contains('PublicKey');
      final endpoint = _extraerEndpoint(wgQuick);
      if (!minimo || endpoint == null) return null;
      return VpnConfig(
        wgQuickConfig: wgQuick,
        serverAddress: endpoint,
        providerBundleIdentifier: bundleId,
      );
    }

    // Formato 2: campos sueltos.
    final privateKey = (data['privateKey'] ?? '').toString().trim();
    final address = (data['address'] ?? '').toString().trim();
    final peerPublicKey = (data['peerPublicKey'] ?? '').toString().trim();
    final allowedIps = (data['allowedIps'] ?? '').toString().trim();
    final endpoint = (data['endpoint'] ?? '').toString().trim();
    if (privateKey.isEmpty ||
        address.isEmpty ||
        peerPublicKey.isEmpty ||
        allowedIps.isEmpty ||
        endpoint.isEmpty) {
      return null;
    }

    final dns = (data['dns'] ?? '').toString().trim();
    final keepalive = (data['persistentKeepalive'] ?? 25).toString().trim();

    final buf = StringBuffer()
      ..writeln('[Interface]')
      ..writeln('PrivateKey = $privateKey')
      ..writeln('Address = $address');
    if (dns.isNotEmpty) buf.writeln('DNS = $dns');
    buf
      ..writeln()
      ..writeln('[Peer]')
      ..writeln('PublicKey = $peerPublicKey')
      ..writeln('AllowedIPs = $allowedIps')
      ..writeln('Endpoint = $endpoint')
      ..writeln('PersistentKeepalive = $keepalive');

    return VpnConfig(
      wgQuickConfig: buf.toString(),
      serverAddress: endpoint,
      providerBundleIdentifier: bundleId,
    );
  }

  String? _extraerEndpoint(String wgQuick) {
    for (final line in wgQuick.split('\n')) {
      final t = line.trim().toLowerCase();
      if (t.startsWith('endpoint')) {
        final v = line.substring(line.indexOf('=') + 1).trim();
        if (v.isNotEmpty) return v;
      }
    }
    return null;
  }
}

