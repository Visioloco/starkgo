import 'package:flutter/foundation.dart';
import 'package:routeros_api/routeros_api.dart';

// ════════════════════════════════════════════════════════════════
//  MIKROTIK LOCAL API — cliente directo al router por la red local
// ════════════════════════════════════════════════════════════════

class MikrotikLocalException implements Exception {
  final String mensaje;
  MikrotikLocalException(this.mensaje);
  @override
  String toString() => mensaje;
}

class MikrotikLocalApi {
  final String ip;
  final String usuario;
  final String password;
  final int puerto;
  final bool useSsl;
  final Duration timeout;

  MikrotikLocalApi({
    required this.ip,
    required this.usuario,
    required this.password,
    this.puerto = 8728,
    this.useSsl = false,
    this.timeout = const Duration(seconds: 10),
  });

  // ✅ Crea el cliente (todavía sin conectar)
  RouterOSClient _cliente() {
    return RouterOSClient(
      host: ip,
      user: usuario,
      password: password,
      useSsl: useSsl,
      port: puerto,
      defaultTimeout: timeout,
    );
  }

  // ✅ Conecta, hace login y ejecuta un comando. Cierra el socket al final.
  Future<List<Map<String, dynamic>>> _ejecutar(
    String ruta, {
    List<String> atributos = const [],
  }) async {
    final client = _cliente();
    try {
      // 1) Conectar y autenticar — esto es lo que faltaba.
      await client.connect().timeout(
            timeout,
            onTimeout: () => throw MikrotikLocalException(
              'Tiempo de espera agotado conectando a $ip:$puerto. '
              'Verifica que estés en la misma red que el MikroTik.',
            ),
          );

      // 2) Ejecutar el comando. Los atributos tipo "=name=valor" van
      //    como palabras extra de la sentencia (mismo formato que usa
      //    el ejemplo oficial con `flags: ['=count-only=']`).
      final resultado = await client.execute(ruta, flags: atributos).timeout(timeout);

      return resultado.map((e) => Map<String, dynamic>.from(e)).toList();
    } on RouterOSException catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('login') || msg.contains('password') || msg.contains('auth') || msg.contains('cannot log in')) {
        throw MikrotikLocalException('Usuario o contraseña incorrectos');
      }
      throw MikrotikLocalException(
        'El MikroTik respondió con un error: $e',
      );
    } catch (e) {
      if (e is MikrotikLocalException) rethrow;
      throw MikrotikLocalException(
        'No se pudo conectar a $ip:$puerto. Verifica que estés en la misma '
        'red que el MikroTik y que el servicio API esté habilitado '
        '(IP → Services → api).\n\nError: $e',
      );
    } finally {
      client.close();
    }
  }

  // ── Prueba de conexión ──
  Future<String> probarConexion() async {
    final res = await _ejecutar('/system/identity/print');
    if (res.isEmpty) return 'MikroTik';
    return (res.first['name'] ?? 'MikroTik').toString();
  }

  // ─────────────────────────────────────────────────────────────
  // Perfiles / planes de hotspot
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> obtenerPerfiles() async {
    return await _ejecutar('/ip/hotspot/user/profile/print');
  }

  Future<void> crearPerfil({
    required String nombre,
    required String rateLimit,
    required int sessionTimeoutSegundos,
    int usuariosCompartidos = 1,
  }) async {
    await _ejecutar(
      '/ip/hotspot/user/profile/add',
      atributos: [
        '=name=$nombre',
        '=rate-limit=$rateLimit',
        '=session-timeout=${_formatearDuracion(sessionTimeoutSegundos)}',
        '=shared-users=$usuariosCompartidos',
      ],
    );
  }

  Future<void> borrarPerfil(String id) async {
    await _ejecutar(
      '/ip/hotspot/user/profile/remove',
      atributos: ['=.id=$id'],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Fichas / vouchers de hotspot
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> obtenerFichas() async {
    return await _ejecutar('/ip/hotspot/user/print');
  }

  Future<void> crearFicha({
    required String codigo,
    required String perfil,
    String? limitUptime,
  }) async {
    final atributos = <String>[
      '=name=$codigo',
      '=password=$codigo',
      '=profile=$perfil',
    ];
    // 'limit-uptime' = tiempo TOTAL acumulado permitido para la ficha.
    // Sin esto la ficha NUNCA se acaba (el 'session-timeout' del perfil solo
    // limita cada sesión y se reinicia al volver a entrar).
    if (limitUptime != null && limitUptime.isNotEmpty && limitUptime != '0s' && limitUptime != '0') {
      atributos.add('=limit-uptime=$limitUptime');
    }
    await _ejecutar(
      '/ip/hotspot/user/add',
      atributos: atributos,
    );
  }

  Future<void> borrarFicha(String id) async {
    await _ejecutar(
      '/ip/hotspot/user/remove',
      atributos: ['=.id=$id'],
    );
  }

  /// Aplica/actualiza el 'limit-uptime' (tiempo TOTAL) de una ficha existente.
  Future<void> aplicarLimitUptime({
    required String id,
    required String limitUptime,
  }) async {
    await _ejecutar(
      '/ip/hotspot/user/set',
      atributos: ['=.id=$id', '=limit-uptime=$limitUptime'],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 🛡️ Blindaje del administrador (portal cautivo / hotspot)
  //
  // Deja TU teléfono como `ip-binding type=bypassed`: el portal NO le pide
  // ficha/PIN. Se puede hacer por IP y/o por MAC (la MAC sobrevive a los
  // cambios de IP del DHCP).
  // ─────────────────────────────────────────────────────────────

  /// Equipos que el hotspot ve ahora mismo (`/ip hotspot host/print`).
  /// Cada uno trae `mac-address`, `address` (IP) y `host-name`.
  Future<List<Map<String, dynamic>>> obtenerHostsHotspot() async {
    return await _ejecutar('/ip/hotspot/host/print');
  }

  /// `ip-binding` existentes del hotspot (para saber qué está blindado).
  Future<List<Map<String, dynamic>>> obtenerBindingsHotspot() async {
    return await _ejecutar('/ip/hotspot/ip-binding/print');
  }

  /// Crea el `ip-binding type=bypassed` para una IP y/o MAC.
  ///
  /// Devuelve `true` si quedó blindado (o si ya lo estaba: RouterOS responde
  /// con error "already have" y lo tratamos como éxito, así reintentar es
  /// inofensivo).
  Future<bool> blindarDispositivo({
    String? ip,
    String? mac,
    String comentario = 'StarkGo ADMIN',
  }) async {
    final atributos = <String>[
      '=type=bypassed',
      '=comment=$comentario',
    ];
    final ipOk = (ip ?? '').trim();
    final macOk = (mac ?? '').trim().toUpperCase();
    if (ipOk.isNotEmpty) atributos.add('=address=$ipOk');
    if (macOk.isNotEmpty) atributos.add('=mac-address=$macOk');
    if (ipOk.isEmpty && macOk.isEmpty) return false;

    try {
      await _ejecutar('/ip/hotspot/ip-binding/add', atributos: atributos);
      return true;
    } on MikrotikLocalException catch (e) {
      final msg = e.mensaje.toLowerCase();
      // Ya existía ese binding → el objetivo está cumplido.
      if (msg.contains('already') || msg.contains('haved')) return true;
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 📌 Leases DHCP — las IPs que el router le da a las antenas
  //
  // Sirve para saber qué IP le tocó a una antena recién conectada SIN entrar
  // a WinBox: la app la lista, la buscás y la usás al registrar el cliente.
  // ─────────────────────────────────────────────────────────────

  /// Leases del servidor DHCP (`/ip dhcp-server lease/print`).
  /// Campos útiles: `address` (IP), `mac-address`, `host-name`, `dynamic`
  /// (true = la dio el DHCP), `status`, `comment`, `last-seen`.
  Future<List<Map<String, dynamic>>> obtenerLeasesDhcp() async {
    return await _ejecutar('/ip/dhcp-server/lease/print');
  }

  /// Marca el lease de una IP como StarkGo:
  ///   · lo pasa a **ESTÁTICO** (si era dinámico) → la antena conserva la IP,
  ///   · le pone el comentario `StarkGo <nombre>`,
  ///   · y agrega la IP a la address-list `starkgo`.
  ///
  /// Devuelve `{estatica, comentario, lista}` con lo que se logró aplicar.
  /// Es idempotente: si ya es estática o ya está en la lista, no repite nada.
  Future<Map<String, bool>> marcarLeaseDhcp({
    required String ip,
    required String nombre,
  }) async {
    final resultado = <String, bool>{
      'estatica': false,
      'comentario': false,
      'lista': false,
    };
    final ipOk = ip.trim();
    if (ipOk.isEmpty) return resultado;
    final comentario = 'StarkGo ${nombre.trim()}';

    final leases = await obtenerLeasesDhcp();
    final lease = leases.firstWhere(
      (l) => (l['address']?.toString() ?? '') == ipOk,
      orElse: () => <String, dynamic>{},
    );
    final id = lease['.id']?.toString() ?? '';

    if (id.isEmpty) {
      // No hay lease para esa IP (IP fija fuera del DHCP): igual la dejamos
      // marcada en la address-list.
      await _agregarListaStarkgo(ip: ipOk, comentario: comentario, resultado: resultado);
      return resultado;
    }

    final esDinamica = lease['dynamic'] == true || lease['dynamic']?.toString() == 'true';
    if (esDinamica) {
      try {
        await _ejecutar('/ip/dhcp-server/lease/make-static', atributos: ['=.id=$id']);
        resultado['estatica'] = true;
      } catch (e) {
        debugPrint('[Leases] make-static falló: $e');
      }
    } else {
      resultado['estatica'] = true; // ya era estática
    }

    if (resultado['estatica'] == true) {
      try {
        await _ejecutar('/ip/dhcp-server/lease/set',
            atributos: ['=.id=$id', '=comment=$comentario']);
        resultado['comentario'] = true;
      } catch (e) {
        debugPrint('[Leases] comentario falló: $e');
      }
    }

    await _agregarListaStarkgo(ip: ipOk, comentario: comentario, resultado: resultado);
    return resultado;
  }

  /// Deja la IP en la address-list `starkgo` (idempotente).
  Future<void> _agregarListaStarkgo({
    required String ip,
    required String comentario,
    required Map<String, bool> resultado,
  }) async {
    try {
      final actual = await _ejecutar('/ip/firewall/address-list/print');
      final ya = actual.any((a) =>
          (a['list']?.toString() ?? '') == 'starkgo' &&
          (a['address']?.toString() ?? '') == ip);
      if (ya) {
        resultado['lista'] = true;
        return;
      }
      await _ejecutar('/ip/firewall/address-list/add',
          atributos: ['=list=starkgo', '=address=$ip', '=comment=$comentario']);
      resultado['lista'] = true;
    } catch (e) {
      debugPrint('[Leases] address-list falló: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Usuarios activos (sesiones conectadas ahora mismo)
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> obtenerActivos() async {
    return await _ejecutar('/ip/hotspot/active/print');
  }

  // ─────────────────────────────────────────────────────────────
  // Utilitarios
  // ─────────────────────────────────────────────────────────────

  String _formatearDuracion(int totalSegundos) {
    if (totalSegundos <= 0) return '00:00:00';
    final d = totalSegundos ~/ 86400;
    final h = (totalSegundos % 86400) ~/ 3600;
    final m = (totalSegundos % 3600) ~/ 60;
    final s = totalSegundos % 60;
    final partes = <String>[];
    if (d > 0) partes.add('${d}d');
    if (h > 0) partes.add('${h}h');
    if (m > 0) partes.add('${m}m');
    if (s > 0) partes.add('${s}s');
    return partes.isEmpty ? '00:00:00' : partes.join('');
  }
}
