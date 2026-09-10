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
      final doc = await FirebaseFirestore.instance
          .collection(_coleccion)
          .doc(uid)
          .get();
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
  //  GENERAR IP DEL TÚNEL PARA EL MIKROTIK (10.50.50.x)
  //  Consulta Firestore (config_mikrotik.mikrotikTunelIp + wg_peers.ip)
  //  y devuelve la primera IP libre del pool 2..250. La .1 (el VPS)
  //  nunca se asigna y las usadas no se repiten.
  // ══════════════════════════════════════════════════════════
  static Future<String?> generarIpTunelMikrotik() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final usadas = <String>{};
    try {
      // IPs de túnel ya asignadas a MikroTik (campo mikrotikTunelIp).
      final cfg = await FirebaseFirestore.instance.collection(_coleccion).get();
      for (final d in cfg.docs) {
        final ip = (d.data()['mikrotikTunelIp'] ?? '').toString().trim();
        if (ip.startsWith('10.50.50.')) usadas.add(ip);
      }
      // IPs de túnel de los teléfonos registrados en el VPS.
      final peers =
          await FirebaseFirestore.instance.collection('wg_peers').get();
      for (final d in peers.docs) {
        final ip = (d.data()['ip'] ?? '').toString().trim();
        if (ip.startsWith('10.50.50.')) usadas.add(ip);
      }
      // IP del dispositivo del propio usuario (si tiene vpn_config).
      final vpn = await FirebaseFirestore.instance
          .collection('vpn_config')
          .doc(uid)
          .get();
      if (vpn.exists) {
        final addr = (vpn.data()?['address'] ?? '').toString().trim();
        final ip = addr.split('/').first.trim();
        if (ip.startsWith('10.50.50.')) usadas.add(ip);
      }
    } catch (e) {
      debugPrint('[VpsService] Error consultando IPs del túnel: $e');
    }
    for (int i = 2; i <= 250; i++) {
      final ip = '10.50.50.$i';
      if (!usadas.contains(ip)) return ip;
    }
    return null;
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

      // Portal de pago para morosos: solo se activa si el usuario lo habilitó
      // en config_mikrotik/{uid} con portalMorosos: true. Si no está activado,
      // el comportamiento es EXACTAMENTE el de antes (bloquear/desbloquear).
      final bool portalMorosos = (config['portalMorosos'] ?? false) == true;

      final Map<String, dynamic> body = {'apikey': apiKey, 'nombre': nombre};
      if (ip.isNotEmpty) body['ip'] = ip;
      if (portalMorosos) body['portal'] = true;
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

    // Ráfaga individual de la VELOCIDAD elegida para este cliente: se agrega a
    // su Simple Queue junto al max-limit (solo si esa velocidad tiene perfil).
    final burst = await _perfilVelocidad(velocidad);
    final body = <String, dynamic>{
      'apikey': apiKey,
      'accion': 'limitarMegas',
      'ip': ip,
      'nombre': nombre,
      'bajada': bajada,
      'subida': subida,
    };
    if (burst != null) body.addAll(burst);
    await _post('/limitar', body);

    // Portal de pago para morosos: si está habilitado (portalMorosos: true),
    // damos de alta el "bypass" del hotspot para la IP del cliente nuevo.
    // Así el cliente navega normal y NO ve el portal (su ip-binding lo protege).
    // El VPS lo encola y el scheduler del MikroTik lo aplica en el próximo ciclo.
    final bool portalMorosos = (config['portalMorosos'] ?? false) == true;
    if (portalMorosos) {
      await _post('/desbloquear', {
        'apikey': apiKey,
        'nombre': nombre,
        'ip': ip,
        'portal': true,
      });
    }
  }

  // ══════════════════════════════════════════════════════════
  //  BLINDAR IP DEL PORTAL (hotspot) — sectoriales y equipos
  // ══════════════════════════════════════════════════════════
  /// Si el portal de pago para morosos está habilitado (portalMorosos: true),
  /// encola en el VPS el alta del `ip hotspot ip-binding type=bypassed` para
  /// esa IP. Así el hotspot del MikroTik NO intercepta la interfaz web del
  /// equipo (mismo mecanismo que usan los clientes al día). No hace nada si
  /// el portal está apagado o si falta config/vpsApiKey.
  static Future<void> blindarIpDelPortal({
    required String nombre,
    required String ip,
  }) async {
    if (ip.trim().isEmpty || nombre.trim().isEmpty) return;
    final config = await obtenerConfig();
    if (config == null) return;
    final bool portalMorosos = (config['portalMorosos'] ?? false) == true;
    if (!portalMorosos) return; // sin portal activo no hace falta blindar
    final String apiKey = (config['vpsApiKey'] ?? '').toString();
    if (apiKey.isEmpty) return;
    debugPrint('[VpsService] Blindando IP $ip del portal (bypassed).');
    await _post('/desbloquear', {
      'apikey': apiKey,
      'nombre': nombre,
      'ip': ip,
      'portal': true,
    });
  }

  // ══════════════════════════════════════════════════════════
  //  RÁFAGA POR VELOCIDAD — perfiles guardados en "Velocidades MikroTik"
  // ══════════════════════════════════════════════════════════
  /// Busca en `velocidades/{uid}/perfiles` la ráfaga de la VELOCIDAD exacta
  /// que se asignó al cliente. Devuelve los campos para /limitar (Simple
  /// Queue) o null si esa velocidad no tiene ráfaga guardada.
  static Future<Map<String, dynamic>?> _perfilVelocidad(String velocidad) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty || velocidad.trim().isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('velocidades')
          .doc(uid)
          .get();
      if (!doc.exists) return null;
      final perfiles = doc.data()?['perfiles'];
      if (perfiles is! Map<String, dynamic>) return null;
      final p = perfiles[velocidad];
      if (p is! Map<String, dynamic>) return null;

      String? v(Object? x) {
        final s = (x ?? '').toString().trim();
        return s.isEmpty ? null : s;
      }

      final bb = v(p['burstBajada']);
      final bs = v(p['burstSubida']);
      final ub = v(p['umbralBajada']);
      final us = v(p['umbralSubida']);
      final t = v(p['tiempo']);
      if (bb == null || bs == null || ub == null || us == null || t == null) {
        return null;
      }
      debugPrint('[VpsService] Ráfaga de "$velocidad": ↓$bb/↑$bs · umbral ↓$ub/↑$us · ${t}s');
      return {
        'burstBajada': bb,
        'burstSubida': bs,
        'umbralBajada': ub,
        'umbralSubida': us,
        'tiempo': t,
      };
    } catch (e) {
      debugPrint('[VpsService] Error leyendo ráfagas: $e');
      return null;
    }
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
            body: jsonEncode(
                {'apikey': key, 'publicKey': publicKey, 'nombre': nombre}),
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        debugPrint(
            '[VpsService] /wg/register error ${resp.statusCode}: ${resp.body}');
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

  /// POST /wg/register-mikrotik — da de alta el MikroTik como peer estático
  /// (AllowedIPs = ip del MikroTik/32 + subred de antenas, automático).
  static Future<bool> registrarMikrotikVps({required String publicKey}) async {
    final key = await obtenerApikey();
    if (key == null) return false;
    try {
      final resp = await http
          .post(
            Uri.parse('$_baseUrl/wg/register-mikrotik'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'apikey': key, 'publicKey': publicKey}),
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body) as Map<String, dynamic>;
        return j['ok'] == true;
      }
      debugPrint(
          '[VpsService] /wg/register-mikrotik error ${resp.statusCode}: ${resp.body}');
      return false;
    } catch (e) {
      debugPrint('[VpsService] /wg/register-mikrotik no disponible: $e');
      return false;
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
        debugPrint(
            '[VpsService] $endpoint error ${response.statusCode}: ${response.body}');
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
