import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../plan_model.dart';
import '../../services/pais_service.dart';
import '../../services/precios_service.dart';
import '../Pago/pago_webview_page.dart';

/// Métodos de pago disponibles para renovar la membresía.
enum MetodoPago { mercadoPago, rapid, epayco, paypal }

/// Rapid (antes Rapyd): APAGADA — su reemplazo es ePayco.
/// El botón se muestra SOLO si el VPS la enciende (`RAPID_ACTIVO=true`), así
/// que se puede reactivar sin recompilar la app. Este valor compilado es sólo
/// el respaldo cuando el VPS todavía no respondió.
const bool _kRapidHabilitado = false;

/// ePayco: disponible en TODOS los países (incluida Colombia; ahí además
/// está Mercado Pago). El botón se muestra SOLO si el VPS lo informa en
/// producción (`config_pagos/epayco.produccion` = true) y el país no está en
/// `excluirPaises`. Mientras no esté configurado, este valor compilado lo
/// mantiene OCULTO.
const bool _kEpaycoHabilitado = false;

/// PayPal DESACTIVADO por ahora (se usará más adelante).
/// Poné en `true` cuando quieras volver a mostrar el botón.
const bool _kPayPalHabilitado = false;

class _C {
  static const Color primary = Color(0xFF1A73E8);
  static const Color accent = Color(0xFF00C6AE);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFE53935);
  static const Color dark = Color(0xFF0F172A);
  static const Color darkMid = Color(0xFF1E293B);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF1F5F9);
  static const Color textPri = Color(0xFF0F172A);
  static const Color textSec = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color purple = Color(0xFF7C3AED);
  static const Color whatsapp = Color(0xFF25D366);
}

class RenovarMembresiaWidget extends StatefulWidget {
  const RenovarMembresiaWidget({super.key});

  static String routeName = 'RenovarMembresia';
  static String routePath = 'renovarMembresia';

  @override
  State<RenovarMembresiaWidget> createState() => _RenovarMembresiaWidgetState();
}

class _RenovarMembresiaWidgetState extends State<RenovarMembresiaWidget> with TickerProviderStateMixin {
  Plan? _planSel;
  bool _isLoading = false;

  /// Método de pago que se está procesando (para mostrar el spinner correcto).
  MetodoPago? _metodoCargando;
  DateTime? _fechaActualVencimiento;
  String _nombreUsuario = '';
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  // ── URL del VPS ──
  static const String _vpsUrl = 'http://5.161.88.42:3000';

  /// El botón de Rapid se muestra SOLO si el VPS la enciende
  /// (`RAPID_ACTIVO=true`, además de que su config esté en producción).
  /// Rapid quedó reemplazada por ePayco, así que por defecto está oculta.
  bool get _rapidVisible => PreciosService.rapidProduccion ?? _kRapidHabilitado;

  /// El botón de ePayco se muestra SOLO si el VPS lo tiene en producción
  /// (`config_pagos/epayco.produccion` = true), el país no está excluido
  /// (`config_pagos/epayco.excluirPaises`) y el plan elegido no supera el
  /// tope de monto de ePayco (`montoMax`). Todo se ajusta desde Firestore
  /// sin recompilar la app.
  bool get _epaycoVisible =>
      (PreciosService.epaycoProduccion ?? _kEpaycoHabilitado) &&
      PreciosService.epaycoDisponible(PaisService.pais) &&
      PreciosService.epaycoPermiteMonto(_planSel?.precioCop);

  /// true si el plan elegido supera el tope de monto de ePayco (para avisar
  /// por qué no se puede pagar ese plan con ePayco).
  bool get _epaycoMontoExcedido =>
      _planSel != null && PreciosService.epaycoDisponible(PaisService.pais) && !PreciosService.epaycoPermiteMonto(_planSel!.precioCop);

  /// Mercado Pago SOLO funciona en Colombia (la cuenta es colombiana): el
  /// botón se muestra únicamente si el teléfono está en uno de los países
  /// permitidos (`pasarelas.mercadoPago.paises`, por defecto CO).
  bool get _mercadoPagoVisible => PreciosService.mercadoPagoDisponible(PaisService.pais);

  /// true si NO hay ninguna pasarela disponible para este teléfono
  /// (ej: cliente en el exterior antes de habilitar ePayco).
  bool get _sinPasarelas => !_mercadoPagoVisible && !_epaycoVisible && !_rapidVisible && !_kPayPalHabilitado;

