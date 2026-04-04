import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
  static const Color darkCard = Color(0xFF1E293B);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPri = Color(0xFF0F172A);
  static const Color textSec = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
}

// ─────────────────────────────────────────────
//  WIDGET: CAMPO DE AUTH
// ─────────────────────────────────────────────
class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: _C.textSec,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: isPassword && !passwordVisible,
          keyboardType: keyboardType,
          autofillHints: isPassword ? [AutofillHints.password] : [AutofillHints.email],
          validator: validator != null ? (val) => validator!(val) : null,
          style: GoogleFonts.spaceGrotesk(
            color: _C.textPri,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.spaceGrotesk(
              color: _C.textSec.withOpacity(0.6),
              fontSize: 13,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 8, 8),
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
                    child: Icon(
                      passwordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: _C.textSec,
                      size: 20,
                    ),
                  )
                : null,
            filled: true,
            fillColor: _C.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _C.border, width: 1.2),
              borderRadius: BorderRadius.circular(14),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _C.primary, width: 1.8),
              borderRadius: BorderRadius.circular(14),
            ),
            errorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _C.danger, width: 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _C.danger, width: 1.8),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  MAIN WIDGET
// ─────────────────────────────────────────────
class LoginWidget extends StatefulWidget {
  const LoginWidget({super.key});

  static String routeName = 'login';
  static String routePath = 'login';

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> with TickerProviderStateMixin {
  late LoginModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = false;
  // 0 = login, 1 = crear cuenta
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LoginModel());

    _model.tabBarController = TabController(
      vsync: this,
      length: 2,
      initialIndex: 0,
    )..addListener(() => safeSetState(() {}));

