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
  static const Color danger = Color(0xFFEF4444);
  static const Color dark = Color(0xFF0F172A);
  static const Color bg1 = Color(0xFF13233F);
  static const Color bg2 = Color(0xFF0B1526);
  static const Color card = Color(0xFF111C33);
  static const Color cardBorder = Color(0xFF243049);
  static const Color inputBg = Color(0xFF0B1526);
  static const Color textPri = Color(0xFF0F172A);
  static const Color border = Color(0xFFE2E8F0);
  static const Color onDark = Color(0xFFF1F5F9);
  static const Color onDarkSec = Color(0xFF94A3B8);
}

// ─────────────────────────────────────────────
//  LISTA DE PAÍSES (indicativos)
// ─────────────────────────────────────────────
const _paises = [
  {'flag': '🇨🇴', 'nombre': 'Colombia', 'codigo': '+57'},
  {'flag': '🇻🇪', 'nombre': 'Venezuela', 'codigo': '+58'},
  {'flag': '🇲🇽', 'nombre': 'México', 'codigo': '+52'},
  {'flag': '🇺🇸', 'nombre': 'Estados Unidos', 'codigo': '+1'},
  {'flag': '🇦🇷', 'nombre': 'Argentina', 'codigo': '+54'},
  {'flag': '🇨🇱', 'nombre': 'Chile', 'codigo': '+56'},
  {'flag': '🇵🇪', 'nombre': 'Perú', 'codigo': '+51'},
  {'flag': '🇪🇨', 'nombre': 'Ecuador', 'codigo': '+593'},
  {'flag': '🇧🇴', 'nombre': 'Bolivia', 'codigo': '+591'},
  {'flag': '🇵🇾', 'nombre': 'Paraguay', 'codigo': '+595'},
  {'flag': '🇺🇾', 'nombre': 'Uruguay', 'codigo': '+598'},
  {'flag': '🇧🇷', 'nombre': 'Brasil', 'codigo': '+55'},
  {'flag': '🇵🇦', 'nombre': 'Panamá', 'codigo': '+507'},
  {'flag': '🇨🇷', 'nombre': 'Costa Rica', 'codigo': '+506'},
  {'flag': '🇩🇴', 'nombre': 'Rep. Dominicana', 'codigo': '+1809'},
  {'flag': '🇬🇹', 'nombre': 'Guatemala', 'codigo': '+502'},
  {'flag': '🇭🇳', 'nombre': 'Honduras', 'codigo': '+504'},
  {'flag': '🇸🇻', 'nombre': 'El Salvador', 'codigo': '+503'},
  {'flag': '🇳🇮', 'nombre': 'Nicaragua', 'codigo': '+505'},
  {'flag': '🇪🇸', 'nombre': 'España', 'codigo': '+34'},
  {'flag': '🇨🇦', 'nombre': 'Canadá', 'codigo': '+1'},
  {'flag': '🇬🇧', 'nombre': 'Reino Unido', 'codigo': '+44'},
  {'flag': '🇨🇺', 'nombre': 'Cuba', 'codigo': '+53'},
];

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
            color: _C.onDarkSec,
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
        style: GoogleFonts.spaceGrotesk(color: _C.onDark, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.spaceGrotesk(color: _C.onDarkSec.withOpacity(0.6), fontSize: 13),
          prefixIcon: Container(
            margin: const EdgeInsets.fromLTRB(14, 9, 10, 9),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _C.accent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: _C.accent, size: 16),
          ),
          suffixIcon: isPassword
              ? GestureDetector(
                  onTap: onTogglePassword,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Icon(
                      passwordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: _C.onDarkSec,
                      size: 20,
                    ),
                  ),
                )
              : null,
          filled: true,
          fillColor: _C.inputBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _C.cardBorder, width: 1.2),
            borderRadius: BorderRadius.circular(14),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _C.accent, width: 1.8),
            borderRadius: BorderRadius.circular(14),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: _C.danger, width: 1.4),
            borderRadius: BorderRadius.circular(14),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: _C.danger, width: 1.8),
            borderRadius: BorderRadius.circular(14),
          ),
          errorStyle: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 11),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────
