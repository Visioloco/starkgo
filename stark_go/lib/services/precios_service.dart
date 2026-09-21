import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'pais_service.dart';

// ══════════════════════════════════════════════════════════════
//  PreciosService — tasa USD→COP, formato de precios y estado de las
//  pasarelas de pago.
//
//  Los planes están en USD (lo que ve el cliente) y las pasarelas
//  colombianas (Mercado Pago, Rapid, ePayco) cobran en COP. Para que el
//  precio MOSTRADO y el COBRADO nunca se desincronicen, la tasa vive en el
//  VPS (`GET /precios`, variable de entorno USD_A_COP) y la app la trae de ahí.
//
//  Si el VPS no responde se usa [kUsdACopPorDefecto] (3200) para que la
//  app nunca quede sin mostrar el precio.
// ══════════════════════════════════════════════════════════════
class PreciosService {
  static const String _vpsUrl = 'http://5.161.88.42:3000';

  /// Tasa de respaldo, solo por si el VPS no responde todavía.
  static const double kUsdACopPorDefecto = 3200;

  static double _usdACop = kUsdACopPorDefecto;
  static bool _cargado = false;
  static String _fuente = '';
  static String _actualizado = '';
  static int _ultimoMs = 0;

  /// `config_pagos/rapid.produccion` informado por el VPS:
  /// · true  → Rapid está en PRODUCCIÓN → el botón se muestra
  /// · false → Rapid está en SANDBOX   → el botón se oculta
  /// · null  → todavía no sabemos (usar el valor compilado de respaldo)
  static bool? _rapidProduccion;

  /// COP ya calculado por el VPS para cada plan (id → COP).
  static final Map<String, int> _copPorPlan = {};

  /// Tasa USD→COP que se está usando.
  static double get usdACop => _usdACop;

  /// true si la tasa vino del VPS (no del respaldo).
  static bool get esTasaDelVps => _cargado;

  /// Estado de Rapid según Firestore (`config_pagos/rapid.produccion`).
  static bool? get rapidProduccion => _rapidProduccion;

  /// Avisa a la UI al instante cuando cambia `produccion` (tiempo real).
  static final ValueNotifier<bool?> rapidProduccionNotifier =
      ValueNotifier<bool?>(null);

  /// `config_pagos/epayco.produccion` informado por el VPS:
  /// · true  → ePayco está configurado y en PRODUCCIÓN → el botón se muestra
  /// · false → ePayco en PRUEBAS o sin llaves          → el botón se oculta
  /// · null  → todavía no sabemos (usar el valor compilado de respaldo)
  static bool? _epaycoProduccion;

  /// Avisa a la UI al instante cuando cambia la producción de ePayco.
  static final ValueNotifier<bool?> epaycoProduccionNotifier =
      ValueNotifier<bool?>(null);

  /// Países donde Mercado Pago está disponible. Por defecto solo Colombia,
  /// porque la cuenta de Mercado Pago es colombiana y solo cobra allá.
  /// El VPS lo publica en `pasarelas.mercadoPago.paises` (MP_PAISES).
  static List<String> _mpPaises = const [PaisService.kColombia];

  /// `pasarelas.mercadoPago.forzar` = true → mostrar el botón en TODO el
  /// mundo (sirve para hacer pruebas desde el exterior).
  static bool _mpForzar = false;

  /// Países EXCLUIDOS de Mercado Pago (ninguno por defecto).
  static List<String> _mpExcluir = const [];

  /// ePayco: países donde SÍ se muestra (lista blanca). Vacía = todos.
  static List<String> _epaycoPaises = const [];

  /// ePayco: países donde NO se muestra (lista negra). Vacía = se muestra en
  /// TODOS los países, incluida Colombia (donde además está Mercado Pago).
  /// Poné `['CO']` si algún día querés que en Colombia solo cobre Mercado Pago.
  static List<String> _epaycoExcluir = const [];

  /// `pasarelas.epayco.forzar` = true → mostrar ePayco en TODO el mundo
  /// (sirve para probar desde Colombia sin cambiar las listas).
  static bool _epaycoForzar = false;

  /// Tope de monto de ePayco en COP (0 = sin tope). En modo PRUEBAS ePayco
  /// rechaza montos fuera de 5.000–200.000 COP; si está configurado, la app
  /// oculta el botón para ese plan y avisa por qué.
  static int _epaycoMontoMax = 0;

  /// Tope de monto de ePayco (COP). 0 = sin tope.
  static int get epaycoMontoMax => _epaycoMontoMax;

