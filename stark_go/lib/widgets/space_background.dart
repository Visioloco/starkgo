import 'dart:math' as math;

import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════
//  SpaceBackground — fondo espacial animado (estilo "StarkGo")
//
//  Estrellas de fondo (3 capas con parpadeo y deriva), nebulosa que
//  respira, estrellas fugaces con núcleo/resplandor, un agujero negro
//  con disco de acreción (con efecto Doppler) y pulsos de energía
//  periódicos, una LUNA REAL (imagen) con glow y rotación suave,
//  un asteroide cruzando, viñeta y grano cinematográfico.
//
//  · Se dibuja con CustomPaint sobre UN solo AnimationController
//    (sin setState por frame) y va envuelto en RepaintBoundary →
//    no cuesta rendimiento al hacer scroll.
//  · El grano/viñeta son estáticos (no escuchan la animación), así
//    que se pintan una sola vez y no agregan costo por frame.
//  · La luna usa una imagen real (asset) en vez de dibujo vectorial.
//
//  Requisito en pubspec.yaml para la luna:
//    flutter:
//      assets:
//        - assets/images/luna.png
//
//  Uso:  Stack(children: [ const SpaceBackground(), ...contenido ])
// ══════════════════════════════════════════════════════════════
class SpaceBackground extends StatefulWidget {
  const SpaceBackground({
    super.key,
    this.intensidad = 1.0,
    this.rutaLuna = 'assets/images/luna.png',
    this.rutaPersonaje = 'assets/images/personaje.png',
  });

  /// Multiplica la opacidad de todo (0.5 = más sobrio, 1 = completo).
  final double intensidad;

  /// Ruta del asset de la luna (PNG, idealmente con fondo transparente).
  final String rutaLuna;

  /// Ruta del asset del personaje (PNG con fondo transparente).
  final String rutaPersonaje;

  @override
  State<SpaceBackground> createState() => _SpaceBackgroundState();
}

