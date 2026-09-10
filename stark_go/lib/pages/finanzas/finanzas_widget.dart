import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stark_go/services/finanzas_cobros_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  FINANZAS PERSONALES — Control de ingresos y gastos
//  Guarda en Firestore → colección "finanzas" por usuario (propietarioUid)
// ═══════════════════════════════════════════════════════════════════════════

// ── DESIGN SYSTEM ────────────────────────────────────────────────────────────
class _C {
  static const Color primary = Color(0xFF1A73E8);
  static const Color income = Color(0xFF22C55E);
  static const Color expense = Color(0xFFE53935);
  static const Color warning = Color(0xFFF59E0B);
  static const Color purple = Color(0xFF7C3AED);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF5F7FA);
  static const Color textPri = Color(0xFF0F172A);
  static const Color textSec = Color(0xFF64748B);
  static const Color textTer = Color(0xFF9AA6B4);
  static const Color border = Color(0xFFE7ECF2);
}

TextStyle _f(double size,
        {FontWeight w = FontWeight.w500, Color c = _C.textPri, double? h}) =>
    GoogleFonts.spaceGrotesk(
        fontSize: size, fontWeight: w, color: c, height: h);

BoxDecoration _cardDecoration(
        {Color? borderColor, double radius = 16, Color? color}) =>
    BoxDecoration(
      color: color ?? _C.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? _C.border, width: 1.1),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 5))
      ],
    );

// ── MONEDA (COP) ─────────────────────────────────────────────────────────────
const _mesesLargos = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre'
];
const _mesesCortos = [
  'Ene',
  'Feb',
  'Mar',
  'Abr',
  'May',
  'Jun',
  'Jul',
  'Ago',
  'Sep',
  'Oct',
  'Nov',
  'Dic'
];

String _fmtMoneda(double v) {
  final neg = v < 0;
  final entero = v.abs().round().toString().split('');
  final buf = StringBuffer();
  int cnt = 0;
  for (int i = entero.length - 1; i >= 0; i--) {
    if (cnt > 0 && cnt % 3 == 0) buf.write('.');
    buf.write(entero[i]);
    cnt++;
  }
  final s = buf.toString().split('').reversed.join('');
  return '${neg ? '-' : ''}\$$s';
}

String _fmtMonedaCorta(double v) {
  final neg = v < 0;
  final a = v.abs();
  if (a >= 1000000)
    return '${neg ? '-' : ''}\$${(a / 1000000).toStringAsFixed(1)}M';
  if (a >= 1000) return '${neg ? '-' : ''}\$${(a / 1000).toStringAsFixed(0)}K';
  return '${neg ? '-' : ''}\$${a.toStringAsFixed(0)}';
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
}

