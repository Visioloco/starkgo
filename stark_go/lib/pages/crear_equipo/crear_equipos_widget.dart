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
class CrearEquipoWidget extends StatefulWidget {
  const CrearEquipoWidget({super.key});
  static String routeName = 'CrearEquipo';
  static String routePath = 'crearEquipo';

  @override
  State<CrearEquipoWidget> createState() => _CrearEquipoWidgetState();
}

class _CrearEquipoWidgetState extends State<CrearEquipoWidget> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // 'antena' o 'router'
  String _tipoEquipo = 'antena';

  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _ipCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  final _marcaFocus = FocusNode();
  final _modeloFocus = FocusNode();
  final _ipFocus = FocusNode();
  final _notasFocus = FocusNode();

  // Marcas predefinidas para sugerencias rápidas
  static const _marcasAntena = ['TP-Link', 'Ubiquiti', 'Mikrotik', 'Cambium'];
  static const _marcasRouter = ['TP-Link', 'Mikrotik', 'ASUS', 'Tenda', 'Huawei'];
  static const _modelosAntena = ['CPE210', 'CPE510', 'M5 Gen2', 'M5 Normal', 'LiteBeam M5', 'NanoBeam M5'];
  static const _modelosRouter = ['TL-WR840N', 'RB951', 'RB750', 'Archer C6', 'AC10'];

  @override
  void dispose() {
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _ipCtrl.dispose();
    _notasCtrl.dispose();
    _marcaFocus.dispose();
    _modeloFocus.dispose();
    _ipFocus.dispose();
    _notasFocus.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      // ── UID del usuario autenticado ──────────────────────────
      final uid = FirebaseAuth.instance.currentUser?.uid;
      // ────────────────────────────────────────────────────────

      await FirebaseFirestore.instance.collection('equipos').add({
        'tipo': _tipoEquipo,
        'marca': _marcaCtrl.text.trim(),
        'modelo': _modeloCtrl.text.trim(),
        'ip': _ipCtrl.text.trim(),
        'notas': _notasCtrl.text.trim(),
        'fecha_registro': FieldValue.serverTimestamp(),
        'disponible': true,
        'propietarioUid': uid, // ← NUEVO
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('${_marcaCtrl.text} ${_modeloCtrl.text} registrado', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          ]),
          backgroundColor: _C.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        // Limpiar para registrar otro equipo
        _marcaCtrl.clear();
        _modeloCtrl.clear();
        _ipCtrl.clear();
        _notasCtrl.clear();
        setState(() {});
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
    final isAntena = _tipoEquipo == 'antena';
    final tipoColor = isAntena ? _C.accent : _C.purple;

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
                    Text('Nuevo Equipo', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 20, fontWeight: FontWeight.w800)),
                    Text('Registrar antena o router', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: tipoColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: tipoColor.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      Icon(isAntena ? Icons.cell_tower_rounded : Icons.router_rounded, color: tipoColor, size: 13),
                      const SizedBox(width: 5),
                      Text(isAntena ? 'Antena' : 'Router',
                          style: GoogleFonts.spaceGrotesk(color: tipoColor, fontSize: 12, fontWeight: FontWeight.w600)),
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
                        gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1A2F4A)]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: _C.dark.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      child: Row(children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [tipoColor, tipoColor.withOpacity(0.6)]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(isAntena ? Icons.cell_tower_rounded : Icons.router_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Registrar Equipo',
                              style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text('Los equipos registrados aquí aparecerán al crear clientes.',
                              style: GoogleFonts.spaceGrotesk(color: Colors.white60, fontSize: 12)),
                        ])),
                      ]),
                    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0),
                    const SizedBox(height: 16),

                    // ── Selector tipo ──
                    _seccion(
                      icon: Icons.category_rounded,
                      color: _C.primary,
                      title: 'Tipo de Equipo',
                      subtitle: '¿Es una antena o un router?',
                      delay: 80,
                      children: [
                        Row(children: [
                          Expanded(child: _tipoBtn('antena', 'Antena', Icons.cell_tower_rounded, _C.accent)),
                          const SizedBox(width: 10),
                          Expanded(child: _tipoBtn('router', 'Router', Icons.router_rounded, _C.purple)),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Datos del equipo ──
                    _seccion(
                      icon: isAntena ? Icons.cell_tower_rounded : Icons.router_rounded,
                      color: tipoColor,
                      title: 'Datos del Equipo',
                      subtitle: 'Marca, modelo e IP asignada',
                      delay: 160,
                      children: [
                        // Sugerencias de marca
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _Field(
                            controller: _marcaCtrl,
                            focusNode: _marcaFocus,
                            label: 'MARCA',
                            hint: isAntena ? 'Ej: TP-Link' : 'Ej: Mikrotik',
                            icon: Icons.business_rounded,
                            iconColor: tipoColor,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                          ),
                          const SizedBox(height: 8),
                          // Chips de marca rápida
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: (isAntena ? _marcasAntena : _marcasRouter)
                                .map(
                                  (m) => GestureDetector(
                                    onTap: () {
                                      _marcaCtrl.text = m;
                                      setState(() {});
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: _marcaCtrl.text == m ? tipoColor.withOpacity(0.12) : _C.surfaceDim,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: _marcaCtrl.text == m ? tipoColor : _C.border, width: 1.2),
                                      ),
                                      child: Text(m,
                                          style: GoogleFonts.spaceGrotesk(
                                              color: _marcaCtrl.text == m ? tipoColor : _C.textSec,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ]),

                        // Modelo
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _Field(
                            controller: _modeloCtrl,
                            focusNode: _modeloFocus,
                            label: 'MODELO',
                            hint: isAntena ? 'Ej: CPE210' : 'Ej: RB951',
                            icon: Icons.devices_rounded,
                            iconColor: tipoColor,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                          ),
                          const SizedBox(height: 8),
                          // Chips de modelo rápido
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: (isAntena ? _modelosAntena : _modelosRouter)
                                .map(
                                  (m) => GestureDetector(
                                    onTap: () {
                                      _modeloCtrl.text = m;
                                      setState(() {});
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: _modeloCtrl.text == m ? tipoColor.withOpacity(0.12) : _C.surfaceDim,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: _modeloCtrl.text == m ? tipoColor : _C.border, width: 1.2),
                                      ),
                                      child: Text(m,
                                          style: GoogleFonts.spaceGrotesk(
                                              color: _modeloCtrl.text == m ? tipoColor : _C.textSec,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ]),

                        // IP
                        _Field(
                          controller: _ipCtrl,
                          focusNode: _ipFocus,
                          label: 'IP ASIGNADA',
                          hint: 'Ej: 192.168.1.10',
                          icon: Icons.wifi_rounded,
                          iconColor: _C.success,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Notas ──
                    _seccion(
                      icon: Icons.notes_rounded,
                      color: _C.warning,
                      title: 'Notas',
                      subtitle: 'Observaciones del equipo (opcional)',
                      delay: 280,
                      children: [
                        _Field(
                          controller: _notasCtrl,
                          focusNode: _notasFocus,
                          label: 'NOTAS',
                          hint: 'Ej: Equipo usado, en buen estado',
                          icon: Icons.edit_note_rounded,
                          iconColor: _C.warning,
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
                          gradient: _isLoading ? null : LinearGradient(colors: [tipoColor, tipoColor.withOpacity(0.7)]),
                          color: _isLoading ? _C.border : null,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow:
                              _isLoading ? [] : [BoxShadow(color: tipoColor.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
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
                                      Icon(isAntena ? Icons.cell_tower_rounded : Icons.router_rounded, color: Colors.white, size: 20),
                                      const SizedBox(width: 10),
                                      Text('Registrar ${isAntena ? 'Antena' : 'Router'}',
                                          style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                                    ]),
                            ),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 350.ms, delay: 360.ms).slideY(begin: 0.05, end: 0),

                    const SizedBox(height: 16),

                    // ── Lista de equipos registrados ──
                    _ListaEquipos(tipoActual: _tipoEquipo),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tipoBtn(String tipo, String label, IconData icon, Color color) {
    final selected = _tipoEquipo == tipo;
    return GestureDetector(
      onTap: () => setState(() {
        _tipoEquipo = tipo;
        _marcaCtrl.clear();
        _modeloCtrl.clear();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : _C.surfaceDim,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : _C.border, width: selected ? 2 : 1.2),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? color : _C.textSec, size: 26),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.spaceGrotesk(color: selected ? color : _C.textSec, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
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

// ─────────────────────────────────────────────
//  LISTA DE EQUIPOS REGISTRADOS
// ─────────────────────────────────────────────
class _ListaEquipos extends StatelessWidget {
  final String tipoActual;
  const _ListaEquipos({required this.tipoActual});

  @override
  Widget build(BuildContext context) {
    final isAntena = tipoActual == 'antena';
    final color = isAntena ? _C.accent : _C.purple;

    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(isAntena ? Icons.cell_tower_rounded : Icons.router_rounded, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Text('${isAntena ? 'Antenas' : 'Routers'} registrados',
                style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('equipos')
                .where('tipo', isEqualTo: tipoActual)
                .orderBy('fecha_registro', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: _C.primary, strokeWidth: 2),
                ));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                      child: Text('Aún no hay ${isAntena ? 'antenas' : 'routers'} registrados.',
                          style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13))),
                );
              }
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _C.surfaceDim,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _C.border),
                    ),
                    child: Row(children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
                        child: Icon(isAntena ? Icons.cell_tower_rounded : Icons.router_rounded, color: color, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${d['marca']} ${d['modelo']}',
                            style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('IP: ${d['ip']}', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: _C.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('Disponible',
                            style: GoogleFonts.spaceGrotesk(color: _C.success, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  );
                }).toList(),
              );
            },
          ),
        ]),
      ),
    );
  }
}
