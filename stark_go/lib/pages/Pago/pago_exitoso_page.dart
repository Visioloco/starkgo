import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';

import '../../plan_model.dart';
import '../../services/bienvenida_service.dart';

class PagoExitosoPage extends StatefulWidget {
  final Plan plan;
  const PagoExitosoPage({super.key, required this.plan});

  @override
  State<PagoExitosoPage> createState() => _PagoExitosoPageState();
}

class _PagoExitosoPageState extends State<PagoExitosoPage> with TickerProviderStateMixin {
  late AnimationController _particleController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Marcar que el usuario tiene una bienvenida pendiente por ver.
    // Se mostrará UNA sola vez cuando navegue al Home.
    BienvenidaService.marcarBienvenidaPendiente(widget.plan);
    HapticFeedback.heavyImpact();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _particleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatFecha(DateTime d) => '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  DateTime get _nuevaFecha {
    final now = DateTime.now();
    return DateTime(now.year, now.month + widget.plan.meses, now.day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _ExitosoPainter(animation: _particleController),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(children: [
              const SizedBox(height: 30),

              // ── Ícono animado ──
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, child) {
                  final pulse = 0.5 + _pulseController.value * 0.5;
                  return Stack(alignment: Alignment.center, children: [
                    Container(
                      width: 130 + pulse * 10,
                      height: 130 + pulse * 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF22C55E).withOpacity(0.06 * pulse),
                      ),
                    ),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF22C55E).withOpacity(0.1),
                        border: Border.all(
                          color: const Color(0xFF22C55E).withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                    ),
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF22C55E).withOpacity(0.5),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 38),
                    ),
                  ]);
                },
              ).animate().scaleXY(begin: 0.3, end: 1, duration: 600.ms, curve: Curves.elasticOut).fadeIn(duration: 400.ms),

              const SizedBox(height: 28),

              Text('¡Pago exitoso!', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800))
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 300.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms, delay: 300.ms),

              const SizedBox(height: 8),

              Text(
                'Tu membresía ha sido activada\ncorrectamente en StarkGo',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 14),
              ).animate().fadeIn(duration: 400.ms, delay: 400.ms),

              const SizedBox(height: 32),

              // ── Card detalles ──
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withOpacity(0.3),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withOpacity(0.08),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                      border: Border(bottom: BorderSide(color: const Color(0xFF22C55E).withOpacity(0.15))),
                    ),
                    child: Row(children: [
                      Icon(widget.plan.icon, color: const Color(0xFF22C55E), size: 16),
                      const SizedBox(width: 8),
                      Text('Detalles de tu membresía',
                          style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Activa',
                            style: GoogleFonts.dmSans(color: const Color(0xFF22C55E), fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(children: [
                      _fila(Icons.workspace_premium_rounded, 'Plan', widget.plan.duracion, const Color(0xFF22C55E)),
                      _fila(Icons.attach_money_rounded, 'Monto pagado', '\$${widget.plan.precio} USD', const Color(0xFF1A73E8)),
                      _fila(Icons.event_available_rounded, 'Válido hasta', _formatFecha(_nuevaFecha), const Color(0xFF00C6AE)),
                      _fila(Icons.calendar_month_rounded, 'Días de acceso', '${_nuevaFecha.difference(DateTime.now()).inDays} días',
                          const Color(0xFF7C3AED)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            const Color(0xFF22C55E).withOpacity(0.12),
                            const Color(0xFF16A34A).withOpacity(0.06),
                          ]),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.2)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.wifi_rounded, color: Color(0xFF22C55E), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tu acceso a internet StarkGo está activo y listo para usar.',
                              style: GoogleFonts.dmSans(color: const Color(0xFF22C55E), fontSize: 12),
                            ),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ).animate().fadeIn(duration: 400.ms, delay: 500.ms).slideY(begin: 0.06, end: 0, duration: 400.ms, delay: 500.ms),

              const SizedBox(height: 20),

              // ── Nota WhatsApp ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF25D366).withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Recibirás confirmación por WhatsApp en los próximos minutos.',
                      style: GoogleFonts.dmSans(color: const Color(0xFF25D366), fontSize: 11.5),
                    ),
                  ),
                ]),
              ).animate().fadeIn(duration: 400.ms, delay: 600.ms),

              const SizedBox(height: 28),

              // ── Botón inicio ──
              SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF22C55E).withOpacity(0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).popUntil((r) => r.isFirst);
                        context.goNamed(HomeWidget.routeName);
                      },
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.home_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text('Volver al inicio', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 700.ms).slideY(begin: 0.06, end: 0, duration: 400.ms, delay: 700.ms),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _fila(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
}

class _ExitosoPainter extends CustomPainter {
  final Animation<double> animation;
  _ExitosoPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0F172A), Color(0xFF052E16)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final t = animation.value;
    final paint = Paint()..style = PaintingStyle.fill;
    final rng = math.Random(42);

    for (int i = 0; i < 18; i++) {
      final seed = i / 18.0;
      final x = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final y = (baseY - t * size.height * 0.4 + size.height) % size.height;
      final r = 2.0 + rng.nextDouble() * 3;
      paint.color = const Color(0xFF22C55E).withOpacity(0.06 + math.sin(seed * math.pi + t * 2 * math.pi) * 0.04);
      canvas.drawCircle(Offset(x, y), r, paint);
    }

    paint.color = const Color(0xFF22C55E).withOpacity(0.04);
    canvas.drawCircle(Offset(-30, size.height * 0.2), 160, paint);
    paint.color = const Color(0xFF1A73E8).withOpacity(0.04);
    canvas.drawCircle(Offset(size.width + 30, size.height * 0.7), 130, paint);
  }

  @override
  bool shouldRepaint(_ExitosoPainter old) => true;
}