// Convierte lo que el usuario escriba ("250000", "1.500.000", "50.500,75")
double? _parseMontoInput(String raw) {
  var s = raw.trim().replaceAll(' ', '');
  if (s.isEmpty) return null;
  s = s.replaceAll('\$', '');
  final tienePunto = s.contains('.');
  final tieneComa = s.contains(',');
  if (tienePunto && tieneComa) {
    // Formato colombiano: puntos como separador de miles y coma decimal.
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (tienePunto) {
    final partes = s.split('.');
    final decimal = partes.length > 1 ? partes.last : '';
    if (decimal.length != 3) {
      // "1.5" → 1.5 ; "500.75" → 500.75
    } else {
      // "1.500" → 1500 (separador de miles)
      s = s.replaceAll('.', '');
    }
  } else if (tieneComa) {
    final partes = s.split(',');
    final decimal = partes.length > 1 ? partes.last : '';
    if (decimal.length != 3) {
      s = s.replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  }
  return double.tryParse(s);
}

// ── CATEGORÍAS ───────────────────────────────────────────────────────────────
const _categoriasIngreso = [
  'Ventas / Servicios',
  'Salario',
  'Freelance',
  'Inversiones',
  'Negocio propio',
  'Otros ingresos'
];
const _categoriasGasto = [
  'Alimentación',
  'Transporte',
  'Servicios',
  'Internet',
  'Arriendo',
  'Salud',
  'Educación',
  'Entretenimiento',
  'Suscripciones',
  'Otros gastos'
];

Color _colorCategoria(String tipo, String categoria) {
  if (tipo == 'ingreso') {
    switch (categoria) {
      case 'Ventas / Servicios':
        return const Color(0xFF1A73E8);
      case 'Salario':
        return const Color(0xFF22C55E);
      case 'Freelance':
        return const Color(0xFF00C6AE);
      case 'Inversiones':
        return const Color(0xFF7C3AED);
      case 'Negocio propio':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF64748B);
    }
  }
  switch (categoria) {
    case 'Alimentación':
      return const Color(0xFFF59E0B);
    case 'Transporte':
      return const Color(0xFF0EA5E9);
    case 'Servicios':
      return const Color(0xFFF97316);
    case 'Internet':
      return const Color(0xFF1A73E8);
    case 'Arriendo':
      return const Color(0xFF7C3AED);
    case 'Salud':
      return const Color(0xFFE53935);
    case 'Educación':
      return const Color(0xFF8B5CF6);
    case 'Entretenimiento':
      return const Color(0xFFEC4899);
    case 'Suscripciones':
      return const Color(0xFF14B8A6);
    default:
      return const Color(0xFF64748B);
  }
}

IconData _iconoCategoria(String tipo, String categoria) {
  if (tipo == 'ingreso') {
    switch (categoria) {
      case 'Ventas / Servicios':
        return Icons.storefront_rounded;
      case 'Salario':
        return Icons.badge_rounded;
      case 'Freelance':
        return Icons.laptop_mac_rounded;
      case 'Inversiones':
        return Icons.trending_up_rounded;
      case 'Negocio propio':
        return Icons.business_center_rounded;
      default:
        return Icons.payments_rounded;
    }
  }
  switch (categoria) {
    case 'Alimentación':
      return Icons.restaurant_rounded;
    case 'Transporte':
      return Icons.directions_bus_rounded;
    case 'Servicios':
      return Icons.bolt_rounded;
    case 'Internet':
      return Icons.wifi_rounded;
    case 'Arriendo':
      return Icons.home_rounded;
    case 'Salud':
      return Icons.favorite_rounded;
    case 'Educación':
      return Icons.school_rounded;
    case 'Entretenimiento':
      return Icons.movie_rounded;
    case 'Suscripciones':
      return Icons.subscriptions_rounded;
    default:
      return Icons.receipt_long_rounded;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MODELO
// ═══════════════════════════════════════════════════════════════════════════
class _Movimiento {
  final String id;
  final DocumentReference ref;
  final String tipo; // 'ingreso' | 'gasto'
  final String descripcion;
  final String categoria;
  final double monto;
  final DateTime fecha;
  final bool origenCliente; // true si es un cobro automático de cliente

  const _Movimiento({
    required this.id,
    required this.ref,
    required this.tipo,
    required this.descripcion,
    required this.categoria,
    required this.monto,
    required this.fecha,
    this.origenCliente = false,
  });

  factory _Movimiento.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    DateTime? fecha;
    final ts = d['fecha'];
    if (ts is Timestamp) fecha = ts.toDate();
    if (fecha == null) fecha = DateTime.now();
    return _Movimiento(
      id: doc.id,
      ref: doc.reference,
      tipo: (d['tipo'] ?? 'gasto').toString(),
      descripcion: (d['descripcion'] ?? 'Sin descripción').toString(),
      categoria: (d['categoria'] ?? 'Otros gastos').toString(),
      monto: _toDouble(d['monto']).abs(),
      fecha: fecha,
      origenCliente: (d['origenCliente'] ?? false) == true,
    );
  }

  bool get esIngreso => tipo == 'ingreso';
}

class _ClienteCobro {
  final String id;
  final String nombre;
  final double planValor;
  final String status; // activo | mora | inactivo
  final DateTime? alta;
  final DateTime? ultimoPago;

  const _ClienteCobro({
    required this.id,
    required this.nombre,
    required this.planValor,
    required this.status,
    this.alta,
    this.ultimoPago,
  });

  bool get enCartera =>
      (status == 'activo' || status == 'mora') && planValor > 0;

  factory _ClienteCobro.fromDoc(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    DateTime? alta;
    final a = d['fecha'];
    if (a is Timestamp) alta = a.toDate();
    DateTime? ult;
    final u = d['ultimoPago'];
    if (u is Timestamp) ult = u.toDate();
    return _ClienteCobro(
      id: doc.id,
      nombre: (d['nombre'] ?? '').toString().trim(),
      planValor: _toDouble(d['planValor']),
      status: (d['status'] ?? '').toString(),
      alta: alta,
      ultimoPago: ult,
    );
  }
}

class _DraftMovimiento {
  final String? id; // null = nuevo
  final String tipo;
  final double monto;
  final String descripcion;
  final String categoria;
  final DateTime fecha;
  const _DraftMovimiento({
    this.id,
    required this.tipo,
    required this.monto,
    required this.descripcion,
    required this.categoria,
    required this.fecha,
  });
}

class _ResumenMes {
  final int anio;
  final int mes;
  double ingresos = 0;
  double gastos = 0;
  int movimientos = 0;
  double get balance => ingresos - gastos;
  int get clave => anio * 12 + (mes - 1);
  _ResumenMes(this.anio, this.mes);
}

// ═══════════════════════════════════════════════════════════════════════════
//  PÁGINA PRINCIPAL
// ═══════════════════════════════════════════════════════════════════════════
class FinanzasWidget extends StatefulWidget {
  const FinanzasWidget({super.key});

  static String routeName = 'Finanzas';
  static String routePath = 'finanzas';

  @override
  State<FinanzasWidget> createState() => _FinanzasWidgetState();
}

class _FinanzasWidgetState extends State<FinanzasWidget> {
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  late int _mes;
  late int _anio;
  List<_Movimiento> _movs = [];
  List<_ClienteCobro> _clientes = [];
  bool _cargando = true;
  bool _sincronizandoCobros = false;
  StreamSubscription<QuerySnapshot>? _sub;
  StreamSubscription<QuerySnapshot>? _subClientes;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _mes = hoy.month;
    _anio = hoy.year;
    _suscribir();
  }

  void _suscribir() {
    if (_uid.isEmpty) {
      setState(() => _cargando = false);
      return;
    }
    _sub = FirebaseFirestore.instance
        .collection('finanzas')
        .where('propietarioUid', isEqualTo: _uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final docs = snap.docs.map(_Movimiento.fromDoc).toList()
        ..sort((a, b) => b.fecha.compareTo(a.fecha));
      setState(() {
        _movs = docs;
        _cargando = false;
      });
    }, onError: (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar finanzas: $e')));
    });

    // Clientes del usuario → para calcular "esperado por cobrar" según su
    // planValor (lo que deberías recibir en los días de pago).
    _subClientes = FirebaseFirestore.instance
        .collection('clientes')
        .where('propietarioUid', isEqualTo: _uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final docs = snap.docs.map(_ClienteCobro.fromDoc).toList()
        ..sort((a, b) {
          final st = b.status.compareTo(a.status);
          if (st != 0) return st;
          return a.nombre.compareTo(b.nombre);
        });
      setState(() {
        _clientes = docs;
        _cargando = false;
      });
    }, onError: (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar clientes: $e')));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _subClientes?.cancel();
    super.dispose();
  }

  bool get _esMesActual =>
      _anio == DateTime.now().year && _mes == DateTime.now().month;

  bool get _puedeAvanzar {
    final hoy = DateTime.now();
    return _anio * 12 + (_mes - 1) < hoy.year * 12 + (hoy.month - 1);
  }

  void _irAlMes(int anio, int mes) {
    setState(() {
      _anio = anio;
      _mes = mes;
    });
  }

  void _cambiarMes(int delta) {
    var nuevo = _anio * 12 + (_mes - 1) + delta;
    final hoy = DateTime.now();
    final max = hoy.year * 12 + (hoy.month - 1);
    if (nuevo > max) nuevo = max;
    if (nuevo < 0) nuevo = 0;
    _irAlMes(nuevo ~/ 12, (nuevo % 12) + 1);
  }

  // ── Cálculos globales ────────────────────────────────────────────────────────
  double get _totalIngresos =>
      _movs.where((m) => m.esIngreso).fold(0, (s, m) => s + m.monto);
  double get _totalGastos =>
      _movs.where((m) => !m.esIngreso).fold(0, (s, m) => s + m.monto);
  double get _saldoTotal => _totalIngresos - _totalGastos;

  // ── COBROS DE CLIENTES (esperado vs recibido) ───────────────────────────────
  /// Cartera actual: clientes activos o en mora con plan > 0.
  List<_ClienteCobro> get _cartera =>
      _clientes.where((c) => c.enCartera).toList();

  /// Ingresos reales registrados por cobros de clientes en el mes visible.
  double get _recibidoCobrosMes => _movs
      .where((m) =>
          m.esIngreso &&
          m.origenCliente &&
          m.fecha.year == _anio &&
          m.fecha.month == _mes)
      .fold(0.0, (s, m) => s + m.monto);

  /// Esperado del mes visible: suma de planes de la cartera que ya existía
  /// cuando empezó ese mes (según su fecha de alta). Si no hay fecha de alta
  /// se asume que debe pagar desde siempre.
  double get _esperadoMes {
    final fin = DateTime(_anio, _mes + 1, 0); // último día del mes
    double total = 0;
    for (final c in _cartera) {
      if (c.alta != null && c.alta!.isAfter(fin)) continue;
      total += c.planValor;
    }
    return total;
  }

  /// Clientes de la cartera que NO han pagado en el mes visible
  /// (se deduce del campo `ultimoPago`, igual que tu lógica de mora automática).
  List<_ClienteCobro> get _pendientesMes => _cartera.where((c) {
        final u = c.ultimoPago;
        final pagoEsteMes = u != null && u.year == _anio && u.month == _mes;
        return !pagoEsteMes;
      }).toList();

  double get _pendienteMes => (_esperadoMes - _recibidoCobrosMes)
      .clamp(0.0, double.infinity)
      .toDouble();

  bool get _tieneCobrosActivos =>
      _cartera.isNotEmpty || _movs.any((m) => m.esIngreso && m.origenCliente);

  /// Últimos cobros de clientes registrados (para mostrarlos al instante).
  List<_Movimiento> get _cobrosRecientes =>
      _movs.where((m) => m.esIngreso && m.origenCliente).take(3).toList();

  Future<void> _sincronizarCobros() async {
    if (_sincronizandoCobros) return;
    setState(() => _sincronizandoCobros = true);
    try {
      final creados = await FinanzasCobrosService.sincronizarHistoricos(_uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(creados > 0
              ? '✅ $creados cobro(s) importados a Mis Finanzas'
              : '✨ Todo sincronizado: no hay cobros pendientes de importar')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al sincronizar cobros: $e')));
    } finally {
      if (mounted) setState(() => _sincronizandoCobros = false);
    }
  }

  List<_Movimiento> get _movsDelMes => _movs
      .where((m) => m.fecha.year == _anio && m.fecha.month == _mes)
      .toList();

  double _ingresosDe(Iterable<_Movimiento> lista) =>
      lista.where((m) => m.esIngreso).fold(0.0, (s, m) => s + m.monto);
  double _gastosDe(Iterable<_Movimiento> lista) =>
      lista.where((m) => !m.esIngreso).fold(0.0, (s, m) => s + m.monto);

  Map<int, _ResumenMes> _mapaMensual() {
    final map = <int, _ResumenMes>{};
    for (final m in _movs) {
      final clave = m.fecha.year * 12 + (m.fecha.month - 1);
      final r = map.putIfAbsent(
          clave, () => _ResumenMes(m.fecha.year, m.fecha.month));
      r.movimientos++;
      if (m.esIngreso) {
        r.ingresos += m.monto;
      } else {
        r.gastos += m.monto;
      }
    }
    return map;
  }

  List<_ResumenMes> _ultimosMeses(int n) {
    final map = _mapaMensual();
    final fin = _anio * 12 + (_mes - 1);
    final lista = <_ResumenMes>[];
    for (int i = n - 1; i >= 0; i--) {
      final clave = fin - i;
      lista.add(map[clave] ?? _ResumenMes(clave ~/ 12, (clave % 12) + 1));
    }
    return lista;
  }

  // ── CRUD ────────────────────────────────────────────────────────────────────
  Future<void> _abrirFormulario([_Movimiento? existente]) async {
    final draft = await showModalBottomSheet<_DraftMovimiento>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MovimientoSheet(existente: existente),
    );
    if (draft == null || !mounted) return;
    try {
      final data = <String, dynamic>{
        'tipo': draft.tipo,
        'descripcion': draft.descripcion,
        'categoria': draft.categoria,
        'monto': draft.monto,
        'fecha': Timestamp.fromDate(draft.fecha),
      };
      if (draft.id == null) {
        data['propietarioUid'] = _uid;
        data['creadoEn'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('finanzas').add(data);
        if (!mounted) return;
        setState(() {
          _anio = draft.fecha.year;
          _mes = draft.fecha.month;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Movimiento registrado correctamente')));
      } else {
        await FirebaseFirestore.instance
            .collection('finanzas')
            .doc(draft.id)
            .update(data);
        if (!mounted) return;
        setState(() {
          _anio = draft.fecha.year;
          _mes = draft.fecha.month;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✏️ Movimiento actualizado correctamente')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    }
  }

  Future<void> _eliminarMovimiento(_Movimiento m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Eliminar movimiento?'),
        content: Text(
            '"${m.descripcion}" por ${_fmtMoneda(m.monto)} se eliminará permanentemente.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: _C.expense),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await m.ref.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Movimiento eliminado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mesStats = _ultimosMeses(6);
    final movsMes = _movsDelMes;
    final ingresosMes = _ingresosDe(movsMes);
    final gastosMes = _gastosDe(movsMes);
    final balanceMes = ingresosMes - gastosMes;

    return Scaffold(
      backgroundColor: _C.surfaceDim,
      appBar: AppBar(
        backgroundColor: _C.surface,
        surfaceTintColor: _C.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 19, color: _C.textPri),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Mis Finanzas', style: _f(18, w: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Nuevo movimiento',
            icon: const Icon(Icons.add_circle_rounded,
                color: _C.primary, size: 26),
            onPressed: () => _abrirFormulario(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        backgroundColor: _C.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Registrar',
            style: _f(13, w: FontWeight.w700, c: Colors.white)),
      ),
      body: _cargando
          ? const _LoadingFinanzas()
          : RefreshIndicator(
              color: _C.primary,
              onRefresh: () async {},
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                children: [
                  _MesSelector(
                    anio: _anio,
                    mes: _mes,
                    esActual: _esMesActual,
                    puedeAvanzar: _puedeAvanzar,
                    onAnterior: () => _cambiarMes(-1),
                    onSiguiente: () => _cambiarMes(1),
                    onHoy: () {
                      final hoy = DateTime.now();
                      _irAlMes(hoy.year, hoy.month);
                    },
                  ),
                  const SizedBox(height: 14),
                  _HeroBalance(
                    balanceMes: balanceMes,
                    ingresosMes: ingresosMes,
                    gastosMes: gastosMes,
                    movimientosMes: movsMes.length,
                    saldoTotal: _saldoTotal,
                    totalIngresos: _totalIngresos,
                    totalGastos: _totalGastos,
                  ),
                  const SizedBox(height: 14),
                  if (_tieneCobrosActivos) ...[
                    _CobrosCard(
                      anio: _anio,
                      mes: _mes,
                      esperado: _esperadoMes,
                      recibido: _recibidoCobrosMes,
                      pendiente: _pendienteMes,
                      pendientes: _pendientesMes,
                      recientes: _cobrosRecientes,
                      sincronizando: _sincronizandoCobros,
                      onSync: _sincronizarCobros,
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_movs.isNotEmpty) ...[
                    _CardSeccion(
                      icon: Icons.bar_chart_rounded,
                      titulo: 'Ingresos vs Gastos',
                      subtitulo:
                          'Últimos 6 meses hasta ${_mesesLargos[_mes - 1]}',
                      color: _C.primary,
                      child: _BarrasIngresosGastos(datos: mesStats),
                    ),
                    const SizedBox(height: 14),
                    _CardSeccion(
                      icon: Icons.show_chart_rounded,
                      titulo: 'Balance mes a mes',
                      subtitulo: 'Resultado neto de cada mes',
                      color: _C.purple,
                      child: _LineaBalance(datos: mesStats),
                    ),
                    const SizedBox(height: 14),
                    _CardSeccion(
                      icon: Icons.donut_large_rounded,
                      titulo: 'Gastos por categoría',
                      subtitulo: _anio == DateTime.now().year
                          ? '${_mesesLargos[_mes - 1]}'
                          : '${_mesesLargos[_mes - 1]} · $_anio',
                      color: _C.expense,
                      child: _DonaGastos(movs: movsMes),
                    ),
                    const SizedBox(height: 22),
                    _HeaderListaMovimientos(
                      anio: _anio,
                      mes: _mes,
                      count: movsMes.length,
                      totalMes: balanceMes,
                    ),
                    const SizedBox(height: 6),
                    if (movsMes.isEmpty)
                      _SinMovimientos(
                          anio: _anio, mes: _mes, onAgregar: _abrirFormulario)
                    else
                      ..._buildMovimientos(movsMes),
                  ] else if (_clientes.isEmpty)
                    _BienvenidaFinanzas(onAgregar: () => _abrirFormulario()),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildMovimientos(List<_Movimiento> lista) {
    // Agrupa por fecha (día)
    final grupos = <DateTime, List<_Movimiento>>{};
    for (final m in lista) {
      final dia = DateTime(m.fecha.year, m.fecha.month, m.fecha.day);
      grupos.putIfAbsent(dia, () => []).add(m);
    }
    final dias = grupos.keys.toList()..sort((a, b) => b.compareTo(a));
    final out = <Widget>[];
    for (final dia in dias) {
      out.add(_GrupoDia(
        fecha: dia,
        items: grupos[dia]!,
        onEditar: (m) => _abrirFormulario(m),
        onEliminar: (m) => _eliminarMovimiento(m),
      ));
    }
    return out;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  WIDGETS DE SOPORTE
// ═══════════════════════════════════════════════════════════════════════════
// ── COBROS DE CLIENTES (ESPERADO VS RECIBIDO) ───────────────────────────────
class _CobrosCard extends StatelessWidget {
  final int anio, mes;
  final double esperado, recibido, pendiente;
  final List<_ClienteCobro> pendientes;
  final List<_Movimiento> recientes;
  final bool sincronizando;
  final VoidCallback onSync;

  const _CobrosCard({
    required this.anio,
    required this.mes,
    required this.esperado,
    required this.recibido,
    required this.pendiente,
    required this.pendientes,
    required this.recientes,
    required this.sincronizando,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final porc = esperado <= 0 ? 0.0 : (recibido / esperado).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(
          borderColor: _C.primary.withOpacity(0.25), radius: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1A73E8), Color(0xFF00C6AE)]),
              borderRadius: BorderRadius.circular(11),
            ),
            child:
                const Icon(Icons.groups_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cobros de clientes', style: _f(13.5, w: FontWeight.w800)),
              Text('${_mesesLargos[mes - 1]} $anio · días de pago',
                  style: _f(10, c: _C.textTer)),
            ]),
          ),
          TextButton.icon(
            onPressed: sincronizando ? null : onSync,
            icon: sincronizando
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_rounded, size: 16),
            label: Text(sincronizando ? 'Sincronizando' : 'Sincronizar',
                style: _f(11, w: FontWeight.w700, c: _C.primary)),
            style: TextButton.styleFrom(foregroundColor: _C.primary),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _MetroCobro(
              icon: Icons.event_available_rounded,
              label: 'Esperado',
              value: esperado,
              color: _C.primary),
          const SizedBox(width: 6),
          _MetroCobro(
              icon: Icons.check_circle_rounded,
              label: 'Recibido',
              value: recibido,
              color: _C.income),
          const SizedBox(width: 6),
          _MetroCobro(
              icon: Icons.schedule_rounded,
              label: 'Pendiente',
              value: pendiente,
              color: _C.warning),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: porc.toDouble(),
            minHeight: 8,
            backgroundColor: _C.border,
            valueColor: AlwaysStoppedAnimation<Color>(
                porc >= 1 ? _C.income : _C.primary),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Has cobrado el ${(porc * 100).toStringAsFixed(0)}% de lo esperado del mes. '
          'El esperado se calcula con tu cartera actual (activos y en mora).',
          style: _f(9.5, c: _C.textTer, h: 1.4),
        ),
        if (pendientes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(height: 1, color: _C.border),
          const SizedBox(height: 10),
          Row(children: [
            Text('Clientes por pagar este mes',
                style: _f(11.5, w: FontWeight.w800)),
            const Spacer(),
            if (pendientes.length > 4)
              Text('+${pendientes.length - 4} más',
                  style: _f(10, w: FontWeight.w700, c: _C.textSec)),
          ]),
          const SizedBox(height: 4),
          ...pendientes.take(4).map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _C.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Text(
                        c.nombre.isNotEmpty ? c.nombre[0].toUpperCase() : '?',
                        style: _f(13, w: FontWeight.w800, c: _C.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.nombre,
                              style: _f(12, w: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text('${_fmtMonedaCorta(c.planValor)} / mes',
                              style: _f(10, c: _C.textSec)),
                        ]),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: (c.status == 'mora' ? _C.expense : _C.income)
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(c.status == 'mora' ? 'Mora' : 'Por pagar',
                        style: _f(9,
                            w: FontWeight.w800,
                            c: c.status == 'mora' ? _C.expense : _C.income)),
                  ),
                ]),
              )),
        ],
        if (recientes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(height: 1, color: _C.border),
          const SizedBox(height: 10),
          Text('Últimos cobros registrados',
              style: _f(11.5, w: FontWeight.w800)),
          const SizedBox(height: 4),
          ...recientes.map((m) {
            final nombre = m.descripcion.replaceFirst('Pago de cliente · ', '');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _C.income.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: _C.income, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nombre,
                            style: _f(12, w: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(
                            '${m.fecha.day} ${_mesesCortos[m.fecha.month - 1]} · Pago registrado',
                            style: _f(9.5, c: _C.textTer)),
                      ]),
                ),
                Text('+${_fmtMonedaCorta(m.monto)}',
                    style: _f(12.5, w: FontWeight.w800, c: _C.income)),
              ]),
            );
          }),
        ],
      ]),
    ).animate().fadeIn(duration: 260.ms);
  }
}

