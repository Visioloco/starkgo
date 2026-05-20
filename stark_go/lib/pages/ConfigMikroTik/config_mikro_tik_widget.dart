import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'config_mikro_tik_model.dart';
import '/flutter_flow/flutter_flow_util.dart';

class _VPS {
  static const String url = 'http://5.161.88.42:3000';
}

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

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode? focusNode;
  final String label, hint;
  final IconData icon;
  final Color color;
  final TextInputType keyboardType;
  final bool obscure;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? validator;

  const _Field({
    required this.ctrl,
    this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    required this.color,
    this.keyboardType = TextInputType.text,
    this.obscure = false,
    this.formatters,
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
        controller: ctrl,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscure,
        inputFormatters: formatters,
        validator: validator,
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
          errorBorder: OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.5), borderRadius: BorderRadius.circular(14)),
          focusedErrorBorder:
              OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.8), borderRadius: BorderRadius.circular(14)),
          errorStyle: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 11),
        ),
      ),
    ]);
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final List<Widget> children;

  const _Section({
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
              decoration:
                  BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]), borderRadius: BorderRadius.circular(12)),
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

class _SchedulerDropdown extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  const _SchedulerDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final opciones = [1, 2, 3, 5, 10, 15, 30];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text('INTERVALO DEL SCHEDULER',
            style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      ),
      Container(
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: value != null ? _C.warning : _C.border, width: value != null ? 1.8 : 1.2),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: value,
            isExpanded: true,
            borderRadius: BorderRadius.circular(14),
            dropdownColor: _C.surface,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            icon: Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.keyboard_arrow_down_rounded, color: _C.textSec)),
            hint: Row(children: [
              Container(
                margin: const EdgeInsets.only(left: 6, right: 10),
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: _C.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
                child: Icon(Icons.timer_rounded, color: _C.warning, size: 16),
              ),
              Text('Selecciona el intervalo', style: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.6), fontSize: 14)),
            ]),
            items: opciones
                .map((m) => DropdownMenuItem<int>(
                      value: m,
                      child: Row(children: [
                        Container(
                          margin: const EdgeInsets.only(left: 4, right: 10),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(color: _C.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.timer_rounded, color: _C.warning, size: 15),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text('Cada $m minuto${m == 1 ? '' : 's'}',
                              style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('Consulta al VPS cada $m min', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10)),
                        ]),
                      ]),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    ]);
  }
}

class ConfigMikroTikWidget extends StatefulWidget {
  const ConfigMikroTikWidget({super.key});
  static String routeName = 'ConfigMikroTik';
  static String routePath = 'configMikroTik';

  @override
  State<ConfigMikroTikWidget> createState() => _ConfigMikroTikWidgetState();
}

class _ConfigMikroTikWidgetState extends State<ConfigMikroTikWidget> {
  late ConfigMikroTikModel _model;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  static const String _col = 'config_mikrotik';

