import 'package:cloud_firestore/cloud_firestore.dart';

// ══════════════════════════════════════════════════════════════
//  AntenasService — listado de antenas accesibles por la VPN.
//
//  Las antenas viven en la colección `clientes`, en el campo `ipatn`
//  (junto con status, usuarioatn/claveatn y antenaMarca/antenaModelo).
//  Se consultan filtradas por `propietarioUid` = usuario autenticado.
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

  /// Estados que habilitan abrir la interfaz airOS.
  bool get esAccesible => estado == 'activo' || estado == 'en_linea';

  /// true si la IP está dentro de la subred de antenas del usuario.
  bool ipValida(String redAntenas) => AntenasService.ipEnSubred(ip, redAntenas);

  /// URL de la interfaz airOS nativa.
  String get urlAirOs => 'http://$ip';

  /// Mapea un documento de `clientes` → antena (campo `ipatn`).
  factory AntenaModel.fromCliente(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? const {};
    final nombreCompleto = '${d['nombre'] ?? ''} ${d['apellido'] ?? ''}'.trim();
    return AntenaModel(
      id: doc.id,
      nombre: nombreCompleto.isEmpty ? doc.id : nombreCompleto,
      ip: (d['ipatn'] ?? '').toString().trim(),
      estado: (d['status'] ?? 'desconocido').toString(),
      notas: (d['notas'] ?? '').toString().isEmpty ? null : d['notas'].toString(),
      marca: (d['antenaMarca'] ?? '').toString().isEmpty ? null : d['antenaMarca'].toString(),
      modelo: (d['antenaModelo'] ?? '').toString().isEmpty ? null : d['antenaModelo'].toString(),
      usuarioAtn: (d['usuarioatn'] ?? '').toString().isEmpty ? null : d['usuarioatn'].toString(),
      claveAtn: (d['claveatn'] ?? '').toString().isEmpty ? null : d['claveatn'].toString(),
    );
  }
}

class AntenasService {
  static const String _coleccionClientes = 'clientes';

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

  /// Stream en tiempo real de las antenas del usuario/técnico autenticado.
  /// Consulta la colección `clientes` por `propietarioUid` y toma el campo
  /// `ipatn` de cada documento con antena asignada.
  static Stream<List<AntenaModel>> antenasStream({required String uid}) {
    final query = FirebaseFirestore.instance
        .collection(_coleccionClientes)
        .where('propietarioUid', isEqualTo: uid);
    return query.snapshots().map((snap) {
      final lista = snap.docs
          .map(AntenaModel.fromCliente)
          .where((a) => a.ip.isNotEmpty) // solo clientes con antena asignada
          .toList();
      lista.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      return lista;
    });
  }

  /// Devuelve la próxima IP libre dentro de la subred de antenas del usuario
  /// (hosts 2..250), teniendo en cuenta las IPs de antena (`ipatn`) de
  /// `clientes` del usuario y su propia vpn_config.
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