class _MetroCobro extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final Color color;
  const _MetroCobro({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Flexible(
                child: Text(label,
                    style: _f(9, w: FontWeight.w600, c: _C.textSec),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 4),
          Text(_fmtMonedaCorta(value),
              style: _f(13, w: FontWeight.w800, c: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

class _LoadingFinanzas extends StatelessWidget {
  const _LoadingFinanzas();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: _C.primary, strokeWidth: 2.6),
          SizedBox(height: 14),
          Text('Cargando tus finanzas...',
              style: TextStyle(color: _C.textSec, fontSize: 13)),
        ]),
      );
}

class _CardSeccion extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String? subtitulo;
  final Color color;
  final Widget child;
  const _CardSeccion({
    required this.icon,
    required this.titulo,
    required this.color,
    required this.child,
    this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: _cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: _f(13.5, w: FontWeight.w800)),
              if (subtitulo != null && subtitulo!.isNotEmpty)
                Text(subtitulo!, style: _f(10.5, c: _C.textTer)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

class _MesSelector extends StatelessWidget {
  final int anio;
  final int mes;
  final bool esActual;
  final bool puedeAvanzar;
  final VoidCallback onAnterior;
  final VoidCallback onSiguiente;
  final VoidCallback onHoy;

  const _MesSelector({
    required this.anio,
    required this.mes,
    required this.esActual,
    required this.puedeAvanzar,
    required this.onAnterior,
    required this.onSiguiente,
    required this.onHoy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: _cardDecoration(borderColor: _C.border, radius: 18),
      child: Row(children: [
        IconButton(
          onPressed: onAnterior,
          icon: const Icon(Icons.chevron_left_rounded,
              color: _C.textPri, size: 28),
          tooltip: 'Mes anterior',
        ),
        Expanded(
          child: InkWell(
            onTap: esActual ? null : onHoy,
            borderRadius: BorderRadius.circular(12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${_mesesLargos[mes - 1]}',
                    style: _f(15, w: FontWeight.w800)),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _C.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$anio',
                      style: _f(12, w: FontWeight.w700, c: _C.primary)),
                ),
              ]),
              const SizedBox(height: 2),
              Text(
                esActual
                    ? 'Mes actual · toca para hoy'
                    : 'Toca para volver al mes actual',
                style: _f(9.5, c: _C.textTer),
              ),
            ]),
          ),
        ),
        IconButton(
          onPressed: puedeAvanzar ? onSiguiente : null,
          icon: const Icon(Icons.chevron_right_rounded,
              color: _C.textPri, size: 28),
          tooltip: 'Mes siguiente',
        ),
      ]),
    );
  }
}

