import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mikrotik_local_api.dart';
import 'vps_service.dart';

// ══════════════════════════════════════════════════════════════════════
//  🛡️ BLINDAJE DEL ADMINISTRADOR (mi teléfono)
//
//  Mientras estás creando fichas o configurando el hotspot, TU teléfono no
//  tiene que pedirte una ficha/PIN: queda **bypassed** en el hotspot del
//  MikroTik (`/ip hotspot ip-binding type=bypassed`).
//
//  Se puede blindar por **MAC** (sobrevive a los cambios de IP del DHCP) y/o
//  por **IP** (sirve cuando el celular usa MAC aleatoria, típico en Android 10+
//  y en iPhone: ahí la MAC cambia por red y la IP es la referencia confiable).
//
//  Dónde queda guardado:
//    `config_mikrotik/{uid}.blindajeAdmin` = { activo, auto, macs[], ips[] }
//    (se guarda con `merge`, así no pisa el resto de la configuración)
//    + una copia local en SharedPreferences para poder leerlo **sin internet**
//      cuando estás parado en la red del hotspot.
//
//  Cómo se aplica (se intentan las dos, en este orden):
//    1. **Directo** al MikroTik por la API local (panel local conectado)
//       → queda aplicado al instante.
//    2. **Por la cola del VPS** (acción `hotspot-blindar-admin`) → el router lo
//       aplica en el próximo ciclo del scheduler (sirve a distancia, por el
//       túnel VPN).
// ══════════════════════════════════════════════════════════════════════

// Import condicional: en web no existe `dart:io`, así que devuelve vacío.
import 'blindaje_admin_ips_stub.dart'
    if (dart.library.io) 'blindaje_admin_ips_io.dart' as ips_impl;

/// Configuración guardada del blindaje del administrador.
class BlindajeAdminConfig {
  const BlindajeAdminConfig({
    this.activo = false,
    this.auto = true,
    this.macs = const [],
    this.ips = const [],
  });

  /// ¿El blindaje está encendido? (se prende al aplicar con éxito)
  final bool activo;

  /// Blindar automáticamente al crear fichas o abrir el panel del hotspot.
  final bool auto;

  /// MACs (AA:BB:CC:DD:EE:FF) de los equipos del administrador.
  final List<String> macs;

  /// IPs de los equipos del administrador (incluye la del túnel VPN).
  final List<String> ips;

  bool get tieneAlgo => macs.isNotEmpty || ips.isNotEmpty;

  BlindajeAdminConfig copyWith({
    bool? activo,
    bool? auto,
    List<String>? macs,
    List<String>? ips,
  }) {
    return BlindajeAdminConfig(
      activo: activo ?? this.activo,
      auto: auto ?? this.auto,
      macs: macs ?? this.macs,
      ips: ips ?? this.ips,
    );
  }

  Map<String, dynamic> toMap() => {
        'activo': activo,
        'auto': auto,
        'macs': macs,
        'ips': ips,
        'actualizado': FieldValue.serverTimestamp(),
      };

  static BlindajeAdminConfig fromMap(dynamic v) {
    if (v is! Map) return const BlindajeAdminConfig();
    List<String> lista(dynamic x) => x is List
        ? x
            .map((e) => '$e'.trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : const <String>[];
    return BlindajeAdminConfig(
      activo: v['activo'] == true,
      auto: v['auto'] != false, // por defecto: sí
      macs: lista(v['macs']),
      ips: lista(v['ips']),
    );
  }
}

/// Resultado de aplicar el blindaje.
class ResultadoBlindaje {
  const ResultadoBlindaje({
    required this.local,
    required this.cola,
    required this.aplicados,
    this.error,
  });

  /// Se aplicó directo al router (API local).
  final bool local;

  /// Se encoló en el VPS (el router lo aplica en el próximo ciclo).
  final bool cola;

  /// Cuántos bindings se crearon por la vía local.
  final int aplicados;

  /// Detalle del error, si hubo.
  final String? error;

  bool get ok => local || cola;

  String get detalle {
    if (local && cola) return 'Blindado: aplicado en el router y encolado en el VPS.';
    if (local) return 'Blindado en el router (se aplicó directo).';
    if (cola) return 'Encolado: el router lo aplica en el próximo ciclo (1-5 min).';
    return error ?? 'No se pudo blindar.';
  }
}

class BlindajeAdminService {
  static const String _colConfig = 'config_mikrotik';
  static const String _campo = 'blindajeAdmin';
  static const String _prefsKey = 'sg_blindaje_admin';
  static const String _prefsUltimoAuto = 'sg_blindaje_admin_ultimo';

  /// No repetimos el auto-blindaje antes de este tiempo (evita encolar el
  /// mismo comando en cada ficha que creás).
  static const Duration esperaEntreAuto = Duration(minutes: 5);

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ─────────────────────────────────────────────────────────────
  // Normalización / validaciones
  // ─────────────────────────────────────────────────────────────

