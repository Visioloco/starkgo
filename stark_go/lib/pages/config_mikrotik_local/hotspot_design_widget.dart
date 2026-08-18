import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/hotspot_ftp_service.dart';
import '../../services/hotspot_design_store.dart';

// ─────────────────────────────────────────────────────────────────────────
// Misma paleta usada en el resto del módulo MikroTik.
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
}

// Plantilla base: lo mínimo que el router necesita para procesar el login.
// Pásale esto (o el prompt sugerido) a la IA que use el cliente para que
// no rompa el formulario al "decorarlo".
const String kPlantillaBaseHotspot = '''
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <title>Acceso WiFi</title>
  <style>
    body { font-family: sans-serif; background:#0F172A; color:#fff; display:flex; align-items:center; justify-content:center; height:100vh; margin:0; }
    .tarjeta { background:#1E293B; padding:32px; border-radius:16px; width:280px; text-align:center; }
    img.logo { width:96px; margin-bottom:16px; }
    input { width:100%; padding:12px; margin:8px 0; border-radius:8px; border:none; box-sizing:border-box; }
    button { width:100%; padding:12px; border-radius:8px; border:none; background:#00C6AE; color:#fff; font-weight:bold; margin-top:8px; }
    .error { color:#F59E0B; font-size:13px; margin-top:8px; }
  </style>
</head>
<body>
  <div class="tarjeta">
    <img class="logo" src="logo.png" alt="Logo" />
    <h2>Bienvenido</h2>
    <form name="login" action="\$(link-login-only)" method="post">
      <input type="hidden" name="dst" value="\$(link-orig)" />
      <input type="hidden" name="popup" value="true" />
      <input type="text" name="username" placeholder="Usuario" />
      <input type="password" name="password" placeholder="Clave" />
      <button type="submit">Conectar</button>
    </form>
    <div class="error">\$(error)</div>
  </div>
</body>
</html>
''';

class HotspotDesignWidget extends StatefulWidget {
  final String host;
  final String usuario;
  final String clave;
  final int puertoFtp;

  const HotspotDesignWidget({
    Key? key,
    required this.host,
    required this.usuario,
    required this.clave,
    this.puertoFtp = 21,
  }) : super(key: key);

  @override
  State<HotspotDesignWidget> createState() => _HotspotDesignWidgetState();
}

class _HotspotDesignWidgetState extends State<HotspotDesignWidget> {
  late final HotspotFtpService _ftp;
  final HotspotDesignStore _historial = HotspotDesignStore();

  final TextEditingController _htmlController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  Uint8List? _logoBytes;
  String? _logoNombre;

  bool _publicando = false;
  bool _cargandoHistorial = true;
  bool _cargandoBorrador = true;
  List<HotspotDesignVersion> _versiones = [];

  // Evita escribir a disco en cada tecla mientras el usuario edita el HTML.
  Timer? _debounceBorrador;

  @override
  void initState() {
    super.initState();
    _ftp = HotspotFtpService(
      host: widget.host,
      usuario: widget.usuario,
      clave: widget.clave,
      puerto: widget.puertoFtp,
    );
    _htmlController.addListener(_onHtmlCambiado);
    _cargarBorrador();
    _cargarHistorial();
  }

  @override
  void dispose() {
    _debounceBorrador?.cancel();
    _htmlController.removeListener(_onHtmlCambiado);
    _htmlController.dispose();
    super.dispose();
  }

  // ── Borrador local (persiste aunque se cierre la app) ──

  Future<void> _cargarBorrador() async {
    setState(() => _cargandoBorrador = true);
    try {
      final borrador = await _historial.cargarBorrador();
      if (!mounted) return;
      if (borrador != null) {
        setState(() {
          _htmlController.text = borrador.html;
          _logoBytes = borrador.logoBytes;
          _logoNombre = borrador.logoNombre;
        });
      }
    } catch (_) {
      // Si falla la carga, simplemente arrancamos en blanco.
    } finally {
      if (mounted) setState(() => _cargandoBorrador = false);
    }
  }