// ── TARJETA HERO: BALANCE ────────────────────────────────────────────────────
class _HeroBalance extends StatelessWidget {
  final double balanceMes,
      ingresosMes,
      gastosMes,
      saldoTotal,
      totalIngresos,
      totalGastos;
  final int movimientosMes;
  const _HeroBalance({
    required this.balanceMes,
    required this.ingresosMes,
    required this.gastosMes,
    required this.movimientosMes,
    required this.saldoTotal,
    required this.totalIngresos,
    required this.totalGastos,
  });

  @override
  Widget build(BuildContext context) {
    final positivo = balanceMes >= 0;
    final ok = saldoTotal >= 0;
    final chipColor = positivo ? _C.income : _C.expense;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF0B1220), Color(0xFF16233C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0B1220).withOpacity(0.28),
              blurRadius: 18,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text('Balance del mes',
              style: _f(13, w: FontWeight.w600, c: Colors.white70)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
                color: chipColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: chipColor.withOpacity(0.4))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  positivo
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 13,
                  color: chipColor),
              const SizedBox(width: 4),
              Text(positivo ? 'SUPERÁVIT' : 'DÉFICIT',
                  style: _f(9.5, w: FontWeight.w800, c: chipColor)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(_fmtMoneda(balanceMes),
              key: ValueKey('${balanceMes.toStringAsFixed(0)}_$positivo'),
              style: _f(30, w: FontWeight.w800, c: Colors.white)),
        ),
        const SizedBox(height: 4),
        Text(
            '$movimientosMes movimiento${movimientosMes == 1 ? '' : 's'} en el mes',
            style: _f(11.5, c: Colors.white54)),
        const SizedBox(height: 18),
        Row(children: [
          _HeroMini(
              icon: Icons.arrow_downward_rounded,
              label: 'Ingresos mes',
              value: ingresosMes,
              color: _C.income),
          const SizedBox(width: 8),
          _HeroMini(
              icon: Icons.arrow_upward_rounded,
              label: 'Gastos mes',
              value: gastosMes,
              color: _C.expense),
        ]),
        const SizedBox(height: 14),
        // ── Balance acumulado de todo el historial ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08))),
          child: Row(children: [
            const Icon(Icons.savings_rounded,
                color: Color(0xFF00C6AE), size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Balance acumulado (todo tu historial)',
                        style: _f(10.5, c: Colors.white60)),
                    Text(_fmtMoneda(saldoTotal),
                        style: _f(16,
                            w: FontWeight.w800,
                            c: ok
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFF87171))),
                  ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Ingresos ${_fmtMonedaCorta(totalIngresos)}',
                  style: _f(9.5, c: Colors.white60)),
              Text('Gastos ${_fmtMonedaCorta(totalGastos)}',
                  style: _f(9.5, c: Colors.white60)),
            ]),
          ]),
        ),
      ]),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _HeroMini extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final Color color;
  const _HeroMini(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: _f(9.5, c: Colors.white54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(_fmtMonedaCorta(value),
                  style: _f(13, w: FontWeight.w800, c: Colors.white)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── GRÁFICA DE BARRAS: INGRESOS VS GASTOS (6 MESES) ──────────────────────────
class _BarrasIngresosGastos extends StatelessWidget {
  final List<_ResumenMes> datos;
  const _BarrasIngresosGastos({required this.datos});

  @override
  Widget build(BuildContext context) {
    double maxV = 1;
    for (final d in datos) {
      if (d.ingresos > maxV) maxV = d.ingresos;
      if (d.gastos > maxV) maxV = d.gastos;
    }
    final escala = maxV <= 0 ? 1.0 : maxV * 1.12;
    final hayDatos = datos.any((d) => d.ingresos > 0 || d.gastos > 0);
    if (!hayDatos) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Center(
          child: Column(children: [
            const Icon(Icons.bar_chart_rounded, color: _C.textTer, size: 30),
            const SizedBox(height: 8),
            Text('Aún no hay movimientos en este rango',
                style: _f(12, c: _C.textSec), textAlign: TextAlign.center),
          ]),
        ),
      );
    }
    return Column(children: [
      SizedBox(
        height: 148,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: datos.map((d) {
            final fi = (d.ingresos / escala).clamp(0.0, 1.0);
            final fg = (d.gastos / escala).clamp(0.0, 1.0);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child:
                    Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (d.ingresos > 0 || d.gastos > 0)
                    Text(
                        d.balance == 0
                            ? '·'
                            : (d.balance > 0 ? '+' : '') +
                                _fmtMonedaCorta(d.balance),
                        style: _f(8.5,
                            w: FontWeight.w700,
                            c: d.balance >= 0 ? _C.income : _C.expense),
                        maxLines: 1),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _barraAnimada(fi, _C.primary, 'Ingresos'),
                      const SizedBox(width: 3),
                      _barraAnimada(fg, _C.expense, 'Gastos'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${_mesesCortos[d.mes - 1]}',
                      style: _f(9.5, w: FontWeight.w700, c: _C.textSec)),
                ]),
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 6),
      Container(height: 1, color: _C.border),
      const SizedBox(height: 10),
      Row(children: [
        _Leyenda(color: _C.primary, texto: 'Ingresos'),
        const SizedBox(width: 14),
        _Leyenda(color: _C.expense, texto: 'Gastos'),
        const Spacer(),
        Text(
            'Balance 6m: ${_fmtMonedaCorta(datos.fold(0.0, (s, d) => s + d.balance))}',
            style: _f(10, w: FontWeight.w700, c: _C.textSec)),
      ]),
    ]);
  }

  Widget _barraAnimada(double frac, Color color, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 11,
        height: 112,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: frac),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Container(
              height: 112 * v,
              decoration: BoxDecoration(
                color: color,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(5)),
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.75)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  final Color color;
  final String texto;
  const _Leyenda({required this.color, required this.texto});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(texto, style: _f(10.5, c: _C.textSec)),
      ]);
}