  /// MAC normalizada (AA:BB:CC:DD:EE:FF) o `null` si no es válida.
  static String? normalizarMac(String? mac) {
    final s = (mac ?? '').toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
    if (s.length != 12) return null;
    return RegExp(r'.{2}').allMatches(s).map((m) => m.group(0)).join(':');
  }

  /// ¿Es una IPv4 válida?
  static bool esIp(String? v) =>
      RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch((v ?? '').trim());

  /// ¿Es una MAC válida (en cualquier formato: `AA-BB-…`, `aabb.ccdd.…`, etc.)?
  static bool esMac(String? v) => normalizarMac(v) != null;

  /// Nombre corto y seguro para el `comment=` de RouterOS.
  static String _nombreSeguro([String? preferido]) {
    var base = (preferido ?? '').trim();
    if (base.isEmpty) {
      final u = FirebaseAuth.instance.currentUser;
      base = (u?.displayName ?? '').trim();
      if (base.isEmpty && u?.email != null) base = u!.email!.split('@').first;
    }
    if (base.isEmpty) base = 'admin';
    base = base
        .replaceAll(RegExp(r'[\r\n"$;\\`{}]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (base.isEmpty) base = 'admin';
    return base.length > 32 ? base.substring(0, 32) : base;
  }

  // ─────────────────────────────────────────────────────────────
  // Config (Firestore + copia local)
  // ─────────────────────────────────────────────────────────────

  static Future<void> _cachear(BlindajeAdminConfig cfg) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'activo': cfg.activo,
          'auto': cfg.auto,
          'macs': cfg.macs,
          'ips': cfg.ips,
        }),
      );
    } catch (_) {}
  }

  /// Lee la configuración: primero la copia local (sirve sin internet) y, si
  /// hay sesión, también la de Firestore (fuente de verdad).
  static Future<BlindajeAdminConfig> cargar() async {
    BlindajeAdminConfig local = const BlindajeAdminConfig();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        local = BlindajeAdminConfig.fromMap(jsonDecode(raw));
      }
    } catch (_) {}

    final uid = _uid;
    if (uid == null) return local;
    try {
      final doc =
          await FirebaseFirestore.instance.collection(_colConfig).doc(uid).get();
      final cfg = BlindajeAdminConfig.fromMap((doc.data() ?? const {})[_campo]);
      await _cachear(cfg);
      return cfg;
    } catch (e) {
      debugPrint('[Blindaje] No pude leer la config: $e');
      return local;
    }
  }

  /// Guarda la configuración (merge: no toca el resto de `config_mikrotik`).
  static Future<bool> guardar(BlindajeAdminConfig cfg) async {
    await _cachear(cfg);
    final uid = _uid;
    if (uid == null) return false;
    try {
      await FirebaseFirestore.instance
          .collection(_colConfig)
          .doc(uid)
          .set({_campo: cfg.toMap()}, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('[Blindaje] No pude guardar la config: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Detección
  // ─────────────────────────────────────────────────────────────

  /// IPs IPv4 de ESTE teléfono (Wi-Fi, datos y túnel VPN si está conectado).
  static Future<List<String>> misIps() => ips_impl.ipsLocalesDelTelefono();

  /// De la lista de equipos del hotspot, devuelve los que son ESTE teléfono
  /// (los que tienen una de mis IPs): `{ip, mac, nombre}`.
  static List<Map<String, String>> detectarme(
    List<Map<String, dynamic>> hosts,
    List<String> misIps,
  ) {
    String campo(Map<String, dynamic> h, List<String> claves) {
      for (final k in claves) {
        final v = h[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return '';
    }

    final mias = misIps.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final salida = <Map<String, String>>[];
    for (final h in hosts) {
      final ip = campo(h, const ['address']);
      if (ip.isEmpty || !mias.contains(ip)) continue;
      final mac =
          normalizarMac(campo(h, const ['mac-address', 'macAddress'])) ?? '';
      final nombre = campo(h, const ['host-name', 'hostName', 'comment']);
      salida.add({
        'ip': ip,
        'mac': mac,
        'nombre': nombre.isEmpty ? ip : nombre,
      });
    }
    return salida;
  }

  // ─────────────────────────────────────────────────────────────
  // Aplicar el blindaje
  // ─────────────────────────────────────────────────────────────

  /// Blinda las MACs y/o IPs indicadas (vía local + cola del VPS) y lo deja
  /// guardado en la configuración.
  static Future<ResultadoBlindaje> blindar({
    List<String> macs = const [],
    List<String> ips = const [],
    MikrotikLocalApi? apiLocal,
    String? nombre,
    bool guardarConfig = true,
  }) async {
    final macsOk = macs.map(normalizarMac).whereType<String>().toSet().toList();
    final ipsOk = ips.map((e) => e.trim()).where(esIp).toSet().toList();
    if (macsOk.isEmpty && ipsOk.isEmpty) {
      return const ResultadoBlindaje(
        local: false,
        cola: false,
        aplicados: 0,
        error: 'No hay ninguna MAC ni IP válida para blindar.',
      );
    }
    final quien = _nombreSeguro(nombre);

    // (1) Directo al router (instantáneo, si hay panel local conectado).
    var localOk = false;
    var aplicados = 0;
    String? error;
    if (apiLocal != null) {
      try {
        for (final mac in macsOk) {
          if (await apiLocal.blindarDispositivo(
              mac: mac, comentario: 'StarkGo ADMIN $quien')) {
            aplicados++;
          }
        }
        for (final ip in ipsOk) {
          if (await apiLocal.blindarDispositivo(
              ip: ip, comentario: 'StarkGo ADMIN $quien')) {
            aplicados++;
          }
        }
        localOk = aplicados > 0;
      } catch (e) {
        error = '$e';
        debugPrint('[Blindaje] La vía local falló: $e');
      }
    }

    // (2) Por la cola del VPS (sirve también a distancia / por el túnel).
    var colaOk = false;
    try {
      for (final mac in macsOk) {
        final ok = await VpsService.encolar({
          'accion': 'hotspot-blindar-admin',
          'nombre': quien,
          'mac': mac,
        });
        colaOk = colaOk || ok;
      }
      for (final ip in ipsOk) {
        final ok = await VpsService.encolar({
          'accion': 'hotspot-blindar-admin',
          'nombre': quien,
          'ip': ip,
        });
        colaOk = colaOk || ok;
      }
    } catch (e) {
      error ??= '$e';
      debugPrint('[Blindaje] La cola del VPS falló: $e');
    }

    if (guardarConfig) {
      final cfg = await cargar();
      await guardar(cfg.copyWith(
        activo: cfg.activo || localOk || colaOk,
        macs: {...cfg.macs, ...macsOk}.toList(),
        ips: {...cfg.ips, ...ipsOk}.toList(),
      ));
    }

    return ResultadoBlindaje(
      local: localOk,
      cola: colaOk,
      aplicados: aplicados,
      error: error,
    );
  }

  /// Saca una IP o MAC de la lista guardada. (No borra el binding del router:
  /// para eso se quita desde el MikroTik o con `/ip hotspot ip-binding remove`.)
  static Future<BlindajeAdminConfig> olvidar({String? ip, String? mac}) async {
    final cfg = await cargar();
    final macOk = normalizarMac(mac);
    final nueva = cfg.copyWith(
      macs: cfg.macs.where((m) => m != macOk).toList(),
      ips: cfg.ips.where((i) => i != (ip ?? '').trim()).toList(),
    );
    await guardar(nueva.copyWith(activo: nueva.tieneAlgo && nueva.activo));
    return nueva;
  }

  // ─────────────────────────────────────────────────────────────
  // Auto-blindaje (se llama al crear fichas o abrir el panel)
  // ─────────────────────────────────────────────────────────────

  /// Si el auto-blindaje está activo, blinda mi equipo con lo guardado **+ la
  /// IP actual** del teléfono (así sigue funcionando aunque el DHCP le haya
  /// dado otra IP o el celular use MAC aleatoria).
  ///
  /// Es best-effort: nunca lanza excepción ni frena la creación de fichas.
  static Future<ResultadoBlindaje?> autoBlindar({
    MikrotikLocalApi? apiLocal,
    String? nombre,
    bool ignorarEspera = false,
  }) async {
    try {
      final cfg = await cargar();
      if (!cfg.auto) return null;

      // Anti-repetición: no encolamos el mismo blindaje con cada ficha.
      if (!ignorarEspera) {
        final prefs = await SharedPreferences.getInstance();
        final ultimo = prefs.getInt(_prefsUltimoAuto) ?? 0;
        final ahora = DateTime.now().millisecondsSinceEpoch;
        if (ultimo > 0 && ahora - ultimo < esperaEntreAuto.inMilliseconds) {
          return null;
        }
        await prefs.setInt(_prefsUltimoAuto, ahora);
      }

      final actuales = await misIps();
      final ips = {...cfg.ips, ...actuales}.toList();
      if (cfg.macs.isEmpty && ips.isEmpty) return null;

      debugPrint('[Blindaje] Auto-blindaje → macs=${cfg.macs} ips=$ips');
      return await blindar(
        macs: cfg.macs,
        ips: ips,
        apiLocal: apiLocal,
        nombre: nombre,
        guardarConfig: true,
      );
    } catch (e) {
      debugPrint('[Blindaje] Auto-blindaje omitido: $e');
      return null;
    }
  }
}

