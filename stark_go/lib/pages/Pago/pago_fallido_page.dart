import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../plan_model.dart';
import '../renovar_membresia/renovar_membresia_widget.dart';

class PagoFallidoPage extends StatefulWidget {
  final Plan plan;
  final bool esPendiente;

  const PagoFallidoPage({
    super.key,
    required this.plan,
    this.esPendiente = false,
  });

  @override
  State<PagoFallidoPage> createState() => _PagoFallidoPageState();
}

class _PagoFallidoPageState extends State<PagoFallidoPage> with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    HapticFeedback.vibrate();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _bgController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Color get _color => widget.esPendiente ? const Color(0xFFF59E0B) : const Color(0xFFE53935);

  IconData get _icono => widget.esPendiente ? Icons.hourglass_empty_rounded : Icons.cancel_rounded;

  String get _titulo => widget.esPendiente ? 'Pago pendiente' : 'Pago rechazado';

  String get _subtitulo => widget.esPendiente
      ? 'Tu pago está siendo procesado.\nTe notificaremos cuando se confirme.'
      : 'No pudimos procesar tu pago.\nPor favor intenta con otro método.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _FallidoPainter(
              animation: _bgController,
              esPendiente: widget.esPendiente,
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(children: [
              const SizedBox(height: 30),

              // ── Ícono con shake ──
              AnimatedBuilder(
                animation: _shakeController,
                builder: (_, child) {
                  final shake = math.sin(_shakeController.value * math.pi * 6) * (1 - _shakeController.value) * 8;
                  return Transform.translate(offset: Offset(shake, 0), child: child);
                },
                child: Stack(alignment: Alignment.center, children: [
                  Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: _color.withOpacity(0.06))),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _color.withOpacity(0.1),
                      border: Border.all(color: _color.withOpacity(0.3), width: 1.5),
                    ),
                  ),
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [_color, _color.withOpacity(0.7)]),
                      boxShadow: [BoxShadow(color: _color.withOpacity(0.45), blurRadius: 22, offset: const Offset(0, 8))],
                    ),
                    child: Icon(_icono, color: Colors.white, size: 36),
                  ),
                ]),
              ).animate().scaleXY(begin: 0.3, end: 1, duration: 500.ms, curve: Curves.elasticOut).fadeIn(duration: 400.ms),

              const SizedBox(height: 28),

              Text(_titulo, style: GoogleFonts.dmSans(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800))
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 300.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms, delay: 300.ms),

              const SizedBox(height: 8),

              Text(_subtitulo, textAlign: TextAlign.center, style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 14))
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 400.ms),

              const SizedBox(height: 32),

              // ── Card razones ──
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _color.withOpacity(0.25), width: 1.2),
                ),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: _color.withOpacity(0.08),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                      border: Border(bottom: BorderSide(color: _color.withOpacity(0.12))),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline_rounded, color: _color, size: 16),
                      const SizedBox(width: 8),
                      Text(widget.esPendiente ? '¿Qué significa esto?' : 'Posibles motivos',
                          style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                        children: widget.esPendiente
                            ? [
                                _razon(Icons.schedule_rounded, 'El banco está verificando tu pago', _color),
                                _razon(Icons.notifications_rounded, 'Recibirás notificación cuando se apruebe', _color),
                                _razon(Icons.support_agent_rounded, 'Si tienes dudas, contacta soporte', _color),
                              ]
                            : [
                                _razon(Icons.credit_card_off_rounded, 'Fondos insuficientes en la tarjeta', _color),
                                _razon(Icons.lock_rounded, 'Tarjeta bloqueada o datos incorrectos', _color),
                                _razon(Icons.wifi_off_rounded, 'Problema de conexión durante el pago', _color),
                              ]),
                  ),
                ]),
              ).animate().fadeIn(duration: 400.ms, delay: 500.ms).slideY(begin: 0.06, end: 0, duration: 400.ms, delay: 500.ms),

              const SizedBox(height: 24),

              // ── Plan recordatorio ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.plan.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.plan.icon, color: widget.plan.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Plan seleccionado', style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 11)),
                      Text('${widget.plan.duracion} · \$${widget.plan.precio} USD',
                          style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  Text('Guardado', style: GoogleFonts.dmSans(color: Colors.white30, fontSize: 11)),
                ]),
              ).animate().fadeIn(duration: 400.ms, delay: 600.ms),

              const SizedBox(height: 28),

              // ── Botón reintentar ──
              SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient:
                        LinearGradient(colors: [_color, _color.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: _color.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 6))],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const RenovarMembresiaWidget()),
                        (route) => route.isFirst,
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(widget.esPendiente ? Icons.refresh_rounded : Icons.replay_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text(widget.esPendiente ? 'Verificar estado' : 'Intentar de nuevo',
                            style: GoogleFonts.dmSans(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 700.ms),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child:
                    Text('Volver al inicio', style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w600)),
              ).animate().fadeIn(duration: 400.ms, delay: 800.ms),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _razon(IconData icon, String texto, Color color) {
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
        Expanded(
          child: Text(texto, style: GoogleFonts.dmSans(color: Colors.white60, fontSize: 12.5)),
        ),
      ]),
    );
  }
}

class _FallidoPainter extends CustomPainter {
  final Animation<double> animation;
  final bool esPendiente;

  _FallidoPainter({required this.animation, required this.esPendiente}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final color = esPendiente ? const Color(0xFFF59E0B) : const Color(0xFFE53935);
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF0F172A),
          esPendiente ? const Color(0xFF1C1400) : const Color(0xFF1A0000),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final t = animation.value;
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = color.withOpacity(0.04);
    canvas.drawCircle(Offset(-30, size.height * 0.15 + math.sin(t * 2 * math.pi) * 15), 160, paint);
    paint.color = color.withOpacity(0.03);
    canvas.drawCircle(Offset(size.width + 30, size.height * 0.7 + math.cos(t * 2 * math.pi) * 10), 120, paint);
  }

  @override
  bool shouldRepaint(_FallidoPainter old) => true;
}
