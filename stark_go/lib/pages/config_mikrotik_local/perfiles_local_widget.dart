import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/mikrotik_local_api.dart';

// ─────────────────────────────────────────────────────────────────────────
// Paleta — misma que usa ConfigMikroTikWidget, para que todo el flujo de
// MikroTik (remoto y local) se vea consistente.
// ─────────────────────────────────────────────────────────────────────────
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

class PerfilesLocalWidget extends StatefulWidget {
  final MikrotikLocalApi api;

  const PerfilesLocalWidget({Key? key, required this.api}) : super(key: key);

  @override
  State<PerfilesLocalWidget> createState() => _PerfilesLocalWidgetState();
}

class _PerfilesLocalWidgetState extends State<PerfilesLocalWidget> {
  List<Map<String, dynamic>> perfiles = [];
  bool isLoading = true;
  bool _guardandoPerfil = false;
  String? error;

  final _formKeyDialog = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _rateLimitController = TextEditingController();
  final TextEditingController _tiempoController = TextEditingController(text: '3600');
  final TextEditingController _usuariosController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _cargarPerfiles();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _rateLimitController.dispose();
    _tiempoController.dispose();
    _usuariosController.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfiles() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final res = await widget.api.obtenerPerfiles();
      if (!mounted) return;
      setState(() => perfiles = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = _mensajeError(e));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _mensajeError(Object e) {
    final msg = e is MikrotikLocalException ? e.mensaje : e.toString();
    return msg;
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.spaceGrotesk(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _limpiarCampos() {
    _nombreController.clear();
    _rateLimitController.clear();
    _tiempoController.text = '3600';
    _usuariosController.text = '1';
  }

  // ─────────────────────────────────────────────────────────────────────
  // Crear perfil
  // ─────────────────────────────────────────────────────────────────────
  void _abrirDialogoCrear() {
    _limpiarCampos();
    showDialog(
      context: context,
      barrierDismissible: !_guardandoPerfil,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: Form(
              key: _formKeyDialog,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_C.purple, Color(0xFF5B21B6)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Nuevo perfil',
                          style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  _dialogField(
                    controller: _nombreController,
                    label: 'NOMBRE DEL PERFIL',
                    hint: 'ej: Plan-5MB',
                    icon: Icons.badge_rounded,
                    color: _C.purple,
                  ),
                  const SizedBox(height: 14),
                  _dialogField(
                    controller: _rateLimitController,
                    label: 'LÍMITE DE VELOCIDAD',
                    hint: 'subida/bajada — ej: 1M/5M',
                    icon: Icons.speed_rounded,
                    color: _C.accent,
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: _dialogField(
                        controller: _tiempoController,
                        label: 'SESIÓN (SEGUNDOS)',
                        hint: '3600 = 1 hora',
                        icon: Icons.timer_rounded,
                        color: _C.warning,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dialogField(
                        controller: _usuariosController,
                        label: 'USUARIOS',
                        hint: '1',
                        icon: Icons.people_alt_rounded,
                        color: _C.primary,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 22),
                  Row(children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _guardandoPerfil ? null : () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_C.purple, Color(0xFF5B21B6)]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _guardandoPerfil
                                ? null
                                : () async {
                                    if (!_formKeyDialog.currentState!.validate()) return;
                                    setDialogState(() => _guardandoPerfil = true);
                                    final ok = await _guardarPerfil();
                                    setDialogState(() => _guardandoPerfil = false);
                                    if (ok && dialogContext.mounted) Navigator.pop(dialogContext);
                                  },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: _guardandoPerfil
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Text('Crear perfil',
                                        style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label,
              style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w500),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.5), fontSize: 13),
            prefixIcon: Container(
              margin: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 15),
            ),
            filled: true,
            fillColor: _C.surfaceDim,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: color, width: 1.6), borderRadius: BorderRadius.circular(12)),
            errorBorder: OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.4), borderRadius: BorderRadius.circular(12)),
            errorStyle: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 10),
          ),
        ),
      ],
    );
  }

  Future<bool> _guardarPerfil() async {
    final nombre = _nombreController.text.trim();
    final rateLimit = _rateLimitController.text.trim();
    final tiempo = int.tryParse(_tiempoController.text.trim()) ?? 3600;
    final usuarios = int.tryParse(_usuariosController.text.trim()) ?? 1;

    try {
      await widget.api.crearPerfil(
        nombre: nombre,
        rateLimit: rateLimit,
        sessionTimeoutSegundos: tiempo,
        usuariosCompartidos: usuarios,
      );
      await _cargarPerfiles();
      _snack('Perfil "$nombre" creado en el MikroTik', _C.success);
      return true;
    } catch (e) {
      _snack(_mensajeError(e), _C.danger);
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // Borrar perfil
  // ─────────────────────────────────────────────────────────────────────
  Future<void> _borrarPerfil(String id, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: _C.danger.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline_rounded, color: _C.danger, size: 24),
              ),
              const SizedBox(height: 14),
              Text('Eliminar perfil', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Se eliminará "$nombre" del MikroTik. Los usuarios con fichas de este perfil dejarán de tener límite asignado.',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                    child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: _C.danger, borderRadius: BorderRadius.circular(12)),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(dialogContext, true),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: Center(
                            child: Text('Eliminar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );

    if (confirmar != true) return;

    try {
      await widget.api.borrarPerfil(id);
      await _cargarPerfiles();
      _snack('Perfil "$nombre" eliminado', _C.textPri);
    } catch (e) {
      _snack(_mensajeError(e), _C.danger);
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.surfaceDim,
      child: RefreshIndicator(
        color: _C.purple,
        onRefresh: _cargarPerfiles,
        child: isLoading
            ? _buildLoading()
            : error != null
                ? _buildError()
                : _buildContenido(),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView(
      children: [
        SizedBox(
          height: 400,
          child: Center(child: CircularProgressIndicator(color: _C.purple, strokeWidth: 2.5)),
        ),
      ],
    );
  }

  Widget _buildError() {
    return ListView(
      children: [
        SizedBox(
          height: 420,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: _C.danger.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.wifi_off_rounded, color: _C.danger, size: 30),
                  ),
                  const SizedBox(height: 16),
                  Text('No se pudo conectar',
                      style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(error!,
                      textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12.5, height: 1.4)),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_C.purple, Color(0xFF5B21B6)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _cargarPerfiles,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text('Reintentar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContenido() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Header + botón crear
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_C.dark, Color(0xFF1E293B)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: _C.dark.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_C.purple, Color(0xFF5B21B6)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Perfiles de Hotspot',
                      style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${perfiles.length} perfil(es) en este router',
                      style: GoogleFonts.spaceGrotesk(color: Colors.white60, fontSize: 11)),
                ],
              ),
            ),
          ]),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_C.purple, Color(0xFF5B21B6)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _C.purple.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 5))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _abrirDialogoCrear,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_circle_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text('Crear nuevo perfil',
                          style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ).animate().fadeIn(duration: 300.ms, delay: 60.ms).slideY(begin: 0.05, end: 0),
        const SizedBox(height: 18),

        // Lista de perfiles
        if (perfiles.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Column(
              children: [
                Icon(Icons.inbox_rounded, size: 56, color: _C.textSec.withOpacity(0.35)),
                const SizedBox(height: 12),
                Text('No hay perfiles creados todavía', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13)),
              ],
            ),
          )
        else
          ...perfiles.asMap().entries.map((entry) {
            final i = entry.key;
            final perfil = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _perfilCard(perfil).animate().fadeIn(duration: 280.ms, delay: (i * 40).ms).slideX(begin: 0.03, end: 0),
            );
          }),
      ],
    );
  }

  Widget _perfilCard(Map<String, dynamic> perfil) {
    final nombre = perfil['name']?.toString() ?? 'Sin nombre';
    final rateLimit = perfil['rate-limit']?.toString() ?? 'N/A';
    final sessionTimeout = perfil['session-timeout']?.toString() ?? 'N/A';
    final sharedUsers = perfil['shared-users']?.toString() ?? '1';
    final id = perfil['.id']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: _C.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.person_rounded, color: _C.purple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _chip(Icons.speed_rounded, rateLimit, _C.accent),
                  _chip(Icons.timer_rounded, sessionTimeout, _C.warning),
                  _chip(Icons.people_alt_rounded, sharedUsers, _C.primary),
                ]),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _borrarPerfil(id, nombre),
            icon: Icon(Icons.delete_outline_rounded, color: _C.danger.withOpacity(0.8), size: 21),
            tooltip: 'Eliminar perfil',
          ),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(texto, style: GoogleFonts.spaceGrotesk(color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
