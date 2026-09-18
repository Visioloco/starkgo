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

  static Future<bool> cambiarStatus({
    required String status,
    required String ip,
    required String nombre,
  }) async {
    if (_procesando) return false;
    if (status != 'mora' && status != 'activo') return false;
    _procesando = true;
    try {
      final config = await obtenerConfig();
      if (config == null) {
        debugPrint('[VpsService] cambiarStatus — sin config_mikrotik, omitido.');
        return false;
      }
      final String apiKey = (config['vpsApiKey'] ?? '').toString();
      if (apiKey.isEmpty) {
        debugPrint('[VpsService] cambiarStatus — falta vpsApiKey, omitido.');
        return false;
      }
      final bool bloquear = status == 'mora';

      // Portal de pago para morosos: solo se activa si el usuario lo habilitó
      // en config_mikrotik/{uid} con portalMorosos: true. Si no está activado,
      // el comportamiento es EXACTAMENTE el de antes (bloquear/desbloquear):
      // suspender = solo el drop de la address-list `morosos`.
      final bool portalMorosos = (config['portalMorosos'] ?? false) == true;

      final Map<String, dynamic> body = {'apikey': apiKey, 'nombre': nombre};
      if (ip.isNotEmpty) body['ip'] = ip;
      // `portal: true` hace que el VPS encole además el manejo del `ip-binding`:
      //   · suspender con el portal activo → QUITA el bypass (la IP queda
      //     cautiva y el cliente ve el portal de pago);
      //   · reactivar (activo) → siempre DEVUELVE el bypass, para que el hotspot
      //     no le intercepte la navegación. Si el hotspot no está configurado el
      //     binding queda inerte y no molesta a nadie.
      if (!bloquear || portalMorosos) body['portal'] = true;
      final bool ok = await _post(bloquear ? '/bloquear' : '/desbloquear', body);
      if (!ok) {
        debugPrint('[VpsService] ⚠️ cambiarStatus("$status") no llegó al VPS '
            '(revisá la API Key y la conexión).');
      }
      return ok;
    } finally {
      _procesando = false;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  CLIENTE CREADO (Simple Queue por IP + blindaje del hotspot)
  // ══════════════════════════════════════════════════════════
  /// Encola en el VPS:
  ///   1. la **Simple Queue** de la IP de antena (`ipatn`) con su velocidad, y
  ///   2. el `ip hotspot ip-binding type=bypassed` de esa misma IP, para que
  ///      el portal cautivo NO le salga al equipo del cliente.
  ///
  /// Devuelve `true` solo si el VPS aceptó AMBOS comandos. Si devuelve false,
  /// el cliente quedó guardado en Firestore pero el router NO recibió los
  /// comandos: hay que avisarle al operador (antes fallaba en silencio).
  static Future<bool> clienteCreado({
    required String nombre,
    required String ip,
    required String velocidad,
  }) async {
    if (ip.trim().isEmpty) {
      debugPrint('[VpsService] clienteCreado — sin IP de antena: no se crea la Simple Queue.');
      return false;
    }
    if (velocidad.trim().isEmpty) {
      debugPrint('[VpsService] clienteCreado — sin velocidad: no se crea la Simple Queue.');
      return false;
    }
    final config = await obtenerConfig();
    if (config == null) {
      debugPrint('[VpsService] clienteCreado — sin config_mikrotik: no se encoló nada.');
      return false;
    }
    final String apiKey = (config['vpsApiKey'] ?? '').toString();
    if (apiKey.isEmpty) {
      debugPrint('[VpsService] clienteCreado — falta vpsApiKey: no se encoló nada.');
      return false;
    }

    // La velocidad de la app viene como "SUBIDA/BAJADA" (ej: "5M/10M") y la
    // Simple Queue de RouterOS también se escribe subida/bajada (max-limit).
    // `ordenVelocidad` le dice al VPS que estos valores ya vienen en el orden
    // real: así una APK vieja (que los mandaba invertidos) sigue funcionando
    // bien mientras se actualiza, y la nueva no se da vuelta.
    final partes = velocidad.split('/');
    final String subida = partes.isNotEmpty ? partes[0].trim() : velocidad.trim();
    final String bajada = partes.length > 1 ? partes[1].trim() : subida;

    // Ráfaga individual de la VELOCIDAD elegida para este cliente: se agrega a
    // su Simple Queue junto al max-limit (solo si esa velocidad tiene perfil).
    final burst = await _perfilVelocidad(velocidad);
    final body = <String, dynamic>{
      'apikey': apiKey,
      'accion': 'limitarMegas',
      'ip': ip.trim(),
      'nombre': nombre,
      'subida': subida,
      'bajada': bajada,
      'ordenVelocidad': 'subida-bajada',
    };
    if (burst != null) body.addAll(burst);
    final bool colaOk = await _post('/limitar', body);
    if (!colaOk) {
      debugPrint('[VpsService] ⚠️ El VPS no aceptó la Simple Queue de $ip '
          '(cliente: $nombre). Revisá la API Key del VPS y la conexión.');
    } else {
      debugPrint('[VpsService] ✅ Simple Queue encolada: $nombre → $ip ($velocidad)');
    }

    // Blindaje del portal (hotspot): SIEMPRE. El binding `bypassed` hace que
    // el hotspot NO intercepte la IP del cliente. Si el hotspot está apagado
    // el binding queda inerte; si está encendido, es imprescindible.
    final bool blindado = await _blindar(apiKey: apiKey, nombre: nombre, ip: ip.trim());
    if (!blindado) {
      debugPrint('[VpsService] ⚠️ No se pudo encolar el blindaje (ip-binding bypassed) de $ip.');
    }
    return colaOk && blindado;
  }

  // ══════════════════════════════════════════════════════════
  //  BLINDAR IP DEL PORTAL (hotspot) — sectoriales y equipos
  // ══════════════════════════════════════════════════════════
  /// Encola el alta del `ip hotspot ip-binding type=bypassed` para esa IP, así
  /// el hotspot del MikroTik NO intercepta la interfaz web del equipo (mismo
  /// mecanismo que usan los clientes al día).
  ///
  /// Se hace SIEMPRE, tenga o no activado el portal de morosos: si el hotspot
  /// está apagado el binding queda inerte y no molesta a nadie; si está
  /// encendido, es imprescindible (antes sólo se creaba con portalMorosos=true
  /// y por eso las IPs de los clientes nuevos quedaban capturadas).
  static Future<bool> blindarIpDelPortal({
    required String nombre,
    required String ip,
  }) async {
    if (ip.trim().isEmpty || nombre.trim().isEmpty) return false;
    final config = await obtenerConfig();
    if (config == null) return false;
    final String apiKey = (config['vpsApiKey'] ?? '').toString();
    if (apiKey.isEmpty) return false;
    debugPrint('[VpsService] Blindando IP $ip del portal (bypassed).');
    return _blindar(apiKey: apiKey, nombre: nombre, ip: ip.trim());
  }

  /// Encola el bypass del hotspot para una IP (helper interno).
  /// El VPS responde con el `ip-binding` en el próximo ciclo del scheduler.
  static Future<bool> _blindar({
    required String apiKey,
    required String nombre,
    required String ip,
  }) async {
    if (ip.trim().isEmpty) return false;
    return _post('/desbloquear', {
      'apikey': apiKey,
      'nombre': nombre,
      'ip': ip.trim(),
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
  //  El VPS acepta sólo acciones conocidas (/encolar con lista blanca).
  // ══════════════════════════════════════════════════════════
  static Future<bool> encolar(Map<String, dynamic> comando) async {
    final config = await obtenerConfig();
    if (config == null) return false;
    final String apiKey = (config['vpsApiKey'] ?? '').toString();
    if (apiKey.isEmpty) return false;
    final cmd = Map<String, dynamic>.from(comando);
    // Igual que en clienteCreado: marcamos el orden real de subida/bajada para
    // que el VPS no aplique la compatibilidad de la app vieja.
    if (cmd['accion'] == 'limitarMegas' && cmd['ordenVelocidad'] == null) {
      cmd['ordenVelocidad'] = 'subida-bajada';
    }
    return _post('/encolar', {'apikey': apiKey, ...cmd});
  }

  // ══════════════════════════════════════════════════════════
  //  ESTADO DE LA COLA (diagnóstico)
  //  Consulta GET /cola/estado: cuántos comandos están pendientes, cuál es el
  //  lote "en vuelo" (bajado por el MikroTik y todavía sin confirmar) y cuándo
  //  fue la última confirmación. Sirve para responder "¿se aplicó en el router?".
  // ══════════════════════════════════════════════════════════
  static Future<ColaEstadoVps?> estadoCola() async {
    final key = await obtenerApikey();
    if (key == null) return null;
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/cola/estado?apikey=$key'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      return ColaEstadoVps.fromJson(j);
    } catch (e) {
      debugPrint('[VpsService] /cola/estado no disponible: $e');
      return null;
    }
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
  /// (AllowedIPs = ip del MikroTik/32 + subred de gestión/antenas).
  ///
  /// [subred]  → red local declarada por el usuario (ej. "192.168.10.0/24").
  ///             El VPS la usa como subred de antenas y valida que sea única
  ///             entre empresas. Vacío → el VPS asigna una 10.10.X.0/24 libre.
  /// [ipLocal] → puerta de enlace del MikroTik en su red local (se guarda).
  static Future<WgMikrotikVps> registrarMikrotikVps({
    required String publicKey,
    String? subred,
    String? ipLocal,
  }) async {
    final key = await obtenerApikey();
    if (key == null) {
      return const WgMikrotikVps(
        ok: false,
        error: 'Sin API Key del VPS: cargala en Config. MikroTik → "Tu clave de acceso".',
      );
    }
    try {
      final resp = await http
          .post(
            Uri.parse('$_baseUrl/wg/register-mikrotik'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'apikey': key,
              'publicKey': publicKey,
              if (subred != null && subred.trim().isNotEmpty)
                'subred': subred.trim(),
              if (ipLocal != null && ipLocal.trim().isNotEmpty)
                'ipLocal': ipLocal.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));
      Map<String, dynamic> j = const {};
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) j = decoded;
      } catch (_) {
        // El VPS no devolvió JSON (p. ej. versión vieja sin el endpoint).
      }
      if (resp.statusCode == 200 && j['ok'] == true) {
        final red = (j['redAntenas'] ?? '').toString().trim();
        final ip = (j['ip'] ?? '').toString().trim();
        return WgMikrotikVps(
          ok: true,
          ip: ip.isEmpty ? null : ip,
          ipReasignada: j['ipReasignada'] == true,
          redAntenas: red.isEmpty ? null : red,
        );
      }
      final msg = (j['error'] ?? '').toString().trim();
      debugPrint(
          '[VpsService] /wg/register-mikrotik error ${resp.statusCode}: ${resp.body}');
      return WgMikrotikVps(
        ok: false,
        status: resp.statusCode,
        detalle: _recortar(resp.body),
        // Si el VPS explicó el motivo (subred ocupada, IP del túnel en uso, …)
        // se muestra tal cual + el código HTTP; si no vino nada, se traduce el
        // código HTTP a una causa probable con la acción a tomar.
        error: msg.isNotEmpty
            ? '$msg (HTTP ${resp.statusCode})'
            : _explicarErrorVps(resp.statusCode, resp.body),
      );
    } catch (e) {
      debugPrint('[VpsService] /wg/register-mikrotik no disponible: $e');
      return WgMikrotikVps(
        ok: false,
        error: 'No se pudo contactar al VPS ($e). Revisá tu conexión a internet.',
        detalle: e.toString(),
      );
    }
  }

  /// Recorta un texto largo (respuesta cruda del VPS) para poder mostrarlo.
  static String _recortar(String s, [int max = 200]) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length > max ? '${t.substring(0, max)}…' : t;
  }

  /// Traduce el código HTTP del VPS a una causa probable + acción concreta.
  /// Se usa solo cuando el VPS NO mandó un campo `error` en el JSON (por ej.
  /// el 404 de Express, un 401 sin cuerpo o un 502 de un proxy delante del VPS).
  static String _explicarErrorVps(int status, String body) {
    final muestra = _recortar(body, 160);
    switch (status) {
      case 401:
        return 'El VPS rechazó la API Key (HTTP 401 · No autorizado). '
            'Revisá que la API Key guardada en Config. MikroTik sea la misma '
            'que usás y tocá Guardar; reintentá (el VPS refresca las claves '
            'al instante desde la v2.6).';
      case 404:
        return 'El VPS no tiene el endpoint /wg/register-mikrotik (HTTP 404): '
            'está corriendo una versión vieja. Subí el functions/index.js '
            'actualizado al VPS y reiniciá el servicio (pm2 restart).';
      case 502:
      case 503:
      case 504:
        return 'El VPS no está respondiendo bien (HTTP $status). Revisá que el '
            'servicio Node esté arriba y reintentá.';
      default:
        return muestra.isEmpty
            ? 'El VPS rechazó el registro (HTTP $status). Revisá el log del VPS.'
            : 'El VPS rechazó el registro (HTTP $status): $muestra';
    }
  }

  /// DELETE /wg/peers/:publicKey — da de baja el peer del usuario.
  static Future<bool> eliminarPeerVps(String publicKey) async {
    final key = await obtenerApikey();
    if (key == null) return false;
    try {
      final resp = await http
          .delete(Uri.parse(
              '$_baseUrl/wg/peers/${Uri.encodeComponent(publicKey)}?apikey=$key'))
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
  //  IMPORTANTE: si devuelve false, el router NO va a recibir nada.
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
      } else if (response.statusCode == 401) {
        debugPrint('[VpsService] ⚠️ $endpoint NO AUTORIZADO (401): la API Key del '
            'VPS no coincide con la guardada en config_mikrotik. '
            'Abrí Config. MikroTik → Guardar y reintentá.');
      } else {
        debugPrint(
            '[VpsService] $endpoint error ${response.statusCode}: ${response.body}');
      }
      return ok;
    } catch (e) {
      debugPrint('[VpsService] ⚠️ $endpoint no disponible (el VPS no respondió): $e');
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

/// Respuesta de POST /wg/register-mikrotik.
class WgMikrotikVps {
  const WgMikrotikVps({
    required this.ok,
    this.ip,
    this.ipReasignada = false,
    this.redAntenas,
    this.error,
    this.status,
    this.detalle,
  });

  /// true si el VPS registró el peer del MikroTik.
  final bool ok;

  /// IP del túnel que quedó efectivamente asignada (10.50.50.x).
  /// Puede diferir de la generada en la app si el VPS la encontró ocupada.
  final String? ip;

  /// true si el VPS tuvo que reasignar la IP del túnel (ya estaba en uso).
  final bool ipReasignada;

  /// Subred de gestión/antenas que quedó activa (ej. "192.168.10.0/24").
  final String? redAntenas;

  /// Mensaje de error del VPS (ej. subred ya en uso por otra empresa).
  final String? error;

  /// Código HTTP que devolvió el VPS (null si ni siquiera hubo respuesta).
  /// Se muestra en la app para diagnosticar sin mirar los logs.
  final int? status;

  /// Cuerpo crudo de la respuesta del VPS (recortado) — solo diagnóstico.
  final String? detalle;
}

/// Respuesta de GET /cola/estado — cómo va la entrega de comandos al router.
class ColaEstadoVps {
  const ColaEstadoVps({
    required this.pendientes,
    required this.comandosEnVuelo,
    required this.enviadoEn,
    required this.edadSegundos,
    required this.ultimaConfirmacion,
    required this.ttlSegundos,
  });

  /// Comandos todavía sin bajar por el MikroTik.
  final int pendientes;

  /// Comandos que el MikroTik ya bajó y aún NO confirmó (0 = todo aplicado).
  final int comandosEnVuelo;

  /// Cuándo se entregó el lote en vuelo (null si no hay ninguno).
  final DateTime? enviadoEn;

  /// Segundos desde la entrega del lote en vuelo.
  final int edadSegundos;

  /// Última vez que el MikroTik confirmó el /import completo.
  final DateTime? ultimaConfirmacion;

  /// Plazo (segundos) tras el cual el VPS reintenta el lote.
  final int ttlSegundos;

  /// true si todo lo encolado ya se aplicó en el router.
  bool get todoAplicado => pendientes == 0 && comandosEnVuelo == 0;

  static DateTime? _fecha(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }

  factory ColaEstadoVps.fromJson(Map<String, dynamic> j) {
    final vuelo = j['enVuelo'];
    final vueloMap = vuelo is Map ? Map<String, dynamic>.from(vuelo) : null;
    return ColaEstadoVps(
      pendientes: (j['pendientes'] as num?)?.toInt() ?? 0,
      comandosEnVuelo: (vueloMap?['comandos'] as num?)?.toInt() ?? 0,
      enviadoEn: _fecha(vueloMap?['enviadoEn']),
      edadSegundos: (vueloMap?['edadSegundos'] as num?)?.toInt() ?? 0,
      ultimaConfirmacion: _fecha(j['ultimaConfirmacion']),
      ttlSegundos: (j['ttlSegundos'] as num?)?.toInt() ?? 600,
    );
  }
}
