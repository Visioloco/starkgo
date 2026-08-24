import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:stark_go/services/antenas_service.dart';
import 'package:stark_go/services/vpn_controller.dart';

import 'antena_webview_page.dart';
import 'config_vpn_widget.dart';
import 'guia_vpn_page.dart';

// ══════════════════════════════════════════════════════════════
//  VpnWidget — control del túnel WireGuard + listado de antenas.
//
//  · Switch/indicador de estado (desconectado → conectando → conectado)
//  · Carga segura de la config desde Firestore (vpn_config/{uid})
//  · Lista de antenas (solo visible cuando el túnel está conectado)
//  · Tap en antena → WebView airOS (http://<ip>)
// ══════════════════════════════════════════════════════════════

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

class VpnWidget extends StatefulWidget {
  const VpnWidget({super.key});

  static String routeName = 'Vpn';
  static String routePath = 'vpn';

  @override
  State<VpnWidget> createState() => _VpnWidgetState();
}

class _VpnWidgetState extends State<VpnWidget> {
  final VpnController _vpn = VpnController.instance;

  late final StreamSubscription<VpnStatus> _sub;

  VpnStatus _status = VpnStatus.disconnected;
  bool _busy = false;
  bool _inicializado = false;
  String? _lastError;

  /// Subred de antenas del usuario (asignada por el VPS, 10.10.x.0/24).
  String _redAntenas = '10.10.15.0/24';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _sub = _vpn.statusStream.listen((s) {
      if (!mounted) return;
      setState(() {
        _status = s;
        if (s != VpnStatus.error) _lastError = null;
      });
    });
    _cargarRedAntenas();
    _iniciar();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<void> _iniciar() async {
    if (!_vpn.isSupportedPlatform) return;
    try {
      await _vpn.initialize();
      final st = await _vpn.status();
      if (mounted) {
        setState(() {
          _inicializado = true;
          _status = st;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _inicializado = true;
          _status = VpnStatus.error;
          _lastError = 'No se pudo inicializar la interfaz VPN: ${e.runtimeType}';
        });
      }
    }
  }

