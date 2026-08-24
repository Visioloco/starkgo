import 'dart:convert';

import 'package:cryptography/cryptography.dart';

// ══════════════════════════════════════════════════════════════
//  WireGuardKeygen — genera el par de claves (X25519/Curve25519)
//  que usa WireGuard, directamente en el dispositivo.
//
//  · privateKey → base64 32 bytes (se guarda en vpn_config/{uid})
//  · publicKey  → base64 32 bytes (se agrega como Peer en el MikroTik)
// ══════════════════════════════════════════════════════════════

class WireGuardKeyPair {
  const WireGuardKeyPair({required this.privateKey, required this.publicKey});

  final String privateKey;
  final String publicKey;
}

class WireGuardKeygen {
  /// Clave WireGuard = 32 bytes en base64 → 44 caracteres terminando en '='.
  static final RegExp _claveRegex = RegExp(r'^[A-Za-z0-9+/]{43}=$');

  static bool esClaveValida(String clave) => _claveRegex.hasMatch(clave.trim());

  /// Genera un par de claves nuevo.
  static Future<WireGuardKeyPair> generarParClaves() async {
    final x25519 = X25519();
    final keyPair = await x25519.newKeyPair();
    final privateBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    return WireGuardKeyPair(
      privateKey: base64Encode(privateBytes),
      publicKey: base64Encode(publicKey.bytes),
    );
  }

  /// Deriva la clave pública a partir de una privada existente.
  /// Devuelve null si la privada no es válida.
  static Future<String?> derivarPublica(String privateKeyB64) async {
    final priv = privateKeyB64.trim();
    if (!esClaveValida(priv)) return null;
    try {
      final x25519 = X25519();
      final keyPair = await x25519.newKeyPairFromSeed(base64Decode(priv));
      final publicKey = await keyPair.extractPublicKey();
      return base64Encode(publicKey.bytes);
    } catch (_) {
      return null;
    }
  }
}
