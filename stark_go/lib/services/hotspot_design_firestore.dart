import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Páginas editables del portal hotspot de MikroTik.
enum HotspotPagina {
  login('login.html', 'Login'),
  status('status.html', 'Status'),
  logout('logout.html', 'Logout'),
  errors('errors.html', 'Errores');

  final String archivo;
  final String etiqueta;

  const HotspotPagina(this.archivo, this.etiqueta);
}

/// Guarda y carga el diseño del hotspot (HTML + logo) en Firestore,
/// asociado al UID del usuario autenticado.
///
/// Colección: `hotspot_design/{uid}`
///   - html: String (el HTML del login) — se mantiene por compatibilidad
///   - paginas: Map<String, String> (archivo → HTML) para cada página
///   - logoBytes: String base64 (opcional)
///   - logoNombre: String (opcional)
///   - actualizado: Timestamp
class HotspotDesignFirestore {
  static const String _coleccion = 'hotspot_design';

  /// UID del usuario autenticado actual.
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static DocumentReference _ref(String uid) => FirebaseFirestore.instance.collection(_coleccion).doc(uid);

  /// Guarda el HTML de una página (y opcionalmente el logo) del usuario autenticado.
  static Future<void> guardar({
    required HotspotPagina pagina,
    required String html,
    Uint8List? logoBytes,
    String? logoNombre,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw Exception('No hay usuario autenticado');
    }

    final data = <String, dynamic>{
      'actualizado': FieldValue.serverTimestamp(),
    };

    // Guardar en el mapa de páginas (archivo → html)
    data['paginas.${pagina.archivo}'] = html;

    // Por compatibilidad, si es el login también lo guardamos en 'html'
    if (pagina == HotspotPagina.login) {
      data['html'] = html;
    }

    if (logoBytes != null) {
      data['logoBytes'] = base64Encode(logoBytes);
      data['logoNombre'] = logoNombre ?? 'logo.png';
    }

    await _ref(uid).set(data, SetOptions(merge: true));
  }

  /// Carga el HTML de una página guardada del usuario autenticado.
  /// Devuelve null si no hay nada guardado para esa página.
  static Future<String?> cargarPagina(HotspotPagina pagina) async {
    final uid = _uid;
    if (uid == null) return null;

    final doc = await _ref(uid).get();
    if (!doc.exists) return null;

    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;

    // Buscar en el mapa de páginas
    final paginas = data['paginas'];
    if (paginas is Map) {
      final html = paginas[pagina.archivo];
      if (html is String && html.isNotEmpty) return html;
    }

    // Compatibilidad: si es login, buscar en 'html'
    if (pagina == HotspotPagina.login) {
      final html = data['html'];
      if (html is String && html.isNotEmpty) return html;
    }

    return null;
  }

  /// Carga el logo guardado del usuario autenticado.
  static Future<Map<String, dynamic>?> cargarLogo() async {
    final uid = _uid;
    if (uid == null) return null;

    final doc = await _ref(uid).get();
    if (!doc.exists) return null;

    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;

    Uint8List? logoBytes;
    final logoB64 = data['logoBytes'];
    if (logoB64 is String && logoB64.isNotEmpty) {
      try {
        logoBytes = base64Decode(logoB64);
      } catch (_) {
        logoBytes = null;
      }
    }

    final logoNombre = data['logoNombre'];
    return {
      'logoBytes': logoBytes,
      'logoNombre': logoNombre is String ? logoNombre : null,
    };
  }

  /// Carga el HTML guardado del usuario autenticado (compatibilidad con login).
  /// Devuelve null si no hay nada guardado.
  static Future<Map<String, dynamic>?> cargar() async {
    final uid = _uid;
    if (uid == null) return null;

    final doc = await _ref(uid).get();
    if (!doc.exists) return null;

    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;

    Uint8List? logoBytes;
    final logoB64 = data['logoBytes'];
    if (logoB64 is String && logoB64.isNotEmpty) {
      try {
        logoBytes = base64Decode(logoB64);
      } catch (_) {
        logoBytes = null;
      }
    }

    final html = data['html'];
    final logoNombre = data['logoNombre'];
    return {
      'html': html is String ? html : '',
      'logoBytes': logoBytes,
      'logoNombre': logoNombre is String ? logoNombre : null,
    };
  }

  /// Borra el diseño guardado del usuario autenticado.
  static Future<void> borrar() async {
    final uid = _uid;
    if (uid == null) return;
    await _ref(uid).delete();
  }
}
