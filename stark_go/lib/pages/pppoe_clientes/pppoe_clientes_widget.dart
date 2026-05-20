import 'package:stark_go/services/vps_service.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─── Paleta ─────────────────────────────────────────────────
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
  static const Color pppoe = Color(0xFF0EA5E9);
}

// ════════════════════════════════════════════════════════════
//  LISTA DE CLIENTES PPPOE
// ════════════════════════════════════════════════════════════
class PppoeClientesWidget extends StatefulWidget {
  const PppoeClientesWidget({super.key});
  static String routeName = 'PppoeClientes';
  static String routePath = 'pppoeClientes';

  @override
  State<PppoeClientesWidget> createState() => _PppoeClientesWidgetState();
}

class _PppoeClientesWidgetState extends State<PppoeClientesWidget> {
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  String _busqueda = '';
  final _ctrlBusqueda = TextEditingController();

  @override
  void dispose() {
    _ctrlBusqueda.dispose();
    super.dispose();
  }

  // ── Eliminar cliente ────────────────────────────────────
  Future<void> _eliminar(String docId, String usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Eliminar PPPoE', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
        content: Text('Se eliminara el secreto "$usuario" de MikroTik y de la app.', style: GoogleFonts.spaceGrotesk(color: _C.textSec)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _C.textSec)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _C.danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    await VpsService.pppoeEliminar(usuario: usuario);
    await FirebaseFirestore.instance.collection('pppoe_clientes').doc(docId).delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('PPPoE "$usuario" eliminado', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        backgroundColor: _C.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: _C.surfaceDim,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(context),
          _buildBusqueda(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pppoe_clientes')
                  .where('propietarioUid', isEqualTo: _uid)
                  .orderBy('fecha', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return _buildVacio();
                }
                final docs = snap.data!.docs.where((d) {
                  if (_busqueda.isEmpty) return true;
                  final data = d.data() as Map<String, dynamic>;
                  final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                  final usuario = (data['usuarioPppoe'] ?? '').toString().toLowerCase();
                  return nombre.contains(_busqueda) || usuario.contains(_busqueda);
                }).toList();

                if (docs.isEmpty) return _buildVacio();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildCard(doc.id, data, i).animate().fadeIn(duration: 300.ms, delay: (i * 50).ms).slideY(begin: 0.05, end: 0);
                  },
                );
              },
            ),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed('CrearPppoe'),
        backgroundColor: _C.pppoe,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Nuevo PPPoE', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ── Card de cliente ─────────────────────────────────────
  Widget _buildCard(String docId, Map<String, dynamic> data, int index) {
    final nombre = data['nombre'] ?? '';
    final usuario = data['usuarioPppoe'] ?? '';
    final bajada = data['bajada'] ?? '';
    final subida = data['subida'] ?? '';
    final perfil = data['perfil'] ?? '';
    final ip = data['ip'] ?? '';
    final estado = data['estado'] ?? 'activo';
    final activo = estado == 'activo';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: activo ? _C.pppoe.withOpacity(0.2) : _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Encabezado
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_C.pppoe, _C.purple]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.cable_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nombre, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
                Text('@$usuario', style: GoogleFonts.spaceGrotesk(color: _C.pppoe, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: activo ? _C.success.withOpacity(0.1) : _C.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: activo ? _C.success.withOpacity(0.3) : _C.danger.withOpacity(0.3)),
              ),
              child: Text(activo ? 'Activo' : 'Inactivo',
                  style: GoogleFonts.spaceGrotesk(color: activo ? _C.success : _C.danger, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 12),
          Divider(color: _C.border, height: 1),
          const SizedBox(height: 12),

          // Info chips
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip(Icons.arrow_downward_rounded, _C.accent, 'Bajada', bajada),
            _chip(Icons.arrow_upward_rounded, _C.primary, 'Subida', subida),
            _chip(Icons.layers_rounded, _C.purple, 'Perfil', perfil.replaceAll('starkgo_', '')),
            if (ip.isNotEmpty) _chip(Icons.router_rounded, _C.success, 'IP', ip),
          ]),
          const SizedBox(height: 12),

          // Botones
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _abrirEditar(context, docId, data),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: Text('Editar', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.pppoe,
                  side: BorderSide(color: _C.pppoe.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _eliminar(docId, usuario),
              style: OutlinedButton.styleFrom(
                foregroundColor: _C.danger,
                side: BorderSide(color: _C.danger.withOpacity(0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              ),
              child: const Icon(Icons.delete_outline_rounded, size: 18),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, Color color, String label, String valor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.spaceGrotesk(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
            Text(valor, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ]),
      );

  // ── Abrir bottom sheet edicion ──────────────────────────
  void _abrirEditar(BuildContext context, String docId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditarPppoeSheet(
        docId: docId,
        data: data,
        uid: _uid!,
      ),
    );
  }

  // ── Buscador ────────────────────────────────────────────
  Widget _buildBusqueda() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(
          controller: _ctrlBusqueda,
          onChanged: (v) => setState(() => _busqueda = v.toLowerCase()),
          style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Buscar por nombre o usuario...',
            hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.5), fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, color: _C.textSec, size: 20),
            suffixIcon: _busqueda.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, color: _C.textSec, size: 18),
                    onPressed: () {
                      _ctrlBusqueda.clear();
                      setState(() => _busqueda = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: _C.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            enabledBorder:
                OutlineInputBorder(borderSide: BorderSide(color: _C.border, width: 1.2), borderRadius: BorderRadius.circular(14)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _C.pppoe, width: 1.8), borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );

  Widget _buildVacio() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: _C.pppoe.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.cable_rounded, color: _C.pppoe, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Sin clientes PPPoE', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Toca el boton + para agregar uno', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13)),
        ]),
      );

  Widget _buildTopBar(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
              Text('Clientes PPPoE', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 20, fontWeight: FontWeight.w800)),
              Text('Secretos activos en MikroTik', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
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
              const Icon(Icons.cable_rounded, color: _C.pppoe, size: 13),
              const SizedBox(width: 5),
              Text('PPPoE', style: GoogleFonts.spaceGrotesk(color: _C.pppoe, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );
}

// ════════════════════════════════════════════════════════════
//  BOTTOM SHEET — EDITAR PPPOE
// ════════════════════════════════════════════════════════════
class _EditarPppoeSheet extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String uid;

  const _EditarPppoeSheet({
    required this.docId,
    required this.data,
    required this.uid,
  });

  @override
  State<_EditarPppoeSheet> createState() => _EditarPppoeSheetState();
}

