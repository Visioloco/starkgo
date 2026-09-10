import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'package:stark_go/services/vpn_controller.dart';

// ══════════════════════════════════════════════════════════════
//  MikrotikWebViewPage — abre el panel web (WebFig) del MikroTik
//  a través del túnel VPN.
//
//  🔒 Solo funciona con el túnel WireGuard en estado "conectado":
//    - se valida al abrir la página y en tiempo real;
//    - si el túnel se cae mientras se navega, se bloquea la vista.
//
//  La IP del MikroTik se configura en:
//  VPN · Antenas → ⚙️ (Configurar) → "IP del MikroTik (panel web)".
// ══════════════════════════════════════════════════════════════

class MikrotikWebViewPage extends StatefulWidget {
  const MikrotikWebViewPage({
    super.key,
    required this.ip,
    this.usuario,
    this.clave,
  });

  final String ip;

  /// Credenciales del MikroTik (desde config_mikrotik) para copiarlas.
  final String? usuario;
  final String? clave;

  @override
  State<MikrotikWebViewPage> createState() => _MikrotikWebViewPageState();
}

class _MikrotikWebViewPageState extends State<MikrotikWebViewPage> {
  final VpnController _vpn = VpnController.instance;

  WebViewController? _controller;
  bool _cargando = true;
  bool _vpnConectado = false;
  String? _error;
  List<String> _urls = const [];
  int _urlIdx = 0;

  late final StreamSubscription<VpnStatus> _sub;

  @override
  void initState() {
    super.initState();
    _sub = _vpn.statusStream.listen((status) {
      if (!mounted) return;
      final ok = status == VpnStatus.connected;
      if (ok != _vpnConectado) setState(() => _vpnConectado = ok);
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

  /// RouterOS v7 nuevo sirve WebFig en 8085; los antiguos en 80.
  /// Probamos ambos automáticamente.
  List<String> _urlsCandidatas(String ip) {
    final limpio =
        ip.trim().replaceAll(RegExp(r'^https?://'), '').split('/').first;
    if (limpio.isEmpty) return const [];
    if (limpio.contains(':')) return ['http://$limpio'];
    return ['http://$limpio', 'http://$limpio:8085'];
  }

  void _crearWebView() {
    _urls = _urlsCandidatas(widget.ip);
    _urlIdx = 0;
    _cargarUrl();
  }

  void _cargarUrl() {
    if (_urls.isEmpty) {
      setState(() => _error = 'IP del MikroTik inválida');
      return;
    }
    final url = _urls[_urlIdx];
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
            if (!mounted || !_cargando) return;
            if (_urlIdx < _urls.length - 1) {
              _urlIdx++;
              _cargarUrl();
            } else {
              setState(() => _error =
                  'No se pudo cargar el panel de MikroTik (${widget.ip})');
            }
          },
          // MikroTik usa certificado self-signed → aceptamos SOLO IPs privadas.
          onSslAuthError: (SslAuthError error) {
            final androidError = error.platform;
            final esPrivada = androidError is AndroidSslAuthError &&
                (androidError.url.startsWith('https://10.') ||
                    androidError.url.startsWith('https://192.168.'));
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MikroTik',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            Text(
              widget.ip,
              style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 11),
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
          _buildCredencialesBtn(),
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
                  child: const Icon(Icons.vpn_lock_rounded,
                      color: Color(0xFFE53935), size: 34),
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
                  'Para abrir el panel de MikroTik (${widget.ip}) '
                  'el túnel WireGuard debe estar conectado.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                      color: Colors.white54, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
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
                const Icon(Icons.cloud_off_rounded,
                    color: Colors.white54, size: 40),
                const SizedBox(height: 14),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Verificá que el MikroTik esté encendido y que la VPN tenga '
                  'acceso a ${widget.ip}.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                      color: Colors.white54, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _cargando = true;
                      _crearWebView();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24)),
                  icon: const Icon(Icons.refresh_rounded,
                      size: 18, color: Colors.white),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  BOTÓN FLOTANTE — credenciales del MikroTik
  //  Aparece sobre el panel WebFig para copiar usuario/clave
  //  mientras se inicia sesión.
  // ══════════════════════════════════════════════════════════
  bool get _tieneCredenciales =>
      (widget.usuario != null && widget.usuario!.isNotEmpty) ||
      (widget.clave != null && widget.clave!.isNotEmpty);

  Widget _buildCredencialesBtn() {
    if (!_tieneCredenciales) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: GestureDetector(
          onTap: _mostrarCredenciales,
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
            child: const Icon(Icons.vpn_key_rounded,
                color: Color(0xFFF59E0B), size: 24),
          ),
        ),
      ),
    );
  }

  void _mostrarCredenciales() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.vpn_key_rounded,
                    color: Color(0xFFF59E0B), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Credenciales del MikroTik',
                          style: GoogleFonts.dmSans(
                              color: const Color(0xFF0F172A),
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      Text('Usalas para iniciar sesión en WebFig',
                          style: GoogleFonts.dmSans(
                              color: const Color(0xFF64748B), fontSize: 11)),
                    ]),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.close_rounded,
                      color: Color(0xFF64748B), size: 18),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            _CredRow(
                icon: Icons.router_rounded,
                color: const Color(0xFFF59E0B),
                label: 'IP MikroTik',
                value: widget.ip),
            const SizedBox(height: 8),
            _CredRow(
                icon: Icons.person_pin_rounded,
                color: const Color(0xFFF59E0B),
                label: 'Usuario',
                value: widget.usuario ?? '—'),
            const SizedBox(height: 8),
            _CredRow(
                icon: Icons.lock_rounded,
                color: const Color(0xFFF59E0B),
                label: 'Clave',
                value: widget.clave ?? '—'),
            const SizedBox(height: 16),
            Text('Mantené presionado sobre un dato para copiarlo.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                    color: const Color(0xFF64748B), fontSize: 11)),
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

  const _CredRow(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});

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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.dmSans(
                    color: const Color(0xFF64748B),
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value,
                style: GoogleFonts.dmSans(
                    color: const Color(0xFF0F172A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        GestureDetector(
          onTap: () => Clipboard.setData(ClipboardData(text: value)).then((_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('$label copiado',
                    style:
                        GoogleFonts.dmSans(color: Colors.white, fontSize: 13)),
                backgroundColor: const Color(0xFF22C55E),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 1),
              ));
            }
          }),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.copy_rounded, color: color, size: 14),
          ),
        ),
      ]),
    );
  }
}