class _SpaceBackgroundState extends State<SpaceBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
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
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF040814), Color(0xFF0A1128)],
            ),
          ),
          child: Stack(
            children: [
              // 0) Estrellas de fondo — 3 capas con parpadeo y deriva,
              //    detrás de todo lo demás.
              Positioned.fill(
                child: CustomPaint(painter: _EstrellasPainter(_c, op)),
              ),
              // 1) Nebulosa (manchas de color que respiran)
              Positioned.fill(
                child: CustomPaint(painter: _NebulosaPainter(_c, op)),
              ),
              // 2) Destello ambiental — tinte azulado parejo en toda
              //    la pantalla, del mismo tono que el glow del
              //    personaje, con un pulso lento.
              Positioned.fill(
                child: CustomPaint(painter: _DestelloPainter(_c, op)),
              ),
              // 3) Agujero negro (arriba a la izquierda), con disco de
              //    acreción con efecto Doppler (lado que se acerca más
              //    brillante/azulado, lado que se aleja más tenue/
              //    rojizo) y pulsos de energía periódicos.
              Positioned(
                top: -60,
                left: -70,
                child: CustomPaint(
                  size: const Size(220, 220),
                  painter: _AgujeroNegroPainter(_c, op),
                ),
              ),
              // 4) Luna real (imagen) con glow y rotación suave —
              //    arriba, a un lado (como corresponde a una luna en
              //    el cielo), no en el centro de la pantalla.
              Positioned(
                top: 70,
                right: 24,
                child: LunaReal(anim: _c, op: op, tamano: 72, rutaImagen: widget.rutaLuna),
              ),
              // 5) Asteroide cruzando lento en diagonal (rompe simetría)
              Positioned.fill(
                child: CustomPaint(painter: _AsteroidePainter(_c, op)),
              ),
              // 6) Estrellas fugaces (encima de todo lo animado)
              Positioned.fill(
                child: CustomPaint(painter: _FugacesPainter(_c, op)),
              ),
              // 6.5) Personaje: fijo abajo, donde nace la pantalla,
              //      mirando el cielo (estrellas/luna). Solo un leve
              //      balanceo de respiración.
              Positioned.fill(
                child: Personaje(anim: _c, op: op, rutaImagen: widget.rutaPersonaje),
              ),
              // 7) Grano cinematográfico — estático, no escucha la
              //    animación, se pinta una sola vez (costo ínfimo).
              Positioned.fill(
                child: CustomPaint(painter: _GranoPainter(op)),
              ),
              // 8) Viñeta — oscurece bordes para dar foco al contenido.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.15,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.38 * op),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  LunaReal — imagen real de la luna con glow, rotación lenta,
//  flote y sombra de fase (iluminación direccional).
// ══════════════════════════════════════════════════════════════
class LunaReal extends StatelessWidget {
  const LunaReal({
    super.key,
    required this.anim,
    required this.op,
    this.tamano = 150,
    this.rutaImagen = 'assets/images/luna.png',
  });

  final Animation<double> anim;
  final double op;
  final double tamano;
  final String rutaImagen;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final t = anim.value * 2 * math.pi;
        final flote = math.sin(t * 3) * 6;
        // Rotación propia MUY lenta (una vuelta completa cada ~3
        // ciclos del controller) — sutil, no un giro vistoso.
        final rotacion = anim.value * 2 * math.pi * 0.34;

        return Transform.translate(
          offset: Offset(0, flote),
          child: SizedBox(
            width: tamano * 1.9,
            height: tamano * 1.9,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // 2) La luna real: recorte circular duro (ClipOval),
                //    sin ShaderMask — evita un bug conocido de Impeller
                //    donde a veces se filtra el recuadro del widget.
                Opacity(
                  opacity: op,
                  child: Transform.rotate(
                    angle: rotacion,
                    child: ClipOval(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ColorFiltered(
                            // Tinte azul-frío sutil para que combine
                            // con la paleta nocturna en vez de verse
                            // gris/blanca desentonada.
                            colorFilter: const ColorFilter.mode(
                              Color(0x2238BDF8),
                              BlendMode.overlay,
                            ),
                            child: Image.asset(
                              rutaImagen,
                              width: tamano,
                              height: tamano,
                              fit: BoxFit.cover,
                              // Si el asset no existe todavía o falla
                              // la carga, no rompe el layout.
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: tamano,
                                  height: tamano,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF9CA3AF).withOpacity(0.3),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // 3) Sombra sutil de "fase" — oscurece un borde para
                //    dar sensación de iluminación direccional, en vez
                //    de una luna plana iluminada por todos lados.
                ClipOval(
                  child: Container(
                    width: tamano,
                    height: tamano,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.35 * op),
                        ],
                        stops: const [0.55, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Personaje — parado, fijo, justo donde nace la pantalla (borde
//  inferior), mirando el cielo (estrellas/luna). Solo un leve
//  balanceo de respiración; no entra ni sale caminando.
// ══════════════════════════════════════════════════════════════
class Personaje extends StatelessWidget {
  const Personaje({
    super.key,
    required this.anim,
    required this.op,
    this.rutaImagen = 'assets/images/personaje.png',
  });

  final Animation<double> anim;
  final double op;
  final String rutaImagen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return AnimatedBuilder(
          animation: anim,
          builder: (context, _) {
            final t = anim.value; // 0..1, se repite cada 60s

            // Posición fija: parado justo donde nace la pantalla
            // (borde inferior), mirando el cielo. Solo un leve
            // balanceo de respiración, sin entrada/salida caminando.
            const reposo = Offset(0.20, 1.02);
            final bob = math.sin(t * 2 * math.pi * 1.3) * 0.004;

            final posFrac = reposo;

            final pos = Offset(
              posFrac.dx * size.width,
              (posFrac.dy + bob) * size.height,
            );

            const alto = 118.0;
            const ancho = 66.0;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: pos.dx - ancho / 2,
                  top: pos.dy - alto,
                  child: Opacity(
                    opacity: op,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          rutaImagen,
                          width: ancho,
                          height: alto,
                          fit: BoxFit.contain,
                          // Si el asset no existe todavía, dibuja una
                          // silueta simple en su lugar — no rompe el
                          // layout mientras se agrega el PNG real.
                          errorBuilder: (context, error, stackTrace) {
                            return SizedBox(
                              width: ancho,
                              height: alto,
                              child: CustomPaint(painter: _SiluetaPainter(op)),
                            );
                          },
                        ),
                        // Sombra de contacto en el suelo, sutil.
                        Container(
                          width: ancho * 0.65,
                          height: 5,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: RadialGradient(
                              colors: [
                                Colors.black.withOpacity(0.32 * op),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// Silueta humana simple de respaldo — solo se usa si personaje.png
// todavía no está agregado al proyecto, para que el layout no se
// rompa mientras tanto.
class _SiluetaPainter extends CustomPainter {
  _SiluetaPainter(this.op);
  final double op;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.55 * op);
    final cx = size.width / 2;
    canvas.drawCircle(Offset(cx, size.height * 0.14), size.width * 0.16, paint);
    final cuerpo = Path()
      ..moveTo(cx - size.width * 0.14, size.height * 0.32)
      ..lineTo(cx + size.width * 0.14, size.height * 0.32)
      ..lineTo(cx + size.width * 0.10, size.height * 0.95)
      ..lineTo(cx - size.width * 0.10, size.height * 0.95)
      ..close();
    canvas.drawPath(cuerpo, paint);
  }

  @override
  bool shouldRepaint(_SiluetaPainter old) => old.op != op;
}

// ══════════════════════════════════════════════════════════════
//  Estrellas de fondo — 3 capas (lejana/media/cercana) con distinto
//  tamaño, brillo y velocidad de parpadeo, deriva horizontal muy
//  sutil por capa (paralaje) y un halo (bloom) detrás de cada núcleo
//  para que no se vean como píxeles duros.
//
//  Las posiciones se generan una sola vez con `math.Random(seed)`
//  fijo, así no "saltan" al reconstruir el widget.
// ══════════════════════════════════════════════════════════════
class _EstrellasPainter extends CustomPainter {
  _EstrellasPainter(this.anim, this.op) : super(repaint: anim);
  final Animation<double> anim;
  final double op;

  static final List<_Estrella> _capaLejana = _generarEstrellas(70, 99, tamMin: 0.5, tamMax: 1.1);
  static final List<_Estrella> _capaMedia = _generarEstrellas(40, 42, tamMin: 1.0, tamMax: 1.8);
  static final List<_Estrella> _capaCercana = _generarEstrellas(18, 7, tamMin: 1.6, tamMax: 2.6);

  static List<_Estrella> _generarEstrellas(
    int cantidad,
    int seed, {
    required double tamMin,
    required double tamMax,
  }) {
    final rnd = math.Random(seed);
    return List.generate(cantidad, (i) {
      return _Estrella(
        x: rnd.nextDouble(),
        y: rnd.nextDouble(),
        tamano: tamMin + rnd.nextDouble() * (tamMax - tamMin),
        fase: rnd.nextDouble(),
        velocidad: 0.4 + rnd.nextDouble() * 0.9,
        brilloBase: 0.35 + rnd.nextDouble() * 0.3,
        // Ángulo propio de deriva — cada estrella viaja en su propia
        // diagonal en vez de todas moviéndose parejo horizontal.
        angulo: rnd.nextDouble() * 2 * math.pi,
      );
    });
  }

  void _pintarCapa(
    Canvas canvas,
    Size size,
    List<_Estrella> capa,
    double derivaPx,
    double brilloExtra,
  ) {
    for (final e in capa) {
      // Parpadeo: oscila entre 0 y 1 con velocidad y fase propias de
      // cada estrella, para que no titilen todas en sincronía.
      final parpadeo = 0.5 + 0.5 * math.sin((anim.value * e.velocidad + e.fase) * 2 * math.pi);
      final alfa = (e.brilloBase + parpadeo * brilloExtra).clamp(0.0, 1.0) * op;
      if (alfa <= 0.02) continue;

      // Deriva diagonal lenta y propia de cada estrella (paralaje +
      // movimiento real, no solo parpadeo) — envuelve con `%` para
      // que reaparezca del otro lado sin saltos bruscos.
      final avance = anim.value * derivaPx * e.velocidad;
      final dx = (e.x * size.width + math.cos(e.angulo) * avance) % size.width;
      final dy = (e.y * size.height + math.sin(e.angulo) * avance) % size.height;
      final pos = Offset(dx < 0 ? dx + size.width : dx, dy < 0 ? dy + size.height : dy);

      // Halo difuso detrás del núcleo (bloom).
      canvas.drawCircle(
        pos,
        e.tamano * 2.6,
        Paint()
          ..color = Colors.white.withOpacity(alfa * 0.25)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, e.tamano * 1.4),
      );
      // Núcleo nítido.
      canvas.drawCircle(
        pos,
        e.tamano * 0.5,
        Paint()..color = Colors.white.withOpacity(alfa),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _pintarCapa(canvas, size, _capaLejana, 6, 0.35);
    _pintarCapa(canvas, size, _capaMedia, 12, 0.45);
    _pintarCapa(canvas, size, _capaCercana, 20, 0.55);
  }

  @override
  bool shouldRepaint(_EstrellasPainter old) => false;
}

class _Estrella {
  _Estrella({
    required this.x,
    required this.y,
    required this.tamano,
    required this.fase,
    required this.velocidad,
    required this.brilloBase,
    required this.angulo,
  });
  final double x;
  final double y;
  final double tamano;
  final double fase;
  final double velocidad;
  final double brilloBase;
  final double angulo;
}

class _NebulosaPainter extends CustomPainter {
  _NebulosaPainter(this.anim, this.op) : super(repaint: anim);
  final Animation<double> anim;
  final double op;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    final ola = (math.sin(t * 2 * math.pi) + 1) / 2; // 0..1

    void mancha(Offset centro, double radio, Color color, double alpha) {
      final shader = RadialGradient(
        colors: [color.withOpacity(alpha * op), Colors.transparent],
      ).createShader(Rect.fromCircle(center: centro, radius: radio));
      canvas.drawRect(
        Rect.fromCircle(center: centro, radius: radio),
        Paint()..shader = shader,
      );
    }

    mancha(
      Offset(size.width * 0.20, size.height * (0.22 + ola * 0.03)),
      size.width * 1.05,
      const Color(0xFF8B5CF6),
      0.11,
    );
    mancha(
      Offset(size.width * 0.86, size.height * (0.62 - ola * 0.03)),
      size.width * 0.95,
      const Color(0xFF38BDF8),
      0.11,
    );
    mancha(
      Offset(size.width * 0.50, size.height * 0.95),
      size.width * 0.85,
      const Color(0xFFFF007A),
      0.06,
    );
    // Toque cálido sutil, para que la paleta no se sienta solo fría.
    mancha(
      Offset(size.width * 0.68, size.height * (0.12 + ola * 0.02)),
      size.width * 0.55,
      const Color(0xFFF3E5AB),
      0.045,
    );
  }

  @override
  bool shouldRepaint(_NebulosaPainter old) => false;
}

// ── Destello ambiental: el mismo tono azulado (0xFF7FB3E8) que el
//    box-shadow del personaje, pero como un tinte PAREJO en toda la
//    pantalla (misma intensidad en todos lados, no concentrado en
//    manchas ni en el borde) — para que se sienta como la misma luz
//    ambiental envolviendo todo, con un pulso lento y sutil.
class _DestelloPainter extends CustomPainter {
  _DestelloPainter(this.anim, this.op) : super(repaint: anim);
  final Animation<double> anim;
  final double op;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    final pulso = 0.75 + 0.25 * math.sin(t * 2 * math.pi * 0.5);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF7FB3E8).withOpacity(0.10 * op * pulso),
    );
  }

  @override
  bool shouldRepaint(_DestelloPainter old) => false;
}

// ── Agujero negro: dos discos elípticos girando + núcleo oscuro
//    + pulsos de energía periódicos + efecto Doppler (el lado del
//    disco que "se acerca" al observador se ve más brillante y con
//    corrimiento al azul; el lado que "se aleja" se ve más tenue y
//    con corrimiento al rojo — así como en discos de acreción reales,
//    en vez de un anillo de brillo uniforme) ──
class _AgujeroNegroPainter extends CustomPainter {
  _AgujeroNegroPainter(this.anim, this.op) : super(repaint: anim);
  final Animation<double> anim;
  final double op;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final t = anim.value * 2 * math.pi;

    void disco(double rx, double ry, double grosor, List<Color> colores, double giro) {
      canvas.save();
      canvas.translate(centro.dx, centro.dy);
      canvas.rotate(-0.24 + giro);
      final rect = Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2);

      final azulAcerca = Color.lerp(colores[0], const Color(0xFF60A5FA), 0.55)!;
      final rojoAleja = Color.lerp(colores[1], const Color(0xFFF87171), 0.45)!;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor
        ..shader = SweepGradient(
          // Estos stops rompen la simetría a propósito: pico de
          // brillo/azul cerca de 0.22 (lado que se acerca) y mínimo
          // de brillo/rojo cerca de 0.78 (lado que se aleja).
          colors: [
            colores[0].withOpacity(0),
            azulAcerca.withOpacity(0.85 * op),
            colores[1].withOpacity(0.45 * op),
            rojoAleja.withOpacity(0.22 * op),
            colores[0].withOpacity(0),
          ],
          stops: const [0.0, 0.22, 0.5, 0.78, 1.0],
        ).createShader(rect);
      canvas.drawOval(rect, paint);
      canvas.restore();
    }

    // Pulso de energía: anillo que se expande y se desvanece, en un
    // ciclo corto e independiente del giro de los discos.
    final cicloPulso = (anim.value * 3) % 1.0; // 3 pulsos por vuelta completa
    final radioPulso = 44 + cicloPulso * 130;
    final alfaPulso = (1 - cicloPulso) * 0.35 * op;
    if (alfaPulso > 0.01) {
      canvas.drawCircle(
        centro,
        radioPulso,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFF38BDF8).withOpacity(alfaPulso),
      );
    }

    disco(74, 22, 4, const [Colors.white, Colors.white], t * 0.5);
    disco(98, 30, 6, const [Color(0xFFF3E5AB), Color(0xFF38BDF8)], -t * 0.25);

    final halo = RadialGradient(
      colors: [
        Colors.black.withOpacity(0.95 * op),
        Colors.black.withOpacity(0.0),
      ],
    ).createShader(Rect.fromCircle(center: centro, radius: 62));
    canvas.drawRect(Rect.fromCircle(center: centro, radius: 62), Paint()..shader = halo);
    canvas.drawCircle(centro, 34, Paint()..color = Colors.black.withOpacity(0.9 * op));
  }

  @override
  bool shouldRepaint(_AgujeroNegroPainter old) => false;
}

// ── Asteroide: cruza lento en diagonal, con leve rotación y trail ──
class _AsteroidePainter extends CustomPainter {
  _AsteroidePainter(this.anim, this.op) : super(repaint: anim);
  final Animation<double> anim;
  final double op;

  @override
  void paint(Canvas canvas, Size size) {
    // Un solo paso lento por vuelta completa del controller (60s).
    final t = anim.value;
    final x = -30 + t * (size.width + 60);
    final y = size.height * 0.16 + math.sin(t * 2 * math.pi * 1.3) * 14;
    final pos = Offset(x, y);
    final rot = t * 6; // rotación propia, lenta

    // Trail sutil detrás del asteroide.
    final cola = pos.translate(-26, -9);
    canvas.drawLine(
      cola,
      pos,
      Paint()
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white.withOpacity(0.18 * op),
          ],
        ).createShader(Rect.fromPoints(cola, pos)),
    );

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(rot);
    final cuerpo = Paint()..color = const Color(0xFF9CA3AF).withOpacity(0.85 * op);
    final sombra = Paint()..color = const Color(0xFF4B5563).withOpacity(0.9 * op);
    canvas.drawCircle(Offset.zero, 3.4, cuerpo);
    canvas.drawCircle(const Offset(1.1, 1.0), 1.1, sombra);
    canvas.drawCircle(const Offset(-1.0, -0.6), 0.7, sombra);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AsteroidePainter old) => false;
}

// ── Estrellas fugaces: meteoros con núcleo, resplandor y cola nítida ──
class _FugacesPainter extends CustomPainter {
  _FugacesPainter(this.anim, this.op) : super(repaint: anim);
  final Animation<double> anim;
  final double op;

  // [x%, y%, retardo, duración, ánguloGrados, largo, grosor]
  static const _fugaces = <List<double>>[
    [0.05, 0.06, 0.00, 0.16, 34, 150, 2.0],
    [0.58, 0.10, 0.09, 0.14, 28, 120, 1.6],
    [0.22, 0.30, 0.20, 0.15, 40, 170, 2.2],
    [0.82, 0.42, 0.05, 0.13, 30, 110, 1.4],
    [0.08, 0.55, 0.28, 0.16, 36, 160, 2.0],
    [0.90, 0.20, 0.34, 0.14, 25, 130, 1.6],
    [0.42, 0.70, 0.24, 0.15, 32, 140, 1.8],
    [0.35, 0.05, 0.40, 0.13, 38, 120, 1.5],
    [0.68, 0.60, 0.44, 0.16, 29, 155, 2.0],
    [0.14, 0.18, 0.50, 0.14, 35, 125, 1.6],
    [0.95, 0.68, 0.56, 0.15, 33, 145, 1.9],
    [0.48, 0.35, 0.62, 0.13, 27, 115, 1.5],
    [0.26, 0.80, 0.68, 0.16, 37, 165, 2.1],
    [0.75, 0.08, 0.74, 0.14, 31, 125, 1.6],
    [0.02, 0.85, 0.80, 0.15, 39, 150, 1.9],
    [0.60, 0.88, 0.86, 0.13, 26, 110, 1.4],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final diag = size.longestSide;
    for (final f in _fugaces) {
      final retardo = f[2];
      final dur = f[3];
      var p = (anim.value - retardo) % 1.0;
      if (p < 0) p += 1.0;
      if (p > dur) continue;

      final avance = (p / dur).clamp(0.0, 1.0);
      final brillo = avance < 0.2 ? avance / 0.2 : 1.0 - math.pow((avance - 0.2) / 0.8, 1.6).toDouble();
      final alfa = brillo.clamp(0.0, 1.0) * op;
      if (alfa <= 0.02) continue;

      final anguloRad = f[4] * math.pi / 180;
      final direccion = Offset(math.cos(anguloRad), math.sin(anguloRad));
      final largo = f[5] * (diag / 520);
      final grosor = f[6];

      final inicio = Offset(size.width * f[0], size.height * f[1]);
      final pos = inicio + direccion * (largo * 2.6 * avance);
      final cola = pos - direccion * largo;

      canvas.drawLine(
        cola,
        pos,
        Paint()
          ..strokeWidth = grosor * 4
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, grosor * 2.2)
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              const Color(0xFF38BDF8).withOpacity(0.35 * alfa),
              Colors.white.withOpacity(0.55 * alfa),
            ],
          ).createShader(Rect.fromPoints(cola, pos)),
      );

      canvas.drawLine(
        cola,
        pos,
        Paint()
          ..strokeWidth = grosor
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              const Color(0xFFF3E5AB).withOpacity(0.6 * alfa),
              Colors.white.withOpacity(0.98 * alfa),
            ],
          ).createShader(Rect.fromPoints(cola, pos)),
      );

      canvas.drawCircle(
        pos,
        grosor * 2.4,
        Paint()
          ..color = Colors.white.withOpacity(0.55 * alfa)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, grosor * 1.6),
      );
      canvas.drawCircle(
        pos,
        grosor * 0.9,
        Paint()..color = Colors.white.withOpacity(0.95 * alfa),
      );
    }
  }

  @override
  bool shouldRepaint(_FugacesPainter old) => false;
}

// ── Grano cinematográfico: puntos estáticos de ruido muy sutil.
//    No escucha la animación (sin `repaint: anim`) → se pinta una
//    sola vez y no agrega costo por frame.
class _GranoPainter extends CustomPainter {
  _GranoPainter(this.op);
  final double op;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(99);
    final cantidad = (size.width * size.height / 2600).clamp(120, 900).toInt();
    final paint = Paint();
    for (var i = 0; i < cantidad; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final claro = rnd.nextBool();
      paint.color = (claro ? Colors.white : Colors.black).withOpacity((0.02 + rnd.nextDouble() * 0.025) * op);
      canvas.drawCircle(Offset(x, y), 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(_GranoPainter old) => old.op != op;
}
