import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:stark_go/services/vps_service.dart';

// ══════════════════════════════════════════════════════════════
//  GuiaVpnPage — guía paso a paso de la configuración manual
//  (VPS + MikroTik + antenas). Lo que ya es automático se marca aparte.
// ══════════════════════════════════════════════════════════════

class _C {
  static const Color primary = Color(0xFF1A73E8);
  static const Color accent = Color(0xFF00C6AE);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color dark = Color(0xFF0F172A);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF1F5F9);
  static const Color textPri = Color(0xFF0F172A);
  static const Color textSec = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
}

class GuiaVpnPage extends StatefulWidget {
  const GuiaVpnPage({super.key});

  @override
  State<GuiaVpnPage> createState() => _GuiaVpnPageState();
}

class _GuiaVpnPageState extends State<GuiaVpnPage> {
  /// Public key del VPS cargada desde /wg/info (no es secreta, es pública).
  String _serverPubKey = '';

  @override
  void initState() {
    super.initState();
    _cargarPubKey();
  }

  Future<void> _cargarPubKey() async {
    final info = await VpsService.obtenerInfoVps();
    if (info != null && info.serverPublicKey.isNotEmpty && mounted) {
      setState(() => _serverPubKey = info.serverPublicKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pubKey = _serverPubKey.isEmpty ? '<PUBLIC_KEY_DEL_VPS>' : _serverPubKey;
    return Scaffold(
      backgroundColor: _C.surfaceDim,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _banner(
                      icon: Icons.auto_awesome_rounded,
                      color: _C.success,
                      title: 'Guía rápida para tu empresa 🎉',
                      subtitle: 'En 3 pasos conectás tu MikroTik al servidor y accedés a '
                          'tus antenas desde la app. No necesitás conocimientos de WireGuard.',
                    ),
                    const SizedBox(height: 6),
                    _paso(context, 1, 'MikroTik · crear el túnel hacia el servidor',
                        'En tu MikroTik (Winbox → New Terminal o SSH), pegá estos comandos. '
                        'La public key del servidor ya viene cargada abajo:',
                        '/interface wireguard add name=wg1 listen-port=13231\n'
                        '/interface wireguard peers add interface=wg1 \\\n'
                        '  public-key="$pubKey" \\\n'
                        '  endpoint-address=5.161.88.42 endpoint-port=1234 \\\n'
                        '  allowed-address=10.50.50.0/24 persistent-keepalive=10s\n\n'
                        '# Anotá la public key de TU MikroTik y enviasela al administrador:\n'
                        '/interface wireguard print detail'),
                    _banner(
                      icon: Icons.lock_rounded,
                      color: _C.primary,
                      title: 'La public key del servidor es SEGURA de compartir',
                      subtitle: 'Es pública por diseño (como un usuario). Que la conozcas no '
                          'te da acceso a nada: solo el administrador da de alta los equipos. '
                          'La clave privada del servidor jamás se comparte.',
                    ),
                    _paso(context, 2, 'Antenas · gateway',
                        'Entrá a cada antena (http://10.10.x.y) → Network → Gateway y poné '
                        'la IP del MikroTik en su red (ej: 10.10.15.1). Así la antena '
                        'devuelve el tráfico por el túnel.',
                        null),
                    _paso(context, 3, 'App · activar la VPN',
                        '1) Iniciá sesión en la app.\n'
                        '2) Menú → VPN · Antenas → ⚙️ (Configurar).\n'
                        '3) Tocá "Generar claves" y después "Registrar en el VPS".\n'
                        '4) Guardá y activá el switch → debe quedar "Conectado".\n'
                        '5) Tocá una antena para abrir su pantalla de airOS.',
                        null),
                    const SizedBox(height: 10),
                    _banner(
                      icon: Icons.check_circle_outline_rounded,
                      color: _C.accent,
                      title: 'Ya está ✅',
                      subtitle: 'El administrador se encarga del resto en el servidor '
                          '(darte de alta, IPs, subred y rutas). Recordá enviarle la public '
                          'key de tu MikroTik del paso 1. Cualquier duda, contactalo.',
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, color: _C.textPri),
          ),
          const SizedBox(width: 4),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_C.primary, _C.accent]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Guía de configuración',
                    style: GoogleFonts.spaceGrotesk(
                        color: _C.textPri, fontSize: 17, fontWeight: FontWeight.w800)),
                Text('Para tu empresa · MikroTik + antenas + app',
                    style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Un paso numerado (con bloque de código opcional) ──────────
  Widget _paso(BuildContext context, int numero, String titulo, String descripcion, String? codigo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_C.primary, _C.accent]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text('$numero',
                      style: GoogleFonts.spaceGrotesk(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: GoogleFonts.spaceGrotesk(
                            color: _C.textPri, fontSize: 13.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(descripcion,
                        style: GoogleFonts.spaceGrotesk(
                            color: _C.textSec, fontSize: 11.5, height: 1.45)),
                  ],
                ),
              ),
            ],
          ),
          if (codigo != null) ...[
            const SizedBox(height: 10),
            _bloqueCodigo(context, codigo),
          ],
        ],
      ),
    );
  }

  // ── Bloque de código con botón copiar ─────────────────────────
  Widget _bloqueCodigo(BuildContext context, String codigo) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.dark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              codigo,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white70, height: 1.5),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: codigo));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Comando copiado'), duration: Duration(seconds: 1)),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.copy_rounded, color: Colors.white38, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ── Banner informativo ────────────────────────────────────────
  Widget _banner({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.spaceGrotesk(
                        color: _C.textPri, fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

