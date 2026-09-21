import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'mikrotik_local_api.dart';
import 'vps_service.dart';

// ══════════════════════════════════════════════════════════════════════
//  📌 LEASES DHCP DEL MIKROTIK — «¿qué IP le dio el router a la antena?»
//
//  Cuando conectás una antena, el MikroTik le asigna una IP por DHCP. Para
//  registrar el cliente necesitás ESA IP (campo `ipatn`) y antes había que
//  entrar a WinBox a buscarla.
//
//  Este servicio la trae a la app por dos caminos:
//    1. **Directo al router** (API local 8728/8729) si estás en la red o por
//       el túnel → instantáneo.
//    2. **Por el VPS** (`GET /mikrotik/leases`, que habla REST con el router)
//       → funciona desde cualquier lado.
//
//  Además permite **marcar** un lease: queda ESTÁTICO (la antena conserva la
//  IP), con comentario `StarkGo <cliente>` y la IP en la address-list
//  `starkgo`. Eso mismo se aplica solo al crear un cliente.
// ══════════════════════════════════════════════════════════════════════

String _texto(dynamic v) => (v ?? '').toString().trim();

bool _bool(dynamic v) => v == true || _texto(v).toLowerCase() == 'true';

/// Un lease (IP asignada) del DHCP del MikroTik.
class LeaseDhcp {
  const LeaseDhcp({
    required this.ip,
    this.id,
    this.mac = '',
    this.nombre = '',
    this.comentario = '',
    this.dinamica = true,
    this.estado = '',
    this.visto = '',
    this.caduca = '',
    this.usadoPor = '',
    this.esSectorial = false,
  });

  /// `.id` interno de RouterOS (para poder editar el lease).
  final String? id;

  final String ip;
  final String mac;

  /// Nombre del equipo que reporta el router (`host-name`).
  final String nombre;

  /// Comentario del lease (si dice `StarkGo …` ya está marcado).
  final String comentario;

  /// `true` = la IP la dio el DHCP y todavía no es fija.
  final bool dinamica;

  /// `bound` / `waiting-for-lease` / …
  final String estado;

  /// Última vez visto (`last-seen`) y cuándo vence (`expires-after`).
  final String visto;
  final String caduca;

  /// Quién usa esa IP según LA APP: `Cliente: Juan`, `Sectorial: Base 1` o ''.
  final String usadoPor;

  /// `true` si la IP pertenece a un equipo del operador (sectorial).
  final bool esSectorial;

  /// ¿Ya está marcada como StarkGo?
  bool get esStark => comentario.toLowerCase().contains('starkgo');

  /// ¿La IP no está usada por ningún cliente/sectorial de la app?
  bool get libre => usadoPor.isEmpty;

  LeaseDhcp copyWith({String? usadoPor, bool? esSectorial}) => LeaseDhcp(
        id: id,
        ip: ip,
        mac: mac,
        nombre: nombre,
        comentario: comentario,
        dinamica: dinamica,
        estado: estado,
        visto: visto,
        caduca: caduca,
        usadoPor: usadoPor ?? this.usadoPor,
        esSectorial: esSectorial ?? this.esSectorial,
      );

  /// Desde la API local del router (`/ip dhcp-server/lease/print`).
  static LeaseDhcp desdeLocal(Map<String, dynamic> l) => LeaseDhcp(
        id: _texto(l['.id']).isEmpty ? null : _texto(l['.id']),
        ip: _texto(l['address']),
        mac: _texto(l['mac-address']),
        nombre: _texto(l['host-name']),
        comentario: _texto(l['comment']),
        dinamica: _bool(l['dynamic']),
        estado: _texto(l['status']),
        visto: _texto(l['last-seen']),
        caduca: _texto(l['expires-after']),
      );