  /// Reconstruye la pantalla cuando cambia el estado de una pasarela en
  /// Firestore o cuando termina la detección del país (tiempo real: los
  /// botones aparecen/desaparecen sin reiniciar la app).
  void _onPasarelas() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _cargarDatosUsuario();
    // Tasa USD→COP del VPS: para mostrar el precio también en pesos.
    PreciosService.cargar().then((_) {
      if (mounted) setState(() {});
    });
    // Tiempo real: si cambiás `produccion` en Firestore, el botón cambia solo.
    PreciosService.escucharPasarelas();
    PreciosService.rapidProduccionNotifier.addListener(_onPasarelas);
    PreciosService.epaycoProduccionNotifier.addListener(_onPasarelas);
    // ¿En qué país está el teléfono? Decide si se muestra Mercado Pago.
    PaisService.paisNotifier.addListener(_onPasarelas);
    PaisService.detectar().then((_) {
      if (mounted) setState(() {});
    });
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    PreciosService.rapidProduccionNotifier.removeListener(_onPasarelas);
    PreciosService.epaycoProduccionNotifier.removeListener(_onPasarelas);
    PaisService.paisNotifier.removeListener(_onPasarelas);
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosUsuario() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('user').doc(uid).get();
      if (!mounted) return;
      final data = doc.data();
      if (data != null) {
        setState(() {
          _nombreUsuario = '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'.trim();
          final ts = data['fechaVencimiento'];
          if (ts != null) {
            _fechaActualVencimiento = (ts as Timestamp).toDate();
          }
        });
      }
    } catch (_) {}
  }

  void _seleccionarPlan(Plan planElegido) {
    HapticFeedback.lightImpact();
    setState(() => _planSel = planElegido);
  }

  DateTime get _nuevaFechaVencimiento {
    final base =
        (_fechaActualVencimiento != null && _fechaActualVencimiento!.isAfter(DateTime.now())) ? _fechaActualVencimiento! : DateTime.now();
    return DateTime(base.year, base.month + (_planSel?.meses ?? 0), base.day);
  }

  // ══════════════════════════════════════════════════════════
  //  ESTADO REAL DE LA MEMBRESÍA
  //  (antes esta pantalla mostraba "Vencida / Inactivo" fijo,
  //   aunque la membresía estuviera vigente)
  // ══════════════════════════════════════════════════════════

  /// true si la membresía está VIGENTE (vence en el futuro).
  bool get _membresiaActiva => _fechaActualVencimiento != null && _fechaActualVencimiento!.isAfter(DateTime.now());

  /// Color del estado: verde si está activa, rojo si venció.
  Color get _estadoColor => _membresiaActiva ? _C.success : _C.danger;

  /// Días que le quedan (0 si ya venció o no hay fecha).
  int get _diasRestantes {
    if (!_membresiaActiva) return 0;
    return _fechaActualVencimiento!.difference(DateTime.now()).inDays;
  }

  /// Días transcurridos desde el vencimiento (0 si está activa).
  int get _diasVencida {
    if (_membresiaActiva || _fechaActualVencimiento == null) return 0;
    return DateTime.now().difference(_fechaActualVencimiento!).inDays;
  }

  // ══════════════════════════════════════════
  //  _renovar — llama al VPS en lugar de
  //  Firebase Functions
  // ══════════════════════════════════════════
  Future<void> _renovar(MetodoPago metodo) async {
    if (_planSel == null) {
      _showError('Selecciona un plan para continuar');
      return;
    }
    setState(() {
      _isLoading = true;
      _metodoCargando = metodo;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Sesión expirada. Vuelve a iniciar sesión.');
        return;
      }

      // Obtener token Firebase para autenticar con el VPS
      final token = await user.getIdToken(true);

      // Endpoint según el botón de pago pulsado. Todos responden
      // { initPoint } con la URL del checkout hospedado.
      final endpoint = switch (metodo) {
        MetodoPago.rapid => '/rapid/crear-orden',
        MetodoPago.epayco => '/epayco/crear-orden',
        MetodoPago.paypal => '/paypal/crear-orden',
        MetodoPago.mercadoPago => '/mp/crear-preferencia',
      };

      final response = await http
          .post(
            Uri.parse('$_vpsUrl$endpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'planId': _planSel!.id,
              'nombre': _nombreUsuario,
              'tipo': _planSel!.tipo.name, // 'completo' | 'vouchers'
              'meses': _planSel!.meses,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('[Pago] VPS respondió ${response.statusCode}: ${response.body}');
        _showError(_mensajeErrorVps(response));
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // Ambos endpoints devuelven la URL de pago en 'initPoint'.
      final url = (data['initPoint'] ?? data['approveUrl']) as String?;
      if (url == null || url.isEmpty) {
        _showError('No se pudo obtener el enlace de pago');
        return;
      }

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PagoWebViewPage(
              url: url,
              plan: _planSel!,
              // Pasarela + nº de orden: la pantalla de "pago pendiente" los usa
              // para verificar el cobro en la pasarela correcta.
              metodo: metodo.name,
              ordenId: (data['ordenId'] ?? data['checkoutId'] ?? data['orderId']) as String?,
            ),
          ),
        );
      }
    } on TimeoutException {
      _showError('Tiempo de espera agotado. Verifica tu conexión.');
    } catch (e) {
      debugPrint('[Pago] Excepción al iniciar el pago: $e');
      _showError('Error al iniciar el pago: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _metodoCargando = null;
        });
      }
    }
  }

  String _formatFecha(DateTime d) => '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Motivo del error que devolvió el VPS (ej: "ePayco todavía no está
  /// configurado…"). Si no manda mensaje, se usa el código HTTP.
  String _mensajeErrorVps(http.Response r) {
    try {
      final j = jsonDecode(r.body);
      if (j is Map) {
        final m = '${j['error'] ?? j['message'] ?? ''}'.trim();
        if (m.isNotEmpty) return m;
      }
    } catch (_) {
      // Sin cuerpo JSON: se muestra el código.
    }
    return 'Error del servidor (${r.statusCode})';
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.dmSans(color: Colors.white))),
      ]),
      backgroundColor: _C.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.dmSans(color: Colors.white))),
      ]),
      backgroundColor: _C.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.dark,
      body: Stack(children: [
        _buildFondoDecorativo(),
        SafeArea(
          child: Column(children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                child: Column(children: [
                  _buildHeroCard().animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0, duration: 400.ms, curve: Curves.easeOut),
                  const SizedBox(height: 20),
                  _buildSeccionPlanes()
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 120.ms)
                      .slideY(begin: 0.06, end: 0, duration: 400.ms, delay: 120.ms),
                  if (_planSel != null) ...[
                    const SizedBox(height: 16),
                    _buildResumenPlan().animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, end: 0, duration: 300.ms),
                  ],
                  const SizedBox(height: 18),
                  _buildBotones()
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 200.ms)
                      .slideY(begin: 0.06, end: 0, duration: 400.ms, delay: 200.ms),
                  const SizedBox(height: 14),
                  _buildNotaSeguridad().animate().fadeIn(duration: 400.ms, delay: 320.ms),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildFondoDecorativo() {
    return Positioned.fill(
      child: CustomPaint(painter: _FondoPainter(animation: _shimmerController)),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 17),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Renovar Membresía', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
            Text('StarkGo · Panel de gestión ISP', style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 11.5)),
          ]),
        ),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, __) {
            final pulse = 0.5 + _pulseController.value * 0.5;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: _estadoColor.withOpacity(0.12 + pulse * 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _estadoColor.withOpacity(0.4 + pulse * 0.2)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _estadoColor.withOpacity(pulse),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(_membresiaActiva ? 'Activa' : 'Vencida',
                    style: GoogleFonts.dmSans(color: _estadoColor, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ]),
            );
          },
        ),
      ]),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _membresiaActiva ? const [Color(0xFF064E3B), Color(0xFF065F46)] : const [Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _estadoColor.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(color: _estadoColor.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(children: [
        Positioned(
          right: -20,
          top: -20,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.purple.withOpacity(0.12),
            ),
          ),
        ),
        Positioned(
          right: 20,
          bottom: -30,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.primary.withOpacity(0.1),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _membresiaActiva ? [_C.success, const Color(0xFF4ADE80)] : [_C.danger, const Color(0xFFFF6B6B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: _estadoColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Icon(_membresiaActiva ? Icons.verified_rounded : Icons.lock_clock_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_membresiaActiva ? 'Membresía activa' : 'Acceso suspendido',
                      style: GoogleFonts.dmSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                      _nombreUsuario.isNotEmpty
                          ? 'Hola, $_nombreUsuario'
                          : (_membresiaActiva ? 'Tu membresía está vigente' : 'Tu membresía ha vencido'),
                      style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(children: [
                Expanded(
                  child: _heroStat(
                    _membresiaActiva ? 'Vence el' : 'Venció el',
                    _fechaActualVencimiento != null ? _formatFecha(_fechaActualVencimiento!) : '—',
                    _estadoColor,
                    _membresiaActiva ? Icons.event_available_rounded : Icons.event_busy_rounded,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white.withOpacity(0.08)),
                Expanded(
                  child: _heroStat(
                    _membresiaActiva ? 'Días restantes' : 'Días vencida',
                    _fechaActualVencimiento == null
                        ? '—'
                        : _membresiaActiva
                            ? '${_diasRestantes}d'
                            : '${_diasVencida}d',
                    _membresiaActiva ? _C.success : _C.warning,
                    _membresiaActiva ? Icons.timer_rounded : Icons.timer_off_rounded,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white.withOpacity(0.08)),
                Expanded(
                  child: _heroStat(
                    'Estado',
                    _membresiaActiva ? 'Activo' : 'Inactivo',
                    _estadoColor,
                    _membresiaActiva ? Icons.verified_user_rounded : Icons.block_rounded,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (_membresiaActiva ? _C.success : _C.warning).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (_membresiaActiva ? _C.success : _C.warning).withOpacity(0.25)),
              ),
              child: Row(children: [
                Icon(_membresiaActiva ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                    color: _membresiaActiva ? _C.success : _C.warning, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _membresiaActiva
                        ? 'Tu membresía está ACTIVA. Si renovás ahora, el tiempo se SUMA a tu vencimiento actual.'
                        : 'Para recuperar el acceso completo a StarkGo, selecciona un plan y completa el pago.',
                    style: GoogleFonts.dmSans(color: _membresiaActiva ? _C.success : _C.warning, fontSize: 11.5),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _heroStat(String label, String value, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.dmSans(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 9.5), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildSeccionPlanes() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 14),
        child: Row(children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_C.purple, _C.primary],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text('Elige tu plan', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _C.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.accent.withOpacity(0.3)),
            ),
            child: Text('Con descuento', style: GoogleFonts.dmSans(color: _C.accent, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.35,
        ),
        itemCount: kPlanes.length,
        itemBuilder: (_, i) {
          final planItem = kPlanes[i];
          final sel = _planSel?.id == planItem.id;
          return _PlanCard(
            plan: planItem,
            selected: sel,
            onTap: () => _seleccionarPlan(planItem),
          ).animate(target: sel ? 1 : 0).scaleXY(begin: 1.0, end: 1.02, duration: 200.ms, curve: Curves.easeOut);
        },
      ),

      // ── Separador ──
      const SizedBox(height: 22),

      // ── Sección "Solo Vouchers" ──
      _buildSeccionVouchers(),
    ]);
  }

  // ── Sección "Solo Vouchers" ──
  Widget _buildSeccionVouchers() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Encabezado de la sección
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: const Color(0xFF0EA5E9).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.vpn_key_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Solo Vouchers', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('Acceso solo al módulo MikroTik Local', style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 11)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Económico', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.35,
        ),
        itemCount: kPlanesVouchers.length,
        itemBuilder: (_, i) {
          final planItem = kPlanesVouchers[i];
          final sel = _planSel?.id == planItem.id;
          return _PlanCard(
            plan: planItem,
            selected: sel,
            onTap: () => _seleccionarPlan(planItem),
          ).animate(target: sel ? 1 : 0).scaleXY(begin: 1.0, end: 1.02, duration: 200.ms, curve: Curves.easeOut);
        },
      ),
    ]);
  }

  Widget _buildResumenPlan() {
    if (_planSel == null) return const SizedBox.shrink();
    final nuevaFecha = _nuevaFechaVencimiento;
    final diasGanados = nuevaFecha.difference(DateTime.now()).inDays;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _planSel!.color.withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _planSel!.color.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _planSel!.color.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(bottom: BorderSide(color: _planSel!.color.withOpacity(0.15))),
          ),
          child: Row(children: [
            Icon(_planSel!.icon, color: _planSel!.color, size: 16),
            const SizedBox(width: 8),
            Text('Resumen de renovación', style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: _planSel!.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_planSel!.badge, style: GoogleFonts.dmSans(color: _planSel!.color, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(children: [
            _resumenFila(Icons.workspace_premium_rounded, 'Plan', '${_planSel!.duracion} · ${_planSel!.sublabel}', _planSel!.color),
            _resumenFila(Icons.event_rounded, 'Nuevo vencimiento', _formatFecha(nuevaFecha), _C.accent),
            _resumenFila(Icons.calendar_month_rounded, 'Días de acceso', '$diasGanados días', _C.success),
            if (_planSel!.ahorro > 0) _resumenFila(Icons.savings_rounded, 'Ahorro vs mensual', '- \$${_planSel!.ahorro} USD', _C.success),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Total a pagar', style: GoogleFonts.dmSans(color: Colors.white60, fontSize: 14)),
                Row(children: [
                  if (_planSel!.ahorro > 0) ...[
                    Text('\$${_planSel!.precioBase}',
                        style: GoogleFonts.dmSans(
                          color: Colors.white24,
                          fontSize: 13,
                          decoration: TextDecoration.lineThrough,
                        )),
                    const SizedBox(width: 8),
                  ],
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('\$${_planSel!.precio} USD',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        )),
                    Text('= ${_planSel!.precioCopTexto}',
                        style: GoogleFonts.dmSans(
                          color: Colors.white54,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        )),
                    Text('tasa del día: ${PreciosService.tasaTexto} COP/USD',
                        style: GoogleFonts.dmSans(
                          color: Colors.white30,
                          fontSize: 9.5,
                        )),
                  ]),
                ]),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _resumenFila(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Text('$label:', style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 12.5)),
        const Spacer(),
        Text(value, style: GoogleFonts.dmSans(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Botones de pago (Mercado Pago · Rapid · ePayco; PayPal opcional) ──
  Widget _buildBotones() {
    return Column(children: [
      // Mercado Pago SOLO en Colombia (su cuenta solo cobra allá).
      if (_mercadoPagoVisible)
        _buildBotonPago(
          MetodoPago.mercadoPago,
          'Pagar con Mercado Pago',
          Icons.account_balance_wallet_rounded,
          const [Color(0xFF00B1EA), Color(0xFF1A73E8)],
          const Color(0xFF00B1EA),
        ),
      if (_rapidVisible) ...[
        const SizedBox(height: 12),
        _buildBotonPago(
          MetodoPago.rapid,
          'Pagar con Rapid (PayU)',
          Icons.credit_card_rounded,
          const [Color(0xFF00C6AE), Color(0xFF0F766E)],
          const Color(0xFF00C6AE),
        ),
      ],
      // ePayco: solo si el VPS lo tiene en producción.
      if (_epaycoVisible) ...[
        const SizedBox(height: 12),
        _buildBotonPago(
          MetodoPago.epayco,
          'Pagar con ePayco',
          Icons.credit_score_rounded,
          const [Color(0xFF001E42), Color(0xFF00A0DF)],
          const Color(0xFF00A0DF),
        ),
      ],
      // Aviso cuando Mercado Pago está oculto por el país.
      if (!_mercadoPagoVisible) ...[
        const SizedBox(height: 12),
        _buildAvisoPais(),
      ],
      // Aviso cuando el plan supera el tope de monto de ePayco.
      if (_epaycoMontoExcedido) ...[
        const SizedBox(height: 12),
        _buildAvisoMonto(),
      ],
      // PayPal desactivado por ahora (_kPayPalHabilitado = false).
      if (_kPayPalHabilitado) ...[
        const SizedBox(height: 12),
        _buildBotonPago(
          MetodoPago.paypal,
          'Pagar con PayPal',
          Icons.payments_rounded,
          const [Color(0xFF0070BA), Color(0xFF003087)],
          const Color(0xFF0070BA),
        ),
      ],
      // Sin ninguna pasarela para este país: pedimos que nos escriban.
      if (_sinPasarelas) ...[
        const SizedBox(height: 12),
        _buildAvisoSinPago(),
      ],
    ]);
  }

  // ── Aviso: todavía no hay pasarela habilitada para este país ──
  Widget _buildAvisoSinPago() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _C.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.primary.withOpacity(0.25)),
      ),
      child: Row(children: [
        Icon(Icons.support_agent_rounded, color: _C.primary, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Estamos habilitando los pagos para tu país. Escríbenos por WhatsApp y activamos tu plan manualmente.',
            style: GoogleFonts.dmSans(color: Colors.white60, fontSize: 11.5),
          ),
        ),
      ]),
    );
  }

  // ── Aviso: el plan elegido supera el tope de monto de ePayco ──
  Widget _buildAvisoMonto() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _C.warning.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.warning.withOpacity(0.25)),
      ),
      child: Row(children: [
        Icon(Icons.speed_rounded, color: _C.warning, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'ePayco no acepta este monto (su máximo es \$${PreciosService.formatoCop(PreciosService.epaycoMontoMax)} COP). '
            'Elegí un plan menor o pagalo con Mercado Pago.',
            style: GoogleFonts.dmSans(color: Colors.white60, fontSize: 11.5),
          ),
        ),
      ]),
    );
  }

  // ── Aviso: Mercado Pago solo está disponible en Colombia ──
  Widget _buildAvisoPais() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _C.warning.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.warning.withOpacity(0.25)),
      ),
      child: Row(children: [
        Icon(Icons.public_rounded, color: _C.warning, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Mercado Pago solo está disponible en Colombia. Usa otra pasarela para pagar desde tu país.',
            style: GoogleFonts.dmSans(color: Colors.white60, fontSize: 11.5),
          ),
        ),
      ]),
    );
  }

  Widget _buildBotonPago(
    MetodoPago metodo,
    String label,
    IconData icon,
    List<Color> gradiente,
    Color shadow,
  ) {
    final cargando = _metodoCargando == metodo;
    final activo = _planSel != null && !_isLoading;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: activo ? LinearGradient(colors: gradiente, begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
          color: activo ? null : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          boxShadow: activo ? [BoxShadow(color: shadow.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 8))] : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: activo ? () => _renovar(metodo) : null,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white.withOpacity(0.1),
            child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (cargando)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white.withOpacity(0.6)),
                    ),
                  )
                else
                  Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  _planSel != null ? '$label · \$${_planSel!.precio} USD' : 'Selecciona un plan',
                  style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotaSeguridad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(children: [
        Icon(Icons.verified_user_rounded, color: Colors.white24, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Al renovar, tu acceso se activa inmediatamente y recibirás confirmación por WhatsApp.',
            style: GoogleFonts.dmSans(color: Colors.white30, fontSize: 11),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════
//  PLAN CARD
// ═══════════════════════════════════════
class _PlanCard extends StatelessWidget {
  final Plan plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: selected ? plan.color.withOpacity(0.15) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? plan.color : Colors.white.withOpacity(0.1),
            width: selected ? 1.8 : 1,
          ),
          boxShadow: selected ? [BoxShadow(color: plan.color.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))] : [],
        ),
        child: Stack(children: [
          if (plan.destacado)
            Positioned(
              top: -8,
              right: -8,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: plan.color.withOpacity(0.15),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: selected ? plan.color.withOpacity(0.25) : plan.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(plan.icon, color: plan.color, size: 16),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: selected ? plan.color.withOpacity(0.25) : Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(plan.badge,
                        style: GoogleFonts.dmSans(
                          color: selected ? plan.color : Colors.white54,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(plan.duracion,
                      style: GoogleFonts.dmSans(
                        color: selected ? Colors.white : Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: 1),
                  Text('\$${plan.precio} USD',
                      style: GoogleFonts.dmSans(
                        color: selected ? plan.color : Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      )),
                  Text('= ${plan.precioCopTexto}',
                      style: GoogleFonts.dmSans(
                        color: Colors.white30,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      )),
                  if (plan.ahorro > 0)
                    Text('Ahorras \$${plan.ahorro}',
                        style: GoogleFonts.dmSans(
                          color: const Color(0xFF22C55E).withOpacity(selected ? 1 : 0.6),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ))
                  else
                    Text('Precio estándar', style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.2), fontSize: 9.5)),
                ]),
              ],
            ),
          ),
          if (selected)
            Positioned(
              top: 9,
              right: 9,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: plan.color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
              ),
            ).animate().scaleXY(begin: 0, end: 1, duration: 200.ms, curve: Curves.elasticOut),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════
//  FONDO PAINTER
// ═══════════════════════════════════════
class _FondoPainter extends CustomPainter {
  final Animation<double> animation;
  _FondoPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0F172A), Color(0xFF0D1321)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final t = animation.value;

    void drawCircle(double cx, double cy, double r, Color color, double opacity) {
      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }

    drawCircle(-40, size.height * 0.15 + math.sin(t * 2 * math.pi) * 20, 180, const Color(0xFF7C3AED), 0.04);
    drawCircle(size.width + 40, size.height * 0.55 + math.cos(t * 2 * math.pi) * 15, 150, const Color(0xFF1A73E8), 0.05);
    drawCircle(size.width * 0.5, size.height * 0.85, 100, const Color(0xFF00C6AE), 0.03);

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 0.5;
    const spacing = 44.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height * 0.45), gridPaint);
    }
  }

  @override
  bool shouldRepaint(_FondoPainter old) => true;
}
