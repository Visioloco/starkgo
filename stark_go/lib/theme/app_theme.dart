import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════════
//  StarkGo · Tema Día / Noche
//
//  · AppPalette  → todos los colores de UN modo (inmutable).
//  · AppColors   → acceso estático a la paleta ACTIVA
//                  (AppColors.textPri, AppColors.surface, ...).
//  · AppTheme    → controlador (ChangeNotifier) con persistencia.
//  · ThemeToggleButton → botón sol/luna para el drawer (estilo Telegram).
//  · ThemeReveal → transición circular que nace del botón.
//
//  Como AppColors lee la paleta activa, YA NO se puede usar dentro
//  de widgets `const`. Quita el `const` de los widgets que la usen.
// ══════════════════════════════════════════════════════════════

@immutable
class AppPalette {
  const AppPalette({
    required this.esOscuro,
    // Canvas
    required this.background,
    required this.drawerBg,
    // Cristal / tarjetas
    required this.surfaceSolid,
    required this.surface,
    required this.surfaceSoft,
    required this.surfaceStrong,
    required this.barra,
    required this.cardBorder,
    required this.divider,
    // Texto
    required this.textPri,
    required this.textSec,
    required this.textMuted,
    // Acentos
    required this.primary,
    required this.accent,
    required this.purple,
    required this.gold,
    required this.cyan,
    // Estados
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.neutral,
    required this.neutralBg,
    required this.danger,
    // Avatares
    required this.avatarNeutralBg,
    required this.avatarNeutralText,
    required this.avatarBronzeBg,
    required this.avatarBronzeBorder,
    required this.avatarBronzeText,
    required this.avatarRedBg,
    required this.avatarRedBorder,
    required this.avatarRedText,
    // Series de consumo
    required this.stream1,
    required this.stream2,
    required this.stream3,
    // Acción principal
    required this.brand,
    required this.brandHover,
  });

  final bool esOscuro;

  final Color background;
  final Color drawerBg;

  final Color surfaceSolid;
  final Color surface;
  final Color surfaceSoft;
  final Color surfaceStrong;

  /// Barra superior: en día es blanco ~90% para que el sol/nubes se
  /// asomen por detrás.
  final Color barra;
  final Color cardBorder;
  final Color divider;

  final Color textPri;
  final Color textSec;
  final Color textMuted;

  final Color primary;
  final Color accent;
  final Color purple;
  final Color gold;
  final Color cyan;

  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color neutral;
  final Color neutralBg;
  final Color danger;

  final Color avatarNeutralBg;
  final Color avatarNeutralText;
  final Color avatarBronzeBg;
  final Color avatarBronzeBorder;
  final Color avatarBronzeText;
  final Color avatarRedBg;
  final Color avatarRedBorder;
  final Color avatarRedText;

  final Color stream1;
  final Color stream2;
  final Color stream3;

  final Color brand;
  final Color brandHover;

  // ─────────────────────────────────────────
  //  🌙 NOCHE — idéntica a tu paleta actual
  // ─────────────────────────────────────────
  static const AppPalette noche = AppPalette(
    esOscuro: true,
    background: Color(0xFF0B0F19),
    drawerBg: Color(0xFF0B0F19),
    surfaceSolid: Color(0xFF161C2E),
    surface: Color(0xCC161C2E),
    surfaceSoft: Color(0xB3161C2E),
    surfaceStrong: Color(0xD9161C2E),
    barra: Color(0xD9161C2E),
    cardBorder: Color(0x14FFFFFF),
    divider: Color(0x0DFFFFFF),
    textPri: Color(0xFFFFFFFF),
    textSec: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    primary: Color(0xFF7FB3E8),
    accent: Color(0xFF38BDF8),
    purple: Color(0xFFA855F7),
    gold: Color(0xFFF3E5AB),
    cyan: Color(0xFF38BDF8),
    success: Color(0xFF22C55E),
    successBg: Color(0xFF052E16),
    warning: Color(0xFFF59E0B),
    warningBg: Color(0xFF451A03),
    neutral: Color(0xFF94A3B8),
    neutralBg: Color(0xFF1E293B),
    danger: Color(0xFFEF4444),
    avatarNeutralBg: Color(0xFF334155),
    avatarNeutralText: Color(0xFFE2E8F0),
    avatarBronzeBg: Color(0xFF78350F),
    avatarBronzeBorder: Color(0xFFD97706),
    avatarBronzeText: Color(0xFFFFFFFF),
    avatarRedBg: Color(0xFF7F1D1D),
    avatarRedBorder: Color(0xFFEF4444),
    avatarRedText: Color(0xFFFFFFFF),
    stream1: Color(0xFF10B981),
    stream2: Color(0xFFF97316),
    stream3: Color(0xFFA855F7),
    brand: Color(0xFF16A34A),
    brandHover: Color(0xFF15803D),
  );

