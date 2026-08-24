import 'dart:async';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/hotspot_ftp_service.dart';
import '../../services/hotspot_design_store.dart';
import '../../services/hotspot_design_firestore.dart';

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

// Plantilla base para la página de status (cuando el cliente ya está conectado).
const String kPlantillaBaseStatus = '''
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <title>Conectado</title>
  <style>
    body { font-family: sans-serif; background:#0F172A; color:#fff; display:flex; align-items:center; justify-content:center; height:100vh; margin:0; }
    .tarjeta { background:#1E293B; padding:32px; border-radius:16px; width:300px; text-align:center; }
    img.logo { width:96px; margin-bottom:16px; }
    .ok { color:#22C55E; font-size:40px; }
    .dato { background:#0F172A; border-radius:8px; padding:10px; margin:8px 0; font-size:13px; }
    .dato b { color:#00C6AE; }
    a { display:block; margin-top:14px; color:#F59E0B; text-decoration:none; font-size:13px; }
  </style>
</head>
<body>
  <div class="tarjeta">
    <img class="logo" src="logo.png" alt="Logo" />
    <div class="ok">✓</div>
    <h2>¡Conectado!</h2>
    <div class="dato">Usuario: <b>\$(username)</b></div>
    <div class="dato">IP: <b>\$(ip)</b></div>
    <div class="dato">Tiempo: <b>\$(uptime)</b></div>
    <div class="dato">Bytes: <b>\$(bytes-in-nice) / \$(bytes-out-nice)</b></div>
    <a href="\$(link-logout)">Desconectar</a>
  </div>
</body>
</html>
''';

// Plantilla base para la página de logout (cuando el cliente se desconecta).
const String kPlantillaBaseLogout = '''
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <title>Desconectado</title>
  <style>
    body { font-family: sans-serif; background:#0F172A; color:#fff; display:flex; align-items:center; justify-content:center; height:100vh; margin:0; }
    .tarjeta { background:#1E293B; padding:32px; border-radius:16px; width:300px; text-align:center; }
    img.logo { width:96px; margin-bottom:16px; }
    .bye { color:#F59E0B; font-size:40px; }
    a { display:block; margin-top:14px; color:#00C6AE; text-decoration:none; font-size:13px; }
  </style>
</head>
<body>
  <div class="tarjeta">
    <img class="logo" src="logo.png" alt="Logo" />
    <div class="bye">👋</div>
    <h2>¡Hasta pronto!</h2>
    <p style="color:#94A3B8; font-size:13px;">Gracias por usar nuestro servicio WiFi.</p>
    <a href="\$(link-login)">Volver a conectar</a>
  </div>
</body>
</html>
''';