  /// ¿ePayco acepta este monto (en COP)? Si no hay tope, siempre sí.
  static bool epaycoPermiteMonto(int? cop) {
    if (_epaycoMontoMax <= 0) return true;
    if (cop == null) return true;
    return cop <= _epaycoMontoMax;
  }

  /// Estado de ePayco según Firestore (`config_pagos/epayco.produccion`).
  static bool? get epaycoProduccion => _epaycoProduccion;

  /// Países donde Mercado Pago aplica (ISO-3166 alfa-2).
  static List<String> get mercadoPagoPaises => _mpPaises;

  /// Países donde ePayco aplica (vacío = todos menos [excluirPaises]).
  static List<String> get epaycoPaises => _epaycoPaises;

  /// ¿Mercado Pago aplica para este país? (solo Colombia por defecto).
  static bool mercadoPagoDisponible(String? pais) => paisPermitido(
        pais: pais,
        paises: _mpPaises,
        excluir: _mpExcluir,
        forzar: _mpForzar,
      );

  /// ¿ePayco aplica para este país? Por defecto SÍ en todos los países
  /// (incluida Colombia); se puede excluir alguno desde Firestore
  /// (`config_pagos/epayco.excluirPaises`, ej: `["CO"]`).
  static bool epaycoDisponible(String? pais) => paisPermitido(
        pais: pais,
        paises: _epaycoPaises,
        excluir: _epaycoExcluir,
        forzar: _epaycoForzar,
      );

  /// Regla común de países para cualquier pasarela:
  /// · `forzar` = true → se muestra en todo el mundo (pruebas)
  /// · país desconocido (null) → se muestra: no le bloqueamos la venta al
  ///   cliente por un fallo de red
  /// · `excluir` → nunca se muestra ahí
  /// · `paises` → si tiene algo es lista blanca; si está vacía, todos
  static bool paisPermitido({
    required String? pais,
    List<String> paises = const [],
    List<String> excluir = const [],
    bool forzar = false,
  }) {
    if (forzar) return true;
    if (pais == null) return true;
    final p = pais.toUpperCase();
    if (excluir.contains(p)) return false;
    if (paises.isEmpty) return true;
    return paises.contains(p);
  }

  /// Convierte el valor que manda el VPS/Firestore en una lista de códigos
  /// de país: acepta `['CO','US']` o `'CO,US'`. Devuelve null si no hay dato.
  static List<String>? _leerPaises(dynamic v) {
    if (v == null) return null;
    final crudo = v is List ? v : '$v'.split(',');
    return crudo
        .map((e) => '$e'.trim().toUpperCase())
        .where((e) => e.length == 2)
        .toList();
  }

  /// Lee `mercadoPago: { paises: [...], excluirPaises: [...], forzar: bool }`
  /// (del VPS o del espejo público) y lo aplica.
  static void _aplicarMercadoPago(dynamic mp) {
    if (mp is! Map) return;
    if (mp.containsKey('paises')) _mpPaises = _leerPaises(mp['paises']) ?? _mpPaises;
    if (mp.containsKey('excluirPaises')) {
      _mpExcluir = _leerPaises(mp['excluirPaises']) ?? _mpExcluir;
    }
    final forzar = _aBool(mp['forzar']);
    if (forzar != null) _mpForzar = forzar;
  }

  /// Lee la parte de países/forzar/tope de `pasarelas.epayco`.
  static void _aplicarPaisesEpayco(dynamic ep) {
    if (ep is! Map) return;
    if (ep.containsKey('paises')) {
      _epaycoPaises = _leerPaises(ep['paises']) ?? _epaycoPaises;
    }
    if (ep.containsKey('excluirPaises')) {
      _epaycoExcluir = _leerPaises(ep['excluirPaises']) ?? _epaycoExcluir;
    }
    final forzar = _aBool(ep['forzar']);
    if (forzar != null) _epaycoForzar = forzar;
    final montoMax = ep['montoMax'];
    if (montoMax is num) _epaycoMontoMax = montoMax.round();
  }

  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  /// Escucha EN TIEMPO REAL el espejo público que escribe el VPS
  /// (`config_publica/pasarelas`). Así, al cambiar `produccion` en Firestore,
  /// el botón de Rapid aparece o desaparece **sin reinstalar la app**.
  static void escucharPasarelas() {
    _sub ??= FirebaseFirestore.instance
        .collection('config_publica')
        .doc('pasarelas')
        .snapshots()
        .listen(
      (snap) {
        final d = snap.data();
        if (d == null) return;
        final rapid = d['rapid'];
        final v = _aBool(rapid is Map ? rapid['produccion'] : null);
        if (v != null) {
          _rapidProduccion = v;
          rapidProduccionNotifier.value = v;
          debugPrint('[Pasarelas] rapid.produccion = $v (tiempo real)');
        }
        final epayco = d['epayco'];
        final e = _aBool(epayco is Map ? epayco['produccion'] : null);
        if (e != null) {
          _epaycoProduccion = e;
          epaycoProduccionNotifier.value = e;
          debugPrint('[Pasarelas] epayco.produccion = $e (tiempo real)');
        }
        // Países de ePayco (resto del mundo: excluye Colombia por defecto)
        // y de Mercado Pago (Colombia).
        _aplicarPaisesEpayco(epayco);
        _aplicarMercadoPago(d['mercadoPago']);
      },
      onError: (e) => debugPrint('[Pasarelas] Listener no disponible: $e'),
    );
  }

