import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Un respaldo local de una versión publicada del login del hotspot.
/// Guardamos el HTML como texto; el logo NO se duplica aquí (se sube
/// directo al router), pero sí guardamos si esa versión incluía logo
/// nuevo, para que el historial tenga contexto.
class HotspotDesignVersion {
  final String id;
  final String html;
  final bool incluyoLogoNuevo;
  final DateTime fecha;
  final String? nota;

  HotspotDesignVersion({
    required this.id,
    required this.html,
    required this.incluyoLogoNuevo,
    required this.fecha,
    this.nota,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'html': html,
        'incluyoLogoNuevo': incluyoLogoNuevo,
        'fecha': fecha.toIso8601String(),
        'nota': nota,
      };

  factory HotspotDesignVersion.fromJson(Map<String, dynamic> json) => HotspotDesignVersion(
        id: json['id'] as String,
        html: json['html'] as String,
        incluyoLogoNuevo: json['incluyoLogoNuevo'] as bool? ?? false,
        fecha: DateTime.parse(json['fecha'] as String),
        nota: json['nota'] as String?,
      );
}

/// El "borrador" es lo último que el usuario dejó en la pantalla —
/// haya publicado o no. Se restaura automáticamente al reabrir la app.
class HotspotBorrador {
  final String html;
  final Uint8List? logoBytes;
  final String? logoNombre;

  HotspotBorrador({
    required this.html,
    this.logoBytes,
    this.logoNombre,
  });
}

class HotspotDesignStore {
  static const _archivoHistorial = 'hotspot_design_historial.json';
  static const _archivoBorrador = 'hotspot_design_borrador.json';
  static const _archivoLogoBorrador = 'hotspot_design_borrador_logo.bin';

  Future<Directory> _dir() async => getApplicationDocumentsDirectory();

  Future<File> _indiceFile() async {
    final base = await _dir();
    return File('${base.path}/$_archivoHistorial');
  }

  Future<File> _borradorFile() async {
    final base = await _dir();
    return File('${base.path}/$_archivoBorrador');
  }

  Future<File> _logoBorradorFile() async {
    final base = await _dir();
    return File('${base.path}/$_archivoLogoBorrador');
  }

  // ─────────────────────────────────────────────────────────────
  // Historial de versiones publicadas
  // ─────────────────────────────────────────────────────────────

  Future<List<HotspotDesignVersion>> listar() async {
    final file = await _indiceFile();
    if (!await file.exists()) return [];
    try {
      final contenido = await file.readAsString();
      if (contenido.trim().isEmpty) return [];
      final lista = jsonDecode(contenido) as List;
      final versiones = lista.map((e) => HotspotDesignVersion.fromJson(e as Map<String, dynamic>)).toList();
      versiones.sort((a, b) => b.fecha.compareTo(a.fecha));
      return versiones;
    } catch (_) {
      return [];
    }
  }

  Future<HotspotDesignVersion> guardar({
    required String html,
    required bool incluyoLogoNuevo,
    String? nota,
  }) async {
    final ahora = DateTime.now();
    final version = HotspotDesignVersion(
      id: ahora.microsecondsSinceEpoch.toString(),
      html: html,
      incluyoLogoNuevo: incluyoLogoNuevo,
      fecha: ahora,
      nota: nota,
    );
    final versiones = await listar();
    versiones.insert(0, version);
    // Conservamos como máximo 15 versiones para no acumular espacio.
    final recortadas = versiones.take(15).toList();
    final file = await _indiceFile();
    await file.writeAsString(jsonEncode(recortadas.map((e) => e.toJson()).toList()));
    return version;
  }

  Future<void> eliminar(String id) async {
    final versiones = await listar();
    versiones.removeWhere((v) => v.id == id);
    final file = await _indiceFile();
    await file.writeAsString(jsonEncode(versiones.map((e) => e.toJson()).toList()));
  }

  // ─────────────────────────────────────────────────────────────
  // Borrador actual (lo que se ve en pantalla, publicado o no)
  // ─────────────────────────────────────────────────────────────

  /// Guarda el HTML y el logo actuales para restaurarlos si el usuario
  /// cierra y vuelve a abrir la app. Se llama automáticamente mientras
  /// el usuario edita.
  Future<void> guardarBorrador({
    required String html,
    Uint8List? logoBytes,
    String? logoNombre,
  }) async {
    final file = await _borradorFile();
    await file.writeAsString(jsonEncode({
      'html': html,
      'logoNombre': logoNombre,
      'tieneLogo': logoBytes != null,
    }));

    final logoFile = await _logoBorradorFile();
    if (logoBytes != null) {
      await logoFile.writeAsBytes(logoBytes);
    } else if (await logoFile.exists()) {
      await logoFile.delete();
    }
  }

  /// Carga el último borrador guardado, si existe.
  Future<HotspotBorrador?> cargarBorrador() async {
    final file = await _borradorFile();
    if (!await file.exists()) return null;
    try {
      final contenido = await file.readAsString();
      if (contenido.trim().isEmpty) return null;
      final json = jsonDecode(contenido) as Map<String, dynamic>;

      Uint8List? logoBytes;
      if (json['tieneLogo'] == true) {
        final logoFile = await _logoBorradorFile();
        if (await logoFile.exists()) {
          logoBytes = await logoFile.readAsBytes();
        }
      }

      return HotspotBorrador(
        html: json['html'] as String? ?? '',
        logoBytes: logoBytes,
        logoNombre: json['logoNombre'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Borra el borrador guardado (por ejemplo, si el usuario quiere
  /// empezar de cero).
  Future<void> borrarBorrador() async {
    final file = await _borradorFile();
    if (await file.exists()) await file.delete();
    final logoFile = await _logoBorradorFile();
    if (await logoFile.exists()) await logoFile.delete();
  }
}
