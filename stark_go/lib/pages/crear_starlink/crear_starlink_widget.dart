import '/flutter_flow/flutter_flow_util.dart';
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
//  HELPER — parsear valor ingresado por el usuario
//
//  Casos cubiertos:
//    "150000"      → 150000.0  (sin formato)
//    "150.000"     → 150000.0  (punto = miles, formato colombiano)
//    "150,000"     → 150000.0  (coma = miles, formato anglosajón)
//    "150.000,50"  → 150000.5  (punto miles + coma decimal)
//    "150,000.50"  → 150000.5  (coma miles + punto decimal)
//    "1500.50"     → 1500.5    (punto decimal, menos de 3 dígitos después)
//    "1500,50"     → 1500.5    (coma decimal, menos de 3 dígitos después)
// ─────────────────────────────────────────────
double _parsearValor(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return 0;

  final tienePunto = s.contains('.');
  final tieneComa = s.contains(',');

  String limpio;

  if (tienePunto && tieneComa) {
    // Ambos presentes → el último es el separador decimal
    final ultimoPunto = s.lastIndexOf('.');
    final ultimaComa = s.lastIndexOf(',');
    if (ultimaComa > ultimoPunto) {
      // "150.000,50" → punto=miles, coma=decimal
      limpio = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // "150,000.50" → coma=miles, punto=decimal
      limpio = s.replaceAll(',', '');
    }
  } else if (tienePunto && !tieneComa) {
    // Solo punto → si hay exactamente 3 dígitos tras él, es miles
    final partes = s.split('.');
    final digitosDespues = partes.last.length;
    if (digitosDespues == 3 && partes.length >= 2) {
      // "150.000" → miles → quitar punto
      limpio = s.replaceAll('.', '');
    } else {
      // "150.5" → decimal → dejar como está
      limpio = s;
    }
  } else if (!tienePunto && tieneComa) {
    // Solo coma → si hay exactamente 3 dígitos tras ella, es miles
    final partes = s.split(',');
    final digitosDespues = partes.last.length;
    if (digitosDespues == 3 && partes.length >= 2) {
      // "150,000" → miles → quitar coma
      limpio = s.replaceAll(',', '');
    } else {
      // "150,5" → decimal → convertir coma a punto
      limpio = s.replaceAll(',', '.');
    }
  } else {
    // Solo dígitos
    limpio = s;
  }

  return double.tryParse(limpio) ?? 0;
}

// ─────────────────────────────────────────────
//  CAMPO DE TEXTO GENÉRICO
// ─────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label, hint;
  final IconData icon;
  final Color iconColor;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;

  const _Field({
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
  final _planValorCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  final _nombreFocus = FocusNode();
  final _ubicacionFocus = FocusNode();
  final _planValorFocus = FocusNode();
  final _notasFocus = FocusNode();

  DateTime _fechaInstalacion = DateTime.now();

  _Moneda? _monedaSel;
  String? _monedaError;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _ubicacionCtrl.dispose();
    _planValorCtrl.dispose();
    _notasCtrl.dispose();
    _nombreFocus.dispose();
    _ubicacionFocus.dispose();
    _planValorFocus.dispose();
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
    setState(() => _monedaError = _monedaSel == null ? 'Selecciona una moneda' : null);
    if (!_formKey.currentState!.validate()) return;
    if (_monedaSel == null) return;

    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      // ✅ "150.000" → 150000.0  |  "250" → 250.0  |  "1500,50" → 1500.5
      final valorDouble = _parsearValor(_planValorCtrl.text);

      await FirebaseFirestore.instance.collection('starlinks').add({
        'nombre': _nombreCtrl.text.trim(),
        'ubicacion': _ubicacionCtrl.text.trim(),
        'plan_pago': valorDouble,
        'plan_pago_moneda_codigo': _monedaSel!.codigo,
        'plan_pago_moneda_nombre': _monedaSel!.nombre,
        'plan_pago_moneda_simbolo': _monedaSel!.simbolo,
        'notas': _notasCtrl.text.trim(),
        'fecha_instalacion': Timestamp.fromDate(_fechaInstalacion),
        'fecha_registro': FieldValue.serverTimestamp(),
        'activo': true,
        'clientes_count': 0,
        'propietarioUid': uid,
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

  Widget _buildMonedaDropdown() {
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
            color: _monedaError != null ? _C.danger : (_monedaSel != null ? _C.success : _C.border),
            width: _monedaSel != null ? 1.8 : 1.2,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<_Moneda>(
            value: _monedaSel,
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
                decoration: BoxDecoration(color: _C.success.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
                child: Icon(Icons.currency_exchange_rounded, color: _C.success, size: 16),
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
                          decoration: BoxDecoration(color: _C.success.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
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
            onChanged: (m) => setState(() {
              _monedaSel = m;
              _monedaError = null;
            }),
          ),
        ),
      ),
      if (_monedaError != null)
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4),
          child: Text(_monedaError!, style: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 11)),
        ),
    ]);
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
                    // ── Banner ──
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

                    // ── Sección: Información ──
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

                    // ── Sección: Plan ──
                    _seccion(
                      icon: Icons.payments_rounded,
                      color: _C.success,
                      title: 'Plan que pagas a Starlink',
                      subtitle: 'Costo mensual del servicio Starlink',
                      delay: 180,
                      children: [
                        _Field(
                          controller: _planValorCtrl,
                          focusNode: _planValorFocus,
                          label: 'VALOR / COSTO MENSUAL',
                          hint: 'Ej: 150.000  ó  250',
                          icon: Icons.receipt_long_rounded,
                          iconColor: _C.success,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                        ),
                        // Chips de referencia rápida — ahora con formato colombiano
                        Wrap(
                            spacing: 8,
                            children: ['150.000', '250.000', '300.000']
                                .map(
                                  (p) => GestureDetector(
                                    onTap: () => setState(() => _planValorCtrl.text = p),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _planValorCtrl.text == p ? _C.success.withOpacity(0.15) : _C.surfaceDim,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: _planValorCtrl.text == p ? _C.success : _C.border, width: 1.2),
                                      ),
                                      child: Text(p,
                                          style: GoogleFonts.spaceGrotesk(
                                              color: _planValorCtrl.text == p ? _C.success : _C.textSec,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                )
                                .toList()),
                        _buildMonedaDropdown(),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Sección: Fecha ──
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
                                    '${_fechaInstalacion.day.toString().padLeft(2, '0')}/'
                                    '${_fechaInstalacion.month.toString().padLeft(2, '0')}/'
                                    '${_fechaInstalacion.year}',
                                    style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w600)),
                              ])),
                              Icon(Icons.edit_calendar_rounded, color: _C.textSec.withOpacity(0.5), size: 18),
                            ]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Sección: Notas ──
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

                    // ── Botón guardar ──
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
