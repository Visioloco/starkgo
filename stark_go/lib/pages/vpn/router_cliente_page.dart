import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'package:stark_go/services/antenas_service.dart';

// ══════════════════════════════════════════════════════════════
//  RouterClientePage — Guía paso a paso + acceso al router del
//  cliente a través de la antena (port forwarding de airOS).
//
//  · Muestra la guía para configurar el Port Forwarding en la
//    antena Ubiquiti (airOS en modo Router).
//  · Permite escribir la IP de la antena y el puerto público
//    (ej. 8080) y abre http://IP:PUERTO en un WebView para entrar
//    al router del cliente y cambiar la clave del Wi-Fi.
//
//  La navegación funciona con el túnel WireGuard conectado.
// ══════════════════════════════════════════════════════════════

class RouterClientePage extends StatefulWidget {
  const RouterClientePage({super.key, required this.antena});

  final AntenaModel antena;

  @override
  State<RouterClientePage> createState() => _RouterClientePageState();
}

class _RouterClientePageState extends State<RouterClientePage> {
  // ─── Paleta (misma del módulo MikroTik/VPN) ────────────────────
  static const Color _primary = Color(0xFF1A73E8);
  static const Color _accent = Color(0xFF00C6AE);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _danger = Color(0xFFE53935);
  static const Color _success = Color(0xFF22C55E);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _surfaceDim = Color(0xFFF1F5F9);
  static const Color _textPri = Color(0xFF0F172A);
  static const Color _textSec = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  late final TextEditingController _ipCtrl;
  late final TextEditingController _portCtrl;

  WebViewController? _web;
  bool _probadoHttps = false;
  bool _cargando = false;
  String? _error;
  String? _urlActiva;

  /// Pasos de la guía (configuración manual del Port Forwarding en airOS).
  static const List<String> _pasos = [
    'Entra a la antena Ubiquiti (airOS) en modo Router: abre su IP en el navegador y entra con tu usuario y clave de administración.',
    'Revisa las dos redes: la LAN de la antena (airOS usa 192.168.1.1 por defecto) y la LAN del router del cliente (ej. 192.168.0.1). Deben ser subredes DISTINTAS; si coinciden, cambia una de las dos para que no choquen.',
    'Confirma que el router del cliente está conectado al puerto LAN de la antena y que esta le asignó una IP en su red (la WAN del router, ej. 192.168.1.2). Esa IP WAN es el destino del Port Forwarding: la 192.168.0.1 de su LAN está detrás de su NAT y no se alcanza desde la antena.',
    'En el router del cliente activa el Control remoto / Administración remota desde WAN (Remote Management) y deja su puerto de administración en 8080. Sin esto el router rechaza la conexión que llega desde la antena.',
    'En airOS ve a Network → Port Forwarding y marca la casilla Enable Port Forwarding.',
    'Crea la regla con Configure o Add: Interface = WAN · Private IP = IP WAN del router del cliente (ej. 192.168.1.2) · Private Port = 8080 (el puerto de administración remota del router) · Type = TCP · Source IP/Mask = 0.0.0.0/0 · Public Port = 8080.',
    'Guarda con OK o Add, presiona el botón Change (abajo a la derecha) y finalmente Apply en la barra azul superior para aplicar los cambios.',
    'Verifica: desde tu red abre en el navegador http://IP_DE_LA_ANTENA:8080 (ej. http://10.10.20.50:8080) y debe cargar la pantalla de inicio de sesión del router del cliente. Si no carga, prueba con la IP WAN de la antena.',
    'Entra al router del cliente y cambia la clave del Wi-Fi en la sección Wireless / WLAN.',
    'Importante: el puerto de administración web de la antena (airOS) NO debe ser 8080, y las LAN de la antena y del router no deben repetirse, para evitar conflictos.',
  ];

