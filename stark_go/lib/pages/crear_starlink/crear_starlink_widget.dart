import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ← NUEVO

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
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label, hint;
  final IconData icon;
  final Color iconColor;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    required this.iconColor,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child:
            Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      ),
      TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.6), fontSize: 14),
          prefixIcon: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          filled: true,
          fillColor: _C.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _C.border, width: 1.2), borderRadius: BorderRadius.circular(14)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: iconColor, width: 1.8), borderRadius: BorderRadius.circular(14)),
          errorBorder: OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.5), borderRadius: BorderRadius.circular(14)),
          focusedErrorBorder:
              OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.8), borderRadius: BorderRadius.circular(14)),
          errorStyle: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 11),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────
//  MAIN WIDGET
// ─────────────────────────────────────────────
class CrearStarlinkWidget extends StatefulWidget {
  const CrearStarlinkWidget({super.key});
  static String routeName = 'CrearStarlink';
  static String routePath = 'crearStarlink';

  @override
  State<CrearStarlinkWidget> createState() => _CrearStarlinkWidgetState();
}

class _CrearStarlinkWidgetState extends State<CrearStarlinkWidget> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _nombreCtrl = TextEditingController();
  final _ubicacionCtrl = TextEditingController();
  final _planCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  final _nombreFocus = FocusNode();
  final _ubicacionFocus = FocusNode();
  final _planFocus = FocusNode();
  final _notasFocus = FocusNode();

  DateTime _fechaInstalacion = DateTime.now();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _ubicacionCtrl.dispose();
    _planCtrl.dispose();
    _notasCtrl.dispose();
    _nombreFocus.dispose();
    _ubicacionFocus.dispose();
    _planFocus.dispose();
    _notasFocus.dispose();
    super.dispose();
  }

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaInstalacion,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _C.primary, onSurface: _C.textPri)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _fechaInstalacion = picked);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      // ── UID del usuario autenticado ──────────────────────────
      final uid = FirebaseAuth.instance.currentUser?.uid;
      // ────────────────────────────────────────────────────────

      await FirebaseFirestore.instance.collection('starlinks').add({
        'nombre': _nombreCtrl.text.trim(),
        'ubicacion': _ubicacionCtrl.text.trim(),
        'plan_pago': _planCtrl.text.trim(),
        'notas': _notasCtrl.text.trim(),
        'fecha_instalacion': Timestamp.fromDate(_fechaInstalacion),
        'fecha_registro': FieldValue.serverTimestamp(),
        'activo': true,
        'clientes_count': 0,
        'propietarioUid': uid, // ← NUEVO
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('"${_nombreCtrl.text}" registrada correctamente', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          ]),
          backgroundColor: _C.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        context.safePop();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          backgroundColor: _C.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
              // ── TOP BAR ──
              Padding(
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
                    Text('Nueva Starlink', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 20, fontWeight: FontWeight.w800)),
                    Text('Registrar punto de distribución', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _C.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _C.primary.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      Icon(Icons.satellite_alt_rounded, color: _C.primary, size: 13),
                      const SizedBox(width: 5),
                      Text('Admin', style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                  child: Column(children: [
                    // Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: _C.dark.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      child: Row(children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [_C.primary, _C.accent]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.satellite_alt_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Registrar Starlink',
                              style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text('Cada Starlink es un punto de distribución para tus clientes.',
                              style: GoogleFonts.spaceGrotesk(color: Colors.white60, fontSize: 12)),
                        ])),
                      ]),
                    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0),
                    const SizedBox(height: 16),

                    // ── Sección info ──
                    _seccion(
                      icon: Icons.satellite_alt_rounded,
                      color: _C.primary,
                      title: 'Información de la Starlink',
                      subtitle: 'Nombre e identificación del punto',
                      delay: 100,
                      children: [
                        _Field(
                          controller: _nombreCtrl,
                          focusNode: _nombreFocus,
                          label: 'NOMBRE / IDENTIFICADOR',
                          hint: 'Ej: Starlink Caserío Norte',
                          icon: Icons.satellite_alt_rounded,
                          iconColor: _C.primary,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                        ),
                        _Field(
                          controller: _ubicacionCtrl,
                          focusNode: _ubicacionFocus,
                          label: 'UBICACIÓN / CASERÍO',
                          hint: 'Ej: Caserío La Montaña',
                          icon: Icons.location_on_rounded,
                          iconColor: _C.accent,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Plan que se le paga a Starlink ──
                    _seccion(
                      icon: Icons.payments_rounded,
                      color: _C.success,
                      title: 'Plan que pagas a Starlink',
                      subtitle: 'Costo mensual del servicio Starlink',
                      delay: 180,
                      children: [
                        _Field(
                          controller: _planCtrl,
                          focusNode: _planFocus,
                          label: 'PLAN / COSTO MENSUAL',
                          hint: 'Ej: \$150/mes  ó  \$250/mes',
                          icon: Icons.receipt_long_rounded,
                          iconColor: _C.success,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                        ),
                        // Chips de referencia rápida
                        Wrap(
                            spacing: 8,
                            children: ['\$150/mes', '\$250/mes', '\$300/mes']
                                .map(
                                  (p) => GestureDetector(
                                    onTap: () {
                                      _planCtrl.text = p;
                                      setState(() {});
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _planCtrl.text == p ? _C.success.withOpacity(0.15) : _C.surfaceDim,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: _planCtrl.text == p ? _C.success : _C.border, width: 1.2),
                                      ),
                                      child: Text(p,
                                          style: GoogleFonts.spaceGrotesk(
                                              color: _planCtrl.text == p ? _C.success : _C.textSec,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                )
                                .toList()),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Fecha ──
                    _seccion(
                      icon: Icons.calendar_month_rounded,
                      color: _C.warning,
                      title: 'Fecha de Instalación',
                      subtitle: 'Cuándo se instaló esta Starlink',
                      delay: 260,
                      children: [
                        GestureDetector(
                          onTap: _pickFecha,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: _C.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _C.border, width: 1.2),
                            ),
                            child: Row(children: [
                              Container(
                                margin: const EdgeInsets.only(right: 10),
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(color: _C.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
                                child: const Icon(Icons.calendar_today_rounded, color: _C.warning, size: 17),
                              ),
                              Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('FECHA DE INSTALACIÓN',
                                    style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                    '${_fechaInstalacion.day.toString().padLeft(2, '0')}/${_fechaInstalacion.month.toString().padLeft(2, '0')}/${_fechaInstalacion.year}',
                                    style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w600)),
                              ])),
                              Icon(Icons.edit_calendar_rounded, color: _C.textSec.withOpacity(0.5), size: 18),
                            ]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Notas ──
                    _seccion(
                      icon: Icons.notes_rounded,
                      color: _C.purple,
                      title: 'Notas adicionales',
                      subtitle: 'Observaciones (opcional)',
                      delay: 320,
                      children: [
                        _Field(
                          controller: _notasCtrl,
                          focusNode: _notasFocus,
                          label: 'NOTAS',
                          hint: 'Ej: Necesita mantenimiento en lluvia',
                          icon: Icons.edit_note_rounded,
                          iconColor: _C.purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Botón ──
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          gradient: _isLoading ? null : const LinearGradient(colors: [_C.primary, _C.accent]),
                          color: _isLoading ? _C.border : null,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _isLoading
                              ? []
                              : [BoxShadow(color: _C.primary.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
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
                                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_C.textSec))),
                                      const SizedBox(width: 10),
                                      Text('Guardando...',
                                          style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 15, fontWeight: FontWeight.w600)),
                                    ])
                                  : Row(mainAxisSize: MainAxisSize.min, children: [
                                      const Icon(Icons.satellite_alt_rounded, color: Colors.white, size: 20),
                                      const SizedBox(width: 10),
                                      Text('Registrar Starlink',
                                          style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                                    ]),
                            ),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 350.ms, delay: 400.ms).slideY(begin: 0.05, end: 0),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _seccion({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required List<Widget> children,
    int delay = 0,
  }) {
    return Container(
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
          const SizedBox(height: 18),
          ...children.map((w) => Padding(padding: const EdgeInsets.only(bottom: 14), child: w)),
        ]),
      ),
    ).animate().fadeIn(duration: 350.ms, delay: Duration(milliseconds: delay)).slideY(begin: 0.05, end: 0);
  }
}
