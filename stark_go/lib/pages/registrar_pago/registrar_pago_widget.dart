import 'package:stark_go/services/vps_service.dart';

import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'registrar_pago_model.dart';
export 'registrar_pago_model.dart';

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
  static const Color whatsapp = Color(0xFF25D366);
}

class _EvolutionInstance {
  final String serverUrl, instanceName, apiKey, status;
  const _EvolutionInstance({required this.serverUrl, required this.instanceName, required this.apiKey, required this.status});
  bool get isConnected => status == 'connected' || status == 'open';
}

class _PagoField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label, hint;
  final IconData icon;
  final Color iconColor;
  final TextInputType keyboardType;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final bool readOnly;

  const _PagoField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    required this.iconColor,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.inputFormatters,
    this.suffixIcon,
    this.validator,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label,
              style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4))),
      TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        readOnly: readOnly,
        validator: validator != null ? (val) => validator!(val) : null,
        style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.6), fontSize: 13),
          prefixIcon: Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: iconColor, size: 16)),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: _C.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _C.border, width: 1.2), borderRadius: BorderRadius.circular(14)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: iconColor, width: 1.8), borderRadius: BorderRadius.circular(14)),
          errorBorder: OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.5), borderRadius: BorderRadius.circular(14)),
          focusedErrorBorder:
              OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.8), borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ]);
  }
}

class RegistrarPagoWidget extends StatefulWidget {
  const RegistrarPagoWidget({super.key, required this.nombre, required this.numero, required this.refcliente, required this.planCliente});
  final String? nombre;
  final int? numero;
  final DocumentReference? refcliente;
  final dynamic planCliente;
  static String routeName = 'RegistrarPago';
  static String routePath = 'registrarPago';

  @override
  State<RegistrarPagoWidget> createState() => _RegistrarPagoWidgetState();
}

class _RegistrarPagoWidgetState extends State<RegistrarPagoWidget> {
  late RegistrarPagoModel _model;
  bool _isLoading = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  String _generarReferencia() {
    final rand = Random();
    return List.generate(8, (_) => rand.nextInt(10)).join();
  }

  double get _planValor {
    try {
      final dynamic plan = widget.planCliente;
      if (plan == null) return 0.0;
      if (plan is double) return plan;
      if (plan is int) return plan.toDouble();
      if (plan is num) return plan.toDouble();
      if (plan is String) return double.tryParse(plan) ?? 0.0;
      return double.tryParse(plan.toString()) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  String get _planFormateado {
    final valor = _planValor.toInt();
    final str = valor.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => RegistrarPagoModel());
    _model.textController1 ??= TextEditingController();
    _model.textFieldFocusNode1 ??= FocusNode();
    _model.textController2 ??= TextEditingController();
    _model.textFieldFocusNode2 ??= FocusNode();
    _model.textController3 ??= TextEditingController();
    _model.textFieldFocusNode3 ??= FocusNode();
    _model.textController4 ??= TextEditingController();
    _model.textFieldFocusNode4 ??= FocusNode();
    _model.textController5 ??= TextEditingController();
    _model.textFieldFocusNode5 ??= FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {
          _model.textController1?.text = _generarReferencia();
          _model.textController2?.text = _planValor.toInt().toString();
          _model.textController3?.text = dateTimeFormat("MMMMEEEEd", getCurrentTimestamp, locale: FFLocalizations.of(context).languageCode);
        }));
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<_EvolutionInstance?> _obtenerInstanciaEvolution() async {
    if (_uid.isEmpty) return null;
    try {
      final snap = await FirebaseFirestore.instance.collection('whatsapp_instances').where('uid', isEqualTo: _uid).limit(1).get();
      if (snap.docs.isEmpty) return null;
      final d = snap.docs.first.data();
      return _EvolutionInstance(
          serverUrl: d['serverUrl'] ?? '', instanceName: d['instanceName'] ?? '', apiKey: d['apiKey'] ?? '', status: d['status'] ?? '');
    } catch (e) {
      debugPrint('[StarkGo] Error leyendo whatsapp_instances: $e');
      return null;
    }
  }

