import 'dart:io' show NetworkInterface, InternetAddressType;

import 'package:flutter/foundation.dart';

// ══════════════════════════════════════════════════════════════
//  IPs IPv4 de ESTE teléfono (Android / iOS / escritorio).
//
//  Sirve para saber con qué IP ve el MikroTik al teléfono — la del Wi-Fi, la
//  de datos o la del túnel WireGuard (que también aparece como interfaz) — y
//  así blindarlo en el hotspot sin que el operador la escriba a mano.
// ══════════════════════════════════════════════════════════════
Future<List<String>> ipsLocalesDelTelefono() async {
  try {
    final listas = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
    final ips = <String>[];
    for (final l in listas) {
      for (final a in l.addresses) {
        final ip = a.address.trim();
        if (ip.isEmpty) continue;
        if (ip.startsWith('169.254.')) continue; // link-local (no sirve)
        ips.add(ip);
      }
    }
    return ips.toSet().toList();
  } catch (e) {
    debugPrint('[Blindaje] No pude leer las IPs del teléfono: $e');
    return const [];
  }
}
