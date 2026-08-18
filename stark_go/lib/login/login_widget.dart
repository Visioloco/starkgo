import 'package:stark_go/pages/Registro/registro_widget.dart';
import 'package:stark_go/pages/activar_membresia/activar_membresia_widget.dart';
import 'package:stark_go/pages/renovar_membresia/renovar_membresia_widget.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_model.dart';
export 'login_model.dart';

// ─────────────────────────────────────────────
//  PALETA
// ─────────────────────────────────────────────
class _C {
  static const Color primary = Color(0xFF1A73E8);
  static const Color accent = Color(0xFF00C6AE);
  static const Color danger = Color(0xFFE53935);
  static const Color dark = Color(0xFF0F172A);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPri = Color(0xFF0F172A);
  static const Color textSec = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color surfaceDim = Color(0xFFF1F5F9);
}

// ─────────────────────────────────────────────
//  CAMPO DE AUTH
// ─────────────────────────────────────────────
class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label, hint;
  final IconData icon;
  final bool isPassword;
  final bool passwordVisible;
  final VoidCallback? onTogglePassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _AuthField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.passwordVisible = false,
    this.onTogglePassword,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 7),
        child: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            color: _C.textSec,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
      TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: isPassword && !passwordVisible,
        keyboardType: keyboardType,
        autofillHints: isPassword ? [AutofillHints.password] : [AutofillHints.email],
        validator: validator,
        style: GoogleFonts.spaceGrotesk(
          color: _C.textPri,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.5), fontSize: 13),
          prefixIcon: Container(
            margin: const EdgeInsets.fromLTRB(14, 9, 10, 9),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _C.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: _C.primary, size: 16),
          ),
          suffixIcon: isPassword
              ? GestureDetector(
                  onTap: onTogglePassword,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Icon(
                      passwordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: _C.textSec,
                      size: 20,
                    ),
                  ),
                )
              : null,
          filled: true,
          fillColor: _C.surfaceDim,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: _C.border, width: 1.2),
            borderRadius: BorderRadius.circular(14),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: _C.primary, width: 2),
            borderRadius: BorderRadius.circular(14),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: _C.danger, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: _C.danger, width: 2),
            borderRadius: BorderRadius.circular(14),
          ),
          errorStyle: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 11),
        ),
      ),
    ]);
  }
}

// ═════════════════════════════════════════════
//  MAIN WIDGET
// ═════════════════════════════════════════════
class LoginWidget extends StatefulWidget {
  const LoginWidget({super.key});

