import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/nav/nav.dart';
import '/index.dart';
import '/pages/renovar_membresia/renovar_membresia_widget.dart';

class SplashWidget extends StatefulWidget {
  const SplashWidget({super.key});
  static String routeName = 'Splash';
  static String routePath = 'splash';

  @override
  State<SplashWidget> createState() => _SplashWidgetState();
}

class _SplashWidgetState extends State<SplashWidget> {
  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    // 1. Esperar que Firebase Auth restaure la sesión completamente
    //    ANTES del delay visual — así el token está listo cuando naveguemos
    final user = await FirebaseAuth.instance.authStateChanges().first;

    // 2. Mostrar splash por 3 segundos
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // 3. Si no hay sesión → Login
    if (!AppStateNotifier.instance.loggedIn || user == null) {
      context.goNamed(LoginWidget.routeName);
      return;
    }

    // 4. Refrescar token y esperar que se propague internamente en el SDK
    try {
      await user.getIdToken(true);
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (_) {}

    if (!mounted) return;

    // 5. Verificar fecha de vencimiento en Firestore
    try {
      final doc = await FirebaseFirestore.instance.collection('user').doc(user.uid).get();
      final ts = doc.data()?['fechaVencimiento'] as Timestamp?;

      if (!mounted) return;

      if (ts != null && DateTime.now().isAfter(ts.toDate())) {
        context.goNamed(RenovarMembresiaWidget.routeName);
      } else {
        context.goNamed(HomeWidget.routeName);
      }
    } catch (_) {
      if (mounted) context.goNamed(HomeWidget.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1A3A5C),
              Color(0xFF1A73E8),
              Color(0xFF00C6AE),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),

            // ── Logo ──
            Image.asset(
              'assets/icon.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ).animate().fadeIn(duration: 800.ms).scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1.0, 1.0),
                  duration: 800.ms,
                  curve: Curves.easeOutBack,
                ),

            const SizedBox(height: 32),

            // ── Nombre ──
            Text(
              'StarkGo',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 400.ms).slideY(
                  begin: 0.3,
                  end: 0,
                  duration: 600.ms,
                  delay: 400.ms,
                ),

            const SizedBox(height: 8),

            // ── Subtítulo ──
            Text(
              'Panel de gestión',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white60,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 600.ms),

            const Spacer(flex: 2),

            // ── Loader ──
            Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: Column(children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(
                      Colors.white.withOpacity(0.5),
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 900.ms),
                const SizedBox(height: 12),
                Text(
                  'Cargando...',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 1000.ms),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
