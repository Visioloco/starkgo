import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'space_background.dart' show SpaceBackground, Personaje;

// ══════════════════════════════════════════════════════════════
//  AppBackground — elige el fondo según el modo activo.
//  Escucha a AppTheme por sí mismo, así que funciona aunque lo
//  uses como `const AppBackground()`.
// ══════════════════════════════════════════════════════════════
class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppTheme.instance,
      builder: (context, _) => AppTheme.instance.esOscuro
          ? const SpaceBackground(key: ValueKey('fondo-noche'))
          : const DayBackground(key: ValueKey('fondo-dia')),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  DayBackground — cielo de día, limpio y suave.
//
//  Capas (de atrás hacia adelante):
//   1. Degradado #F8FAFC → #F1F5F9
//   2. Sol: PNG (assets/images/sol.png), sin dibujo por código
//   3. Nubes en 7 posiciones, blancas con sombra azulada suave
//   4. Motas de luz flotando
//   5. Bruma de suelo + personaje (opcional)
//
//  · Sin luna, sin estrellas, sin agujero negro.
//  · Un solo AnimationController (60 s). Todo se mueve con ciclos
//    ENTEROS, así que el bucle no da saltos.
//  · RepaintBoundary + IgnorePointer: no cuesta al hacer scroll.
// ══════════════════════════════════════════════════════════════
class DayBackground extends StatefulWidget {
  const DayBackground({
    super.key,
    this.intensidad = 1.0,
    this.mostrarPersonaje = true,
    this.rutaPersonaje = 'assets/images/personaje.png',
    // Posición del sol como fracción de la pantalla (x, y).
    // (0.86, 0.06) = esquina superior derecha, medio escondido tras
    // la barra superior. Baja "y" si lo quieres más visible.
    this.solCentro = const Offset(0.86, 0.40),
    // PNG del sol, ya subido en assets/images/sol.png
    this.rutaSol = 'assets/images/sol.png',
    // Tamaño (ancho y alto) del PNG del sol en píxeles lógicos.
    this.tamanoSol = 140,
  });

  /// Multiplica la opacidad de todo (0.5 = más sobrio).
  final double intensidad;
  final bool mostrarPersonaje;
  final String rutaPersonaje;
  final Offset solCentro;
  final String rutaSol;
  final double tamanoSol;

  @override
  State<DayBackground> createState() => _DayBackgroundState();
}

