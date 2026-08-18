import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stark_go/pages/activar_membresia/activar_membresia_widget.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

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
//  CAMPO REUTILIZABLE
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
        validator: validator,
        style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w500),
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
//  WIDGET PRINCIPAL
// ═════════════════════════════════════════════
class RegistroWidget extends StatefulWidget {
  const RegistroWidget({super.key});

  static String routeName = 'Registro';
  static String routePath = 'registro';

  @override
  State<RegistroWidget> createState() => _RegistroWidgetState();
}

class _RegistroWidgetState extends State<RegistroWidget> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final scaffoldKey = GlobalKey<ScaffoldState>();

  // ── Controladores ──
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  // ── FocusNodes ──
  final _nombreFocus = FocusNode();
  final _apellidoFocus = FocusNode();
  final _telefonoFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _passVisible = false;
  bool _confirmVisible = false;
  bool _isLoading = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.92, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _nombreFocus.dispose();
    _apellidoFocus.dispose();
    _telefonoFocus.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  // ── Registro + guardar en Firestore + navegar a planes ──
  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // 1. Preparar evento de autenticación
      GoRouter.of(context).prepareAuthEvent();

      // 2. Crear cuenta con email y contraseña
      final user = await authManager.createAccountWithEmail(
        context,
        _emailCtrl.text.trim(),
        _passCtrl.text,
      );
      if (user == null) return;

      // 3. Guardar datos extra en Firestore (colección "user")
      await FirebaseFirestore.instance.collection('user').doc(user.uid).set({
        'uid': user.uid,
        'nombre': _nombreCtrl.text.trim(),
        'apellido': _apellidoCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'activo': false, // se activa al pagar
        'rol': 'operador',
        'planMembresia': '',
        'mesesMembresia': 0,
        'fechaVencimiento': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 1)),
        ),
        'created_time': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 4. Navegar a escoger membresía
      if (mounted) {
        context.pushNamed(ActivarMembresiaWidget.routeName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.error_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Error al registrar: $e',
                style: GoogleFonts.spaceGrotesk(color: Colors.white),
              ),
            ),
          ]),
          backgroundColor: const Color(0xFF0F172A), // color oscuro del gradiente top
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Registrarse con Google ──
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
          context.goNamed('RenovarMembresia');
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.error_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No se pudo iniciar sesión con Google',
                style: GoogleFonts.spaceGrotesk(color: Colors.white),
              ),
            ),
          ]),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: _C.surface,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(children: [
              // ── Header decorativo ──
              _buildHeader(),
              // ── Formulario ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: Form(
                  key: _formKey,
                  child: Column(children: [
                    // Título
                    _buildTitulo().animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms),

                    const SizedBox(height: 28),

                    // ── Sección: Datos personales ──
                    _seccionLabel('DATOS PERSONALES', Icons.person_rounded).animate().fadeIn(duration: 400.ms, delay: 80.ms),

                    const SizedBox(height: 12),

                    // Nombre y Apellido en fila
                    Row(
                      children: [
                        Expanded(
                          child: _AuthField(
                            controller: _nombreCtrl,
                            focusNode: _nombreFocus,
                            label: 'NOMBRE',
                            hint: 'Juan',
                            icon: Icons.badge_rounded,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AuthField(
                            controller: _apellidoCtrl,
                            focusNode: _apellidoFocus,
                            label: 'APELLIDO',
                            hint: 'Pérez',
                            icon: Icons.badge_outlined,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 400.ms, delay: 120.ms),

                    const SizedBox(height: 16),

                    _AuthField(
                      controller: _telefonoCtrl,
                      focusNode: _telefonoFocus,
                      label: 'TELÉFONO (WhatsApp)',
                      hint: '+58 412 0000000',
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Requerido';
                        if (v.trim().length < 7) return 'Número muy corto';
                        return null;
                      },
                    ).animate().fadeIn(duration: 400.ms, delay: 160.ms),

                    const SizedBox(height: 24),

                    // ── Sección: Acceso ──
                    _seccionLabel('ACCESO A LA CUENTA', Icons.lock_rounded).animate().fadeIn(duration: 400.ms, delay: 200.ms),

                    const SizedBox(height: 12),

                    _AuthField(
                      controller: _emailCtrl,
                      focusNode: _emailFocus,
                      label: 'CORREO ELECTRÓNICO',
                      hint: 'correo@ejemplo.com',
                      icon: Icons.email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Requerido';
                        if (!v.contains('@')) return 'Correo inválido';
                        return null;
                      },
                    ).animate().fadeIn(duration: 400.ms, delay: 240.ms),

                    const SizedBox(height: 16),

                    _AuthField(
                      controller: _passCtrl,
                      focusNode: _passFocus,
                      label: 'CONTRASEÑA',
                      hint: 'Mínimo 6 caracteres',
                      icon: Icons.lock_rounded,
                      isPassword: true,
                      passwordVisible: _passVisible,
                      onTogglePassword: () => setState(() => _passVisible = !_passVisible),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido';
                        if (v.length < 6) return 'Mínimo 6 caracteres';
                        return null;
                      },
                    ).animate().fadeIn(duration: 400.ms, delay: 280.ms),

                    const SizedBox(height: 16),

                    _AuthField(
                      controller: _confirmPassCtrl,
                      focusNode: _confirmFocus,
                      label: 'CONFIRMAR CONTRASEÑA',
                      hint: 'Repite tu contraseña',
                      icon: Icons.lock_outline_rounded,
                      isPassword: true,
                      passwordVisible: _confirmVisible,
                      onTogglePassword: () => setState(() => _confirmVisible = !_confirmVisible),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido';
                        if (v != _passCtrl.text) return 'Las contraseñas no coinciden';
                        return null;
                      },
                    ).animate().fadeIn(duration: 400.ms, delay: 320.ms),

                    const SizedBox(height: 32),

                    // ── Botón registrar ──
                    _buildBoton()
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 380.ms)
                        .slideY(begin: 0.05, end: 0, duration: 400.ms, delay: 380.ms),

                    const SizedBox(height: 18),

                    // ── Separador "o" ──
                    Row(children: [
                      Expanded(child: Divider(color: _C.border, thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('o', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
                      ),
                      Expanded(child: Divider(color: _C.border, thickness: 1)),
                    ]).animate().fadeIn(duration: 400.ms, delay: 420.ms),

                    const SizedBox(height: 18),

                    // ── Botón Continuar con Google ──
                    _buildGoogleButton().animate().fadeIn(duration: 400.ms, delay: 440.ms),

                    const SizedBox(height: 20),

                    // ── Ir a login ──
                    _buildLoginLink().animate().fadeIn(duration: 400.ms, delay: 480.ms),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Header azul con logo ──
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1A73E8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(children: [
        // Círculos decorativos
        Positioned(
          right: -30,
          top: -30,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
        ),
        Positioned(
          left: -20,
          bottom: -20,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.accent.withOpacity(0.08),
            ),
          ),
        ),
        // Contenido
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                ),
                child: const Icon(Icons.wifi_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 10),
              Text('StarkGo',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  )),
              Text('Crea tu cuenta',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white60,
                    fontSize: 12,
                  )),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildTitulo() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 24),
      Text('Registro',
          style: GoogleFonts.spaceGrotesk(
            color: _C.textPri,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          )),
      const SizedBox(height: 4),
      Text('Completa tus datos para crear tu cuenta',
          style: GoogleFonts.spaceGrotesk(
            color: _C.textSec,
            fontSize: 13,
          )),
    ]);
  }

  Widget _seccionLabel(String label, IconData icon) {
    return Row(children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _C.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: _C.primary, size: 14),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          color: _C.textSec,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: Divider(color: _C.border, thickness: 1)),
    ]);
  }

  Widget _buildBoton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _isLoading
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1A73E8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: _isLoading ? _C.surfaceDim : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isLoading
              ? []
              : [
                  BoxShadow(
                    color: _C.primary.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : _registrar,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: _isLoading
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(_C.textSec.withOpacity(0.6)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Creando cuenta...',
                          style: GoogleFonts.spaceGrotesk(
                            color: _C.textSec,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          )),
                    ])
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Text('Crear cuenta y elegir plan',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          )),
                    ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Botón Continuar con Google ──
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

  Widget _buildLoginLink() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('¿Ya tienes cuenta? ', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13)),
      GestureDetector(
        onTap: () => context.pushNamed('login'),
        child: Text(
          'Inicia sesión',
          style: GoogleFonts.spaceGrotesk(
            color: _C.primary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
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
