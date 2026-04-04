import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

class ListaStarlinksWidget extends StatefulWidget {
  const ListaStarlinksWidget({super.key});
  static String routeName = 'ListaStarlinks';
  static String routePath = 'listaStarlinks';

  @override
  State<ListaStarlinksWidget> createState() => _ListaStarlinksWidgetState();
}

class _ListaStarlinksWidgetState extends State<ListaStarlinksWidget> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  // ── Filtrar: uid del usuario actual + los que no tienen uid ──
  List<QueryDocumentSnapshot> _filtrarDocs(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final docUid = data['propietarioUid'];
      return docUid == _uid || docUid == null || docUid == '';
    }).toList();
  }

  Future<void> _eliminar(String docId, String nombre) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Eliminar Starlink', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
            content: Text('¿Seguro que quieres eliminar "$nombre"? Esta acción no se puede deshacer.', style: GoogleFonts.spaceGrotesk()),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _C.danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Eliminar', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (ok) {
      await FirebaseFirestore.instance.collection('starlinks').doc(docId).delete();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Starlink eliminada', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          backgroundColor: _C.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
    }
  }

  Future<void> _editar(String docId, Map<String, dynamic> data) async {
    final nombreCtrl = TextEditingController(text: data['nombre'] ?? '');
    final ubicacionCtrl = TextEditingController(text: data['ubicacion'] ?? '');
    final planCtrl = TextEditingController(text: data['plan_pago'] ?? '');
    final notasCtrl = TextEditingController(text: data['notas'] ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Editar Starlink', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          _editField(nombreCtrl, 'Nombre', Icons.satellite_alt_rounded, _C.primary),
          const SizedBox(height: 10),
          _editField(ubicacionCtrl, 'Ubicación', Icons.location_on_rounded, _C.accent),
          const SizedBox(height: 10),
          _editField(planCtrl, 'Plan que pagas', Icons.payments_rounded, _C.success),
          const SizedBox(height: 10),
          _editField(notasCtrl, 'Notas', Icons.notes_rounded, _C.warning),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              final Map<String, dynamic> updates = {
                'nombre': nombreCtrl.text.trim(),
                'ubicacion': ubicacionCtrl.text.trim(),
                'plan_pago': planCtrl.text.trim(),
                'notas': notasCtrl.text.trim(),
              };

              // Agrega uid si el doc no lo tiene aún
              if (_uid != null && (data['propietarioUid'] == null || data['propietarioUid'] == '')) {
                updates['propietarioUid'] = _uid;
              }

              await FirebaseFirestore.instance.collection('starlinks').doc(docId).update(updates);
              if (mounted) Navigator.pop(ctx);
            },
            child: Text('Guardar', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _editField(TextEditingController ctrl, String label, IconData icon, Color color) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12),
        prefixIcon: Icon(icon, color: color, size: 18),
        filled: true,
        fillColor: _C.surfaceDim,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _C.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _C.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: 1.8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surfaceDim,
      body: SafeArea(
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
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))]),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.textPri, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Starlinks', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 20, fontWeight: FontWeight.w800)),
              Text('Puntos de distribución', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
            ])),
            GestureDetector(
              onTap: () => context.pushNamed(CrearStarlinkWidget.routeName),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_C.primary, _C.accent]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: _C.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text('Nueva', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),

        // ── LISTA ──
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // Sin orderBy para evitar error de índice compuesto; ordenamos en Dart
            stream: FirebaseFirestore.instance.collection('starlinks').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _C.primary));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _emptyState();
              }

              // Filtrar: solo uid del usuario + sin uid
              final docs = _filtrarDocs([...snapshot.data!.docs]);
              if (docs.isEmpty) return _emptyState();

              // Ordenar: sin uid primero, luego por fecha desc
              docs.sort((a, b) {
                final da = a.data() as Map<String, dynamic>;
                final db = b.data() as Map<String, dynamic>;
                final aSinUid = da['propietarioUid'] == null || da['propietarioUid'] == '';
                final bSinUid = db['propietarioUid'] == null || db['propietarioUid'] == '';
                if (aSinUid && !bSinUid) return -1;
                if (!aSinUid && bSinUid) return 1;
                final ta = da['fecha_registro'];
                final tb = db['fecha_registro'];
                if (ta == null && tb == null) return 0;
                if (ta == null) return 1;
                if (tb == null) return -1;
                return (tb as Timestamp).compareTo(ta as Timestamp);
              });

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final activo = data['activo'] ?? true;
                  final clientes = data['clientes_count'] ?? 0;
                  final sinUid = data['propietarioUid'] == null || data['propietarioUid'] == '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _C.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sinUid ? _C.warning.withOpacity(0.6) : _C.primary.withOpacity(0.2),
                        width: sinUid ? 1.8 : 1.2,
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 4))],
                    ),
                    child: Column(children: [
                      // Banner de aviso si no tiene uid
                      if (sinUid)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: _C.warning.withOpacity(0.1),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: Row(children: [
                            Icon(Icons.warning_amber_rounded, color: _C.warning, size: 14),
                            const SizedBox(width: 6),
                            Text('Sin propietario — toca editar para asignarlo',
                                style: GoogleFonts.spaceGrotesk(color: _C.warning, fontSize: 11, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)]),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.satellite_alt_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(data['nombre'] ?? '',
                                  style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Row(children: [
                                Icon(Icons.location_on_rounded, size: 12, color: _C.textSec),
                                const SizedBox(width: 3),
                                Text(data['ubicacion'] ?? '', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
                              ]),
                            ])),
                            Column(children: [
                              // Editar — naranja si no tiene uid
                              GestureDetector(
                                onTap: () => _editar(doc.id, data),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                      color: sinUid ? _C.warning.withOpacity(0.15) : _C.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Icon(Icons.edit_rounded, color: sinUid ? _C.warning : _C.primary, size: 16),
                                ),
                              ),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () => _eliminar(doc.id, data['nombre'] ?? ''),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(color: _C.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.delete_rounded, color: _C.danger, size: 16),
                                ),
                              ),
                            ]),
                          ]),
                          const SizedBox(height: 12),
                          Divider(color: _C.border, height: 1),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 6, children: [
                            _chip(Icons.payments_rounded, data['plan_pago'] ?? '', _C.success),
                            _chip(Icons.people_rounded, '$clientes clientes', _C.purple),
                            _chip(activo ? Icons.check_circle_rounded : Icons.cancel_rounded, activo ? 'Activa' : 'Inactiva',
                                activo ? _C.success : _C.danger),
                          ]),
                          if ((data['notas'] ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(children: [
                              Icon(Icons.notes_rounded, size: 12, color: _C.textSec),
                              const SizedBox(width: 4),
                              Expanded(
                                  child: Text(data['notas'],
                                      style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis)),
                            ]),
                          ],
                        ]),
                      ),
                    ]),
                  ).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: i * 60)).slideY(begin: 0.04, end: 0);
                },
              );
            },
          ),
        ),
      ])),
    );
  }

  Widget _chip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 5),
        Text(text, style: GoogleFonts.spaceGrotesk(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _emptyState() {
    return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: _C.primary.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.satellite_alt_rounded, color: _C.primary, size: 30)),
      const SizedBox(height: 16),
      Text('Sin Starlinks registradas', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Toca "Nueva" para agregar tu primera Starlink.', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13)),
    ]));
  }
}
