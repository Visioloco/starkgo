import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// ══════════════════════════════════════════════════════════════
//  PreciosService — tasa USD→COP y formato de precios.
//
//  Los planes están en USD (lo que ve el cliente) y las pasarelas
//  colombianas (Mercado Pago, Rapid) cobran en COP. Para que el precio
//  MOSTRADO y el COBRADO nunca se desincronicen, la tasa vive en el VPS
//  (`GET /precios`, variable de entorno USD_A_COP) y la app la trae de ahí.
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
        final rapid = d == null ? null : d['rapid'];
        final v = _aBool(rapid is Map ? rapid['produccion'] : null);
        if (v == null) return;
        _rapidProduccion = v;
        rapidProduccionNotifier.value = v;
        debugPrint('[Pasarelas] rapid.produccion = $v (tiempo real)');
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
          }
          _cargado = true;
          _ultimoMs = ahora;
          debugPrint('[Precios] Tasa del día: $_usdACop ($_fuente) · ${_copPorPlan.length} planes · rapidProduccion=$_rapidProduccion');
        }
      }
    } catch (e) {
      debugPrint('[Precios] No se pudo leer la tasa del VPS: $e');
    }
  }
}
