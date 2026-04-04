// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

/// Genera la próxima IP de antena disponible en rango 192.168.10.3 - 192.168.10.30
/// Revisa Firestore para no repetir IPs ya usadas.
Future<String> generarIpAntena() async {
  // ── Rango permitido ──
  const String base = '192.168.10.';
  const int rangoInicio = 3;
  const int rangoFin = 30;

  // ── Obtener todas las IPs ya usadas en Firestore ──
  final snapshot = await FirebaseFirestore.instance.collection('clientes').get();

  final Set<String> ipsUsadas = snapshot.docs.map((doc) => (doc.data()['ipatn'] ?? '') as String).where((ip) => ip.isNotEmpty).toSet();

  // ── Buscar la primera IP disponible en el rango ──
  for (int i = rangoInicio; i <= rangoFin; i++) {
    final String candidata = '$base$i';
    if (!ipsUsadas.contains(candidata)) {
      return candidata;
    }
  }

  // ── Si todas están ocupadas, lanzar error descriptivo ──
  throw Exception(
    'No hay IPs disponibles en el rango $base$rangoInicio - $base$rangoFin. '
    'Todas las ${rangoFin - rangoInicio + 1} IPs están en uso.',
  );
}
// Set your action name, define your arguments and return parameter,
// and then add the code required for your action below.
