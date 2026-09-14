import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:stark_go/services/antenas_service.dart';
import 'package:stark_go/services/notificaciones_service.dart';
import 'package:stark_go/services/vpn_controller.dart';
import 'package:stark_go/services/vps_service.dart';

import 'antena_webview_page.dart';
import 'config_vpn_widget.dart';
import 'guia_vpn_page.dart';
import 'mikrotik_webview_page.dart';
import 'package:stark_go/pages/ConfigMikroTik/config_mikro_tik_widget.dart';

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
  static const Color purple = Color(0xFF7C3AED);
  static const Color indigo = Color(0xFF4F46E5);
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

  /// Modo **netmap**: el MikroTik traduce la subred del túnel a tu red local.
  /// Permite que varias empresas compartan la misma red (ej. 192.168.1.x).
  bool _usarNetmap = false;

  /// IP que se está probando ahora mismo (para el spinner del botón de prueba).
  String? _probandoIp;

  /// Tu red local real (ej. 192.168.1.0/24). Puede repetirse entre empresas.
  String _subredLocal = '';

  /// Subred donde viven las IPs **reales** de las antenas:
  ///  · netmap ON  → tu red local (ej. 192.168.1.0/24)
  ///  · netmap OFF → la subred del túnel (10.10.15.0/24 o 192.168.10.0/24)
  String get _redReal =>
      (_usarNetmap && AntenasService.cidrValido(_subredLocal))
          ? _subredLocal
          : _redAntenas;

  /// IP del MikroTik para abrir su panel web (desde config_mikrotik).
  String _mikrotikIp = '';
  String _mikrotikUser = '';
  String _mikrotikPass = '';

  // ── Búsqueda y filtro de antenas ──
  final TextEditingController _buscarCtrl = TextEditingController();
  String _busqueda = '';
  int _filtroAntenas = 0; // 0 = todas · 1 = clientes · 2 = sectoriales

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
      _syncNotifTunel();
    });
    _cargarRedAntenas();
    _iniciar();
  }

  @override
  void dispose() {
    _sub.cancel();
    _buscarCtrl.dispose();
    super.dispose();
  }

  /// Muestra/oculta la notificación persistente según el estado del túnel.
  void _syncNotifTunel() {
    // En Android la notificación persistente "VPN Activa / Conectado a
    // MikroTik" la publica el servicio nativo en primer plano, arrancado y
    // detenido desde VpnController (VpnForegroundBridge). Evitamos duplicarla
    // con flutter_local_notifications; en iOS no hay FGS y seguimos usando la
    // notificación local ongoing.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return;

    final activo = _status == VpnStatus.connected;
    if (activo) {
      NotificacionesService.instance.mostrarTunelActivo();
    } else {
      NotificacionesService.instance.ocultarTunelActivo();
    }
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
        _syncNotifTunel();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _inicializado = true;
          _status = VpnStatus.error;
          _lastError = 'No se pudo inicializar la interfaz VPN: ${e.runtimeType}';
        });
        _syncNotifTunel();
      }
    }
  }

  /// Lee la subred de antenas asignada por el VPS (solo lectura).
  Future<void> _cargarRedAntenas() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('vpn_config').doc(uid).get();
      if (doc.exists && mounted) {
        final red = (doc.data()?['redAntenas'] ?? '').toString();
        if (red.isNotEmpty) setState(() => _redAntenas = red);
      }
    } catch (_) {
      // Si no se puede leer, queda el valor por defecto.
    }
    await _cargarConfigMikrotik();
  }

  /// Lee la IP/usuario/clave del MikroTik desde config_mikrotik/{uid}.
  Future<void> _cargarConfigMikrotik() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('config_mikrotik').doc(uid).get();
      if (doc.exists && mounted) {
        final d = doc.data() as Map<String, dynamic>;
        setState(() {
          _mikrotikIp = (d['mikrotikIp'] ?? '').toString().trim();
          _mikrotikUser = (d['mikrotikUser'] ?? '').toString().trim();
          _mikrotikPass = (d['mikrotikPass'] ?? '').toString().trim();
          _usarNetmap = (d['usarNetmap'] ?? false) == true;
          _subredLocal = (d['subredLocal'] ?? '').toString().trim();
        });
      }
    } catch (_) {
      // Si no se puede leer, se muestra "Sin IP configurada".
    }
  }

  Future<void> _toggle(bool encender) async {
    if (_busy) return;

    // Consentimiento informado: se muestra SIEMPRE antes de activar el túnel.
    if (encender) {
      final acepta = await _mostrarConsentimientoVpn();
      if (!acepta) return;
    }

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

  /// Consentimiento informado que se muestra cada vez que se va a encender
  /// el túnel. También sirve como "divulgación destacada" para Play Console.
  Future<bool> _mostrarConsentimientoVpn() async {
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(gradient: const LinearGradient(colors: [_C.primary, _C.accent]), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.vpn_lock_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Conexión VPN', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Al conectar se crea un túnel cifrado hacia el MikroTik de tu '
              'empresa para administrar antenas y equipos de tus clientes.',
              style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            _filaConsentimiento('No se recopila ni se comparte información de tu tráfico.'),
            _filaConsentimiento('El túnel solo está activo mientras lo usas.'),
            _filaConsentimiento('Puedes desconectarlo cuando quieras desde esta pantalla o la notificación.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _C.textSec)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Conectar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Widget _filaConsentimiento(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.check_circle_rounded, color: _C.success, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(texto, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12.5, height: 1.35)),
        ),
      ]),
    );
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
  bool get _transicion => _status == VpnStatus.connecting || _status == VpnStatus.disconnecting;

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
                      if (_conectado) ...[
                        _buildMikrotik(),
                        const SizedBox(height: 14),
                        _buildAntenas(),
                      ] else
                        _buildHintConectar(),
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
                Text('VPN · Antenas', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 17, fontWeight: FontWeight.w800)),
                Text('Túnel WireGuard seguro', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
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
                        _conectado ? Icons.lock_rounded : (_status == VpnStatus.error ? Icons.error_rounded : Icons.lock_open_rounded),
                        color: _estadoColor,
                        size: 26,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_estadoTexto, style: GoogleFonts.spaceGrotesk(color: _estadoColor, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(
                      _conectado ? 'El túnel está activo. Podés acceder a las antenas.' : 'Activá la VPN para acceder a la red de antenas.',
                      style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11.5, height: 1.35),
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
                Text(title, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, height: 1.4)),
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
                      style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Manual: VPS, MikroTik y antenas · paso a paso', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
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
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _uid != null ? () => _abrirFormSectorial() : null,
            icon: const Icon(Icons.add_rounded, size: 17, color: _C.accent),
            label:
                Text('Registrar sectorial', style: GoogleFonts.spaceGrotesk(color: _C.accent, fontSize: 12.5, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: _C.accent.withOpacity(0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Acceso al panel del MikroTik (WebFig) ─────────────────
  Widget _buildMikrotik() {
    // Con netmap, el panel del MikroTik se abre por su IP virtual del túnel
    // (ej. 192.168.1.1 → 10.10.15.1). Es idempotente si ya es virtual.
    final ip = _usarNetmap
        ? AntenasService.ipVirtual(_mikrotikIp.trim(), _redAntenas)
        : _mikrotikIp.trim();
    final configurado = ip.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MikroTik', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Tocá para abrir el panel web (WebFig) del MikroTik.', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11.5)),
        const SizedBox(height: 12),
        Container(
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
              onTap: configurado
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MikrotikWebViewPage(
                            ip: ip,
                            usuario: _mikrotikUser,
                            clave: _mikrotikPass,
                          ),
                        ),
                      );
                    }
                  : () => context.pushNamed(ConfigMikroTikWidget.routeName),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _C.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.router_rounded, color: _C.warning, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MikroTik — WebFig',
                              style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            configurado ? ip : 'Sin IP configurada · toca para configurar',
                            style: GoogleFonts.spaceGrotesk(color: configurado ? _C.textSec : _C.warning, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      configurado ? Icons.chevron_right_rounded : Icons.tune_rounded,
                      color: configurado ? _C.textSec : _C.warning,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
            const Spacer(),
            if (uid != null)
              TextButton.icon(
                onPressed: () => _abrirFormSectorial(),
                icon: const Icon(Icons.add_rounded, size: 16, color: _C.primary),
                label: Text('Agregar', style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Tocá una antena para abrir su interfaz airOS.', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11.5)),
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
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
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
                  subtitle: 'No tenés antenas ni sectoriales registrados. '
                      'Usá "Agregar" para registrar tus sectoriales o asigná '
                      'la IP de antena en tus clientes.',
                );
              }
              final filtradas = _filtrarAntenas(antenas);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAntenasToolbar(antenas),
                  if (filtradas.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      child: Center(
                        child: Text(
                          _busqueda.trim().isNotEmpty ? 'No se encontró ninguna antena con "$_busqueda".' : 'No hay antenas de este tipo.',
                          style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12),
                        ),
                      ),
                    )
                  else
                    ...filtradas.map(_buildAntenaTile),
                ],
              );
            },
          ),
      ],
    );
  }

  // ── Registro de sectoriales ──────────────────────────────────
  Future<void> _abrirFormSectorial({AntenaModel? existente}) async {
    final uid = _uid;
    if (uid == null) return;

    final ctrlNombre = TextEditingController(text: existente?.nombre ?? '');
    final ctrlIp = TextEditingController(text: existente?.ip ?? '');
    final ctrlMarca = TextEditingController(text: existente?.marca ?? '');
    final ctrlModelo = TextEditingController(text: existente?.modelo ?? '');
    final ctrlUsuario = TextEditingController(text: existente?.usuarioAtn ?? '');
    final ctrlClave = TextEditingController(text: existente?.claveAtn ?? '');

    try {
      final guardar = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> sugerirIp() async {
              final ip = await AntenasService.siguienteIpLibre(uid: uid, cidr: _redReal);
              setDialogState(() {});
              if (ip != null) {
                ctrlIp.text = ip;
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text('IP libre sugerida: $ip'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: _C.success,
                  ));
                }
              } else if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  content: Text('No hay IPs libres en $_redReal'),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(children: [
                Icon(existente == null ? Icons.add_circle_rounded : Icons.edit_rounded, color: _C.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(existente == null ? 'Registrar sectorial' : 'Editar sectorial',
                      style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ]),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: ctrlNombre,
                      decoration: const InputDecoration(labelText: 'Nombre / referencia'),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: ctrlIp,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: _usarNetmap
                                ? 'IP real (en tu red local)'
                                : 'IP (en la subred de antenas)',
                            hintText: _usarNetmap
                                ? 'Ej: 192.168.1.20'
                                : 'Ej: 10.10.15.20',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: sugerirIp,
                        tooltip: 'Buscar IP libre',
                        icon: const Icon(Icons.my_location_rounded, color: _C.primary),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: ctrlMarca,
                          decoration: const InputDecoration(labelText: 'Marca (opcional)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: ctrlModelo,
                          decoration: const InputDecoration(labelText: 'Modelo (opcional)'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    TextField(
                      controller: ctrlUsuario,
                      decoration: const InputDecoration(labelText: 'Usuario airOS (opcional)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: ctrlClave,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Clave airOS (opcional)'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                        _usarNetmap
                            ? 'Poné la IP REAL del equipo en tu red local ($_redReal). La app lo abre por el túnel con la IP virtual equivalente (misma última octeta).'
                            : 'El sectorial debe estar en el mismo segmento $_redAntenas.',
                        style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _C.primary),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        ),
      );
      if (guardar != true) return;

      final nombre = ctrlNombre.text.trim();
      final ip = ctrlIp.text.trim();
      if (nombre.isEmpty || ip.isEmpty) {
        _snack('Completá el nombre y la IP del sectorial', _C.warning, Icons.warning_rounded);
        return;
      }

      await AntenasService.guardarSectorial(
        uid: uid,
        docId: existente?.id,
        nombre: nombre,
        ip: ip,
        estado: existente?.estado ?? 'activo',
        marca: ctrlMarca.text,
        modelo: ctrlModelo.text,
        usuario: ctrlUsuario.text,
        clave: ctrlClave.text,
      );
      // Si el portal (hotspot) está activo (portalMorosos: true), blindamos la
      // IP de la sectorial del portal cautivo para que su interfaz web cargue
      // igual que la de los clientes al día. El VPS lo encola y el scheduler
      // del MikroTik crea el ip-binding type=bypassed en el próximo ciclo.
      unawaited(VpsService.blindarIpDelPortal(nombre: nombre, ip: ip));
      _snack(existente == null ? 'Sectorial registrado' : 'Sectorial actualizado', _C.success, Icons.check_circle_rounded);
    } catch (e) {
      _snack('Error al guardar: $e', _C.danger, Icons.error_rounded);
    } finally {
      ctrlNombre.dispose();
      ctrlIp.dispose();
      ctrlMarca.dispose();
      ctrlModelo.dispose();
      ctrlUsuario.dispose();
      ctrlClave.dispose();
    }
  }

  Future<void> _confirmarEliminarSectorial(AntenaModel antena) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar sectorial'),
        content: Text('¿Eliminar "${antena.nombre}" (${antena.ip}) de tus sectoriales?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _C.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AntenasService.eliminarSectorial(antena.id);
      _snack('Sectorial eliminado', _C.success, Icons.delete_outline_rounded);
    } catch (e) {
      _snack('Error al eliminar: $e', _C.danger, Icons.error_rounded);
    }
  }

  void _snack(String msg, Color bg, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13))),
      ]),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Filtro y buscador de antenas ──────────────────────────────────
  List<AntenaModel> _filtrarAntenas(List<AntenaModel> antenas) {
    final texto = _busqueda.trim().toLowerCase();
    return antenas.where((a) {
      final tipoOk = _filtroAntenas == 0 || (_filtroAntenas == 1 && !a.esSectorial) || (_filtroAntenas == 2 && a.esSectorial);
      final textoOk = texto.isEmpty || a.nombre.toLowerCase().contains(texto) || a.ip.toLowerCase().contains(texto);
      return tipoOk && textoOk;
    }).toList();
  }

  Widget _buildAntenasToolbar(List<AntenaModel> antenas) {
    final clientes = antenas.where((a) => !a.esSectorial).length;
    final sectoriales = antenas.length - clientes;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border),
          ),
          child: Row(children: [
            const Icon(Icons.search_rounded, color: _C.textSec, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _buscarCtrl,
                onChanged: (v) => setState(() => _busqueda = v),
                style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Buscar antena por nombre o IP…',
                  hintStyle: TextStyle(color: _C.textSec.withOpacity(0.55), fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_busqueda.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _buscarCtrl.clear();
                  setState(() => _busqueda = '');
                },
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.close_rounded, color: _C.textSec, size: 17),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _chipFiltro(0, 'Todas', antenas.length, _C.textSec),
          _chipFiltro(1, 'Clientes', clientes, _C.primary),
          _chipFiltro(2, 'Sectoriales', sectoriales, _C.accent),
        ]),
      ]),
    );
  }

  Widget _chipFiltro(int valor, String label, int count, Color color) {
    final activo = _filtroAntenas == valor;
    final txtColor = activo ? color : _C.textSec;
    return GestureDetector(
      onTap: () => setState(() => _filtroAntenas = valor),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: activo ? color.withOpacity(0.12) : _C.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: activo ? color.withOpacity(0.5) : _C.border, width: 1.2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: GoogleFonts.spaceGrotesk(color: txtColor, fontSize: 11.5, fontWeight: FontWeight.w700)),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: (activo ? color : _C.textSec).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$count', style: GoogleFonts.spaceGrotesk(color: txtColor, fontSize: 10.5, fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }

  /// Prueba si la antena responde por el túnel (http/https) y explica el fallo.
  Future<void> _probarAntena(AntenaModel antena, String ipAbrir) async {
    if (_status != VpnStatus.connected) {
      _snack('Activá el túnel para poder probar la antena', _C.warning,
          Icons.warning_rounded);
      return;
    }
    if (_probandoIp != null) return;
    setState(() => _probandoIp = ipAbrir);
    final r = await AntenasService.probarIp(ipAbrir);
    if (!mounted) return;
    setState(() => _probandoIp = null);
    if (r.ok) {
      _snack('✅ ${antena.nombre} respondió en $ipAbrir (${r.detalle})',
          _C.success, Icons.check_circle_rounded);
      return;
    }
    _snack(
      _usarNetmap
          ? '❌ ${antena.nombre} no respondió en $ipAbrir.\n'
              'Revisá: (1) la regla netmap en el MikroTik, (2) que la antena real '
              '(${antena.ip}) conteste desde tu red, (3) que el túnel siga conectado.'
          : '❌ ${antena.nombre} no respondió en $ipAbrir.\n'
              'Revisá que la antena esté encendida con esa IP y que el túnel siga conectado.',
      _C.danger,
      Icons.error_rounded,
    );
  }

  Widget _buildAntenaTile(AntenaModel antena) {
    final abierta = antena.esAccesible &&
        antena.ipValidaVpn(redTunel: _redAntenas, netmap: _usarNetmap);
    // IP con la que se abre el equipo (virtual si el MikroTik usa netmap).
    final ipAbrir = antena.ipParaVpn(redTunel: _redAntenas, netmap: _usarNetmap);
    final estadoColor = antena.esAccesible ? _C.success : _C.danger;
    final esSectorial = antena.esSectorial;

    // Logo/ícono según el tipo:
    //  · Sectoriales → torre celular con degradado púrpura
    //  · Antenas de cliente → ícono de antena con degradado azul/teal
    final Color gA = esSectorial ? _C.purple : _C.primary;
    final Color gB = esSectorial ? _C.indigo : _C.accent;
    final IconData icono = esSectorial ? Icons.cell_tower_rounded : Icons.settings_input_antenna_rounded;
    final String tipo = esSectorial ? 'SECTORIAL' : 'CLIENTE';
    final String subDetalle = [
      if (antena.marca != null && antena.marca!.isNotEmpty) antena.marca!,
      if (antena.modelo != null && antena.modelo!.isNotEmpty) antena.modelo!,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: abierta
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AntenaWebViewPage(antena: antena, ipAbrir: ipAbrir),
                    ),
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                // Logo del tipo de antena
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [gA, gB],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: gA.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icono, color: Colors.white, size: 23),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(antena.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                              color: _C.textPri,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        subDetalle.isEmpty ? tipo : '$subDetalle · $tipo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                            color: esSectorial ? _C.purple : _C.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.lan_rounded,
                              color: _C.textSec.withOpacity(0.6), size: 12),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                                _usarNetmap ? '${antena.ip} → $ipAbrir' : antena.ip,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceGrotesk(
                                    color: _C.textSec, fontSize: 11.5)),
                          ),
                          if (!antena.ipValidaVpn(
                              redTunel: _redAntenas, netmap: _usarNetmap)) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: _C.warning.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('fuera de rango',
                                  style: GoogleFonts.spaceGrotesk(
                                      color: _C.warning, fontSize: 9)),
                            ),
                          ],
                          // ── Probar conexión con esta antena (por el túnel) ──
                          if (abierta) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: _probandoIp == null
                                  ? () => _probarAntena(antena, ipAbrir)
                                  : null,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _C.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: _probandoIp == ipAbrir
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 1.6))
                                    : const Icon(Icons.network_check_rounded,
                                        size: 13, color: _C.primary),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Estado (pill con punto) + acciones del sectorial
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: estadoColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: estadoColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(antena.estado,
                              style: GoogleFonts.spaceGrotesk(
                                  color: estadoColor,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    if (antena.esSectorial) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _abrirFormSectorial(existente: antena),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: _C.surfaceDim,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.edit_rounded,
                                  color: _C.textSec, size: 15),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _confirmarEliminarSectorial(antena),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: _C.danger.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.delete_outline_rounded,
                                  color: _C.danger.withOpacity(0.8), size: 15),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
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
