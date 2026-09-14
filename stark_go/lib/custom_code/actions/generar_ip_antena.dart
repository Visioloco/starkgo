// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

/// Genera la próxima IP de antena disponible **dentro de la red local real**
/// del operador, para que la antena coincida con su MikroTik.
///
/// Orden de prioridad para la subred:
///   1. `config_mikrotik/{uid}.subredLocal` → la red declarada por el usuario
///      (ej. "192.168.10.0/24"), que el VPS ya expone por el túnel.
///   2. `vpn_config/{uid}.redAntenas` → la subred asignada por el VPS
///      (ej. "10.10.15.0/24").
///   3. Fallback histórico: rango 192.168.10.3 – 192.168.10.30.
///
/// Se excluye la IP del MikroTik / puerta de enlace (`config_mikrotik.ipLocal`)
/// y nunca repite una IP ya usada en `clientes.ipatn` / `sectoriales.ip`.
Future<String> generarIpAntena() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;

  // ── 1) Subred base (la red real del usuario, si la declaró) ──
  String? cidr;
  String? gateway;
  try {
    if (uid != null) {
      final cfg = await FirebaseFirestore.instance
          .collection('config_mikrotik')
          .doc(uid)
          .get();
      final d = cfg.data();
      if (d != null) {
        final s = (d['subredLocal'] ?? '').toString().trim();
        if (_cidrValido(s)) cidr = s;
        final ip = (d['ipLocal'] ?? '').toString().trim();
        if (_ipv4Valida(ip)) gateway = ip;
      }
      if (cidr == null) {
        final vpn = await FirebaseFirestore.instance
            .collection('vpn_config')
            .doc(uid)
            .get();
        final r = (vpn.data()?['redAntenas'] ?? '').toString().trim();
        if (_cidrValido(r)) cidr = r;
      }
    }
  } catch (_) {
    // Sin conexión: seguimos con el fallback de abajo.
  }

  // ── 2) IPs ya usadas (antenas de clientes + sectoriales) ──
  final Set<String> ipsUsadas = <String>{};
  try {
    final clientes =
        await FirebaseFirestore.instance.collection('clientes').get();
    for (final d in clientes.docs) {
      final ip = (d.data()['ipatn'] ?? '').toString().trim();
      if (ip.isNotEmpty) ipsUsadas.add(ip);
    }
    final sectoriales =
        await FirebaseFirestore.instance.collection('sectoriales').get();
    for (final d in sectoriales.docs) {
      final ip = (d.data()['ip'] ?? '').toString().trim();
      if (ip.isNotEmpty) ipsUsadas.add(ip);
    }
  } catch (_) {
    // Si no se puede leer, seguimos con el set vacío.
  }

  // ── 3) Primera IP libre dentro de la subred real ──
  if (cidr != null) {
    final partes = cidr.split('/').first.trim().split('.');
    for (int i = 2; i <= 254; i++) {
      final candidata = '${partes[0]}.${partes[1]}.${partes[2]}.$i';
      // No pisar la puerta de enlace / IP del MikroTik.
      if (gateway != null && candidata == gateway) continue;
      if (!ipsUsadas.contains(candidata)) return candidata;
    }
    throw Exception('No hay IPs libres en $cidr. '
        'Liberá alguna antena o ampliá tu subred local.');
  }

  // ── 4) Fallback histórico (sin subred declarada ni asignada) ──
  const String base = '192.168.10.';
  const int rangoInicio = 3;
  const int rangoFin = 30;
  for (int i = rangoInicio; i <= rangoFin; i++) {
    final String candidata = '$base$i';
    if (!ipsUsadas.contains(candidata)) {
      return candidata;
    }
  }

  // ── Si todas están ocupadas, lanzar error descriptivo ──
  throw Exception(
    'No hay IPs disponibles en el rango $base$rangoInicio - $base$rangoFin. '
    'Todas las ${rangoFin - rangoInicio + 1} IPs están en uso. '
    'Declará tu subred local en Config. MikroTik para ampliar el rango.',
  );
}

// ── Helpers de validación ──

/// true si `s` es una IPv4 válida (a.b.c.d con octetos 0-255).
bool _ipv4Valida(String s) {
  final p = s.trim().split('.');
  if (p.length != 4) return false;
  for (final o in p) {
    final n = int.tryParse(o);
    if (n == null || n < 0 || n > 255) return false;
  }
  return true;
}

/// true si `s` es un CIDR válido con prefijo 16..30 (ej. "192.168.10.0/24").
bool _cidrValido(String s) {
  final c = s.trim();
  final i = c.indexOf('/');
  if (i <= 0) return false;
  final pref = int.tryParse(c.substring(i + 1).trim());
  return _ipv4Valida(c.substring(0, i)) && pref != null && pref >= 16 && pref <= 30;
}
// Set your action name, define your arguments and return parameter,
// and then add the code required for your action below.
