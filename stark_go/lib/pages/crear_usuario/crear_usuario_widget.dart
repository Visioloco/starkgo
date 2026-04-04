import 'package:stark_go/pages/vps_service.dart';

import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'vps_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'crear_usuario_model.dart';
export 'crear_usuario_model.dart';

// ─────────────────────────────────────────────
//  PALETA
// ─────────────────────────────────────────────
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

// ─────────────────────────────────────────────
//  MODELO DE PLAN (idéntico a detalle_cliente)
// ─────────────────────────────────────────────
class _PlanItem {
  final String id;
  final String nombre;
  final double valor;
  final String simbolo;
  final String monedaCodigo;

  const _PlanItem({
    required this.id,
    required this.nombre,
    required this.valor,
    required this.simbolo,
    required this.monedaCodigo,
  });

  String get etiqueta => '$nombre — $simbolo ${valor.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}';
}

// ─────────────────────────────────────────────
//  CAMPO DE TEXTO
// ─────────────────────────────────────────────
class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label, hint;
  final IconData icon;
  final Color iconColor;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;

  const _FormField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    required this.iconColor,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.inputFormatters,
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
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w500),
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.6), fontSize: 14),
          prefixIcon: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          filled: true,
          fillColor: _C.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _C.border, width: 1.2), borderRadius: BorderRadius.circular(14)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: iconColor, width: 1.8), borderRadius: BorderRadius.circular(14)),
          errorBorder: OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.5), borderRadius: BorderRadius.circular(14)),
          focusedErrorBorder:
              OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.8), borderRadius: BorderRadius.circular(14)),
          errorStyle: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 11),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────
//  DROPDOWN GENÉRICO ESTILIZADO
// ─────────────────────────────────────────────
class _StyledDropdown<T> extends StatelessWidget {
  final String label, hint;
  final IconData icon;
  final Color color;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? errorText;

  const _StyledDropdown({
    required this.label,
    required this.hint,
    required this.icon,
    required this.color,
    required this.value,
    required this.items,
    required this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child:
            Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      ),
      Container(
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasError ? _C.danger : (value != null ? color : _C.border),
            width: value != null ? 1.8 : 1.2,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            borderRadius: BorderRadius.circular(14),
            dropdownColor: _C.surface,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            icon: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.keyboard_arrow_down_rounded, color: _C.textSec),
            ),
            hint: Row(children: [
              Container(
                margin: const EdgeInsets.only(left: 6, right: 10),
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, color: color, size: 16),
              ),
              Text(hint, style: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.6), fontSize: 14)),
            ]),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
      if (hasError)
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4),
          child: Text(errorText!, style: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 11)),
        ),
    ]);
  }
}

// ─────────────────────────────────────────────
//  SECCIÓN DE FORMULARIO
// ─────────────────────────────────────────────
class _FormSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final List<Widget> children;

  const _FormSection({
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
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]),
                borderRadius: BorderRadius.circular(12),
              ),
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

// ─────────────────────────────────────────────
//  MAIN WIDGET
// ─────────────────────────────────────────────
class CrearUsuarioWidget extends StatefulWidget {
  const CrearUsuarioWidget({super.key});

  static String routeName = 'CrearUsuario';
  static String routePath = 'crearUsuario';

  @override
  State<CrearUsuarioWidget> createState() => _CrearUsuarioWidgetState();
}

class _CrearUsuarioWidgetState extends State<CrearUsuarioWidget> {
  late CrearUsuarioModel _model;
  bool _isLoading = false;
  bool _validarDropdowns = false;

  // ── Estado de dropdowns ──
  Map<String, dynamic>? _starlinkSel;
  String? _starlinkId;
  Map<String, dynamic>? _antenaSel;
  String? _antenaId;
  Map<String, dynamic>? _routerSel;
  String? _routerId;
  String? _tipoServicio;
  String? _velocidad;

