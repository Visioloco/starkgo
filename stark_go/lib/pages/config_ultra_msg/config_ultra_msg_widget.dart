import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'config_ultra_msg_model.dart';
export 'config_ultra_msg_model.dart';

// ── Paleta idéntica a DetalleCliente ─────────────────────────
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
  static const Color border = Color(0xFFE2E8F0);
  static const Color purple = Color(0xFF7C3AED);
  static const Color whatsapp = Color(0xFF25D366);
}

const String _kCollection = 'config_ultramsg';

// ═════════════════════════════════════════════════════════════
class ConfigUltraMsgWidget extends StatefulWidget {
  const ConfigUltraMsgWidget({super.key});
  static String routeName = 'ConfigUltraMsg';
  static String routePath = 'configUltraMsg';

  @override
  State<ConfigUltraMsgWidget> createState() => _ConfigUltraMsgWidgetState();
}

class _ConfigUltraMsgWidgetState extends State<ConfigUltraMsgWidget> {
  late ConfigUltraMsgModel _model;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ConfigUltraMsgModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  // ── helpers ──────────────────────────────────────────────
  void _snack(String msg, Color bg, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 13))),
      ]),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Abrir bottom-sheet para CREAR o EDITAR ────────────────
  void _abrirFormulario({DocumentSnapshot? doc}) {
    final isEdit = doc != null;
    final data = isEdit ? (doc.data() as Map<String, dynamic>) : <String, dynamic>{};

    final ctrlNombre = TextEditingController(text: data['nombre'] ?? '');
    final ctrlInstance = TextEditingController(text: data['instance'] ?? '');
    final ctrlToken = TextEditingController(text: data['token'] ?? '');
    final ctrlNequi = TextEditingController(text: data['nequi'] ?? '');
    bool ocultarToken = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // ── Handle ───────────────────────────────────
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),

                  // ── Título ───────────────────────────────────
                  Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_C.whatsapp, _C.whatsapp.withOpacity(0.6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.settings_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        isEdit ? 'Editar configuración' : 'Nueva configuración',
                        style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      Text('UltraMsg · WhatsApp API', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
                    ])),
                  ]),
                  const SizedBox(height: 24),

                  // ── Campos ───────────────────────────────────
                  _modalField(
                    controller: ctrlNombre,
                    label: 'NOMBRE / ETIQUETA',
                    hint: 'Ej: Instancia principal',
                    icon: Icons.label_rounded,
                    color: _C.primary,
                  ),
                  const SizedBox(height: 14),
                  _modalField(
                    controller: ctrlInstance,
                    label: 'INSTANCE ID',
                    hint: 'Ej: instance167962',
                    icon: Icons.devices_rounded,
                    color: _C.accent,
                  ),
                  const SizedBox(height: 14),
                  _modalField(
                    controller: ctrlToken,
                    label: 'TOKEN',
                    hint: 'Token de UltraMsg',
                    icon: Icons.vpn_key_rounded,
                    color: _C.purple,
                    obscure: ocultarToken,
                    suffixIcon: IconButton(
                      icon: Icon(
                        ocultarToken ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: _C.textSec,
                        size: 18,
                      ),
                      onPressed: () => setModal(() => ocultarToken = !ocultarToken),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _modalField(
                    controller: ctrlNequi,
                    label: 'NÚMERO NEQUI',
                    hint: 'Ej: 3145336101',
                    icon: Icons.account_balance_wallet_rounded,
                    color: _C.success,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 28),

                  // ── Botón Guardar ────────────────────────────
                  StatefulBuilder(builder: (ctx2, setSave) {
                    return SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _guardando
                            ? null
                            : () async {
                                final instance = ctrlInstance.text.trim();
                                final token = ctrlToken.text.trim();
                                final nequi = ctrlNequi.text.trim();
                                final nombre = ctrlNombre.text.trim();

                                if (instance.isEmpty || token.isEmpty) {
                                  _snack('El Instance ID y el Token son obligatorios', _C.danger, Icons.error_rounded);
                                  return;
                                }

                                setSave(() => _guardando = true);
                                try {
                                  final payload = {
                                    'instance': instance,
                                    'token': token,
                                    'nequi': nequi,
                                    'nombre': nombre.isEmpty ? 'Sin nombre' : nombre,
                                    'creadoEn': FieldValue.serverTimestamp(),
                                  };

                                  if (isEdit) {
                                    await FirebaseFirestore.instance.collection(_kCollection).doc(doc.id).update(payload);
                                  } else {
                                    await FirebaseFirestore.instance.collection(_kCollection).add(payload);
                                  }

                                  if (mounted) Navigator.pop(ctx);
                                  _snack(
                                    isEdit ? 'Configuración actualizada' : 'Configuración creada',
                                    _C.success,
                                    Icons.check_circle_rounded,
                                  );
                                } catch (e) {
                                  _snack('Error: $e', _C.danger, Icons.error_rounded);
                                } finally {
                                  setSave(() => _guardando = false);
                                }
                              },
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [_C.whatsapp, Color(0xFF128C7E)]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: _guardando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      isEdit ? 'Guardar cambios' : 'Crear configuración',
                                      style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                                    ),
                                  ]),
                          ),
                        ),
                      ),
                    );
                  }),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Confirmar y eliminar ──────────────────────────────────
  Future<void> _eliminar(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final nombre = data['nombre'] ?? 'esta configuración';

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Eliminar configuración', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
            content: RichText(
              text: TextSpan(
                style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14),
                children: [
                  const TextSpan(text: '¿Eliminar '),
                  TextSpan(text: '"$nombre"', style: const TextStyle(fontWeight: FontWeight.w700, color: _C.danger)),
                  const TextSpan(text: '?\n\nEsta acción no se puede deshacer.'),
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
                    backgroundColor: _C.danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Eliminar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;
    await FirebaseFirestore.instance.collection(_kCollection).doc(doc.id).delete();
    _snack('Configuración eliminada', _C.danger, Icons.delete_rounded);
  }

  // ── Campo de texto para el modal ─────────────────────────
  Widget _modalField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 6),
        child:
            Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      ),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        obscureText: obscure,
        style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.5), fontSize: 13),
          prefixIcon: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: _C.surfaceDim,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _C.border, width: 1.2), borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: color, width: 1.8), borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ]);
  }

  // ── Tarjeta de cada config ────────────────────────────────
  Widget _buildCard(DocumentSnapshot doc, int index) {
    final data = doc.data() as Map<String, dynamic>;
    final nombre = data['nombre'] as String? ?? 'Sin nombre';
    final instance = data['instance'] as String? ?? '-';
    final token = data['token'] as String? ?? '-';
    final nequi = data['nequi'] as String? ?? '-';

    final tokenMask = token.length > 4 ? '${'•' * (token.length - 4)}${token.substring(token.length - 4)}' : token;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4))],
        border: Border.all(color: _C.border, width: 1),
      ),
      child: Column(children: [
        // ── Cabecera ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_C.whatsapp.withOpacity(0.08), _C.whatsapp.withOpacity(0.02)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_C.whatsapp, Color(0xFF128C7E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  nombre.isNotEmpty ? nombre[0].toUpperCase() : 'W',
                  style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nombre, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
              Text('WhatsApp · UltraMsg', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
            ])),
            GestureDetector(
              onTap: () => _abrirFormulario(doc: doc),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _C.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.warning.withOpacity(0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.edit_rounded, color: _C.warning, size: 13),
                  const SizedBox(width: 4),
                  Text('Editar', style: GoogleFonts.spaceGrotesk(color: _C.warning, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _eliminar(doc),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _C.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.danger.withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.delete_rounded, color: _C.danger, size: 13),
                  const SizedBox(width: 4),
                  Text('Borrar', style: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),

        // ── Datos ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            _infoRow(Icons.devices_rounded, _C.accent, 'Instance ID', instance, copyValue: instance),
            const SizedBox(height: 8),
            _infoRow(Icons.vpn_key_rounded, _C.purple, 'Token', tokenMask, copyValue: token),
            const SizedBox(height: 8),
            _infoRow(Icons.account_balance_wallet_rounded, _C.success, 'Nequi', nequi, copyValue: nequi),
          ]),
        ),
      ]),
    ).animate().fadeIn(duration: 300.ms, delay: (index * 80).ms).slideY(begin: 0.05, end: 0);
  }

  Widget _infoRow(IconData icon, Color color, String label, String value, {String? copyValue}) {
    return GestureDetector(
      onLongPress: copyValue != null
          ? () {
              Clipboard.setData(ClipboardData(text: copyValue));
              _snack('"$label" copiado', _C.primary, Icons.copy_rounded);
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: _C.surfaceDim, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10, fontWeight: FontWeight.w500)),
            Text(value, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w600)),
          ])),
          if (copyValue != null) Icon(Icons.copy_rounded, color: _C.textSec.withOpacity(0.35), size: 14),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surfaceDim,
      body: SafeArea(
        child: Column(children: [
          // ── Top bar ──────────────────────────────────────────
          Padding(
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
                Text('Configuración WhatsApp',
                    style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 17, fontWeight: FontWeight.w800)),
                Text('UltraMsg · Credenciales API', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
              ])),
              GestureDetector(
                onTap: () => _abrirFormulario(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_C.whatsapp, Color(0xFF128C7E)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: _C.whatsapp.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 5),
                    Text('Nueva', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ]),
          ),

          // ── Banner informativo ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_C.whatsapp.withOpacity(0.08), _C.accent.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _C.whatsapp.withOpacity(0.2), width: 1.2),
              ),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: _C.whatsapp.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.info_outline_rounded, color: _C.whatsapp, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                  'Mantén pulsado cualquier campo para copiarlo. '
                  'Estos datos se usan para enviar notificaciones de mora por WhatsApp.',
                  style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11),
                )),
              ]),
            ),
          ),

          // ── Lista de configs ──────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection(_kCollection).orderBy('creadoEn', descending: true).snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _C.whatsapp, strokeWidth: 2.5));
                }

                final docs = snap.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: _C.whatsapp.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.chat_rounded, color: _C.whatsapp, size: 36),
                      ),
                      const SizedBox(height: 16),
                      Text('Sin configuraciones',
                          style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Toca "+ Nueva" para agregar\ntus credenciales de UltraMsg.',
                          style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13), textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () => _abrirFormulario(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [_C.whatsapp, Color(0xFF128C7E)]),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: _C.whatsapp.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text('Agregar configuración',
                                style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ]),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) => _buildCard(docs[i], i),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
