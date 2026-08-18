import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:printing/printing.dart';
import '../../services/mikrotik_local_api.dart';
import '../../services/pdf_fichas_service.dart';

// ─────────────────────────────────────────────────────────────────────────
// Paleta — misma que ConfigMikroTikWidget y PerfilesLocalWidget.
// ─────────────────────────────────────────────────────────────────────────
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

// Máximo de fichas por lote — mantenlo alineado con el límite del PDF.
const int _kMaxFichasPorLote = 20;

class FichasLocalWidget extends StatefulWidget {
  final MikrotikLocalApi api;

  const FichasLocalWidget({Key? key, required this.api}) : super(key: key);

  @override
  State<FichasLocalWidget> createState() => _FichasLocalWidgetState();
}

class _FichasLocalWidgetState extends State<FichasLocalWidget> {
  List<Map<String, dynamic>> fichas = [];
  List<Map<String, dynamic>> perfiles = [];
  bool isLoading = true;
  bool _generando = false;
  String? error;
  String? _perfilSeleccionado;
  int _cantidadFichas = 1;

  // ── PDFs guardados localmente ──────────────────────────────────────────
  final FichasPdfStore _pdfStore = FichasPdfStore();
  List<PdfBatchRecord> _pdfs = [];
  bool _cargandoPdfs = true;
  String? _pdfOcupado; // id del PDF con una acción en curso (ver/compartir/eliminar)

  // Selección múltiple para borrado masivo de PDFs
  bool _modoSeleccionPdfs = false;
  final Set<String> _pdfsSeleccionados = {};
  bool _eliminandoPdfsSeleccionados = false;

