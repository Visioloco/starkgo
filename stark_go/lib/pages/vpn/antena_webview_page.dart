import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:stark_go/services/antenas_service.dart';
import 'package:stark_go/services/vpn_controller.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

// ══════════════════════════════════════════════════════════════
//  AntenaWebViewPage — abre la interfaz airOS nativa de una antena.
//
//  🔒 Solo funciona con el túnel VPN en estado "conectado":
//    - el acceso se valida al abrir la página y en tiempo real;
//    - si el túnel se cae mientras se navega, se bloquea la vista.
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

  late final StreamSubscription<VpnStatus> _sub;

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
    final url = widget.antena.urlAirOs;
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
            if (mounted && _cargando) {
              setState(() => _error = 'No se pudo cargar ${widget.antena.ip}');
            }
          },
          // airOS (Ubiquiti) redirige http → https con certificado self-signed.
          // Aceptamos el certificado SOLO para IPs privadas del túnel.
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
              widget.antena.nombre,
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            Text(
              widget.antena.ip,
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
                  'Verificá que la antena esté encendida y que la VPN tenga '
                  'acceso a ${widget.antena.ip}.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12, height: 1.4),
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
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24)),
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

