import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────
//  PALETA
// ─────────────────────────────────────────────
class _C {
  static const Color primary = Color(0xFF1A73E8);
  static const Color accent = Color(0xFF00C6AE);
  static const Color danger = Color(0xFFE53935);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF22C55E);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF1F5F9);
  static const Color textPri = Color(0xFF0F172A);
  static const Color textSec = Color(0xFF64748B);
  static const Color cardBorder = Color(0xFFE2E8F0);
}

// ─────────────────────────────────────────────
//  ESTRUCTURA FIRESTORE
//  colección: "velocidades"
//  documento: velocidades/{uid}
//  campos:    { uid, lista: ["2M/10M","512k/2M",...], actualizadoEn }
// ─────────────────────────────────────────────
class ConfigVelocidadesWidget extends StatefulWidget {
  const ConfigVelocidadesWidget({super.key});

  static String routeName = 'ConfigVelocidades';
  static String routePath = 'config-velocidades';

  @override
  State<ConfigVelocidadesWidget> createState() => _ConfigVelocidadesWidgetState();
}

class _ConfigVelocidadesWidgetState extends State<ConfigVelocidadesWidget> {
  // ── colección dedicada por usuario ──────────
  static const String _kCol = 'velocidades'; // velocidades/{uid}

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  List<String> _velocidades = [];
  bool _cargando = true;
  bool _guardando = false;

  final _ctrlSubida = TextEditingController();
  final _ctrlBajada = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _ctrlSubida.dispose();
    _ctrlBajada.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────
  //  FIRESTORE — lee velocidades/{uid}
  // ──────────────────────────────────────────
  Future<void> _cargar() async {
    if (_uid.isEmpty) {
      setState(() => _cargando = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection(_kCol).doc(_uid).get();
      if (doc.exists && mounted) {
        final raw = (doc.data() as Map<String, dynamic>)['lista'];
        setState(() {
          _velocidades = raw is List ? List<String>.from(raw.map((e) => e.toString())) : [];
        });
      }
    } catch (e) {
      debugPrint('[StarkGo] Error cargando velocidades: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ── guarda/sobreescribe velocidades/{uid} ──
  Future<void> _guardar() async {
    if (_uid.isEmpty || _guardando) return;
    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance.collection(_kCol).doc(_uid).set({
        'uid': _uid,
        'lista': _velocidades,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      if (mounted) _snack('Velocidades guardadas', _C.success);
    } catch (e) {
      if (mounted) _snack('Error al guardar: $e', _C.danger);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _agregarVelocidad() {
    if (!_formKey.currentState!.validate()) return;
    final subida = _ctrlSubida.text.trim().toUpperCase();
    final bajada = _ctrlBajada.text.trim().toUpperCase();
    final nueva = '$subida/$bajada';

    if (_velocidades.contains(nueva)) {
      _snack('Esa velocidad ya existe', _C.warning);
      return;
    }
    setState(() {
      _velocidades.add(nueva);
      _ctrlSubida.clear();
      _ctrlBajada.clear();
    });
    FocusScope.of(context).unfocus();
  }

  void _eliminar(int i) => setState(() => _velocidades.removeAt(i));

  void _snack(String msg, Color color) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));

  // ──────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _C.surfaceDim,
        appBar: AppBar(
          backgroundColor: _C.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.textPri, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title:
              Text('Velocidades MikroTik', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 17, fontWeight: FontWeight.w700)),
          centerTitle: false,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(color: _C.cardBorder, height: 1),
          ),
        ),
        body: _cargando
            ? Center(child: CircularProgressIndicator(color: _C.primary, strokeWidth: 2.5))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // ── Header gradient ───────────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_C.primary, _C.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: _C.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.speed_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Velocidades MikroTik',
                              style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                          Text(
                            'Define las velocidades en formato MikroTik.\n'
                            'Ej: 2M/10M  ·  512k/2M  ·  5M/20M',
                            style: GoogleFonts.spaceGrotesk(color: Colors.white70, fontSize: 11, height: 1.4),
                          ),
                        ]),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 12),

