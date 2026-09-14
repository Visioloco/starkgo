import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';

// ══════════════════════════════════════════════════════════════
//  AntenasService — listado de antenas accesibles por la VPN.
//
//  Fuentes de antenas:
//    1. `clientes` → campo `ipatn` (antenas de clientes / airOS)
//    2. `sectoriales` → antenas propias (sectoriales / bases) que el
//       técnico registra desde la app (colección `sectoriales`).
//
//  Se consultan filtradas por `propietarioUid` = usuario autenticado
//  y siempre dentro de la misma subred de antenas (10.10.x.0/24).
//
//  Pensado para que más adelante el WebView (airOS) pueda reemplazarse
//  por llamadas a la REST API de RouterOS/airOS usando los mismos datos
//  (usuarioAtn/claveAtn ya quedan disponibles en AntenaModel).
// ══════════════════════════════════════════════════════════════

class AntenaModel {
  const AntenaModel({
    required this.id,
    required this.nombre,
    required this.ip,
    required this.estado,
    this.notas,
    this.marca,
    this.modelo,
    this.usuarioAtn,
    this.claveAtn,
    this.esSectorial = false,
  });

  final String id;
  final String nombre;
  final String ip;
  final String estado;
  final String? notas;

  /// Datos de la antena (para mostrar y para la futura REST API).
  final String? marca;
  final String? modelo;
  final String? usuarioAtn;
  final String? claveAtn;

  /// true si viene de la colección `sectoriales` (se puede editar/eliminar).
  final bool esSectorial;

  /// Estados que habilitan abrir la interfaz airOS.
  bool get esAccesible => estado == 'activo' || estado == 'en_linea';

  /// true si la IP está dentro de la subred de antenas del usuario.
  bool ipValida(String redAntenas) => AntenasService.ipEnSubred(ip, redAntenas);

  /// URL de la interfaz airOS nativa.
  String get urlAirOs => 'http://$ip';

  /// IP con la que se abre la interfaz desde la VPN:
  ///  · [netmap] = false → la IP real (`ipatn` / `sectoriales.ip`).
  ///  · [netmap] = true  → la IP **virtual** equivalente dentro de la subred
  ///    del túnel (misma última octeta), que el MikroTik traduce con netmap.
  String ipParaVpn({required String redTunel, required bool netmap}) =>
      netmap ? AntenasService.ipVirtual(ip, redTunel) : ip;

  /// true si la antena es alcanzable por el túnel con el modo actual.
  bool ipValidaVpn({required String redTunel, required bool netmap}) =>
      AntenasService.ipEnSubred(
          ipParaVpn(redTunel: redTunel, netmap: netmap), redTunel);

  /// URL airOS considerando el modo (real o virtual por netmap).
  String urlAirOsVpn({required String redTunel, required bool netmap}) =>
      'http://${ipParaVpn(redTunel: redTunel, netmap: netmap)}';

  /// Copia con campos editables (para editar un sectorial).
  AntenaModel copyWith({
    String? nombre,
    String? ip,
    String? estado,
    String? notas,
    String? marca,
    String? modelo,
    String? usuarioAtn,
    String? claveAtn,
  }) {
    return AntenaModel(
      id: id,
      nombre: nombre ?? this.nombre,
      ip: ip ?? this.ip,
      estado: estado ?? this.estado,
      notas: notas ?? this.notas,
      marca: marca ?? this.marca,
      modelo: modelo ?? this.modelo,
      usuarioAtn: usuarioAtn ?? this.usuarioAtn,
      claveAtn: claveAtn ?? this.claveAtn,
      esSectorial: esSectorial,
    );
  }

