import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════════
//  PaisService — ¿en qué país está el TELÉFONO?
//
//  Lo usa la pantalla de membresía para mostrar Mercado Pago SOLO
//  cuando el teléfono está en Colombia: la cuenta de Mercado Pago es
//  colombiana y solo cobra en Colombia (si el cliente está en otro
//  país, el cobro falla y el cliente se queda sin poder pagar).
//  Fuera de Colombia queda ePayco / Rapid, que sí cobran allá.
//
//  Señales, en orden de prioridad (la primera que responde gana):
//    1. Caché local (SharedPreferences, 24 h) → no golpea la red
//    2. Geolocalización por IP (ipwho.is → ipapi.co, HTTPS y sin key)
//    3. País del idioma del teléfono (locale, ej: es_CO)
//
//  Si NINGUNA señal responde, [esColombia] devuelve true a propósito:
//  preferimos NO quitarle el botón de pago a un cliente colombiano por
//  un fallo de red (el VPS valida igual contra la cuenta de Mercado
//  Pago al crear la preferencia).
//
//  Para forzar/desactivar sin recompilar la app existe el espejo
//  público `config_publica/pasarelas` (lo escribe el VPS):
//      mercadoPago: { paises: ['CO'], forzar: false }
// ══════════════════════════════════════════════════════════════
class PaisService {
  PaisService._();

  /// Código ISO-3166 alfa-2 de Colombia.
  static const String kColombia = 'CO';

  /// Cuánto dura el dato antes de volver a consultarlo.
  static const Duration kTtl = Duration(hours: 24);

  static const String _prefPais = 'sg_pais';
  static const String _prefMs = 'sg_pais_ms';

  /// Fuentes de geolocalización por IP (gratis, HTTPS, sin API key).
  static const List<String> _urlsIp = [
    'https://ipwho.is/',
    'https://ipapi.co/json/',
  ];

  static String? _pais;
  static String _fuente = '';
  static Future<String?>? _enVuelo;

  /// País detectado (ej: 'CO'), o null si todavía no se sabe.
  static String? get pais => _pais;

  /// De dónde salió el dato: 'caché', 'IP' o 'idioma del teléfono'.
  static String get fuente => _fuente;

  /// ¿El teléfono está en Colombia? (ver nota del encabezado: si no se
  /// pudo detectar nada, devuelve true).
  static bool get esColombia => _pais == null || _pais == kColombia;

  /// Avisa a la UI en cuanto termina la detección (el botón de pago
  /// aparece/desaparece sin reiniciar la app).
  static final ValueNotifier<String?> paisNotifier = ValueNotifier<String?>(null);

  /// Detecta el país. Es seguro llamarlo varias veces: mientras una
  /// detección está en curso, las demás esperan esa misma.
  static Future<String?> detectar({bool forzar = false}) async {
    if (_pais != null && !forzar) return _pais;
    final enCurso = _enVuelo;
    if (enCurso != null) return enCurso;
    final futuro = _detectar(forzar: forzar);
    _enVuelo = futuro;
    try {
      return await futuro;
    } finally {
      _enVuelo = null;
    }
  }

  static Future<String?> _detectar({required bool forzar}) async {
    if (!forzar) {
      final guardado = await _leerCache();
      if (guardado != null) return _fijar(guardado, 'caché');
    }
    final porIp = await _paisPorIp();
    if (porIp != null) {
      await _guardarCache(porIp);
      return _fijar(porIp, 'IP');
    }
    final porIdioma = _paisPorIdioma();
    if (porIdioma != null) {
      await _guardarCache(porIdioma);
      return _fijar(porIdioma, 'idioma del teléfono');
    }
    debugPrint('[País] No se pudo detectar el país (sigue como desconocido)');
    return _pais;
  }

  static String _fijar(String codigo, String fuente) {
    _pais = codigo.toUpperCase();
    _fuente = fuente;
    paisNotifier.value = _pais;
    debugPrint('[País] $_pais detectado ($fuente)');
    return _pais!;
  }

  /// País según la IP pública (la del WiFi o los datos móviles).
  static Future<String?> _paisPorIp() async {
    for (final url in _urlsIp) {
      try {
        final resp = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 6));
        if (resp.statusCode != 200) continue;
        final j = jsonDecode(resp.body);
        if (j is! Map) continue;
        final codigo = '${j['country_code'] ?? ''}'.trim().toUpperCase();
        if (codigo.length == 2) return codigo;
      } catch (e) {
        debugPrint('[País] $url no respondió: $e');
      }
    }
    return null;
  }

  /// País del idioma del teléfono (ej: es_CO). Respaldo cuando la
  /// geolocalización por IP no está disponible.
  static String? _paisPorIdioma() {
    try {
      final dispatcher = WidgetsBinding.instance.platformDispatcher;
      for (final l in dispatcher.locales) {
        final c = (l.countryCode ?? '').toUpperCase();
        if (c.length == 2) return c;
      }
      final c = (dispatcher.locale.countryCode ?? '').toUpperCase();
      if (c.length == 2) return c;
    } catch (e) {
      debugPrint('[País] No pude leer el idioma del teléfono: $e');
    }
    return null;
  }

  /// País guardado en el teléfono, si todavía no venció.
  static Future<String?> _leerCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final codigo = (prefs.getString(_prefPais) ?? '').toUpperCase();
      if (codigo.length != 2) return null;
      final guardadoMs = prefs.getInt(_prefMs) ?? 0;
      final edadMs = DateTime.now().millisecondsSinceEpoch - guardadoMs;
      if (edadMs < 0 || edadMs > kTtl.inMilliseconds) return null;
      return codigo;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _guardarCache(String codigo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefPais, codigo.toUpperCase());
      await prefs.setInt(_prefMs, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // Sin caché igual funciona: se vuelve a consultar la próxima vez.
    }
  }
}
