import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../renovar_membresia/renovar_membresia_widget.dart';

class _C {
  static const Color primary = Color(0xFF1A73E8);
  static const Color accent = Color(0xFF00C6AE);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFE53935);
  static const Color dark = Color(0xFF0F172A);
  static const Color purple = Color(0xFF7C3AED);
}

class CompletarPerfilWidget extends StatefulWidget {
  const CompletarPerfilWidget({super.key});

  static String routeName = 'CompletarPerfil';
  static String routePath = 'completarPerfil';

  @override
  State<CompletarPerfilWidget> createState() => _CompletarPerfilWidgetState();
}

class _CompletarPerfilWidgetState extends State<CompletarPerfilWidget> {
  final _formKey = GlobalKey<FormState>();

  // ── Controladores ──
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();

  // ── FocusNodes ──
  final _nombreFocus = FocusNode();
  final _apellidoFocus = FocusNode();
  final _telefonoFocus = FocusNode();

  bool _isLoading = false;
  bool _cargando = true;

  // ── Datos de membresía ──
  String _planMembresia = '';
  String _tipoPlan = '';
  DateTime? _fechaVencimiento;
  String _email = '';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    _nombreFocus.dispose();
    _apellidoFocus.dispose();
    _telefonoFocus.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      setState(() => _cargando = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('user').doc(uid).get();
      if (!mounted) return;
      final data = doc.data();
      if (data != null) {
        setState(() {
          _nombreCtrl.text = data['nombre'] ?? '';
          _apellidoCtrl.text = data['apellido'] ?? '';
          _telefonoCtrl.text = data['telefono'] ?? '';
          _email = data['email'] ?? '';
          _planMembresia = data['planMembresia'] ?? '';
          final ts = data['fechaVencimiento'];
          if (ts != null) {
            _fechaVencimiento = (ts as Timestamp).toDate();
          }
          // Determinar tipo de plan
          final planMap = data['plan'];
          if (planMap is Map) {
            _tipoPlan = (planMap['tipo'] ?? '').toString();
          }
          if (_tipoPlan.isEmpty) {
            const planesVouchers = {'v1m', 'v3m', 'v6m', 'v1a'};
            const planesCompletos = {'1m', '3m', '6m', '1a'};
            if (planesVouchers.contains(_planMembresia)) {
              _tipoPlan = 'vouchers';
            } else if (planesCompletos.contains(_planMembresia)) {
              _tipoPlan = 'completo';
            }
          }
          _cargando = false;
        });
      } else {
        setState(() => _cargando = false);
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isEmpty) {
        _showError('Sesión expirada. Vuelve a iniciar sesión.');
        return;
      }
      await FirebaseFirestore.instance.collection('user').doc(uid).update({
        'nombre': _nombreCtrl.text.trim(),
        'apellido': _apellidoCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
      });
      if (mounted) {
        _showSuccess('Datos guardados correctamente');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _showError('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatFecha(DateTime d) => '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  String get _nombrePlan {
    switch (_planMembresia) {
      case '1m':
        return '1 Mes · Completo';
      case '3m':
        return '3 Meses · Completo';
      case '6m':
        return '6 Meses · Completo';
      case '1a':
        return '1 Año · Completo';
      case 'v1m':
        return '1 Mes · Solo Vouchers';
      case 'v3m':
        return '3 Meses · Solo Vouchers';
      case 'v6m':
        return '6 Meses · Solo Vouchers';
      case 'v1a':
        return '1 Año · Solo Vouchers';
      default:
        return _planMembresia.isEmpty ? 'Sin plan' : _planMembresia;
    }
  }

  String get _tipoPlanLabel {
    if (_tipoPlan == 'vouchers') return 'Solo Vouchers';
    if (_tipoPlan == 'completo') return 'Acceso Completo';
    return 'Sin plan';
  }

  Color get _tipoPlanColor {
    if (_tipoPlan == 'vouchers') return const Color(0xFF0EA5E9);
    if (_tipoPlan == 'completo') return _C.success;
    return _C.warning;
  }

  IconData get _tipoPlanIcon {
    if (_tipoPlan == 'vouchers') return Icons.vpn_key_rounded;
    if (_tipoPlan == 'completo') return Icons.workspace_premium_rounded;
    return Icons.error_outline_rounded;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.dmSans(color: Colors.white))),
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
        Expanded(child: Text(msg, style: GoogleFonts.dmSans(color: Colors.white))),
      ]),
      backgroundColor: _C.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.dark,
      body: Stack(children: [
        _buildFondo(),
        SafeArea(
          child: Column(children: [
            _buildTopBar(),
            Expanded(
              child: _cargando
                  ? const Center(
                      child: CircularProgressIndicator(color: _C.primary),
                    )
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                      child: Form(
                        key: _formKey,
                        child: Column(children: [
                          _buildHeroCard()
                              .animate()
                              .fadeIn(duration: 400.ms)
                              .slideY(begin: 0.06, end: 0, duration: 400.ms, curve: Curves.easeOut),
                          const SizedBox(height: 20),
                          _buildPlanCard()
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 120.ms)
                              .slideY(begin: 0.06, end: 0, duration: 400.ms, delay: 120.ms),
                          const SizedBox(height: 20),
                          _buildDatosPersonales()
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 200.ms)
                              .slideY(begin: 0.06, end: 0, duration: 400.ms, delay: 200.ms),
                          const SizedBox(height: 24),
                          _buildBotonGuardar()
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 280.ms)
                              .slideY(begin: 0.06, end: 0, duration: 400.ms, delay: 280.ms),
                        ]),
                      ),
                    ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildFondo() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF0D1321)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 17),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mi Perfil', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
            Text('Completa tu información', style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 11.5)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: _tipoPlanColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _tipoPlanColor.withOpacity(0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_tipoPlanIcon, color: _tipoPlanColor, size: 14),
            const SizedBox(width: 6),
            Text(_tipoPlanLabel, style: GoogleFonts.dmSans(color: _tipoPlanColor, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.purple.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(color: _C.purple.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(children: [
        Positioned(
          right: -20,
          top: -20,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.purple.withOpacity(0.12),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_C.primary, _C.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: _C.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    '${_nombreCtrl.text.trim()} ${_apellidoCtrl.text.trim()}'.trim().isEmpty
                        ? 'Completa tu perfil'
                        : '${_nombreCtrl.text.trim()} ${_apellidoCtrl.text.trim()}'.trim(),
                    style: GoogleFonts.dmSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _email.isNotEmpty ? _email : 'Sin correo registrado',
                    style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(children: [
                Expanded(
                  child: _heroStat(
                    'Plan actual',
                    _nombrePlan,
                    _tipoPlanColor,
                    _tipoPlanIcon,
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white.withOpacity(0.08)),
                Expanded(
                  child: _heroStat(
                    'Vence el',
                    _fechaVencimiento != null ? _formatFecha(_fechaVencimiento!) : '—',
                    _C.accent,
                    Icons.event_rounded,
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _heroStat(String label, String value, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.dmSans(color: color, fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 9.5), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildPlanCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _tipoPlanColor.withOpacity(0.3), width: 1.2),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _tipoPlanColor.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(bottom: BorderSide(color: _tipoPlanColor.withOpacity(0.15))),
          ),
          child: Row(children: [
            Icon(_tipoPlanIcon, color: _tipoPlanColor, size: 16),
            const SizedBox(width: 8),
            Text('Tu membresía', style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: _tipoPlanColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_tipoPlanLabel, style: GoogleFonts.dmSans(color: _tipoPlanColor, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _resumenFila(Icons.workspace_premium_rounded, 'Plan', _nombrePlan, _tipoPlanColor),
            _resumenFila(Icons.event_rounded, 'Vencimiento', _fechaVencimiento != null ? _formatFecha(_fechaVencimiento!) : '—', _C.accent),
            const SizedBox(height: 12),
            // ── Botón cambiar plan ──
            SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_C.primary, _C.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: _C.primary.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RenovarMembresiaWidget()),
                      );
                      if (result == true) {
                        _cargarDatos();
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Center(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _tipoPlan == 'vouchers' ? 'Cambiar a Plan Completo' : 'Cambiar / Renovar Plan',
                          style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
            if (_tipoPlan == 'vouchers') ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _C.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.warning.withOpacity(0.25)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, color: _C.warning, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Con el plan completo accedes a clientes, planes, informes, facturación y más.',
                      style: GoogleFonts.dmSans(color: _C.warning, fontSize: 11),
                    ),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _resumenFila(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Text('$label:', style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 12.5)),
        const Spacer(),
        Text(value, style: GoogleFonts.dmSans(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildDatosPersonales() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _C.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.person_rounded, color: _C.primary, size: 16),
            ),
            const SizedBox(width: 10),
            Text('Datos personales', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          // Nombre y Apellido
          Row(children: [
            Expanded(
              child: _buildField(
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
              child: _buildField(
                controller: _apellidoCtrl,
                focusNode: _apellidoFocus,
                label: 'APELLIDO',
                hint: 'Pérez',
                icon: Icons.badge_outlined,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _buildField(
            controller: _telefonoCtrl,
            focusNode: _telefonoFocus,
            label: 'TELÉFONO (WhatsApp)',
            hint: '+57 300 0000000',
            icon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Requerido';
              if (v.trim().length < 7) return 'Número muy corto';
              return null;
            },
          ),
        ]),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 7),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            color: Colors.white38,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
      TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(color: Colors.white24, fontSize: 13),
          prefixIcon: Container(
            margin: const EdgeInsets.fromLTRB(14, 9, 10, 9),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _C.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: _C.primary, size: 16),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white.withOpacity(0.12), width: 1.2),
            borderRadius: BorderRadius.circular(14),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _C.primary, width: 2),
            borderRadius: BorderRadius.circular(14),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _C.danger, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _C.danger, width: 2),
            borderRadius: BorderRadius.circular(14),
          ),
          errorStyle: GoogleFonts.dmSans(color: _C.danger, fontSize: 11),
        ),
      ),
    ]);
  }

  Widget _buildBotonGuardar() {
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
          color: _isLoading ? Colors.white.withOpacity(0.08) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isLoading
              ? []
              : [
                  BoxShadow(color: _C.primary.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : _guardar,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: _isLoading
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white.withOpacity(0.5)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Guardando...', style: GoogleFonts.dmSans(color: Colors.white60, fontSize: 15, fontWeight: FontWeight.w600)),
                    ])
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text('Guardar cambios', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}
