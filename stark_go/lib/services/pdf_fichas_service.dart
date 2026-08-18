import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ─────────────────────────────────────────────────────────────────────────
// Modelo de un lote de fichas ya exportado a PDF
// ─────────────────────────────────────────────────────────────────────────
class PdfBatchRecord {
  final String id;
  final String fileName;
  final String filePath;
  final String perfil;
  final int cantidad;
  final DateTime fechaCreacion;

  PdfBatchRecord({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.perfil,
    required this.cantidad,
    required this.fechaCreacion,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'filePath': filePath,
        'perfil': perfil,
        'cantidad': cantidad,
        'fechaCreacion': fechaCreacion.toIso8601String(),
      };

  factory PdfBatchRecord.fromJson(Map<String, dynamic> json) => PdfBatchRecord(
        id: json['id'] as String,
        fileName: json['fileName'] as String,
        filePath: json['filePath'] as String,
        perfil: json['perfil'] as String,
        cantidad: json['cantidad'] as int,
        fechaCreacion: DateTime.parse(json['fechaCreacion'] as String),
      );
}

// ─────────────────────────────────────────────────────────────────────────
// "Base de datos" local (índice JSON) de los PDFs generados.
// Guarda los archivos físicos en el directorio de documentos de la app,
// dentro de la carpeta fichas_pdfs/, y un índice con los metadatos.
// ─────────────────────────────────────────────────────────────────────────
class FichasPdfStore {
  static const _carpeta = 'fichas_pdfs';
  static const _indice = 'indice.json';

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_carpeta');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _indiceFile() async {
    final dir = await _dir();
    return File('${dir.path}/$_indice');
  }

  Future<List<PdfBatchRecord>> listar() async {
    final file = await _indiceFile();
    if (!await file.exists()) return [];
    try {
      final contenido = await file.readAsString();
      if (contenido.trim().isEmpty) return [];
      final lista = jsonDecode(contenido) as List;
      final registros = lista.map((e) => PdfBatchRecord.fromJson(e as Map<String, dynamic>)).toList();
      registros.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
      return registros;
    } catch (_) {
      return [];
    }
  }

  Future<void> _guardarIndice(List<PdfBatchRecord> registros) async {
    final file = await _indiceFile();
    await file.writeAsString(jsonEncode(registros.map((e) => e.toJson()).toList()));
  }

  /// Guarda los bytes del PDF en disco y agrega el registro al índice local.
  Future<PdfBatchRecord> guardar({
    required Uint8List bytes,
    required String perfil,
    required int cantidad,
  }) async {
    final dir = await _dir();
    final ahora = DateTime.now();
    final id = ahora.microsecondsSinceEpoch.toString();
    final nombreArchivo = 'fichas_${_sanear(perfil)}_${_marcaTiempo(ahora)}.pdf';
    final file = File('${dir.path}/$nombreArchivo');
    await file.writeAsBytes(bytes, flush: true);

    final registro = PdfBatchRecord(
      id: id,
      fileName: nombreArchivo,
      filePath: file.path,
      perfil: perfil,
      cantidad: cantidad,
      fechaCreacion: ahora,
    );

    final registros = await listar();
    registros.insert(0, registro);
    await _guardarIndice(registros);
    return registro;
  }

  Future<void> eliminar(String id) async {
    final registros = await listar();
    final registro = registros.firstWhere(
      (r) => r.id == id,
      orElse: () => throw Exception('Registro no encontrado'),
    );
    final file = File(registro.filePath);
    if (await file.exists()) await file.delete();
    registros.removeWhere((r) => r.id == id);
    await _guardarIndice(registros);
  }

  Future<Uint8List> leerBytes(PdfBatchRecord registro) async {
    final file = File(registro.filePath);
    if (!await file.exists()) {
      throw Exception('El archivo PDF ya no existe en este dispositivo');
    }
    return file.readAsBytes();
  }