  void _onHtmlCambiado() {
    _debounceBorrador?.cancel();
    _debounceBorrador = Timer(const Duration(milliseconds: 600), _guardarBorrador);
  }

  Future<void> _guardarBorrador() async {
    await _historial.guardarBorrador(
      html: _htmlController.text,
      logoBytes: _logoBytes,
      logoNombre: _logoNombre,
    );
  }

  Future<void> _cargarHistorial() async {
    setState(() => _cargandoHistorial = true);
    try {
      final lista = await _historial.listar();
      if (!mounted) return;
      setState(() {
        _versiones = lista;
        _cargandoHistorial = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoHistorial = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.spaceGrotesk(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _usarPlantillaBase() {
    _htmlController.text = kPlantillaBaseHotspot;
    _guardarBorrador();
    _snack('Plantilla base cargada, ahora puedes editarla o pegar la de la IA', _C.primary);
  }

  void _copiarPromptParaIA() {
    const prompt = 'Genera un archivo HTML+CSS (todo en un solo archivo, con <style> interno) '
        'para una página de login de hotspot WiFi de MikroTik. Diseño: [describe aquí lo que quieras]. '
        'Es obligatorio conservar exactamente: el <form name="login" action="\$(link-login-only)" method="post">, '
        'los campos ocultos dst y popup, los inputs name="username" y name="password", el botón submit, '
        'y la variable \$(error) visible en algún punto. El logo debe referenciarse como <img src="logo.png">. '
        'No uses scripts ni fuentes externas que requieran internet.';
    Clipboard.setData(const ClipboardData(text: prompt));
    _snack('Prompt copiado — pégalo en tu IA favorita', _C.success);
  }

  Future<void> _elegirLogo() async {
    try {
      final XFile? archivo = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (archivo == null) return;
      final bytes = await archivo.readAsBytes();
      setState(() {
        _logoBytes = bytes;
        _logoNombre = 'logo.png';
      });
      await _guardarBorrador();
    } catch (e) {
      _snack('No se pudo cargar la imagen: $e', _C.danger);
    }
  }

  bool _htmlTieneLoCritico(String html) {
    return html.contains('name="username"') &&
        html.contains('name="password"') &&
        html.contains(r'$(link-login-only)') &&
        html.contains(r'$(error)');
  }

  Future<void> _publicar() async {
    final html = _htmlController.text.trim();
    if (html.isEmpty) {
      _snack('Pega o escribe el HTML antes de publicar', _C.warning);
      return;
    }

    if (!_htmlTieneLoCritico(html)) {
      final continuar = await _confirmarFaltantes();
      if (continuar != true) return;
    }

    setState(() => _publicando = true);
    try {
      final archivos = <String, Uint8List>{
        'login.html': Uint8List.fromList(html.codeUnits),
      };
      if (_logoBytes != null) {
        archivos[_logoNombre ?? 'logo.png'] = _logoBytes!;
      }
      await _ftp.subirArchivos(archivos);

      await _historial.guardar(html: html, incluyoLogoNuevo: _logoBytes != null);
      await _guardarBorrador();
      await _cargarHistorial();

      _snack('Diseño publicado en el router ✓', _C.success);
    } catch (e) {
      _snack('Error al publicar: $e', _C.danger);
    } finally {
      if (mounted) setState(() => _publicando = false);
    }
  }

  Future<bool?> _confirmarFaltantes() {
    return showDialog<bool>(
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
                child: const Icon(Icons.warning_amber_rounded, color: _C.warning, size: 24),
              ),
              const SizedBox(height: 14),
              Text('Faltan elementos clave', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Tu HTML no parece tener el formulario de usuario/clave o la variable de error del router. '
                'Si publicas así, el login podría no funcionar. ¿Publicar de todas formas?',
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
                              child: Text('Publicar igual',
                                  style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700))),
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

  Future<void> _revertirA(HotspotDesignVersion version) async {
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
              const Icon(Icons.restore_rounded, color: _C.primary, size: 30),
              const SizedBox(height: 12),
              Text('Volver a esta versión', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Se publicará este HTML en el router ahora mismo (reemplaza el actual).',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: _C.primary, borderRadius: BorderRadius.circular(12)),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(dialogContext, true),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: Center(
                              child: Text('Publicar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700))),
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

    setState(() => _publicando = true);
    try {
      await _ftp.subirArchivo(
        nombreArchivo: 'login.html',
        contenido: Uint8List.fromList(version.html.codeUnits),
      );
      _htmlController.text = version.html;
      await _guardarBorrador();
      _snack('Versión anterior restaurada ✓', _C.success);
    } catch (e) {
      _snack('Error al restaurar: $e', _C.danger);
    } finally {
      if (mounted) setState(() => _publicando = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.surfaceDim,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildIntro(),
          const SizedBox(height: 16),
          _buildLogoPicker(),
          const SizedBox(height: 16),
          _buildHtmlEditor(),
          const SizedBox(height: 16),
          _buildBotonPublicar(),
          const SizedBox(height: 20),
          _buildHistorial(),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_C.dark, Color(0xFF1E293B)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.design_services_rounded, color: _C.accent, size: 20),
            const SizedBox(width: 8),
            Text('Diseño del portal WiFi', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            if (_cargandoBorrador) ...[
              const Spacer(),
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)),
            ],
          ]),
          const SizedBox(height: 8),
          Text(
            'Pega el HTML que te generó tu IA y publícalo directo al router. '
            'Tu progreso se guarda automáticamente en este dispositivo.',
            style: GoogleFonts.spaceGrotesk(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copiarPromptParaIA,
                icon: const Icon(Icons.smart_toy_rounded, size: 15, color: Colors.white),
                label: Text('Copiar prompt para IA', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 11.5)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white30),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _usarPlantillaBase,
                icon: const Icon(Icons.article_rounded, size: 15, color: Colors.white),
                label: Text('Usar plantilla base', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 11.5)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white30),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildLogoPicker() {
    return Container(
      decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.border)),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _C.surfaceDim,
            borderRadius: BorderRadius.circular(12),
            image: _logoBytes != null ? DecorationImage(image: MemoryImage(_logoBytes!), fit: BoxFit.cover) : null,
          ),
          child: _logoBytes == null ? const Icon(Icons.image_outlined, color: _C.textSec) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Logo del hotspot', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                _logoBytes != null ? 'Se subirá como logo.png' : 'Se referencia en el HTML como <img src="logo.png">',
                style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10.5),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: _elegirLogo,
          child: Text(_logoBytes == null ? 'Elegir' : 'Cambiar',
              style: GoogleFonts.spaceGrotesk(color: _C.primary, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _buildHtmlEditor() {
    return Container(
      decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.border)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HTML del login', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _htmlController,
            maxLines: 14,
            style: GoogleFonts.sourceCodePro(fontSize: 12, color: _C.textPri),
            decoration: InputDecoration(
              hintText: 'Pega aquí el HTML que te generó la IA…',
              filled: true,
              fillColor: _C.surfaceDim,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonPublicar() {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_C.accent, Color(0xFF059669)]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _publicando ? null : _publicar,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: _publicando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text('Publicar en el router',
                            style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistorial() {
    return Container(
      decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.border)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Historial de versiones', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (_cargandoHistorial)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary)),
          ]),
          const SizedBox(height: 8),
          if (!_cargandoHistorial && _versiones.isEmpty)
            Text('Aún no has publicado ningún diseño.', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
          ..._versiones.map((v) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  decoration: BoxDecoration(color: _C.surfaceDim, borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_fechaCorta(v.fecha),
                              style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 12, fontWeight: FontWeight.w600)),
                          if (v.incluyoLogoNuevo)
                            Text('Incluía logo nuevo', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10.5)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _publicando ? null : () => _revertirA(v),
                      child:
                          Text('Restaurar', style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              )),
        ],
      ),
    );
  }

  String _fechaCorta(DateTime d) {
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)} ${meses[d.month - 1]} ${d.year} · ${p(d.hour)}:${p(d.minute)}';
  }
}
