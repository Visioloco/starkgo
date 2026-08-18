import 'dart:convert';
import 'dart:io';

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

class HotspotDesignStore {
  static const _archivo = 'hotspot_design_historial.json';

  Future<File> _indiceFile() async {
    final base = await getApplicationDocumentsDirectory();
    return File('${base.path}/$_archivo');
  }

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
}