  /// Lee la subred de antenas asignada por el VPS (solo lectura).
  Future<void> _cargarRedAntenas() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vpn_config')
          .doc(uid)
          .get();
      if (doc.exists && mounted) {
        final red = (doc.data()?['redAntenas'] ?? '').toString();
        if (red.isNotEmpty) setState(() => _redAntenas = red);
      }
    } catch (_) {
      // Si no se puede leer, queda el valor por defecto.
    }
  }

  Future<void> _toggle(bool encender) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (encender) {
        final resultado = await _vpn.start();
        if (!resultado.ok && mounted) {
          setState(() {
            _status = VpnStatus.error;
            _lastError = resultado.errorMessage ?? 'No se pudo conectar';
          });
          if (resultado.kind == StartVpnResultKind.noConfig) {
            await _preguntarCrearConfig();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(resultado.errorMessage ?? 'No se pudo conectar'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        await _vpn.stop();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preguntarCrearConfig() async {
    if (!mounted) return;
    final ir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sin configuración del túnel'),
        content: const Text(
          'Aún no hay una configuración VPN para tu cuenta. '
          '¿Querés crear una ahora? (endpoint, claves e IP del túnel)',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ahora no')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Crear configuración', style: TextStyle(color: _C.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ir == true && mounted) {
      await _abrirConfiguracion();
    }
  }

  // ── Helpers de estado ─────────────────────────────────────────
  bool get _conectado => _status == VpnStatus.connected;
  bool get _transicion =>
      _status == VpnStatus.connecting || _status == VpnStatus.disconnecting;

  String get _estadoTexto {
    switch (_status) {
      case VpnStatus.connecting:
        return 'Conectando…';
      case VpnStatus.connected:
        return 'Conectado';
      case VpnStatus.disconnecting:
        return 'Desconectando…';
      case VpnStatus.error:
        return 'Error';
      case VpnStatus.disconnected:
        return 'Desconectado';
    }
  }

  Color get _estadoColor {
    if (_conectado) return _C.success;
    if (_transicion) return _C.warning;
    if (_status == VpnStatus.error) return _C.danger;
    return _C.textSec;
  }
  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surfaceDim,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_vpn.isSupportedPlatform)
                      _buildNoSoportado()
                    else ...[
                      _buildStatusCard(),
                      const SizedBox(height: 12),
                      _buildGuiaBoton(),
                      if (_vpn.needsExtraSetup) _buildSetupBanner(),
                      if (_lastError != null) _buildErrorBanner(),
                      const SizedBox(height: 14),
                      if (_conectado) _buildAntenas() else _buildHintConectar(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
            child: const Icon(Icons.vpn_lock_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('VPN · Antenas',
                    style: GoogleFonts.spaceGrotesk(
                        color: _C.textPri, fontSize: 17, fontWeight: FontWeight.w800)),
                Text('Túnel WireGuard seguro',
                    style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            onPressed: _abrirConfiguracion,
            tooltip: 'Configurar túnel',
            icon: const Icon(Icons.settings_rounded, color: _C.textSec),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirConfiguracion() async {
    await context.pushNamed(ConfigVpnWidget.routeName);
    // Al volver, si se creó la config, refrescamos el estado del túnel.
    if (mounted) {
      final st = await _vpn.status();
      if (mounted) setState(() => _status = st);
    }
  }

  // ── Tarjeta de estado + switch ────────────────────────────────
  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(color: _C.dark.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Indicador de estado circular
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: _estadoColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: _transicion
                    ? Padding(
                        padding: const EdgeInsets.all(15),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(_estadoColor),
                        ),
                      )
                    : Icon(
                        _conectado
                            ? Icons.lock_rounded
                            : (_status == VpnStatus.error
                                ? Icons.error_rounded
                                : Icons.lock_open_rounded),
                        color: _estadoColor,
                        size: 26,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_estadoTexto,
                        style: GoogleFonts.spaceGrotesk(
                            color: _estadoColor, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(
                      _conectado
                          ? 'El túnel está activo. Podés acceder a las antenas.'
                          : 'Activá la VPN para acceder a la red de antenas.',
                      style: GoogleFonts.spaceGrotesk(
                          color: _C.textSec, fontSize: 11.5, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Switch
              Switch(
                value: _conectado || _transicion,
                onChanged: _busy || _transicion || !_inicializado ? null : _toggle,
                activeTrackColor: _C.success,
                thumbColor: const WidgetStatePropertyAll(Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Barra de progreso de conexión
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 5,
              backgroundColor: _C.border,
              valueColor: AlwaysStoppedAnimation(_estadoColor),
              value: _conectado ? 1 : (_transicion ? null : 0),
            ),
          ),
        ],
      ),
    );
  }
  // ── Avisos ───────────────────────────────────────────────────
  Widget _buildSetupBanner() {
    return _banner(
      icon: Icons.build_rounded,
      color: _C.warning,
      title: 'iOS: configuración pendiente',
      subtitle: _vpn.setupNote ?? '',
    );
  }

  Widget _buildErrorBanner() {
    return _banner(
      icon: Icons.error_outline_rounded,
      color: _C.danger,
      title: 'No se pudo conectar',
      subtitle: _lastError ?? '',
    );
  }

  Widget _banner({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
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
                    style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuiaBoton() {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GuiaVpnPage()),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _C.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu_book_rounded, color: _C.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Guía de configuración',
                      style: GoogleFonts.spaceGrotesk(
                          color: _C.textPri, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Manual: VPS, MikroTik y antenas · paso a paso',
                      style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _C.textSec, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSoportado() {
    return _banner(
      icon: Icons.devices_other_rounded,
      color: _C.textSec,
      title: 'Plataforma no soportada',
      subtitle: _vpn.unsupportedMessage,
    );
  }

  Widget _buildHintConectar() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: _C.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Conectá el túnel para ver y acceder a las antenas (interfaz airOS). '
                  'La configuración se carga de forma segura desde vpn_config/<uid>.',
                  style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11.5, height: 1.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _abrirConfiguracion,
            icon: const Icon(Icons.tune_rounded, size: 17, color: _C.primary),
            label: Text('Crear / editar configuración',
                style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 12.5, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: _C.primary.withOpacity(0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
  // ── Sección de antenas (solo visible con túnel conectado) ────
  Widget _buildAntenas() {
    final uid = _uid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Antenas', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _C.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_redAntenas, style: GoogleFonts.spaceGrotesk(color: _C.success, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Tocá una antena para abrir su interfaz airOS.',
            style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11.5)),
        const SizedBox(height: 12),
        if (uid == null)
          _banner(
            icon: Icons.person_off_rounded,
            color: _C.textSec,
            title: 'Sin sesión',
            subtitle: 'Iniciá sesión para cargar tus antenas.',
          )
        else
          StreamBuilder<List<AntenaModel>>(
            stream: AntenasService.antenasStream(uid: uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _banner(
                  icon: Icons.error_outline_rounded,
                  color: _C.danger,
                  title: 'Error cargando antenas',
                  subtitle: 'Revisá tu conexión e intentá de nuevo.',
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator(color: _C.primary)),
                );
              }
              final antenas = snapshot.data ?? const <AntenaModel>[];
              if (antenas.isEmpty) {
                return _banner(
                  icon: Icons.settings_input_antenna_rounded,
                  color: _C.primary,
                  title: 'Sin antenas',
                  subtitle: 'No se encontraron clientes con antena (campo ipatn) '
                      'para tu usuario. Asigná la IP de antena en tus clientes.',
                );
              }
              return Column(
                children: antenas.map(_buildAntenaTile).toList(),
              );
            },
          ),
      ],
    );
  }
  Widget _buildAntenaTile(AntenaModel antena) {
    final abierta = antena.esAccesible && antena.ipValida(_redAntenas);
    final estadoColor = antena.esAccesible ? _C.success : _C.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: abierta
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AntenaWebViewPage(antena: antena),
                    ),
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _C.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.settings_input_antenna_rounded, color: _C.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(antena.nombre,
                          style: GoogleFonts.spaceGrotesk(
                              color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(antena.ip,
                              style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
                          const SizedBox(width: 8),
                          if (!antena.ipValida(_redAntenas))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: _C.warning.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('IP fuera de rango',
                                  style: GoogleFonts.spaceGrotesk(color: _C.warning, fontSize: 9)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: estadoColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(antena.estado,
                      style: GoogleFonts.spaceGrotesk(color: estadoColor, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 4),
                Icon(
                  abierta ? Icons.chevron_right_rounded : Icons.lock_rounded,
                  color: abierta ? _C.textSec : _C.border,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}