// ── GRÁFICA DE LÍNEA: BALANCE MES A MES ──────────────────────────────────────
class _LineaBalance extends StatelessWidget {
  final List<_ResumenMes> datos;
  const _LineaBalance({required this.datos});

  @override
  Widget build(BuildContext context) {
    final valores = datos.map((d) => d.balance).toList();
    final tieneDatos = valores.any((v) => v != 0);
    final ultimo = valores.isEmpty ? 0.0 : valores.last;
    return Column(children: [
      SizedBox(
        height: 190,
        child: CustomPaint(
          size: Size.infinite,
          painter: _LineaPainter(
              valores, datos.map((d) => _mesesCortos[d.mes - 1]).toList()),
        ),
      ),
      const SizedBox(height: 2),
      Container(height: 1, color: _C.border),
      const SizedBox(height: 10),
      Row(children: [
        _Leyenda(color: _C.purple, texto: 'Resultado neto del mes'),
        const Spacer(),
        Text('Último: ${_fmtMonedaCorta(ultimo)}',
            style: _f(10.5,
                w: FontWeight.w800, c: ultimo >= 0 ? _C.income : _C.expense)),
      ]),
      if (!tieneDatos) ...[
        const SizedBox(height: 4),
        Text('Sin movimientos registrados en los últimos 6 meses',
            style: _f(10.5, c: _C.textTer)),
      ],
    ]);
  }
}