  static String routeName = 'login';
  static String routePath = 'login';

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> with SingleTickerProviderStateMixin {
  late LoginModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LoginModel());
    _model.emailAddressTextController ??= TextEditingController();
    _model.emailAddressFocusNode ??= FocusNode();
    _model.passwordTextController ??= TextEditingController();
    _model.passwordFocusNode ??= FocusNode();

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.92, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      GoRouter.of(context).prepareAuthEvent();
      final user = await authManager.signInWithEmail(
        context,
        _model.emailAddressTextController!.text.trim(),
        _model.passwordTextController!.text,
      );
      if (user == null) return;
      if (mounted) {
        SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ));
        context.goNamedAuth(HomeWidget.routeName, context.mounted);
      }
    } catch (e) {
      _showError('Correo o contraseña incorrectos');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Iniciar sesión con Google ──────────────
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      GoRouter.of(context).prepareAuthEvent();
      final user = await authManager.signInWithGoogle(context);
      if (user == null) return;

      if (!mounted) return;
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ));

      // Verificar si el usuario ya existe en Firestore
      final uid = user.uid;
      final email = user.email ?? '';
      var doc = await FirebaseFirestore.instance.collection('user').doc(uid).get();

      // ── Si no existe con el uid de Google, buscar por email ──
      // Esto ocurre cuando la cuenta fue creada con email/contraseña
      // y luego se intenta entrar con Google (que genera un uid distinto).
      if (!doc.exists && email.isNotEmpty) {
        final query = await FirebaseFirestore.instance.collection('user').where('email', isEqualTo: email).limit(1).get();

        if (query.docs.isNotEmpty) {
          final existingDoc = query.docs.first;
          final existingUid = existingDoc.id;

          // Vincular la cuenta existente al nuevo uid de Google
          // (copiar el documento al nuevo uid y eliminar el antiguo)
          final existingData = existingDoc.data();
          await FirebaseFirestore.instance.collection('user').doc(uid).set({
            ...existingData,
            'uid': uid,
            'email': email,
          }, SetOptions(merge: true));

          // Eliminar el documento antiguo para evitar duplicados
          if (existingUid != uid) {
            await FirebaseFirestore.instance.collection('user').doc(existingUid).delete();
          }

          // Recargar el documento con el nuevo uid
          doc = await FirebaseFirestore.instance.collection('user').doc(uid).get();
        }
      }

      if (!doc.exists) {
        // Usuario nuevo → crear documento y enviar a elegir membresía
        final partesNombre = (user.displayName ?? '').trim().split(' ');
        final nombre = partesNombre.isNotEmpty ? partesNombre.first : '';
        final apellido = partesNombre.length > 1 ? partesNombre.sublist(1).join(' ') : '';

        await FirebaseFirestore.instance.collection('user').doc(uid).set({
          'uid': uid,
          'email': email,
          'nombre': nombre,
          'apellido': apellido,
          'telefono': '',
          'activo': false,
          'rol': 'operador',
          'planMembresia': '',
          'mesesMembresia': 0,
          'fechaVencimiento': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 1)),
          ),
          'created_time': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          context.pushNamed(ActivarMembresiaWidget.routeName);
        }
        return;
      }

      // Usuario existente → verificar membresía
      final data = doc.data()!;

      final ts = data['fechaVencimiento'] as Timestamp?;
      final activo = data['activo'] ?? false;

      if (ts != null && DateTime.now().isAfter(ts.toDate())) {
        // Membresía vencida → renovar
        if (mounted) {
          context.goNamed(RenovarMembresiaWidget.routeName);
        }
      } else if (activo == true) {
        // Membresía activa → Home
        if (mounted) {
          context.goNamedAuth(HomeWidget.routeName, context.mounted);
        }
      } else {
        // Sin membresía activa → elegir membresía
        if (mounted) {
          context.pushNamed(ActivarMembresiaWidget.routeName);
        }
      }
    } catch (e) {
      if (mounted) _showError('No se pudo iniciar sesión con Google');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.spaceGrotesk(color: Colors.white))),
      ]),
      backgroundColor: _C.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ═══════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: _C.dark,
        body: Stack(children: [
          _buildBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Form(
                key: _formKey,
                child: Column(children: [
                  const SizedBox(height: 40),
                  _buildLogo().animate().fadeIn(duration: 500.ms).slideY(begin: -0.08, end: 0, curve: Curves.easeOut),
                  const SizedBox(height: 36),
                  _buildCard().animate().fadeIn(duration: 500.ms, delay: 180.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
                  const SizedBox(height: 20),

                  // ── Botón Registro ──
                  _buildRegistroButton().animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.05, end: 0),

                  const SizedBox(height: 16),
                  _buildFooter().animate().fadeIn(duration: 400.ms, delay: 400.ms),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  FONDO ANIMADO
  // ─────────────────────────────────────────
  Widget _buildBackground() {
    return Stack(children: [
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0F1E), Color(0xFF0D2137), Color(0xFF071A2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
      ),
      Positioned(
        top: -80,
        right: -80,
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Transform.scale(
            scale: _pulseAnim.value,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_C.primary.withOpacity(0.18), _C.primary.withOpacity(0.0)],
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: -100,
        left: -60,
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Transform.scale(
            scale: 1.1 - (_pulseAnim.value - 0.92) * 0.5,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_C.accent.withOpacity(0.12), _C.accent.withOpacity(0.0)],
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, _C.primary.withOpacity(0.6), _C.accent.withOpacity(0.6), Colors.transparent],
            ),
          ),
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────
  //  LOGO
  // ─────────────────────────────────────────
  Widget _buildLogo() {
    return Column(children: [
      Stack(alignment: Alignment.center, children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [_C.primary.withOpacity(0.25), Colors.transparent],
            ),
          ),
        ),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_C.primary, _C.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: _C.primary.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8)),
              BoxShadow(color: _C.accent.withOpacity(0.2), blurRadius: 40, spreadRadius: 4),
            ],
          ),
          child: const Icon(Icons.wifi_tethering_rounded, color: Colors.white, size: 38),
        ),
      ]),
      const SizedBox(height: 18),
      Text(
        'StarkGo ISP',
        style: GoogleFonts.spaceGrotesk(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      const SizedBox(height: 6),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: const BoxDecoration(color: _C.accent, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(
          'Panel de administración',
          style: GoogleFonts.spaceGrotesk(color: Colors.white54, fontSize: 13, letterSpacing: 0.3),
        ),
        const SizedBox(width: 8),
        Container(width: 6, height: 6, decoration: const BoxDecoration(color: _C.primary, shape: BoxShape.circle)),
      ]),
    ]);
  }

  // ─────────────────────────────────────────
  //  CARD DE LOGIN
  // ─────────────────────────────────────────
  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 40, offset: const Offset(0, 16)),
          BoxShadow(color: _C.primary.withOpacity(0.08), blurRadius: 60, spreadRadius: 2),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _C.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.lock_open_rounded, color: _C.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Iniciar Sesión', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 20, fontWeight: FontWeight.w800)),
              Text('Acceso exclusivo para operadores', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
            ]),
          ]),
          const SizedBox(height: 28),
          Divider(color: _C.border, height: 1),
          const SizedBox(height: 24),
          _AuthField(
            controller: _model.emailAddressTextController!,
            focusNode: _model.emailAddressFocusNode!,
            label: 'CORREO ELECTRÓNICO',
            hint: 'correo@starkgo.com',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (val) {
              if (val == null || val.isEmpty) return 'Ingresa tu correo';
              if (!val.contains('@')) return 'Correo inválido';
              return null;
            },
          ),
          const SizedBox(height: 18),
          _AuthField(
            controller: _model.passwordTextController!,
            focusNode: _model.passwordFocusNode!,
            label: 'CONTRASEÑA',
            hint: '••••••••••',
            icon: Icons.shield_rounded,
            isPassword: true,
            passwordVisible: _model.passwordVisibility,
            onTogglePassword: () => safeSetState(() => _model.passwordVisibility = !_model.passwordVisibility),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Ingresa tu contraseña';
              if (val.length < 6) return 'Mínimo 6 caracteres';
              return null;
            },
          ),
          const SizedBox(height: 28),
          _buildLoginButton(),
          const SizedBox(height: 18),

          // ── Separador "o" ──
          Row(children: [
            Expanded(child: Divider(color: _C.border, thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('o', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
            ),
            Expanded(child: Divider(color: _C.border, thickness: 1)),
          ]),
          const SizedBox(height: 18),

          // ── Botón Continuar con Google ──
          _buildGoogleButton(),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.verified_user_rounded, color: Color(0xFF22C55E), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Acceso restringido · Solo cuentas autorizadas',
                  style: GoogleFonts.spaceGrotesk(color: const Color(0xFF166534), fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: _isLoading
              ? null
              : const LinearGradient(
                  colors: [_C.primary, Color(0xFF0F5BBE), _C.accent],
                  stops: [0.0, 0.5, 1.0],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: _isLoading ? _C.border : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isLoading
              ? []
              : [
                  BoxShadow(color: _C.primary.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
                  BoxShadow(color: _C.accent.withOpacity(0.15), blurRadius: 30, spreadRadius: 2),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : _signIn,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white.withOpacity(0.1),
            child: Center(
              child: _isLoading
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(_C.textSec)),
                      ),
                      const SizedBox(width: 10),
                      Text('Verificando...', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 15, fontWeight: FontWeight.w600)),
                    ])
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.login_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text('Ingresar al Panel',
                          style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    ]),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  BOTÓN CONTINUAR CON GOOGLE
  // ─────────────────────────────────────────
  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _signInWithGoogle,
          borderRadius: BorderRadius.circular(16),
          splashColor: _C.primary.withOpacity(0.08),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.border, width: 1.2),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Center(
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(_C.primary)),
                    )
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      // Logo real de Google (G multicolor)
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Stack(alignment: Alignment.center, children: [
                          // Fondo blanco
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          // G multicolor (4 colores del logo de Google)
                          CustomPaint(
                            size: const Size(22, 22),
                            painter: _GoogleLogoPainter(),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Continuar con Google',
                        style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ]),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  BOTÓN REGISTRO (reemplaza WhatsApp)
  // ─────────────────────────────────────────
  Widget _buildRegistroButton() {
    return GestureDetector(
      onTap: () => context.pushNamed(RegistroWidget.routeName),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _C.accent.withOpacity(0.35), width: 1.2),
        ),
        child: Row(children: [
          // Ícono
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_C.primary, _C.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: _C.primary.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '¿No tienes cuenta?',
                style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'Crear una cuenta nueva',
                style: GoogleFonts.spaceGrotesk(color: _C.accent, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _C.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.accent.withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                'Registrar',
                style: GoogleFonts.spaceGrotesk(color: _C.accent, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios_rounded, color: _C.accent, size: 11),
            ]),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  FOOTER
  // ─────────────────────────────────────────
  Widget _buildFooter() {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 30, height: 1, color: Colors.white12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('StarkGo ISP v1.0.0+5', style: GoogleFonts.spaceGrotesk(color: Colors.white24, fontSize: 11)),
        ),
        Container(width: 30, height: 1, color: Colors.white12),
      ]),
      const SizedBox(height: 8),
      Text(
        '© 2025 StarkGo · Todos los derechos reservados',
        style: GoogleFonts.spaceGrotesk(color: Colors.white12, fontSize: 10),
        textAlign: TextAlign.center,
      ),
    ]);
  }
}