  String _generarApiKey(String uid) {
    final parte = uid.substring(0, 8);
    final ts = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    return 'sg_${parte}_$ts';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Source del script starkgo-sync
  // El usuario lo pega en System → Scripts → starkgo-sync → Source
  // ─────────────────────────────────────────────────────────────────────────
  String _buildScriptSource() {
    final key = _model.vpsApiKeyController?.text.trim() ?? '';
    return '/tool fetch url="http://5.161.88.42:3000/cola?apikey=$key" mode=http dst-path=cola.rsc\n'
        '/import cola.rsc\n'
        '/file remove cola.rsc';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Comando del scheduler
  // El on-event tiene el fetch+import+remove inline (igual que el script).
  // Asi funciona aunque el script no exista o no se haya creado aun.
  // ─────────────────────────────────────────────────────────────────────────
  String _buildComandoScheduler() {
    final key = _model.vpsApiKeyController?.text.trim() ?? '';
    final min = _model.schedulerMinutos ?? 2;
    return '/system scheduler add name=starkgo-scheduler interval=${min}m '
        'on-event="/tool fetch url=\\"http://5.161.88.42:3000/cola?apikey=$key\\" '
        'mode=http dst-path=cola.rsc; /import cola.rsc; /file remove cola.rsc" '
        'start-time=startup comment="StarkGo"';
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ConfigMikroTikModel());
    _model.vpsApiKeyController ??= TextEditingController();
    _model.vpsApiKeyFocusNode ??= FocusNode();
    _model.mikrotikIpController ??= TextEditingController();
    _model.mikrotikIpFocusNode ??= FocusNode();
    _model.mikrotikUserController ??= TextEditingController();
    _model.mikrotikUserFocusNode ??= FocusNode();
    _model.mikrotikPassController ??= TextEditingController();
    _model.mikrotikPassFocusNode ??= FocusNode();
    _cargarConfig();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _cargarConfig() async {
    if (_uid == null) return;
    setState(() => _model.cargando = true);
    try {
      final doc = await FirebaseFirestore.instance.collection(_col).doc(_uid).get();
      if (doc.exists && mounted) {
        final d = doc.data()!;
        _model.vpsApiKeyController!.text = d['vpsApiKey'] ?? _generarApiKey(_uid!);
        _model.mikrotikIpController!.text = d['mikrotikIp'] ?? '';
        _model.mikrotikUserController!.text = d['mikrotikUser'] ?? '';
        _model.mikrotikPassController!.text = d['mikrotikPass'] ?? '';
        setState(() => _model.schedulerMinutos = d['schedulerMinutos'] as int?);
        _model.scriptVisible = d['scriptGenerado'] == true;
      } else {
        _model.vpsApiKeyController!.text = _generarApiKey(_uid!);
      }
    } catch (e) {
      debugPrint('[StarkGo] Error cargando config MikroTik: $e');
    } finally {
      if (mounted) setState(() => _model.cargando = false);
    }
  }

  Future<void> _guardar() async {
    if (!_model.formKey.currentState!.validate()) return;
    if (_model.schedulerMinutos == null) {
      _snack('Selecciona el intervalo del scheduler', _C.danger);
      return;
    }
    if (_uid == null) return;
    setState(() => _model.guardando = true);
    try {
      await FirebaseFirestore.instance.collection(_col).doc(_uid).set({
        'propietarioUid': _uid,
        'vpsApiKey': _model.vpsApiKeyController!.text.trim(),
        'mikrotikIp': _model.mikrotikIpController!.text.trim(),
        'mikrotikUser': _model.mikrotikUserController!.text.trim(),
        'mikrotikPass': _model.mikrotikPassController!.text.trim(),
        'schedulerMinutos': _model.schedulerMinutos,
        'scriptGenerado': true,
        'actualizadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        setState(() => _model.scriptVisible = true);
        _snack('Configuracion guardada correctamente', _C.success);
      }
    } catch (e) {
      if (mounted) _snack('Error al guardar: $e', _C.danger);
    } finally {
      if (mounted) setState(() => _model.guardando = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.spaceGrotesk(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Este campo es obligatorio' : null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _C.surfaceDim,
        body: SafeArea(
          child: _model.cargando
              ? Center(child: CircularProgressIndicator(color: _C.primary, strokeWidth: 2.5))
              : Form(
                  key: _model.formKey,
                  child: Column(children: [
                    _buildTopBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                        child: Column(children: [
                          _buildBanner().animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0),
                          const SizedBox(height: 16),

                          // API Key
                          _Section(
                            icon: Icons.vpn_key_rounded,
                            color: _C.purple,
                            title: 'Tu clave de acceso',
                            subtitle: 'Identifica tu MikroTik en el sistema',
                            children: [_buildApiKeyReadonly(), _buildInfoApiKey()],
                          ).animate().fadeIn(duration: 350.ms, delay: 100.ms).slideY(begin: 0.05, end: 0),
                          const SizedBox(height: 14),

                          // Datos MikroTik
                          _Section(
                            icon: Icons.router_rounded,
                            color: _C.accent,
                            title: 'Datos del MikroTik',
                            subtitle: 'IP, usuario y contrasena del router',
                            children: [
                              _Field(
                                  ctrl: _model.mikrotikIpController!,
                                  focusNode: _model.mikrotikIpFocusNode,
                                  label: 'IP DEL MIKROTIK',
                                  hint: '192.168.1.1',
                                  icon: Icons.dns_rounded,
                                  color: _C.accent,
                                  keyboardType: TextInputType.url,
                                  validator: _required),
                              _Field(
                                  ctrl: _model.mikrotikUserController!,
                                  focusNode: _model.mikrotikUserFocusNode,
                                  label: 'USUARIO MIKROTIK',
                                  hint: 'admin',
                                  icon: Icons.person_rounded,
                                  color: _C.accent,
                                  validator: _required),
                              _Field(
                                  ctrl: _model.mikrotikPassController!,
                                  focusNode: _model.mikrotikPassFocusNode,
                                  label: 'CONTRASENA MIKROTIK',
                                  hint: 'password',
                                  icon: Icons.lock_rounded,
                                  color: _C.accent,
                                  obscure: true,
                                  validator: _required),
                            ],
                          ).animate().fadeIn(duration: 350.ms, delay: 200.ms).slideY(begin: 0.05, end: 0),
                          const SizedBox(height: 14),

                          // Scheduler interval selector
                          _Section(
                            icon: Icons.schedule_rounded,
                            color: _C.warning,
                            title: 'Scheduler MikroTik',
                            subtitle: 'Cada cuanto consulta el servidor',
                            children: [
                              _SchedulerDropdown(
                                  value: _model.schedulerMinutos, onChanged: (v) => setState(() => _model.schedulerMinutos = v)),
                              _buildInfoScheduler(),
                            ],
                          ).animate().fadeIn(duration: 350.ms, delay: 280.ms).slideY(begin: 0.05, end: 0),
                          const SizedBox(height: 14),

                          // Instrucciones en dos pasos (se muestran tras guardar)
                          if (_model.scriptVisible) ...[
                            // PASO 1 — Script source
                            _buildScriptCard().animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
                            const SizedBox(height: 14),

                            // PASO 2 — Comando scheduler
                            _buildSchedulerCard().animate().fadeIn(duration: 400.ms, delay: 80.ms).slideY(begin: 0.05, end: 0),
                            const SizedBox(height: 14),
                          ],

                          _buildBotonGuardar().animate().fadeIn(duration: 350.ms, delay: 340.ms).slideY(begin: 0.05, end: 0),
                        ]),
                      ),
                    ),
                  ]),
                ),
        ),
      ),
    );
  }

  // ── PASO 1: Script source (System → Scripts → starkgo-sync → Source) ─────
  Widget _buildScriptCard() {
    final src = _buildScriptSource();
    return Container(
      decoration: BoxDecoration(
          color: _C.dark,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: _C.dark.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))]),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_C.primary, Color(0xFF1558B0)]), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.description_rounded, color: Colors.white, size: 18)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Paso 1 — Crear el Script',
                  style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              Text('System → Scripts → + → Name: starkgo-sync', style: GoogleFonts.spaceGrotesk(color: Colors.white60, fontSize: 10)),
            ])),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: src));
                _snack('Source copiado', _C.success);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                    color: _C.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _C.primary.withOpacity(0.4))),
                child: Row(children: [
                  const Icon(Icons.copy_rounded, color: _C.primary, size: 14),
                  const SizedBox(width: 5),
                  Text('Copiar', style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 14),

          _buildPaso(1, Icons.folder_rounded, _C.warning, 'Ve a System → Scripts → presiona +'),
          _buildPaso(2, Icons.edit_rounded, _C.accent, 'En Name escribe: starkgo-sync'),
          _buildPaso(3, Icons.policy_rounded, _C.pppoe, 'Marca: read, write, policy, test'),
          _buildPaso(4, Icons.code_rounded, _C.primary, 'En Source pega el codigo de abajo'),
          _buildPaso(5, Icons.check_rounded, _C.success, 'Click OK y luego Run Script para probar'),
          const SizedBox(height: 4),

          // Source code block
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
            child: SelectableText(
              src,
              style: GoogleFonts.sourceCodePro(color: const Color(0xFF22C55E), fontSize: 12, height: 1.6),
            ),
          ),
        ]),
      ),
    );
  }

  // ── PASO 2: Comando scheduler (New Terminal) ──────────────────────────────
  Widget _buildSchedulerCard() {
    final cmd = _buildComandoScheduler();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.warning.withOpacity(0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_C.warning, Color(0xFFD97706)]), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.schedule_rounded, color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Paso 2 — Crear el Scheduler',
                style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w700)),
            Text('New Terminal → pega el comando y presiona Enter', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10)),
          ])),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: cmd));
              _snack('Comando scheduler copiado', _C.success);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                  color: _C.warning.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _C.warning.withOpacity(0.5))),
              child: Row(children: [
                Icon(Icons.copy_rounded, color: _C.warning, size: 14),
                const SizedBox(width: 5),
                Text('Copiar', style: GoogleFonts.spaceGrotesk(color: _C.warning, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 14),

        // Comando block
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              cmd,
              style: GoogleFonts.sourceCodePro(color: const Color(0xFF22C55E), fontSize: 12, height: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Nota
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, color: _C.warning, size: 15),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  'El scheduler ejecuta el fetch directamente cada ${_model.schedulerMinutos ?? 2} minuto(s) '
                  'desde el arranque del router, sin depender del script.',
                  style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11))),
        ]),
      ]),
    );
  }

  Widget _buildPaso(int n, IconData icon, Color color, String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Center(child: Text('$n', style: GoogleFonts.spaceGrotesk(color: color, fontSize: 11, fontWeight: FontWeight.w800))),
          ),
          const SizedBox(width: 10),
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: GoogleFonts.spaceGrotesk(color: Colors.white70, fontSize: 12))),
        ]),
      );

  Widget _buildApiKeyReadonly() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _C.purple.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.purple.withOpacity(0.25), width: 1.2),
        ),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: _C.purple.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
              child: Icon(Icons.key_rounded, color: _C.purple, size: 17)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('API KEY',
                style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
            const SizedBox(height: 2),
            Text(_model.vpsApiKeyController?.text ?? '...',
                style: GoogleFonts.sourceCodePro(color: _C.purple, fontSize: 13, fontWeight: FontWeight.w600)),
          ])),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _model.vpsApiKeyController?.text ?? ''));
              _snack('API Key copiada', _C.success);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                  color: _C.purple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _C.purple.withOpacity(0.3))),
              child: Row(children: [
                Icon(Icons.copy_rounded, color: _C.purple, size: 13),
                const SizedBox(width: 4),
                Text('Copiar', style: GoogleFonts.spaceGrotesk(color: _C.purple, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      );

  Widget _buildInfoApiKey() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: _C.purple.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.purple.withOpacity(0.2))),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, color: _C.purple, size: 16),
          const SizedBox(width: 10),
          Expanded(
              child: Text('Esta clave identifica tu router. Se genera automaticamente y va dentro del source del script.',
                  style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11))),
        ]),
      );

  Widget _buildTopBar() => Padding(
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
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))]),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.textPri, size: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Config. MikroTik', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 20, fontWeight: FontWeight.w800)),
            Text('Router + Scheduler + PPPoE', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: _C.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _C.accent.withOpacity(0.3))),
            child: Row(children: [
              Icon(Icons.router_rounded, color: _C.accent, size: 13),
              const SizedBox(width: 5),
              Text('Auto', style: GoogleFonts.spaceGrotesk(color: _C.accent, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );

  Widget _buildBanner() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_C.dark, Color(0xFF1E293B)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: _C.dark.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6))]),
        child: Row(children: [
          Container(
              width: 52,
              height: 52,
              decoration:
                  BoxDecoration(gradient: const LinearGradient(colors: [_C.primary, _C.accent]), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.router_rounded, color: Colors.white, size: 26)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Conecta tu MikroTik', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text('Bloqueos + Queues + PPPoE. Compatible RouterOS v6 y v7.',
                style: GoogleFonts.spaceGrotesk(color: Colors.white60, fontSize: 11)),
          ])),
        ]),
      );

  Widget _buildInfoScheduler() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: _C.warning.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.warning.withOpacity(0.25))),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, color: _C.warning, size: 16),
          const SizedBox(width: 10),
          Expanded(
              child: Text('El MikroTik consultara el VPS cada X minutos para bloqueos, desbloqueos y PPPoE.',
                  style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11))),
        ]),
      );

  Widget _buildBotonGuardar() => SizedBox(
        width: double.infinity,
        height: 56,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
              gradient: _model.guardando ? null : const LinearGradient(colors: [_C.primary, _C.accent]),
              color: _model.guardando ? _C.border : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow:
                  _model.guardando ? [] : [BoxShadow(color: _C.primary.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))]),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _model.guardando ? null : _guardar,
              borderRadius: BorderRadius.circular(16),
              child: Center(
                  child: _model.guardando
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
                          const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text('Guardar y generar comandos',
                              style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        ])),
            ),
          ),
        ),
      );
}