  // Limpieza de fichas ya consumidas en el router
  bool _limpiandoUsadas = false;
  bool _autoLimpiarUsadas = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _cargarPdfs();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.obtenerFichas(),
        widget.api.obtenerPerfiles(),
      ]);
      if (!mounted) return;
      setState(() {
        fichas = results[0];
        perfiles = results[1];
        if (perfiles.isNotEmpty) {
          final existe = perfiles.any((p) => p['name']?.toString() == _perfilSeleccionado);
          if (_perfilSeleccionado == null || !existe) {
            _perfilSeleccionado = perfiles.first['name']?.toString();
          }
        } else {
          _perfilSeleccionado = null;
        }
      });
      if (_autoLimpiarUsadas) {
        await _limpiarFichasUsadas(preguntar: false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => error = _mensajeError(e));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Una ficha se considera "usada" si el router ya registró conexión
  // (tiempo conectado o datos transmitidos). Si tu API devuelve otros
  // nombres de campo, ajusta las claves que se revisan aquí.
  bool _fichaFueUsada(Map<String, dynamic> ficha) {
    final uptime = (ficha['uptime'] ?? ficha['uptime-used'])?.toString() ?? '';
    final bytesIn = int.tryParse((ficha['bytes-in'] ?? ficha['bytesIn'])?.toString() ?? '0') ?? 0;
    final bytesOut = int.tryParse((ficha['bytes-out'] ?? ficha['bytesOut'])?.toString() ?? '0') ?? 0;
    final tieneUptime = uptime.isNotEmpty && uptime != '0s' && uptime != '0';
    return tieneUptime || bytesIn > 0 || bytesOut > 0;
  }

  List<Map<String, dynamic>> get _fichasUsadas => fichas.where(_fichaFueUsada).toList();

  Future<void> _limpiarFichasUsadas({bool preguntar = true}) async {
    final usadas = _fichasUsadas;
    if (usadas.isEmpty) {
      if (preguntar) _snack('No hay fichas usadas para eliminar', _C.textPri);
      return;
    }

    if (preguntar) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: _C.warning.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.cleaning_services_rounded, color: _C.warning, size: 22),
                ),
                const SizedBox(height: 14),
                Text('Eliminar fichas usadas',
                    style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'Se detectaron ${usadas.length} ficha(s) que ya fueron consumidas (con conexión registrada). Se eliminarán del router y no podrán volver a usarse.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                      child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(color: _C.warning, borderRadius: BorderRadius.circular(12)),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.pop(dialogContext, true),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            child: Center(
                                child: Text('Eliminar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700))),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      );
      if (confirmar != true) return;
    }

    setState(() => _limpiandoUsadas = true);
    var eliminadas = 0;
    try {
      for (final f in usadas) {
        final id = f['.id']?.toString();
        if (id == null || id.isEmpty) continue;
        try {
          await widget.api.borrarFicha(id);
          eliminadas++;
        } catch (_) {
          // Si una falla, seguimos con las demás y avisamos al final.
        }
      }
      await _cargarDatos();
      if (eliminadas > 0) {
        _snack('$eliminadas ficha(s) usada(s) eliminada(s)', _C.success);
      }
    } finally {
      if (mounted) setState(() => _limpiandoUsadas = false);
    }
  }

  Future<void> _cargarPdfs() async {
    if (mounted) setState(() => _cargandoPdfs = true);
    try {
      final lista = await _pdfStore.listar();
      if (!mounted) return;
      setState(() {
        _pdfs = lista;
        _cargandoPdfs = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoPdfs = false);
    }
  }

  String _mensajeError(Object e) => e is MikrotikLocalException ? e.mensaje : e.toString();

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.spaceGrotesk(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // Usuario/clave: minúsculas + números, 6 caracteres — fácil de leer y de
  // escribir en el portal cautivo desde un celular.
  String _generarCodigo({int length = 6}) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  String _generarCodigoUnico(Set<String> existentes) {
    String codigo;
    do {
      codigo = _generarCodigo();
    } while (existentes.contains(codigo));
    existentes.add(codigo);
    return codigo;
  }

  Future<void> _crearFichas() async {
    if (_perfilSeleccionado == null) {
      _snack('Selecciona un perfil primero', _C.warning);
      return;
    }

    setState(() => _generando = true);

    final codigosCreados = <String>[];
    final existentes = fichas.map((f) => (f['name']?.toString() ?? '').toLowerCase()).toSet();

    try {
      for (int i = 0; i < _cantidadFichas; i++) {
        final codigo = _generarCodigoUnico(existentes);
        // El mismo código se usa como usuario y como clave del ticket.
        await widget.api.crearFicha(codigo: codigo, perfil: _perfilSeleccionado!);
        codigosCreados.add(codigo);
        if (i < _cantidadFichas - 1) await Future.delayed(const Duration(milliseconds: 100));
      }

      await _cargarDatos();

      if (codigosCreados.isNotEmpty && mounted) {
        await _generarYGuardarPdf(codigosCreados);
      }
    } catch (e) {
      _snack('Error al crear fichas: ${_mensajeError(e)}', _C.danger);
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _generarYGuardarPdf(List<String> codigos) async {
    try {
      final fichasPdf = codigos.map((c) => {'usuario': c, 'clave': c}).toList();
      final bytes = await FichasPdfBuilder.construir(
        fichas: fichasPdf,
        perfil: _perfilSeleccionado!,
      );
      final registro = await _pdfStore.guardar(
        bytes: bytes,
        perfil: _perfilSeleccionado!,
        cantidad: codigos.length,
      );
      await _cargarPdfs();
      if (mounted) _mostrarFichasCreadas(codigos, registro);
    } catch (e) {
      if (mounted) {
        _snack('Fichas creadas, pero falló el PDF: ${_mensajeError(e)}', _C.warning);
        _mostrarFichasCreadas(codigos, null);
      }
    }
  }

  void _mostrarFichasCreadas(List<String> codigos, PdfBatchRecord? pdf) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxHeight: 520),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: _C.success.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: _C.success, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fichas creadas', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
                      Text('Perfil: $_perfilSeleccionado', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11.5)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: codigos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final codigo = codigos[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: _C.surfaceDim, borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const Icon(Icons.vpn_key_rounded, size: 16, color: _C.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child:
                              Text(codigo, style: GoogleFonts.sourceCodePro(color: _C.textPri, fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: codigo));
                            _snack('Código copiado', _C.success);
                          },
                          child: Icon(Icons.copy_rounded, size: 17, color: _C.textSec),
                        ),
                      ]),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              if (pdf != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(color: _C.primary, borderRadius: BorderRadius.circular(12)),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _verPdf(pdf);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text('Ver / compartir PDF', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: codigos.join('\n')));
                      _snack('Todos los códigos copiados', _C.success);
                    },
                    icon: const Icon(Icons.copy_all_rounded, size: 16, color: _C.primary),
                    label: Text('Copiar todos', style: GoogleFonts.spaceGrotesk(color: _C.primary, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: _C.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: _C.dark, borderRadius: BorderRadius.circular(12)),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(dialogContext),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                              child: Text('Cerrar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700))),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _borrarFicha(String id, String codigo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: _C.danger.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline_rounded, color: _C.danger, size: 24),
              ),
              const SizedBox(height: 14),
              Text('Eliminar ficha', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Se eliminará el código "$codigo". No se podrá volver a usar para iniciar sesión.',
                  textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12.5, height: 1.4)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                    child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: _C.danger, borderRadius: BorderRadius.circular(12)),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(dialogContext, true),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: Center(
                              child: Text('Eliminar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700))),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );

    if (confirmar != true) return;

    try {
      await widget.api.borrarFicha(id);
      await _cargarDatos();
      _snack('Ficha "$codigo" eliminada', _C.textPri);
    } catch (e) {
      _snack(_mensajeError(e), _C.danger);
    }
  }

  // ── Acciones sobre PDFs guardados ──────────────────────────────────────

  Future<void> _verPdf(PdfBatchRecord registro) async {
    setState(() => _pdfOcupado = registro.id);
    try {
      final bytes = await _pdfStore.leerBytes(registro);
      await Printing.layoutPdf(
        name: registro.fileName,
        onLayout: (format) async => bytes,
      );
    } catch (e) {
      _snack(_mensajeError(e), _C.danger);
    } finally {
      if (mounted) setState(() => _pdfOcupado = null);
    }
  }

  Future<void> _compartirPdf(PdfBatchRecord registro) async {
    setState(() => _pdfOcupado = registro.id);
    try {
      final bytes = await _pdfStore.leerBytes(registro);
      await Printing.sharePdf(bytes: bytes, filename: registro.fileName);
    } catch (e) {
      _snack(_mensajeError(e), _C.danger);
    } finally {
      if (mounted) setState(() => _pdfOcupado = null);
    }
  }

  Future<void> _eliminarPdf(PdfBatchRecord registro) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: _C.danger.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline_rounded, color: _C.danger, size: 24),
              ),
              const SizedBox(height: 14),
              Text('Eliminar PDF', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Se eliminará "${registro.fileName}" de este dispositivo. Esto no afecta a las fichas ya creadas en el router.',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                    child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: _C.danger, borderRadius: BorderRadius.circular(12)),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(dialogContext, true),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: Center(
                              child: Text('Eliminar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700))),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );

    if (confirmar != true) return;

    try {
      await _pdfStore.eliminar(registro.id);
      await _cargarPdfs();
      _snack('PDF eliminado', _C.textPri);
    } catch (e) {
      _snack(_mensajeError(e), _C.danger);
    }
  }

  void _toggleModoSeleccionPdfs() {
    setState(() {
      _modoSeleccionPdfs = !_modoSeleccionPdfs;
      _pdfsSeleccionados.clear();
    });
  }

  void _toggleSeleccionPdf(String id) {
    setState(() {
      if (_pdfsSeleccionados.contains(id)) {
        _pdfsSeleccionados.remove(id);
      } else {
        _pdfsSeleccionados.add(id);
      }
    });
  }

  void _seleccionarTodosPdfs() {
    setState(() {
      if (_pdfsSeleccionados.length == _pdfs.length) {
        _pdfsSeleccionados.clear();
      } else {
        _pdfsSeleccionados
          ..clear()
          ..addAll(_pdfs.map((r) => r.id));
      }
    });
  }

  Future<void> _eliminarPdfsSeleccionados() async {
    if (_pdfsSeleccionados.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: _C.danger.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.delete_sweep_rounded, color: _C.danger, size: 24),
              ),
              const SizedBox(height: 14),
              Text('Eliminar ${_pdfsSeleccionados.length} PDF(s)',
                  style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Se eliminarán de este dispositivo. Esto no afecta a las fichas ya creadas en el router.',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                    child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: _C.danger, borderRadius: BorderRadius.circular(12)),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(dialogContext, true),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: Center(
                              child: Text('Eliminar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700))),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );

    if (confirmar != true) return;

    setState(() => _eliminandoPdfsSeleccionados = true);
    var eliminados = 0;
    try {
      for (final id in _pdfsSeleccionados.toList()) {
        try {
          await _pdfStore.eliminar(id);
          eliminados++;
        } catch (_) {
          // continúa con los demás
        }
      }
      await _cargarPdfs();
      setState(() {
        _modoSeleccionPdfs = false;
        _pdfsSeleccionados.clear();
      });
      if (eliminados > 0) _snack('$eliminados PDF(s) eliminado(s)', _C.success);
    } finally {
      if (mounted) setState(() => _eliminandoPdfsSeleccionados = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.surfaceDim,
      child: RefreshIndicator(
        color: _C.accent,
        onRefresh: () async {
          await _cargarDatos();
          await _cargarPdfs();
        },
        child: isLoading
            ? ListView(children: const [SizedBox(height: 400, child: Center(child: CircularProgressIndicator(color: _C.accent)))])
            : error != null
                ? _buildError()
                : _buildContenido(),
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      children: [
        SizedBox(
          height: 420,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: _C.danger.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.wifi_off_rounded, color: _C.danger, size: 30),
                  ),
                  const SizedBox(height: 16),
                  Text('No se pudo conectar',
                      style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(error!,
                      textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12.5, height: 1.4)),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_C.accent, Color(0xFF059669)]), borderRadius: BorderRadius.circular(14)),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _cargarDatos,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text('Reintentar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContenido() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Panel de generación
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_C.dark, Color(0xFF1E293B)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: _C.dark.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_C.accent, Color(0xFF059669)]), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Generar fichas',
                          style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      Text('${fichas.length} ficha(s) activas en el router',
                          style: GoogleFonts.spaceGrotesk(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              if (perfiles.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _C.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, color: _C.warning, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Crea al menos un perfil antes de generar fichas',
                          style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 11.5)),
                    ),
                  ]),
                )
              else ...[
                Text('PERFIL',
                    style:
                        GoogleFonts.spaceGrotesk(color: Colors.white54, fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _perfilSeleccionado,
                      isExpanded: true,
                      dropdownColor: _C.dark,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white60),
                      items: perfiles.map((p) {
                        final nombre = p['name']?.toString() ?? '';
                        return DropdownMenuItem(
                            value: nombre, child: Text(nombre, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 13.5)));
                      }).toList(),
                      onChanged: (v) => setState(() => _perfilSeleccionado = v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Text('CANTIDAD',
                      style:
                          GoogleFonts.spaceGrotesk(color: Colors.white54, fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                  const SizedBox(width: 6),
                  Text('(máx. $_kMaxFichasPorLote)', style: GoogleFonts.spaceGrotesk(color: Colors.white38, fontSize: 10)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  _stepperBtn(Icons.remove_rounded, () {
                    if (_cantidadFichas > 1) setState(() => _cantidadFichas--);
                  }),
                  Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text('$_cantidadFichas',
                          style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  _stepperBtn(Icons.add_rounded, () {
                    if (_cantidadFichas < _kMaxFichasPorLote) setState(() => _cantidadFichas++);
                  }),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_C.accent, Color(0xFF059669)]), borderRadius: BorderRadius.circular(14)),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _generando ? null : _crearFichas,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: _generando
                                ? const SizedBox(
                                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.add_circle_rounded, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Text('Generar $_cantidadFichas ficha(s) + PDF',
                                        style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                                  ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
        const SizedBox(height: 18),

        // Panel de PDFs generados
        _buildPanelPdfs(),
        const SizedBox(height: 18),

        // Lista de fichas
        if (fichas.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Expanded(
                child: Text('Fichas en el router (${fichas.length})',
                    style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
              GestureDetector(
                onTap: () => setState(() => _autoLimpiarUsadas = !_autoLimpiarUsadas),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_autoLimpiarUsadas ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                      color: _autoLimpiarUsadas ? _C.success : _C.textSec, size: 22),
                  const SizedBox(width: 3),
                  Text('Auto', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10.5)),
                ]),
              ),
              const SizedBox(width: 6),
              if (_fichasUsadas.isNotEmpty)
                GestureDetector(
                  onTap: _limpiandoUsadas ? null : () => _limpiarFichasUsadas(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(color: _C.warning.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: _limpiandoUsadas
                        ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: _C.warning))
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.cleaning_services_rounded, size: 13, color: _C.warning),
                            const SizedBox(width: 5),
                            Text('Usadas (${_fichasUsadas.length})',
                                style: GoogleFonts.spaceGrotesk(color: _C.warning, fontSize: 11, fontWeight: FontWeight.w700)),
                          ]),
                  ),
                ),
            ]),
          ),
        if (fichas.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Column(children: [
              Icon(Icons.vpn_key_off_rounded, size: 56, color: _C.textSec.withOpacity(0.35)),
              const SizedBox(height: 12),
              Text('No hay fichas creadas', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13)),
            ]),
          )
        else
          ...fichas.asMap().entries.map((entry) {
            final i = entry.key;
            final ficha = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _fichaCard(ficha).animate().fadeIn(duration: 280.ms, delay: (i * 35).ms).slideX(begin: 0.03, end: 0),
            );
          }),
      ],
    );
  }

  // ── Panel de PDFs generados ─────────────────────────────────────────
  Widget _buildPanelPdfs() {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: _C.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.picture_as_pdf_rounded, color: _C.primary, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('PDFs generados', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            if (_cargandoPdfs)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary))
            else if (_pdfs.isNotEmpty)
              TextButton.icon(
                onPressed: _toggleModoSeleccionPdfs,
                icon: Icon(_modoSeleccionPdfs ? Icons.close_rounded : Icons.checklist_rounded, size: 16, color: _C.primary),
                label: Text(_modoSeleccionPdfs ? 'Cancelar' : 'Seleccionar',
                    style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 11.5, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
              ),
          ]),
          const SizedBox(height: 10),
          if (!_cargandoPdfs && _pdfs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child:
                  Text('Todavía no has generado ningún PDF de fichas.', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
            )
          else ...[
            if (_modoSeleccionPdfs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  GestureDetector(
                    onTap: _seleccionarTodosPdfs,
                    child: Text(
                      _pdfsSeleccionados.length == _pdfs.length ? 'Quitar selección' : 'Seleccionar todos',
                      style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  Text('${_pdfsSeleccionados.length} seleccionado(s)', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11.5)),
                ]),
              ),
            ..._pdfs.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _pdfCard(r),
                )),
            if (_modoSeleccionPdfs) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    color: _pdfsSeleccionados.isEmpty ? _C.border : _C.danger,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _pdfsSeleccionados.isEmpty || _eliminandoPdfsSeleccionados ? null : _eliminarPdfsSeleccionados,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: _eliminandoPdfsSeleccionados
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.delete_sweep_rounded, color: _pdfsSeleccionados.isEmpty ? _C.textSec : Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Eliminar seleccionados (${_pdfsSeleccionados.length})',
                                    style: GoogleFonts.spaceGrotesk(
                                        color: _pdfsSeleccionados.isEmpty ? _C.textSec : Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13),
                                  ),
                                ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _pdfCard(PdfBatchRecord r) {
    final ocupado = _pdfOcupado == r.id;
    final seleccionado = _pdfsSeleccionados.contains(r.id);
    return Material(
      color: seleccionado ? _C.primary.withOpacity(0.08) : _C.surfaceDim,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _modoSeleccionPdfs ? () => _toggleSeleccionPdf(r.id) : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: seleccionado ? Border.all(color: _C.primary, width: 1.4) : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            if (_modoSeleccionPdfs) ...[
              Icon(
                seleccionado ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: seleccionado ? _C.primary : _C.textSec.withOpacity(0.5),
                size: 22,
              ),
              const SizedBox(width: 10),
            ] else ...[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: _C.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.picture_as_pdf_rounded, color: _C.danger, size: 18),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r.cantidad} ficha(s) · ${r.perfil}',
                      style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(_fechaCorta(r.fechaCreacion), style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10.5)),
                ],
              ),
            ),
            if (!_modoSeleccionPdfs)
              if (ocupado)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary)),
                )
              else ...[
                IconButton(
                  onPressed: () => _verPdf(r),
                  icon: const Icon(Icons.visibility_rounded, color: _C.primary, size: 19),
                  tooltip: 'Ver / descargar',
                ),
                IconButton(
                  onPressed: () => _compartirPdf(r),
                  icon: const Icon(Icons.ios_share_rounded, color: _C.textSec, size: 18),
                  tooltip: 'Compartir',
                ),
                IconButton(
                  onPressed: () => _eliminarPdf(r),
                  icon: Icon(Icons.delete_outline_rounded, color: _C.danger.withOpacity(0.8), size: 20),
                  tooltip: 'Eliminar',
                ),
              ],
          ]),
        ),
      ),
    );
  }

  String _fechaCorta(DateTime d) {
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)} ${meses[d.month - 1]} ${d.year} · ${p(d.hour)}:${p(d.minute)}';
  }

  Widget _stepperBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _fichaCard(Map<String, dynamic> ficha) {
    final codigo = ficha['name']?.toString() ?? 'Sin código';
    final perfil = ficha['profile']?.toString() ?? 'N/A';
    final id = ficha['.id']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: _C.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.vpn_key_rounded, color: _C.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(codigo, style: GoogleFonts.sourceCodePro(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                _chip(Icons.person_rounded, perfil, _C.purple),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: codigo));
              _snack('Código copiado', _C.success);
            },
            icon: Icon(Icons.copy_rounded, color: _C.textSec, size: 18),
            tooltip: 'Copiar código',
          ),
          IconButton(
            onPressed: () => _borrarFicha(id, codigo),
            icon: Icon(Icons.delete_outline_rounded, color: _C.danger.withOpacity(0.8), size: 21),
            tooltip: 'Eliminar ficha',
          ),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(texto, style: GoogleFonts.spaceGrotesk(color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
