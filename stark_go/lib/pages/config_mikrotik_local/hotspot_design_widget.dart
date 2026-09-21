import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/hotspot_ftp_service.dart';
import '../../services/hotspot_design_store.dart';
import '../../services/hotspot_design_firestore.dart';
import '../../services/portal_vps_service.dart';
import '../../widgets/sin_soporte_web.dart';

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

const String kPromptIaPortal = '''
Genera el HTML de UNA SOLA página (autocontenida, sin dependencias externas) para mostrar a un cliente de internet cuyo servicio está SUSPENDIDO por falta de pago (portal de mora). NO es un login de hotspot: NO incluyas formulario de usuario ni clave. Se verá en el celular del cliente.

Requisitos:
1. HTML5 con todo el CSS dentro del mismo archivo (tag <style> o estilos en línea). No uses fuentes ni scripts externos ni imágenes de internet: el cliente no tiene navegación.
2. Usa EXACTAMENTE estos marcadores y NO los reemplaces por valores fijos:
   {{nombre}} -> nombre del cliente (para saludarlo)
   {{saldo}}  -> valor a pagar (debe quedar MUY destacado)
   {{plan}}   -> plan contratado
   {{ip}}     -> IP del cliente (opcional, en texto pequeño)
   {{fecha}}  -> fecha actual (en el pie de página)
3. Estructura sugerida:
   - Encabezado: logo opcional <img src="logo.png"> y nombre de la empresa [NOMBRE EMPRESA].
   - Aviso grande y claro: "Hola {{nombre}}, tu servicio está suspendido".
   - Motivo: falta de pago del plan.
   - Caja destacada con el monto: "Valor a pagar: {{saldo}}" y debajo "Plan: {{plan}}".
   - Pasos para pagar (1. Realiza el pago, 2. Envía el comprobante por WhatsApp) con un botón grande de WhatsApp con el enlace: https://wa.me/57[WHATSAPP SOPORTE]?text=Hola,%20ya%20realic%C3%A9%20el%20pago%20de%20mi%20servicio
   - Pie: "Si ya realizaste el pago, tu servicio se reactiva en pocos minutos." y {{fecha}}.
4. Estilo con colores de marca [COLOR PRINCIPAL, ej. #1A73E8] y [COLOR SECUNDARIO, ej. #00C6AE], tipografía legible y botones grandes para móvil.
5. NO uses variables de MikroTik del tipo \$(...). Solo los marcadores {{...}} de arriba.

Entrega únicamente el código HTML completo dentro de un bloque ```html ... ```.
''';

class HotspotDesignWidget extends StatefulWidget {
  final String host;
  final String usuario;
  final String clave;
  final int puertoFtp;

  /// true = modo remoto (portal de pago en el VPS): oculta la conexión FTP
  /// local y el botón "Publicar en el router"; solo publica en el portal VPS.
  final bool soloPortalVps;

  const HotspotDesignWidget({
    Key? key,
    required this.host,
    required this.usuario,
    required this.clave,
    this.puertoFtp = 21,
    this.soloPortalVps = false,
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
  bool _publicandoPortal = false;
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
      final logoReducido = await _redimensionarLogo(bytes);
      setState(() {
        _logoBytes = logoReducido;
        _logoNombre = 'logo.png';
      });
      await _guardarBorrador();
    } catch (e) {
      _snack('No se pudo cargar la imagen: $e', _C.danger);
    }
  }

