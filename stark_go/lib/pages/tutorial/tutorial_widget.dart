import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class _C {
  static const Color primary = Color(0xFF1A73E8);
  static const Color accent = Color(0xFF00C6AE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF1F5F9);
  static const Color textPri = Color(0xFF0F172A);
  static const Color textSec = Color(0xFF64748B);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color danger = Color(0xFFE53935);
}

class TutorialWidget extends StatefulWidget {
  const TutorialWidget({super.key});
  static String routeName = 'Tutorial';
  static String routePath = 'tutorial';

  @override
  State<TutorialWidget> createState() => _TutorialWidgetState();
}

class _TutorialWidgetState extends State<TutorialWidget> {
  bool _loading = true;
  bool _error = false;
  String _errorMsg = '';
  String _titulo = 'Tutorial StarkGo';
  WebViewController? _webController;

  @override
  void initState() {
    super.initState();
    _cargarUrl();
  }

  String? _extractVimeoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('vimeo.com')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
    }
    return null;
  }

  Future<void> _cargarUrl() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('tutorial').limit(1).get();

      if (snap.docs.isEmpty) {
        if (mounted)
          setState(() {
            _loading = false;
            _error = true;
            _errorMsg = 'No hay tutorial configurado aún.';
          });
        return;
      }

      final data = snap.docs.first.data();
      final rawUrl = (data['url'] ?? '').toString().trim();
      final titulo = (data['titulo'] ?? 'Tutorial StarkGo').toString();

      if (rawUrl.isEmpty) {
        if (mounted)
          setState(() {
            _loading = false;
            _error = true;
            _errorMsg = 'La URL del tutorial está vacía.';
          });
        return;
      }

      final vimeoId = _extractVimeoId(rawUrl);
      if (vimeoId == null) {
        if (mounted)
          setState(() {
            _loading = false;
            _error = true;
            _errorMsg = 'URL de Vimeo inválida. Ejemplo: https://vimeo.com/123456789';
          });
        return;
      }

      final embedUrl = 'https://player.vimeo.com/video/$vimeoId?autoplay=0&title=0&byline=0&portrait=0';

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..loadRequest(Uri.parse(embedUrl));

      if (mounted)
        setState(() {
          _titulo = titulo;
          _webController = controller;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = true;
          _errorMsg = 'Error al cargar: $e';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surfaceDim,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── TopBar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _C.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.textPri, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Tutorial', style: TextStyle(color: _C.textPri, fontSize: 20, fontWeight: FontWeight.w800)),
                  Text('Aprende a usar StarkGo', style: TextStyle(color: _C.textSec, fontSize: 12)),
                ]),
              ]),
            ),

            const SizedBox(height: 20),

            if (_loading)
              _buildLoading()
            else if (_error)
              _buildError()
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Column(children: [
                    // ── Video Player ────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          width: double.infinity,
                          height: MediaQuery.of(context).size.width * 9 / 16,
                          child: WebViewWidget(controller: _webController!),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Info card ────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _C.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _C.cardBorder, width: 1.2),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [_C.primary, _C.accent]),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.play_circle_rounded, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_titulo, style: TextStyle(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w700)),
                              Text('Video oficial de uso', style: TextStyle(color: _C.textSec, fontSize: 11)),
                            ])),
                          ]),
                          const SizedBox(height: 12),
                          _TipRow(icon: Icons.fullscreen_rounded, text: 'Toca pantalla completa para mejor experiencia.'),
                          const SizedBox(height: 6),
                          _TipRow(icon: Icons.touch_app_rounded, text: 'Puedes pausar y reanudar en cualquier momento.'),
                          const SizedBox(height: 6),
                          _TipRow(icon: Icons.subtitles_rounded, text: 'Activa subtítulos tocando CC dentro del reproductor.'),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() => Expanded(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: _C.primary, strokeWidth: 2.5),
            const SizedBox(height: 16),
            Text('Cargando tutorial…', style: TextStyle(color: _C.textSec, fontSize: 14)),
          ]),
        ),
      );

  Widget _buildError() => Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: Color(0xFFFEF2F2), shape: BoxShape.circle),
                child: Icon(Icons.play_circle_outline_rounded, size: 52, color: _C.danger),
              ),
              const SizedBox(height: 16),
              Text('Tutorial no disponible',
                  style: TextStyle(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(_errorMsg, style: TextStyle(color: _C.textSec, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => setState(() {
                  _loading = true;
                  _error = false;
                  _cargarUrl();
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_C.primary, _C.accent]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text('Reintentar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      );
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: _C.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 13, color: _C.primary),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: _C.textSec, fontSize: 12, height: 1.4))),
      ]);
}
