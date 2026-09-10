import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:stark_go/services/antenas_service.dart';
import 'package:stark_go/services/vpn_controller.dart';
import 'package:stark_go/pages/vpn/router_cliente_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

// ══════════════════════════════════════════════════════════════
//  AntenaWebViewPage — abre la interfaz airOS nativa de una antena.
//
//  🔒 Solo funciona con el túnel VPN en estado "conectado":
//    - el acceso se valida al abrir la página y en tiempo real;
//    - si el túnel se cae mientras se navega, se bloquea la vista.
//
//  🌐 Prueba http:// y, si el equipo no responde en el puerto 80
//    (común en sectoriales/bases con modo seguro), reintenta solo
//    con https:// (certificado autofirmado aceptado para IPs del túnel).
//
//  Estructurado para que en el futuro el body pueda reemplazarse por
//  llamadas a la REST API de RouterOS/airOS (mismo AntenaModel).
// ══════════════════════════════════════════════════════════════

class AntenaWebViewPage extends StatefulWidget {
  const AntenaWebViewPage({super.key, required this.antena});

  final AntenaModel antena;

  @override
  State<AntenaWebViewPage> createState() => _AntenaWebViewPageState();
}

class _AntenaWebViewPageState extends State<AntenaWebViewPage> {
  final VpnController _vpn = VpnController.instance;

  WebViewController? _controller;
  bool _cargando = true;
  bool _vpnConectado = false;
  String? _error;

  /// true cuando el primer intento (http) falló y ya estamos reintentando
  /// (o reintentamos) con https://
  bool _probadoHttps = false;

  late final StreamSubscription<VpnStatus> _sub;

  /// URL según el esquema en uso: primero http y, tras el fallo, https.
  String get _urlInterfaz => '${_probadoHttps ? 'https' : 'http'}://${widget.antena.ip}';

