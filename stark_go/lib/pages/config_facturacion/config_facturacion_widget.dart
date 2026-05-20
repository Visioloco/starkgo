import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const Color whatsapp = Color(0xFF25D366);
}

// ─────────────────────────────────────────────
//  VARIABLES DE PLANTILLA
//  Tokens que el usuario puede escribir en el
//  template y que se reemplazan al enviar.
// ─────────────────────────────────────────────
const _kTokens = [
  _Token('{nombre}', 'Nombre del cliente'),
  _Token('{plan}', 'Nombre del plan'),
  _Token('{valor}', 'Valor del plan'),
  _Token('{dia}', 'Día de vencimiento'),
  _Token('{estado}', 'Estado (vence en X días…)'),
  _Token('{empresa}', 'Nombre de tu empresa'),
  _Token('{nequi}', 'Número Nequi'),
  _Token('{titular}', 'Nombre titular Nequi'),
  _Token('{soporte}', 'WhatsApp soporte'),
  _Token('{horario}', 'Horario de atención'),
];

class _Token {
  final String token;
  final String descripcion;
  const _Token(this.token, this.descripcion);
}

// ─────────────────────────────────────────────
//  WIDGET PRINCIPAL
// ─────────────────────────────────────────────
class ConfigFacturacionWidget extends StatefulWidget {
  const ConfigFacturacionWidget({super.key});

  static String routeName = 'ConfigFacturacion';
  static String routePath = 'config-facturacion';

  @override
  State<ConfigFacturacionWidget> createState() => _ConfigFacturacionWidgetState();
}

class _ConfigFacturacionWidgetState extends State<ConfigFacturacionWidget> with SingleTickerProviderStateMixin {
  static const String _kCol = 'config_empresa';

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Facturación ───────────────────────────
  int _diaVencimiento = 25;
  int _diasAviso = 1;

  // ── Datos empresa ─────────────────────────
  final _ctrlEmpresa = TextEditingController();
  final _ctrlTitular = TextEditingController();
  final _ctrlNequi = TextEditingController();
  final _ctrlWhatsapp = TextEditingController();
  final _ctrlHorario = TextEditingController();

  // ── Plantillas de mensajes ─────────────────
  final _ctrlMsgRecordatorio = TextEditingController();
  final _ctrlMsgSuspension = TextEditingController();

  // ── Estado UI ─────────────────────────────
  bool _cargando = true;
  bool _guardando = false;
  bool _guardadoOk = false;
  int _tabActiva = 0; // 0=recordatorio 1=suspensión

  late AnimationController _successCtrl;
  late Animation<double> _successAnim;

  // ── Plantillas por defecto ─────────────────
  static const String _defaultRecordatorio = '📢 *{empresa} — Recordatorio de Pago*\n\n'
      'Hola *{nombre}*, te recordamos que tu factura del servicio de '
      'internet vence el día *{dia}* del mes.\n\n'
      '📋 *Detalle de factura*\n'
      '💳 *Valor:* \${valor}\n'
      '📅 *Vence:* día {dia} de cada mes\n'
      '{estado}\n\n'
      '💜 *Paga fácil por Nequi*\n'
      'Número: {nequi}\n'
      'Nombre: {titular}\n'
      '_Envía el comprobante a este mismo número_\n\n'
      '📞 *Soporte y pagos*\n'
      'WhatsApp: {soporte}\n'
      '_{horario}_\n\n'
      'Realiza tu pago antes del vencimiento para evitar la '
      'suspensión del servicio. 🙏\n\n'
      '_Equipo {empresa}_';

  static const String _defaultSuspension = '🚫 *SERVICIO SUSPENDIDO* 🚫\n\n'
      'Estimado/a *{nombre}*, su servicio de internet ha sido '
      '*suspendido temporalmente* por falta de pago del plan '
      '*{plan}* por valor de \${valor}.\n\n'
      '━━━━━━━━━━━━━━━━━━━━\n'
      '💳 *INSTRUCCIONES DE PAGO*\n'
      '💜 *Paga fácil por Nequi*\n'
      'Número: {nequi}\n'
      'Nombre: {titular}\n'
      '━━━━━━━━━━━━━━━━━━━━\n\n'
      'Envíe el comprobante de pago a este número para reactivar '
      'su servicio.\n\n'
      '⏰ *Horario de atención:*\n'
      '{horario}\n\n'
      '📞 *Soporte:* {soporte}\n\n'
      '— *Equipo {empresa}* 🌐';

