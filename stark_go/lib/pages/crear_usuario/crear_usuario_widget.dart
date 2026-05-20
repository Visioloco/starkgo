import 'package:stark_go/services/vps_service.dart';
import 'package:stark_go/pages/config_velocidades/config_velocidades_widget.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'crear_usuario_model.dart';
export 'crear_usuario_model.dart';

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

class _PaisItem {
  final String codigo, bandera, nombre;
  const _PaisItem({required this.codigo, required this.bandera, required this.nombre});
}

const List<_PaisItem> _paises = [
  _PaisItem(codigo: '+57', bandera: '🇨🇴', nombre: 'Colombia'),
  _PaisItem(codigo: '+1', bandera: '🇺🇸', nombre: 'EE. UU.'),
  _PaisItem(codigo: '+52', bandera: '🇲🇽', nombre: 'México'),
  _PaisItem(codigo: '+54', bandera: '🇦🇷', nombre: 'Argentina'),
  _PaisItem(codigo: '+56', bandera: '🇨🇱', nombre: 'Chile'),
  _PaisItem(codigo: '+51', bandera: '🇵🇪', nombre: 'Perú'),
  _PaisItem(codigo: '+58', bandera: '🇻🇪', nombre: 'Venezuela'),
  _PaisItem(codigo: '+593', bandera: '🇪🇨', nombre: 'Ecuador'),
  _PaisItem(codigo: '+591', bandera: '🇧🇴', nombre: 'Bolivia'),
  _PaisItem(codigo: '+598', bandera: '🇺🇾', nombre: 'Uruguay'),
  _PaisItem(codigo: '+595', bandera: '🇵🇾', nombre: 'Paraguay'),
  _PaisItem(codigo: '+34', bandera: '🇪🇸', nombre: 'España'),
  _PaisItem(codigo: '+55', bandera: '🇧🇷', nombre: 'Brasil'),
  _PaisItem(codigo: '+44', bandera: '🇬🇧', nombre: 'Reino Unido'),
  _PaisItem(codigo: '+49', bandera: '🇩🇪', nombre: 'Alemania'),
  _PaisItem(codigo: '+33', bandera: '🇫🇷', nombre: 'Francia'),
  _PaisItem(codigo: '+39', bandera: '🇮🇹', nombre: 'Italia'),
  _PaisItem(codigo: '+507', bandera: '🇵🇦', nombre: 'Panamá'),
  _PaisItem(codigo: '+506', bandera: '🇨🇷', nombre: 'Costa Rica'),
  _PaisItem(codigo: '+503', bandera: '🇸🇻', nombre: 'El Salvador'),
  _PaisItem(codigo: '+502', bandera: '🇬🇹', nombre: 'Guatemala'),
  _PaisItem(codigo: '+504', bandera: '🇭🇳', nombre: 'Honduras'),
  _PaisItem(codigo: '+505', bandera: '🇳🇮', nombre: 'Nicaragua'),
  _PaisItem(codigo: '+53', bandera: '🇨🇺', nombre: 'Cuba'),
  _PaisItem(codigo: '+1787', bandera: '🇵🇷', nombre: 'Puerto Rico'),
  _PaisItem(codigo: '+1809', bandera: '🇩🇴', nombre: 'Rep. Dominicana'),
];

class _PlanItem {
  final String id, nombre, simbolo, monedaCodigo;
  final double valor;
  const _PlanItem({
    required this.id,
    required this.nombre,
    required this.valor,
    required this.simbolo,
    required this.monedaCodigo,
  });
}