class _LineaPainter extends CustomPainter {
  final List<double> vals;
  final List<String> labels;
  _LineaPainter(this.vals, this.labels);

  @override
  void paint(Canvas canvas, Size size) {
    final labelH = 26.0;
    final h = size.height - labelH;
    final padT = 14.0;
    final padB = 8.0;
    final chartH = h - padT - padB;
    final w = size.width;

    if (vals.isEmpty) return;

    var minV = 0.0;
    var maxV = 0.0;
    for (final v in vals) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    if (maxV == minV) {
      maxV = maxV == 0 ? 1 : maxV.abs();
      minV = minV == 0 ? 0 : -minV.abs();
      if (maxV == minV) maxV = 1;
    }
    final span = maxV - minV;

    double xFor(int i) =>
        vals.length == 1 ? w / 2 : i * (w / (vals.length - 1));
    double yFor(double v) => padT + (1 - (v - minV) / span) * chartH;

    // Líneas guía
    final gridPaint = Paint()
      ..color = _C.border
      ..strokeWidth = 1;
    for (int g = 0; g <= 2; g++) {
      final v = minV + span * (g / 2);
      final y = yFor(v);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Línea del cero
    if (minV < 0 && maxV > 0) {
      final y0 = yFor(0);
      final dashPaint = Paint()
        ..color = _C.textTer.withOpacity(0.5)
        ..strokeWidth = 1.2;
      for (double x = 0; x < w; x += 12) {
        canvas.drawLine(
            Offset(x, y0), Offset(math.min(x + 6, w), y0), dashPaint);
      }
    }

    // Polilínea
    final linePath = Path();
    for (int i = 0; i < vals.length; i++) {
      final o = Offset(xFor(i), yFor(vals[i]));
      if (i == 0) {
        linePath.moveTo(o.dx, o.dy);
      } else {
        linePath.lineTo(o.dx, o.dy);
      }
    }

    // Relleno degradado bajo la curva
    if (vals.length > 1) {
      final fillPath = Path.from(linePath)
        ..lineTo(xFor(vals.length - 1), padT + chartH)
        ..lineTo(xFor(0), padT + chartH)
        ..close();
      final fill = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x557C3AED), Color(0x007C3AED)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, padT, w, chartH));
      canvas.drawPath(fillPath, fill);
    }

    final stroke = Paint()
      ..color = const Color(0xFF7C3AED)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, stroke);

    // Puntos
    for (int i = 0; i < vals.length; i++) {
      final o = Offset(xFor(i), yFor(vals[i]));
      canvas.drawCircle(o, 4.4, Paint()..color = _C.surface);
      canvas.drawCircle(o, 3.0, Paint()..color = const Color(0xFF7C3AED));
    }

    // Etiquetas de meses abajo
    for (int i = 0; i < vals.length && i < labels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
            text: labels[i], style: _f(9.5, w: FontWeight.w700, c: _C.textSec)),
        textDirection: TextDirection.ltr,
      )..layout();
      var x = xFor(i) - tp.width / 2;
      x = x.clamp(0.0, math.max(0.0, size.width - tp.width));
      tp.paint(canvas, Offset(x, padT + chartH + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _LineaPainter old) =>
      old.vals.length != vals.length ||
      (vals.isNotEmpty && old.vals.first != vals.first) ||
      (labels.isNotEmpty && old.labels.first != labels.first);
}

// ── DONA: GASTOS POR CATEGORÍA ───────────────────────────────────────────────
class _Slice {
  final String categoria;
  final double valor;
  final Color color;
  const _Slice(this.categoria, this.valor, this.color);
}

class _DonaGastos extends StatelessWidget {
  final List<_Movimiento> movs;
  const _DonaGastos({required this.movs});

  @override
  Widget build(BuildContext context) {
    final porCat = <String, double>{};
    for (final m in movs) {
      if (m.esIngreso) continue;
      porCat[m.categoria] = (porCat[m.categoria] ?? 0) + m.monto;
    }
    final total = porCat.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: Column(children: [
            const Icon(Icons.donut_large_rounded, color: _C.textTer, size: 30),
            const SizedBox(height: 8),
            Text('Sin gastos en este mes 🎉', style: _f(12, c: _C.textSec)),
          ]),
        ),
      );
    }
    final entradas = porCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final slices = entradas
        .map((e) => _Slice(e.key, e.value, _colorCategoria('gasto', e.key)))
        .toList();
    final visibles = slices.take(5).toList();
    final resto = slices.length > 5
        ? slices.skip(5).fold<double>(0, (s, sl) => s + sl.valor)
        : 0.0;

    return Column(children: [
      Row(children: [
        SizedBox(
          width: 140,
          height: 140,
          child: CustomPaint(
            painter: _DonaPainter(slices, total),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_fmtMonedaCorta(total),
                    style: _f(18, w: FontWeight.w800, c: _C.textPri)),
                Text('gastado', style: _f(9.5, c: _C.textTer)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              ...visibles.map((sl) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                              color: sl.color,
                              borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 7),
                      Expanded(
                          child: Text(sl.categoria,
                              style: _f(10.5, c: _C.textPri),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                      Text(_fmtMonedaCorta(sl.valor),
                          style: _f(10, w: FontWeight.w800, c: _C.textSec)),
                      const SizedBox(width: 5),
                      SizedBox(
                        width: 40,
                        child: Text(
                            '${((sl.valor / total) * 100).toStringAsFixed(0)}%',
                            style: _f(9.5, w: FontWeight.w700, c: _C.textTer),
                            textAlign: TextAlign.right),
                      ),
                    ]),
                  )),
              if (resto > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                            color: _C.textTer,
                            borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 7),
                    Expanded(
                        child: Text('Otros (${slices.length - 5})',
                            style: _f(10.5, c: _C.textSec),
                            overflow: TextOverflow.ellipsis)),
                    Text(_fmtMonedaCorta(resto),
                        style: _f(10, w: FontWeight.w800, c: _C.textSec)),
                  ]),
                ),
            ],
          ),
        ),
      ]),
    ]);
  }
}

