import 'package:stark_go/services/vps_service.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─── Paleta reutilizada del proyecto ────────────────────────
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
  static const Color pppoe = Color(0xFF0EA5E9); // azul PPPoE distintivo
}

// ─── Campo de formulario reutilizable ───────────────────────
class _Field extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label, hint;
  final IconData icon;
  final Color iconColor;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final bool obscure;
  final Widget? suffix;

  const _Field({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    required this.iconColor,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.validator,
    this.obscure = false,
    this.suffix,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late bool _oculto;

  @override
  void initState() {
    super.initState();
    _oculto = widget.obscure;
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(widget.label,
              style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        ),
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          obscureText: _oculto,
          style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w500),
          validator: widget.validator,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.5), fontSize: 14),
            prefixIcon: Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: widget.iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
              child: Icon(widget.icon, color: widget.iconColor, size: 17),
            ),
            suffixIcon: widget.obscure
                ? IconButton(
                    icon: Icon(_oculto ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: _C.textSec, size: 18),
                    onPressed: () => setState(() => _oculto = !_oculto),
                  )
                : widget.suffix,
            filled: true,
            fillColor: _C.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder:
                OutlineInputBorder(borderSide: BorderSide(color: _C.border, width: 1.2), borderRadius: BorderRadius.circular(14)),
            focusedBorder:
                OutlineInputBorder(borderSide: BorderSide(color: widget.iconColor, width: 1.8), borderRadius: BorderRadius.circular(14)),
            errorBorder: OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.5), borderRadius: BorderRadius.circular(14)),
            focusedErrorBorder:
                OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.8), borderRadius: BorderRadius.circular(14)),
            errorStyle: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 11),
          ),
        ),
      ]);
}

// ─── Seccion con encabezado ──────────────────────────────────
class _Section extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final List<Widget> children;

  const _Section({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _C.border),
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
                    gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]), borderRadius: BorderRadius.circular(12)),
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
            const SizedBox(height: 18),
            ...children.map((w) => Padding(padding: const EdgeInsets.only(bottom: 14), child: w)),
          ]),
        ),
      );
}

// ════════════════════════════════════════════════════════════
//  WIDGET PRINCIPAL
// ════════════════════════════════════════════════════════════
class CrearPppoeWidget extends StatefulWidget {
  const CrearPppoeWidget({super.key});
  static String routeName = 'CrearPppoe';
  static String routePath = 'crearPppoe';

  @override
  State<CrearPppoeWidget> createState() => _CrearPppoeWidgetState();
}

