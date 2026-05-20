import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'planes_model.dart';
export 'planes_model.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
}

// ─────────────────────────────────────────────
//  MONEDAS POR PAÍS
// ─────────────────────────────────────────────
class _Moneda {
  final String codigo;
  final String nombre;
  final String simbolo;
  final String bandera;
  const _Moneda(this.codigo, this.nombre, this.simbolo, this.bandera);
}

const _monedas = [
  _Moneda('COP', 'Peso Colombiano', 'COP \$', '🇨🇴'),
  _Moneda('USD', 'Dólar Estadounidense', 'USD \$', '🇺🇸'),
  _Moneda('EUR', 'Euro', '€', '🇪🇺'),
  _Moneda('MXN', 'Peso Mexicano', 'MXN \$', '🇲🇽'),
  _Moneda('ARS', 'Peso Argentino', 'ARS \$', '🇦🇷'),
  _Moneda('CLP', 'Peso Chileno', 'CLP \$', '🇨🇱'),
  _Moneda('PEN', 'Sol Peruano', 'S/', '🇵🇪'),
  _Moneda('BRL', 'Real Brasileño', 'R\$', '🇧🇷'),
  _Moneda('VES', 'Bolívar Venezolano', 'Bs.', '🇻🇪'),
  _Moneda('GTQ', 'Quetzal Guatemalteco', 'Q', '🇬🇹'),
  _Moneda('HNL', 'Lempira Hondureño', 'L', '🇭🇳'),
  _Moneda('GBP', 'Libra Esterlina', '£', '🇬🇧'),
  _Moneda('CAD', 'Dólar Canadiense', 'CAD \$', '🇨🇦'),
];

// ─────────────────────────────────────────────
//  HELPER — formatear con puntos de miles
// ─────────────────────────────────────────────
String _formatearValor(dynamic raw) {
  final num valor = (raw is num) ? raw : double.tryParse(raw.toString()) ?? 0;
  final String sinDecimales = valor.toStringAsFixed(0);
  final buffer = StringBuffer();
  int count = 0;
  for (int i = sinDecimales.length - 1; i >= 0; i--) {
    if (count > 0 && count % 3 == 0) buffer.write('.');
    buffer.write(sinDecimales[i]);
    count++;
  }
  return buffer.toString().split('').reversed.join('');
}

// ─────────────────────────────────────────────
//  CAMPO DE TEXTO
// ─────────────────────────────────────────────
class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label, hint;
  final IconData icon;
  final Color iconColor;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;

  const _FormField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    required this.iconColor,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.inputFormatters,
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
        inputFormatters: inputFormatters,
        style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w500),
        validator: validator,
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
//  SECCIÓN DE FORMULARIO
// ─────────────────────────────────────────────
class _FormSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final List<Widget> children;

  const _FormSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 18),
          ...children.map((w) => Padding(padding: const EdgeInsets.only(bottom: 14), child: w)),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════
//  MAIN WIDGET
// ═════════════════════════════════════════════
class PlanesWidget extends StatefulWidget {
  const PlanesWidget({super.key});

  static String routeName = 'Planes';
  static String routePath = 'planes';

  @override
  State<PlanesWidget> createState() => _PlanesWidgetState();
}

class _PlanesWidgetState extends State<PlanesWidget> {
  late PlanesModel _model;
  bool _isLoading = false;

  // Dropdown moneda
  _Moneda? _monedaSel;
  String? _monedaError;

  // Lista de planes desde Firestore
  List<QueryDocumentSnapshot> _planes = [];
  bool _cargandoPlanes = true;