class _EditarPppoeSheetState extends State<_EditarPppoeSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late final TextEditingController _ctrlNombre;
  late final TextEditingController _ctrlUsuario;
  late final TextEditingController _ctrlClave;
  late final TextEditingController _ctrlBajada;
  late final TextEditingController _ctrlSubida;
  late final TextEditingController _ctrlPerfil;
  late final TextEditingController _ctrlIp;

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _ctrlNombre = TextEditingController(text: d['nombre'] ?? '');
    _ctrlUsuario = TextEditingController(text: d['usuarioPppoe'] ?? '');
    _ctrlClave = TextEditingController(text: d['clavePppoe'] ?? '');
    _ctrlBajada = TextEditingController(text: d['bajada'] ?? '');
    _ctrlSubida = TextEditingController(text: d['subida'] ?? '');
    _ctrlPerfil = TextEditingController(text: d['perfil'] ?? '');
    _ctrlIp = TextEditingController(text: d['ip'] ?? '');
  }

  @override
  void dispose() {
    for (final c in [_ctrlNombre, _ctrlUsuario, _ctrlClave, _ctrlBajada, _ctrlSubida, _ctrlPerfil, _ctrlIp]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _validarVelocidad(String? val) {
    if (val == null || val.trim().isEmpty) return 'Requerido';
    if (!RegExp(r'^\d+(\.\d+)?[MmKkGg]?$').hasMatch(val.trim())) return 'Ej: 10M o 512K';
    return null;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final usuario = _ctrlUsuario.text.trim();
      final clave = _ctrlClave.text.trim();
      final nombre = _ctrlNombre.text.trim();
      final subida = _ctrlSubida.text.trim();
      final bajada = _ctrlBajada.text.trim();
      final perfil = _ctrlPerfil.text.trim();
      final ip = _ctrlIp.text.trim();
      final perfilFinal = perfil.isNotEmpty ? perfil : 'starkgo_$usuario';

      // 1. Reencolar en VPS para actualizar MikroTik
      await VpsService.pppoeCrear(
        usuario: usuario,
        clave: clave,
        nombre: nombre,
        subida: subida,
        bajada: bajada,
        perfil: perfilFinal,
      );

      // 2. Actualizar Firestore — siempre con propietarioUid
      await FirebaseFirestore.instance.collection('pppoe_clientes').doc(widget.docId).update({
        'nombre': nombre,
        'usuarioPppoe': usuario,
        'clavePppoe': clave,
        'bajada': bajada,
        'subida': subida,
        'perfil': perfilFinal,
        'ip': ip,
        'propietarioUid': widget.uid,
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('PPPoE actualizado correctamente', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          ]),
          backgroundColor: _C.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
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

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(2)),
            ),
            // Titulo
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration:
                    BoxDecoration(gradient: const LinearGradient(colors: [_C.pppoe, _C.purple]), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Editar PPPoE', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w800)),
                Text('Los cambios se aplican en MikroTik', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
              ]),
            ]),
            const SizedBox(height: 20),

            // ── Campos ────────────────────────────────────
            _campoEditar(_ctrlNombre, 'NOMBRE CLIENTE', 'Juan Perez', Icons.badge_rounded, _C.pppoe,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
            const SizedBox(height: 12),
            _campoEditar(_ctrlUsuario, 'USUARIO PPPOE', 'finca_usuario', Icons.account_circle_rounded, _C.purple,
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
            const SizedBox(height: 12),
            _campoEditar(_ctrlClave, 'CLAVE PPPOE', 'Nueva clave', Icons.lock_rounded, _C.purple,
                obscure: true, validator: (v) => (v == null || v.trim().length < 4) ? 'Minimo 4 caracteres' : null),
            const SizedBox(height: 12),

            // Velocidades en fila
            Row(children: [
              Expanded(
                child: _campoEditar(_ctrlBajada, 'BAJADA', '10M', Icons.arrow_downward_rounded, _C.accent,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.MmKkGg]'))], validator: _validarVelocidad),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _campoEditar(_ctrlSubida, 'SUBIDA', '5M', Icons.arrow_upward_rounded, _C.primary,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.MmKkGg]'))], validator: _validarVelocidad),
              ),
            ]),
            const SizedBox(height: 12),
            _campoEditar(_ctrlPerfil, 'PERFIL (opcional)', 'starkgo_usuario', Icons.layers_rounded, _C.textSec,
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))]),
            const SizedBox(height: 12),
            _campoEditar(_ctrlIp, 'IP FIJA (opcional)', '192.168.100.50', Icons.router_rounded, _C.success,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]),
            const SizedBox(height: 20),

            // Boton guardar
            SizedBox(
              width: double.infinity,
              height: 52,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: _isLoading ? null : const LinearGradient(colors: [_C.pppoe, _C.purple]),
                  color: _isLoading ? _C.border : null,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _isLoading ? [] : [BoxShadow(color: _C.pppoe.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 5))],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading ? null : _guardar,
                    borderRadius: BorderRadius.circular(14),
                    child: Center(
                      child: _isLoading
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_C.textSec))),
                              const SizedBox(width: 8),
                              Text('Actualizando en MikroTik...',
                                  style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 14, fontWeight: FontWeight.w600)),
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
    );
  }

  // ── Campo editar compacto ───────────────────────────────
  Widget _campoEditar(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon,
    Color color, {
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 5),
        child:
            Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      ),
      TextFormField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.4), fontSize: 13),
          prefixIcon: Container(
            margin: const EdgeInsets.fromLTRB(10, 7, 7, 7),
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 15),
          ),
          filled: true,
          fillColor: _C.surfaceDim,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _C.border, width: 1.1), borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: color, width: 1.7), borderRadius: BorderRadius.circular(12)),
          errorBorder: OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.3), borderRadius: BorderRadius.circular(12)),
          focusedErrorBorder:
              OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.7), borderRadius: BorderRadius.circular(12)),
          errorStyle: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 10),
        ),
      ),
    ]);
  }
}
