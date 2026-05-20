import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

class _RenovacionOpcion {
  final String label;
  final int dias;
  const _RenovacionOpcion(this.label, this.dias);
}

const _opciones = [
  _RenovacionOpcion('+1 mes', 30),
  _RenovacionOpcion('+3 meses', 90),
  _RenovacionOpcion('+6 meses', 180),
  _RenovacionOpcion('+1 año', 365),
];

class ListaOperadoresWidget extends StatefulWidget {
  const ListaOperadoresWidget({super.key});
  static String routeName = 'ListaOperadores';
  static String routePath = 'listaOperadores';

  @override
  State<ListaOperadoresWidget> createState() => _ListaOperadoresWidgetState();
}

class _ListaOperadoresWidgetState extends State<ListaOperadoresWidget> {
  String _busqueda = '';
  bool _renovando = false;

  // ── Estado del operador ──────────────────────────────────
  _EstadoMembresia _estado(Timestamp? fechaTs) {
    if (fechaTs == null) return _EstadoMembresia.vencido;
    final fecha = fechaTs.toDate();
    final diff = fecha.difference(DateTime.now()).inDays;
    if (diff < 0) return _EstadoMembresia.vencido;
    if (diff <= 30) return _EstadoMembresia.proxVencer;
    return _EstadoMembresia.activo;
  }

  Color _colorEstado(_EstadoMembresia e) {
    switch (e) {
      case _EstadoMembresia.activo:
        return _C.success;
      case _EstadoMembresia.proxVencer:
        return _C.warning;
      case _EstadoMembresia.vencido:
        return _C.danger;
    }
  }

  String _labelEstado(_EstadoMembresia e, Timestamp? ts) {
    if (ts == null) return 'Sin fecha';
    final fecha = ts.toDate();
    final diff = fecha.difference(DateTime.now()).inDays;
    switch (e) {
      case _EstadoMembresia.activo:
        return 'Activo · $diff días';
      case _EstadoMembresia.proxVencer:
        return 'Vence pronto · $diff días';
      case _EstadoMembresia.vencido:
        final hace = DateTime.now().difference(fecha).inDays;
        return 'Vencido hace $hace días';
    }
  }

  // ── Renovar membresía ────────────────────────────────────
  Future<void> _renovar(
    BuildContext context,
    String docId,
    String nombre,
    Timestamp? fechaActual,
    _RenovacionOpcion opcion,
  ) async {
    final confirmar = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Confirmar renovación', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 15)),
            content: RichText(
              text: TextSpan(
                style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14),
                children: [
                  const TextSpan(text: 'Agregar '),
                  TextSpan(
                    text: opcion.label.replaceAll('+', ''),
                    style: const TextStyle(color: _C.primary, fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' a la membresía de '),
                  TextSpan(
                    text: nombre,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: '.\n\n¿Confirmar?'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _C.textSec)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Confirmar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmar) return;

    setState(() => _renovando = true);
    try {
      // Si ya está vencido, la nueva fecha parte desde HOY
      // Si aún está activo, se suma a la fecha existente
      final base = (fechaActual != null && fechaActual.toDate().isAfter(DateTime.now())) ? fechaActual.toDate() : DateTime.now();

      final nuevaFecha = base.add(Duration(days: opcion.dias));

      await FirebaseFirestore.instance.collection('user').doc(docId).update({
        'fechaVencimiento': Timestamp.fromDate(nuevaFecha),
        'activo': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Membresía renovada hasta ${_formatFecha(nuevaFecha)}',
                style: GoogleFonts.spaceGrotesk(color: Colors.white),
              ),
            ),
          ]),
          backgroundColor: _C.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al renovar: $e', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          backgroundColor: _C.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _renovando = false);
    }
  }