  /// Cancela el listener (por si se necesita reiniciar).
  static Future<void> dejarDeEscucharPasarelas() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Acepta booleano, texto ("true") o número (1); null si no hay dato.
  static bool? _aBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      return ['true', '1', 'si', 'sí', 'yes', 'on']
          .contains(v.trim().toLowerCase());
    }
    return null;
  }

  /// De dónde salió la tasa (ej: "TRM oficial (Superfinanciera)").
  static String get fuente => _fuente;

  /// Fecha de la última actualización (ISO, si el VPS la informó).
  static String get actualizado => _actualizado;

  /// Tasa en texto: "3.072,27".
  static String get tasaTexto => NumberFormat('#,##0.00', 'es_CO').format(_usdACop);

  /// Precio en COP de un monto en USD (cálculo local de respaldo).
  static int copDe(num usd) {
    final cop = (usd * _usdACop / 100).round() * 100;
    return cop < 0 ? 0 : cop;
  }

  /// COP de un plan: usa el que calculó el VPS (tasa del día real);
  /// si todavía no se cargó, lo estima con la tasa local.
  static int copDePlan(String planId, num usd) => _copPorPlan[planId] ?? copDe(usd);

  /// Formatea un número al estilo colombiano: 369.000
  static String formatoCop(num valor) => NumberFormat.decimalPattern('es_CO').format(valor.round());

  /// Texto corto listo para mostrar: "$369.000 COP".
  static String textoCop(num usd) => '\$${formatoCop(copDe(usd))} COP';

  /// Trae la tasa del día y los precios ya calculados desde el VPS
  /// (`GET /precios`). Silencioso: si falla, queda la tasa de respaldo.
  static Future<void> cargar({bool forzar = false}) async {
    final ahora = DateTime.now().millisecondsSinceEpoch;
    // Relee cada 2 minutos: si cambiás `produccion` en Firestore, la app
    // lo refleja sola sin reinstalar.
    if (!forzar && _cargado && ahora - _ultimoMs < 120000) return;
    try {
      final resp = await http.get(Uri.parse('$_vpsUrl/precios')).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body) as Map<String, dynamic>;
        final t = j['usdACop'];
        if (t is num && t > 0) {
          _usdACop = t.toDouble();
          _fuente = (j['fuente'] ?? '').toString();
          _actualizado = (j['actualizado'] ?? '').toString();
          final planes = j['planes'];
          if (planes is Map) {
            _copPorPlan.clear();
            planes.forEach((k, v) {
              if (v is Map && v['cop'] is num) {
                _copPorPlan['$k'] = (v['cop'] as num).round();
              }
            });
          }
          // ¿Rapid está en producción? (lo decide Firestore, no la app)
          final pasarelas = j['pasarelas'];
          if (pasarelas is Map) {
            final rapid = pasarelas['rapid'];
            final v = _aBool(rapid is Map ? rapid['produccion'] : null);
            if (v != null) {
              _rapidProduccion = v;
              rapidProduccionNotifier.value = v;
            }
            // ePayco: botón visible solo si está en producción.
            final epayco = pasarelas['epayco'];
            final e = _aBool(epayco is Map ? epayco['produccion'] : null);
            if (e != null) {
              _epaycoProduccion = e;
              epaycoProduccionNotifier.value = e;
            }
            // ePayco = resto del mundo (excluye CO) · MP = Colombia.
            _aplicarPaisesEpayco(epayco);
            _aplicarMercadoPago(pasarelas['mercadoPago']);
          }
          _cargado = true;
          _ultimoMs = ahora;
          debugPrint('[Precios] Tasa del día: $_usdACop ($_fuente) · ${_copPorPlan.length} planes · rapidProduccion=$_rapidProduccion · epaycoProduccion=$_epaycoProduccion · mpPaises=$_mpPaises · epaycoExcluir=$_epaycoExcluir');
        }
      }
    } catch (e) {
      debugPrint('[Precios] No se pudo leer la tasa del VPS: $e');
    }
  }
}