  @override
  void initState() {
    super.initState();
    _sub = _vpn.statusStream.listen((status) {
      if (!mounted) return;
      final ok = status == VpnStatus.connected;
      if (ok != _vpnConectado) {
        setState(() => _vpnConectado = ok);
      }
      // Si el túnel se cae en vivo → bloqueamos la navegación.
      if (!ok && _controller != null) {
        _controller = null;
        setState(() => _cargando = false);
      }
    });
    _validarYcargar();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<void> _validarYcargar() async {
    final status = await _vpn.status();
    if (!mounted) return;
    if (status != VpnStatus.connected) {
      setState(() => _vpnConectado = false);
      return;
    }
    setState(() => _vpnConectado = true);
    _crearWebView();
  }

  void _crearWebView() {
    final url = _urlInterfaz;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _cargando = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _cargando = false);
          },
          onWebResourceError: (_) {
            // Solo reportamos si la página principal no terminó de cargar.
            if (!mounted || !_cargando) return;
            if (!_probadoHttps) {
              // El equipo no respondió en http:// (puerto 80 apagado o
              // caído, típico en sectoriales/bases con modo seguro):
              // reintentamos automáticamente con https:// una sola vez.
              _probadoHttps = true;
              _error = null;
              _crearWebView();
              return;
            }
            setState(() {
              _cargando = false;
              _error = 'No se pudo cargar la interfaz de ${widget.antena.ip} '
                  '(probamos http y https).';
            });
          },
          // airOS (Ubiquiti) redirige http → https con certificado self-signed.
          // Aceptamos el certificado SOLO para IPs privadas del túnel.
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
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    // Guard: VPN no conectado → pantalla de bloqueo.
    if (!_vpnConectado) return _buildBloqueado();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.antena.esSectorial
                      ? const [Color(0xFF7C3AED), Color(0xFF4F46E5)]
                      : const [Color(0xFF1A73E8), Color(0xFF00C6AE)],
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                widget.antena.esSectorial ? Icons.cell_tower_rounded : Icons.settings_input_antenna_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.antena.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '${widget.antena.ip}  ·  ${widget.antena.esSectorial ? 'Sectorial' : 'Cliente'}',
                    style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: _cargando
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF1A73E8)),
                ),
              )
            : null,
      ),
      body: Stack(
        children: [
          if (_controller != null) WebViewWidget(controller: _controller!),
          if (_controller == null && _cargando)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A73E8)),
            ),
          if (_error != null) _buildErrorOverlay(),
          _buildFloatingBtns(),
        ],
      ),
    );
  }

  Widget _buildBloqueado() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.vpn_lock_rounded, color: Color(0xFFE53935), size: 34),
                ),
                const SizedBox(height: 20),
                Text(
                  'VPN desconectado',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Para abrir la interfaz de ${widget.antena.nombre} '
                  'el túnel WireGuard debe estar conectado.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  ),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _reintentar() {
    setState(() {
      _error = null;
      _cargando = true;
      _crearWebView();
    });
  }

  /// Abre la interfaz en el navegador del sistema (fuera del WebView),
  /// útil para probar si el equipo responde o si es un problema del WebView.
  Future<void> _abrirEnNavegador() async {
    final uri = Uri.parse(_urlInterfaz);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildErrorOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF0F172A).withOpacity(0.96),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, color: Colors.white54, size: 40),
                const SizedBox(height: 14),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ya probamos http y https. Verificá que el equipo esté '
                  'encendido, que ${widget.antena.ip} sea su IP real y que '
                  'la VPN tenga acceso a esa subred.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _reintentar,
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24)),
                      icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                      label: const Text('Reintentar'),
                    ),
                    FilledButton.icon(
                      onPressed: _abrirEnNavegador,
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00C6AE)),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF0F172A)),
                      label: const Text('Abrir en navegador', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700)),
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

  // ══════════════════════════════════════════════════════════
  //  BOTONES FLOTANTES sobre el panel web
  //   · Router del cliente → guía + acceso al router (port forwarding)
  //   · Credenciales airOS → copiar usuario/clave para el login
  // ══════════════════════════════════════════════════════════
  bool get _tieneCredenciales =>
      (widget.antena.usuarioAtn != null && widget.antena.usuarioAtn!.isNotEmpty) ||
      (widget.antena.claveAtn != null && widget.antena.claveAtn!.isNotEmpty);

  Widget _buildFloatingBtns() {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Guía + acceso al router del cliente (port forwarding airOS).
            _fab(
              icon: Icons.router_rounded,
              color: const Color(0xFF7C3AED),
              onTap: _abrirRouterCliente,
            ),
            if (_tieneCredenciales) ...[
              const SizedBox(height: 12),
              // Credenciales airOS (copiar usuario/clave).
              _fab(
                icon: Icons.vpn_key_rounded,
                color: const Color(0xFF00C6AE),
                onTap: _mostrarCredenciales,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fab({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  void _abrirRouterCliente() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RouterClientePage(antena: widget.antena),
    ));
  }

  void _mostrarCredenciales() {
    final a = widget.antena;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: const Color(0xFF00C6AE).withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.vpn_key_rounded, color: Color(0xFF00C6AE), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Credenciales de la antena',
                      style: GoogleFonts.dmSans(color: const Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w800)),
                  Text('Usalas para iniciar sesión en airOS', style: GoogleFonts.dmSans(color: const Color(0xFF64748B), fontSize: 11)),
                ]),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 18),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            _CredRow(icon: Icons.router_rounded, color: const Color(0xFF00C6AE), label: 'IP Antena', value: a.ip),
            const SizedBox(height: 8),
            _CredRow(icon: Icons.person_pin_rounded, color: const Color(0xFF00C6AE), label: 'Usuario', value: a.usuarioAtn ?? '—'),
            const SizedBox(height: 8),
            _CredRow(icon: Icons.lock_rounded, color: const Color(0xFF00C6AE), label: 'Clave', value: a.claveAtn ?? '—'),
            const SizedBox(height: 16),
            Text('Mantené presionado sobre un dato para copiarlo.',
                textAlign: TextAlign.center, style: GoogleFonts.dmSans(color: const Color(0xFF64748B), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Fila de credencial copiable (con botón de copiar)
// ══════════════════════════════════════════════════════════
class _CredRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _CredRow({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.dmSans(color: const Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.dmSans(color: const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
        GestureDetector(
          onTap: () => Clipboard.setData(ClipboardData(text: value)).then((_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('$label copiado', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13)),
                backgroundColor: const Color(0xFF22C55E),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 1),
              ));
            }
          }),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.copy_rounded, color: color, size: 14),
          ),
        ),
      ]),
    );
  }
}