class _DonaPainter extends CustomPainter {
  final List<_Slice> slices;
  final double total;
  _DonaPainter(this.slices, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radio = math.min(size.width, size.height) / 2 - 12;
    const grosor = 17.0;

    // Fondo sutil (anillo)
    canvas.drawCircle(
      center,
      radio,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor
        ..color = _C.border.withOpacity(0.55),
    );

    if (total <= 0 || slices.isEmpty) return;

    var start = -math.pi / 2;
    for (int i = 0; i < slices.length; i++) {
      final sl = slices[i];
      final sweep = (sl.valor / total) * 2 * math.pi;
      // Reserva un pequeño espacio entre segmentos
      final gap = slices.length > 1 ? 0.045 : 0.0;
      final usable = math.max(0.0, sweep - gap);
      if (usable <= 0.0001) {
        start += sweep;
        continue;
      }
      final rect = Rect.fromCircle(center: center, radius: radio);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor
        ..color = sl.color
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start + gap / 2, usable, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonaPainter old) =>
      old.total != total || old.slices.length != slices.length;
}

// ── LISTA DE MOVIMIENTOS ─────────────────────────────────────────────────────
class _HeaderListaMovimientos extends StatelessWidget {
  final int anio, mes, count;
  final double totalMes;
  const _HeaderListaMovimientos({
    required this.anio,
    required this.mes,
    required this.count,
    required this.totalMes,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
            color: _C.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10)),
        child:
            const Icon(Icons.receipt_long_rounded, color: _C.primary, size: 17),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Movimientos · ${_mesesLargos[mes - 1]} $anio',
              style: _f(14, w: FontWeight.w800)),
          Text(
              '$count movimiento${count == 1 ? '' : 's'} · Neto ${_fmtMonedaCorta(totalMes)}',
              style: _f(10.5, c: _C.textTer)),
        ]),
      ),
      const SizedBox(width: 8),
    ]);
  }
}

class _SinMovimientos extends StatelessWidget {
  final int anio, mes;
  final VoidCallback onAgregar;
  const _SinMovimientos(
      {required this.anio, required this.mes, required this.onAgregar});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
      decoration: _cardDecoration(),
      child: Column(children: [
        const Icon(Icons.inbox_rounded, color: _C.textTer, size: 34),
        const SizedBox(height: 10),
        Text('Sin movimientos en ${_mesesLargos[mes - 1]} $anio',
            style: _f(13, w: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Registra tus ingresos y gastos para llevar el control.',
            style: _f(11, c: _C.textSec), textAlign: TextAlign.center),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onAgregar,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Nuevo movimiento'),
          style: OutlinedButton.styleFrom(foregroundColor: _C.primary),
        ),
      ]),
    );
  }
}

class _BienvenidaFinanzas extends StatelessWidget {
  final VoidCallback onAgregar;
  const _BienvenidaFinanzas({required this.onAgregar});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 22),
      decoration: _cardDecoration(),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF1A73E8), Color(0xFF00C6AE)]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.account_balance_wallet_rounded,
              color: Colors.white, size: 40),
        ),
        const SizedBox(height: 16),
        Text('¡Bienvenido a Mis Finanzas!', style: _f(17, w: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          'Lleva el control total de tu dinero: registra cuánto entra (ingresos) y cuánto sale (gastos) cada mes, '
          'mira tu balance y analízalo con gráficos.',
          style: _f(12, c: _C.textSec, h: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A73E8).withOpacity(0.08),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_rounded, size: 14, color: _C.primary),
            const SizedBox(width: 6),
            Text('Tus datos se guardan de forma segura en tu cuenta',
                style: _f(10.5, c: _C.primary)),
          ]),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 48,
          width: 220,
          child: ElevatedButton.icon(
            onPressed: onAgregar,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Registrar mi primer movimiento'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── GRUPO POR DÍA DE MOVIMIENTOS ─────────────────────────────────────────────
String _diaLeyenda(DateTime f) {
  final hoy = DateTime.now();
  final h = DateTime(hoy.year, hoy.month, hoy.day);
  final d = DateTime(f.year, f.month, f.day);
  if (d == h) return 'Hoy';
  final ayer = h.subtract(const Duration(days: 1));
  if (d == ayer) return 'Ayer';
  return '${d.day} de ${_mesesLargos[d.month - 1]}';
}

class _GrupoDia extends StatelessWidget {
  final DateTime fecha;
  final List<_Movimiento> items;
  final void Function(_Movimiento) onEditar;
  final void Function(_Movimiento) onEliminar;
  const _GrupoDia({
    required this.fecha,
    required this.items,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final total =
        items.fold<double>(0, (s, m) => s + (m.esIngreso ? m.monto : -m.monto));
    final thisYear = fecha.year != DateTime.now().year;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: _cardDecoration(radius: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 6),
          child: Row(children: [
            Text('${_diaLeyenda(fecha)}${thisYear ? ' · ${fecha.year}' : ''}',
                style: _f(12, w: FontWeight.w800, c: _C.textSec)),
            const Spacer(),
            Text(
                total == 0
                    ? 'Equilibrado'
                    : (total > 0 ? '+' : '') + _fmtMonedaCorta(total),
                style: _f(11,
                    w: FontWeight.w800,
                    c: total >= 0 ? _C.income : _C.expense)),
          ]),
        ),
        ...items.map((m) => _MovimientoTile(
            mov: m, onTap: () => onEditar(m), onDelete: () => onEliminar(m))),
      ]),
    );
  }
}

class _MovimientoTile extends StatelessWidget {
  final _Movimiento mov;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _MovimientoTile(
      {required this.mov, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = mov.esIngreso ? _C.income : _C.expense;
    final catColor = _colorCategoria(mov.tipo, mov.categoria);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: catColor.withOpacity(0.13),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(_iconoCategoria(mov.tipo, mov.categoria),
                size: 18, color: catColor),
          ),
          const SizedBox(width: 11),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(mov.descripcion,
                  style: _f(12.5, w: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 1),
              Text(mov.categoria,
                  style: _f(10, c: _C.textTer),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${mov.esIngreso ? '+' : '-'}${_fmtMonedaCorta(mov.monto)}',
                style: _f(12.5, w: FontWeight.w800, c: color)),
            Text(
                '${mov.fecha.hour.toString().padLeft(2, '0')}:${mov.fecha.minute.toString().padLeft(2, '0')}',
                style: _f(9, c: _C.textTer)),
          ]),
          const SizedBox(width: 2),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: _C.textTer),
            tooltip: 'Eliminar',
            visualDensity: VisualDensity.compact,
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  FORMULARIO — REGISTRAR / EDITAR MOVIMIENTO
// ═══════════════════════════════════════════════════════════════════════════
class _MovimientoSheet extends StatefulWidget {
  final _Movimiento? existente;
  const _MovimientoSheet({this.existente});

  @override
  State<_MovimientoSheet> createState() => _MovimientoSheetState();
}

class _MovimientoSheetState extends State<_MovimientoSheet> {
  late String _tipo;
  late TextEditingController _montoCtrl;
  late TextEditingController _descCtrl;
  String? _categoria;
  late DateTime _fecha;

  List<String> get _cats =>
      _tipo == 'ingreso' ? _categoriasIngreso : _categoriasGasto;
  bool get _editando => widget.existente != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    _tipo = e?.tipo ?? 'gasto';
    _categoria = e?.categoria;
    _fecha = e?.fecha ?? DateTime.now();
    _montoCtrl = TextEditingController(
        text: e == null
            ? ''
            : (e.monto % 1 == 0
                ? e.monto.toStringAsFixed(0)
                : e.monto.toString()));
    _descCtrl = TextEditingController(text: e?.descripcion ?? '');
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _elegirTipo(String t) {
    if (_tipo == t) return;
    setState(() {
      _tipo = t;
      if (!_cats.contains(_categoria)) _categoria = null;
    });
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    var ultima = ahora;
    if (widget.existente != null && widget.existente!.fecha.isAfter(ahora)) {
      ultima = widget.existente!.fecha;
    }
    final sel = await showDatePicker(
      context: context,
      initialDate: _fecha.isAfter(ultima) ? ultima : _fecha,
      firstDate: DateTime(2000),
      lastDate: ultima,
      helpText: 'Fecha del movimiento',
      cancelText: 'Cancelar',
      confirmText: 'OK',
      locale: const Locale('es'),
    );
    if (sel != null) setState(() => _fecha = sel);
  }

