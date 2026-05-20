import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'crear_cuenta_model.dart';
export 'crear_cuenta_model.dart';

// ─────────────────────────────────────────────
//  PALETA
// ─────────────────────────────────────────────
class _C {
  static const Color primary = Color(0xFF1A73E8);
  static const Color accent = Color(0xFF00C6AE);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFE53935);
  static const Color dark = Color(0xFF0F172A);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF1F5F9);
  static const Color textPri = Color(0xFF0F172A);
  static const Color textSec = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color purple = Color(0xFF7C3AED);
  static const Color whatsapp = Color(0xFF25D366);
}

// ─────────────────────────────────────────────
//  LISTA DE PAÍSES
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
  {'flag': '🇩🇪', 'nombre': 'Alemania', 'codigo': '+49'},
  {'flag': '🇫🇷', 'nombre': 'Francia', 'codigo': '+33'},
  {'flag': '🇮🇹', 'nombre': 'Italia', 'codigo': '+39'},
  {'flag': '🇵🇹', 'nombre': 'Portugal', 'codigo': '+351'},
  {'flag': '🇨🇺', 'nombre': 'Cuba', 'codigo': '+53'},
  {'flag': '🇯🇲', 'nombre': 'Jamaica', 'codigo': '+1876'},
  {'flag': '🇹🇹', 'nombre': 'Trinidad y Tobago', 'codigo': '+1868'},
];

// ─────────────────────────────────────────────
//  MODELO DE MEMBRESÍA
// ─────────────────────────────────────────────
class _PlanMembresia {
  final String id;
  final String label;
  final String sublabel;
  final int meses;
  final Color color;
  final IconData icon;
  final String badge;

  const _PlanMembresia({
    required this.id,
    required this.label,
    required this.sublabel,
    required this.meses,
    required this.color,
    required this.icon,
    required this.badge,
  });
}

const _planes = [
  _PlanMembresia(
    id: '1m',
    label: '1 Mes',
    sublabel: 'Acceso mensual',
    meses: 1,
    color: _C.textSec,
    icon: Icons.calendar_today_rounded,
    badge: 'Básico',
  ),
  _PlanMembresia(
    id: '3m',
    label: '3 Meses',
    sublabel: 'Trimestral',
    meses: 3,
    color: _C.primary,
    icon: Icons.date_range_rounded,
    badge: 'Popular',
  ),
  _PlanMembresia(
    id: '6m',
    label: '6 Meses',
    sublabel: 'Semestral',
    meses: 6,
    color: _C.accent,
    icon: Icons.event_rounded,
    badge: 'Recomendado',
  ),
  _PlanMembresia(
    id: '1a',
    label: '1 Año',
    sublabel: 'Anual completo',
    meses: 12,
    color: _C.purple,
    icon: Icons.workspace_premium_rounded,
    badge: 'Premium',
  ),
];

// ─────────────────────────────────────────────
//  CAMPO DE FORMULARIO
// ─────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label, hint;
  final IconData icon;
  final Color iconColor;
  final TextInputType keyboardType;
  final bool isPassword;
  final bool passwordVisible;
  final VoidCallback? onTogglePassword;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    this.iconColor = _C.primary,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.passwordVisible = false,
    this.onTogglePassword,
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
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 16),
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
            borderSide: BorderSide(color: iconColor, width: 2),
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
class CrearCuentaWidget extends StatefulWidget {
  const CrearCuentaWidget({super.key});

  static String routeName = 'CrearCuenta';
  static String routePath = 'crearCuenta';

  @override
  State<CrearCuentaWidget> createState() => _CrearCuentaWidgetState();
}

class _CrearCuentaWidgetState extends State<CrearCuentaWidget> {
  late CrearCuentaModel _model;
  bool _isLoading = false;
  _PlanMembresia? _planSel;
  bool _validarPlan = false;
  DateTime? _fechaVencimiento;

  // ── Indicativo de país ─────────────────────
  String _indicativoPais = '+57';

