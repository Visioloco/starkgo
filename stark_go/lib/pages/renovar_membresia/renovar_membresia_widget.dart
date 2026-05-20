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
import '../Pago/pago_webview_page.dart';

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
  DateTime? _fechaActualVencimiento;
  String _nombreUsuario = '';
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  // ── URL del VPS ──
  static const String _vpsUrl = 'http://5.161.88.42:3000';

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
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
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

  // ══════════════════════════════════════════
  //  _renovar — llama al VPS en lugar de
  //  Firebase Functions
  // ══════════════════════════════════════════
  Future<void> _renovar() async {
    if (_planSel == null) {
      _showError('Selecciona un plan para continuar');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Sesión expirada. Vuelve a iniciar sesión.');
        return;
      }

      // Obtener token Firebase para autenticar con el VPS
      final token = await user.getIdToken(true);

      final response = await http
          .post(
            Uri.parse('$_vpsUrl/mp/crear-preferencia'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'planId': _planSel!.id,
              'nombre': _nombreUsuario,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        _showError('Error del servidor (${response.statusCode})');
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final url = data['initPoint'] as String;

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PagoWebViewPage(
              url: url,
              plan: _planSel!,
            ),
          ),
        );
      }
    } on TimeoutException {
      _showError('Tiempo de espera agotado. Verifica tu conexión.');
    } catch (e) {
      _showError('Error al iniciar el pago: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatFecha(DateTime d) => '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

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
                  const SizedBox(height: 20),
                  _buildBoton()
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 240.ms)
                      .slideY(begin: 0.06, end: 0, duration: 400.ms, delay: 240.ms),
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
                color: _C.danger.withOpacity(0.12 + pulse * 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _C.danger.withOpacity(0.4 + pulse * 0.2)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _C.danger.withOpacity(pulse),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text('Vencida', style: GoogleFonts.dmSans(color: _C.danger, fontSize: 11.5, fontWeight: FontWeight.w700)),
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
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.purple.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(color: _C.purple.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 10)),
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
                  gradient: const LinearGradient(
                    colors: [_C.danger, Color(0xFFFF6B6B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: _C.danger.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Icon(Icons.lock_clock_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Acceso suspendido', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(_nombreUsuario.isNotEmpty ? 'Hola, $_nombreUsuario' : 'Tu membresía ha vencido',
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
                    'Venció el',
                    _fechaActualVencimiento != null ? _formatFecha(_fechaActualVencimiento!) : '—',
                    _C.danger,
                    Icons.event_busy_rounded,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white.withOpacity(0.08)),
                Expanded(
                  child: _heroStat(
                    'Días vencida',
                    _fechaActualVencimiento != null ? '${DateTime.now().difference(_fechaActualVencimiento!).inDays}d' : '—',
                    _C.warning,
                    Icons.timer_off_rounded,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white.withOpacity(0.08)),
                Expanded(
                  child: _heroStat('Estado', 'Inactivo', _C.danger, Icons.block_rounded),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _C.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.warning.withOpacity(0.25)),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: _C.warning, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Para recuperar el acceso completo a StarkGo, selecciona un plan y completa el pago.',
                    style: GoogleFonts.dmSans(color: _C.warning, fontSize: 11.5),
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
                  Text('\$${_planSel!.precio} USD',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      )),
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

  Widget _buildBoton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _isLoading
              ? null
              : LinearGradient(
                  colors: _planSel != null ? [_planSel!.color, _C.primary] : [_C.purple, _C.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: _isLoading ? Colors.white.withOpacity(0.08) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isLoading || _planSel == null
              ? []
              : [
                  BoxShadow(
                    color: (_planSel?.color ?? _C.primary).withOpacity(0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : _renovar,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white.withOpacity(0.1),
            child: Center(
              child: _isLoading
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white.withOpacity(0.5)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Procesando renovación...',
                          style: GoogleFonts.dmSans(color: Colors.white60, fontSize: 15, fontWeight: FontWeight.w600)),
                    ])
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(_planSel != null ? 'Pagar \$${_planSel!.precio} USD' : 'Selecciona un plan',
                          style: GoogleFonts.dmSans(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
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