class _DayBackgroundState extends State<DayBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final op = widget.intensidad.clamp(0.0, 1.0);
    return RepaintBoundary(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
            ),
          ),
          child: Stack(
            children: [
              // 1) Sol en PNG, anclado sobre solCentro
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;
                    final cx = w * widget.solCentro.dx;
                    final cy = h * widget.solCentro.dy;
                    return Stack(
                      children: [
                        Positioned(
                          left: cx - widget.tamanoSol / 2,
                          top: cy - widget.tamanoSol / 2,
                          width: widget.tamanoSol,
                          height: widget.tamanoSol,
                          child: Opacity(
                            opacity: op,
                            child: Image.asset(
                              widget.rutaSol,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              // 2) Nubes
              Positioned.fill(
                child: CustomPaint(painter: _NubesPainter(_c, op)),
              ),
              // 3) Motas de luz
              Positioned.fill(
                child: CustomPaint(painter: _MotasPainter(_c, op)),
              ),
              // 4) Bruma de suelo (estática)
              Positioned.fill(
                child: CustomPaint(painter: _BrumaPainter(op)),
              ),
              // 5) Personaje, igual que en noche
              if (widget.mostrarPersonaje)
                Positioned.fill(
                  child: Personaje(anim: _c, op: op, rutaImagen: widget.rutaPersonaje),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Nubes
//  Cada una: (y, ancho, fase, alfa, fase de vaivén), como
//  fracciones de la pantalla. Todas cruzan una vez por vuelta.
// ══════════════════════════════════════════════════════════════
class _Nube {
  const _Nube(this.y, this.ancho, this.fase, this.alfa, this.vaiven);
  final double y;
  final double ancho;
  final double fase;
  final double alfa;
  final double vaiven;
}

class _NubesPainter extends CustomPainter {
  _NubesPainter(this.anim, this.op) : super(repaint: anim);

  final Animation<double> anim;
  final double op;

  static const List<_Nube> _nubes = [
    _Nube(0.07, 0.42, 0.05, 0.80, 0.0),
    _Nube(0.19, 0.26, 0.55, 0.60, 0.3),
    _Nube(0.33, 0.36, 0.80, 0.65, 0.6),
    _Nube(0.47, 0.24, 0.30, 0.50, 0.1),
    _Nube(0.60, 0.40, 0.65, 0.60, 0.8),
    _Nube(0.74, 0.28, 0.15, 0.50, 0.5),
    _Nube(0.86, 0.36, 0.90, 0.55, 0.2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    for (final n in _nubes) {
      final ancho = size.width * n.ancho;
      // Recorrido de -ancho/2 a size.width+ancho/2: entra y sale por
      // completo. fase + t da exactamente 1 cruce por vuelta.
      final avance = (n.fase + t) % 1.0;
      final cx = -ancho / 2 + avance * (size.width + ancho);
      final cy = size.height * n.y + math.sin((t * 3 + n.vaiven) * 2 * math.pi) * 4;
      _dibujarNube(canvas, Offset(cx, cy), ancho, n.alfa * op);
    }
  }

  void _dibujarNube(Canvas canvas, Offset c, double ancho, double alfa) {
    final h = ancho * 0.42;
    final nube = Path()
      ..addOval(Rect.fromCenter(center: c.translate(-ancho * 0.28, h * 0.12), width: ancho * 0.34, height: h * 0.62))
      ..addOval(Rect.fromCenter(center: c.translate(-ancho * 0.08, -h * 0.14), width: ancho * 0.42, height: h * 0.95))
      ..addOval(Rect.fromCenter(center: c.translate(ancho * 0.16, -h * 0.22), width: ancho * 0.46, height: h * 1.05))
      ..addOval(Rect.fromCenter(center: c.translate(ancho * 0.34, h * 0.10), width: ancho * 0.30, height: h * 0.60))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: c.translate(0, h * 0.22), width: ancho * 0.86, height: h * 0.50),
        Radius.circular(h * 0.25),
      ));

    // Sombra azulada suave: es lo que hace visible una nube blanca
    // sobre un fondo casi blanco.
    canvas.drawPath(
      nube.shift(const Offset(0, 6)),
      Paint()
        ..color = const Color(0xFF94A3B8).withOpacity(0.20 * alfa)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    // Cuerpo blanco con borde ligeramente difuso.
    canvas.drawPath(
      nube,
      Paint()
        ..color = Colors.white.withOpacity(alfa)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
  }

  @override
  bool shouldRepaint(_NubesPainter old) => false;
}

// ══════════════════════════════════════════════════════════════
//  Motas de luz — polvo dorado flotando en órbitas pequeñas.
//  Frecuencias enteras (1..3) → bucle perfecto.
// ══════════════════════════════════════════════════════════════
class _Mota {
  _Mota({
    required this.x,
    required this.y,
    required this.radio,
    required this.fase,
    required this.fx,
    required this.fy,
    required this.ft,
    required this.amp,
  });
  final double x;
  final double y;
  final double radio;
  final double fase;
  final int fx;
  final int fy;
  final int ft;
  final double amp;
}

class _MotasPainter extends CustomPainter {
  _MotasPainter(this.anim, this.op) : super(repaint: anim);

  final Animation<double> anim;
  final double op;

  static final List<_Mota> _motas = () {
    final rnd = math.Random(21);
    return List.generate(22, (_) {
      return _Mota(
        x: rnd.nextDouble(),
        y: rnd.nextDouble(),
        radio: 1.0 + rnd.nextDouble() * 1.4,
        fase: rnd.nextDouble(),
        fx: rnd.nextInt(3) + 1,
        fy: rnd.nextInt(3) + 1,
        ft: rnd.nextInt(3) + 2,
        amp: 10 + rnd.nextDouble() * 18,
      );
    });
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    for (final m in _motas) {
      final x = size.width * m.x + math.sin((t * m.fx + m.fase) * 2 * math.pi) * m.amp;
      final y = size.height * m.y + math.cos((t * m.fy + m.fase) * 2 * math.pi) * m.amp;
      final brillo = 0.5 + 0.5 * math.sin((t * m.ft + m.fase * 3) * 2 * math.pi);
      final alfa = (0.15 + 0.55 * brillo) * op;
      final pos = Offset(x, y);

      canvas.drawCircle(
        pos,
        m.radio * 2.6,
        Paint()
          ..color = const Color(0xFFFDE68A).withOpacity(0.35 * alfa)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, m.radio * 1.6),
      );
      canvas.drawCircle(
        pos,
        m.radio * 0.6,
        Paint()..color = const Color(0xFFFCD34D).withOpacity(0.75 * alfa),
      );
    }
  }

  @override
  bool shouldRepaint(_MotasPainter old) => false;
}

// ══════════════════════════════════════════════════════════════
//  Bruma de suelo — da base al personaje. Estática.
// ══════════════════════════════════════════════════════════════
class _BrumaPainter extends CustomPainter {
  _BrumaPainter(this.op);
  final double op;

  @override
  void paint(Canvas canvas, Size size) {
    final alto = size.height * 0.25;
    final rect = Rect.fromLTWH(0, size.height - alto, size.width, alto);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFCBD5E1).withOpacity(0.0),
            const Color(0xFFCBD5E1).withOpacity(0.35 * op),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_BrumaPainter old) => old.op != op;
}
