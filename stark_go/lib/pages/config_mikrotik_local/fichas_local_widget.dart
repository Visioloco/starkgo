import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/blindaje_admin_service.dart';
import '../../services/hotspot_vouchers.dart';
import '../../services/mikrotik_local_api.dart';
import '../../services/pdf_fichas_service.dart';
import '../../widgets/sin_soporte_web.dart';

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

// ── Límites de generación de vouchers ──────────────────────────────────────
// Los valores viven en pdf_fichas_service.dart (compartidos con el PDF) y se
// exponen acá como alias locales para no repetirlos:
//   kMaxVouchersPorLote → máximo TOTAL de fichas por lote (1000).
//   kMaxVouchersPorPdf  → máximo de fichas por CADA archivo PDF (100). Un lote
//                         de 1000 se reparte solo en 10 PDFs.
const int _kMaxVouchersPorLote = kMaxVouchersPorLote;
const int _kMaxVouchersPorPdf = kMaxVouchersPorPdf;

// Máximo de códigos que se listan en el diálogo de confirmación: el resto
// queda en los PDFs. Así el diálogo sigue rápido con lotes de 1000.
const int _kMaxCodigosEnDialogo = 200;

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

  /// Cantidad de vouchers a crear (1 … 1000). Se escribe en el campo numérico
  /// del panel "Generar fichas"; el getter [_cantidadFichas] la mantiene
  /// siempre dentro del límite permitido.
  final TextEditingController _cantidadCtrl = TextEditingController(text: '1');

  /// Progreso de la creación (para lotes grandes: "345/1000").
  int _progresoCreadas = 0;

  // ── PDFs guardados localmente ──────────────────────────────────────────
  final FichasPdfStore _pdfStore = FichasPdfStore();
  List<PdfBatchRecord> _pdfs = [];
  bool _cargandoPdfs = true;
  String? _pdfOcupado; // id del PDF con una acción en curso (ver/compartir/eliminar)

  // Selección múltiple para borrado masivo de PDFs
  bool _modoSeleccionPdfs = false;
  final Set<String> _pdfsSeleccionados = {};
  bool _eliminandoPdfsSeleccionados = false;

  // Limpieza de fichas ya USADAS y CADUCADAS (las nuevas nunca se borran)
  bool _limpiandoCaducadas = false;
  bool _autoLimpiarCaducadas = true;

  /// Preferencia guardada: ¿el usuario dejó activada la limpieza automática?
  static const String _kPrefAutoLimpiar = 'fichas_auto_limpiar_caducadas';

  /// Revisa y limpia solo cada 5 minutos mientras el panel está abierto.
  Timer? _timerAutoLimpiar;

  // Aplicar 'limit-uptime' a fichas viejas
  bool _aplicandoLimite = false;

  @override
  void initState() {
    super.initState();
    _inicializar();
    _programarAutoLimpieza();
  }

  @override
  void dispose() {
    _timerAutoLimpiar?.cancel();
    _cantidadCtrl.dispose();
    super.dispose();
  }

  /// Carga la preferencia del switch "Auto" y recién ahí pide los datos:
  /// así, si el usuario lo dejó apagado, no se borra nada al abrir.
  Future<void> _inicializar() async {
    await _cargarPrefAutoLimpiar();
    if (!mounted) return;
    await _cargarDatos();
    await _cargarPdfs();
  }

  Future<void> _cargarPrefAutoLimpiar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getBool(_kPrefAutoLimpiar);
      if (guardado == null || !mounted) return;
      if (guardado != _autoLimpiarCaducadas) {
        setState(() => _autoLimpiarCaducadas = guardado);
      }
    } catch (_) {
      // Si falla, se mantiene el valor por defecto (activado).
    }
  }

  /// Cada 5 minutos vuelve a leer las fichas del router: si alguna ya se usó y
  /// caducó, se borra sola (con el switch "Auto" activado).
  void _programarAutoLimpieza() {
    _timerAutoLimpiar?.cancel();
    _timerAutoLimpiar = Timer.periodic(const Duration(minutes: 5), (_) async {
      if (!mounted || !_autoLimpiarCaducadas || _generando || _limpiandoCaducadas) return;
      await _cargarDatos();
    });
  }

  Future<void> _toggleAutoLimpiar() async {
    final nuevo = !_autoLimpiarCaducadas;
    setState(() => _autoLimpiarCaducadas = nuevo);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefAutoLimpiar, nuevo);
    } catch (_) {}
    // Al activarlo, limpiá de una las que ya están caducadas.
    if (nuevo && mounted) await _cargarDatos();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cantidad de vouchers del lote (1 … 1000) y reparto en PDFs
  // ─────────────────────────────────────────────────────────────────────────

  /// Cantidad pedida, siempre dentro del límite (1 … [_kMaxVouchersPorLote]).
  int get _cantidadFichas {
    final v = int.tryParse(_cantidadCtrl.text.trim()) ?? 1;
    return v.clamp(1, _kMaxVouchersPorLote);
  }

  /// Cuántos PDFs generará el lote (bloques de [_kMaxVouchersPorPdf] fichas).
  int get _pdfsDelLote => pdfsParaLote(_cantidadFichas, porPdf: _kMaxVouchersPorPdf);

  void _ajustarCantidad(int delta) {
    final nueva = (_cantidadFichas + delta).clamp(1, _kMaxVouchersPorLote);
    setState(() => _cantidadCtrl.text = '$nueva');
  }

  void _fijarCantidad(int valor) {
    setState(() => _cantidadCtrl.text = '${valor.clamp(1, _kMaxVouchersPorLote)}');
  }

  /// Duración que se le copiará a cada pin (`limit-uptime`) según el perfil
  /// elegido. `null` = el perfil no tiene duración → el pin no caducaría.
  Duration? get _duracionPerfilSeleccionado {
    if (_perfilSeleccionado == null) return null;
    for (final p in perfiles) {
      if ((p['name'] ?? '').toString() == _perfilSeleccionado) {
        final d = parseDuracionRouteros((p['session-timeout'] ?? '').toString());
        if (d != null && d.inSeconds > 0) return d;
        return null;
      }
    }
    return null;
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
      if (_autoLimpiarCaducadas) {
        await _limpiarFichasCaducadas(preguntar: false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => error = _mensajeError(e));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ── Reglas de uso y caducidad (ver services/hotspot_vouchers.dart) ──
  // Una ficha se considera "usada" si el router ya registró conexión (tiempo
  // consumido o datos transferidos) y "caducada" cuando ese uso ya agotó su
  // `limit-uptime`. La limpieza borra SÓLO las que cumplen LAS DOS cosas:
  // las nuevas (sin vender) y las que todavía tienen tiempo a favor se quedan.
  bool _fichaFueUsada(Map<String, dynamic> ficha) => fichaUsada(ficha);

  List<Map<String, dynamic>> get _fichasUsadas => fichas.where(_fichaFueUsada).toList();

  /// Fichas usadas que ya agotaron su tiempo: las únicas que se borran solas.
  List<Map<String, dynamic>> get _fichasCaducadas => fichas.where(fichaListaParaBorrar).toList();

  Future<void> _limpiarFichasCaducadas({bool preguntar = true}) async {
    final caducadas = _fichasCaducadas;
    if (caducadas.isEmpty) {
      if (preguntar) _snack('No hay fichas usadas y caducadas para eliminar', _C.textPri);
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
                Text('Eliminar fichas caducadas',
                    style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'Se detectaron ${caducadas.length} ficha(s) que YA SE USARON y cuya duración ya se agotó. '
                  'Se eliminarán del router y no podrán volver a usarse.\n\n'
                  'Las fichas nuevas (sin usar) y las que todavía tienen tiempo a favor NO se tocan.',
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

    setState(() => _limpiandoCaducadas = true);
    var eliminadas = 0;
    try {
      for (final f in caducadas) {
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
        _snack('$eliminadas ficha(s) usada(s) y caducada(s) eliminada(s)', _C.success);
      }
    } finally {
      if (mounted) setState(() => _limpiandoCaducadas = false);
    }
  }

  /// Aplica el 'limit-uptime' (tiempo total acumulado) a las fichas que NO lo
  /// tienen, copiando la duración del perfil de cada una. Arregla las fichas
  /// viejas creadas antes de este cambio.
  Future<void> _aplicarLimiteFichas() async {
    // perfil -> duración (ej. "1h")
    final porPerfil = <String, String>{};
    for (final p in perfiles) {
      final n = (p['name'] ?? '').toString();
      final st = (p['session-timeout'] ?? '').toString().trim();
      if (n.isNotEmpty && st.isNotEmpty && st != '0s' && st != '0') {
        porPerfil[n] = st;
      }
    }

    final pendientes = fichas.where((f) {
      final lu = (f['limit-uptime'] ?? '').toString().trim();
      return lu.isEmpty || lu == '0s' || lu == '0';
    }).toList();

    if (pendientes.isEmpty) {
      _snack('Todas las fichas ya tienen su límite de tiempo', _C.textPri);
      return;
    }

    setState(() => _aplicandoLimite = true);
    var aplicadas = 0;
    var sinPerfil = 0;
    try {
      for (final f in pendientes) {
        final id = f['.id']?.toString();
        final perfil = (f['profile'] ?? '').toString();
        final limite = porPerfil[perfil];
        if (id == null || id.isEmpty) continue;
        if (limite == null) {
          sinPerfil++;
          continue;
        }
        try {
          await widget.api.aplicarLimitUptime(id: id, limitUptime: limite);
          aplicadas++;
        } catch (_) {
          // si una falla, seguimos con las demás
        }
      }
      await _cargarDatos();
      final partes = <String>[];
      if (aplicadas > 0) partes.add('$aplicadas actualizada(s)');
      if (sinPerfil > 0) partes.add('$sinPerfil sin perfil con duración');
      _snack(
        'Límite de tiempo: ${partes.isEmpty ? 'no se pudo actualizar ninguna' : partes.join(', ')}',
        aplicadas > 0 ? _C.success : _C.warning,
      );
    } finally {
      if (mounted) setState(() => _aplicandoLimite = false);
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

    // Cantidad ya validada por el getter: entre 1 y _kMaxVouchersPorLote.
    final cantidad = _cantidadFichas;

    // Duración del perfil seleccionado (MikroTik la devuelve como "1h", "1d"…).
    // Se copia como 'limit-uptime' en cada ficha: ESO es lo que hace que la
    // ficha se ACABE (tiempo total acumulado). El 'session-timeout' del perfil
    // solo limita cada sesión y se reinicia al volver a entrar.
    String? limitUptime;
    for (final p in perfiles) {
      if ((p['name']?.toString() ?? '') == _perfilSeleccionado) {
        final st = (p['session-timeout'] ?? '').toString().trim();
        if (st.isNotEmpty && st != '0s' && st != '0') limitUptime = st;
        break;
      }
    }

    // Sin duración el pin NUNCA deja de dar acceso: confirmamos antes de crear.
    if (limitUptime == null) {
      final continuar = await _confirmarSinDuracion();
      if (continuar != true || !mounted) return;
    }

    // 🛡️ Blindaje del administrador: si está activado, tu teléfono queda
    // "bypassed" en el hotspot ANTES de crear las fichas, así el portal
    // cautivo no te pide una ficha/PIN mientras trabajás. Es best-effort:
    // nunca frena la creación si algo falla.
    await BlindajeAdminService.autoBlindar(apiLocal: widget.api);

    setState(() {
      _generando = true;
      _progresoCreadas = 0;
    });

    final codigosCreados = <String>[];
    final existentes = fichas.map((f) => (f['name']?.toString() ?? '').toLowerCase()).toSet();

    try {
      for (int i = 0; i < cantidad; i++) {
        final codigo = _generarCodigoUnico(existentes);
        // El mismo código se usa como usuario y como clave del ticket.
        await widget.api.crearFicha(
          codigo: codigo,
          perfil: _perfilSeleccionado!,
          limitUptime: limitUptime,
        );
        codigosCreados.add(codigo);
        if (mounted) setState(() => _progresoCreadas = i + 1);
        if (i < cantidad - 1) await Future.delayed(const Duration(milliseconds: 100));
      }

      await _cargarDatos();

      if (codigosCreados.isNotEmpty && mounted) {
        final pdfs = await _generarYGuardarPdfs(codigosCreados);
        if (mounted) _mostrarFichasCreadas(codigosCreados, pdfs);
      }
    } catch (e) {
      // Si el router cortó a mitad de camino, las fichas ya creadas se
      // convierten igual en PDF para no perderlas.
      if (codigosCreados.isNotEmpty && mounted) {
        _snack('Se crearon ${codigosCreados.length} de $cantidad fichas. ${_mensajeError(e)}', _C.warning);
        List<PdfBatchRecord> pdfs = const [];
        try {
          pdfs = await _generarYGuardarPdfs(codigosCreados);
        } catch (_) {}
        if (mounted) _mostrarFichasCreadas(codigosCreados, pdfs);
      } else {
        _snack('Error al crear fichas: ${_mensajeError(e)}', _C.danger);
      }
    } finally {
      if (mounted) {
        setState(() {
          _generando = false;
          _progresoCreadas = 0;
        });
      }
    }
  }

  /// Construye y guarda los PDFs del lote: un archivo por cada bloque de
  /// [_kMaxVouchersPorPdf] fichas (ej. 1000 fichas → 10 PDFs de 100).
  Future<List<PdfBatchRecord>> _generarYGuardarPdfs(List<String> codigos) async {
    final registros = <PdfBatchRecord>[];
    for (final bloque in dividirEnBloques(codigos, _kMaxVouchersPorPdf)) {
      final fichasPdf = bloque.map((c) => {'usuario': c, 'clave': c}).toList();
      final bytes = await FichasPdfBuilder.construir(
        fichas: fichasPdf,
        perfil: _perfilSeleccionado!,
      );
      registros.add(await _pdfStore.guardar(
        bytes: bytes,
        perfil: _perfilSeleccionado!,
        cantidad: bloque.length,
      ));
    }
    await _cargarPdfs();
    return registros;
  }

  void _mostrarFichasCreadas(List<String> codigos, List<PdfBatchRecord> pdfs) {
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
                      Text('${codigos.length} ficha(s) creadas',
                          style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
                      Text('Perfil: $_perfilSeleccionado', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11.5)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  // Con lotes grandes sólo se listan los primeros códigos (los
                  // demás quedan en los PDFs) para que el diálogo no se trabe.
                  itemCount: codigos.length > _kMaxCodigosEnDialogo ? _kMaxCodigosEnDialogo : codigos.length,
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
              if (codigos.length > _kMaxCodigosEnDialogo) ...[
                const SizedBox(height: 8),
                Text(
                  'Mostrando los primeros $_kMaxCodigosEnDialogo códigos. Los ${codigos.length} están en los PDFs guardados.',
                  style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, height: 1.35),
                ),
              ],
              const SizedBox(height: 14),
              if (pdfs.isNotEmpty) ...[
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
                          _verPdf(pdfs.first);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              pdfs.length == 1 ? 'Ver / compartir PDF' : 'Ver / compartir PDF 1 de ${pdfs.length}',
                              style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
                if (pdfs.length > 1) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Se guardaron ${pdfs.length} PDFs de hasta $_kMaxVouchersPorPdf fichas cada uno. '
                    'Están todos en "PDFs generados" (ahí podés verlos, compartirlos o borrarlos).',
                    style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, height: 1.35),
                  ),
                ],
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

  /// Descarga el PDF a la carpeta de Descargas del dispositivo.
  Future<void> _descargarPdf(PdfBatchRecord registro) async {
    setState(() => _pdfOcupado = registro.id);
    try {
      final bytes = await _pdfStore.leerBytes(registro);

      // Intentamos guardar en la carpeta de Descargas del dispositivo.
      Directory? destino;
      try {
        destino = await getDownloadsDirectory();
      } catch (_) {
        destino = null;
      }

      if (destino == null) {
        // Si no hay carpeta de descargas (p. ej. iOS), usamos documentos.
        destino = await getApplicationDocumentsDirectory();
      }

      final archivo = File('${destino.path}/${registro.fileName}');

      await archivo.writeAsBytes(bytes, flush: true);

      _snack('PDF descargado en ${archivo.path}', _C.success);
    } catch (e) {
      _snack('No se pudo descargar el PDF: ${_mensajeError(e)}', _C.danger);
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
    // ── WEB: las fichas locales guardan PDFs en el teléfono (no hay soporte) ──
    if (kIsWeb) {
      return const SinSoporteWebInline(
        titulo: 'Fichas locales',
        detalle: 'Generar y guardar fichas PDF en el equipo sólo está '
            'disponible desde la app del teléfono.',
      );
    }
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
                _buildDuracionPin(),
                const SizedBox(height: 14),
                Row(children: [
                  Text('CANTIDAD',
                      style:
                          GoogleFonts.spaceGrotesk(color: Colors.white54, fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                  const SizedBox(width: 6),
                  Text('(1 a $_kMaxVouchersPorLote · PDF de $_kMaxVouchersPorPdf)',
                      style: GoogleFonts.spaceGrotesk(color: Colors.white38, fontSize: 10)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  _stepperBtn(Icons.remove_rounded, () => _ajustarCantidad(-10)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
                      child: TextField(
                        controller: _cantidadCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                        style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 11),
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => setState(() => _cantidadCtrl.text = '$_cantidadFichas'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _stepperBtn(Icons.add_rounded, () => _ajustarCantidad(10)),
                ]),
                const SizedBox(height: 8),
                // Atajos rápidos: 10 / 50 / 100 / 500 / máximo 1000
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _chipCantidad('10', 10),
                  _chipCantidad('50', 50),
                  _chipCantidad('100', 100),
                  _chipCantidad('500', 500),
                  _chipCantidad('Máx $_kMaxVouchersPorLote', _kMaxVouchersPorLote),
                ]),
                const SizedBox(height: 8),
                Text(
                  'Se crearán $_cantidadFichas ficha(s) y ${_pdfsDelLote == 1 ? '1 PDF' : '$_pdfsDelLote PDFs de hasta $_kMaxVouchersPorPdf'}.',
                  style: GoogleFonts.spaceGrotesk(color: Colors.white60, fontSize: 11),
                ),
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
                                ? Row(mainAxisSize: MainAxisSize.min, children: [
                                    const SizedBox(
                                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                    const SizedBox(width: 10),
                                    Text(_progresoCreadas > 0 ? 'Creando $_progresoCreadas de $_cantidadFichas…' : 'Creando fichas…',
                                        style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                                  ])
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
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Fichas en el router (${fichas.length})',
                        style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${fichas.length - _fichasUsadas.length} nueva(s) · '
                      '${_fichasUsadas.length - _fichasCaducadas.length} en uso · '
                      '${_fichasCaducadas.length} caducada(s)',
                      style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10.5),
                    ),
                  ]),
                ),
                GestureDetector(
                  onTap: _toggleAutoLimpiar,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_autoLimpiarCaducadas ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                        color: _autoLimpiarCaducadas ? _C.success : _C.textSec, size: 22),
                    const SizedBox(width: 3),
                    Text('Auto', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10.5)),
                  ]),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                'La limpieza borra sólo las fichas que YA SE USARON y su tiempo ya caducó (ej. 1 hora, 1 semana o 1 mes). '
                'Las nuevas y las que todavía tienen tiempo a favor se conservan. '
                'Con "Auto" activado se revisa cada 5 minutos.',
                style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10.5, height: 1.35),
              ),
              const SizedBox(height: 10),
              Row(children: [
                // Aplica 'limit-uptime' a las fichas viejas que no lo tienen.
                GestureDetector(
                  onTap: (_aplicandoLimite || _generando) ? null : _aplicarLimiteFichas,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(color: _C.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: _aplicandoLimite
                        ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary))
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.timer_rounded, size: 13, color: _C.primary),
                            const SizedBox(width: 5),
                            Text('Aplicar tiempo a viejas',
                                style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                          ]),
                  ),
                ),
                const Spacer(),
                if (_fichasCaducadas.isNotEmpty)
                  GestureDetector(
                    onTap: _limpiandoCaducadas ? null : () => _limpiarFichasCaducadas(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(color: _C.warning.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                      child: _limpiandoCaducadas
                          ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: _C.warning))
                          : Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.cleaning_services_rounded, size: 13, color: _C.warning),
                              const SizedBox(width: 5),
                              Text('Caducadas (${_fichasCaducadas.length})',
                                  style: GoogleFonts.spaceGrotesk(color: _C.warning, fontSize: 11, fontWeight: FontWeight.w700)),
                            ]),
                    ),
                  ),
              ]),
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
                  tooltip: 'Ver',
                ),
                IconButton(
                  onPressed: () => _descargarPdf(r),
                  icon: const Icon(Icons.download_rounded, color: _C.success, size: 19),
                  tooltip: 'Descargar PDF',
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

  /// Atajo de cantidad (10 / 50 / 100 / 500 / Máx 1000) del panel de vouchers.
  Widget _chipCantidad(String label, int valor) {
    final activo = _cantidadFichas == valor;
    return Material(
      color: activo ? _C.accent.withOpacity(0.35) : Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _fijarCantidad(valor),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(label,
              style: GoogleFonts.spaceGrotesk(
                  color: activo ? Colors.white : Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  /// Aviso con la duración que tendrá cada pin del perfil elegido: responde
  /// "¿el pin dura 1 hora si escojo 1 hora?" antes de generarlo.
  Widget _buildDuracionPin() {
    final d = _duracionPerfilSeleccionado;
    final ok = d != null;
    final color = ok ? _C.success : _C.warning;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ok ? Icons.timer_rounded : Icons.timer_off_rounded, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            ok
                ? 'Cada pin durará ${duracionLegible(d)} de navegación: el tiempo corre mientras el cliente está '
                    'conectado y, al agotarse, el router ya no lo deja entrar.'
                : 'Este perfil NO tiene duración: los pines no caducarían nunca. Creá o editá el perfil con '
                    '1 hora, 1 día, 1 semana o 1 mes.',
            style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 10.5, height: 1.35),
          ),
        ),
      ]),
    );
  }

  /// El perfil elegido no tiene duración: los pines no caducarían nunca.
  /// Pedimos confirmación para que nadie genere pines "infinitos" sin darse
  /// cuenta (la caducidad es lo que hace que el pin deje de dar acceso).
  Future<bool?> _confirmarSinDuracion() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: _C.warning.withOpacity(0.12), shape: BoxShape.circle),
              child: const Icon(Icons.timer_off_rounded, color: _C.warning, size: 22),
            ),
            const SizedBox(height: 14),
            Text('Perfil sin duración',
                style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'El perfil "$_perfilSeleccionado" no tiene duración, así que los pines NO van a caducar: '
              'darán acceso hasta que los borres a mano.\n\n'
              'Si querés pines de 1 hora, 1 día, 1 semana o 1 mes, cancelá y editá el perfil.',
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
                            child: Text('Crear igual', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700))),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ]),
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
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _chip(Icons.person_rounded, perfil, _C.purple),
                    _chipEstado(ficha),
                  ],
                ),
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

  /// Chip con el estado de la ficha: Nueva / En uso (con el tiempo restante) /
  /// Caducada (la que borra la limpieza) / Sin límite.
  Widget _chipEstado(Map<String, dynamic> ficha) {
    final estado = estadoDeFicha(ficha);
    var color = _C.textSec;
    var icon = Icons.timer_rounded;
    var texto = estado.etiqueta;
    switch (estado) {
      case EstadoFicha.nueva:
        color = _C.primary;
        icon = Icons.fiber_new_rounded;
        break;
      case EstadoFicha.enUso:
        color = _C.success;
        icon = Icons.timer_rounded;
        final resta = tiempoRestante(ficha);
        if (resta != null) texto = 'En uso · restan ${duracionLegible(resta)}';
        break;
      case EstadoFicha.caducada:
        color = _C.danger;
        icon = Icons.timer_off_rounded;
        break;
      case EstadoFicha.sinLimite:
        color = _C.warning;
        icon = Icons.all_inclusive_rounded;
        // Si el perfil sí tiene duración, la mostramos para que se sepa qué
        // se aplicará con "Aplicar tiempo a viejas".
        final sugerida = duracionVoucher(ficha, perfiles);
        if (sugerida != null) texto = 'Sin límite · perfil ${duracionLegible(sugerida)}';
        break;
    }
    return _chip(icon, texto, color);
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
