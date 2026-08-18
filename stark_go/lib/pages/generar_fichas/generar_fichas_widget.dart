import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ════════════════════════════════════════════════════════════════
//  GENERAR FICHAS — genera vouchers de hotspot y arma el PDF de
//  cupones (varias fichas por hoja, con líneas de corte).
//
//  Dependencias nuevas en pubspec.yaml:
//    pdf: ^3.10.7
//    printing: ^5.12.0
//
//  Endpoints usados:
//    GET  /hotspot/perfiles?apikey=...           lista de perfiles
//    POST /hotspot/generar-fichas                 crea N fichas (encoladas)
//    GET  /fichas/listar?apikey=...&estado=...    lista fichas guardadas
//    POST /fichas/marcar-pdf                       marca códigos como impresos
// ════════════════════════════════════════════════════════════════

class _VPS {
  static const String url = 'http://5.161.88.42:3000';
}

class _C {
  static const Color primary = Color(0xFF1A73E8);
  static const Color accent = Color(0xFF00C6AE);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFE53935);
  static const Color dark = Color(0xFF0F172A);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF1F5F9);
  static const Color textPri = Color(0xFF0F172A);
  static const Color textSec = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color purple = Color(0xFF7C3AED);
}

class FichaVoucher {
  final String codigo;
  final String perfil;
  final double precio;
  final String estado; // sin_usar | usada
  final bool generadaPdf;

  FichaVoucher({
    required this.codigo,
    required this.perfil,
    required this.precio,
    required this.estado,
    required this.generadaPdf,
  });

  factory FichaVoucher.fromJson(Map<String, dynamic> j) => FichaVoucher(
        codigo: (j['codigo'] ?? '').toString(),
        perfil: (j['perfil'] ?? '').toString(),
        precio: (j['precio'] is num) ? (j['precio'] as num).toDouble() : double.tryParse('${j['precio']}') ?? 0,
        estado: (j['estado'] ?? 'sin_usar').toString(),
        generadaPdf: j['generadaPdf'] == true,
      );
}

class GenerarFichasWidget extends StatefulWidget {
  const GenerarFichasWidget({super.key});
  static String routeName = 'GenerarFichas';
  static String routePath = 'generarFichas';

  @override
  State<GenerarFichasWidget> createState() => _GenerarFichasWidgetState();
}

class _GenerarFichasWidgetState extends State<GenerarFichasWidget> {
  String? _apikey;
  String? _nombreEmpresa;
  bool _cargando = true;
  bool _generando = false;
  bool _exportando = false;

  List<Map<String, dynamic>> _perfiles = []; // {name, precio}
  String? _perfilSeleccionado;
  final _cantidadCtrl = TextEditingController(text: '10');
  final _precioCtrl = TextEditingController();