  // UID del usuario autenticado
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PlanesModel());
    _model.initControllers();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarPlanes());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  //  HELPER — formatear con puntos de miles
  // ─────────────────────────────────────────
  String _fmt(dynamic raw) => _formatearValor(raw);

  // ── Cargar planes del usuario autenticado ──
  Future<void> _cargarPlanes() async {
    if (_uid == null) return;
    setState(() => _cargandoPlanes = true);
    final snap = await FirebaseFirestore.instance.collection('planes').where('propietarioUid', isEqualTo: _uid).get();
    if (mounted) {
      setState(() {
        _planes = snap.docs;
        _cargandoPlanes = false;
      });
    }
  }

  // ── Limpiar formulario ──
  void _limpiarForm() {
    _model.tcNombre.clear();
    _model.tcValor.clear();
    _model.tcDescripcion.clear();
    setState(() {
      _monedaSel = null;
      _monedaError = null;
    });
  }

  // ── Parsear valor escrito (quitar puntos de miles si el usuario los escribió) ──
  double _parsearValorInput(String raw) {
    // Elimina puntos de miles y comas, deja solo dígitos y punto decimal real
    final limpio = raw.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(limpio) ?? 0;
  }

  // ── Guardar plan ──
  Future<void> _guardar() async {
    setState(() => _monedaError = _monedaSel == null ? 'Selecciona una moneda' : null);
    if (_model.formKey.currentState == null || !_model.formKey.currentState!.validate()) return;
    if (_monedaSel == null) return;
    if (_uid == null) {
      _snack('No hay sesión activa', _C.danger, Icons.error_rounded);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final valorDouble = _parsearValorInput(_model.tcValor.text);
      await FirebaseFirestore.instance.collection('planes').add({
        'nombre': _model.tcNombre.text.trim(),
        'valor': valorDouble, // ✅ se guarda como double limpio
        'descripcion': _model.tcDescripcion.text.trim(),
        'monedaCodigo': _monedaSel!.codigo,
        'monedaNombre': _monedaSel!.nombre,
        'monedaSimbolo': _monedaSel!.simbolo,
        'propietarioUid': _uid,
        'fechaCreacion': FieldValue.serverTimestamp(),
      });
      _limpiarForm();
      await _cargarPlanes();
      if (mounted) _snack('Plan guardado correctamente', _C.success, Icons.check_circle_rounded);
    } catch (e) {
      if (mounted) _snack('Error al guardar: $e', _C.danger, Icons.error_rounded);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Eliminar plan ──
  Future<void> _eliminar(String docId, String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Eliminar plan', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontWeight: FontWeight.w700)),
        content: Text('¿Eliminar el plan "$nombre"? Esta acción no se puede deshacer.',
            style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _C.textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: GoogleFonts.spaceGrotesk(color: _C.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance.collection('planes').doc(docId).delete();
    _snack('Plan "$nombre" eliminado', _C.warning, Icons.delete_rounded);
    _cargarPlanes();
  }

  // ── Editar plan (bottom sheet) ──
  Future<void> _editarPlan(QueryDocumentSnapshot doc) async {
    final d = doc.data() as Map<String, dynamic>;
    // ✅ Muestra el valor formateado con puntos de miles al editar
    final valorFormateado = _fmt(d['valor'] ?? 0);
    final tcN = TextEditingController(text: d['nombre'] ?? '');
    final tcV = TextEditingController(text: valorFormateado);
    final tcD = TextEditingController(text: d['descripcion'] ?? '');
    _Moneda? monedaEdit = _monedas.cast<_Moneda?>().firstWhere((m) => m?.codigo == (d['monedaCodigo'] ?? ''), orElse: () => null);
    String? mError;
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: _C.surfaceDim,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(99)),
                  ),
                ),
                const SizedBox(height: 16),
                // Header
                Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_C.warning, Color(0xFFF97316)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Editar Plan', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 17, fontWeight: FontWeight.w800)),
                    Text('Modifica los datos del plan', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
                  ]),
                ]),
                const SizedBox(height: 20),

                // Campos
                _editField(tcN, 'NOMBRE DEL PLAN', 'Ej: Plan Básico', Icons.label_rounded, _C.primary),
                const SizedBox(height: 14),
                _editField(tcV, 'VALOR', 'Ej: 50.000', Icons.payments_rounded, _C.success,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    // ✅ Permite dígitos, puntos y comas
                    formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))]),
                const SizedBox(height: 14),
                _editField(tcD, 'DESCRIPCIÓN', 'Descripción del plan', Icons.description_rounded, _C.accent),
                const SizedBox(height: 14),

                // Dropdown moneda
                _buildMonedaDropdown(
                  value: monedaEdit,
                  errorText: mError,
                  onChanged: (m) => setBS(() {
                    monedaEdit = m;
                    mError = null;
                  }),
                ),
                const SizedBox(height: 24),

                // Botón guardar
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      gradient: saving ? null : const LinearGradient(colors: [_C.warning, Color(0xFFF97316)]),
                      color: saving ? _C.border : null,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: saving ? [] : [BoxShadow(color: _C.warning.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: saving
                            ? null
                            : () async {
                                if (tcN.text.trim().isEmpty || tcV.text.trim().isEmpty) return;
                                if (monedaEdit == null) {
                                  setBS(() => mError = 'Selecciona una moneda');
                                  return;
                                }
                                setBS(() => saving = true);
                                // ✅ Parsear valor correctamente al guardar edición
                                final valorDouble = _parsearValorInput(tcV.text);
                                await FirebaseFirestore.instance.collection('planes').doc(doc.id).update({
                                  'nombre': tcN.text.trim(),
                                  'valor': valorDouble,
                                  'descripcion': tcD.text.trim(),
                                  'monedaCodigo': monedaEdit!.codigo,
                                  'monedaNombre': monedaEdit!.nombre,
                                  'monedaSimbolo': monedaEdit!.simbolo,
                                  'propietarioUid': _uid,
                                });
                                Navigator.pop(ctx);
                                _snack('Plan actualizado', _C.success, Icons.check_circle_rounded);
                                _cargarPlanes();
                              },
                        child: Center(
                          child: saving
                              ? Row(mainAxisSize: MainAxisSize.min, children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_C.textSec)),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('Guardando...', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontWeight: FontWeight.w600)),
                                ])
                              : Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Guardar cambios',
                                      style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                                ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helper: campo en bottom sheet ──
  Widget _editField(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon,
    Color color, {
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? formatters,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child:
            Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      ),
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        inputFormatters: formatters,
        style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.6), fontSize: 14),
          prefixIcon: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: color, size: 17),
          ),
          filled: true,
          fillColor: _C.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _C.border, width: 1.2), borderRadius: BorderRadius.circular(14)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: color, width: 1.8), borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ]);
  }

  // ── Dropdown moneda reutilizable ──
  Widget _buildMonedaDropdown({
    required _Moneda? value,
    required String? errorText,
    required ValueChanged<_Moneda?> onChanged,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text('MONEDA',
            style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      ),
      Container(
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: errorText != null ? _C.danger : (value != null ? _C.primary : _C.border),
            width: value != null ? 1.8 : 1.2,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<_Moneda>(
            value: value,
            isExpanded: true,
            borderRadius: BorderRadius.circular(14),
            dropdownColor: _C.surface,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            icon: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.keyboard_arrow_down_rounded, color: _C.textSec),
            ),
            hint: Row(children: [
              Container(
                margin: const EdgeInsets.only(left: 6, right: 10),
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: _C.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
                child: Icon(Icons.currency_exchange_rounded, color: _C.primary, size: 16),
              ),
              Text('Selecciona la moneda', style: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.6), fontSize: 14)),
            ]),
            items: _monedas
                .map((m) => DropdownMenuItem<_Moneda>(
                      value: m,
                      child: Row(children: [
                        Container(
                          margin: const EdgeInsets.only(left: 4, right: 10),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(color: _C.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                          child: Center(child: Text(m.bandera, style: const TextStyle(fontSize: 17))),
                        ),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Text('${m.codigo} — ${m.simbolo}',
                                style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(m.nombre, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
                          ]),
                        ),
                      ]),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
      if (errorText != null)
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4),
          child: Text(errorText, style: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 11)),
        ),
    ]);
  }

  void _snack(String msg, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.spaceGrotesk(color: Colors.white))),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ═══════════════════════
  //  BUILD
  // ═══════════════════════
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
              // ── Top bar ──
              _buildTopBar(context),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                  child: Column(children: [
                    // Banner
                    _buildBanner().animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0),
                    const SizedBox(height: 16),

                    // ── Formulario nuevo plan ──
                    _FormSection(
                      icon: Icons.add_card_rounded,
                      color: _C.primary,
                      title: 'Nuevo Plan',
                      subtitle: 'Ingresa los datos del plan de servicio',
                      children: [
                        _FormField(
                          controller: _model.tcNombre,
                          focusNode: _model.fnNombre,
                          label: 'NOMBRE DEL PLAN',
                          hint: 'Ej: Plan Básico',
                          icon: Icons.label_rounded,
                          iconColor: _C.primary,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
                        ),
                        _FormField(
                          controller: _model.tcValor,
                          focusNode: _model.fnValor,
                          label: 'VALOR DEL PLAN',
                          hint: 'Ej: 60.000',
                          icon: Icons.payments_rounded,
                          iconColor: _C.success,
                          // ✅ Permite dígitos, puntos de miles y coma decimal
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'El valor es obligatorio' : null,
                        ),
                        _FormField(
                          controller: _model.tcDescripcion,
                          focusNode: _model.fnDescripcion,
                          label: 'DESCRIPCIÓN',
                          hint: 'Descripción breve del plan',
                          icon: Icons.description_rounded,
                          iconColor: _C.accent,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'La descripción es obligatoria' : null,
                        ),
                        _buildMonedaDropdown(
                          value: _monedaSel,
                          errorText: _monedaError,
                          onChanged: (m) => setState(() {
                            _monedaSel = m;
                            _monedaError = null;
                          }),
                        ),
                      ],
                    ).animate().fadeIn(duration: 350.ms, delay: 100.ms).slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 16),

                    // Botón guardar
                    _buildSubmitButton().animate().fadeIn(duration: 350.ms, delay: 200.ms).slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 24),

                    // ── Lista de planes ──
                    _buildListaHeader(),
                    const SizedBox(height: 12),
                    _buildListaPlanes(),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

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
            Text('Planes de Servicio', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 20, fontWeight: FontWeight.w800)),
            Text('Crea y administra los planes', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _C.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.primary.withOpacity(0.3)),
          ),
          child: Row(children: [
            Icon(Icons.list_alt_rounded, color: _C.primary, size: 13),
            const SizedBox(width: 5),
            Text('${_planes.length}', style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_C.dark, Color(0xFF1E293B)]),
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
          child: const Icon(Icons.add_card_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Gestión de Planes', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text('Define planes con nombre, valor y moneda.', style: GoogleFonts.spaceGrotesk(color: Colors.white60, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: _isLoading ? null : const LinearGradient(colors: [_C.primary, _C.accent]),
          color: _isLoading ? _C.border : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isLoading ? [] : [BoxShadow(color: _C.primary.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
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
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_C.textSec)),
                      ),
                      const SizedBox(width: 10),
                      Text('Guardando...', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 15, fontWeight: FontWeight.w600)),
                    ])
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text('Guardar Plan', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListaHeader() {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_C.success, _C.accent]),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.format_list_bulleted_rounded, color: Colors.white, size: 16),
      ),
      const SizedBox(width: 10),
      Text('Planes registrados', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
      const Spacer(),
      GestureDetector(
        onTap: _cargarPlanes,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.border)),
          child: Icon(Icons.refresh_rounded, color: _C.textSec, size: 16),
        ),
      ),
    ]);
  }

  Widget _buildListaPlanes() {
    if (_cargandoPlanes) {
      return Container(
        height: 120,
        decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _C.border)),
        child: Center(child: CircularProgressIndicator(color: _C.primary, strokeWidth: 2)),
      );
    }
    if (_planes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _C.border)),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _C.surfaceDim, shape: BoxShape.circle),
            child: Icon(Icons.inbox_rounded, color: _C.textSec, size: 32),
          ),
          const SizedBox(height: 12),
          Text('Sin planes registrados', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Crea el primer plan arriba', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
        ]),
      );
    }

    return Column(
      children: _planes.asMap().entries.map((entry) {
        final idx = entry.key;
        final doc = entry.value;
        final d = doc.data() as Map<String, dynamic>;
        final moneda = d['monedaCodigo'] ?? '';
        final simbolo = d['monedaSimbolo'] ?? '';

        // ✅ CORRECCIÓN PRINCIPAL: mostrar valor formateado con puntos de miles
        final valor = _fmt(d['valor'] ?? 0);

        final bandera = _monedas.cast<_Moneda?>().firstWhere((m) => m?.codigo == moneda, orElse: () => null)?.bandera ?? '💵';

        final colors = [_C.primary, _C.accent, _C.success, _C.warning, _C.purple];
        final color = colors[idx % colors.length];

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _C.border, width: 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.wifi_tethering_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d['nombre'] ?? '', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(d['descripcion'] ?? '',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _C.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _C.success.withOpacity(0.3)),
                        ),
                        child: Text('$simbolo $valor',
                            style: GoogleFonts.spaceGrotesk(color: _C.success, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _C.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _C.primary.withOpacity(0.2)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(bandera, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(moneda, style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                  ]),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  _actionBtn(icon: Icons.edit_rounded, color: _C.warning, onTap: () => _editarPlan(doc)),
                  const SizedBox(height: 6),
                  _actionBtn(icon: Icons.delete_rounded, color: _C.danger, onTap: () => _eliminar(doc.id, d['nombre'] ?? '')),
                ]),
              ]),
            ),
          ).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: 60 * idx)),
        );
      }).toList(),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}
