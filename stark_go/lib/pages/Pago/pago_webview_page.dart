import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:webview_flutter/webview_flutter.dart';
import '../../plan_model.dart';

import 'pago_exitoso_page.dart';
import 'pago_fallido_page.dart';

class PagoWebViewPage extends StatefulWidget {
  final String url;
  final Plan plan;

  const PagoWebViewPage({super.key, required this.url, required this.plan});

  @override
  State<PagoWebViewPage> createState() => _PagoWebViewPageState();
}

class _PagoWebViewPageState extends State<PagoWebViewPage> {
  late final WebViewController _controller;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _cargando = true),
        onPageFinished: (_) => setState(() => _cargando = false),
        onNavigationRequest: (req) {
          final url = req.url;

          if (url.startsWith('starkgo://pago/exitoso') || (url.contains('mercadopago') && url.contains('status=approved'))) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => PagoExitosoPage(plan: widget.plan),
              ),
            );
            return NavigationDecision.prevent;
          }

          if (url.startsWith('starkgo://pago/fallido') || (url.contains('mercadopago') && url.contains('status=rejected'))) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => PagoFallidoPage(plan: widget.plan),
              ),
            );
            return NavigationDecision.prevent;
          }

          if (url.startsWith('starkgo://pago/pendiente') || (url.contains('mercadopago') && url.contains('status=pending'))) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => PagoFallidoPage(
                  plan: widget.plan,
                  esPendiente: true,
                ),
              ),
            );
            return NavigationDecision.prevent;
          }

          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Completar pago',
          style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w700),
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
      body: WebViewWidget(controller: _controller),
    );
  }
}