// Plantilla base para la página de errores (usuario/clave incorrectos).
const String kPlantillaBaseErrors = '''
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <title>Error</title>
  <style>
    body { font-family: sans-serif; background:#0F172A; color:#fff; display:flex; align-items:center; justify-content:center; height:100vh; margin:0; }
    .tarjeta { background:#1E293B; padding:32px; border-radius:16px; width:300px; text-align:center; }
    img.logo { width:96px; margin-bottom:16px; }
    .err { color:#E53935; font-size:40px; }
    .error { color:#F59E0B; font-size:13px; margin-top:8px; }
    a { display:block; margin-top:14px; color:#00C6AE; text-decoration:none; font-size:13px; }
  </style>
</head>
<body>
  <div class="tarjeta">
    <img class="logo" src="logo.png" alt="Logo" />
    <div class="err">⚠</div>
    <h2>No se pudo conectar</h2>
    <div class="error">\$(error)</div>
    <a href="\$(link-login)">Intentar de nuevo</a>
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
  late HotspotFtpService _ftp;
  final HotspotDesignStore _historial = HotspotDesignStore();

  final TextEditingController _htmlController = TextEditingController();
  final TextEditingController _puertoFtpController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  Uint8List? _logoBytes;
  String? _logoNombre;

  HotspotPagina _paginaActual = HotspotPagina.login;

  bool _publicando = false;
  bool _cargandoHistorial = true;
  bool _cargandoBorrador = true;
  bool _cargandoFirestore = true;
  List<HotspotDesignVersion> _versiones = [];

  // Evita escribir a disco en cada tecla mientras el usuario edita el HTML.
  Timer? _debounceBorrador;
  Timer? _debounceFirestore;

  @override
  void initState() {
    super.initState();
    _puertoFtpController.text = widget.puertoFtp.toString();
    _ftp = HotspotFtpService(
      host: widget.host,
      usuario: widget.usuario,
      clave: widget.clave,
      puerto: widget.puertoFtp,
    );
    _htmlController.addListener(_onHtmlCambiado);
    _puertoFtpController.addListener(_onPuertoFtpCambiado);
    _cargarBorrador();
    _cargarDesdeFirestore();
    _cargarHistorial();
  }

  @override
  void dispose() {
    _debounceBorrador?.cancel();
    _debounceFirestore?.cancel();
    _htmlController.removeListener(_onHtmlCambiado);
    _puertoFtpController.removeListener(_onPuertoFtpCambiado);
    _htmlController.dispose();
    _puertoFtpController.dispose();
    super.dispose();
  }

  // ── Borrador local (persiste aunque se cierre la app) ──

  Future<void> _cargarBorrador() async {
    setState(() => _cargandoBorrador = true);
    try {
      // Cargar el HTML de la página actual desde el borrador por página
      final htmlPagina = await _historial.cargarBorradorPagina(_paginaActual.archivo);
      if (htmlPagina != null) {
        if (!mounted) return;
        setState(() {
          _htmlController.text = htmlPagina;
        });
      } else {
        // Compatibilidad: si no hay borrador por página, usar el borrador general (login)
        final borrador = await _historial.cargarBorrador();
        if (!mounted) return;
        if (borrador != null && _paginaActual == HotspotPagina.login) {
          setState(() {
            _htmlController.text = borrador.html;
            _logoBytes = borrador.logoBytes;
            _logoNombre = borrador.logoNombre;
          });
        }
      }
    } catch (_) {
      // Si falla la carga, simplemente arrancamos en blanco.
    } finally {
      if (mounted) setState(() => _cargandoBorrador = false);
    }
  }

  // ── Carga el HTML guardado en Firestore del usuario autenticado ──

  Future<void> _cargarDesdeFirestore() async {
    setState(() => _cargandoFirestore = true);
    try {
      final htmlPagina = await HotspotDesignFirestore.cargarPagina(_paginaActual);
      if (!mounted) return;
      if (htmlPagina != null && htmlPagina.isNotEmpty) {
        setState(() {
          _htmlController.text = htmlPagina;
        });
      }
      // Cargar el logo (compartido entre todas las páginas)
      final logo = await HotspotDesignFirestore.cargarLogo();
      if (!mounted) return;
      if (logo != null) {
        setState(() {
          _logoBytes = logo['logoBytes'] as Uint8List?;
          _logoNombre = logo['logoNombre'] as String?;
        });
      }
    } catch (_) {
      // Si falla la carga desde Firestore, seguimos con el borrador local.
    } finally {
      if (mounted) setState(() => _cargandoFirestore = false);
    }
  }

  void _onHtmlCambiado() {
    _debounceBorrador?.cancel();
    _debounceBorrador = Timer(const Duration(milliseconds: 600), _guardarBorrador);

    _debounceFirestore?.cancel();
    _debounceFirestore = Timer(const Duration(milliseconds: 1200), _guardarEnFirestore);
  }

  void _onPuertoFtpCambiado() {
    final puerto = int.tryParse(_puertoFtpController.text.trim());
    if (puerto != null && puerto > 0) {
      _ftp = HotspotFtpService(
        host: widget.host,
        usuario: widget.usuario,
        clave: widget.clave,
        puerto: puerto,
      );
    }
  }

  Future<void> _guardarBorrador() async {
    // Guardar el HTML de la página actual en el borrador por página
    await _historial.guardarBorradorPagina(_paginaActual.archivo, _htmlController.text);
    // Compatibilidad: si es login, también guardar en el borrador general
    if (_paginaActual == HotspotPagina.login) {
      await _historial.guardarBorrador(
        html: _htmlController.text,
        logoBytes: _logoBytes,
        logoNombre: _logoNombre,
      );
    }
  }

  Future<void> _guardarEnFirestore() async {
    try {
      await HotspotDesignFirestore.guardar(
        pagina: _paginaActual,
        html: _htmlController.text,
        logoBytes: _logoBytes,
        logoNombre: _logoNombre,
      );
    } catch (_) {
      // Silencioso: si no hay usuario autenticado o falla la red,
      // el borrador local sigue funcionando.
    }
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

  String _plantillaPara(HotspotPagina pagina) {
    switch (pagina) {
      case HotspotPagina.login:
        return kPlantillaBaseHotspot;
      case HotspotPagina.status:
        return kPlantillaBaseStatus;
      case HotspotPagina.logout:
        return kPlantillaBaseLogout;
      case HotspotPagina.errors:
        return kPlantillaBaseErrors;
    }
  }

  void _usarPlantillaBase() {
    _htmlController.text = _plantillaPara(_paginaActual);
    _guardarBorrador();
    _snack('Plantilla base de ${_paginaActual.etiqueta} cargada', _C.primary);
  }

  void _copiarPromptParaIA() {
    final pagina = _paginaActual;
    String prompt;
    if (pagina == HotspotPagina.login) {
      prompt = 'Genera un archivo HTML+CSS (todo en un solo archivo, con <style> interno) '
          'para una página de login de hotspot WiFi de MikroTik. Diseño: [describe aquí lo que quieras]. '
          'Es obligatorio conservar exactamente: el <form name="login" action="\$(link-login-only)" method="post">, '
          'los campos ocultos dst y popup, los inputs name="username" y name="password", el botón submit, '
          'y la variable \$(error) visible en algún punto. El logo debe referenciarse como <img src="logo.png">. '
          'No uses scripts ni fuentes externas que requieran internet.';
    } else if (pagina == HotspotPagina.status) {
      prompt = 'Genera un archivo HTML+CSS (todo en un solo archivo, con <style> interno) '
          'para la página de status de un hotspot WiFi de MikroTik (se muestra cuando el cliente ya está conectado). '
          'Diseño: [describe aquí lo que quieras]. '
          'Es obligatorio conservar las variables del router: \$(username), \$(ip), \$(uptime), \$(bytes-in-nice), '
          '\$(bytes-out-nice) y el enlace \$(link-logout) para desconectar. '
          'El logo debe referenciarse como <img src="logo.png">. No uses scripts ni fuentes externas.';
    } else if (pagina == HotspotPagina.logout) {
      prompt = 'Genera un archivo HTML+CSS (todo en un solo archivo, con <style> interno) '
          'para la página de logout de un hotspot WiFi de MikroTik (se muestra cuando el cliente se desconecta). '
          'Diseño: [describe aquí lo que quieras]. '
          'Debe incluir un enlace \$(link-login) para volver a conectar. '
          'El logo debe referenciarse como <img src="logo.png">. No uses scripts ni fuentes externas.';
    } else {
      prompt = 'Genera un archivo HTML+CSS (todo en un solo archivo, con <style> interno) '
          'para la página de errores de un hotspot WiFi de MikroTik (se muestra cuando el login falla). '
          'Diseño: [describe aquí lo que quieras]. '
          'Es obligatorio conservar la variable \$(error) visible y un enlace \$(link-login) para reintentar. '
          'El logo debe referenciarse como <img src="logo.png">. No uses scripts ni fuentes externas.';
    }
    Clipboard.setData(ClipboardData(text: prompt));
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
    // Solo el login requiere el formulario de usuario/clave.
    if (_paginaActual != HotspotPagina.login) return true;
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
        _paginaActual.archivo: Uint8List.fromList(html.codeUnits),
      };
      if (_logoBytes != null) {
        archivos[_logoNombre ?? 'logo.png'] = _logoBytes!;
      }
      await _ftp.subirArchivos(archivos);

      await _historial.guardar(html: html, incluyoLogoNuevo: _logoBytes != null);
      await _guardarBorrador();
      await _cargarHistorial();

      _snack('${_paginaActual.etiqueta} publicado en el router ✓', _C.success);
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
        nombreArchivo: _paginaActual.archivo,
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

  // ── Vista previa del HTML en un diálogo ──

  void _verVistaPrevia() {
    final html = _htmlController.text.trim();
    if (html.isEmpty) {
      _snack('Escribe o pega el HTML antes de ver la vista previa', _C.warning);
      return;
    }
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _C.dark,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(children: [
                  const Icon(Icons.visibility_rounded, color: _C.accent, size: 18),
                  const SizedBox(width: 8),
                  Text('Vista previa de ${_paginaActual.etiqueta}',
                      style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(dialogContext),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ]),
              ),
              Expanded(
                child: WebViewWidget(
                  controller: WebViewController()
                    ..setJavaScriptMode(JavaScriptMode.unrestricted)
                    ..loadHtmlString(html),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          _buildConfigFtp(),
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
            if (_cargandoBorrador || _cargandoFirestore) ...[
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

  Widget _buildConfigFtp() {
    return Container(
      decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.border)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: _C.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.dns_rounded, color: _C.primary, size: 17),
            ),
            const SizedBox(width: 10),
            Text('Conexión FTP', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _puertoFtpController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              labelText: 'Puerto FTP',
              hintText: '21',
              prefixIcon: const Icon(Icons.settings_ethernet_rounded, color: _C.primary, size: 18),
              filled: true,
              fillColor: _C.surfaceDim,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 6),
          Text('El puerto FTP del router (por defecto 21). Cámbialo si tu MikroTik usa otro.',
              style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10.5)),
        ],
      ),
    );
  }

  Future<void> _cambiarPagina(HotspotPagina nueva) async {
    if (nueva == _paginaActual) return;
    // Guardar el HTML actual antes de cambiar de página
    await _guardarBorrador();
    setState(() {
      _paginaActual = nueva;
      _htmlController.clear();
    });
    // Cargar el HTML de la nueva página
    await _cargarBorrador();
    await _cargarDesdeFirestore();
  }

  // Información de cada página para que el usuario sepa qué pegar ahí.
  ({String descripcion, String variables, String icono}) _infoPagina(HotspotPagina p) {
    switch (p) {
      case HotspotPagina.login:
        return (
          descripcion: 'Es la pantalla de acceso. El cliente ve aquí el formulario para escribir su usuario y clave.',
          variables: 'Debe conservar: form name="login", inputs username y password, y \$(error)',
          icono: '🔑',
        );
      case HotspotPagina.status:
        return (
          descripcion: 'Es la pantalla que ve el cliente cuando YA está conectado. Muestra su IP, tiempo y datos.',
          variables: 'Debe conservar: \$(username), \$(ip), \$(uptime), \$(bytes-in-nice), \$(link-logout)',
          icono: '✅',
        );
      case HotspotPagina.logout:
        return (
          descripcion: 'Es la pantalla que ve el cliente cuando se desconecta. Ideal para despedirlo con tu marca.',
          variables: 'Debe conservar: \$(link-login) para volver a conectar',
          icono: '👋',
        );
      case HotspotPagina.errors:
        return (
          descripcion: 'Es la pantalla que ve el cliente cuando el usuario o la clave son incorrectos.',
          variables: 'Debe conservar: \$(error) y \$(link-login) para reintentar',
          icono: '⚠️',
        );
    }
  }

  Widget _buildHtmlEditor() {
    final info = _infoPagina(_paginaActual);
    return Container(
      decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.border)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector de página
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: _C.surfaceDim, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: HotspotPagina.values.map((p) {
                final seleccionada = p == _paginaActual;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _cambiarPagina(p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: seleccionada ? _C.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: seleccionada
                            ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1))]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          p.etiqueta,
                          style: GoogleFonts.spaceGrotesk(
                            color: seleccionada ? _C.primary : _C.textSec,
                            fontSize: 11.5,
                            fontWeight: seleccionada ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // Tarjeta informativa de la página seleccionada
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _C.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.primary.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(info.icono, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('¿Para qué sirve esta página?',
                        style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(info.descripcion, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 11.5, height: 1.4)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: _C.warning, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(info.variables, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10.5, height: 1.4)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Text('HTML de ${_paginaActual.etiqueta}',
                style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton.icon(
              onPressed: _verVistaPrevia,
              icon: const Icon(Icons.visibility_rounded, size: 15, color: _C.primary),
              label: Text('Vista previa', style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 11.5, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                backgroundColor: _C.primary.withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _htmlController,
            maxLines: 14,
            style: GoogleFonts.sourceCodePro(fontSize: 12, color: _C.textPri),
            decoration: InputDecoration(
              hintText: 'Pega aquí el HTML de ${_paginaActual.etiqueta}…',
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
