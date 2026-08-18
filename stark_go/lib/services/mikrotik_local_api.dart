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
  }) async {
    await _ejecutar(
      '/ip/hotspot/user/add',
      atributos: [
        '=name=$codigo',
        '=password=$codigo',
        '=profile=$perfil',
      ],
    );
  }

  Future<void> borrarFicha(String id) async {
    await _ejecutar(
      '/ip/hotspot/user/remove',
      atributos: ['=.id=$id'],
    );
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