  String _normalizarNumero(dynamic raw) {
    if (raw == null) return '';
    String num = raw.toString().replaceAll(RegExp(r'[^0-9]'), '');
    if (num.isEmpty || num.length < 10) return '';
    if (num.length > 10) return num;
    return '57$num';
  }

  String _construirMensaje({
    required String nombre,
    required String referencia,
    required String fecha,
    required String valor,
    required String metodoPago,
  }) {
    String valorFormateado = valor;
    try {
      final int v = int.parse(valor.replaceAll(RegExp(r'[^\d]'), ''));
      valorFormateado = '\$${v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
    } catch (_) {
      valorFormateado = '\$$valor';
    }
    return '📄 *Comprobante de Pago Recibido*\n\n'
        'Hola $nombre 👋, hemos registrado tu pago exitosamente ✅\n\n'
        '🧾 *Referencia:* $referencia\n📅 *Fecha:* $fecha\n'
        '💰 *Valor:* $valorFormateado\n💳 *Método:* $metodoPago\n\n'
        '🙏 ¡Gracias por tu pago! Tu servicio está activo.\nBendiciones 🌟';
  }

  Future<void> _enviarWhatsappEvolution({
    required String nombre,
    required dynamic numero,
    required String referencia,
    required String fecha,
    required String valor,
    required String metodoPago,
  }) async {
    final instancia = await _obtenerInstanciaEvolution();
    if (instancia == null) {
      debugPrint('[StarkGo] Sin instancia Evolution.');
      return;
    }
    if (!instancia.isConnected) {
      debugPrint('[StarkGo] Instancia desconectada.');
      return;
    }
    final String numeroDestino = _normalizarNumero(numero);
    if (numeroDestino.isEmpty) {
      debugPrint('[StarkGo] Número inválido.');
      return;
    }
    final String mensaje = _construirMensaje(nombre: nombre, referencia: referencia, fecha: fecha, valor: valor, metodoPago: metodoPago);
    try {
      final url = Uri.parse('${instancia.serverUrl}/message/sendText/${instancia.instanceName}');
      final response = await http
          .post(url,
              headers: {'Content-Type': 'application/json', 'apikey': instancia.apiKey},
              body: jsonEncode({'number': numeroDestino, 'text': mensaje}))
          .timeout(const Duration(seconds: 20));
      debugPrint('[StarkGo] WA ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('[StarkGo] Excepción enviando WA: $e');
    }
  }

  // ── Desbloquear en MikroTik — apikey dinámico vía VpsService ──
  Future<void> _desbloquearVPS() async {
    try {
      final clienteSnap = await widget.refcliente!.get();
      if (!clienteSnap.exists) return;
      final clienteData = clienteSnap.data() as Map<String, dynamic>;
      final String ip = (clienteData['ipatn'] ?? '').toString().trim();
      final String nombre = '${clienteData['nombre'] ?? ''} ${clienteData['apellido'] ?? ''}'.trim();
      if (ip.isEmpty) {
        debugPrint('[StarkGo] Sin IP antena, VPS omitido.');
        return;
      }
      await VpsService.cambiarStatus(status: 'activo', ip: ip, nombre: nombre);
    } catch (e) {
      debugPrint('[StarkGo] Error en _desbloquearVPS: $e');
    }
  }

  Future<void> _registrarPago() async {
    if (_model.formKey.currentState == null || !_model.formKey.currentState!.validate()) return;
    final String metodoPago = _model.textController5!.text.trim().isEmpty ? 'Efectivo' : _model.textController5!.text.trim();

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Confirmar Pago', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              _ConfirmRow(label: 'Cliente', value: widget.nombre ?? '-'),
              _ConfirmRow(label: 'Referencia', value: _model.textController1.text),
              _ConfirmRow(label: 'Valor', value: '\$${_model.textController2.text}'),
              _ConfirmRow(label: 'Fecha', value: _model.textController3.text),
              _ConfirmRow(label: 'Método', value: metodoPago),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _C.textSec))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _C.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Confirmar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;
    setState(() => _isLoading = true);
    try {
      // 1. Guardar en Firestore
      var ref = ReportepagoRecord.collection.doc();
      final data = createReportepagoRecordData(
        ref: _model.textController1.text,
        valor: int.tryParse(_model.textController2.text),
        fecha: getCurrentTimestamp,
        comentario: _model.textController4.text.isNotEmpty ? _model.textController4.text : 'Sin comentario',
        refcliente: widget.refcliente,
        nombrecliente: widget.nombre,
      );
      await ref.set(data);
      _model.pago = ReportepagoRecord.getDocumentFromData(data, ref);

      // 2. Actualizar estado → activo y guardar fecha del último pago
      await widget.refcliente!.update(createClientesRecordData(status: 'activo', ultimoPago: DateTime.now()));

      // 3. Desbloquear en MikroTik (apikey dinámico desde config_mikrotik/{uid})
      await _desbloquearVPS();

      // 4. Enviar WhatsApp comprobante
      await _enviarWhatsappEvolution(
        nombre: widget.nombre ?? '',
        numero: widget.numero,
        referencia: _model.textController1.text,
        fecha: _model.textController3.text,
        valor: _model.textController2.text,
        metodoPago: metodoPago,
      );

      if (mounted) context.pushNamed(HomeWidget.routeName);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
            backgroundColor: _C.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _C.surfaceDim,
        body: SafeArea(
          child: Form(
            key: _model.formKey,
            autovalidateMode: AutovalidateMode.disabled,
            child: Column(children: [
              _buildTopBar(context),
              Expanded(
                  child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                child: Column(children: [
                  _buildClienteBanner().animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0),
                  const SizedBox(height: 14),
                  _buildFormSection().animate().fadeIn(duration: 350.ms, delay: 80.ms).slideY(begin: 0.04, end: 0),
                  const SizedBox(height: 14),
                  _buildInfoCard().animate().fadeIn(duration: 350.ms, delay: 160.ms),
                  const SizedBox(height: 20),
                  _buildSubmitButton().animate().fadeIn(duration: 350.ms, delay: 220.ms).slideY(begin: 0.04, end: 0),
                ]),
              )),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
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
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.textPri, size: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Registrar Pago', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 20, fontWeight: FontWeight.w800)),
          Text('Completa los datos del pago', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: _C.whatsapp.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.whatsapp.withOpacity(0.3), width: 1)),
          child: Row(children: [
            Icon(Icons.send_rounded, color: _C.whatsapp, size: 13),
            const SizedBox(width: 5),
            Text('Auto WA', style: GoogleFonts.spaceGrotesk(color: _C.whatsapp, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildClienteBanner() {
    final inicial = (widget.nombre?.isNotEmpty ?? false) ? widget.nombre![0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_C.dark, Color(0xFF1E293B)]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: _C.dark.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6))]),
      child: Row(children: [
        Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [_C.primary, _C.accent]), shape: BoxShape.circle),
            child: Center(
                child: Text(inicial, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)))),
        const SizedBox(width: 14),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pago para', style: GoogleFonts.spaceGrotesk(color: Colors.white54, fontSize: 11)),
          Text(widget.nombre ?? '-', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Plan mensual', style: GoogleFonts.spaceGrotesk(color: Colors.white54, fontSize: 11)),
          Text('\$$_planFormateado', style: GoogleFonts.spaceGrotesk(color: _C.accent, fontSize: 18, fontWeight: FontWeight.w800)),
        ]),
      ]),
    );
  }

  Widget _buildFormSection() {
    return Container(
      decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _C.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))]),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 38,
                height: 38,
                decoration:
                    BoxDecoration(gradient: const LinearGradient(colors: [_C.primary, _C.accent]), borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 19)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Información del Pago', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
              Text('Completa todos los campos', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
            ]),
          ]),
          const SizedBox(height: 16),
          Divider(color: _C.border, height: 1),
          const SizedBox(height: 16),
          _PagoField(
            controller: _model.textController1!,
            focusNode: _model.textFieldFocusNode1!,
            label: 'REFERENCIA',
            hint: 'Ej: 12345678',
            icon: Icons.tag_rounded,
            iconColor: _C.primary,
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => safeSetState(() => _model.textController1?.text = _generarReferencia()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(color: _C.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.refresh_rounded, color: _C.primary, size: 12),
                    const SizedBox(width: 4),
                    Text('NUEVO', style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
            validator: (val) => _model.textController1Validator.asValidator(context)?.call(val),
          ),
          const SizedBox(height: 14),
          _PagoField(
            controller: _model.textController2!,
            focusNode: _model.textFieldFocusNode2!,
            label: 'VALOR A COBRAR',
            hint: 'Monto del pago',
            icon: Icons.attach_money_rounded,
            iconColor: _C.success,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: _C.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('COP', style: GoogleFonts.spaceGrotesk(color: _C.success, fontSize: 11, fontWeight: FontWeight.w700)))),
            validator: (val) => _model.textController2Validator.asValidator(context)?.call(val),
          ),
          const SizedBox(height: 14),
          _PagoField(
            controller: _model.textController3!,
            focusNode: _model.textFieldFocusNode3!,
            label: 'FECHA',
            hint: 'Fecha del pago',
            icon: Icons.calendar_today_rounded,
            iconColor: _C.warning,
            readOnly: true,
            suffixIcon: const Icon(Icons.lock_outline_rounded, color: _C.textSec, size: 16),
            validator: (val) => _model.textController3Validator.asValidator(context)?.call(val),
          ),
          const SizedBox(height: 14),
          _PagoField(
            controller: _model.textController4!,
            focusNode: _model.textFieldFocusNode4!,
            label: 'COMENTARIO (OPCIONAL)',
            hint: 'Observaciones adicionales...',
            icon: Icons.comment_rounded,
            iconColor: _C.textSec,
            maxLines: 3,
            validator: (val) => _model.textController4Validator.asValidator(context)?.call(val),
          ),
          const SizedBox(height: 14),
          _PagoField(
            controller: _model.textController5!,
            focusNode: _model.textFieldFocusNode5!,
            label: 'MÉTODO DE PAGO',
            hint: 'Efectivo (por defecto)',
            icon: Icons.payment_rounded,
            iconColor: _C.accent,
            suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: _C.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('OPC', style: GoogleFonts.spaceGrotesk(color: _C.accent, fontSize: 11, fontWeight: FontWeight.w700)))),
          ),
        ]),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _C.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.primary.withOpacity(0.2), width: 1)),
      child: Row(children: [
        Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _C.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.info_rounded, color: _C.primary, size: 18)),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Información importante', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text('Al registrar, el estado cambia a Activo, se restablece el servicio en MikroTik y se envía comprobante por WhatsApp.',
              style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11.5)),
        ])),
      ]),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
            gradient: _isLoading ? null : const LinearGradient(colors: [_C.primary, _C.accent]),
            color: _isLoading ? _C.border : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isLoading ? [] : [BoxShadow(color: _C.primary.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))]),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : _registrarPago,
            borderRadius: BorderRadius.circular(16),
            child: Center(
                child: _isLoading
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_C.textSec))),
                        const SizedBox(width: 10),
                        Text('Registrando...',
                            style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 15, fontWeight: FontWeight.w600)),
                      ])
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.payments_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text('Registrar Pago',
                            style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                          child: Row(children: [
                            const Icon(Icons.send_rounded, color: Colors.white, size: 11),
                            const SizedBox(width: 4),
                            Text('WA', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ])),
          ),
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label, value;
  const _ConfirmRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13)),
        Text(value, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