  // ─────────────────────────────────────────
  //  ☀️ DÍA — según el prompt
  // ─────────────────────────────────────────
  static const AppPalette dia = AppPalette(
    esOscuro: false,
    // Canvas: #F8FAFC → #F1F5F9 (el degradado lo pinta DayBackground)
    background: Color(0xFFF8FAFC),
    drawerBg: Color(0xFFE9EFF6),
    // Tarjetas: blanco puro + borde #E2E8F0
    surfaceSolid: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFFFFFFF),
    surfaceStrong: Color(0xFFFFFFFF),
    barra: Color(0xE6FFFFFF),
    cardBorder: Color(0xFFE2E8F0),
    divider: Color(0xFFE2E8F0),
    // Texto
    textPri: Color(0xFF0F172A),
    textSec: Color(0xFF475569),
    textMuted: Color(0xFF64748B),
    // Acentos (más oscuros que en noche para tener contraste sobre blanco)
    primary: Color(0xFF2563EB),
    accent: Color(0xFF0284C7),
    purple: Color(0xFF9333EA),
    gold: Color(0xFFB45309),
    cyan: Color(0xFF0891B2),
    // Estados: fondo pastel + texto/ícono oscuro
    success: Color(0xFF15803D),
    successBg: Color(0xFFDCFCE7),
    warning: Color(0xFFB45309),
    warningBg: Color(0xFFFEF3C7),
    neutral: Color(0xFF64748B),
    neutralBg: Color(0xFFF1F5F9),
    danger: Color(0xFFDC2626),
    // Avatares
    avatarNeutralBg: Color(0xFFE2E8F0),
    avatarNeutralText: Color(0xFF334155),
    avatarBronzeBg: Color(0xFFFEF3C7),
    avatarBronzeBorder: Color(0xFFB45309),
    avatarBronzeText: Color(0xFFB45309),
    avatarRedBg: Color(0xFFFEE2E2),
    avatarRedBorder: Color(0xFFB91C1C),
    avatarRedText: Color(0xFFB91C1C),
    // Consumo
    stream1: Color(0xFF059669),
    stream2: Color(0xFFEA580C),
    stream3: Color(0xFF9333EA),
    // Botón principal
    brand: Color(0xFF22C55E),
    brandHover: Color(0xFF16A34A),
  );
}

// ─────────────────────────────────────────────
//  Acceso estático a la paleta activa.
//  Uso: AppColors.textPri, AppColors.surface, AppColors.sombra(0.4)
// ─────────────────────────────────────────────
class AppColors {
  AppColors._();

  static AppPalette get _p => AppTheme.instance.paleta;

  static bool get esOscuro => _p.esOscuro;

  static Color get background => _p.background;
  static Color get drawerBg => _p.drawerBg;
  static const Color surfaceDim = Color(0x00000000);

  static Color get surfaceSolid => _p.surfaceSolid;
  static Color get surface => _p.surface;
  static Color get surfaceSoft => _p.surfaceSoft;
  static Color get surfaceStrong => _p.surfaceStrong;
  static Color get barra => _p.barra;
  static Color get cardBorder => _p.cardBorder;
  static Color get divider => _p.divider;