    _model.emailAddressCreateTextController ??= TextEditingController();
    _model.emailAddressCreateFocusNode ??= FocusNode();
    _model.passwordCreateTextController ??= TextEditingController();
    _model.passwordCreateFocusNode ??= FocusNode();
    _model.emailAddressTextController ??= TextEditingController();
    _model.emailAddressFocusNode ??= FocusNode();
    _model.passwordTextController ??= TextEditingController();
    _model.passwordFocusNode ??= FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  // ── Login ──
  Future<void> _signIn() async {
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
        context.goNamedAuth(HomeWidget.routeName, context.mounted);
      }
    } catch (e) {
      _showError('Error al iniciar sesión: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Crear cuenta ──
  Future<void> _createAccount() async {
    setState(() => _isLoading = true);
    try {
      GoRouter.of(context).prepareAuthEvent();
      final user = await authManager.createAccountWithEmail(
        context,
        _model.emailAddressCreateTextController!.text.trim(),
        _model.passwordCreateTextController!.text,
      );
      if (user == null) return;
      if (mounted) {
        context.goNamedAuth(HomeWidget.routeName, context.mounted);
      }
    } catch (e) {
      _showError('Error al crear cuenta: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Google ──
  Future<void> _signInGoogle() async {
    setState(() => _isLoading = true);
    try {
      GoRouter.of(context).prepareAuthEvent();
      final user = await authManager.signInWithGoogle(context);
      if (user == null) return;
      if (mounted) {
        context.goNamedAuth(HomeWidget.routeName, context.mounted);
      }
    } catch (e) {
      _showError('Error con Google: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(msg, style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        ),
      ]),
      backgroundColor: _C.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: _C.dark,
        body: Stack(
          children: [
            // ── Fondo con gradiente + círculos decorativos ──
            _buildBackground(),

            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  children: [
                    // ── Logo ──
                    _buildLogo().animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),

                    const SizedBox(height: 24),

                    // ── Card de formulario ──
                    _buildFormCard()
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 150.ms)
                        .slideY(begin: 0.08, end: 0)
                        .scaleXY(begin: 0.96, end: 1.0, delay: 150.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  FONDO
  // ─────────────────────────────────────────
  Widget _buildBackground() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_C.dark, Color(0xFF0D2137)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // Círculo decorativo superior
        Positioned(
          top: -60,
          right: -60,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.primary.withOpacity(0.08),
            ),
          ),
        ),
        // Círculo decorativo inferior
        Positioned(
          bottom: -80,
          left: -40,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.accent.withOpacity(0.06),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  //  LOGO
  // ─────────────────────────────────────────
  Widget _buildLogo() {
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 8),
      child: Column(
        children: [
          // Logo con imagen
          Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: const DecorationImage(
                fit: BoxFit.contain,
                image: AssetImage('assets/icon.png'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'StarkGo ISP',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Gestión profesional de clientes',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  CARD PRINCIPAL
  // ─────────────────────────────────────────
  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Tab selector ──
          _buildTabSelector(),

          // ── Contenido del tab ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _tab == 1 ? _buildCrearCuenta() : _buildLogin(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  TAB SELECTOR
  // ─────────────────────────────────────────
  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _TabBtn(
              label: 'Iniciar Sesión',
              selected: _tab == 0,
              onTap: () => setState(() => _tab = 0),
            ),
            _TabBtn(
              label: 'Crear Cuenta',
              selected: _tab == 1,
              onTap: () => setState(() => _tab = 1),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  LOGIN
  // ─────────────────────────────────────────
  Widget _buildLogin() {
    return Padding(
      key: const ValueKey('login'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bienvenido de vuelta',
            style: GoogleFonts.spaceGrotesk(
              color: _C.textPri,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ingresa tus credenciales para continuar',
            style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13),
          ),
          const SizedBox(height: 20),

          _AuthField(
            controller: _model.emailAddressTextController!,
            focusNode: _model.emailAddressFocusNode!,
            label: 'CORREO ELECTRÓNICO',
            hint: 'tu@correo.com',
            icon: Icons.email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (val) => _model.emailAddressTextControllerValidator.asValidator(context)?.call(val),
          ),
          const SizedBox(height: 14),

          _AuthField(
            controller: _model.passwordTextController!,
            focusNode: _model.passwordFocusNode!,
            label: 'CONTRASEÑA',
            hint: '••••••••',
            icon: Icons.lock_rounded,
            isPassword: true,
            passwordVisible: _model.passwordVisibility,
            onTogglePassword: () => safeSetState(() => _model.passwordVisibility = !_model.passwordVisibility),
            validator: (val) => _model.passwordTextControllerValidator.asValidator(context)?.call(val),
          ),
          const SizedBox(height: 22),

          // ── Botón Sign In ──
          _buildGradientButton(
            label: 'Iniciar Sesión',
            icon: Icons.login_rounded,
            onTap: _isLoading ? null : _signIn,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 16),

          // ── Divider ──
          _buildDivider(),
          const SizedBox(height: 16),

          // ── Google ──
          _buildGoogleButton(),
          const SizedBox(height: 8),

          // ── Olvidé contraseña ──
          Center(
            child: TextButton(
              onPressed: () {},
              child: Text(
                '¿Olvidaste tu contraseña?',
                style: GoogleFonts.spaceGrotesk(
                  color: _C.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  CREAR CUENTA
  // ─────────────────────────────────────────
  Widget _buildCrearCuenta() {
    return Padding(
      key: const ValueKey('crear'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Crear cuenta',
            style: GoogleFonts.spaceGrotesk(
              color: _C.textPri,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Completa el formulario para registrarte',
            style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13),
          ),
          const SizedBox(height: 20),

          _AuthField(
            controller: _model.emailAddressCreateTextController!,
            focusNode: _model.emailAddressCreateFocusNode!,
            label: 'CORREO ELECTRÓNICO',
            hint: 'tu@correo.com',
            icon: Icons.email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (val) => _model.emailAddressCreateTextControllerValidator.asValidator(context)?.call(val),
          ),
          const SizedBox(height: 14),

          _AuthField(
            controller: _model.passwordCreateTextController!,
            focusNode: _model.passwordCreateFocusNode!,
            label: 'CONTRASEÑA',
            hint: '••••••••',
            icon: Icons.lock_rounded,
            isPassword: true,
            passwordVisible: _model.passwordCreateVisibility,
            onTogglePassword: () => safeSetState(() => _model.passwordCreateVisibility = !_model.passwordCreateVisibility),
            validator: (val) => _model.passwordCreateTextControllerValidator.asValidator(context)?.call(val),
          ),
          const SizedBox(height: 22),

          // ── Botón Crear ──
          _buildGradientButton(
            label: 'Crear Cuenta',
            icon: Icons.person_add_rounded,
            onTap: _isLoading ? null : _createAccount,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 16),

          // ── Divider ──
          _buildDivider(),
          const SizedBox(height: 16),

          // ── Google ──
          _buildGoogleButton(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  BOTÓN GRADIENTE
  // ─────────────────────────────────────────
  Widget _buildGradientButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: isLoading
              ? null
              : const LinearGradient(
                  colors: [_C.primary, _C.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: isLoading ? _C.border : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isLoading
              ? []
              : [
                  BoxShadow(
                    color: _C.primary.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: isLoading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(_C.textSec),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('Cargando...',
                            style: GoogleFonts.spaceGrotesk(
                              color: _C.textSec,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          label,
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  DIVIDER
  // ─────────────────────────────────────────
  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: _C.border, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'o continúa con',
            style: GoogleFonts.spaceGrotesk(
              color: _C.textSec,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(child: Divider(color: _C.border, height: 1)),
      ],
    );
  }

  // ─────────────────────────────────────────
  //  BOTÓN GOOGLE
  // ─────────────────────────────────────────
  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _signInGoogle,
        style: OutlinedButton.styleFrom(
          backgroundColor: _C.surface,
          side: BorderSide(color: _C.border, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FaIcon(FontAwesomeIcons.google, size: 18, color: Color(0xFFDB4437)),
            const SizedBox(width: 10),
            Text(
              'Continuar con Google',
              style: GoogleFonts.spaceGrotesk(
                color: _C.textPri,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TAB BUTTON
// ─────────────────────────────────────────────
class _TabBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          height: 40,
          decoration: BoxDecoration(
            color: selected ? _C.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: selected ? _C.primary : _C.textSec,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
