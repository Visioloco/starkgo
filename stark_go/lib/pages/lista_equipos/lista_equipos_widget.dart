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

class ListaEquiposWidget extends StatefulWidget {
  const ListaEquiposWidget({super.key});
  static String routeName = 'ListaEquipos';
  static String routePath = 'listaEquipos';

  @override
  State<ListaEquiposWidget> createState() => _ListaEquiposWidgetState();
}

class _ListaEquiposWidgetState extends State<ListaEquiposWidget> {
  String _filtro = 'todos'; // 'todos' | 'antena' | 'router'
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  // ── Eliminar equipo ──
  Future<void> _eliminar(String docId, String nombre) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Eliminar equipo', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
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
      await FirebaseFirestore.instance.collection('equipos').doc(docId).delete();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Equipo eliminado', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          backgroundColor: _C.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
    }
  }

  // ── Editar equipo ──
  Future<void> _editar(String docId, Map<String, dynamic> data) async {
    final marcaCtrl = TextEditingController(text: data['marca'] ?? '');
    final modeloCtrl = TextEditingController(text: data['modelo'] ?? '');
    final ipCtrl = TextEditingController(text: data['ip'] ?? '');
    final notasCtrl = TextEditingController(text: data['notas'] ?? '');
    String tipo = data['tipo'] ?? 'antena';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Editar Equipo', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Tipo
            Row(
                children: ['antena', 'router']
                    .map((t) => Expanded(
                            child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () => setS(() => tipo = t),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: tipo == t ? (t == 'antena' ? _C.accent : _C.purple).withOpacity(0.1) : _C.surfaceDim,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: tipo == t ? (t == 'antena' ? _C.accent : _C.purple) : _C.border, width: 1.5),
                              ),
                              child: Center(
                                  child: Text(t == 'antena' ? 'Antena' : 'Router',
                                      style: GoogleFonts.spaceGrotesk(
                                          color: tipo == t ? (t == 'antena' ? _C.accent : _C.purple) : _C.textSec,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13))),
                            ),
                          ),
                        )))
                    .toList()),
            const SizedBox(height: 14),
            _editField(marcaCtrl, 'Marca', Icons.business_rounded, _C.primary),
            const SizedBox(height: 10),
            _editField(modeloCtrl, 'Modelo', Icons.devices_rounded, _C.accent),
            const SizedBox(height: 10),
            _editField(ipCtrl, 'IP', Icons.wifi_rounded, _C.success),
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
                  'tipo': tipo,
                  'marca': marcaCtrl.text.trim(),
                  'modelo': modeloCtrl.text.trim(),
                  'ip': ipCtrl.text.trim(),
                  'notas': notasCtrl.text.trim(),
                };

                // Agrega uid si el doc no lo tiene aún
                if (_uid != null && (data['propietarioUid'] == null || data['propietarioUid'] == '')) {
                  updates['propietarioUid'] = _uid;
                }

                await FirebaseFirestore.instance.collection('equipos').doc(docId).update(updates);
                if (mounted) Navigator.pop(ctx);
              },
              child: Text('Guardar', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
            ),
          ],
        ),
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

  // ── Filtrar: uid del usuario actual + los que no tienen uid ──
  List<QueryDocumentSnapshot> _filtrarDocs(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final docUid = data['propietarioUid'];
      return docUid == _uid || docUid == null || docUid == '';
    }).toList();
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
              Text('Equipos', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 20, fontWeight: FontWeight.w800)),
              Text('Antenas y routers registrados', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
            ])),
            GestureDetector(
              onTap: () => context.pushNamed(CrearEquipoWidget.routeName),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_C.accent, _C.success]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: _C.accent.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text('Nuevo', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),

        // ── FILTRO TABS ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(children: [
            _tab('todos', 'Todos', Icons.devices_rounded, _C.primary),
            const SizedBox(width: 8),
            _tab('antena', 'Antenas', Icons.cell_tower_rounded, _C.accent),
            const SizedBox(width: 8),
            _tab('router', 'Routers', Icons.router_rounded, _C.purple),
          ]),
        ),

        // ── LISTA ──
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _filtro == 'todos'
                ? FirebaseFirestore.instance.collection('equipos').snapshots()
                : FirebaseFirestore.instance.collection('equipos').where('tipo', isEqualTo: _filtro).snapshots(),
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
                  final isAntena = data['tipo'] == 'antena';
                  final color = isAntena ? _C.accent : _C.purple;
                  final sinUid = data['propietarioUid'] == null || data['propietarioUid'] == '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: _C.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: sinUid ? _C.warning.withOpacity(0.6) : color.withOpacity(0.25),
                        width: sinUid ? 1.8 : 1.2,
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
                    ),
                    child: Column(children: [
                      // Banner de aviso si no tiene uid
                      if (sinUid)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: _C.warning.withOpacity(0.1),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                          ),
                          child: Row(children: [
                            Icon(Icons.warning_amber_rounded, color: _C.warning, size: 14),
                            const SizedBox(width: 6),
                            Text('Sin propietario — toca editar para asignarlo',
                                style: GoogleFonts.spaceGrotesk(color: _C.warning, fontSize: 11, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(isAntena ? Icons.cell_tower_rounded : Icons.router_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${data['marca'] ?? ''} ${data['modelo'] ?? ''}',
                                style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Row(children: [
                              _chip(Icons.wifi_rounded, 'IP: ${data['ip'] ?? '-'}', _C.success),
                              const SizedBox(width: 6),
                              _chip(isAntena ? Icons.cell_tower_rounded : Icons.router_rounded, isAntena ? 'Antena' : 'Router', color),
                            ]),
                            if ((data['notas'] ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(data['notas'],
                                  style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
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
                            // Eliminar
                            GestureDetector(
                              onTap: () => _eliminar(doc.id, '${data['marca'] ?? ''} ${data['modelo'] ?? ''}'),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(color: _C.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.delete_rounded, color: _C.danger, size: 16),
                              ),
                            ),
                          ]),
                        ]),
                      ),
                    ]),
                  ).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: i * 50)).slideY(begin: 0.04, end: 0);
                },
              );
            },
          ),
        ),
      ])),
    );
  }

  Widget _tab(String value, String label, IconData icon, Color color) {
    final selected = _filtro == value;
    return GestureDetector(
      onTap: () => setState(() => _filtro = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : _C.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : _C.border, width: selected ? 1.8 : 1.2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: selected ? color : _C.textSec, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.spaceGrotesk(
                  color: selected ? color : _C.textSec, fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.spaceGrotesk(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _emptyState() {
    return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: _C.accent.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.devices_rounded, color: _C.accent, size: 30)),
      const SizedBox(height: 16),
      Text('Sin equipos registrados', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(
        _filtro == 'todos'
            ? 'Toca "Nuevo" para agregar tu primer equipo.'
            : 'No hay ${_filtro == 'antena' ? 'antenas' : 'routers'} registrados.',
        style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    ]));
  }
}