  String _formatFecha(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _iniciales(String nombre, String apellido) {
    final n = nombre.trim().isNotEmpty ? nombre.trim()[0].toUpperCase() : '';
    final a = apellido.trim().isNotEmpty ? apellido.trim()[0].toUpperCase() : '';
    return '$n$a';
  }

  // ════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surfaceDim,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(context),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('user').where('rol', isEqualTo: 'operador').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return Center(
                    child: CircularProgressIndicator(color: _C.primary, strokeWidth: 2.5),
                  );
                }

                final todos = snap.data!.docs;
                final filtrados = _busqueda.isEmpty
                    ? todos
                    : todos.where((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        final nombre = '${d['nombre'] ?? ''} ${d['apellido'] ?? ''}'.toLowerCase();
                        final correo = (d['email'] ?? '').toString().toLowerCase();
                        final q = _busqueda.toLowerCase();
                        return nombre.contains(q) || correo.contains(q);
                      }).toList();

                // ── Stats ──
                final activos = todos.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final ts = d['fechaVencimiento'] as Timestamp?;
                  return _estado(ts) == _EstadoMembresia.activo;
                }).length;
                final proxVencer = todos.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final ts = d['fechaVencimiento'] as Timestamp?;
                  return _estado(ts) == _EstadoMembresia.proxVencer;
                }).length;
                final vencidos = todos.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final ts = d['fechaVencimiento'] as Timestamp?;
                  return _estado(ts) == _EstadoMembresia.vencido;
                }).length;

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                  child: Column(children: [
                    // ── Stats ──
                    _buildStats(todos.length, activos, proxVencer, vencidos).animate().fadeIn(duration: 300.ms),

                    const SizedBox(height: 14),

                    // ── Buscador ──
                    _buildBuscador(),

                    const SizedBox(height: 10),

                    if (filtrados.isEmpty)
                      _buildVacio()
                    else
                      ...filtrados.asMap().entries.map((e) {
                        final doc = e.value;
                        final d = doc.data() as Map<String, dynamic>;
                        return _buildCard(doc.id, d).animate().fadeIn(duration: 300.ms, delay: (e.key * 60).ms).slideY(begin: 0.04, end: 0);
                      }),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
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
            Text('Operadores', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 20, fontWeight: FontWeight.w800)),
            Text('Gestión de membresías', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  // ── Stats ────────────────────────────────────────────────
  Widget _buildStats(int total, int activos, int proxVencer, int vencidos) {
    return Row(children: [
      _statChip(Icons.people_rounded, total.toString(), 'Total', _C.primary),
      const SizedBox(width: 8),
      _statChip(Icons.wifi_rounded, activos.toString(), 'Activos', _C.success),
      const SizedBox(width: 8),
      _statChip(Icons.warning_amber_rounded, proxVencer.toString(), 'Pronto', _C.warning),
      const SizedBox(width: 8),
      _statChip(Icons.block_rounded, vencidos.toString(), 'Vencidos', _C.danger),
    ]);
  }

  Widget _statChip(IconData icon, String valor, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25), width: 1),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(valor, style: GoogleFonts.spaceGrotesk(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 9, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  // ── Buscador ─────────────────────────────────────────────
  Widget _buildBuscador() {
    return TextField(
      onChanged: (v) => setState(() => _busqueda = v),
      style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Buscar por nombre o correo...',
        hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.5), fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded, color: _C.textSec, size: 20),
        suffixIcon: _busqueda.isNotEmpty
            ? GestureDetector(
                onTap: () => setState(() => _busqueda = ''),
                child: const Icon(Icons.close_rounded, color: _C.textSec, size: 18),
              )
            : null,
        filled: true,
        fillColor: _C.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _C.border, width: 1.2), borderRadius: BorderRadius.circular(14)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _C.primary, width: 1.8), borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ── Card operador ────────────────────────────────────────
  Widget _buildCard(String docId, Map<String, dynamic> d) {
    final nombre = (d['nombre'] ?? '').toString();
    final apellido = (d['apellido'] ?? '').toString();
    final correo = (d['email'] ?? '').toString();
    final ts = d['fechaVencimiento'] as Timestamp?;
    final plan = (d['planMembresia'] ?? '').toString();
    final estado = _estado(ts);
    final color = _colorEstado(estado);
    final labelEstado = _labelEstado(estado, ts);
    final fechaStr = ts != null ? _formatFecha(ts.toDate()) : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: estado == _EstadoMembresia.vencido ? _C.danger.withOpacity(0.4) : _C.border,
          width: 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header ──
          Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _iniciales(nombre, apellido),
                  style: GoogleFonts.spaceGrotesk(color: color, fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      '$nombre $apellido',
                      style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withOpacity(0.3), width: 1),
                    ),
                    child: Text(
                      estado == _EstadoMembresia.activo
                          ? 'Activo'
                          : estado == _EstadoMembresia.proxVencer
                              ? 'Pronto'
                              : 'Vencido',
                      style: GoogleFonts.spaceGrotesk(color: color, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ]),
                Text(correo, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11), overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),

          const SizedBox(height: 10),

          // ── Info membresía ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _C.surfaceDim,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.workspace_premium_rounded, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                'Plan $plan  ·  Vence $fechaStr',
                style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                labelEstado,
                style: GoogleFonts.spaceGrotesk(color: color, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ]),
          ),

          const SizedBox(height: 10),

          // ── Botones renovación ──
          Row(children: [
            Expanded(
              child: Text(
                'Renovar membresía:',
                style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Row(
            children: _opciones.map((op) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: _renovando ? null : () => _renovar(context, docId, '$nombre $apellido', ts, op),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _C.primary.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _C.primary.withOpacity(0.25), width: 1),
                      ),
                      child: Text(
                        op.label,
                        style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 11, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ]),
      ),
    );
  }

  // ── Vacío ────────────────────────────────────────────────
  Widget _buildVacio() {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      child: Column(children: [
        Icon(Icons.people_outline_rounded, color: _C.textSec.withOpacity(0.4), size: 48),
        const SizedBox(height: 12),
        Text('No se encontraron operadores', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 14)),
      ]),
    );
  }
}

enum _EstadoMembresia { activo, proxVencer, vencido }