  // ── Plan (dinámico desde Firestore, igual que detalle_cliente) ──
  List<_PlanItem> _planesDisponibles = [];
  bool _cargandoPlanes = false;
  _PlanItem? _selPlanItem;

  // ── Listas desde Firestore ──
  List<QueryDocumentSnapshot> _starlinks = [];
  List<QueryDocumentSnapshot> _antenas = [];
  List<QueryDocumentSnapshot> _routers = [];

  // ── Opciones fijas — idénticas a detalle_cliente ──
  static const _tiposServicio = ['Fibra Óptica', 'Radio Enlace'];
  static const _velocidades = [
    '2M/2M',
    '2M/3M',
    '2M/4M',
    '2M/5M',
    '2M/6M',
    '2M/7M',
    '2M/8M',
    '2M/9M',
    '2M/10M',
  ];

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CrearUsuarioModel());
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
    _model.textController6 ??= TextEditingController();
    _model.textFieldFocusNode6 ??= FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarDatos();
      safeSetState(() {});
    });
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    // Equipos y planes en paralelo
    final results = await Future.wait([
      FirebaseFirestore.instance.collection('starlinks').where('activo', isEqualTo: true).orderBy('nombre').get(),
      FirebaseFirestore.instance.collection('equipos').where('tipo', isEqualTo: 'antena').get(),
      FirebaseFirestore.instance.collection('equipos').where('tipo', isEqualTo: 'router').get(),
      _cargarPlanesUsuario(),
    ]);

    if (mounted) {
      setState(() {
        _starlinks = (results[0] as QuerySnapshot).docs;
        _antenas = (results[1] as QuerySnapshot).docs;
        _routers = (results[2] as QuerySnapshot).docs;
      });
    }
  }

  Future<QuerySnapshot> _cargarPlanesUsuario() async {
    if (_uid == null) return Future.value(null as QuerySnapshot);
    setState(() => _cargandoPlanes = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('planes').where('propietarioUid', isEqualTo: _uid).get();
      if (mounted) {
        setState(() {
          _planesDisponibles = snap.docs.map((doc) {
            final d = doc.data();
            return _PlanItem(
              id: doc.id,
              nombre: (d['nombre'] ?? '').toString(),
              valor: (d['valor'] is num) ? (d['valor'] as num).toDouble() : 0.0,
              simbolo: (d['monedaSimbolo'] ?? '').toString(),
              monedaCodigo: (d['monedaCodigo'] ?? '').toString(),
            );
          }).toList();
          _cargandoPlanes = false;
        });
      }
      return snap;
    } catch (e) {
      debugPrint('[StarkGo] Error cargando planes: $e');
      if (mounted) setState(() => _cargandoPlanes = false);
      rethrow;
    }
  }

  bool get _dropdownsValidos =>
      _starlinkSel != null &&
      _antenaSel != null &&
      _routerSel != null &&
      _selPlanItem != null &&
      _tipoServicio != null &&
      _velocidad != null;

  // ════════════════════════════════════════════════════════════
  //  REGISTRAR
  // ════════════════════════════════════════════════════════════
  Future<void> _registrar() async {
    setState(() => _validarDropdowns = true);
    if (_model.formKey.currentState == null || !_model.formKey.currentState!.validate()) return;
    if (!_dropdownsValidos) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Completa todos los campos de selección', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        backgroundColor: _C.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    setState(() => _isLoading = true);
    try {
      _model.antna = await actions.generarIpAntena();
      _model.routr = await actions.generarIpAntenaCopy();
      _model.clav = await actions.generarClave(_model.textController5.text, int.parse(_model.textController3.text));

      final uid = FirebaseAuth.instance.currentUser?.uid;

      var ref = ClientesRecord.collection.doc();
      final data = createClientesRecordData(
        nombre: _model.textController1.text.trim(),
        apellido: _model.textController2.text.trim(),
        cc: int.tryParse(_model.textController3.text),
        numero: int.tryParse(_model.textController4.text),
        nombrefinca: _model.textController5.text.trim(),
        vereda: _model.textController6.text.trim(),
        ipatn: _model.antna,
        usuarioatn: _model.clav,
        claveatn: _model.clav,
        iprouter: _model.routr,
        usuariorouter: _model.clav,
        claverouter: _model.clav,
        fecha: getCurrentTimestamp,
        status: 'activo',
        starlinkId: _starlinkId,
        starlinkNombre: _starlinkSel!['nombre'],
        antenaId: _antenaId,
        antenaMarca: _antenaSel!['marca'],
        antenaModelo: _antenaSel!['modelo'],
        antenaIp: _antenaSel!['ip'],
        routerId: _routerId,
        routerMarca: _routerSel!['marca'],
        routerModelo: _routerSel!['modelo'],
        routerIp: _routerSel!['ip'],
        // ── Plan dinámico (igual que detalle_cliente) ──
        planCliente: _selPlanItem!.nombre,
        tipoServicio: _tipoServicio,
        velocidadPlan: _velocidad,
      );

      await ref.set(data);
      _model.rf = ClientesRecord.getDocumentFromData(data, ref);

      // ── Guardar campos extra del plan (planId, planValor, planSimbolo, planMoneda) ──
      await FirebaseFirestore.instance.collection('clientes').doc(ref.id).update({
        'planId': _selPlanItem!.id,
        'planValor': _selPlanItem!.valor,
        'planSimbolo': _selPlanItem!.simbolo,
        'planMoneda': _selPlanItem!.monedaCodigo,
      });

      // ── Notificar al VPS ── (sin tocar)
      final nombreCompleto = '${_model.textController1.text.trim()} ${_model.textController2.text.trim()}';
      await VpsService.clienteCreado(
        nombre: nombreCompleto,
        ip: _model.antna ?? '',
        velocidad: _velocidad ?? '',
      );

      // ── propietarioUid ──
      if (uid != null) {
        await FirebaseFirestore.instance.collection('clientes').doc(ref.id).update({'propietarioUid': uid});
      }

      // ── Incrementar contador Starlink ──
      await FirebaseFirestore.instance.collection('starlinks').doc(_starlinkId).update({'clientes_count': FieldValue.increment(1)});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('${_model.textController1.text} registrado correctamente', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          ]),
          backgroundColor: _C.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        context.pushNamed(
          DetalleClienteWidget.routeName,
          queryParameters: {
            'rf': serializeParam(_model.rf?.reference, ParamType.DocumentReference),
          }.withoutNulls,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al registrar: $e', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          backgroundColor: _C.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                  child: Column(children: [
                    _buildBanner().animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0),
                    const SizedBox(height: 16),

                    // ── Datos personales ──
                    _FormSection(
                      icon: Icons.person_rounded,
                      color: _C.primary,
                      title: 'Datos Personales',
                      subtitle: 'Información básica del cliente',
                      children: [
                        _FormField(
                          controller: _model.textController1!,
                          focusNode: _model.textFieldFocusNode1!,
                          label: 'NOMBRE',
                          hint: 'Ej: Juan',
                          icon: Icons.badge_rounded,
                          iconColor: _C.primary,
                          validator: (val) => _model.textController1Validator.asValidator(context)?.call(val),
                        ),
                        _FormField(
                          controller: _model.textController2!,
                          focusNode: _model.textFieldFocusNode2!,
                          label: 'APELLIDO',
                          hint: 'Ej: Pérez',
                          icon: Icons.badge_outlined,
                          iconColor: _C.primary,
                          validator: (val) => _model.textController2Validator.asValidator(context)?.call(val),
                        ),
                        _FormField(
                          controller: _model.textController3!,
                          focusNode: _model.textFieldFocusNode3!,
                          label: 'CÉDULA',
                          hint: 'Número de identificación',
                          icon: Icons.credit_card_rounded,
                          iconColor: _C.purple,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (val) => _model.textController3Validator.asValidator(context)?.call(val),
                        ),
                        _FormField(
                          controller: _model.textController4!,
                          focusNode: _model.textFieldFocusNode4!,
                          label: 'TELÉFONO',
                          hint: 'Número de contacto',
                          icon: Icons.phone_rounded,
                          iconColor: _C.success,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (val) => _model.textController4Validator.asValidator(context)?.call(val),
                        ),
                      ],
                    ).animate().fadeIn(duration: 350.ms, delay: 100.ms).slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 14),

                    // ── Ubicación ──
                    _FormSection(
                      icon: Icons.location_on_rounded,
                      color: _C.accent,
                      title: 'Ubicación',
                      subtitle: 'Finca y vereda del cliente',
                      children: [
                        _FormField(
                          controller: _model.textController5!,
                          focusNode: _model.textFieldFocusNode5!,
                          label: 'NOMBRE DE LA FINCA',
                          hint: 'Ej: Finca La Esperanza',
                          icon: Icons.agriculture_rounded,
                          iconColor: _C.accent,
                          validator: (val) => _model.textController5Validator.asValidator(context)?.call(val),
                        ),
                        _FormField(
                          controller: _model.textController6!,
                          focusNode: _model.textFieldFocusNode6!,
                          label: 'VEREDA',
                          hint: 'Nombre de la vereda',
                          icon: Icons.map_rounded,
                          iconColor: _C.warning,
                          validator: (val) => _model.textController6Validator.asValidator(context)?.call(val),
                        ),
                      ],
                    ).animate().fadeIn(duration: 350.ms, delay: 200.ms).slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 14),

                    // ── Starlink + Equipos ──
                    _FormSection(
                      icon: Icons.satellite_alt_rounded,
                      color: _C.primary,
                      title: 'Red y Equipos',
                      subtitle: 'Starlink, antena y router asignados',
                      children: [
                        _StyledDropdown<String>(
                          label: 'STARLINK',
                          hint: 'Selecciona la Starlink',
                          icon: Icons.satellite_alt_rounded,
                          color: _C.primary,
                          value: _starlinkId,
                          errorText: _validarDropdowns && _starlinkSel == null ? 'Selecciona una Starlink' : null,
                          items: _starlinks.map((doc) {
                            final d = doc.data() as Map<String, dynamic>;
                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: _dropdownItem(Icons.satellite_alt_rounded, d['nombre'] ?? '', d['ubicacion'] ?? '', _C.primary),
                            );
                          }).toList(),
                          onChanged: (id) {
                            final doc = _starlinks.firstWhere((d) => d.id == id);
                            setState(() {
                              _starlinkId = id;
                              _starlinkSel = doc.data() as Map<String, dynamic>;
                            });
                          },
                        ),
                        _StyledDropdown<String>(
                          label: 'ANTENA',
                          hint: 'Selecciona la antena',
                          icon: Icons.cell_tower_rounded,
                          color: _C.accent,
                          value: _antenaId,
                          errorText: _validarDropdowns && _antenaSel == null ? 'Selecciona una antena' : null,
                          items: _antenas.map((doc) {
                            final d = doc.data() as Map<String, dynamic>;
                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: _dropdownItem(Icons.cell_tower_rounded, '${d['marca']} ${d['modelo']}', 'IP: ${d['ip']}', _C.accent),
                            );
                          }).toList(),
                          onChanged: (id) {
                            final doc = _antenas.firstWhere((d) => d.id == id);
                            setState(() {
                              _antenaId = id;
                              _antenaSel = doc.data() as Map<String, dynamic>;
                            });
                          },
                        ),
                        _StyledDropdown<String>(
                          label: 'ROUTER',
                          hint: 'Selecciona el router',
                          icon: Icons.router_rounded,
                          color: _C.purple,
                          value: _routerId,
                          errorText: _validarDropdowns && _routerSel == null ? 'Selecciona un router' : null,
                          items: _routers.map((doc) {
                            final d = doc.data() as Map<String, dynamic>;
                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: _dropdownItem(Icons.router_rounded, '${d['marca']} ${d['modelo']}', 'IP: ${d['ip']}', _C.purple),
                            );
                          }).toList(),
                          onChanged: (id) {
                            final doc = _routers.firstWhere((d) => d.id == id);
                            setState(() {
                              _routerId = id;
                              _routerSel = doc.data() as Map<String, dynamic>;
                            });
                          },
                        ),
                      ],
                    ).animate().fadeIn(duration: 350.ms, delay: 280.ms).slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 14),

                    // ── Plan y servicio ──
                    _FormSection(
                      icon: Icons.wifi_rounded,
                      color: _C.success,
                      title: 'Plan de Servicio',
                      subtitle: 'Tipo, velocidad y precio del plan',
                      children: [
                        // ── Plan dinámico desde Firestore ──
                        _buildPlanDropdown(),

                        // ── Velocidad — formato 2M/2M igual que detalle_cliente ──
                        _StyledDropdown<String>(
                          label: 'VELOCIDAD (SUBIDA/BAJADA)',
                          hint: 'Selecciona la velocidad',
                          icon: Icons.speed_rounded,
                          color: _C.warning,
                          value: _velocidad,
                          errorText: _validarDropdowns && _velocidad == null ? 'Selecciona la velocidad' : null,
                          items: _velocidades.map((v) {
                            final parts = v.split('/');
                            return DropdownMenuItem<String>(
                              value: v,
                              child: _dropdownItem(
                                Icons.speed_rounded,
                                v,
                                '↑ ${parts[0]} subida  ·  ↓ ${parts[1]} bajada',
                                _C.warning,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _velocidad = v),
                        ),

                        // ── Tipo de servicio — igual que detalle_cliente ──
                        _StyledDropdown<String>(
                          label: 'TIPO DE SERVICIO',
                          hint: 'Fibra Óptica o Radio Enlace',
                          icon: Icons.cable_rounded,
                          color: _C.purple,
                          value: _tipoServicio,
                          errorText: _validarDropdowns && _tipoServicio == null ? 'Selecciona el tipo de servicio' : null,
                          items: _tiposServicio.map((t) {
                            return DropdownMenuItem<String>(
                              value: t,
                              child: _dropdownItem(
                                t == 'Fibra Óptica' ? Icons.fiber_smart_record_rounded : Icons.cell_tower_rounded,
                                t,
                                t == 'Fibra Óptica' ? 'Conexión por fibra óptica' : 'Enlace punto a punto',
                                _C.purple,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _tipoServicio = v),
                        ),
                      ],
                    ).animate().fadeIn(duration: 350.ms, delay: 340.ms).slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 14),

                    _buildAutoInfoCard().animate().fadeIn(duration: 350.ms, delay: 400.ms),
                    const SizedBox(height: 20),

                    _buildSubmitButton().animate().fadeIn(duration: 350.ms, delay: 440.ms).slideY(begin: 0.05, end: 0),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  DROPDOWN DE PLANES (idéntico a detalle_cliente)
  // ─────────────────────────────────────────
  Widget _buildPlanDropdown() {
    if (_cargandoPlanes) {
      return Container(
        height: 56,
        decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _C.border)),
        child: Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary)),
            const SizedBox(width: 8),
            Text('Cargando planes...', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13)),
          ]),
        ),
      );
    }

    if (_planesDisponibles.isEmpty) {
      // Estado vacío — lleva a crear planes
      return GestureDetector(
        onTap: () => context.pushNamed(PlanesWidget.routeName),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _C.danger.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.danger.withOpacity(0.35), width: 1.4),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: _C.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.add_card_rounded, color: _C.danger, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sin planes creados', style: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 13, fontWeight: FontWeight.w700)),
                Text('Toca aquí para crear tu primer plan de servicio', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
              ]),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: _C.danger, size: 14),
          ]),
        ),
      );
    }

    // Hay planes → dropdown normal
    final safeValue = _planesDisponibles.any((p) => p.id == _selPlanItem?.id) ? _selPlanItem : null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text('PLAN DEL CLIENTE',
            style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      ),
      Container(
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: safeValue != null ? _C.success : (_validarDropdowns && _selPlanItem == null ? _C.danger : _C.border),
            width: safeValue != null ? 1.8 : 1.2,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<_PlanItem>(
            value: safeValue,
            isExpanded: true,
            borderRadius: BorderRadius.circular(14),
            dropdownColor: _C.surface,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            icon: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.keyboard_arrow_down_rounded, color: _C.textSec),
            ),
            hint: Row(children: [
              Container(
                margin: const EdgeInsets.only(left: 6, right: 10),
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: _C.success.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
                child: Icon(Icons.payments_rounded, color: _C.success, size: 16),
              ),
              Text('Selecciona el plan', style: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.6), fontSize: 14)),
            ]),
            items: _planesDisponibles
                .map((p) => DropdownMenuItem<_PlanItem>(
                      value: p,
                      child: _dropdownItem(
                        Icons.payments_rounded,
                        p.nombre,
                        '${p.simbolo} ${p.valor.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')} / mes · ${p.monedaCodigo}',
                        _C.success,
                      ),
                    ))
                .toList(),
            onChanged: (p) => setState(() => _selPlanItem = p),
          ),
        ),
      ),
      if (_validarDropdowns && _selPlanItem == null)
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 4),
          child: Text('Selecciona un plan', style: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 11)),
        ),
    ]);
  }

  Widget _dropdownItem(IconData icon, String title, String sub, Color color) {
    return Row(children: [
      Container(
        margin: const EdgeInsets.only(left: 4, right: 10),
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 15),
      ),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(sub, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
      ])),
    ]);
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
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.textPri, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Nuevo Cliente', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 20, fontWeight: FontWeight.w800)),
          Text('Completa todos los campos', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _C.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.success.withOpacity(0.3)),
          ),
          child: Row(children: [
            Icon(Icons.wifi_rounded, color: _C.success, size: 13),
            const SizedBox(width: 5),
            Text('Activo', style: GoogleFonts.spaceGrotesk(color: _C.success, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_C.dark, Color(0xFF1E293B)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _C.dark.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_C.primary, _C.accent]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Registrar nuevo cliente', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text('La IP, usuario y clave se generan automáticamente.', style: GoogleFonts.spaceGrotesk(color: Colors.white60, fontSize: 12)),
        ])),
      ]),
    );
  }

  Widget _buildAutoInfoCard() {
    final items = [
      (Icons.router_rounded, _C.accent, 'IP Antena', 'Auto-generada'),
      (Icons.device_hub_rounded, _C.purple, 'IP Router', 'Auto-generada'),
      (Icons.lock_rounded, _C.warning, 'Claves', 'Basadas en finca + cédula'),
      (Icons.wifi_rounded, _C.success, 'Estado inicial', 'Activo'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: _C.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.auto_awesome_rounded, color: _C.primary, size: 16),
            ),
            const SizedBox(width: 10),
            Text('Datos generados automáticamente',
                style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map((item) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: item.$2.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: item.$2.withOpacity(0.2)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(item.$1, color: item.$2, size: 14),
                        const SizedBox(width: 6),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.$3, style: GoogleFonts.spaceGrotesk(color: item.$2, fontSize: 11, fontWeight: FontWeight.w700)),
                          Text(item.$4, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10)),
                        ]),
                      ]),
                    ))
                .toList(),
          ),
        ]),
      ),
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
          boxShadow: _isLoading ? [] : [BoxShadow(color: _C.primary.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : _registrar,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: _isLoading
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_C.textSec))),
                      const SizedBox(width: 10),
                      Text('Registrando...', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 15, fontWeight: FontWeight.w600)),
                    ])
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text('Registrar Cliente',
                          style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}
