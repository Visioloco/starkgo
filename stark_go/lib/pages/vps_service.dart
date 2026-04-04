import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:flutter/material.dart';

class VpsService {
  static const String _base = 'http://5.161.88.42:3000';

  // Cache de apikey para no leer Firestore en cada llamada
  static String? _apikeyCache;

  /// Obtiene la apikey del usuario desde Firestore (con cache)
  static Future<String?> getApikey() async {
    if (_apikeyCache != null) return _apikeyCache;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;
      final doc = await FirebaseFirestore.instance.collection('config_mikrotik').doc(uid).get();
      if (!doc.exists) {
        debugPrint('[VPS] Usuario sin Config MikroTik. Debe configurarlo primero.');
        return null;
      }
      _apikeyCache = doc.data()?['vpsApiKey'] as String?;
      return _apikeyCache;
    } catch (e) {
      debugPrint('[VPS] Error obteniendo apikey: $e');
      return null;
    }
  }

  /// Llama al cerrar sesión para limpiar el cache
  static void limpiarCache() => _apikeyCache = null;

  /// Llamada HTTP al VPS con 3 reintentos automáticos
  static Future<bool> _post(String endpoint, Map<String, dynamic> body) async {
    final apikey = await getApikey();
    if (apikey == null) return false;

    for (int i = 1; i <= 3; i++) {
      try {
        final res = await http
            .post(
              Uri.parse('$_base$endpoint'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({...body, 'apikey': apikey}),
            )
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) return true;
        debugPrint('[VPS] Error $endpoint intento $i: ${res.body}');
      } catch (e) {
        debugPrint('[VPS] Fallo $endpoint intento $i: $e');
        if (i < 3) await Future.delayed(const Duration(seconds: 2));
      }
    }
    return false;
  }

  /// Llamar al CREAR un cliente nuevo
  static Future<void> clienteCreado({
    required String nombre,
    required String ip,
    required String velocidad, // formato "subida/bajada" ej: "2M/10M"
  }) async {
    if (ip.isEmpty || velocidad.isEmpty) return;
    final partes = velocidad.split('/');
    if (partes.length != 2) return;
    await _post('/limitar', {
      'ip': ip,
      'nombre': nombre,
      'subida': partes[0].trim(),
      'bajada': partes[1].trim(),
    });
  }

  /// Llamar al CAMBIAR STATUS (mora → bloquea, activo → desbloquea)
  static Future<void> cambiarStatus({
    required String status,
    required String ip,
    required String nombre,
  }) async {
    if (status == 'mora') {
      await _post('/bloquear', {'ip': ip, 'nombre': nombre});
    } else if (status == 'activo') {
      await _post('/desbloquear', {'nombre': nombre});
    }
  }

  /// Llamar al ACTUALIZAR MEGAS de un cliente existente
  static Future<void> actualizarMegas({
    required String ip,
    required String nombre,
    required String velocidad,
  }) async {
    if (ip.isEmpty || velocidad.isEmpty) return;
    final partes = velocidad.split('/');
    if (partes.length != 2) return;
    await _post('/limitar', {
      'ip': ip,
      'nombre': nombre,
      'subida': partes[0].trim(),
      'bajada': partes[1].trim(),
    });
  }
}