  /// Desde el VPS (`GET /mikrotik/leases`).
  static LeaseDhcp desdeVps(Map<String, dynamic> j) => LeaseDhcp(
        id: _texto(j['id']).isEmpty ? null : _texto(j['id']),
        ip: _texto(j['ip']),
        mac: _texto(j['mac']),
        nombre: _texto(j['nombre']),
        comentario: _texto(j['comentario']),
        dinamica: j['dinamica'] == true,
        estado: _texto(j['estado']),
        visto: _texto(j['visto']),
        caduca: _texto(j['caduca']),
      );
}

/// Resultado de pedir los leases.
class LeasesResultado {
  const LeasesResultado({
    required this.leases,
    required this.fuente,
    this.error,
  });

  final List<LeaseDhcp> leases;

  /// `'local'` = directo al router · `'vps'` = por el servidor · `'error'`.
  final String fuente;
  final String? error;

  bool get ok => error == null;

  /// Texto corto para mostrar de dónde salió la lista.
  String get fuenteTexto => switch (fuente) {
        'local' => 'Directo al router',
        'vps' => 'Por el VPS',
        _ => 'Sin conexión',
      };
}

/// Resultado de marcar un lease.
class MarcarLeaseResultado {
  const MarcarLeaseResultado({
    required this.ok,
    required this.detalle,
    this.porLocal = false,
  });

  final bool ok;
  final String detalle;

  /// `true` si se aplicó directo al router (si no, fue por el VPS/cola).
  final bool porLocal;
}

class MikrotikLeasesService {
  static const String _colClientes = 'clientes';
  static const String _colSectoriales = 'sectoriales';

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ─────────────────────────────────────────────────────────────
  // Lectura
  // ─────────────────────────────────────────────────────────────

  /// Trae los leases del MikroTik y los cruza con tus clientes/sectoriales.
  /// Intenta **directo al router** (si viene `apiLocal`) y después **por el VPS**.
  static Future<LeasesResultado> cargar({MikrotikLocalApi? apiLocal}) async {
    String? errorLocal;

    // (1) Directo al router — instantáneo si estás en la red o por el túnel.
    if (apiLocal != null) {
      try {
        final crudos = await apiLocal.obtenerLeasesDhcp();
        final lista = crudos
            .map(LeaseDhcp.desdeLocal)
            .where((l) => l.ip.isNotEmpty)
            .toList();
        return LeasesResultado(leases: await _cruzar(lista), fuente: 'local');
      } catch (e) {
        errorLocal = '$e';
        debugPrint('[Leases] Directo al router falló: $e');
      }
    }

    // (2) Por el VPS (el servidor habla REST con el router).
    final json = await VpsService.obtenerLeases();
    if (json != null && json['ok'] == true) {
      final lista = (json['leases'] as List? ?? [])
          .whereType<Map>()
          .map((m) => LeaseDhcp.desdeVps(Map<String, dynamic>.from(m)))
          .where((l) => l.ip.isNotEmpty)
          .toList();
      return LeasesResultado(leases: await _cruzar(lista), fuente: 'vps');
    }

    return LeasesResultado(
      leases: const [],
      fuente: 'error',
      error: errorLocal == null
          ? 'No pude llegar al MikroTik. Revisá que el VPS tenga la IP, el usuario '
              'y la clave del router, y que el servicio www-ssl esté activo.'
          : 'Directo al router: $errorLocal\nPor el VPS: tampoco respondió.',
    );
  }