// ─────────────────────────────────────────────────────────────
//  Componentes reutilizables
// ─────────────────────────────────────────────────────────────
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
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label,
              style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
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
            enabledBorder:
                OutlineInputBorder(borderSide: BorderSide(color: _C.border, width: 1.2), borderRadius: BorderRadius.circular(14)),
            focusedBorder:
                OutlineInputBorder(borderSide: BorderSide(color: iconColor, width: 1.8), borderRadius: BorderRadius.circular(14)),
            errorBorder: OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.5), borderRadius: BorderRadius.circular(14)),
            focusedErrorBorder:
                OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.8), borderRadius: BorderRadius.circular(14)),
            errorStyle: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 11),
          ),
        ),
      ]);
}

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
          border: Border.all(color: hasError ? _C.danger : (value != null ? color : _C.border), width: value != null ? 1.8 : 1.2),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
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
  Widget build(BuildContext context) => Container(
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
                    gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]), borderRadius: BorderRadius.circular(12)),
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

// ═════════════════════════════════════════════════════════════
//  MAIN WIDGET
// ═════════════════════════════════════════════════════════════
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

  Map<String, dynamic>? _starlinkSel;
  String? _starlinkId;
  Map<String, dynamic>? _antenaSel;
  String? _antenaId;
  Map<String, dynamic>? _routerSel;
  String? _routerId;
  String? _tipoServicio;
  String? _velocidad;
  _PaisItem _selPais = _paises.first;

  List<_PlanItem> _planesDisponibles = [];
  bool _cargandoPlanes = false;
  _PlanItem? _selPlanItem;

  List<String> _velocidades = [];
  bool _cargandoVelocidades = false;

  List<QueryDocumentSnapshot> _starlinks = [];
  List<QueryDocumentSnapshot> _antenas = [];
  List<QueryDocumentSnapshot> _routers = [];

  // Controllers manuales de IP
  final _ctrlIpAntena = TextEditingController();
  final _focusIpAntena = FocusNode();
  final _ctrlIpRouter = TextEditingController();
  final _focusIpRouter = FocusNode();

  static const _tiposServicio = ['Fibra Óptica', 'Radio Enlace'];
  static const String _kColVel = 'velocidades';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Validador de IP ──────────────────────────────────────
  static String? _validarIp(String? val) {
    if (val == null || val.trim().isEmpty) return 'Ingresa la IP';
    final ok = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(val.trim());
    if (!ok) return 'IP inválida · Ej: 192.168.1.100';
    final partes = val.trim().split('.');
    for (final p in partes) {
      final n = int.tryParse(p) ?? 256;
      if (n > 255) return 'IP inválida · cada octeto debe ser 0-255';
    }
    return null;
  }

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
      _cargarTodo();
      safeSetState(() {});
    });
  }

  @override
  void dispose() {
    _ctrlIpAntena.dispose();
    _focusIpAntena.dispose();
    _ctrlIpRouter.dispose();
    _focusIpRouter.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async => Future.wait([_cargarEquiposYPlanes(), _cargarVelocidades()]);

  Future<void> _cargarEquiposYPlanes() async {
    if (_uid == null) return;

    final r = await Future.wait([
      FirebaseFirestore.instance.collection('starlinks').where('propietarioUid', isEqualTo: _uid).get(),
      FirebaseFirestore.instance.collection('equipos').where('tipo', isEqualTo: 'antena').where('propietarioUid', isEqualTo: _uid).get(),
      FirebaseFirestore.instance.collection('equipos').where('tipo', isEqualTo: 'router').where('propietarioUid', isEqualTo: _uid).get(),
      _cargarPlanesUsuario(),
    ]);

    if (mounted) {
      setState(() {
        _starlinks = (r[0] as QuerySnapshot).docs;
        _antenas = (r[1] as QuerySnapshot).docs;
        _routers = (r[2] as QuerySnapshot).docs;
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
      if (mounted) setState(() => _cargandoPlanes = false);
      rethrow;
    }
  }

  Future<void> _cargarVelocidades() async {
    if (_uid == null) return;
    setState(() => _cargandoVelocidades = true);
    try {
      final doc = await FirebaseFirestore.instance.collection(_kColVel).doc(_uid).get();
      if (doc.exists && mounted) {
        final raw = (doc.data() as Map<String, dynamic>)['lista'];
        setState(() => _velocidades = raw is List ? List<String>.from(raw.map((e) => e.toString())) : []);
      }
    } catch (e) {
      debugPrint('[StarkGo] Error cargando velocidades: $e');
    } finally {
      if (mounted) setState(() => _cargandoVelocidades = false);
    }
  }

  bool get _dropdownsValidos =>
      _starlinkSel != null &&
      _antenaSel != null &&
      _routerSel != null &&
      _selPlanItem != null &&
      _tipoServicio != null &&
      _velocidad != null;

  // ── Registrar ────────────────────────────────────────────
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

    // Validar IPs manualmente
    final errIpAtn = _validarIp(_ctrlIpAntena.text);
    final errIpRtr = _validarIp(_ctrlIpRouter.text);
    if (errIpAtn != null || errIpRtr != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errIpAtn ?? errIpRtr!, style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        backgroundColor: _C.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // IPs ingresadas manualmente
      _model.antna = _ctrlIpAntena.text.trim();
      _model.routr = _ctrlIpRouter.text.trim();

      // Clave sigue siendo auto-generada
      _model.clav = await actions.generarClave(_model.textController5.text, int.parse(_model.textController3.text));

      final uid = FirebaseAuth.instance.currentUser?.uid;
      final ref = ClientesRecord.collection.doc();

      final data = createClientesRecordData(
        nombre: _model.textController1.text.trim(),
        apellido: _model.textController2.text.trim(),
        cc: int.tryParse(_model.textController3.text),
        numero: int.tryParse(_model.textController4.text),
        nombrefinca: _model.textController5.text.trim(),
        vereda: _model.textController6.text.trim(),
        ipatn: _model.antna, // ← IP manual antena
        usuarioatn: _model.clav,
        claveatn: _model.clav,
        iprouter: _model.routr, // ← IP manual router
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
        planCliente: _selPlanItem!.nombre,
        tipoServicio: _tipoServicio,
        velocidadPlan: _velocidad,
      );

      await ref.set(data);
      _model.rf = ClientesRecord.getDocumentFromData(data, ref);

      await FirebaseFirestore.instance.collection('clientes').doc(ref.id).update({
        'planId': _selPlanItem!.id,
        'planValor': _selPlanItem!.valor,
        'planSimbolo': _selPlanItem!.simbolo,
        'planMoneda': _selPlanItem!.monedaCodigo,
        'codigoPais': _selPais.codigo,
      });

      // Notificar al VPS con la IP manual de la antena
      await VpsService.clienteCreado(
        nombre: '${_model.textController1.text.trim()} ${_model.textController2.text.trim()}',
        ip: _model.antna ?? '',
        velocidad: _velocidad ?? '',
      );

      if (uid != null) {
        await FirebaseFirestore.instance.collection('clientes').doc(ref.id).update({'propietarioUid': uid});
      }

      await FirebaseFirestore.instance.collection('starlinks').doc(_starlinkId).update({'clientes_count': FieldValue.increment(1)});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('${_model.textController1.text} registrado', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          ]),
          backgroundColor: _C.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        context.pushNamed(DetalleClienteWidget.routeName,
            queryParameters: {'rf': serializeParam(_model.rf?.reference, ParamType.DocumentReference)}.withoutNulls);
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

  // ════════════════════════════════════════════════════════
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

                    // ── Datos personales ──────────────────
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
                        _buildTelefonoField(),
                      ],
                    ).animate().fadeIn(duration: 350.ms, delay: 100.ms).slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 14),

                    // ── Ubicación ─────────────────────────
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

                    // ── Red y Equipos ─────────────────────
                    _FormSection(
                      icon: Icons.satellite_alt_rounded,
                      color: _C.primary,
                      title: 'Red y Equipos',
                      subtitle: 'IPs manuales, Starlink, antena y router',
                      children: [
                        // IP Antena manual
                        _FormField(
                          controller: _ctrlIpAntena,
                          focusNode: _focusIpAntena,
                          label: 'IP ANTENA',
                          hint: 'Ej: 192.168.1.100',
                          icon: Icons.cell_tower_rounded,
                          iconColor: _C.accent,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                          validator: _validarIp,
                        ),
                        // IP Router manual
                        _FormField(
                          controller: _ctrlIpRouter,
                          focusNode: _focusIpRouter,
                          label: 'IP ROUTER',
                          hint: 'Ej: 192.168.1.1',
                          icon: Icons.router_rounded,
                          iconColor: _C.purple,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                          validator: _validarIp,
                        ),
                        // Starlink
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
                              child: _ddItem(Icons.satellite_alt_rounded, d['nombre'] ?? '', d['ubicacion'] ?? '', _C.primary),
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
                        // Antena
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
                              child: _ddItem(Icons.cell_tower_rounded, '${d['marca']} ${d['modelo']}', 'IP: ${d['ip']}', _C.accent),
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
                        // Router
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
                              child: _ddItem(Icons.router_rounded, '${d['marca']} ${d['modelo']}', 'IP: ${d['ip']}', _C.purple),
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

                    // ── Plan de servicio ──────────────────
                    _FormSection(
                      icon: Icons.wifi_rounded,
                      color: _C.success,
                      title: 'Plan de Servicio',
                      subtitle: 'Tipo, velocidad y precio',
                      children: [
                        _buildPlanDropdown(),
                        _buildVelocidadDropdown(),
                        _StyledDropdown<String>(
                          label: 'TIPO DE SERVICIO',
                          hint: 'Fibra Óptica o Radio Enlace',
                          icon: Icons.cable_rounded,
                          color: _C.purple,
                          value: _tipoServicio,
                          errorText: _validarDropdowns && _tipoServicio == null ? 'Selecciona el tipo' : null,
                          items: _tiposServicio
                              .map((t) => DropdownMenuItem<String>(
                                    value: t,
                                    child: _ddItem(
                                      t == 'Fibra Óptica' ? Icons.fiber_smart_record_rounded : Icons.cell_tower_rounded,
                                      t,
                                      t == 'Fibra Óptica' ? 'Conexión por fibra óptica' : 'Enlace punto a punto',
                                      _C.purple,
                                    ),
                                  ))
                              .toList(),
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

  // ── Dropdown velocidad ───────────────────────────────────
  Widget _buildVelocidadDropdown() {
    if (_cargandoVelocidades) {
      return Container(
        height: 56,
        decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _C.border)),
        child: Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _C.warning)),
            const SizedBox(width: 8),
            Text('Cargando velocidades...', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13)),
          ]),
        ),
      );
    }
    if (_velocidades.isEmpty) {
      return GestureDetector(
        onTap: () async {
          await context.pushNamed(ConfigVelocidadesWidget.routeName);
          _cargarVelocidades();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _C.warning.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.warning.withOpacity(0.45), width: 1.5),
          ),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: _C.warning.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.speed_rounded, color: _C.warning, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sin velocidades configuradas',
                    style: GoogleFonts.spaceGrotesk(color: _C.warning, fontSize: 13, fontWeight: FontWeight.w700)),
                Text('Toca aquí para configurar antes de crear un cliente',
                    style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
              ]),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: _C.warning, size: 14),
          ]),
        ),
      );
    }
    final safeValue = _velocidades.contains(_velocidad) ? _velocidad : null;
    return _StyledDropdown<String>(
      label: 'VELOCIDAD (SUBIDA/BAJADA)',
      hint: 'Selecciona la velocidad',
      icon: Icons.speed_rounded,
      color: _C.warning,
      value: safeValue,
      errorText: _validarDropdowns && _velocidad == null ? 'Selecciona la velocidad' : null,
      items: _velocidades.map((v) {
        final p = v.split('/');
        return DropdownMenuItem<String>(
          value: v,
          child: _ddItem(Icons.speed_rounded, v, '↑ ${p[0]} subida  ·  ↓ ${p.length > 1 ? p[1] : ''} bajada', _C.warning),
        );
      }).toList(),
      onChanged: (v) => setState(() => _velocidad = v),
    );
  }

  // ── Campo teléfono con selector de país ──────────────────
  Widget _buildTelefonoField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text('TELÉFONO',
            style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      ),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 54,
          decoration:
              BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _C.border, width: 1.2)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<_PaisItem>(
              value: _selPais,
              borderRadius: BorderRadius.circular(14),
              dropdownColor: _C.surface,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _C.textSec, size: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              items: _paises
                  .map((p) => DropdownMenuItem<_PaisItem>(
                        value: p,
                        child: Text('${p.bandera} ${p.codigo}  ${p.nombre}',
                            style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w500)),
                      ))
                  .toList(),
              onChanged: (p) {
                if (p != null) setState(() => _selPais = p);
              },
              selectedItemBuilder: (_) => _paises
                  .map((p) => Center(
                        child: Text('${p.bandera} ${p.codigo}',
                            style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: _C.primary)),
                      ))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: _model.textController4!,
            focusNode: _model.textFieldFocusNode4!,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w500),
            validator: (val) => _model.textController4Validator.asValidator(context)?.call(val),
            decoration: InputDecoration(
              hintText: 'Número sin prefijo',
              hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.5), fontSize: 13),
              prefixIcon: Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: _C.success.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
                child: Icon(Icons.phone_rounded, color: _C.success, size: 17),
              ),
              filled: true,
              fillColor: _C.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder:
                  OutlineInputBorder(borderSide: BorderSide(color: _C.border, width: 1.2), borderRadius: BorderRadius.circular(14)),
              focusedBorder:
                  OutlineInputBorder(borderSide: BorderSide(color: _C.success, width: 1.8), borderRadius: BorderRadius.circular(14)),
              errorBorder:
                  OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.5), borderRadius: BorderRadius.circular(14)),
              focusedErrorBorder:
                  OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.8), borderRadius: BorderRadius.circular(14)),
              errorStyle: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 11),
            ),
          ),
        ),
      ]),
    ]);
  }

  // ── Dropdown plan ────────────────────────────────────────
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
                Text('Toca aquí para crear tu primer plan', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
              ]),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: _C.danger, size: 14),
          ]),
        ),
      );
    }
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
            icon: Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.keyboard_arrow_down_rounded, color: _C.textSec)),
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
                      child: _ddItem(
                        Icons.payments_rounded,
                        p.nombre,
                        '${p.simbolo} ${p.valor.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')} / mes',
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

  // ── Helper item dropdown ─────────────────────────────────
  Widget _ddItem(IconData icon, String title, String sub, Color color) => Row(children: [
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
          ]),
        ),
      ]);

  // ── Top bar ──────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) => Padding(
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
            ]),
          ),
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

  // ── Banner superior ──────────────────────────────────────
  Widget _buildBanner() => Container(
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
            decoration:
                BoxDecoration(gradient: const LinearGradient(colors: [_C.primary, _C.accent]), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Registrar nuevo cliente',
                  style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              Text('Ingresa las IPs manualmente · clave generada automáticamente',
                  style: GoogleFonts.spaceGrotesk(color: Colors.white60, fontSize: 12)),
            ]),
          ),
        ]),
      );

  // ── Tarjeta info auto ────────────────────────────────────
  Widget _buildAutoInfoCard() {
    final items = [
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

  // ── Botón registrar ──────────────────────────────────────
  Widget _buildSubmitButton() => SizedBox(
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
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_C.textSec)),
                        ),
                        const SizedBox(width: 10),
                        Text('Registrando...',
                            style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 15, fontWeight: FontWeight.w600)),
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
