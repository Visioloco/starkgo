import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'vps_service.dart';

// ══════════════════════════════════════════════════════════════
//  PortalVpsService — página de pago del portal alojada en el VPS.
//
//  Permite publicar el HTML del hotspot (login.html, etc.) en el VPS
//  (Firestore portal_vps/<apikey>) y obtener su URL pública para:
//    · vista previa real en la app ("ver cómo queda"),
//    · que el hotspot del MikroTik redirija al moroso a esa página,
//      sin depender del FTP local.
// ══════════════════════════════════════════════════════════════
class PortalVpsService {
  static const String _baseUrl = 'http://5.161.88.42:3000';

  static Future<String?> _apikey() async {
    final config = await VpsService.obtenerConfig();
    if (config == null) return null;
    final key = (config['vpsApiKey'] ?? '').toString().trim();
    return key.isEmpty ? null : key;
  }

  /// Apikey del usuario (para armar URLs / depurar).
  static Future<String?> obtenerApikey() => _apikey();

  /// URL pública de una página publicada (ej: login.html).
  static Future<String?> urlPortal(String archivo) async {
    final key = await _apikey();
    if (key == null) return null;
    return urlPortalConApikey(key, archivo);
  }

  static String urlPortalConApikey(String apikey, String archivo) =>
      '$_baseUrl/portal/${Uri.encodeComponent(apikey)}/'
      '${Uri.encodeComponent(archivo)}';

  /// Descarga el HTML publicado de una página para poder ver el código fuente.
  ///
  /// Pide `?raw=1` para recibir el HTML tal cual se guardó (sin reemplazar los
  /// marcadores `{{nombre}}`, `{{saldo}}`…). Si el VPS todavía no soporta el
  /// parámetro `raw`, igual devuelve el HTML (con los marcadores ya resueltos).
  static Future<String?> obtenerPaginaPublicada(String archivo) async {
    final key = await _apikey();
    if (key == null) return null;
    try {
      final url = '$_baseUrl/portal/${Uri.encodeComponent(key)}/'
          '${Uri.encodeComponent(archivo)}?raw=1';
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) return resp.body;
      debugPrint(
          '[PortalVps] Error leyendo "$archivo": HTTP ${resp.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[PortalVps] No se pudo leer el HTML publicado: $e');
      return null;
    }
  }

  /// Publica el HTML de una página en el portal del VPS.
  static Future<bool> publicarPagina({
    required String archivo,
    required String html,
  }) async {
    final key = await _apikey();
    if (key == null || archivo.trim().isEmpty || html.trim().isEmpty) {
      return false;
    }
    try {
      final resp = await http
          .post(
            Uri.parse('$_baseUrl/hotspot/pagina'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'apikey': key,
              'archivo': archivo.trim(),
              'html': html,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        debugPrint('[PortalVps] "$archivo" publicado en el VPS.');
        return true;
      }
      debugPrint('[PortalVps] Error publicando: HTTP ${resp.statusCode} '
          '→ ${resp.body}');
      return false;
    } catch (e) {
      debugPrint('[PortalVps] No se pudo publicar en el VPS: $e');
      return false;
    }
  }
}