  /// Toma el primer valor no vacío entre varias claves (soporta alias
  /// `usuarioutn`/`claveutn` por compatibilidad con datos existentes).
  static String? _campo(Map<String, dynamic> d, List<String> claves) {
    for (final k in claves) {
      final v = d[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return null;
  }

  /// Mapea un documento de `clientes` → antena (campo `ipatn`).
  factory AntenaModel.fromCliente(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? const {};
    final nombreCompleto = '${d['nombre'] ?? ''} ${d['apellido'] ?? ''}'.trim();
    return AntenaModel(
      id: doc.id,
      nombre: nombreCompleto.isEmpty ? doc.id : nombreCompleto,
      ip: (d['ipatn'] ?? '').toString().trim(),
      estado: (d['status'] ?? 'desconocido').toString(),
      notas: _campo(d, ['notas']),
      marca: _campo(d, ['antenaMarca']),
      modelo: _campo(d, ['antenaModelo']),
      usuarioAtn: _campo(d, ['usuarioutn', 'usuarioatn']),
      claveAtn: _campo(d, ['claveutn', 'claveatn']),
      esSectorial: false,
    );
  }

  /// Mapea un documento de `sectoriales` → antena.
  factory AntenaModel.fromSectorial(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? const {};
    final nombre = (d['nombre'] ?? '').toString().trim();
    return AntenaModel(
      id: doc.id,
      nombre: nombre.isEmpty ? doc.id : nombre,
      ip: (d['ip'] ?? '').toString().trim(),
      estado: (d['estado'] ?? 'activo').toString(),
      notas: _campo(d, ['notas']),
      marca: _campo(d, ['marca', 'antenaMarca']),
      modelo: _campo(d, ['modelo', 'antenaModelo']),
      usuarioAtn: _campo(d, ['usuarioatn', 'usuarioutn', 'usuario']),
      claveAtn: _campo(d, ['claveatn', 'claveutn', 'clave']),
      esSectorial: true,
    );
  }
}

/// Resultado de una prueba de conexión (HTTP/HTTPS) a una IP del túnel.
class PruebaConexion {
  const PruebaConexion({required this.ok, required this.detalle, this.http});

  /// true si el equipo **respondió** (aunque sea con 401/403/302).
  final bool ok;

  /// Explicación corta para mostrar al usuario.
  final String detalle;

  /// Código HTTP, si hubo respuesta.
  final int? http;
}

class AntenasService {
  static const String _coleccionClientes = 'clientes';
  static const String _coleccionSectoriales = 'sectoriales';

  /// Valida que la IP esté dentro de 10.10.15.0/24 (hosts 1..254).
  /// Mantenida por compatibilidad; preferí [ipEnSubred].
  static bool ipEnSubred10_10_15(String ip) => ipEnSubred(ip, '10.10.15.0/24');

  /// Convierte "a.b.c.d" → entero (null si es inválida).
  static int? _ipToInt(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    var v = 0;
    for (final p in parts) {
      final o = int.tryParse(p);
      if (o == null || o < 0 || o > 255) return null;
      v = (v << 8) | o;
    }
    return v;
  }

  /// true si `ip` pertenece a la subred CIDR (ej: "10.10.16.0/24").
  static bool ipEnSubred(String ip, String cidr) {
    final c = cidr.trim();
    final slash = c.indexOf('/');
    if (slash < 0) return false;
    final base = c.substring(0, slash).trim();
    final prefix = int.tryParse(c.substring(slash + 1).trim());
    if (prefix == null || prefix < 0 || prefix > 32) return false;
    final a = _ipToInt(ip);
    final b = _ipToInt(base);
    if (a == null || b == null) return false;
    final mask = prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
    return (a & mask) == (b & mask);
  }

  /// true si `cidr` tiene forma de subred válida (IP + prefijo 16..30).
  static bool cidrValido(String cidr) {
    final c = cidr.trim();
    final slash = c.indexOf('/');
    if (slash <= 0) return false;
    final prefix = int.tryParse(c.substring(slash + 1).trim());
    return _ipToInt(c.substring(0, slash).trim()) != null &&
        prefix != null &&
        prefix >= 16 &&
        prefix <= 30;
  }

  /// IP "virtual" que expone el túnel cuando el MikroTik usa **netmap**:
  /// conserva la última octeta de la IP real y le pone el prefijo de la
  /// subred del túnel. Es la clave para que dos empresas con la misma red
  /// local (ej. 192.168.1.x) puedan tener antenas distintas por el túnel:
  ///
  ///   `192.168.1.10` + `10.10.15.0/24`  →  `10.10.15.10`
  ///   `192.168.1.20` + `10.10.15.0/24`  →  `10.10.15.20`
  ///
  /// La regla del MikroTik que lo hace real:
  /// ```routeros
  /// /ip firewall nat add chain=dstnat in-interface=wg1 \
  ///   dst-address=10.10.15.1-10.10.15.254 action=netmap \
  ///   to-addresses=192.168.1.1-192.168.1.254 place-before=0
  /// ```
  static String ipVirtual(String ipReal, String redTunel) {
    final o = ipReal.trim().split('.');
    final p = redTunel.split('/').first.trim().split('.');
    if (o.length != 4 || p.length != 4) return ipReal.trim();
    final ultima = int.tryParse(o[3]);
    if (ultima == null || ultima < 0 || ultima > 255) return ipReal.trim();
    return '${p[0]}.${p[1]}.${p[2]}.$ultima';
  }

  /// Comando RouterOS listo para pegar en el MikroTik cuando se usa netmap.
  /// Mapea 1:1 la subred del túnel con tu red local (misma última octeta).
  static String comandoNetmap({
    required String redTunel,
    required String redLocal,
    String interfaz = 'wg1',
  }) {
    final t = redTunel.split('/').first.trim().split('.');
    final l = redLocal.split('/').first.trim().split('.');
    if (t.length != 4 || l.length != 4) return '';
    final tBase = '${t[0]}.${t[1]}.${t[2]}';
    final lBase = '${l[0]}.${l[1]}.${l[2]}';
    return '/ip firewall nat add chain=dstnat in-interface=$interfaz '
        'dst-address=$tBase.1-$tBase.254 action=netmap '
        'to-addresses=$lBase.1-$lBase.254 place-before=0 '
        'comment="StarkGo netmap"';
  }

  /// Prueba si un equipo responde por HTTP/HTTPS (se usa con el túnel arriba).
  ///
  /// Es la forma de comprobar la **regla netmap**: si la IP virtual responde,
  /// la traducción está bien hecha. No sigue redirecciones a propósito: un
  /// `301`/`302` ya demuestra que el equipo contestó.
  static Future<PruebaConexion> probarIp(
    String ip, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final host = ip.trim();
    if (host.isEmpty) {
      return const PruebaConexion(ok: false, detalle: 'IP vacía');
    }

    // 1) Web normal: http:// y https:// (sin seguir redirecciones: un
    //    301/302 ya demuestra que el equipo contestó).
    for (final url in ['http://$host/', 'https://$host/']) {
      try {
        final code = await _getSimple(url, timeout);
        return PruebaConexion(
            ok: true, detalle: 'respondió en ${Uri.parse(url).host}:${Uri.parse(url).port}', http: code);
      } catch (e) {
        // Certificado autofirmado (típico airOS): respondió a nivel TLS.
        if (_esErrorTls(e)) {
          return const PruebaConexion(
              ok: true,
              detalle: 'respondió por HTTPS (certificado autofirmado)');
        }
      }
    }

    // 2) Puertos típicos de WebFig/airOS en modo seguro (8085, 8080).
    for (final url in ['http://$host:8085/', 'http://$host:8080/']) {
      try {
        final code = await _getSimple(url, const Duration(seconds: 3));
        return PruebaConexion(
            ok: true, detalle: 'respondió en $host:${Uri.parse(url).port}', http: code);
      } catch (e) {
        if (_esErrorTls(e)) {
          return const PruebaConexion(
              ok: true, detalle: 'respondió por HTTPS (certificado autofirmado)');
        }
      }
    }

    return PruebaConexion(
        ok: false,
        detalle:
            'no respondió en ${timeout.inSeconds}s (probé http, https, :8085 y :8080)');
  }

  /// GET que acepta cualquier respuesta (incluso error) y no sigue redirects.
  static Future<int> _getSimple(String url, Duration timeout) async {
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url))..followRedirects = false;
      final resp = await client.send(req).timeout(timeout);
      return resp.statusCode;
    } finally {
      client.close();
    }
  }

  /// true si la excepción es de TLS/certificado (el equipo SÍ contestó).
  static bool _esErrorTls(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('handshake') ||
        s.contains('certificate') ||
        s.contains('tls') ||
        s.contains('ssl');
  }

  /// Stream en tiempo real de las antenas del usuario/técnico autenticado:
  /// clientes con `ipatn` + sectoriales registrados en `sectoriales`.
  static Stream<List<AntenaModel>> antenasStream({required String uid}) {
    final clientesStream = FirebaseFirestore.instance
        .collection(_coleccionClientes)
        .where('propietarioUid', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map(AntenaModel.fromCliente)
            .where((a) => a.ip.isNotEmpty) // solo clientes con antena asignada
            .toList());

    final sectorialesStream = FirebaseFirestore.instance
        .collection(_coleccionSectoriales)
        .where('propietarioUid', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map(AntenaModel.fromSectorial)
            .where((a) => a.ip.isNotEmpty)
            .toList());

    return Rx.combineLatest2(clientesStream, sectorialesStream, (clientes, sectoriales) {
      final lista = [...clientes, ...sectoriales];
      lista.sort((a, b) {
        final cmp = a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
        if (cmp != 0) return cmp;
        return (a.esSectorial ? 1 : 0) - (b.esSectorial ? 1 : 0);
      });
      return lista;
    });
  }

  /// Crea o actualiza un sectorial en la colección `sectoriales`.
  static Future<void> guardarSectorial({
    required String uid,
    String? docId,
    required String nombre,
    required String ip,
    String estado = 'activo',
    String? marca,
    String? modelo,
    String? usuario,
    String? clave,
    String? notas,
  }) async {
    final payload = <String, dynamic>{
      'propietarioUid': uid,
      'nombre': nombre.trim(),
      'ip': ip.trim(),
      'estado': estado,
      if (marca != null && marca.trim().isNotEmpty) 'marca': marca.trim(),
      if (modelo != null && modelo.trim().isNotEmpty) 'modelo': modelo.trim(),
      if (usuario != null && usuario.trim().isNotEmpty) 'usuarioatn': usuario.trim(),
      if (clave != null && clave.trim().isNotEmpty) 'claveatn': clave.trim(),
      if (notas != null && notas.trim().isNotEmpty) 'notas': notas.trim(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    };
    final ref = docId != null
        ? FirebaseFirestore.instance.collection(_coleccionSectoriales).doc(docId)
        : FirebaseFirestore.instance.collection(_coleccionSectoriales).doc();
    await ref.set(payload, SetOptions(merge: true));
  }

  /// Elimina un sectorial de la colección `sectoriales`.
  static Future<void> eliminarSectorial(String docId) async {
    await FirebaseFirestore.instance.collection(_coleccionSectoriales).doc(docId).delete();
  }

  /// Devuelve la próxima IP libre dentro de la subred de antenas del usuario
  /// (hosts 2..250), teniendo en cuenta las IPs de antena (`ipatn`) de
  /// `clientes`, los `sectoriales` del usuario y su propia vpn_config.
  static Future<String?> siguienteIpLibre({
    required String uid,
    String cidr = '10.10.15.0/24',
  }) async {
    final base = cidr.split('/').first.trim();
    if (!ipEnSubred('${base}10', cidr)) return null;
    final usadas = <String>{};
    try {
      final clientes = await FirebaseFirestore.instance
          .collection(_coleccionClientes)
          .where('propietarioUid', isEqualTo: uid)
          .get();
      for (final doc in clientes.docs) {
        final ip = (doc.data()['ipatn'] ?? '').toString().trim();
        if (ipEnSubred(ip, cidr)) usadas.add(ip);
      }
      final sectoriales = await FirebaseFirestore.instance
          .collection(_coleccionSectoriales)
          .where('propietarioUid', isEqualTo: uid)
          .get();
      for (final doc in sectoriales.docs) {
        final ip = (doc.data()['ip'] ?? '').toString().trim();
        if (ipEnSubred(ip, cidr)) usadas.add(ip);
      }
      final cfg = await FirebaseFirestore.instance
          .collection('vpn_config')
          .doc(uid)
          .get();
      if (cfg.exists) {
        final address = (cfg.data()?['address'] ?? '').toString(); // ej: 10.50.50.6/32
        final ip = address.split('/').first.trim();
        if (ipEnSubred(ip, cidr)) usadas.add(ip);
      }
    } catch (_) {
      // Si no se puede leer, seguimos con el rango vacío.
    }
    final partes = base.split('.');
    for (int i = 2; i <= 250; i++) {
      final candidata = '${partes[0]}.${partes[1]}.${partes[2]}.$i';
      if (!usadas.contains(candidata)) return candidata;
    }
    return null;
  }
}