class _CrearPppoeWidgetState extends State<CrearPppoeWidget> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  final _ctrlNombreCliente = TextEditingController();
  final _focusNombreCliente = FocusNode();
  final _ctrlUsuarioPppoe = TextEditingController();
  final _focusUsuarioPppoe = FocusNode();
  final _ctrlClavePppoe = TextEditingController();
  final _focusClavePppoe = FocusNode();
  final _ctrlSubida = TextEditingController();
  final _focusSubida = FocusNode();
  final _ctrlBajada = TextEditingController();
  final _focusBajada = FocusNode();
  final _ctrlPerfil = TextEditingController();
  final _focusPerfil = FocusNode();
  final _ctrlIp = TextEditingController();
  final _focusIp = FocusNode();

  // Velocidades guardadas del usuario
  List<String> _velocidades = [];
  bool _usarVelocidadGuardada = false;
  String? _velocidadSel;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _cargarVelocidades();
  }

  @override
  void dispose() {
    for (final c in [
      _ctrlNombreCliente,
      _ctrlUsuarioPppoe,
      _ctrlClavePppoe,
      _ctrlSubida,
      _ctrlBajada,
      _ctrlPerfil,
      _ctrlIp,
    ]) c.dispose();
    for (final f in [
      _focusNombreCliente,
      _focusUsuarioPppoe,
      _focusClavePppoe,
      _focusSubida,
      _focusBajada,
      _focusPerfil,
      _focusIp,
    ]) f.dispose();
    super.dispose();
  }

  // Carga velocidades desde Firestore (misma coleccion que CrearUsuario)
  Future<void> _cargarVelocidades() async {
    if (_uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('velocidades').doc(_uid).get();
      if (doc.exists && mounted) {
        final raw = (doc.data() as Map<String, dynamic>)['lista'];
        setState(() => _velocidades = raw is List ? List<String>.from(raw.map((e) => e.toString())) : []);
      }
    } catch (e) {
      debugPrint('[CrearPppoe] Error cargando velocidades: $e');
    }
  }

  // Parsea "bajada/subida" y rellena los campos
  void _aplicarVelocidad(String v) {
    setState(() => _velocidadSel = v);
    final p = v.split('/');
    _ctrlBajada.text = p.isNotEmpty ? p[0].trim() : '';
    _ctrlSubida.text = p.length > 1 ? p[1].trim() : '';
  }

  // Valida formato MikroTik: numero + sufijo (M, K, G) ej: "10M"
  static String? _validarVelocidad(String? val) {
    if (val == null || val.trim().isEmpty) return 'Requerido';
    final ok = RegExp(r'^\d+(\.\d+)?[MmKkGg]?$').hasMatch(val.trim());
    if (!ok) return 'Formato invalido · Ej: 10M o 512K';
    return null;
  }

  static String? _validarIp(String? val) {
    if (val == null || val.trim().isEmpty) return null; // IP opcional en PPPoE
    final ok = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(val.trim());
    if (!ok) return 'IP invalida · Ej: 192.168.1.100';
    return null;
  }

  // ── Crear PPPoE ─────────────────────────────────────────
  Future<void> _crear() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final usuario = _ctrlUsuarioPppoe.text.trim().replaceAll(' ', '_');
      final clave = _ctrlClavePppoe.text.trim();
      final nombre = _ctrlNombreCliente.text.trim();
      final subida = _ctrlSubida.text.trim();
      final bajada = _ctrlBajada.text.trim();
      final perfil = _ctrlPerfil.text.trim();

      // 1. Encolar PPPoE en VPS → MikroTik
      final ok = await VpsService.pppoeCrear(
        usuario: usuario,
        clave: clave,
        nombre: nombre,
        subida: subida,
        bajada: bajada,
        perfil: perfil.isNotEmpty ? perfil : null,
      );

      // 2. Guardar en Firestore coleccion pppoe_clientes
      // propietarioUid es obligatorio — sin el no se guarda
      if (_uid == null) throw Exception('Usuario no autenticado');
      await FirebaseFirestore.instance.collection('pppoe_clientes').add({
        'nombre': nombre,
        'usuarioPppoe': usuario,
        'clavePppoe': clave,
        'subida': subida,
        'bajada': bajada,
        'perfil': perfil.isNotEmpty ? perfil : 'starkgo_$usuario',
        'ip': _ctrlIp.text.trim(),
        'estado': 'activo',
        'propietarioUid': _uid, // ← siempre requerido
        'fecha': FieldValue.serverTimestamp(),
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.warning_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ok ? 'PPPoE "$usuario" encolado correctamente' : 'Guardado en Firestore, pero el VPS no respondio',
                style: GoogleFonts.spaceGrotesk(color: Colors.white),
              ),
            ),
          ]),
          backgroundColor: ok ? _C.success : _C.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        if (ok) context.safePop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          backgroundColor: _C.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _C.surfaceDim,
        body: SafeArea(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.disabled,
            child: Column(children: [
              _buildTopBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                  child: Column(children: [
                    _buildBanner().animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0),
                    const SizedBox(height: 16),

                    // ── Datos del cliente ───────────────
                    _Section(
                      icon: Icons.person_rounded,
                      color: _C.pppoe,
                      title: 'Datos del Cliente',
                      subtitle: 'Nombre visible en la app y en MikroTik',
                      children: [
                        _Field(
                          controller: _ctrlNombreCliente,
                          focusNode: _focusNombreCliente,
                          label: 'NOMBRE DEL CLIENTE',
                          hint: 'Ej: Juan Perez',
                          icon: Icons.badge_rounded,
                          iconColor: _C.pppoe,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
                        ),
                      ],
                    ).animate().fadeIn(duration: 350.ms, delay: 80.ms).slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 14),

                    // ── Credenciales PPPoE ──────────────
                    _Section(
                      icon: Icons.vpn_key_rounded,
                      color: _C.purple,
                      title: 'Credenciales PPPoE',
                      subtitle: 'Usuario y clave que usara el router del cliente',
                      children: [
                        _Field(
                          controller: _ctrlUsuarioPppoe,
                          focusNode: _focusUsuarioPppoe,
                          label: 'USUARIO PPPOE',
                          hint: 'Ej: finca_la_esperanza',
                          icon: Icons.account_circle_rounded,
                          iconColor: _C.purple,
                          // Sin espacios
                          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Ingresa el usuario';
                            if (v.trim().length < 3) return 'Minimo 3 caracteres';
                            return null;
                          },
                        ),
                        _Field(
                          controller: _ctrlClavePppoe,
                          focusNode: _focusClavePppoe,
                          label: 'CLAVE PPPOE',
                          hint: 'Contrasena del cliente',
                          icon: Icons.lock_rounded,
                          iconColor: _C.purple,
                          obscure: true,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Ingresa la clave';
                            if (v.trim().length < 4) return 'Minimo 4 caracteres';
                            return null;
                          },
                        ),
                        _Field(
                          controller: _ctrlPerfil,
                          focusNode: _focusPerfil,
                          label: 'NOMBRE DEL PERFIL (opcional)',
                          hint: 'Ej: plan_10M — si vacio se genera automaticamente',
                          icon: Icons.layers_rounded,
                          iconColor: _C.textSec,
                          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                        ),
                      ],
                    ).animate().fadeIn(duration: 350.ms, delay: 160.ms).slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 14),

                    // ── Velocidad ───────────────────────
                    _Section(
                      icon: Icons.speed_rounded,
                      color: _C.warning,
                      title: 'Velocidad del Plan',
                      subtitle: 'Subida y bajada en formato MikroTik (ej: 10M)',
                      children: [
                        // Toggle: usar velocidad guardada o manual
                        if (_velocidades.isNotEmpty) ...[
                          _buildToggleVelocidad(),
                          const SizedBox(height: 4),
                        ],
                        if (_usarVelocidadGuardada && _velocidades.isNotEmpty)
                          _buildVelocidadDropdown()
                        else ...[
                          _Field(
                            controller: _ctrlBajada,
                            focusNode: _focusBajada,
                            label: 'BAJADA (Download)',
                            hint: 'Ej: 10M o 1024K',
                            icon: Icons.arrow_downward_rounded,
                            iconColor: _C.accent,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.MmKkGg]'))],
                            validator: _validarVelocidad,
                          ),
                          _Field(
                            controller: _ctrlSubida,
                            focusNode: _focusSubida,
                            label: 'SUBIDA (Upload)',
                            hint: 'Ej: 5M o 512K',
                            icon: Icons.arrow_upward_rounded,
                            iconColor: _C.primary,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.MmKkGg]'))],
                            validator: _validarVelocidad,
                          ),
                        ],
                      ],
                    ).animate().fadeIn(duration: 350.ms, delay: 240.ms).slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 14),

                    // ── IP fija (opcional) ──────────────
                    _Section(
                      icon: Icons.lan_rounded,
                      color: _C.success,
                      title: 'IP Fija (Opcional)',
                      subtitle: 'Solo si el cliente tiene IP estatica asignada',
                      children: [
                        _Field(
                          controller: _ctrlIp,
                          focusNode: _focusIp,
                          label: 'IP DEL CLIENTE',
                          hint: 'Ej: 192.168.100.50  —  dejar vacio si es DHCP',
                          icon: Icons.router_rounded,
                          iconColor: _C.success,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                          validator: _validarIp,
                        ),
                      ],
                    ).animate().fadeIn(duration: 350.ms, delay: 300.ms).slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 14),

                    _buildInfoCard().animate().fadeIn(duration: 350.ms, delay: 360.ms),
                    const SizedBox(height: 20),
                    _buildSubmitButton().animate().fadeIn(duration: 350.ms, delay: 400.ms).slideY(begin: 0.05, end: 0),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Toggle velocidad guardada vs manual ─────────────────
  Widget _buildToggleVelocidad() => GestureDetector(
        onTap: () {
          setState(() {
            _usarVelocidadGuardada = !_usarVelocidadGuardada;
            if (!_usarVelocidadGuardada) {
              _velocidadSel = null;
              _ctrlBajada.clear();
              _ctrlSubida.clear();
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _usarVelocidadGuardada ? _C.warning.withOpacity(0.08) : _C.surfaceDim,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _usarVelocidadGuardada ? _C.warning.withOpacity(0.4) : _C.border),
          ),
          child: Row(children: [
            Icon(Icons.bolt_rounded, color: _usarVelocidadGuardada ? _C.warning : _C.textSec, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _usarVelocidadGuardada ? 'Usando velocidades guardadas' : 'Ingresar velocidad manualmente',
                style: GoogleFonts.spaceGrotesk(
                  color: _usarVelocidadGuardada ? _C.warning : _C.textSec,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(_usarVelocidadGuardada ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                color: _usarVelocidadGuardada ? _C.warning : _C.textSec, size: 24),
          ]),
        ),
      );

  // ── Dropdown de velocidades guardadas ───────────────────
  Widget _buildVelocidadDropdown() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text('VELOCIDAD GUARDADA',
              style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        ),
        Container(
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _velocidadSel != null ? _C.warning : _C.border, width: _velocidadSel != null ? 1.8 : 1.2),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _velocidadSel,
              isExpanded: true,
              borderRadius: BorderRadius.circular(14),
              dropdownColor: _C.surface,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              icon: Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.keyboard_arrow_down_rounded, color: _C.textSec)),
              hint: Row(children: [
                Container(
                  margin: const EdgeInsets.only(left: 6, right: 10),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: _C.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.speed_rounded, color: _C.warning, size: 16),
                ),
                Text('Selecciona la velocidad', style: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.6), fontSize: 14)),
              ]),
              items: _velocidades.map((v) {
                final p = v.split('/');
                return DropdownMenuItem<String>(
                  value: v,
                  child: Row(children: [
                    Container(
                      margin: const EdgeInsets.only(left: 4, right: 10),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: _C.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.speed_rounded, color: _C.warning, size: 15),
                    ),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(v, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('Bajada ${p[0]}  ·  Subida ${p.length > 1 ? p[1] : '?'}',
                            style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
                      ]),
                    ),
                  ]),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) _aplicarVelocidad(v);
              },
            ),
          ),
        ),
      ]);

  // ── Top bar ─────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) => Padding(
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
              Text('Cliente PPPoE', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 20, fontWeight: FontWeight.w800)),
              Text('Crear secreto en MikroTik', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _C.pppoe.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.pppoe.withOpacity(0.3)),
            ),
            child: Row(children: [
              Icon(Icons.cable_rounded, color: _C.pppoe, size: 13),
              const SizedBox(width: 5),
              Text('PPPoE', style: GoogleFonts.spaceGrotesk(color: _C.pppoe, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );

  // ── Banner ───────────────────────────────────────────────
  Widget _buildBanner() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0B1D35), Color(0xFF0F2952)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_C.pppoe, Color(0xFF6366F1)]), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.cable_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nuevo secreto PPPoE', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              Text('El comando se encola en el VPS y MikroTik lo aplica en el siguiente ciclo',
                  style: GoogleFonts.spaceGrotesk(color: Colors.white54, fontSize: 11)),
            ]),
          ),
        ]),
      );

  // ── Tarjeta informativa ──────────────────────────────────
  Widget _buildInfoCard() {
    final pasos = [
      (Icons.cloud_upload_rounded, _C.pppoe, 'La app envia el comando al VPS'),
      (Icons.pending_rounded, _C.warning, 'El VPS encola el script RouterOS'),
      (Icons.router_rounded, _C.success, 'MikroTik lo ejecuta en el siguiente ciclo del Scheduler'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: _C.pppoe.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.info_outline_rounded, color: _C.pppoe, size: 16),
            ),
            const SizedBox(width: 10),
            Text('Como funciona', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          ...pasos.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(color: e.value.$2.withOpacity(0.1), shape: BoxShape.circle),
                    child: Center(
                      child: Text('${e.key + 1}',
                          style: GoogleFonts.spaceGrotesk(color: e.value.$2, fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(e.value.$1, color: e.value.$2, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e.value.$3, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
                  ),
                ]),
              )),
        ]),
      ),
    );
  }

  // ── Boton registrar ──────────────────────────────────────
  Widget _buildSubmitButton() => SizedBox(
        width: double.infinity,
        height: 56,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: _isLoading ? null : const LinearGradient(colors: [_C.pppoe, Color(0xFF6366F1)]),
            color: _isLoading ? _C.border : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isLoading ? [] : [BoxShadow(color: _C.pppoe.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : _crear,
              borderRadius: BorderRadius.circular(16),
              child: Center(
                child: _isLoading
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_C.textSec))),
                        const SizedBox(width: 10),
                        Text('Enviando a MikroTik...',
                            style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 15, fontWeight: FontWeight.w600)),
                      ])
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.cable_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text('Crear Secreto PPPoE',
                            style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      ]),
              ),
            ),
          ),
        ),
      );
}