  @override
  void initState() {
    super.initState();
    _successCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _successAnim = CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut);
    // Valores por defecto mientras carga
    _ctrlMsgRecordatorio.text = _defaultRecordatorio;
    _ctrlMsgSuspension.text = _defaultSuspension;
    _cargarConfig();
  }

  @override
  void dispose() {
    _successCtrl.dispose();
    _ctrlEmpresa.dispose();
    _ctrlTitular.dispose();
    _ctrlNequi.dispose();
    _ctrlWhatsapp.dispose();
    _ctrlHorario.dispose();
    _ctrlMsgRecordatorio.dispose();
    _ctrlMsgSuspension.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════
  //  FIRESTORE — leer
  // ══════════════════════════════════════════
  Future<void> _cargarConfig() async {
    if (_uid.isEmpty) {
      setState(() => _cargando = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection(_kCol).doc(_uid).get();
      if (doc.exists && mounted) {
        final d = doc.data() as Map<String, dynamic>;
        setState(() {
          _diaVencimiento = (d['diaVencimiento'] as int?) ?? 25;
          _diasAviso = (d['diasAviso'] as int?) ?? 1;
          _ctrlEmpresa.text = (d['nombreEmpresa'] ?? 'StarkGo').toString();
          _ctrlTitular.text = (d['nombreTitular'] ?? '').toString();
          _ctrlNequi.text = (d['numeroNequi'] ?? '').toString();
          _ctrlWhatsapp.text = (d['whatsappSoporte'] ?? '').toString();
          _ctrlHorario.text = (d['horarioSoporte'] ?? 'Lunes a viernes · 8am – 5pm').toString();
          _ctrlMsgRecordatorio.text = (d['msgRecordatorio'] ?? _defaultRecordatorio).toString();
          _ctrlMsgSuspension.text = (d['msgSuspension'] ?? _defaultSuspension).toString();
        });
      }
    } catch (e) {
      debugPrint('[StarkGo] Error leyendo config_empresa: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ══════════════════════════════════════════
  //  FIRESTORE — guardar
  // ══════════════════════════════════════════
  Future<void> _guardarConfig() async {
    if (_uid.isEmpty || _guardando) return;
    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance.collection(_kCol).doc(_uid).set(
        {
          'uid': _uid,
          // facturación
          'diaVencimiento': _diaVencimiento,
          'diasAviso': _diasAviso,
          // empresa
          'nombreEmpresa': _ctrlEmpresa.text.trim(),
          'nombreTitular': _ctrlTitular.text.trim(),
          'numeroNequi': _ctrlNequi.text.trim(),
          'whatsappSoporte': _ctrlWhatsapp.text.trim(),
          'horarioSoporte': _ctrlHorario.text.trim(),
          // plantillas
          'msgRecordatorio': _ctrlMsgRecordatorio.text.trim(),
          'msgSuspension': _ctrlMsgSuspension.text.trim(),
          // meta
          'fechaActualizada': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (mounted) {
        setState(() => _guardadoOk = true);
        _successCtrl.forward(from: 0);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          setState(() => _guardadoOk = false);
          _successCtrl.reverse();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar: $e', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          backgroundColor: _C.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ══════════════════════════════════════════
  //  RESTAURAR plantilla por defecto
  // ══════════════════════════════════════════
  void _restaurarDefault() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Restaurar mensaje', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
        content: Text(
          'Se restaurará el mensaje ${_tabActiva == 0 ? 'de recordatorio' : 'de suspensión'} '
          'al texto por defecto. ¿Continuar?',
          style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _C.textSec)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.warning,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                if (_tabActiva == 0) {
                  _ctrlMsgRecordatorio.text = _defaultRecordatorio;
                } else {
                  _ctrlMsgSuspension.text = _defaultSuspension;
                }
              });
            },
            child: Text('Restaurar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  //  PREVIEW — reemplaza tokens con valores reales
  // ══════════════════════════════════════════
  String _buildPreview(String template) {
    final now = DateTime.now();
    final diasRestantes = _diaVencimiento - now.day;

    String estado;
    if (diasRestantes == 0) {
      estado = '🔴 *Estado:* Vence HOY';
    } else if (diasRestantes == 1) {
      estado = '🔴 *Estado:* Vence mañana, día $_diaVencimiento';
    } else if (diasRestantes > 1) {
      estado = '🟡 *Estado:* Vence en $diasRestantes días (día $_diaVencimiento)';
    } else {
      estado = '🔴 *Estado:* Venció hace ${diasRestantes.abs()} días';
    }

    return template
        .replaceAll('{nombre}', 'Juan Pérez')
        .replaceAll('{plan}', 'Plan Básico')
        .replaceAll('{valor}', '60.000')
        .replaceAll('{dia}', '$_diaVencimiento')
        .replaceAll('{estado}', estado)
        .replaceAll('{empresa}', _ctrlEmpresa.text.trim().isEmpty ? 'TuEmpresa' : _ctrlEmpresa.text.trim())
        .replaceAll('{nequi}', _ctrlNequi.text.trim().isEmpty ? '3XX XXX XXXX' : _ctrlNequi.text.trim())
        .replaceAll('{titular}', _ctrlTitular.text.trim().isEmpty ? 'Nombre Titular' : _ctrlTitular.text.trim())
        .replaceAll('{soporte}', _ctrlWhatsapp.text.trim().isEmpty ? '3XX XXX XXXX' : _ctrlWhatsapp.text.trim())
        .replaceAll('{horario}', _ctrlHorario.text.trim().isEmpty ? 'Lunes a viernes · 8am – 5pm' : _ctrlHorario.text.trim());
  }

  // ══════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════
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
              Text('Facturación & Mensajes', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 17, fontWeight: FontWeight.w700)),
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
                  // ── HEADER ──────────────────────────────────
                  _buildHeader(),
                  const SizedBox(height: 24),

                  // ── SECCIÓN FACTURACIÓN ──────────────────────
                  _sectionLabel('FECHAS DE FACTURACIÓN'),
                  const SizedBox(height: 10),
                  _buildStepper(
                    label: 'Día de vencimiento',
                    sublabel: 'Día del mes en que vence el servicio',
                    icon: Icons.event_rounded,
                    color: _C.primary,
                    value: _diaVencimiento,
                    min: 1,
                    max: 31,
                    suffix: '',
                    onChanged: (v) => setState(() => _diaVencimiento = v),
                  ),
                  const SizedBox(height: 10),
                  _buildStepper(
                    label: 'Días de aviso previo',
                    sublabel: 'Cuántos días antes del vencimiento avisar',
                    icon: Icons.notifications_active_rounded,
                    color: _C.warning,
                    value: _diasAviso,
                    min: 1,
                    max: 15,
                    suffix: ' día${_diasAviso != 1 ? 's' : ''}',
                    onChanged: (v) => setState(() => _diasAviso = v),
                  ),

                  const SizedBox(height: 24),

                  // ── SECCIÓN DATOS EMPRESA ────────────────────
                  _sectionLabel('DATOS DE LA EMPRESA'),
                  const SizedBox(height: 10),
                  _buildEmpresaSection(),

                  const SizedBox(height: 24),

                  // ── SECCIÓN TOKENS AYUDA ─────────────────────
                  _sectionLabel('VARIABLES DISPONIBLES'),
                  const SizedBox(height: 10),
                  _buildTokensHelp(),

                  const SizedBox(height: 24),

                  // ── SECCIÓN MENSAJES ─────────────────────────
                  _sectionLabel('PLANTILLAS DE MENSAJES'),
                  const SizedBox(height: 4),
                  Text(
                    'Edita el texto. Usa las variables de arriba para '
                    'insertar datos dinámicos al enviar.',
                    style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, height: 1.5),
                  ),
                  const SizedBox(height: 14),

                  // ── TABS Recordatorio / Suspensión ───────────
                  _buildTabSelector(),
                  const SizedBox(height: 14),

                  // ── EDITOR ──────────────────────────────────
                  _buildMensajeEditor(),

                  const SizedBox(height: 16),

                  // ── PREVIEW ─────────────────────────────────
                  _buildPreviewCard(),

                  const SizedBox(height: 28),

                  // ── BOTÓN GUARDAR ────────────────────────────
                  _buildGuardarBtn(),

                  const SizedBox(height: 32),
                ]),
              ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  WIDGETS HELPERS
  // ──────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
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
          child: const Icon(Icons.edit_notifications_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Facturación & Mensajes', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            Text(
              'Configura fechas, datos de tu empresa y personaliza '
              'los mensajes de recordatorio y suspensión.',
              style: GoogleFonts.spaceGrotesk(color: Colors.white70, fontSize: 11, height: 1.4),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String label) => Text(
        label,
        style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1),
      );

  Widget _buildStepper({
    required String label,
    required String sublabel,
    required IconData icon,
    required Color color,
    required int value,
    required int min,
    required int max,
    required String suffix,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.cardBorder, width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w600)),
            Text(sublabel, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
          ]),
        ),
        Row(children: [
          _StepBtn(
            icon: Icons.remove_rounded,
            color: color,
            enabled: value > min,
            onTap: () => onChanged(value - 1),
          ),
          Container(
            width: 52,
            alignment: Alignment.center,
            child: Text(
              '$value$suffix',
              style: GoogleFonts.spaceGrotesk(color: color, fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          _StepBtn(
            icon: Icons.add_rounded,
            color: color,
            enabled: value < max,
            onTap: () => onChanged(value + 1),
          ),
        ]),
      ]),
    );
  }

  Widget _buildEmpresaSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.cardBorder, width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        _empresaField(
          controller: _ctrlEmpresa,
          label: 'NOMBRE DE LA EMPRESA',
          hint: 'Ej: StarkGo',
          icon: Icons.business_rounded,
          color: _C.primary,
        ),
        const SizedBox(height: 10),
        _empresaField(
          controller: _ctrlTitular,
          label: 'TITULAR NEQUI / DAVIPLATA',
          hint: 'Ej: Fabian Cardenas',
          icon: Icons.person_rounded,
          color: _C.accent,
        ),
        const SizedBox(height: 10),
        _empresaField(
          controller: _ctrlNequi,
          label: 'NÚMERO DE PAGO (NEQUI)',
          hint: 'Ej: 314 533 6101',
          icon: Icons.account_balance_wallet_rounded,
          color: _C.success,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 10),
        _empresaField(
          controller: _ctrlWhatsapp,
          label: 'WHATSAPP SOPORTE',
          hint: 'Ej: 314 533 6101',
          icon: Icons.chat_rounded,
          color: _C.whatsapp,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 10),
        _empresaField(
          controller: _ctrlHorario,
          label: 'HORARIO DE ATENCIÓN',
          hint: 'Ej: Lunes a viernes · 8am – 5pm',
          icon: Icons.schedule_rounded,
          color: _C.warning,
        ),
      ]),
    );
  }

  Widget _empresaField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 5),
        child:
            Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      ),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: (_) => setState(() {}), // refresca preview
        style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.5), fontSize: 13),
          prefixIcon: Container(
            margin: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          filled: true,
          fillColor: _C.surfaceDim,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          enabledBorder:
              OutlineInputBorder(borderSide: BorderSide(color: _C.cardBorder, width: 1.2), borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: color, width: 1.8), borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ]);
  }

  Widget _buildTokensHelp() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.primary.withOpacity(0.2), width: 1.2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.code_rounded, color: _C.primary, size: 16),
          const SizedBox(width: 8),
          Text('Toca una variable para copiarla',
              style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kTokens.map((t) => _TokenChip(token: t)).toList(),
        ),
      ]),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.cardBorder, width: 1.2),
      ),
      child: Row(children: [
        _TabBtn(
          label: '📢 Recordatorio',
          active: _tabActiva == 0,
          color: _C.primary,
          onTap: () => setState(() => _tabActiva = 0),
        ),
        _TabBtn(
          label: '🚫 Suspensión',
          active: _tabActiva == 1,
          color: _C.danger,
          onTap: () => setState(() => _tabActiva = 1),
        ),
      ]),
    );
  }

  Widget _buildMensajeEditor() {
    final ctrl = _tabActiva == 0 ? _ctrlMsgRecordatorio : _ctrlMsgSuspension;
    final color = _tabActiva == 0 ? _C.primary : _C.danger;
    final label = _tabActiva == 0 ? 'Mensaje de recordatorio de pago' : 'Mensaje de suspensión del servicio';

    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        // Header editor
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border(bottom: BorderSide(color: color.withOpacity(0.2), width: 1)),
          ),
          child: Row(children: [
            Icon(
              _tabActiva == 0 ? Icons.notifications_active_rounded : Icons.block_rounded,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: GoogleFonts.spaceGrotesk(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            GestureDetector(
              onTap: _restaurarDefault,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _C.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.warning.withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.restore_rounded, color: _C.warning, size: 13),
                  const SizedBox(width: 4),
                  Text('Restaurar', style: GoogleFonts.spaceGrotesk(color: _C.warning, fontSize: 10, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),
        // Área de texto
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextFormField(
            controller: ctrl,
            maxLines: null,
            minLines: 10,
            onChanged: (_) => setState(() {}), // refresca preview
            style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, height: 1.6),
            decoration: InputDecoration(
              hintText: 'Escribe el mensaje aquí...',
              hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.5), fontSize: 13),
              filled: true,
              fillColor: _C.surfaceDim,
              contentPadding: const EdgeInsets.all(14),
              enabledBorder:
                  OutlineInputBorder(borderSide: BorderSide(color: _C.cardBorder, width: 1), borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: color, width: 1.8), borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildPreviewCard() {
    final ctrl = _tabActiva == 0 ? _ctrlMsgRecordatorio : _ctrlMsgSuspension;
    final color = _tabActiva == 0 ? _C.whatsapp : _C.danger;
    final preview = _buildPreview(ctrl.text);

    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.cardBorder, width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        // Header preview
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: color.withOpacity(0.2))),
          ),
          child: Row(children: [
            Icon(Icons.chat_rounded, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Vista previa del mensaje',
                  style: GoogleFonts.spaceGrotesk(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            Text(
              'Hoy día ${DateTime.now().day}',
              style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10),
            ),
          ]),
        ),
        // Burbuja WhatsApp
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _tabActiva == 0 ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Text(
              preview,
              style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 11.5, height: 1.6),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildGuardarBtn() {
    return AnimatedBuilder(
      animation: _successAnim,
      builder: (_, __) {
        final ok = _guardadoOk;
        return GestureDetector(
          onTap: _guardando ? null : _guardarConfig,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: ok ? [_C.success, _C.success.withOpacity(0.8)] : [_C.primary, _C.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (ok ? _C.success : _C.primary).withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: _guardando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          ok ? Icons.check_rounded : Icons.save_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          ok ? '¡Guardado!' : 'Guardar todo',
                          style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  STEP BUTTON
// ─────────────────────────────────────────────
class _StepBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _StepBtn({
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.12) : _C.cardBorder,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? color.withOpacity(0.3) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Icon(icon, size: 18, color: enabled ? color : _C.textSec.withOpacity(0.4)),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TAB BUTTON
// ─────────────────────────────────────────────
class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _TabBtn({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: active ? color : _C.textSec,
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TOKEN CHIP
// ─────────────────────────────────────────────
class _TokenChip extends StatelessWidget {
  final _Token token;
  const _TokenChip({required this.token});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: token.token));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${token.token} copiado', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          backgroundColor: _C.primary,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _C.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _C.primary.withOpacity(0.25), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              token.token,
              style: GoogleFonts.spaceGrotesk(
                color: _C.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              token.descripcion,
              style: GoogleFonts.spaceGrotesk(
                color: _C.textSec,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