                  // ── Info aislamiento por usuario ──────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _C.success.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _C.success.withOpacity(0.25)),
                    ),
                    child: Row(children: [
                      Icon(Icons.person_pin_rounded, color: _C.success, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Estas velocidades son exclusivas de tu cuenta. '
                          'Cada usuario administra las suyas de forma independiente.',
                          style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, height: 1.4),
                        ),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 24),

                  // ── Formulario nueva velocidad ────────────
                  Text('AGREGAR VELOCIDAD',
                      style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                  const SizedBox(height: 10),

                  Form(
                    key: _formKey,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _C.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _C.cardBorder, width: 1.2),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
                      ),
                      child: Column(children: [
                        Row(children: [
                          Expanded(
                              child: _velocityField(
                            controller: _ctrlSubida,
                            label: 'SUBIDA',
                            hint: 'Ej: 2M',
                            icon: Icons.upload_rounded,
                            color: _C.primary,
                          )),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('/', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 22, fontWeight: FontWeight.w700)),
                          ),
                          Expanded(
                              child: _velocityField(
                            controller: _ctrlBajada,
                            label: 'BAJADA',
                            hint: 'Ej: 10M',
                            icon: Icons.download_rounded,
                            color: _C.accent,
                          )),
                        ]),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _C.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                            label: Text('Agregar velocidad',
                                style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                            onPressed: _agregarVelocidad,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _C.primary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _C.primary.withOpacity(0.15)),
                          ),
                          child: Row(children: [
                            Icon(Icons.info_outline_rounded, color: _C.primary, size: 15),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Usa formato MikroTik: k = kilobits, M = megabits.\n'
                                'Ejemplos: 512k · 1M · 2M · 5M · 10M · 20M',
                                style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, height: 1.4),
                              ),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Lista configuradas ────────────────────
                  Row(children: [
                    Expanded(
                      child: Text('VELOCIDADES CONFIGURADAS',
                          style:
                              GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _C.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${_velocidades.length}',
                          style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 10),

                  if (_velocidades.isEmpty) _buildEmptyState() else ..._velocidades.asMap().entries.map((e) => _buildTile(e.value, e.key)),

                  const SizedBox(height: 28),

                  // ── Guardar ───────────────────────────────
                  if (_velocidades.isNotEmpty)
                    GestureDetector(
                      onTap: _guardando ? null : _guardar,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _guardando ? [_C.cardBorder, _C.cardBorder] : [_C.primary, _C.accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow:
                              _guardando ? [] : [BoxShadow(color: _C.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: Center(
                          child: _guardando
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Guardar velocidades',
                                      style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                                ]),
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),
                ]),
              ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  WIDGETS HELPERS
  // ──────────────────────────────────────────

  Widget _velocityField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 5),
        child:
            Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      ),
      TextFormField(
        controller: controller,
        textCapitalization: TextCapitalization.characters,
        style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Requerido';
          if (!RegExp(r'^\d+[kKmM]$').hasMatch(v.trim())) {
            return 'Ej: 2M ó 512k';
          }
          return null;
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.5), fontSize: 13),
          prefixIcon: Container(
            margin: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          filled: true,
          fillColor: _C.surfaceDim,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          enabledBorder:
              OutlineInputBorder(borderSide: BorderSide(color: _C.cardBorder, width: 1.2), borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: color, width: 1.8), borderRadius: BorderRadius.circular(12)),
          errorBorder: OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.4), borderRadius: BorderRadius.circular(12)),
          focusedErrorBorder:
              OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.8), borderRadius: BorderRadius.circular(12)),
          errorStyle: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 10),
        ),
      ),
    ]);
  }

  Widget _buildTile(String velocidad, int index) {
    final parts = velocidad.split('/');
    final subida = parts.isNotEmpty ? parts[0] : '-';
    final bajada = parts.length > 1 ? parts[1] : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.cardBorder, width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _C.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.speed_rounded, color: _C.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(velocidad, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
            Row(children: [
              Icon(Icons.upload_rounded, size: 11, color: _C.primary),
              const SizedBox(width: 3),
              Text('$subida subida', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
              const SizedBox(width: 8),
              Icon(Icons.download_rounded, size: 11, color: _C.accent),
              const SizedBox(width: 3),
              Text('$bajada bajada', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
            ]),
          ]),
        ),
        GestureDetector(
          onTap: () => _confirmarEliminar(index, velocidad),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _C.danger.withOpacity(0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: _C.danger, size: 18),
          ),
        ),
      ]),
    );
  }

  void _confirmarEliminar(int index, String velocidad) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Eliminar velocidad', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
        content: RichText(
          text: TextSpan(
            style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14),
            children: [
              const TextSpan(text: '¿Eliminar '),
              TextSpan(text: velocidad, style: const TextStyle(color: _C.danger, fontWeight: FontWeight.w700)),
              const TextSpan(text: '?\n\nLos clientes con esta velocidad asignada no se verán afectados.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _C.textSec)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              _eliminar(index);
            },
            child: Text('Eliminar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.warning.withOpacity(0.4), width: 1.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _C.warning.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.speed_rounded, color: _C.warning, size: 32),
        ),
        const SizedBox(height: 14),
        Text('Sin velocidades configuradas', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          'Agrega las velocidades que usas en MikroTik\n'
          'para que aparezcan al crear o editar un cliente.',
          style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}
