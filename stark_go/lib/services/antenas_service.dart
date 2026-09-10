import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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