// ─────────────────────────────────────────
//  PAINTER: LOGO REAL DE GOOGLE (G multicolor)
// ─────────────────────────────────────────
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final r = w / 2;

    // Colores oficiales de Google
    const blue = Color(0xFF4285F4);
    const red = Color(0xFFEA4335);
    const yellow = Color(0xFFFBBC05);
    const green = Color(0xFF34A853);

    // ── G azul (parte superior izquierda) ──
    final bluePaint = Paint()
      ..color = blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.16
      ..strokeCap = StrokeCap.round;

    // Arco superior (azul)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r * 0.62),
      -0.35 * 3.14159, // ~ -63°
      1.9 * 3.14159, // ~ 342°
      false,
      bluePaint,
    );

    // ── G rojo (parte inferior izquierda) ──
    final redPaint = Paint()
      ..color = red
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.16
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r * 0.62),
      1.55 * 3.14159, // ~ 279°
      0.9 * 3.14159, // ~ 162°
      false,
      redPaint,
    );

    // ── G amarillo (parte inferior derecha) ──
    final yellowPaint = Paint()
      ..color = yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.16
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r * 0.62),
      2.45 * 3.14159, // ~ 441°
      0.9 * 3.14159, // ~ 162°
      false,
      yellowPaint,
    );

    // ── G verde (parte superior derecha) ──
    final greenPaint = Paint()
      ..color = green
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.16
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r * 0.62),
      3.35 * 3.14159, // ~ 603°
      0.9 * 3.14159, // ~ 162°
      false,
      greenPaint,
    );

    // ── Barra horizontal (verde) ──
    canvas.drawLine(
      Offset(center.dx + r * 0.15, center.dy),
      Offset(center.dx + r * 0.62, center.dy),
      greenPaint,
    );

    // ── Barra vertical (azul) ──
    canvas.drawLine(
      Offset(center.dx, center.dy - r * 0.15),
      Offset(center.dx, center.dy - r * 0.62),
      bluePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