  String _sanear(String texto) => texto.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  String _marcaTiempo(DateTime dt) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}${p(dt.month)}${p(dt.day)}_${p(dt.hour)}${p(dt.minute)}${p(dt.second)}';
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Constructor del PDF profesional de fichas: solo los vouchers, listos
// para imprimir y cortar, cada uno con los datos de contacto al pie.
// ─────────────────────────────────────────────────────────────────────────
class FichasPdfBuilder {
  static Future<Uint8List> construir({
    required List<Map<String, String>> fichas, // [{'usuario': .., 'clave': ..}]
    required String perfil,
    String empresa = 'Servicio de Internet',
    String contacto = 'Ing. Fabian Cardenas · WA. +57 313 7756497',
    String? nota,
  }) async {
    final documento = pw.Document();
    final fecha = DateTime.now();

    final fuenteTitulo = pw.Font.helveticaBold();
    final fuenteTexto = pw.Font.helvetica();
    final fuenteCodigo = pw.Font.courierBold();

    const azul = PdfColor.fromInt(0xFF1A73E8);
    const verde = PdfColor.fromInt(0xFF00C6AE);
    const grisTexto = PdfColor.fromInt(0xFF64748B);
    const grisBorde = PdfColor.fromInt(0xFFE2E8F0);
    const oscuro = PdfColor.fromInt(0xFF0F172A);

    String fechaLegible(DateTime d) {
      const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
      String p(int n) => n.toString().padLeft(2, '0');
      return '${p(d.day)} ${meses[d.month - 1]} ${d.year} · ${p(d.hour)}:${p(d.minute)}';
    }

    pw.Widget encabezado() {
      return pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: grisBorde, width: 1)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(empresa, style: pw.TextStyle(font: fuenteTitulo, fontSize: 14, color: oscuro)),
                pw.SizedBox(height: 2),
                pw.Text('Fichas de acceso WiFi', style: pw.TextStyle(font: fuenteTexto, fontSize: 9, color: grisTexto)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Perfil: $perfil', style: pw.TextStyle(font: fuenteTitulo, fontSize: 9, color: azul)),
                pw.SizedBox(height: 2),
                pw.Text(fechaLegible(fecha), style: pw.TextStyle(font: fuenteTexto, fontSize: 8, color: grisTexto)),
              ],
            ),
          ],
        ),
      );
    }

    pw.Widget ticket(int numero, Map<String, String> ficha) {
      return pw.Container(
        width: 165,
        margin: const pw.EdgeInsets.all(4),
        padding: const pw.EdgeInsets.all(9),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: grisBorde, width: 0.9),
          borderRadius: pw.BorderRadius.circular(7),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('WIFI', style: pw.TextStyle(font: fuenteTitulo, fontSize: 7, color: verde)),
                pw.Text('N.º ${numero.toString().padLeft(3, '0')}',
                    style: pw.TextStyle(font: fuenteTexto, fontSize: 6.5, color: grisTexto)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text('USUARIO', style: pw.TextStyle(font: fuenteTexto, fontSize: 6.5, color: grisTexto)),
            pw.Text(ficha['usuario'] ?? '', style: pw.TextStyle(font: fuenteCodigo, fontSize: 13, color: oscuro)),
            pw.SizedBox(height: 5),
            pw.Text('CLAVE', style: pw.TextStyle(font: fuenteTexto, fontSize: 6.5, color: grisTexto)),
            pw.Text(ficha['clave'] ?? '', style: pw.TextStyle(font: fuenteCodigo, fontSize: 13, color: oscuro)),
            pw.SizedBox(height: 6),
            pw.Container(height: 0.7, color: grisBorde),
            pw.SizedBox(height: 4),
            pw.Text(contacto, style: pw.TextStyle(font: fuenteTexto, fontSize: 6, color: grisTexto)),
          ],
        ),
      );
    }

    documento.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => context.pageNumber == 1
            ? encabezado()
            : pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text('$empresa · Perfil: $perfil', style: pw.TextStyle(font: fuenteTexto, fontSize: 8, color: grisTexto)),
              ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 6),
          child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(font: fuenteTexto, fontSize: 7, color: grisTexto)),
        ),
        build: (context) => [
          pw.SizedBox(height: 10),
          pw.Text('${fichas.length} ficha(s) generada(s)', style: pw.TextStyle(font: fuenteTitulo, fontSize: 10, color: oscuro)),
          pw.SizedBox(height: 10),
          pw.Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (int i = 0; i < fichas.length; i++) ticket(i + 1, fichas[i]),
            ],
          ),
          if (nota != null && nota.trim().isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text('Nota: $nota', style: pw.TextStyle(font: fuenteTexto, fontSize: 8, color: grisTexto)),
          ],
        ],
      ),
    );

    return documento.save();
  }
}