  static Color get textPri => _p.textPri;
  static Color get textSec => _p.textSec;
  static Color get textMuted => _p.textMuted;

  static Color get primary => _p.primary;
  static Color get accent => _p.accent;
  static Color get purple => _p.purple;
  static Color get gold => _p.gold;
  static Color get cyan => _p.cyan;

  static Color get success => _p.success;
  static Color get successBg => _p.successBg;
  static Color get warning => _p.warning;
  static Color get warningBg => _p.warningBg;
  static Color get neutral => _p.neutral;
  static Color get neutralBg => _p.neutralBg;
  static Color get danger => _p.danger;

  static Color get avatarNeutralBg => _p.avatarNeutralBg;
  static Color get avatarNeutralText => _p.avatarNeutralText;
  static Color get avatarBronzeBg => _p.avatarBronzeBg;
  static Color get avatarBronzeBorder => _p.avatarBronzeBorder;
  static Color get avatarBronzeText => _p.avatarBronzeText;
  static Color get avatarRedBg => _p.avatarRedBg;
  static Color get avatarRedBorder => _p.avatarRedBorder;
  static Color get avatarRedText => _p.avatarRedText;

  static Color get stream1 => _p.stream1;
  static Color get stream2 => _p.stream2;
  static Color get stream3 => _p.stream3;
  static List<Color> get streams => [stream1, stream2, stream3];

  static Color get brand => _p.brand;
  static Color get brandHover => _p.brandHover;
  static Color get whatsapp => _p.brand;

  /// Sombra negra. Recibe la opacidad pensada para NOCHE (0.35–0.5);
  /// en día se atenúa a ~5% (spec: 0 4 12 rgba(0,0,0,0.05)).
  static Color sombra(double opacidadNoche) {
    return Colors.black.withOpacity(esOscuro ? opacidadNoche : opacidadNoche * 0.14);
  }
}

// ─────────────────────────────────────────────
//  Controlador del tema (singleton + persistencia)
// ─────────────────────────────────────────────
class AppTheme extends ChangeNotifier {
  AppTheme._();
  static final AppTheme instance = AppTheme._();

  static const String _prefKey = 'starkgo_tema_oscuro';

  bool _oscuro = true; // por defecto: Noche (como hoy)
  bool _cargado = false;

  bool get esOscuro => _oscuro;
  AppPalette get paleta => _oscuro ? AppPalette.noche : AppPalette.dia;

  /// Lee la preferencia guardada. Idempotente. Lo ideal es llamarla en
  /// main() antes de runApp para evitar el parpadeo del primer frame:
  ///   await AppTheme.instance.cargar();
  Future<void> cargar() async {
    if (_cargado) return;
    _cargado = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final oscuro = prefs.getBool(_prefKey) ?? true;
      if (oscuro != _oscuro) {
        _oscuro = oscuro;
        notifyListeners();
      }
    } catch (_) {
      // Sin preferencia guardada: se queda en Noche.
    }
  }

  /// Cambia el modo. Notifica de inmediato (síncrono) y guarda después.
  Future<void> establecer(bool oscuro) async {
    if (oscuro == _oscuro) return;
    _oscuro = oscuro;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, oscuro);
    } catch (_) {}
  }

  Future<void> alternar() => establecer(!_oscuro);

  /// Íconos de la barra de estado según el modo.
  static void aplicarBarraEstado() {
    final oscuro = instance.esOscuro;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: oscuro ? Brightness.light : Brightness.dark, // Android
      statusBarBrightness: oscuro ? Brightness.dark : Brightness.light, // iOS
    ));
  }
}