  /// Marca el lease de una IP: **ESTÁTICO** + comentario `StarkGo <nombre>` +
  /// address-list `starkgo`. Primero directo al router y, si no, por el VPS.
  static Future<MarcarLeaseResultado> marcar({
    required String ip,
    required String nombre,
    MikrotikLocalApi? apiLocal,
  }) async {
    final ipOk = ip.trim();
    final nombreOk = nombre.trim().isEmpty ? 'cliente' : nombre.trim();
    if (ipOk.isEmpty) {
      return const MarcarLeaseResultado(ok: false, detalle: 'Falta la IP.');
    }

    // (1) Directo al router.
    if (apiLocal != null) {
      try {
        final r = await apiLocal.marcarLeaseDhcp(ip: ipOk, nombre: nombreOk);
        if (r['estatica'] == true || r['lista'] == true) {
          final partes = <String>[
            if (r['estatica'] == true) 'IP fija (estática)',
            if (r['comentario'] == true) 'comentario StarkGo',
            if (r['lista'] == true) 'lista starkgo',
          ];
          return MarcarLeaseResultado(
            ok: true,
            porLocal: true,
            detalle: 'Listo en el router: ${partes.join(' · ')}.',
          );
        }
      } catch (e) {
        debugPrint('[Leases] Marcar directo falló: $e');
      }
    }

    // (2) Por el VPS (REST instantáneo o cola).
    final ok = await VpsService.marcarLease(ip: ipOk, nombre: nombreOk);
    return MarcarLeaseResultado(
      ok: ok,
      detalle: ok
          ? 'Enviado al VPS: el router lo aplica ahora (o en el próximo ciclo de la cola).'
          : 'No pude marcarlo. Revisá la API Key y que el VPS llegue al MikroTik.',
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Cruce con la app: ¿esa IP ya es de un cliente o sectorial?
  // ─────────────────────────────────────────────────────────────

  /// Marca en cada lease quién lo usa según `clientes.ipatn` y `sectoriales.ip`.
  static Future<List<LeaseDhcp>> _cruzar(List<LeaseDhcp> leases) async {
    final uid = _uid;
    if (uid == null || leases.isEmpty) return leases;
    final usos = <String, Map<String, dynamic>>{};

    try {
      final clientes = await FirebaseFirestore.instance
          .collection(_colClientes)
          .where('propietarioUid', isEqualTo: uid)
          .get();
      for (final d in clientes.docs) {
        final c = d.data();
        final ip = _texto(c['ipatn']);
        if (ip.isEmpty) continue;
        final nombre = '${_texto(c['nombre'])} ${_texto(c['apellido'])}'.trim();
        usos[ip] = {
          'texto': 'Cliente: ${nombre.isEmpty ? 'sin nombre' : nombre}',
          'sectorial': false,
        };
      }
    } catch (e) {
      debugPrint('[Leases] No pude leer clientes: $e');
    }

    try {
      final sec = await FirebaseFirestore.instance
          .collection(_colSectoriales)
          .where('propietarioUid', isEqualTo: uid)
          .get();
      for (final d in sec.docs) {
        final c = d.data();
        final ip = _texto(c['ip']);
        if (ip.isEmpty) continue;
        final nombre = _texto(c['nombre']);
        usos[ip] = {
          'texto': 'Sectorial: ${nombre.isEmpty ? 'sin nombre' : nombre}',
          'sectorial': true,
        };
      }
    } catch (e) {
      debugPrint('[Leases] No pude leer sectoriales: $e');
    }

    final salida = leases.map((l) {
      final uso = usos[l.ip];
      if (uso == null) return l;
      return l.copyWith(
        usadoPor: uso['texto'] as String,
        esSectorial: uso['sectorial'] as bool,
      );
    }).toList();

    // 🎯 Las DINÁMICAS van primero: son las que estás buscando cuando recién
    // conectás una antena. Después, ordenadas por IP.
    salida.sort((a, b) {
      if (a.dinamica != b.dinamica) return a.dinamica ? -1 : 1;
      return _ordenIp(a.ip, b.ip);
    });
    return salida;
  }

  /// Ordena IPs numéricamente (192.168.1.9 antes que 192.168.1.10).
  static int _ordenIp(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 4; i++) {
      final ia = i < pa.length ? pa[i] : 0;
      final ib = i < pb.length ? pb[i] : 0;
      if (ia != ib) return ia.compareTo(ib);
    }
    return 0;
  }
}