  /// Reduce el logo a un tamaño razonable y lo convierte a PNG. Así el HTML
  /// del portal VPS (con el logo incrustado) no supera el límite del servidor.
  Future<Uint8List> _redimensionarLogo(Uint8List bytes, {int maxLado = 256}) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final ancho = img.width;
      final alto = img.height;
      final mayor = ancho > alto ? ancho : alto;
      final escala = mayor > maxLado ? maxLado / mayor : 1.0;
      final nAncho = (ancho * escala).round().clamp(1, maxLado).toInt();
      final nAlto = (alto * escala).round().clamp(1, maxLado).toInt();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, ancho.toDouble(), alto.toDouble()),
        Rect.fromLTWH(0, 0, nAncho.toDouble(), nAlto.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final resized = await picture.toImage(nAncho, nAlto);
      final data = await resized.toByteData(format: ui.ImageByteFormat.png);
      resized.dispose();
      img.dispose();
      return data?.buffer.asUint8List() ?? bytes;
    } catch (_) {
      return bytes;
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
    if (widget.soloPortalVps) {
      _snack('Modo remoto: usá "Publicar en portal VPS"', _C.warning);
      return;
    }
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
      builder: (_) => _PreviewDialog(
        titulo: 'Vista previa de ${_paginaActual.etiqueta}',
        html: html,
      ),
    );
  }

  // ── Publicar la página actual en el portal del VPS (remoto) ──
  Future<void> _publicarPortalVps() async {
    final html = _htmlController.text.trim();
    if (html.isEmpty) {
      _snack('Pega o escribe el HTML antes de publicar en el portal', _C.warning);
      return;
    }
    setState(() => _publicandoPortal = true);
    try {
      String htmlPublicar = html;
      if (_logoBytes != null) {
        // En el portal VPS no existe logo.png del router: el logo se incrusta
        // como data URI. Si el guardado es pesado (de antes), se reduce aquí.
        final logo = _logoBytes!.length > 250000 ? await _redimensionarLogo(_logoBytes!) : _logoBytes!;
        htmlPublicar = _incrustarLogoEnHtml(html, logo, _logoNombre);
      }

      final ok = await PortalVpsService.publicarPagina(
        archivo: _paginaActual.archivo,
        html: htmlPublicar,
      );
      if (!ok) {
        _snack(
            'No se pudo publicar en el portal del VPS. Si elegiste logo, '
            'probá con una imagen PNG más liviana o más pequeña.',
            _C.danger);
        return;
      }
      await _guardarBorrador();
      _snack('${_paginaActual.etiqueta} publicado en el portal (VPS) ✓', _C.success);
      // Abre la vista previa REAL, tal como la sirve el VPS.
      final url = await PortalVpsService.urlPortal(_paginaActual.archivo);
      if (url != null && mounted) {
        _verPreviewUrl(url, 'Portal publicado · ${_paginaActual.etiqueta}');
      }
    } catch (e) {
      _snack('Error al publicar en el portal: $e', _C.danger);
    } finally {
      if (mounted) setState(() => _publicandoPortal = false);
    }
  }

  /// Incrusta el logo como data URI dentro del HTML (portal VPS).
  String _incrustarLogoEnHtml(String html, Uint8List bytes, String? nombre) {
    final ext = (nombre ?? 'logo.png').split('.').last.toLowerCase();
    final mime = ext == 'jpg' || ext == 'jpeg'
        ? 'image/jpeg'
        : ext == 'gif'
            ? 'image/gif'
            : ext == 'webp'
                ? 'image/webp'
                : 'image/png';
    final uri = 'data:$mime;base64,${base64Encode(bytes)}';
    final re = RegExp("src=([\"'])logo\\.[a-zA-Z0-9]+\\1");
    var out = html.replaceAllMapped(re, (m) => 'src=${m[1]}$uri${m[1]}');
    if (!re.hasMatch(html)) {
      final div = '<div style="text-align:center;margin:10px auto;">'
          '<img src="$uri" alt="Logo" '
          'style="max-width:180px;max-height:80px;object-fit:contain;"></div>';
      final nuevo = html.replaceFirstMapped(
        RegExp(r'<body[^>]*>', caseSensitive: false),
        (m) => '${m[0]}$div',
      );
      out = nuevo == html ? '$div$html' : nuevo;
    }
    return out;
  }

  /// Abre en un diálogo la página YA publicada en el VPS (ver cómo queda).
  void _verPortalPublicado() async {
    final url = await PortalVpsService.urlPortal(_paginaActual.archivo);
    if (url == null) {
      _snack('Falta vpsApiKey (Configuración → MikroTik)', _C.warning);
      return;
    }
    _verPreviewUrl(url, 'Portal publicado · ${_paginaActual.etiqueta}');
  }

  void _verPreviewUrl(String url, String titulo) {
    showDialog(
      context: context,
      builder: (_) => _PreviewDialog(
        titulo: titulo,
        url: url,
        // El "Código" muestra el HTML publicado en el VPS (tal cual se guardó).
        cargarCodigo: () => PortalVpsService.obtenerPaginaPublicada(_paginaActual.archivo),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // ── WEB: el editor del portal usa archivos/FTP del teléfono ──
    if (kIsWeb) {
      return const SinSoporteWebInline(
        titulo: 'Editor del portal',
        detalle: 'El editor del portal cautivo (subir login.html por FTP y '
            'guardar borradores en el equipo) sólo está disponible desde la app '
            'del teléfono.',
      );
    }
    return Container(
      color: _C.surfaceDim,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildIntro(),
          const SizedBox(height: 16),
          if (widget.soloPortalVps) ...[
            _buildBannerVpsRemoto(),
            const SizedBox(height: 16),
          ],
          _buildLogoPicker(),
          const SizedBox(height: 16),
          if (!widget.soloPortalVps) ...[
            _buildConfigFtp(),
            const SizedBox(height: 16),
          ],
          _buildHtmlEditor(),
          const SizedBox(height: 16),
          if (!widget.soloPortalVps) ...[
            _buildBotonPublicar(),
            const SizedBox(height: 16),
          ],
          _buildPortalRemotoCard(),
          const SizedBox(height: 20),
          _buildHistorial(),
        ],
      ),
    );
  }

  void _copiarPromptIa() {
    Clipboard.setData(const ClipboardData(text: kPromptIaPortal));
    _snack('Prompt copiado. Pégalo en tu IA y luego pega el HTML aquí.', _C.success);
  }

  Widget _buildBannerVpsRemoto() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration:
                  BoxDecoration(gradient: const LinearGradient(colors: [_C.primary, _C.accent]), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.lock_clock_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estás editando la página que verá el cliente cuando su servicio '
                    'esté suspendido (portal de pago). Se publica en el VPS, sin '
                    'tocar el hotspot de fichas.',
                    style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 11.5, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Datos automáticos: {{nombre}} · {{saldo}} (valor del plan) · '
                    '{{plan}} · {{ip}} · {{fecha}}',
                    style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 10.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ]),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _copiarPromptIa,
              icon: const Icon(Icons.copy_rounded, size: 15),
              label: Text('Copiar prompt para la IA', style: GoogleFonts.spaceGrotesk(fontSize: 11.5, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(foregroundColor: _C.primary),
            ),
          ),
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
                _logoBytes != null
                    ? (widget.soloPortalVps ? 'Se incrustará en la página al publicar en el VPS' : 'Se subirá como logo.png')
                    : (widget.soloPortalVps
                        ? 'Se incrustará al publicar (usa <img src="logo.png"> en tu HTML)'
                        : 'Se referencia en el HTML como <img src="logo.png">'),
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

  Widget _buildPortalRemotoCard() {
    return Container(
      decoration: BoxDecoration(
        color: _C.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.primary.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration:
                  BoxDecoration(gradient: const LinearGradient(colors: [_C.primary, _C.accent]), borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.language_rounded, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Portal de pago (VPS)', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w700)),
                Text(
                    'Publica esta página en el VPS: la editas y la ves desde cualquier '
                    'lugar (sin FTP local) y el hotspot puede redirigir al moroso aquí.',
                    style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10.5, height: 1.35)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _publicandoPortal ? null : _publicarPortalVps,
                icon: _publicandoPortal
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_upload_rounded, size: 17),
                label: Text(_publicandoPortal ? 'Publicando…' : 'Publicar en portal VPS',
                    style: GoogleFonts.spaceGrotesk(fontSize: 11.5, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.primary,
                  side: BorderSide(color: _C.primary.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _verPortalPublicado,
                icon: const Icon(Icons.open_in_browser_rounded, size: 17),
                label: Text('Ver publicado', style: GoogleFonts.spaceGrotesk(fontSize: 11.5, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.primary,
                  side: BorderSide(color: _C.primary.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                ),
              ),
            ),
          ]),
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

// ═════════════════════════════════════════════════════════════════════════
//  Diálogo de vista previa del portal: pestañas "Visual" y "Código HTML".
//   · Visual → WebView (HTML local o URL publicada en el VPS).
//   · Código → el HTML del editor o el publicado (se descarga con cargarCodigo).
// ═════════════════════════════════════════════════════════════════════════
class _PreviewDialog extends StatefulWidget {
  final String titulo;

  /// HTML local (vista previa del editor). Se usa si no hay [url].
  final String? html;

  /// URL publicada en el VPS; se carga en el WebView.
  final String? url;

  /// Carga diferida del HTML publicado (pestaña "Código").
  /// Si es null, el código mostrado es [html].
  final Future<String?> Function()? cargarCodigo;

  const _PreviewDialog({
    required this.titulo,
    this.html,
    this.url,
    this.cargarCodigo,
  });

  @override
  State<_PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<_PreviewDialog> {
  late final WebViewController _web;
  bool _verCodigo = false;
  bool _cargandoCodigo = false;
  bool _codigoListo = false;
  String? _codigo;
  String? _error;

  bool get _esPublicado => widget.cargarCodigo != null;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white);
    if (widget.url != null) {
      _web.loadRequest(Uri.parse(widget.url!));
    } else {
      _web.loadHtmlString(widget.html ?? '');
    }
  }

  Future<void> _abrirCodigo() async {
    setState(() => _verCodigo = true);
    if (_codigoListo || _cargandoCodigo) return;

    if (widget.cargarCodigo == null) {
      setState(() {
        _codigo = widget.html ?? '';
        _codigoListo = true;
      });
      return;
    }

    setState(() => _cargandoCodigo = true);
    try {
      final html = await widget.cargarCodigo!();
      if (!mounted) return;
      setState(() {
        _codigo = html;
        _error = html == null ? 'No se pudo obtener el HTML publicado.' : null;
        _codigoListo = true;
        _cargandoCodigo = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al leer el HTML: $e';
        _codigoListo = true;
        _cargandoCodigo = false;
      });
    }
  }

  void _copiarCodigo() {
    final texto = _codigo ?? widget.html ?? '';
    if (texto.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Código HTML copiado al portapapeles'),
      duration: Duration(milliseconds: 1400),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _C.dark,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              Icon(_verCodigo ? Icons.code_rounded : Icons.visibility_rounded, color: _C.accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              if (_verCodigo) ...[
                _btnHeader(Icons.copy_rounded, 'Copiar', _copiarCodigo),
                const SizedBox(width: 6),
              ],
              _segmento('Visual', !_verCodigo, () => setState(() => _verCodigo = false)),
              const SizedBox(width: 6),
              _segmento('Código', _verCodigo, _abrirCodigo),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                ),
              ),
            ]),
          ),
          Expanded(
            child: _verCodigo ? _buildCodigo() : WebViewWidget(controller: _web),
          ),
        ]),
      ),
    );
  }

  Widget _segmento(String label, bool sel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? _C.accent : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: GoogleFonts.spaceGrotesk(color: sel ? _C.dark : Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _btnHeader(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _buildCodigo() {
    if (_cargandoCodigo) {
      return const Center(child: CircularProgressIndicator(color: _C.primary, strokeWidth: 2.5));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, color: _C.danger, size: 36),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13)),
          ]),
        ),
      );
    }
    final texto = (_codigo ?? '').trimRight();
    final lineas = texto.isEmpty ? 0 : texto.split('\n').length;
    final titulo = _esPublicado ? 'HTML publicado' : 'HTML del editor';
    return Container(
      color: const Color(0xFF0B1220),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: const Color(0xFF111C31),
          child: Row(children: [
            const Icon(Icons.code_rounded, color: _C.accent, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text('$titulo · $lineas líneas',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.spaceGrotesk(color: Colors.white70, fontSize: 11)),
            ),
            GestureDetector(
              onTap: _copiarCodigo,
              child: Text('Copiar', style: GoogleFonts.spaceGrotesk(color: _C.accent, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: SelectableText(
                texto.isEmpty ? '(sin contenido)' : texto,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontFamilyFallback: ['Courier', 'Courier New'],
                  color: Color(0xFFE2E8F0),
                  fontSize: 11.5,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