// ─────────────────────────────────────────────
//  Botón sol/luna (estilo Telegram) para el header del drawer.
//  `boundaryKey` es la key del RepaintBoundary que envuelve la
//  pantalla: de ahí se toma la "foto" para la transición circular.
// ─────────────────────────────────────────────
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, required this.boundaryKey});

  final GlobalKey boundaryKey;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppTheme.instance,
      builder: (context, _) {
        final oscuro = AppTheme.instance.esOscuro;
        return Tooltip(
          message: oscuro ? 'Cambiar a modo día' : 'Cambiar a modo noche',
          child: Material(
            color: AppColors.neutralBg,
            shape: CircleBorder(side: BorderSide(color: AppColors.cardBorder)),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                final box = context.findRenderObject() as RenderBox?;
                final origen = box != null && box.hasSize ? box.localToGlobal(box.size.center(Offset.zero)) : null;
                ThemeReveal.alternar(context, boundaryKey, origen);
              },
              child: SizedBox(
                width: 40,
                height: 40,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: Tween<double>(begin: 0.75, end: 1.0).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Icon(
                    // En noche muestra el sol (a donde vas); en día, la luna.
                    oscuro ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    key: ValueKey<bool>(oscuro),
                    size: 20,
                    color: oscuro ? AppColors.gold : AppColors.textSec,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  Transición circular tipo Telegram:
//  1) captura la pantalla actual,
//  2) cambia el tema por debajo,
//  3) muestra la captura vieja y un círculo que crece desde el
//     botón revela el tema nuevo.
//  Si algo falla, cambia el tema sin animación (nunca rompe).
// ─────────────────────────────────────────────
class ThemeReveal {
  ThemeReveal._();

  static bool _enCurso = false;

  static Future<void> alternar(
    BuildContext context,
    GlobalKey boundaryKey,
    Offset? origen,
  ) async {
    if (_enCurso) return;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final boundary = boundaryKey.currentContext?.findRenderObject();

    if (overlay == null || origen == null || boundary is! RenderRepaintBoundary) {
      await AppTheme.instance.alternar();
      return;
    }

    _enCurso = true;
    ui.Image? captura;
    try {
      captura = await boundary.toImage(pixelRatio: MediaQuery.of(context).devicePixelRatio);
    } catch (_) {
      captura = null;
    }
    if (captura == null) {
      _enCurso = false;
      await AppTheme.instance.alternar();
      return;
    }

    final ui.Image imagen = captura;
    final Offset centro = origen;
    final size = boundary.size;
    final radioMax = <Offset>[
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((esquina) => (esquina - centro).distance).reduce(math.max);

    final ctrl = AnimationController(
      vsync: overlay,
      duration: const Duration(milliseconds: 550),
    );
    final curva = CurvedAnimation(parent: ctrl, curve: Curves.easeInOutCubic);

    final entrada = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: AnimatedBuilder(
          animation: curva,
          builder: (_, __) => ClipPath(
            clipper: _ClipFueraDelCirculo(centro, radioMax * curva.value),
            child: SizedBox.expand(
              child: RawImage(image: imagen, fit: BoxFit.fill),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entrada);

    // notifyListeners() corre de forma síncrona: el tema nuevo se pinta
    // debajo de la captura en el mismo frame en que aparece el overlay.
    unawaited(AppTheme.instance.alternar());
    AppTheme.aplicarBarraEstado();
    await WidgetsBinding.instance.endOfFrame;

    try {
      await ctrl.forward();
    } catch (_) {
      // Overlay desmontado a mitad de animación: se limpia igual.
    } finally {
      entrada.remove();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ctrl.dispose();
        imagen.dispose();
      });
      _enCurso = false;
    }
  }
}

/// Recorta TODO menos el círculo: la captura vieja solo se ve fuera de él.
class _ClipFueraDelCirculo extends CustomClipper<Path> {
  _ClipFueraDelCirculo(this.centro, this.radio);

  final Offset centro;
  final double radio;

  @override
  Path getClip(Size size) {
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addOval(Rect.fromCircle(center: centro, radius: radio)),
    );
  }

  @override
  bool shouldReclip(covariant _ClipFueraDelCirculo old) => old.radio != radio || old.centro != centro;
}