  List<FichaVoucher> _fichasSinUsar = [];
  final Set<String> _seleccionadas = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _cargando = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('config_mikrotik').doc(uid).get();
      _apikey = doc.data()?['vpsApiKey'] as String?;
      final empresaDoc = await FirebaseFirestore.instance.collection('config_empresa').doc(uid).get();
      _nombreEmpresa = empresaDoc.data()?['nombreEmpresa'] as String? ?? 'StarkGo';
      if (_apikey != null) {
        await Future.wait([_cargarPerfiles(), _cargarFichasPendientes()]);
      }
    } catch (e) {
      debugPrint('[Fichas] Error init: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarPerfiles() async {
    final res = await http.get(Uri.parse('$_VPS.url/hotspot/perfiles?apikey=$_apikey'));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final lista = (data['perfiles'] as List? ?? []).cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _perfiles = lista;
          if (_perfiles.isNotEmpty) {
            _perfilSeleccionado ??= _perfiles.first['name'] as String?;
            _actualizarPrecioSugerido();
          }
        });
      }
    }
  }

  Future<void> _cargarFichasPendientes() async {
    final res = await http.get(Uri.parse('$_VPS.url/fichas/listar?apikey=$_apikey&estado=sin_usar'));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final lista = (data['fichas'] as List? ?? []).map((f) => FichaVoucher.fromJson(f as Map<String, dynamic>)).toList();
      if (mounted) setState(() => _fichasSinUsar = lista);
    }
  }

  void _actualizarPrecioSugerido() {
    final perfil = _perfiles.firstWhere((p) => p['name'] == _perfilSeleccionado, orElse: () => {});
    final precio = perfil['precio'];
    if (precio != null) _precioCtrl.text = '$precio';
  }

  Future<void> _generarFichas() async {
    if (_apikey == null || _perfilSeleccionado == null) return;
    final cantidad = int.tryParse(_cantidadCtrl.text.trim()) ?? 0;
    if (cantidad <= 0) {
      _snack('Cantidad inválida', _C.danger);
      return;
    }
    setState(() => _generando = true);
    try {
      final res = await http.post(
        Uri.parse('$_VPS.url/hotspot/generar-fichas'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'apikey': _apikey,
          'perfil': _perfilSeleccionado,
          'cantidad': cantidad,
          'precio': double.tryParse(_precioCtrl.text.trim()) ?? 0,
        }),
      );
      if (res.statusCode == 200) {
        _snack('$cantidad fichas generadas — se crean en el router en el próximo ciclo', _C.success);
        await _cargarFichasPendientes();
        // Preseleccionamos automáticamente las recién creadas para exportar
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final codigosNuevos = (data['fichas'] as List? ?? []).map((f) => f['codigo'] as String).toSet();
        setState(() => _seleccionadas.addAll(codigosNuevos));
      } else {
        final body = jsonDecode(res.body);
        _snack(body['error'] ?? 'Error al generar fichas', _C.danger);
      }
    } catch (e) {
      _snack('Error de conexión: $e', _C.danger);
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _exportarPdf() async {
    final elegidas = _fichasSinUsar.where((f) => _seleccionadas.contains(f.codigo)).toList();
    if (elegidas.isEmpty) {
      _snack('Selecciona al menos una ficha', _C.warning);
      return;
    }
    setState(() => _exportando = true);
    try {
      final bytes = await _construirPdfCupones(elegidas, nombreEmpresa: _nombreEmpresa ?? 'StarkGo');
      await Printing.sharePdf(bytes: bytes, filename: 'fichas_${DateTime.now().millisecondsSinceEpoch}.pdf');

      // Marcamos como "generadaPdf" en el backend para no repetirlas
      final codigos = elegidas.map((f) => f.codigo).toList();
      await http.post(
        Uri.parse('$_VPS.url/fichas/marcar-pdf'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'apikey': _apikey, 'codigos': codigos}),
      );
      setState(() => _seleccionadas.clear());
      await _cargarFichasPendientes();
    } catch (e) {
      _snack('Error generando el PDF: $e', _C.danger);
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.spaceGrotesk(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surfaceDim,
      body: SafeArea(
        child: _cargando
            ? Center(child: CircularProgressIndicator(color: _C.primary, strokeWidth: 2.5))
            : _apikey == null
                ? _buildSinConfig()
                : RefreshIndicator(
                    onRefresh: () => Future.wait([_cargarPerfiles(), _cargarFichasPendientes()]),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: 16),
                        _buildFormGenerar().animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, end: 0),
                        const SizedBox(height: 18),
                        Row(children: [
                          Expanded(
                            child: Text('Fichas sin usar (${_fichasSinUsar.length})',
                                style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
                          ),
                          if (_fichasSinUsar.isNotEmpty)
                            TextButton(
                              onPressed: () => setState(() {
                                if (_seleccionadas.length == _fichasSinUsar.length) {
                                  _seleccionadas.clear();
                                } else {
                                  _seleccionadas.addAll(_fichasSinUsar.map((f) => f.codigo));
                                }
                              }),
                              child: Text(
                                _seleccionadas.length == _fichasSinUsar.length ? 'Deseleccionar todo' : 'Seleccionar todo',
                                style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                        ]),
                        const SizedBox(height: 8),
                        if (_fichasSinUsar.isEmpty)
                          _buildVacio()
                        else
                          ..._fichasSinUsar.asMap().entries.map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildFichaTile(e.value).animate().fadeIn(duration: 220.ms, delay: (e.key * 25).ms),
                              )),
                      ],
                    ),
                  ),
      ),
      floatingActionButton: (_apikey != null && _seleccionadas.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: _exportando ? null : _exportarPdf,
              backgroundColor: _C.primary,
              icon: _exportando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
              label: Text('Exportar PDF (${_seleccionadas.length})',
                  style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }

  Widget _buildSinConfig() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.confirmation_number_rounded, color: _C.textSec, size: 42),
          const SizedBox(height: 12),
          Text('Primero configura tu MikroTik',
              textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Necesitas guardar tu API Key en "Config. MikroTik" antes de generar fichas.',
              textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
        ]),
      );

  Widget _buildTopBar() => Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))]),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.textPri, size: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Fichas / Vouchers', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 20, fontWeight: FontWeight.w800)),
          Text('Genera y exporta cupones en PDF', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
        ])),
      ]);

  Widget _buildVacio() => Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.border)),
        child: Text('No hay fichas sin usar. Genera algunas arriba.', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
      );

  Widget _buildFormGenerar() {
    if (_perfiles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: _C.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.warning.withOpacity(0.3))),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, color: _C.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text('Aún no tienes perfiles creados. Ve a "Perfiles / Planes" y crea uno primero.',
                  style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12))),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_C.accent, Color(0xFF0E9484)]), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text('Generar fichas', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        Text('PERFIL', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.border)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _perfilSeleccionado,
              isExpanded: true,
              items: _perfiles
                  .map((p) => DropdownMenuItem<String>(
                        value: p['name'] as String?,
                        child: Text('${p['name']} · rate ${p['rateLimit'] ?? p['rate-limit'] ?? '-'}',
                            style: GoogleFonts.spaceGrotesk(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                _perfilSeleccionado = v;
                _actualizarPrecioSugerido();
              }),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: _cantidadCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.spaceGrotesk(fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Cantidad',
                labelStyle: GoogleFonts.spaceGrotesk(fontSize: 12, color: _C.textSec),
                prefixIcon: Icon(Icons.tag_rounded, size: 18, color: _C.textSec),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _C.border)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _precioCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.spaceGrotesk(fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Precio c/u',
                labelStyle: GoogleFonts.spaceGrotesk(fontSize: 12, color: _C.textSec),
                prefixIcon: Icon(Icons.attach_money_rounded, size: 18, color: _C.textSec),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _C.border)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _generando ? null : _generarFichas,
            style: ElevatedButton.styleFrom(
                backgroundColor: _C.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: _generando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Generar fichas', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  Widget _buildFichaTile(FichaVoucher f) {
    final seleccionada = _seleccionadas.contains(f.codigo);
    return GestureDetector(
      onTap: () => setState(() {
        if (seleccionada) {
          _seleccionadas.remove(f.codigo);
        } else {
          _seleccionadas.add(f.codigo);
        }
      }),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: seleccionada ? _C.primary.withOpacity(0.06) : _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: seleccionada ? _C.primary : _C.border, width: seleccionada ? 1.6 : 1),
        ),
        child: Row(children: [
          Icon(seleccionada ? Icons.check_circle_rounded : Icons.circle_outlined, color: seleccionada ? _C.primary : _C.textSec, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.codigo, style: GoogleFonts.sourceCodePro(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w700)),
              Text('${f.perfil} · \$${f.precio.toStringAsFixed(0)}', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
            ]),
          ),
          if (f.generadaPdf)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: _C.textSec.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('ya impresa', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10)),
            ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  PDF — varios cupones por hoja, con líneas de corte punteadas
// ════════════════════════════════════════════════════════════════

Future<Uint8List> _construirPdfCupones(
  List<FichaVoucher> fichas, {
  required String nombreEmpresa,
}) async {
  final doc = pw.Document();

  const columnas = 2;
  const filas = 5; // 10 cupones por hoja tamaño carta
  const porHoja = columnas * filas;

  final paginas = <List<FichaVoucher>>[];
  for (var i = 0; i < fichas.length; i += porHoja) {
    paginas.add(fichas.sublist(i, i + porHoja > fichas.length ? fichas.length : i + porHoja));
  }

  for (final pagina in paginas) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(18),
        build: (context) {
          return pw.GridView(
            crossAxisCount: columnas,
            childAspectRatio: 2.6,
            children: pagina.map((f) => _cuponWidget(f, nombreEmpresa)).toList(),
          );
        },
      ),
    );
  }

  return doc.save();
}

pw.Widget _cuponWidget(FichaVoucher f, String nombreEmpresa) {
  return pw.Container(
    margin: const pw.EdgeInsets.all(4),
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(width: 1, style: pw.BorderStyle.dashed, color: PdfColors.grey600),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 34,
          height: 34,
          decoration: pw.BoxDecoration(color: PdfColors.blue800, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Center(
            child: pw.Text('WiFi', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(nombreEmpresa, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.SizedBox(height: 2),
              pw.Text(f.codigo, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
              pw.SizedBox(height: 2),
              pw.Text('${f.perfil} · \$${f.precio.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.Text('Usuario y clave: ${f.codigo}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
            ],
          ),
        ),
      ],
    ),
  );
}
