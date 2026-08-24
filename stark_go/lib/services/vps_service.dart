import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

// ══════════════════════════════════════════════════════════════
//  VpsService  v2.1  — incluye soporte PPPoE
//  Lee la configuracion desde config_mikrotik/{uid} en Firestore
// ══════════════════════════════════════════════════════════════

class VpsService {
  static const String _baseUrl = 'http://5.161.88.42:3000';
  static const String _coleccion = 'config_mikrotik';

  // ══════════════════════════════════════════════════════════
  //  OBTENER CONFIG
  // ══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> obtenerConfig() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('[VpsService] Sin usuario autenticado.');
      return null;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection(_coleccion).doc(uid).get();
      if (!doc.exists) {
        debugPrint('[VpsService] config_mikrotik/$uid no existe.');
        return null;
      }
      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[VpsService] Error leyendo config_mikrotik: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  CAMBIAR STATUS (bloquear / desbloquear)
  // ══════════════════════════════════════════════════════════
  static bool _procesando = false;

  static Future<void> cambiarStatus({
    required String status,
    required String ip,
    required String nombre,
  }) async {
    if (_procesando) return;
    if (status != 'mora' && status != 'activo') return;
    _procesando = true;
    try {
      final config = await obtenerConfig();
      if (config == null) return;
      final String apiKey = (config['vpsApiKey'] ?? '').toString();
      if (apiKey.isEmpty) return;
      final bool bloquear = status == 'mora';
      final Map<String, dynamic> body = {'apikey': apiKey, 'nombre': nombre};
      if (ip.isNotEmpty) body['ip'] = ip;
      await _post(bloquear ? '/bloquear' : '/desbloquear', body);
    } finally {
      _procesando = false;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  CLIENTE CREADO (queue simple por IP)
  // ══════════════════════════════════════════════════════════
  static Future<void> clienteCreado({
    required String nombre,
    required String ip,
    required String velocidad,
  }) async {
    if (ip.isEmpty || velocidad.isEmpty) return;
    final config = await obtenerConfig();
    if (config == null) return;
    final String apiKey = (config['vpsApiKey'] ?? '').toString();
    if (apiKey.isEmpty) return;

    final partes = velocidad.split('/');
    final String bajada = partes.isNotEmpty ? partes[0].trim() : velocidad;
    final String subida = partes.length > 1 ? partes[1].trim() : bajada;

    await _post('/limitar', {
      'apikey': apiKey,
      'accion': 'limitarMegas',
      'ip': ip,
      'nombre': nombre,
      'bajada': bajada,
      'subida': subida,
    });
  }

  // ══════════════════════════════════════════════════════════
  //  PPPOE CREAR
  //  Crea (o actualiza) un secreto PPPoE + perfil con rate-limit
  //  en el MikroTik via la cola del VPS.
  //
  //  Parametros:
  //    usuario   → nombre del secreto PPPoE (sin espacios)
  //    clave     → password PPPoE
  //    nombre    → nombre visible / comentario del cliente
  //    subida    → velocidad subida  ej: "5M"
  //    bajada    → velocidad bajada  ej: "10M"
  //    perfil    → (opcional) nombre del perfil PPPoE;
  //                si se omite el VPS genera "starkgo_{usuario}"
  //
  //  Retorna true si el VPS respondio OK, false si hubo error.
  // ══════════════════════════════════════════════════════════
  static Future<bool> pppoeCrear({
    required String usuario,
    required String clave,
    required String nombre,
    required String subida,
    required String bajada,
    String? perfil,
  }) async {
    if (usuario.isEmpty || clave.isEmpty || subida.isEmpty || bajada.isEmpty) {
      debugPrint('[VpsService] pppoeCrear — faltan datos, omitido.');
      return false;
    }
    final config = await obtenerConfig();
    if (config == null) return false;
    final String apiKey = (config['vpsApiKey'] ?? '').toString();
    if (apiKey.isEmpty) return false;

    final Map<String, dynamic> body = {
      'apikey': apiKey,
      'usuario': usuario,
      'clave': clave,
      'nombre': nombre,
      'subida': subida,
      'bajada': bajada,
    };
    if (perfil != null && perfil.isNotEmpty) body['perfil'] = perfil;

    return await _post('/pppoe-crear', body);
  }

  // ══════════════════════════════════════════════════════════
  //  PPPOE ELIMINAR
  //  Encola la eliminacion del secreto PPPoE en MikroTik.
  //
  //  Retorna true si el VPS respondio OK.
  // ══════════════════════════════════════════════════════════
  static Future<bool> pppoeEliminar({
    required String usuario,
  }) async {
    if (usuario.isEmpty) return false;
    final config = await obtenerConfig();
    if (config == null) return false;
    final String apiKey = (config['vpsApiKey'] ?? '').toString();
    if (apiKey.isEmpty) return false;

    return await _post('/pppoe-eliminar', {
      'apikey': apiKey,
      'usuario': usuario,
    });
  }

  // ══════════════════════════════════════════════════════════
  //  ENCOLAR GENERICO
  // ══════════════════════════════════════════════════════════
  static Future<void> encolar(Map<String, dynamic> comando) async {
    final config = await obtenerConfig();
    if (config == null) return;
    final String apiKey = (config['vpsApiKey'] ?? '').toString();
    if (apiKey.isEmpty) return;
    await _post('/encolar', {'apikey': apiKey, ...comando});
  }

  // ══════════════════════════════════════════════════════════
  //  WIREGUARD DINÁMICO — registro de peers en el VPS (hub)
  // ══════════════════════════════════════════════════════════

  /// Devuelve la apikey del usuario desde `config_mikrotik/{uid}`.
  static Future<String?> obtenerApikey() async {
    final config = await obtenerConfig();
    if (config == null) return null;
    final key = (config['vpsApiKey'] ?? '').toString().trim();
    return key.isEmpty ? null : key;
  }

  /// GET /wg/info — datos del servidor WireGuard (public key, puerto, host).
  static Future<WgInfoVps?> obtenerInfoVps() async {
    final key = await obtenerApikey();
    if (key == null) return null;
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/wg/info?apikey=$key'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      if (j['ok'] != true) return null;
      return WgInfoVps(
        serverPublicKey: (j['serverPublicKey'] ?? '').toString(),
        listenPort: (j['listenPort'] as num?)?.toInt() ?? 0,
        endpoint: (j['endpoint'] ?? '').toString(),
        pool: (j['pool'] ?? '').toString(),
      );
    } catch (e) {
      debugPrint('[VpsService] /wg/info no disponible: $e');
      return null;
    }
  }

  /// POST /wg/register — da de alta el peer del usuario y devuelve su IP.
  static Future<WgRegistroVps?> registrarPeerVps({
    required String publicKey,
    required String nombre,
  }) async {
    final key = await obtenerApikey();
    if (key == null) return null;
    try {
      final resp = await http
          .post(
            Uri.parse('$_baseUrl/wg/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'apikey': key, 'publicKey': publicKey, 'nombre': nombre}),
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        debugPrint('[VpsService] /wg/register error ${resp.statusCode}: ${resp.body}');
        return null;
      }
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      if (j['ok'] != true) return null;
      return WgRegistroVps(
        ip: (j['ip'] ?? '').toString(),
        address: (j['address'] ?? '').toString(),
        redAntenas: (j['redAntenas'] ?? '').toString().isEmpty
            ? null
            : j['redAntenas'].toString(),
      );
    } catch (e) {
      debugPrint('[VpsService] /wg/register no disponible: $e');
      return null;
    }
  }

  /// DELETE /wg/peers/:publicKey — da de baja el peer del usuario.
  static Future<bool> eliminarPeerVps(String publicKey) async {
    final key = await obtenerApikey();
    if (key == null) return false;
    try {
      final resp = await http
          .delete(Uri.parse('$_baseUrl/wg/peers/$publicKey?apikey=$key'))
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('[VpsService] /wg/peers no disponible: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  HELPER HTTP POST
  //  Retorna true si statusCode 200/201, false en cualquier error.
  // ══════════════════════════════════════════════════════════
  static Future<bool> _post(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      final ok = response.statusCode == 200 || response.statusCode == 201;
      if (ok) {
        debugPrint('[VpsService] $endpoint OK → ${response.body}');
      } else {
        debugPrint('[VpsService] $endpoint error ${response.statusCode}: ${response.body}');
      }
      return ok;
    } catch (e) {
      debugPrint('[VpsService] $endpoint no disponible: $e');
      return false;
    }
  }
}

// ══════════════════════════════════════════════════════════
//  Modelos WireGuard dinámico (VPS hub)
// ══════════════════════════════════════════════════════════

/// Respuesta de GET /wg/info.
class WgInfoVps {
  const WgInfoVps({
    required this.serverPublicKey,
    required this.listenPort,
    required this.endpoint,
    required this.pool,
  });

  final String serverPublicKey;
  final int listenPort;
  final String endpoint; // host:puerto (ej: 5.161.88.42:1234)
  final String pool; // ej: 10.50.50
}

/// Respuesta de POST /wg/register.
class WgRegistroVps {
  const WgRegistroVps({
    required this.ip,
    required this.address,
    this.redAntenas,
  });

  final String ip; // ej: 10.50.50.6
  final String address; // ej: 10.50.50.6/32

  /// Subred de antenas asignada al usuario (10.10.x.0/24, no editable).
  final String? redAntenas;
}