  // ── Evolution API config ───────────────────
  static const String _kEvolutionCol = 'whatsapp_instances';
  static const String _kEvolutionBaseUrl = 'http://5.161.88.42:8080';
  static const String _kEvolutionApiKey = 'starkgo2024secretkey';
  String? _evolutionInstance;
  bool _configCargada = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CrearCuentaModel());
    _model.nombreController ??= TextEditingController();
    _model.nombreFocusNode ??= FocusNode();
    _model.apellidoController ??= TextEditingController();
    _model.apellidoFocusNode ??= FocusNode();
    _model.correoController ??= TextEditingController();
    _model.correoFocusNode ??= FocusNode();
    _model.passwordController ??= TextEditingController();
    _model.passwordFocusNode ??= FocusNode();
    _model.telefonoController ??= TextEditingController();
    _model.telefonoFocusNode ??= FocusNode();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    _cargarConfigEvolution();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  // ── Carga instancia Evolution de Firebase ──
  Future<void> _cargarConfigEvolution() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final snap = await FirebaseFirestore.instance
          .collection(_kEvolutionCol)
          .where('uid', isEqualTo: uid)
          .where('status', isEqualTo: 'open')
          .limit(1)
          .get();

      if (!mounted) return;

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        setState(() {
          _evolutionInstance = data['instanceName'] as String?;
          _configCargada = true;
        });
      } else {
        setState(() => _configCargada = true);
      }
    } catch (e) {
      debugPrint('[StarkGo] Error cargando config Evolution: $e');
      if (mounted) setState(() => _configCargada = true);
    }
  }

  void _onPlanSelected(_PlanMembresia plan) {
    setState(() {
      _planSel = plan;
      _fechaVencimiento = DateTime.now().add(Duration(days: plan.meses * 30));
    });
  }

  Future<void> _seleccionarFechaManual() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaVencimiento ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: _C.primary),
          dialogBackgroundColor: _C.surface,
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _fechaVencimiento = picked);
  }

  // ── Modal selector de país ─────────────────
  Future<void> _seleccionarPais() async {
    final TextEditingController busquedaCtrl = TextEditingController();
    List<Map<String, String>> filtrados = _paises.map((p) => Map<String, String>.from(p)).toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _C.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Seleccionar país',
                    style: GoogleFonts.spaceGrotesk(
                      color: _C.textPri,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: busquedaCtrl,
                    style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Buscar país o código...',
                      hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.5), fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: _C.textSec, size: 18),
                      filled: true,
                      fillColor: _C.surfaceDim,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _C.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _C.primary, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      border: OutlineInputBorder(
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
                        leading: Text(
                          p['flag']!,
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(
                          p['nombre']!,
                          style: GoogleFonts.spaceGrotesk(
                            color: _C.textPri,
                            fontSize: 14,
                            fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              p['codigo']!,
                              style: GoogleFonts.spaceGrotesk(
                                color: _C.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (seleccionado) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.check_circle_rounded, color: _C.primary, size: 16),
                            ],
                          ],
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
  }

  // ── Envío WhatsApp via Evolution API ───────
  Future<void> _enviarBienvenidaWhatsApp({
    required String numero,
    required String nombre,
    required String apellido,
    required String correo,
    required String password,
    required String planLabel,
    required String fechaVencimiento,
  }) async {
    if (_evolutionInstance == null) {
      _showWarning('No hay WhatsApp conectado. Ve a Configuración → WhatsApp.');
      return;
    }

    // numero ya llega con indicativo, solo limpiar caracteres especiales
    String tel = numero.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');

    final mensaje = '''
🌐 *¡Bienvenido a StarkGo!* 🌐

Estimado/a *$nombre $apellido*, nos complace informarle que su cuenta de operador ha sido creada exitosamente en nuestra plataforma de gestión ISP.

━━━━━━━━━━━━━━━━━━━━
🔐 *SUS CREDENCIALES DE ACCESO*
━━━━━━━━━━━━━━━━━━━━

📧 *Correo:* $correo
🔑 *Contraseña:* $password

━━━━━━━━━━━━━━━━━━━━
📋 *DETALLES DE SU MEMBRESÍA*
━━━━━━━━━━━━━━━━━━━━

📦 *Plan:* $planLabel
📅 *Acceso hasta:* $fechaVencimiento

━━━━━━━━━━━━━━━━━━━━

✅ Ya puede iniciar sesión en la aplicación StarkGo con las credenciales indicadas arriba.

App:
https://play.google.com/store/apps/details?id=com.starkgo.net.cardenCode

Estamos a su disposición para cualquier consulta o soporte técnico.

¡Bienvenido al equipo! 🚀

— *Equipo StarkGo* 🌐''';

    try {
      final response = await http
          .post(
            Uri.parse('$_kEvolutionBaseUrl/message/sendText/$_evolutionInstance'),
            headers: {
              'Content-Type': 'application/json',
              'apikey': _kEvolutionApiKey,
            },
            body: jsonEncode({
              'number': '$tel@s.whatsapp.net',
              'text': mensaje,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[StarkGo] WhatsApp bienvenida enviado a $tel');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.chat_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Credenciales enviadas por WhatsApp a $nombre',
                  style: GoogleFonts.spaceGrotesk(color: Colors.white),
                ),
              ),
            ]),
            backgroundColor: _C.whatsapp,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      } else {
        if (mounted) {
          _showWarning('Cuenta creada, pero no se pudo enviar el WhatsApp. (${response.statusCode})');
        }
      }
    } catch (e) {
      if (mounted) _showWarning('Cuenta creada. Error al enviar WhatsApp: $e');
    }
  }

  // ══════════════════════════════════════════
  //  CREAR CUENTA
  // ══════════════════════════════════════════
  Future<void> _crearCuenta() async {
    setState(() => _validarPlan = true);
    if (!_model.formKey.currentState!.validate()) return;
    if (_planSel == null) {
      _showError('Selecciona un plan de membresía');
      return;
    }
    if (_fechaVencimiento == null) {
      _showError('La fecha de vencimiento es requerida');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final correo = _model.correoController!.text.trim();
      final password = _model.passwordController!.text;
      final nombre = _model.nombreController!.text.trim();
      final apellido = _model.apellidoController!.text.trim();
      final telefonoRaw = _model.telefonoController!.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
      // Número completo con indicativo para WhatsApp
      final telefonoCompleto = '$_indicativoPais$telefonoRaw';

      // 1. Crear usuario con instancia secundaria (no cierra sesión admin)
      final secondaryApp = await Firebase.initializeApp(
        name: 'secondary_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: correo,
        password: password,
      );

      final nuevoUid = cred.user!.uid;
      await cred.user!.updateDisplayName('$nombre $apellido');
      await secondaryApp.delete();

      // 2. Guardar en Firestore → colección "user"
      await FirebaseFirestore.instance.collection('user').doc(nuevoUid).set({
        'uid': nuevoUid,
        'email': correo,
        'created_time': FieldValue.serverTimestamp(),
        'nombre': nombre,
        'apellido': apellido,
        'telefono': telefonoCompleto,
        'indicativoPais': _indicativoPais,
        'planMembresia': _planSel!.id,
        'mesesMembresia': _planSel!.meses,
        'fechaVencimiento': Timestamp.fromDate(_fechaVencimiento!),
        'activo': true,
        'rol': 'operador',
      });

      // 3. Enviar WhatsApp con credenciales
      if (telefonoRaw.isNotEmpty) {
        final fechaFormateada = '${_fechaVencimiento!.day.toString().padLeft(2, '0')}/'
            '${_fechaVencimiento!.month.toString().padLeft(2, '0')}/'
            '${_fechaVencimiento!.year}';

        await _enviarBienvenidaWhatsApp(
          numero: telefonoCompleto,
          nombre: nombre,
          apellido: apellido,
          correo: correo,
          password: password,
          planLabel: '${_planSel!.label} · ${_planSel!.sublabel}',
          fechaVencimiento: fechaFormateada,
        );
      }

      // 4. Éxito y volver
      if (mounted) {
        _showSuccess('✅ Cuenta creada para $nombre $apellido');
        await Future.delayed(const Duration(milliseconds: 1400));
        if (mounted) context.safePop();
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Error al crear la cuenta';
      if (e.code == 'email-already-in-use') msg = 'Este correo ya está registrado';
      if (e.code == 'weak-password') msg = 'Contraseña muy débil (mín. 6 caracteres)';
      if (e.code == 'invalid-email') msg = 'Correo inválido';
      _showError(msg);
    } catch (e) {
      _showError('Error: $e');
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

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.spaceGrotesk(color: Colors.white))),
      ]),
      backgroundColor: _C.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showWarning(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 12))),
      ]),
      backgroundColor: _C.warning,
      duration: const Duration(seconds: 5),
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
        backgroundColor: _C.surfaceDim,
        body: SafeArea(
          child: Form(
            key: _model.formKey,
            autovalidateMode: AutovalidateMode.disabled,
            child: Column(children: [
              _buildTopBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  child: Column(children: [
                    _buildBanner().animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0),
                    const SizedBox(height: 16),
                    _buildSeccion(
                      icon: Icons.person_rounded,
                      color: _C.primary,
                      title: 'Datos del Operador',
                      subtitle: 'Información básica del nuevo usuario',
                      children: [
                        _Field(
                          controller: _model.nombreController!,
                          focusNode: _model.nombreFocusNode!,
                          label: 'NOMBRE',
                          hint: 'Ej: Carlos',
                          icon: Icons.badge_rounded,
                          iconColor: _C.primary,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es requerido' : null,
                        ),
                        _Field(
                          controller: _model.apellidoController!,
                          focusNode: _model.apellidoFocusNode!,
                          label: 'APELLIDO',
                          hint: 'Ej: Rodríguez',
                          icon: Icons.badge_outlined,
                          iconColor: _C.primary,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'El apellido es requerido' : null,
                        ),
                        _Field(
                          controller: _model.correoController!,
                          focusNode: _model.correoFocusNode!,
                          label: 'CORREO ELECTRÓNICO',
                          hint: 'operador@empresa.com',
                          icon: Icons.alternate_email_rounded,
                          iconColor: _C.accent,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'El correo es requerido';
                            if (!v.contains('@') || !v.contains('.')) return 'Correo inválido';
                            return null;
                          },
                        ),
                        _Field(
                          controller: _model.passwordController!,
                          focusNode: _model.passwordFocusNode!,
                          label: 'CONTRASEÑA',
                          hint: 'Mínimo 6 caracteres',
                          icon: Icons.lock_rounded,
                          iconColor: _C.purple,
                          isPassword: true,
                          passwordVisible: _model.passwordVisibility,
                          onTogglePassword: () => safeSetState(() => _model.passwordVisibility = !_model.passwordVisibility),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'La contraseña es requerida';
                            if (v.length < 6) return 'Mínimo 6 caracteres';
                            return null;
                          },
                        ),
                        // ── TELÉFONO CON SELECTOR DE PAÍS ──
                        _buildCampoTelefono(),
                      ],
                    ).animate().fadeIn(duration: 350.ms, delay: 100.ms).slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 14),
                    _buildSeccion(
                      icon: Icons.workspace_premium_rounded,
                      color: _C.purple,
                      title: 'Plan de Membresía',
                      subtitle: 'Duración del acceso a la plataforma',
                      children: [_buildPlanesGrid()],
                    ).animate().fadeIn(duration: 350.ms, delay: 200.ms).slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 14),
                    if (_planSel != null) _buildFechaCard().animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, end: 0),
                    if (_planSel != null) const SizedBox(height: 14),
                    if (_planSel != null && _fechaVencimiento != null) _buildResumen().animate().fadeIn(duration: 300.ms, delay: 50.ms),
                    if (_planSel != null && _fechaVencimiento != null) const SizedBox(height: 14),
                    _buildBoton().animate().fadeIn(duration: 350.ms, delay: 300.ms).slideY(begin: 0.05, end: 0),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  CAMPO TELÉFONO CON SELECTOR DE PAÍS
  // ─────────────────────────────────────────
  Widget _buildCampoTelefono() {
    final paisActual = _paises.firstWhere(
      (p) => p['codigo'] == _indicativoPais,
      orElse: () => {'flag': '🌍', 'nombre': '', 'codigo': _indicativoPais},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text(
            'TELÉFONO WHATSAPP',
            style: GoogleFonts.spaceGrotesk(
              color: _C.textSec,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Botón selector de país ──
            GestureDetector(
              onTap: _seleccionarPais,
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _C.surfaceDim,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _C.border, width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Map<String, String>.from(paisActual)['flag'] ?? '🌍',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _indicativoPais,
                      style: GoogleFonts.spaceGrotesk(
                        color: _C.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more_rounded, color: _C.textSec, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // ── Campo número ──
            Expanded(
              child: TextFormField(
                controller: _model.telefonoController!,
                focusNode: _model.telefonoFocusNode!,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Ej: 3001234567',
                  hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.5), fontSize: 13),
                  prefixIcon: Container(
                    margin: const EdgeInsets.fromLTRB(14, 9, 10, 9),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _C.whatsapp.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.chat_rounded, color: _C.whatsapp, size: 16),
                  ),
                  filled: true,
                  fillColor: _C.surfaceDim,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: _C.border, width: 1.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: _C.whatsapp, width: 2),
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
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'El teléfono es requerido';
                  if (v.length < 7) return 'Número muy corto';
                  return null;
                },
              ),
            ),
          ],
        ),
        // ── Preview del número completo ──
        if ((_model.telefonoController?.text ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(children: [
              const Icon(Icons.check_circle_outline_rounded, size: 12, color: _C.whatsapp),
              const SizedBox(width: 4),
              Text(
                'Número completo: $_indicativoPais${_model.telefonoController!.text}',
                style: GoogleFonts.spaceGrotesk(color: _C.whatsapp, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ]),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────
  //  TOP BAR
  // ─────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(children: [
        GestureDetector(
          onTap: () => context.safePop(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.textPri, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Crear Cuenta', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 20, fontWeight: FontWeight.w800)),
            Text('Nuevo operador StarkGo', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _C.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.purple.withOpacity(0.3)),
          ),
          child: Row(children: [
            Icon(Icons.admin_panel_settings_rounded, color: _C.purple, size: 13),
            const SizedBox(width: 5),
            Text('Admin', style: GoogleFonts.spaceGrotesk(color: _C.purple, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────
  //  BANNER
  // ─────────────────────────────────────────
  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _C.dark.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_C.purple, _C.primary]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Registro de operador', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text('Se creará la cuenta y se enviarán las credenciales por WhatsApp.',
                style: GoogleFonts.spaceGrotesk(color: Colors.white60, fontSize: 11.5)),
          ]),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────
  //  SECCIÓN GENÉRICA
  // ─────────────────────────────────────────
  Widget _buildSeccion({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
              Text(subtitle, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
            ]),
          ]),
          const SizedBox(height: 18),
          Divider(color: _C.border, height: 1),
          const SizedBox(height: 16),
          ...children.map((w) => Padding(padding: const EdgeInsets.only(bottom: 14), child: w)),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  GRID DE PLANES
  // ─────────────────────────────────────────
  Widget _buildPlanesGrid() {
    return Column(children: [
      if (_validarPlan && _planSel == null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _C.danger.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.danger.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, color: _C.danger, size: 15),
              const SizedBox(width: 6),
              Text('Selecciona un plan de membresía', style: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 12)),
            ]),
          ),
        ),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.55,
        ),
        itemCount: _planes.length,
        itemBuilder: (_, i) => _PlanCard(
          plan: _planes[i],
          selected: _planSel?.id == _planes[i].id,
          onTap: () => _onPlanSelected(_planes[i]),
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────
  //  CARD FECHA VENCIMIENTO
  // ─────────────────────────────────────────
  Widget _buildFechaCard() {
    final fecha = _fechaVencimiento;
    if (fecha == null) return const SizedBox.shrink();

    final diasRestantes = fecha.difference(DateTime.now()).inDays;
    final color = diasRestantes > 90 ? _C.success : (diasRestantes > 30 ? _C.warning : _C.danger);

    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3), width: 1.4),
        boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.event_available_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Fecha de vencimiento', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w700)),
              Text('$diasRestantes días de acceso',
                  style: GoogleFonts.spaceGrotesk(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
          GestureDetector(
            onTap: _seleccionarFechaManual,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _C.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _C.primary.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.edit_calendar_rounded, color: _C.primary, size: 13),
                const SizedBox(width: 4),
                Text('Ajustar', style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${fecha.day.toString().padLeft(2, '0')} / '
            '${fecha.month.toString().padLeft(2, '0')} / '
            '${fecha.year}',
            style: GoogleFonts.spaceGrotesk(color: color, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1),
            textAlign: TextAlign.center,
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────
  //  RESUMEN
  // ─────────────────────────────────────────
  Widget _buildResumen() {
    final nombre = _model.nombreController?.text.trim() ?? '';
    final apellido = _model.apellidoController?.text.trim() ?? '';
    final correo = _model.correoController?.text.trim() ?? '';
    final telefono = _model.telefonoController?.text.trim() ?? '';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFE0F7F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.primary.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_C.primary, _C.accent]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.summarize_rounded, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          Text('Resumen de la cuenta', style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        if (nombre.isNotEmpty) _resumenFila(Icons.person_rounded, 'Operador', '$nombre $apellido', _C.primary),
        if (correo.isNotEmpty) _resumenFila(Icons.alternate_email_rounded, 'Correo', correo, _C.accent),
        if (telefono.isNotEmpty) _resumenFila(Icons.chat_rounded, 'WhatsApp', '$_indicativoPais $telefono', _C.whatsapp),
        if (_planSel != null) _resumenFila(_planSel!.icon, 'Membresía', '${_planSel!.label} · ${_planSel!.sublabel}', _planSel!.color),
        if (_fechaVencimiento != null)
          _resumenFila(
            Icons.event_rounded,
            'Vence el',
            '${_fechaVencimiento!.day.toString().padLeft(2, '0')}/'
                '${_fechaVencimiento!.month.toString().padLeft(2, '0')}/'
                '${_fechaVencimiento!.year}',
            _C.success,
          ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _C.whatsapp.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            const Icon(Icons.chat_rounded, color: _C.whatsapp, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Las credenciales se enviarán automáticamente por WhatsApp al crear la cuenta.',
                style: GoogleFonts.spaceGrotesk(color: _C.whatsapp, fontSize: 11),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _resumenFila(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Text('$label: ', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12, fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(value,
              style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 12, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────
  //  BOTÓN
  // ─────────────────────────────────────────
  Widget _buildBoton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: _isLoading
              ? null
              : const LinearGradient(
                  colors: [_C.purple, _C.primary, _C.accent],
                  stops: [0.0, 0.5, 1.0],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: _isLoading ? _C.border : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isLoading
              ? []
              : [
                  BoxShadow(color: _C.primary.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8)),
                  BoxShadow(color: _C.purple.withOpacity(0.2), blurRadius: 30, spreadRadius: 2),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : _crearCuenta,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white.withOpacity(0.1),
            child: Center(
              child: _isLoading
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation(_C.textSec),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('Creando cuenta...',
                          style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 15, fontWeight: FontWeight.w600)),
                    ])
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text('Crear cuenta y enviar credenciales',
                          style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CARD DE PLAN
// ─────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final _PlanMembresia plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({required this.plan, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: selected ? plan.color : _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? plan.color : _C.border,
            width: selected ? 0 : 1.2,
          ),
          boxShadow: selected
              ? [BoxShadow(color: plan.color.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))]
              : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withOpacity(0.2) : plan.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(plan.icon, color: selected ? Colors.white : plan.color, size: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withOpacity(0.2) : plan.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  plan.badge,
                  style: GoogleFonts.spaceGrotesk(
                    color: selected ? Colors.white : plan.color,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                plan.label,
                style: GoogleFonts.spaceGrotesk(
                  color: selected ? Colors.white : _C.textPri,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                plan.sublabel,
                style: GoogleFonts.spaceGrotesk(
                  color: selected ? Colors.white70 : _C.textSec,
                  fontSize: 10,
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