  void _guardar() {
    FocusScope.of(context).unfocus();
    final monto = _parseMontoInput(_montoCtrl.text);
    final desc = _descCtrl.text.trim();

    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('⚠️ Ingresa un monto válido mayor a 0')));
      return;
    }
    if (_categoria == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Selecciona una categoría')));
      return;
    }
    Navigator.pop(
      context,
      _DraftMovimiento(
        id: widget.existente?.id,
        tipo: _tipo,
        monto: monto,
        descripcion:
            desc.isEmpty ? (_tipo == 'ingreso' ? 'Ingreso' : 'Gasto') : desc,
        categoria: _categoria!,
        fecha: DateTime(
            _fecha.year, _fecha.month, _fecha.day, _fecha.hour, _fecha.minute),
      ),
    );
  }

  Widget _buildTipoSelector() {
    return Row(children: [
      Expanded(
        child: _TipoBtn(
          tipo: 'ingreso',
          activo: _tipo == 'ingreso',
          icono: Icons.arrow_downward_rounded,
          color: _C.income,
          label: 'Ingreso',
          onTap: () => _elegirTipo('ingreso'),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _TipoBtn(
          tipo: 'gasto',
          activo: _tipo == 'gasto',
          icono: Icons.arrow_upward_rounded,
          color: _C.expense,
          label: 'Gasto',
          onTap: () => _elegirTipo('gasto'),
        ),
      ),
    ]);
  }

  Widget _campoMonto() {
    final pre = _parseMontoInput(_montoCtrl.text);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Row(children: [
          Text('Monto (COP)', style: _f(11, w: FontWeight.w700, c: _C.textSec)),
          if (pre != null && pre > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (_tipo == 'ingreso' ? _C.income : _C.expense)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_fmtMoneda(pre),
                  style: _f(10.5,
                      w: FontWeight.w800,
                      c: _tipo == 'ingreso' ? _C.income : _C.expense)),
            ),
          ],
        ]),
      ),
      TextField(
        controller: _montoCtrl,
        onChanged: (_) => setState(() {}),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: _f(16, w: FontWeight.w700, c: _C.textPri),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
        ],
        decoration: _decInput(
          hint: 'Ej: 500.000',
          icon: Icons.payments_rounded,
          color: _tipo == 'ingreso' ? _C.income : _C.expense,
        ),
      ),
    ]);
  }

  Widget _campoDescripcion() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text('Descripción',
            style: _f(11, w: FontWeight.w700, c: _C.textSec)),
      ),
      TextField(
        controller: _descCtrl,
        textCapitalization: TextCapitalization.sentences,
        maxLength: 60,
        style: _f(14, c: _C.textPri),
        decoration: _decInput(
          hint: 'Ej: Pago de clientes, mercado, plan de datos...',
          icon: Icons.notes_rounded,
          color: _C.primary,
          counter: const Offstage(),
        ),
      ),
    ]);
  }

  InputDecoration _decInput({
    required String hint,
    required IconData icon,
    required Color color,
    Widget? counter,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: _f(13, c: _C.textTer),
      counter: counter,
      prefixIcon: Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, color: color, size: 18),
      ),
      filled: true,
      fillColor: _C.surfaceDim,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _C.border, width: 1.2),
        borderRadius: BorderRadius.circular(14),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: color, width: 1.8),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Widget _campoFecha() {
    final colorTipo = _tipo == 'ingreso' ? _C.income : _C.expense;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text('Fecha', style: _f(11, w: FontWeight.w700, c: _C.textSec)),
      ),
      InkWell(
        onTap: _elegirFecha,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _C.surfaceDim,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border, width: 1.2),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: colorTipo.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(Icons.calendar_month_rounded,
                  color: colorTipo, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${_fecha.day} de ${_mesesLargos[_fecha.month - 1]} de ${_fecha.year}',
                style: _f(13.5, w: FontWeight.w600, c: _C.textPri),
              ),
            ),
            const Icon(Icons.edit_calendar_rounded,
                color: _C.textTer, size: 17),
          ]),
        ),
      ),
    ]);
  }

  Widget _campoCategorias() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child:
            Text('Categoría', style: _f(11, w: FontWeight.w700, c: _C.textSec)),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _cats.map((cat) {
          final activa = _categoria == cat;
          final col = _colorCategoria(_tipo, cat);
          return ChoiceChip(
            label: Text(cat,
                style: _f(11.5,
                    w: FontWeight.w600, c: activa ? Colors.white : _C.textPri)),
            selected: activa,
            onSelected: (_) => setState(() => _categoria = cat),
            selectedColor: col,
            backgroundColor: _C.surfaceDim,
            checkmarkColor: Colors.white,
            showCheckmark: false,
            side: BorderSide(
              color: activa ? col : _C.border,
              width: 1.2,
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          );
        }).toList(),
      ),
    ]);
  }

  Widget _botonGuardar() {
    final color = _tipo == 'ingreso' ? _C.income : _C.expense;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _guardar,
        icon:
            Icon(_editando ? Icons.check_rounded : Icons.add_rounded, size: 20),
        label: Text(
            _editando ? 'Actualizar movimiento' : 'Registrar movimiento',
            style: _f(14, w: FontWeight.w800, c: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _C.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _C.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      _editando ? Icons.edit_rounded : Icons.add_card_rounded,
                      color: _C.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              _editando
                                  ? 'Editar movimiento'
                                  : 'Nuevo movimiento',
                              style: _f(16, w: FontWeight.w800)),
                          Text(
                              _editando
                                  ? 'Corrige los datos del registro'
                                  : 'Registra un ingreso o un gasto',
                              style: _f(10.5, c: _C.textTer)),
                        ]),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: _C.textSec),
                    tooltip: 'Cerrar',
                  ),
                ]),
                const SizedBox(height: 18),
                _buildTipoSelector(),
                const SizedBox(height: 18),
                _campoMonto(),
                const SizedBox(height: 16),
                _campoDescripcion(),
                const SizedBox(height: 12),
                _campoFecha(),
                const SizedBox(height: 18),
                _campoCategorias(),
                const SizedBox(height: 24),
                _botonGuardar(),
                const SizedBox(height: 4),
              ]),
        ),
      ),
    );
  }
}

class _TipoBtn extends StatelessWidget {
  final String tipo;
  final bool activo;
  final IconData icono;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _TipoBtn({
    required this.tipo,
    required this.activo,
    required this.icono,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: activo ? color.withOpacity(0.14) : _C.surfaceDim,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
            color: activo ? color : _C.border, width: activo ? 1.6 : 1.2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, color: activo ? color : _C.textTer, size: 19),
              const SizedBox(width: 8),
              Text(label,
                  style: _f(13.5,
                      w: FontWeight.w800, c: activo ? color : _C.textSec)),
            ],
          ),
        ),
      ),
    );
  }
}
