import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'config_mikro_tik_model.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/vps_service.dart';
import '/services/antenas_service.dart';
import '../config_perfiles/config_perfiles_widget.dart';
import '../vpn/config_vpn_widget.dart';

// ✅ NUEVO: CONEXIÓN LOCAL MIKROTIK
import '../config_mikrotik_local/conectar_mikrotik_local_widget.dart';
import '../config_mikrotik_local/hotspot_design_widget.dart';

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

  /// Si el campo es `obscure`, con `visible: true` se muestra el texto y se
  /// dibuja el ojito para alternar (el estado lo maneja la pantalla).
  final bool visible;
  final VoidCallback? onToggleVisible;
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
    this.visible = false,
    this.onToggleVisible,
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
        obscureText: obscure && !visible,
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
          // 👁️ Ojito para ver la contraseña mientras se escribe.
          suffixIcon: obscure && onToggleVisible != null
              ? IconButton(
                  onPressed: onToggleVisible,
                  splashRadius: 18,
                  tooltip: visible ? 'Ocultar contraseña' : 'Ver contraseña',
                  icon: Icon(
                    visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    color: _C.textSec,
                    size: 20,
                  ),
                )
              : null,
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
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
              ]),
            ),
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

// ─────────────────────────────────────────────────────────────────────────
// Tarjeta de navegación reutilizable (usada dentro de "Herramientas de
// Hotspot" para ir a Perfiles, Fichas y Modo Local)
// ─────────────────────────────────────────────────────────────────────────
class _NavCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.25), width: 1.2),
          ),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration:
                  BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
              ]),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 14),
          ]),
        ),
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

  // ── Controla si la tarjeta de Device-Mode aparece expandida ──
  bool _deviceModeExpandida = true;

  /// 👁️ Muestra la contraseña del MikroTik mientras se escribe.
  bool _verPassMikrotik = false;

  // ── Portal de pago para morosos (opcional; apagado por defecto) ──
  bool _portalMorosos = false;

  /// true cuando ya se leyó `config_mikrotik/{uid}`. Hasta entonces no se
  /// escriben la red local ni la puerta de enlace, para no pisar con vacío
  /// lo que ya está guardado a nombre del usuario.
  bool _configCargada = false;

  // ── Estado de la cola del VPS (¿el MikroTik ya aplicó los comandos?) ──
  bool _consultandoCola = false;
  ColaEstadoVps? _cola;
  String? _colaError;

  /// Consulta GET /cola/estado para saber si lo que se encoló (Simple Queues,
  /// bindings bypassed, bloqueos) ya lo aplicó el MikroTik.
  Future<void> _consultarCola() async {
    if (_consultandoCola) return;
    setState(() {
      _consultandoCola = true;
      _colaError = null;
    });
    try {
      final estado = await VpsService.estadoCola();
      if (!mounted) return;
      setState(() {
        _cola = estado;
        _colaError = estado == null ? 'No pude consultar el VPS (revisá la API Key y que el VPS esté en línea).' : null;
      });
    } catch (e) {
      if (mounted) setState(() => _colaError = 'Error: $e');
    } finally {
      if (mounted) setState(() => _consultandoCola = false);
    }
  }

  String _generarApiKey(String uid) {
    final parte = uid.substring(0, 8);
    final ts = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    return 'sg_${parte}_$ts';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Comandos para verificar y cambiar el Device-Mode
  // ─────────────────────────────────────────────────────────────────────────
  static const String _cmdVerificarDeviceMode = '/system/device-mode/print';
  static const String _cmdCambiarDeviceModeV7Nuevo = '/system/device-mode/update mode=advanced';
  static const String _cmdCambiarDeviceModeV7Antiguo = '/system/device-mode/update mode=enterprise';
  static const String _cmdCambiarDeviceModeV6 = '/system/device-mode/update mode=enterprise';

  // ─────────────────────────────────────────────────────────────────────────
  // Source del script starkgo-sync
  //
  // /cola devuelve los comandos y, al final, la línea de CONFIRMACIÓN
  // (/cola/ack). Si el import falla en cualquier línea anterior, la
  // confirmación no se ejecuta y el VPS reenvía todo en el próximo ciclo
  // (los comandos son idempotentes). El .rsc de confirmación se borra acá.
  // ─────────────────────────────────────────────────────────────────────────
  String _buildScriptSource() {
    final key = _model.vpsApiKeyController?.text.trim() ?? '';
    return '/tool fetch url="http://5.161.88.42:3000/cola?apikey=$key" mode=http dst-path=cola.rsc\n'
        '/import cola.rsc\n'
        '/file remove cola.rsc\n'
        '/file remove starkgo-ack.tmp';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Comando del scheduler
  // ─────────────────────────────────────────────────────────────────────────
  String _buildComandoScheduler() {
    final key = _model.vpsApiKeyController?.text.trim() ?? '';
    final min = _model.schedulerMinutos ?? 2;
    return '/system scheduler add name=starkgo-scheduler interval=${min}m '
        'on-event="/tool fetch url=\\"http://5.161.88.42:3000/cola?apikey=$key\\" '
        'mode=http dst-path=cola.rsc; /import cola.rsc; /file remove cola.rsc; '
        '/file remove starkgo-ack.tmp" '
        'start-time=startup comment="StarkGo"';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PASO 3 — Reporte del Dashboard
  // ─────────────────────────────────────────────────────────────────────────
  String _buildScriptSourceDashboard() {
    final key = _model.vpsApiKeyController?.text.trim() ?? '';
    return ':local apikey "$key"\n'
        ':local url "http://5.161.88.42:3000/dashboard/reportar"\n'
        '\n'
        ':local perfilesJson "["\n'
        ':local first true\n'
        ':foreach i in=[/ip hotspot user profile find] do={\n'
        '  :local n [/ip hotspot user profile get \$i name]\n'
        '  :if (\$n != "default") do={\n'
        '    :local rl [/ip hotspot user profile get \$i rate-limit]\n'
        '    :local st [/ip hotspot user profile get \$i session-timeout]\n'
        '    :local su [/ip hotspot user profile get \$i shared-users]\n'
        '    :if (\$first = false) do={ :set perfilesJson (\$perfilesJson . ",") }\n'
        '    :set perfilesJson (\$perfilesJson . "{\\"name\\":\\"" . \$n . "\\",\\"rateLimit\\":\\"" . \$rl . "\\",\\"sessionTimeout\\":\\"" . \$st . "\\",\\"sharedUsers\\":\\"" . \$su . "\\"}")\n'
        '    :set first false\n'
        '  }\n'
        '}\n'
        ':set perfilesJson (\$perfilesJson . "]")\n'
        '\n'
        ':local usuariosJson "["\n'
        ':set first true\n'
        ':foreach i in=[/ip hotspot user find] do={\n'
        '  :local n [/ip hotspot user get \$i name]\n'
        '  :local up [/ip hotspot user get \$i uptime]\n'
        '  :local pf [/ip hotspot user get \$i profile]\n'
        '  :if (\$first = false) do={ :set usuariosJson (\$usuariosJson . ",") }\n'
        '  :set usuariosJson (\$usuariosJson . "{\\"name\\":\\"" . \$n . "\\",\\"uptime\\":\\"" . \$up . "\\",\\"profile\\":\\"" . \$pf . "\\"}")\n'
        '  :set first false\n'
        '}\n'
        ':set usuariosJson (\$usuariosJson . "]")\n'
        '\n'
        ':local activos [:len [/ip hotspot active find]]\n'
        ':local bindings [:len [/ip hotspot ip-binding find]]\n'
        ':local servers [:len [/ip hotspot find]]\n'
        '\n'
        ':local body ("{\\"apikey\\":\\"" . \$apikey . "\\",\\"perfiles\\":" . \$perfilesJson . ",\\"usuarios\\":" . \$usuariosJson . ",\\"activos\\":" . \$activos . ",\\"ipBindings\\":" . \$bindings . ",\\"servers\\":" . \$servers . "}")\n'
        '\n'
        '/tool fetch url=\$url http-method=post http-header-field="Content-Type: application/json" http-data=\$body output=none';
  }

  String _buildComandoSchedulerDashboard() {
    return '/system scheduler add name=starkgo-dashboard-scheduler interval=10m '
        'on-event="/system script run starkgo-dashboard-report" '
        'start-time=startup comment="StarkGo Dashboard"';
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
    // Red local del operador: la subred donde viven sus antenas y la puerta
    // de enlace (IP local del MikroTik). Se guardan con el uid del usuario.
    _model.subredLocalController ??= TextEditingController();
    _model.subredLocalFocusNode ??= FocusNode();
    _model.ipLocalController ??= TextEditingController();
    _model.ipLocalFocusNode ??= FocusNode();
    // OJO: los controladores del túnel (Public Key de wg1 y la IP del túnel)
    // viven en la pantalla "Configurar VPN"; acá sólo la red local y la
    // puerta de enlace, que se editan en las dos pantallas sobre el mismo doc.
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
        // Tu red local y la puerta de enlace: se guardan en el MISMO doc del
        // uid (`config_mikrotik/{uid}`), así vuelven al entrar/salir.
        _model.subredLocalController!.text = (d['subredLocal'] ?? '').toString();
        _model.ipLocalController!.text = (d['ipLocal'] ?? '').toString();
        _portalMorosos = (d['portalMorosos'] ?? false) == true;
        // El túnel (IP del MikroTik en el túnel, Public Key de wg1 y netmap)
        // se configura en "Configurar VPN" — desde acá no se lee ni se escribe.
        setState(() => _model.schedulerMinutos = d['schedulerMinutos'] as int?);
        _model.scriptVisible = d['scriptGenerado'] == true;
      } else {
        _model.vpsApiKeyController!.text = _generarApiKey(_uid!);
      }
      // Lectura OK (exista o no el doc): ya es seguro guardar.
      _configCargada = true;
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
    final uid = _uid;
    if (uid == null) {
      _snack('Iniciá sesión para guardar tu configuración', _C.danger);
      return;
    }
    setState(() => _model.guardando = true);
    try {
      // Todo se guarda en `config_mikrotik/{uid}`: la config SIEMPRE es de la
      // cuenta autenticada, y al cerrar/abrir sesión vuelve tal cual.
      final datos = <String, dynamic>{
        'propietarioUid': uid,
        'vpsApiKey': _model.vpsApiKeyController!.text.trim(),
        'mikrotikIp': _model.mikrotikIpController!.text.trim(),
        'mikrotikUser': _model.mikrotikUserController!.text.trim(),
        'mikrotikPass': _model.mikrotikPassController!.text.trim(),
        'schedulerMinutos': _model.schedulerMinutos,
        'scriptGenerado': true,
        'portalMorosos': _portalMorosos,
        'actualizadoEn': FieldValue.serverTimestamp(),
      };
      // Tu red local + la puerta de enlace (IP local del MikroTik). Sólo se
      // escriben cuando ya se leyó el doc del usuario: así un guardado con
      // los campos vacíos (por ejemplo al abrir la pantalla por primera vez)
      // nunca borra lo que ya estaba guardado.
      if (_configCargada) {
        datos['subredLocal'] = _model.subredLocalController!.text.trim();
        datos['ipLocal'] = _model.ipLocalController!.text.trim();
      }
      // OJO: mikrotikTunelIp, mikrotikPublicKey, mikrotikRegistradoEn y
      // usarNetmap los escribe "Configurar VPN" (lado túnel): no se tocan
      // desde acá para no pisarlos.
      await FirebaseFirestore.instance.collection(_col).doc(uid).set(datos, SetOptions(merge: true));
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

  /// Abre el editor del portal de pago (morosos) en modo remoto (VPS).
  /// No requiere FTP local: se publica en el VPS y se previsualiza desde ahí.
  void _abrirEditorPortalPago() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          backgroundColor: _C.surface,
          title: Text('Portal de pago · morosos',
              style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        body: HotspotDesignWidget(
          host: '',
          usuario: '',
          clave: '',
          soloPortalVps: true,
        ),
      ),
    ));
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Este campo es obligatorio' : null;

  // ══════════════════════════════════════════════════════════════════════
  //  VALIDACIONES DE LA RED LOCAL (declarada por el operador)
  //  Sirven para que las antenas, la puerta de enlace y el MikroTik
  //  coincidan con la red real del usuario.
  // ══════════════════════════════════════════════════════════════════════

  /// true si `s` es una IPv4 válida (a.b.c.d, 0-255 cada octeto).
  static bool _esIpv4(String s) {
    final p = s.trim().split('.');
    if (p.length != 4) return false;
    for (final o in p) {
      final n = int.tryParse(o);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  /// IP del MikroTik: obligatoria y tiene que ser una IPv4 válida.
  /// (La subred del túnel / el modo netmap se configuran en "Configurar VPN".)
  String? _validarIpMikrotikLocal(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Este campo es obligatorio';
    if (!_esIpv4(s)) return 'IP inválida (ej: 192.168.10.1)';
    return null;
  }

  /// Tu subred local (CIDR) — opcional: si la escribís, tiene que ser válida.
  String? _validarSubredLocalOpcional(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    if (!AntenasService.cidrValido(s)) return 'Formato esperado: 192.168.10.0/24';
    return null;
  }

  /// Tu puerta de enlace / IP local del MikroTik — opcional: si la escribís,
  /// tiene que ser una IPv4 válida.
  String? _validarIpLocalOpcional(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    if (!_esIpv4(s)) return 'IP inválida (ej: 192.168.10.1)';
    return null;
  }

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

                          // ── PASO 0 — Device-Mode ──
                          _buildDeviceModeCard().animate().fadeIn(duration: 350.ms, delay: 40.ms).slideY(begin: 0.05, end: 0),
                          const SizedBox(height: 14),

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
                            subtitle: 'IP, usuario, contrasena, red y puerta de enlace',
                            children: [
                              _Field(
                                  ctrl: _model.mikrotikIpController!,
                                  focusNode: _model.mikrotikIpFocusNode,
                                  label: 'IP DEL MIKROTIK (EN TU RED LOCAL)',
                                  hint: '192.168.10.1',
                                  icon: Icons.dns_rounded,
                                  color: _C.accent,
                                  keyboardType: TextInputType.url,
                                  validator: _validarIpMikrotikLocal),
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
                                  // 👁️ Ojito para revisar la contraseña antes de guardar.
                                  visible: _verPassMikrotik,
                                  onToggleVisible: () => setState(() => _verPassMikrotik = !_verPassMikrotik),
                                  validator: _required),
                              // ── Tu red local y tu puerta de enlace ──
                              // Se guardan en config_mikrotik/{uid}: son del
                              // usuario autenticado y vuelven al entrar/salir.
                              _Field(
                                  ctrl: _model.subredLocalController!,
                                  focusNode: _model.subredLocalFocusNode,
                                  label: 'MI SUBRED LOCAL (CIDR)',
                                  hint: '192.168.10.0/24',
                                  icon: Icons.account_tree_rounded,
                                  color: _C.warning,
                                  keyboardType: TextInputType.url,
                                  validator: _validarSubredLocalOpcional),
                              _Field(
                                  ctrl: _model.ipLocalController!,
                                  focusNode: _model.ipLocalFocusNode,
                                  label: 'MI IP LOCAL / PUERTA DE ENLACE',
                                  hint: '192.168.10.1',
                                  icon: Icons.home_rounded,
                                  color: _C.warning,
                                  keyboardType: TextInputType.url,
                                  validator: _validarIpLocalOpcional),
                              _buildInfoRedLocal(),
                            ],
                          ).animate().fadeIn(duration: 350.ms, delay: 200.ms).slideY(begin: 0.05, end: 0),
                          const SizedBox(height: 14),

                          // ── Todo lo del túnel vive en "Configurar VPN" ──
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _C.pppoe.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _C.pppoe.withOpacity(0.3)),
                            ),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Icon(Icons.hub_rounded, color: _C.pppoe, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('El túnel ahora se configura en "Configurar VPN"',
                                      style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Text(
                                      'La IP del túnel del MikroTik (10.50.50.x), su Public Key como peer '
                                      'del VPS, tu red local y el modo netmap se movieron ahí, junto con '
                                      'el resto del túnel. Acá queda la configuración del router: datos, '
                                      'scheduler, portal de morosos y reglas.',
                                      style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10.5, height: 1.4)),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConfigVpnWidget())),
                                    icon: const Icon(Icons.open_in_new_rounded, size: 16, color: _C.pppoe),
                                    label: Text('Abrir Configurar VPN',
                                        style: GoogleFonts.spaceGrotesk(color: _C.pppoe, fontSize: 12.5, fontWeight: FontWeight.w700)),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: _C.pppoe.withOpacity(0.4)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ]),
                              ),
                            ]),
                          ),

                          const SizedBox(height: 14),

                          // ── Herramientas de Hotspot ──
                          _buildHerramientasHotspot().animate().fadeIn(duration: 350.ms, delay: 240.ms).slideY(begin: 0.05, end: 0),
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

                          // Instrucciones en tres pasos
                          if (_model.scriptVisible) ...[
                            _buildScriptCard().animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
                            const SizedBox(height: 14),
                            _buildSchedulerCard().animate().fadeIn(duration: 400.ms, delay: 80.ms).slideY(begin: 0.05, end: 0),
                            const SizedBox(height: 14),
                            _buildEstadoColaCard().animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.05, end: 0),
                            const SizedBox(height: 14),
                            _buildFirewallRuleCard().animate().fadeIn(duration: 400.ms, delay: 120.ms).slideY(begin: 0.05, end: 0),
                            const SizedBox(height: 14),
                            _buildGuiaPortalCard().animate().fadeIn(duration: 400.ms, delay: 140.ms).slideY(begin: 0.05, end: 0),
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

  // ── Herramientas de Hotspot: Perfiles y Modo Local ────────────────
  Widget _buildHerramientasHotspot() {
    return _Section(
      icon: Icons.build_circle_rounded,
      color: _C.pppoe,
      title: 'Herramientas de Hotspot',
      subtitle: 'Perfiles y conexión directa',
      children: [
        // ✅ NUEVO: Modo Local
        _NavCard(
          icon: Icons.wifi,
          color: Colors.green,
          title: 'Modo Local (Directo)',
          subtitle: 'Conectar al MikroTik en la misma red',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ConectarMikrotikLocalWidget()),
          ),
        ),
        _NavCard(
          icon: Icons.people_alt_rounded,
          color: _C.purple,
          title: 'Perfiles / Planes',
          subtitle: 'Crear, listar y borrar planes de hotspot',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ConfigPerfilesWidget()),
          ),
        ),
      ],
    );
  }

  // ── PASO 0: Device-Mode ──────────────────────────────────────────────────────
  Widget _buildDeviceModeCard() {
    return Container(
      decoration: BoxDecoration(
        color: _C.dark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.danger.withOpacity(0.4), width: 1.4),
        boxShadow: [BoxShadow(color: _C.dark.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          GestureDetector(
            onTap: () => setState(() => _deviceModeExpandida = !_deviceModeExpandida),
            child: Row(children: [
              Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_C.danger, Color(0xFFB91C1C)]), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.security_rounded, color: Colors.white, size: 18)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Paso 0 — Revisa el Device-Mode',
                      style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: _C.danger.withOpacity(0.25), borderRadius: BorderRadius.circular(6)),
                    child:
                        Text('IMPORTANTE', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
                ]),
                Text('Sin esto, el scheduler NUNCA va a bloquear a nadie',
                    style: GoogleFonts.spaceGrotesk(color: Colors.white60, fontSize: 10)),
              ])),
              Icon(_deviceModeExpandida ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Colors.white54),
            ]),
          ),

          if (_deviceModeExpandida) ...[
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _C.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.warning.withOpacity(0.35))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, color: _C.warning, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Muchos MikroTik (sobre todo nuevos) vienen de fabrica en modo '
                    '"home". En ese modo, RouterOS bloquea el scheduler, el fetch y '
                    'otras funciones aunque todo tu script este bien escrito. '
                    'Por eso el bloqueo automatico "no sale" hasta que apagas y '
                    'prendes el router.',
                    style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 11.5, height: 1.4),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),

            _buildPaso(1, Icons.terminal_rounded, _C.accent, 'Abre New Terminal en WinBox, WebFig o por SSH'),
            _buildPaso(2, Icons.visibility_rounded, _C.primary, 'Ejecuta el comando de verificacion (abajo) y revisa el campo "mode"'),
            _buildPaso(3, Icons.swap_horiz_rounded, _C.warning, 'Si dice "mode: home", ejecuta el comando de tu version de RouterOS'),
            _buildPaso(
                4, Icons.power_settings_new_rounded, _C.danger, 'Desconecta el cable de energia y vuelve a conectarlo (NO botón de reset)'),
            _buildPaso(5, Icons.check_circle_rounded, _C.success,
                'Reconéctate y confirma con el mismo comando: debe decir "mode: enterprise" o "advanced"'),
            const SizedBox(height: 10),

            // Comando 1 — Verificar
            _buildComandoConCopia(
              titulo: '1. Verificar el modo actual',
              comando: _cmdVerificarDeviceMode,
              color: _C.primary,
            ),
            const SizedBox(height: 10),

            // Comando 2 — Cambiar
            Text('2. Cambiar a Enterprise/Advanced (según tu versión de RouterOS):',
                style: GoogleFonts.spaceGrotesk(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildComandoConCopia(
              titulo: 'RouterOS v7.17+ (versiones recientes)',
              comando: _cmdCambiarDeviceModeV7Nuevo,
              color: _C.accent,
            ),
            const SizedBox(height: 8),
            _buildComandoConCopia(
              titulo: 'RouterOS v7.0 a v7.16',
              comando: _cmdCambiarDeviceModeV7Antiguo,
              color: _C.warning,
            ),
            const SizedBox(height: 8),
            _buildComandoConCopia(
              titulo: 'RouterOS v6 (v6.49.8+ con módulo de seguridad)',
              comando: _cmdCambiarDeviceModeV6,
              color: _C.purple,
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _C.danger.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.danger.withOpacity(0.35))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.warning_amber_rounded, color: _C.danger, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Después de correr el comando de cambio, el terminal te dará ~100 '
                    'segundos para confirmar. Confirmas apagando y prendiendo el router '
                    '(o presionando el botón mode/reset si tu equipo lo tiene). '
                    'Si no confirmas a tiempo, el cambio se cancela y toca repetirlo. '
                    'No necesitas resetear la configuración, solo cortar la energía.',
                    style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 11.5, height: 1.4),
                  ),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildComandoConCopia({required String titulo, required String comando, required Color color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(titulo, style: GoogleFonts.spaceGrotesk(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: comando));
              _snack('Comando copiado', _C.success);
            },
            child: Icon(Icons.copy_rounded, color: color, size: 14),
          ),
        ]),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(comando, style: GoogleFonts.sourceCodePro(color: color, fontSize: 12, height: 1.5)),
        ),
      ]),
    );
  }

  // ── PASO 1: Script source ───────────────────────────────────────────────────
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

  // ── PASO 2: Comando scheduler ──────────────────────────────────────────────
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
                  'desde el arranque del router, sin depender del script. '
                  'Recuerda: esto solo funciona si ya completaste el Paso 0 (Device-Mode en Enterprise/Advanced).',
                  style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11))),
        ]),
      ]),
    );
  }

  // ── PASO 3: Regla de firewall para morosos ──────────────────────────────
  void _copiarClipboard(String texto, String aviso) {
    Clipboard.setData(ClipboardData(text: texto));
    _snack(aviso, _C.success);
  }

  // ── Estado de la cola: ¿el router ya aplicó las Simple Queues y los bindings? ──
  Widget _buildEstadoColaCard() {
    final c = _cola;
    final bool todoOk = c != null && c.todoAplicado;
    final Color color = _colaError != null ? _C.danger : (todoOk ? _C.success : _C.warning);
    final String titulo = _colaError != null
        ? 'No pude leer el estado'
        : (c == null ? 'Todavía sin consultar' : (todoOk ? 'Todo aplicado en el router' : 'Comandos pendientes'));

    String detalle() {
      if (_colaError != null) return _colaError!;
      if (c == null)
        return 'Toca "Verificar" para preguntarle al VPS si la '
            'Simple Queue y el blindaje del hotspot ya llegaron al MikroTik.';
      final sb = StringBuffer();
      sb.write('Pendientes: ${c.pendientes}');
      if (c.comandosEnVuelo > 0) {
        sb.write(' · En vuelo: ${c.comandosEnVuelo} (hace ${c.edadSegundos}s, '
            'se reintenta a los ${c.ttlSegundos}s si no confirma)');
      } else {
        sb.write(' · En vuelo: 0');
      }
      if (c.ultimaConfirmacion != null) {
        final u = c.ultimaConfirmacion!;
        sb.write(' · Última confirmación del router: '
            '${u.day.toString().padLeft(2, '0')}/${u.month.toString().padLeft(2, '0')} '
            '${u.hour.toString().padLeft(2, '0')}:${u.minute.toString().padLeft(2, '0')}');
      }
      return sb.toString();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(9)),
            child: Icon(
              _colaError != null ? Icons.error_outline_rounded : (todoOk ? Icons.verified_rounded : Icons.hourglass_bottom_rounded),
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cola del VPS · $titulo', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w700)),
              Text('Simple Queues, blockings y bindings bypassed', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10)),
            ]),
          ),
          TextButton.icon(
            onPressed: _consultandoCola ? null : _consultarCola,
            icon: _consultandoCola
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.refresh_rounded, size: 16, color: color),
            label: Text(_consultandoCola ? 'Consultando…' : 'Verificar',
                style: GoogleFonts.spaceGrotesk(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(detalle(), style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10.5, height: 1.4)),
      ]),
    );
  }

  // ── Guía "Portal de pago para morosos": comandos para el MikroTik ──
  Widget _buildGuiaPortalCard() {
    final apiKey = _model.vpsApiKeyController?.text.trim() ?? '';
    // OJO: la URL del redirect DEBE ir por el puerto estándar 80 (sin :3000).
    // Si apunta a un puerto no estándar, el sistema operativo del celular
    // descarta la detección del portal cautivo y muestra "sin acceso a internet".
    // Además lleva ?ip=$(ip): RouterOS reemplaza $(ip) por la IP del cliente
    // cuando sirve este login.html, y así el VPS rellena {{nombre}}, {{saldo}},
    // etc. del portal. Sin ese parámetro la página carga pero sin datos dinámicos.
    final url = 'http://5.161.88.42/portal/${apiKey.isEmpty ? 'TU_APIKEY' : apiKey}'
        '/login.html?ip=\$(ip)';
    final loginHtml = '<!DOCTYPE html>\n<html>\n  <head>\n'
        '    <meta charset="utf-8">\n'
        '    <meta http-equiv="refresh" content="0; url=$url">\n'
        '  </head>\n  <body><p>Redirigiendo...</p></body>\n</html>';
    // Recorre las Simple Queues y crea el ip-binding `bypassed` de cada IP.
    // OJO: [:find] devuelve VACIO cuando no encuentra / y [:pick] con un
    // final vacio TIRA ERROR, lo que cortaba TODO el :foreach (por eso el
    // comando no blindaba nada si alguna queue tenia el target sin /).
    const comandoSync =
        r':foreach q in=[/queue simple find] do={ :local t [/queue simple get $q target]; :local n [/queue simple get $q name]; :local ip $t; :if ([:len [:find $t "/"]] > 0) do={ :set ip [:pick $t 0 [:find $t "/"]] }; :if ([:len $ip] > 0) do={ :if ([:len [/ip hotspot ip-binding find where address=$ip]] = 0) do={ /ip hotspot ip-binding add address=$ip type=bypassed comment=$n } } }';
    const crearTodo =
        ':if ([:len [/ip hotspot profile find where name="perfil-pago"]] = 0) do={ /ip hotspot profile add name=perfil-pago html-directory=hotspot }\n'
        ':if ([:len [/ip hotspot find where name="hs-pago"]] = 0) do={ /ip hotspot add name=hs-pago interface=bridge-local profile=perfil-pago } else={ /ip hotspot enable [find where name="hs-pago"] }';
    const walled = '/ip hotspot walled-garden add dst-host=5.161.88.42';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.primary.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration:
                  BoxDecoration(gradient: const LinearGradient(colors: [_C.primary, _C.accent]), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Portal de pago · configurar MikroTik (1 vez)',
                  style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
              'Pega cada comando en Winbox → New Terminal. Cambia bridge-local '
              'por la interfaz real de tus clientes (ej: bridge1). El login.html '
              'se sube una sola vez a la carpeta hotspot/ del router (usa '
              '"Publicar en el router" o FTP).',
              style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10.5, height: 1.35)),
          const SizedBox(height: 8),
          _buildCopyRow(
            icon: Icons.lock_open_rounded,
            color: _C.primary,
            titulo: '1) Walled garden (permite cargar tu página)',
            codigo: walled,
          ),
          _buildCopyRow(
            icon: Icons.ads_click_rounded,
            color: _C.accent,
            titulo: apiKey.isEmpty
                ? '2) login.html (redirige al portal) — guarda antes para usar tu key'
                : '2) login.html (redirige al portal) — key ya incluida',
            codigo: loginHtml,
          ),
          _buildCopyRow(
            icon: Icons.playlist_add_check_rounded,
            color: _C.warning,
            titulo: '3) Colas → binding bypassed (blinda las IPs: hazlo ANTES de activar el hotspot)',
            codigo: comandoSync,
          ),
          _buildCopyRow(
            icon: Icons.wifi_tethering_rounded,
            color: _C.success,
            titulo: '4) Crear perfil + crear/activar el hotspot (ÚLTIMO paso, cuando ya estén blindadas las IPs)',
            codigo: crearTodo,
          ),
          const SizedBox(height: 6),
          Text(
              'Con el hotspot activo, CADA cliente necesita su binding "bypassed" '
              'para que NO le salga el portal cautivo. Los clientes NUEVOS creados '
              'o reactivados desde la app lo reciben automáticamente (el VPS lo '
              'encola en el próximo ciclo del scheduler, con o sin el portal de '
              'morosos activado). Para los que ya existían, pega el comando 3 '
              'ANTES de activar el hotspot y re-ejecútalo cada vez que agregues '
              'clientes/colas.',
              style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10.5, height: 1.35)),
        ],
      ),
    );
  }

  Widget _buildCopyRow({
    required IconData icon,
    required Color color,
    required String titulo,
    required String codigo,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(titulo, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Copiar',
              onPressed: () => _copiarClipboard(codigo, 'Comando copiado'),
              icon: Icon(Icons.copy_rounded, color: color, size: 16),
            ),
          ]),
          const SizedBox(height: 2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _C.surfaceDim,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              codigo,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: Color(0xFF0F172A), height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirewallRuleCard() {
    // OJO CON EL ORDEN: `/ip firewall filter add` mete la regla al FINAL de la
    // cadena. Si más arriba hay un `accept` (o un `fasttrack-connection`), la IP
    // que está en `morosos` sigue navegando → "puse en mora y no se cortó".
    // Por eso la regla se inserta con place-before=0 (arriba de todo) y, si ya
    // existía de antes, primero se borra (idempotente, no duplica).
    const regla =
        ':if ([:len [/ip firewall filter find where comment="Bloqueo a Morosos"]] > 0) do={ /ip firewall filter remove [find where comment="Bloqueo a Morosos"] }\n'
        '/ip firewall filter add chain=forward src-address-list=morosos action=drop place-before=0 comment="Bloqueo a Morosos"';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.danger.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.danger.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_C.danger, Color(0xFFB91C1C)]), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.block_rounded, color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Paso 3 — Regla de bloqueo a morosos',
                style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w700)),
            Text('Una sola vez, para que el bloqueo funcione', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10)),
          ])),
        ]),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: _C.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.danger.withOpacity(0.3))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, color: _C.danger, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cuando pones un cliente en mora, la app agrega su IP a la lista '
                '"morosos". Para que ese bloqueo realmente corte el internet, en el '
                'MikroTik debe existir ESTA regla de firewall. Sin ella, el scheduler '
                'agrega la IP pero el tráfico sigue pasando.',
                style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11.5, height: 1.4),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        _buildPaso(1, Icons.terminal_rounded, _C.danger, 'Winbox → IP → Firewall → pestaña Filter Rules → +', textColor: _C.textPri),
        _buildPaso(2, Icons.playlist_add_rounded, _C.danger, 'Chain: forward · Src. Address List: morosos · Action: drop',
            textColor: _C.textPri),
        _buildPaso(3, Icons.code_rounded, _C.danger, 'Comment: Bloqueo a Morosos (o copiá el comando de abajo)', textColor: _C.textPri),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Text('Comando (New Terminal)',
                style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(const ClipboardData(text: regla));
              _snack('Regla copiada', _C.success);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: _C.danger.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.copy_rounded, color: _C.danger, size: 13),
                const SizedBox(width: 4),
                Text('Copiar', style: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _C.dark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            regla,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white70, height: 1.5),
          ),
        ),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.warning_amber_rounded, color: _C.danger, size: 15),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  'El ORDEN importa: la regla debe quedar ARRIBA de los "accept" '
                  '(y de cualquier fasttrack) de la cadena forward. Por eso el '
                  'comando usa place-before=0: si queda abajo, la IP en mora sigue '
                  'navegando y parece que "no se aplicó el corte".',
                  style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10.5, height: 1.35))),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: _C.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.primary.withOpacity(0.2))),
          child: Row(children: [
            const Icon(Icons.wifi_password_rounded, color: _C.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Portal de pago para morosos',
                    style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                    'Opcional: al suspender, esa IP queda cautiva y ve el '
                    'login/hotspot con tu info de pago en vez de solo '
                    '"sin internet". Requiere hotspot + página subida '
                    '(ver PORTAL_MOROSOS.md).',
                    style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10.5, height: 1.35)),
              ]),
            ),
            Switch(
              value: _portalMorosos,
              onChanged: (v) => setState(() => _portalMorosos = v),
              activeTrackColor: _C.primary,
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _abrirEditorPortalPago,
            icon: const Icon(Icons.edit_note_rounded, size: 17),
            label: Text('Editar página del portal (morosos)', style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(foregroundColor: _C.primary),
          ),
        ),
      ]),
    );
  }

  // ── PASO 4: Reporte del Dashboard (OCULTO — deshabilitado por el dueño) ─────
  // ignore: unused_element
  Widget _buildDashboardReportCard() {
    final src = _buildScriptSourceDashboard();
    final cmd = _buildComandoSchedulerDashboard();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.purple.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.purple.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_C.purple, Color(0xFF5B21B6)]), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Paso 4 — Reporte del Dashboard',
                style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w700)),
            Text('Planes y estadisticas en vivo', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10)),
          ])),
        ]),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: _C.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.purple.withOpacity(0.3))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, color: _C.purple, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Este paso es opcional pero necesario si usas Planes o el '
                'Dashboard. El router envia su inventario cada 10 minutos, en un '
                'scheduler separado del de bloqueos para no afectarlo si algo falla.',
                style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11.5, height: 1.4),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        // 3a — Script
        _buildPaso(1, Icons.folder_rounded, _C.warning, 'System → Scripts → + → Name: starkgo-dashboard-report', textColor: _C.textPri),
        _buildPaso(2, Icons.policy_rounded, _C.pppoe, 'Marca: read, write, policy, test', textColor: _C.textPri),
        _buildPaso(3, Icons.code_rounded, _C.purple, 'En Source pega el codigo de abajo', textColor: _C.textPri),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: Text('Source del script', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: src));
              _snack('Source copiado', _C.success);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: _C.purple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.purple.withOpacity(0.35))),
              child: Row(children: [
                Icon(Icons.copy_rounded, color: _C.purple, size: 13),
                const SizedBox(width: 4),
                Text('Copiar', style: GoogleFonts.spaceGrotesk(color: _C.purple, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
          child: SelectableText(
            src,
            style: GoogleFonts.sourceCodePro(color: const Color(0xFFA78BFA), fontSize: 11.5, height: 1.6),
          ),
        ),
        const SizedBox(height: 14),

        Divider(color: _C.purple.withOpacity(0.2), height: 1),
        const SizedBox(height: 14),

        // 3b — Scheduler
        _buildPaso(4, Icons.terminal_rounded, _C.accent, 'Abre New Terminal y pega el comando de abajo', textColor: _C.textPri),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: Text('Comando del scheduler',
                style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: cmd));
              _snack('Comando copiado', _C.success);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: _C.purple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.purple.withOpacity(0.35))),
              child: Row(children: [
                Icon(Icons.copy_rounded, color: _C.purple, size: 13),
                const SizedBox(width: 4),
                Text('Copiar', style: GoogleFonts.spaceGrotesk(color: _C.purple, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(cmd, style: GoogleFonts.sourceCodePro(color: const Color(0xFFA78BFA), fontSize: 12, height: 1.5)),
          ),
        ),
      ]),
    );
  }

  Widget _buildPaso(int n, IconData icon, Color color, String texto, {Color textColor = Colors.white70}) => Padding(
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
          Expanded(child: Text(texto, style: GoogleFonts.spaceGrotesk(color: textColor, fontSize: 12))),
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

  /// Aviso de la red local + puerta de enlace: aclara que se guardan SIEMPRE
  /// a nombre del usuario autenticado (uid) y que se comparten con la
  /// pantalla "Configurar VPN".
  Widget _buildInfoRedLocal() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: _C.warning.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.warning.withOpacity(0.25))),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, color: _C.warning, size: 16),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
                  'Opcional: tu subred local (ej. 192.168.10.0/24) y tu puerta de '
                  'enlace (ej. 192.168.10.1). Se guardan en tu cuenta (uid) al tocar '
                  '"Guardar y generar comandos" y vuelven solas cuando entrás de nuevo. '
                  'También se pueden editar en "Configurar VPN" (es el mismo dato).',
                  style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, height: 1.35))),
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