  @override
  void initState() {
    super.initState();
    _ipCtrl = TextEditingController(text: widget.antena.ip);
    _portCtrl = TextEditingController(text: '8080');
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  String get _host => _ipCtrl.text.trim();

  String get _puerto => _portCtrl.text.trim();

  String? _validar() {
    if (_host.isEmpty) return 'Escribe la IP de la antena.';
    if (_puerto.isEmpty) return 'Escribe el puerto público (ej. 8080).';
    final p = int.tryParse(_puerto);
    if (p == null || p < 1 || p > 65535) {
      return 'El puerto debe estar entre 1 y 65535.';
    }
    return null;
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  /// Abre el router del cliente en http://IP:PUERTO
  void _ingresar() {
    final err = _validar();
    if (err != null) {
      _snack(err, _danger);
      return;
    }
    final url = 'http://$_host:$_puerto';
    setState(() {
      _probadoHttps = false;
      _error = null;
      _cargando = true;
      _urlActiva = url;
      _web = _crearController(url);
    });
  }

  WebViewController _crearController(String url) {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _cargando = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _cargando = false);
        },
        onWebResourceError: (_) {
          // Si no cargó por http, reintentamos una vez con https
          // (algunos routers con administración web en 443).
          if (!_probadoHttps) {
            _probadoHttps = true;
            final httpsUrl = 'https://$_host:$_puerto';
            setState(() {
              _error = null;
              _urlActiva = httpsUrl;
              _web = _crearController(httpsUrl);
            });
            return;
          }
          if (mounted) {
            setState(() {
              _cargando = false;
              _error = 'No se pudo abrir $_host:$_puerto (probamos http y '
                  'https). Verifica el Port Forwarding y que la VPN esté '
                  'conectada.';
            });
          }
        },
        // Aceptamos el certificado self-signed SOLO para IPs privadas.
        onSslAuthError: (SslAuthError error) {
          final androidError = error.platform;
          final esPrivada = androidError is AndroidSslAuthError &&
              (androidError.url.startsWith('https://10.') || androidError.url.startsWith('https://192.168.'));
          if (esPrivada) {
            error.proceed();
          } else {
            error.cancel();
          }
        },
      ))
      ..loadRequest(Uri.parse(url));
  }

  void _volverAGuia() {
    setState(() {
      _web = null;
      _error = null;
      _cargando = false;
      _urlActiva = null;
    });
  }

  Future<void> _copiarGuia() async {
    final url = 'http://${_host.isEmpty ? widget.antena.ip : _host}:'
        '${_puerto.isEmpty ? '8080' : _puerto}';
    final texto = StringBuffer()
      ..writeln('Acceso al router del cliente (port forwarding airOS)')
      ..writeln('');
    for (var i = 0; i < _pasos.length; i++) {
      texto.writeln('${i + 1}. ${_pasos[i]}');
      texto.writeln('');
    }
    texto.writeln('URL para entrar al router: $url');
    await Clipboard.setData(ClipboardData(text: texto.toString()));
    if (mounted) _snack('Guía copiada al portapapeles', _success);
  }

  Future<void> _copiarUrl() async {
    final err = _validar();
    if (err != null) {
      _snack(err, _danger);
      return;
    }
    await Clipboard.setData(ClipboardData(text: 'http://$_host:$_puerto'));
    if (mounted) _snack('URL copiada: http://$_host:$_puerto', _success);
  }

  // ══════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final mostrandoWeb = _web != null || _error != null;
    return Scaffold(
      backgroundColor: _dark,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mostrandoWeb ? 'Router del cliente' : 'Acceso al router',
                style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            Text(mostrandoWeb ? (_urlActiva ?? '') : '${widget.antena.nombre} · ${widget.antena.ip}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 11)),
          ],
        ),
        actions: [
          if (mostrandoWeb)
            IconButton(
              tooltip: 'Ver guía',
              icon: const Icon(Icons.menu_book_rounded, color: Colors.white),
              onPressed: _volverAGuia,
            ),
        ],
        bottom: _cargando
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(Color(0xFF1A73E8)),
                ),
              )
            : null,
      ),
      body: mostrandoWeb ? _buildWeb() : _buildForm(),
    );
  }

  Widget _buildWeb() {
    return Stack(
      children: [
        if (_web != null) WebViewWidget(controller: _web!),
        if (_web == null && _cargando) const Center(child: CircularProgressIndicator(color: _primary)),
        if (_error != null) _buildError(),
      ],
    );
  }

  Widget _buildError() {
    return Positioned.fill(
      child: Container(
        color: _dark.withOpacity(0.96),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: _danger.withOpacity(0.12), borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.wifi_tethering_error_rounded, color: _danger, size: 30),
                ),
                const SizedBox(height: 16),
                Text('No se pudo abrir el router',
                    textAlign: TextAlign.center, style: GoogleFonts.dmSans(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(_error ?? '',
                    textAlign: TextAlign.center, style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12.5, height: 1.4)),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _ingresar,
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24)),
                      icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                      label: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                    ),
                    FilledButton.icon(
                      onPressed: _volverAGuia,
                      style: FilledButton.styleFrom(backgroundColor: _accent),
                      icon: const Icon(Icons.menu_book_rounded, size: 18, color: _dark),
                      label: const Text('Ver guía', style: TextStyle(color: _dark, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIntro(),
          const SizedBox(height: 14),
          _buildGuia(),
          const SizedBox(height: 16),
          _buildDatosConexion(),
          const SizedBox(height: 16),
          _btnIngresar(),
          const SizedBox(height: 10),
          _btnCopiarUrl(),
          const SizedBox(height: 16),
          _buildNota(),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_dark, Color(0xFF1E293B)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_purple, Color(0xFF4F46E5)]),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.router_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Acceso remoto al router del cliente',
                    style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                    'Configura el Port Forwarding en la antena y entra al '
                    'router por la VPN.',
                    style: GoogleFonts.dmSans(color: Colors.white60, fontSize: 11.5, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuia() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: _purple.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.menu_book_rounded, color: _purple, size: 16),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text('Guía paso a paso', style: GoogleFonts.dmSans(color: _textPri, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              GestureDetector(
                onTap: _copiarGuia,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.copy_rounded, size: 13, color: _primary),
                  const SizedBox(width: 3),
                  Text('Copiar', style: GoogleFonts.dmSans(color: _primary, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(_pasos.length, (i) => _paso(i + 1, _pasos[i])),
        ],
      ),
    );
  }

  Widget _paso(int n, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: _primary.withOpacity(0.1), shape: BoxShape.circle),
            child: Center(
              child: Text('$n', style: GoogleFonts.dmSans(color: _primary, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto, style: GoogleFonts.dmSans(color: _textSec, fontSize: 12.5, height: 1.45)),
          ),
        ],
      ),
    );
  }

  Widget _buildDatosConexion() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: _accent.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.link_rounded, color: _accent, size: 16),
            ),
            const SizedBox(width: 9),
            Text('Entrar al router', style: GoogleFonts.dmSans(color: _textPri, fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          _campo(
            ctrl: _ipCtrl,
            label: 'IP de la antena',
            hint: 'ej. 10.10.15.10',
            icon: Icons.settings_input_antenna_rounded,
          ),
          const SizedBox(height: 10),
          _campo(
            ctrl: _portCtrl,
            label: 'Puerto público',
            hint: 'ej. 8080',
            icon: Icons.numbers_rounded,
            keyboard: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _campo({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      inputFormatters: keyboard == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : null,
      style: GoogleFonts.dmSans(color: _textPri, fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: _textSec),
        filled: true,
        fillColor: _surfaceDim,
        labelStyle: GoogleFonts.dmSans(color: _textSec, fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
        focusedBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary, width: 1.6)),
      ),
    );
  }

  Widget _btnIngresar() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _ingresar,
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.login_rounded, color: Colors.white, size: 18),
        label: Text('Ingresar al router', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _btnCopiarUrl() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _copiarUrl,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.white.withOpacity(0.08),
          side: const BorderSide(color: Colors.white30, width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.link_rounded, size: 17, color: Colors.white),
        label: Text('Copiar URL', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildNota() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'El acceso funciona con el túnel VPN conectado. Si no carga, '
              'revisa que la regla de Port Forwarding esté habilitada en la '
              'antena, que el router del cliente tenga activado el control '
              'remoto y que su puerto de administración coincida con el '
              'Private Port que pusiste.',
              style: GoogleFonts.dmSans(color: const Color(0xFF92400E), fontSize: 11.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