//  CAMPO DE TELÉFONO CON INDICATIVO
// ─────────────────────────────────────────────
class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String indicativo;
  final String flag;
  final VoidCallback onSelectIndicativo;
  final String? Function(String?)? validator;

  const _PhoneField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.indicativo,
    required this.flag,
    required this.onSelectIndicativo,
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
            color: _C.onDarkSec,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── Selector de indicativo ──
          GestureDetector(
            onTap: onSelectIndicativo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _C.inputBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _C.cardBorder, width: 1.2),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(flag, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 7),
                Text(
                  indicativo,
                  style: GoogleFonts.spaceGrotesk(color: _C.onDark, fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.expand_more_rounded, color: _C.onDarkSec, size: 18),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          // ── Número ──
          Expanded(
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.phone,
              validator: validator,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.spaceGrotesk(color: _C.onDark, fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: '412 000 0000',
                hintStyle: GoogleFonts.spaceGrotesk(color: _C.onDarkSec.withOpacity(0.6), fontSize: 13),
                prefixIcon: Container(
                  margin: const EdgeInsets.fromLTRB(14, 9, 10, 9),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _C.accent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.phone_rounded, color: _C.accent, size: 16),
                ),
                filled: true,
                fillColor: _C.inputBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: _C.cardBorder, width: 1.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: _C.accent, width: 1.8),
                  borderRadius: BorderRadius.circular(14),
                ),
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _C.danger, width: 1.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _C.danger, width: 1.8),
                  borderRadius: BorderRadius.circular(14),
                ),
                errorStyle: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 11),
              ),
            ),
          ),
        ]),
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

  // ── Indicativo de país (teléfono WhatsApp) ──
  String _indicativoPais = '+57';

  Map<String, String> get _paisSel => _paises.firstWhere(
        (p) => p['codigo'] == _indicativoPais,
        orElse: () => {'flag': '🌍', 'nombre': '', 'codigo': _indicativoPais},
      );

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
        'telefono': '$_indicativoPais${_telefonoCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '')}',
        'indicativoPais': _indicativoPais,
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
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
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
        backgroundColor: _C.dark,
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

                    _PhoneField(
                      controller: _telefonoCtrl,
                      focusNode: _telefonoFocus,
                      label: 'TELÉFONO (WhatsApp)',
                      indicativo: _indicativoPais,
                      flag: _paisSel['flag'] ?? '🌍',
                      onSelectIndicativo: _seleccionarPais,
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
                      Expanded(child: Divider(color: _C.cardBorder, thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('o', style: GoogleFonts.spaceGrotesk(color: _C.onDarkSec, fontSize: 12)),
                      ),
                      Expanded(child: Divider(color: _C.cardBorder, thickness: 1)),
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

  // ── Modal selector de indicativo / país ──
  Future<void> _seleccionarPais() async {
    final busquedaCtrl = TextEditingController();
    List<Map<String, String>> filtrados = _paises.map((p) => Map<String, String>.from(p)).toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: _C.card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _C.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Selecciona tu país',
                        style: GoogleFonts.spaceGrotesk(
                          color: _C.onDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: busquedaCtrl,
                    style: GoogleFonts.spaceGrotesk(color: _C.onDark, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Buscar país o código...',
                      hintStyle: GoogleFonts.spaceGrotesk(color: _C.onDarkSec.withOpacity(0.6), fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: _C.onDarkSec, size: 18),
                      filled: true,
                      fillColor: _C.inputBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: _C.cardBorder),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: _C.accent, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) {
                      setModalState(() {
                        filtrados = _paises
                            .where((p) => p['nombre']!.toLowerCase().contains(v.toLowerCase()) || p['codigo']!.contains(v))
                            .map((p) => Map<String, String>.from(p))
                            .toList();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtrados.length,
                    itemBuilder: (_, i) {
                      final p = filtrados[i];
                      final seleccionado = _indicativoPais == p['codigo'];
                      return ListTile(
                        onTap: () {
                          setState(() => _indicativoPais = p['codigo']!);
                          Navigator.pop(ctx);
                        },
                        leading: Text(p['flag'] ?? '', style: const TextStyle(fontSize: 22)),
                        title: Text(
                          p['nombre'] ?? '',
                          style: GoogleFonts.spaceGrotesk(
                            color: _C.onDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: Text(
                          p['codigo'] ?? '',
                          style: GoogleFonts.spaceGrotesk(
                            color: seleccionado ? _C.accent : _C.onDarkSec,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ]),
            );
          },
        );
      },
    );
    busquedaCtrl.dispose();
  }

  // ── Header de marca (oscuro, estilo de la app) ──
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.bg1, _C.bg2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(children: [
        Positioned(
          right: -30,
          top: -30,
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Transform.scale(
              scale: _pulseAnim.value,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.primary.withOpacity(0.10),
                ),
              ),
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
              color: _C.accent.withOpacity(0.10),
            ),
          ),
        ),
        Column(children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_C.primary, _C.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: _C.primary.withOpacity(0.4), blurRadius: 22, offset: const Offset(0, 8)),
                BoxShadow(color: _C.accent.withOpacity(0.2), blurRadius: 36, spreadRadius: 2),
              ],
            ),
            child: const Icon(Icons.wifi_tethering_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 12),
          Text('StarkGo',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              )),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: _C.accent, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('Crea tu cuenta', style: GoogleFonts.spaceGrotesk(color: _C.onDarkSec, fontSize: 12.5)),
            const SizedBox(width: 8),
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: _C.primary, shape: BoxShape.circle)),
          ]),
        ]),
      ]),
    );
  }

  Widget _buildTitulo() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 24),
      Text('Registro',
          style: GoogleFonts.spaceGrotesk(
            color: _C.onDark,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          )),
      const SizedBox(height: 4),
      Text('Completa tus datos para crear tu cuenta',
          style: GoogleFonts.spaceGrotesk(
            color: _C.onDarkSec,
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
          color: _C.accent.withOpacity(0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: _C.accent, size: 14),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          color: _C.onDarkSec,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: Divider(color: _C.cardBorder, thickness: 1)),
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
                  colors: [_C.primary, _C.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: _isLoading ? _C.cardBorder : null,
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
                          valueColor: AlwaysStoppedAnimation(_C.onDarkSec.withOpacity(0.6)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Creando cuenta...',
                          style: GoogleFonts.spaceGrotesk(
                            color: _C.onDarkSec,
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
      Text('¿Ya tienes cuenta? ', style: GoogleFonts.spaceGrotesk(color: _C.onDarkSec, fontSize: 13)),
      GestureDetector(
        onTap: () => context.pushNamed('login'),
        child: Text(
          'Inicia sesión',
          style: GoogleFonts.spaceGrotesk(
            color: _C.accent,
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
