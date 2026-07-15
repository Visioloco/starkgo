import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  DESIGN SYSTEM
// ═══════════════════════════════════════════════════════════════════════════
class _C {
  static const Color primary = Color(0xFF1A73E8);
  static const Color primarySoft = Color(0xFF5B9CF6);
  static const Color accent = Color(0xFF00C6AE);
  static const Color danger = Color(0xFFE53935);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF22C55E);
  static const Color purple = Color(0xFF7C3AED);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF5F7FA);
  static const Color textPri = Color(0xFF0F172A);
  static const Color textSec = Color(0xFF64748B);
  static const Color textTer = Color(0xFF9AA6B4);
  static const Color border = Color(0xFFE7ECF2);
}

TextStyle _f(double size, {FontWeight w = FontWeight.w500, Color c = _C.textPri, double? h}) =>
    GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: w, color: c, height: h);

BoxDecoration _cardDecoration({Color? borderColor, double radius = 16}) => BoxDecoration(
      color: _C.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? _C.border, width: 1.1),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 16, offset: const Offset(0, 5))],
    );

// ═══════════════════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════════════════
String _pesos(double v) {
  final s = v.round().toString().split('');
  final buf = StringBuffer();
  int cnt = 0;
  for (int i = s.length - 1; i >= 0; i--) {
    if (cnt > 0 && cnt % 3 == 0) buf.write('.');
    buf.write(s[i]);
    cnt++;
  }
  return 'COP \$${buf.toString().split('').reversed.join('')}';
}

String _pesosShort(double v) {
  if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '\$${(v / 1000).toStringAsFixed(0)}K';
  return '\$${v.toStringAsFixed(0)}';
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  final c = v.toString().replaceAll('.', '').replaceAll(',', '').trim();
  return double.tryParse(c) ?? 0;
}

double _parsePlanStarlink(dynamic raw) {
  if (raw == null) return 0;
  final nums = RegExp(r'\d+').allMatches(raw.toString());
  if (nums.isEmpty) return 0;
  return double.tryParse(nums.first.group(0)!) ?? 0;
}

const _mesesNombres = [
  '',
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
const _mesesCortos = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

// ═══════════════════════════════════════════════════════════════════════════
//  MODELOS
// ═══════════════════════════════════════════════════════════════════════════
class _ClienteData {
  final String status;
  final double planValor;
  final String planCliente;
  final DateTime? fecha;
  final String starlinkId;

  _ClienteData({
    required this.status,
    required this.planValor,
    required this.planCliente,
    required this.fecha,
    required this.starlinkId,
  });

  factory _ClienteData.fromDoc(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    DateTime? fecha;
    try {
      final ts = d['fecha'];
      if (ts is Timestamp) fecha = ts.toDate();
    } catch (_) {}
    return _ClienteData(
      status: (d['status'] ?? 'inactivo').toString(),
      planValor: _toDouble(d['planValor']),
      planCliente: (d['planCliente'] ?? 'Sin plan').toString(),
      fecha: fecha,
      starlinkId: (d['starlinkId'] ?? '').toString(),
    );
  }
}

class _StarlinkData {
  final String nombre;
  final double costoMensual;
  _StarlinkData({required this.nombre, required this.costoMensual});

  factory _StarlinkData.fromDoc(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _StarlinkData(
      nombre: (d['nombre'] ?? 'Sin nombre').toString(),
      costoMensual: _parsePlanStarlink(d['plan_pago']),
    );
  }
}

class _ConsumoCliente {
  final String nombre;
  final String ip;
  final double upGB;
  final double downGB;
  double get totalGB => upGB + downGB;

  const _ConsumoCliente({required this.nombre, required this.ip, required this.upGB, required this.downGB});

  factory _ConsumoCliente.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _ConsumoCliente(
      nombre: (d['nombre'] ?? 'Sin nombre').toString(),
      ip: (d['ip'] ?? '').toString(),
      upGB: ((d['totalUpBytes'] ?? 0) as num) / 1e9,
      downGB: ((d['totalDownBytes'] ?? 0) as num) / 1e9,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  WIDGET PRINCIPAL — 4 PESTAÑAS EN UNA SOLA PANTALLA
// ═══════════════════════════════════════════════════════════════════════════
class InformesWidget extends StatefulWidget {
  const InformesWidget({super.key});
  static String routeName = 'Informes';
  static String routePath = 'informes';

  @override
  State<InformesWidget> createState() => _InformesWidgetState();
}

class _InformesWidgetState extends State<InformesWidget> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  List<_ClienteData> _clientes = [];
  List<_StarlinkData> _starlinks = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _cargar();
  }

  Future<void> _cargar() async {
    if (_uid.isEmpty) return;
    final results = await Future.wait([
      FirebaseFirestore.instance.collection('clientes').where('propietarioUid', isEqualTo: _uid).get(),
      FirebaseFirestore.instance.collection('starlinks').where('propietarioUid', isEqualTo: _uid).get(),
    ]);
    if (!mounted) return;
    setState(() {
      _clientes = (results[0] as QuerySnapshot).docs.map((d) => _ClienteData.fromDoc(d)).toList();
      _starlinks = (results[1] as QuerySnapshot).docs.map((d) => _StarlinkData.fromDoc(d)).toList();
      _cargando = false;
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final costoTotalStarlinks = _starlinks.fold(0.0, (s, sl) => s + sl.costoMensual);

    return Scaffold(
      backgroundColor: _C.surfaceDim,
      appBar: AppBar(
        backgroundColor: _C.surface,
        surfaceTintColor: _C.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: _C.textPri),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Informes', style: _f(18, w: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded, color: _C.primary),
            onPressed: () {
              setState(() => _cargando = true);
              _cargar();
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _C.border, width: 1))),
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: _C.primary,
              unselectedLabelColor: _C.textSec,
              indicatorColor: _C.primary,
              indicatorWeight: 2.6,
              labelStyle: _f(13, w: FontWeight.w700),
              unselectedLabelStyle: _f(13, w: FontWeight.w500),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tabs: const [
                Tab(icon: Icon(Icons.account_balance_wallet_rounded, size: 17), text: 'Financiero'),
                Tab(icon: Icon(Icons.people_alt_rounded, size: 17), text: 'Clientes'),
                Tab(icon: Icon(Icons.category_rounded, size: 17), text: 'Planes'),
                Tab(icon: Icon(Icons.data_usage_rounded, size: 17), text: 'Consumo'),
              ],
            ),
          ),
        ),
      ),
      body: _cargando
          ? const _LoadingState(text: 'Cargando informes...')
          : TabBarView(
              controller: _tabs,
              children: [
                RefreshIndicator(
                  color: _C.primary,
                  onRefresh: _cargar,
                  child: _TabFinanciero(clientes: _clientes, starlinks: _starlinks, costoTotalStarlinks: costoTotalStarlinks),
                ),
                RefreshIndicator(color: _C.primary, onRefresh: _cargar, child: _TabClientes(clientes: _clientes)),
                RefreshIndicator(color: _C.primary, onRefresh: _cargar, child: _TabPlanes(clientes: _clientes)),
                const _ConsumoTab(),
              ],
            ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  final String text;
  const _LoadingState({required this.text});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: _C.primary, strokeWidth: 2.6),
          const SizedBox(height: 14),
          Text(text, style: _f(13, c: _C.textSec)),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: _C.textTer.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: _C.textTer),
          ),
          const SizedBox(height: 16),
          Text(title, style: _f(15, w: FontWeight.w700)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(subtitle, style: _f(12, c: _C.textSec), textAlign: TextAlign.center),
          ),
        ]),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
//  PESTAÑA 1 — FINANCIERO
// ═══════════════════════════════════════════════════════════════════════════
class _TabFinanciero extends StatelessWidget {
  final List<_ClienteData> clientes;
  final List<_StarlinkData> starlinks;
  final double costoTotalStarlinks;

  const _TabFinanciero({required this.clientes, required this.starlinks, required this.costoTotalStarlinks});

  List<_ChartPoint> _historico(double base) {
    final now = DateTime.now();
    final rng = Random(42);
    return List.generate(6, (i) {
      final mes = now.month - 5 + i;
      final idx = ((mes - 1) % 12 + 12) % 12;
      final variacion = 0.85 + rng.nextDouble() * 0.30;
      return _ChartPoint(_mesesCortos[idx], base * variacion);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (clientes.isEmpty && starlinks.isEmpty) {
      return const _EmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'Sin datos financieros',
        subtitle: 'Registra clientes y Starlinks para ver tu resumen financiero aquí.',
      );
    }

    final activos = clientes.where((c) => c.status == 'activo').toList();
    final mora = clientes.where((c) => c.status == 'mora').toList();
    final inactivo = clientes.where((c) => c.status == 'inactivo').toList();

    final ingresoBruto = activos.fold(0.0, (s, c) => s + c.planValor);
    final ingresoMora = mora.fold(0.0, (s, c) => s + c.planValor);
    final subtotal = ingresoBruto - costoTotalStarlinks;
    final diezmo = subtotal > 0 ? subtotal * 0.10 : 0.0;
    final ingresoNeto = subtotal - diezmo;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const _SectionHeader(icon: Icons.insights_rounded, title: 'Resumen del mes'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _KpiCard(label: 'Ingreso bruto', value: _pesosShort(ingresoBruto), icon: Icons.trending_up_rounded, color: _C.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _KpiCard(
                label: 'Costo Starlinks (${starlinks.length})',
                value: '-${_pesosShort(costoTotalStarlinks)}',
                icon: Icons.satellite_alt_rounded,
                color: _C.danger),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child:
                _KpiCard(label: 'En riesgo (mora)', value: _pesosShort(ingresoMora), icon: Icons.warning_amber_rounded, color: _C.warning),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _KpiCard(label: 'Neto tras diezmo', value: _pesosShort(ingresoNeto), icon: Icons.savings_rounded, color: _C.success),
          ),
        ]),
        const SizedBox(height: 22),
        if (starlinks.isNotEmpty) ...[
          const _SectionHeader(icon: Icons.satellite_alt_rounded, title: 'Costos por Starlink'),
          const SizedBox(height: 12),
          _StarlinkCostosCard(starlinks: starlinks, total: costoTotalStarlinks),
          const SizedBox(height: 22),
        ],
        const _SectionHeader(icon: Icons.donut_large_rounded, title: 'Distribución de clientes'),
        const SizedBox(height: 12),
        _ClientStatusBar(activo: activos.length, mora: mora.length, inactivo: inactivo.length, total: clientes.length),
        const SizedBox(height: 22),
        const _SectionHeader(icon: Icons.show_chart_rounded, title: 'Histórico 6 meses (estimado)'),
        const SizedBox(height: 12),
        _BarChartPro(
          data: _historico(ingresoBruto),
          color: _C.primary,
          overlayColor: _C.purple,
          overlayFraction: 0.10,
          legendPrimary: 'Ingreso',
          legendSecondary: 'Diezmo 10%',
        ),
        const SizedBox(height: 22),
        _DiezmoCard(ingresoBruto: ingresoBruto, costoStarlinks: costoTotalStarlinks, subtotal: subtotal, diezmo: diezmo, neto: ingresoNeto),
      ],
    ).animate().fadeIn(duration: 260.ms);
  }
}

class _StarlinkCostosCard extends StatelessWidget {
  final List<_StarlinkData> starlinks;
  final double total;
  const _StarlinkCostosCard({required this.starlinks, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(borderColor: _C.danger.withOpacity(0.22), radius: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          color: _C.danger.withOpacity(0.06),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: _C.danger.withOpacity(0.13), shape: BoxShape.circle),
              child: const Icon(Icons.satellite_alt_rounded, color: _C.danger, size: 15),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text('Starlinks contratadas', style: _f(13, w: FontWeight.w700, c: _C.danger))),
            Text(_pesos(total), style: _f(12, w: FontWeight.w700, c: _C.danger)),
          ]),
        ),
        ...starlinks.map((sl) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: _C.border, width: 0.6))),
              child: Row(children: [
                const Icon(Icons.satellite_alt_rounded, size: 14, color: _C.textSec),
                const SizedBox(width: 8),
                Expanded(child: Text(sl.nombre, style: _f(13))),
                Text(sl.costoMensual > 0 ? '-${_pesos(sl.costoMensual)}' : 'Sin costo',
                    style: _f(12, w: FontWeight.w600, c: sl.costoMensual > 0 ? _C.danger : _C.textSec)),
              ]),
            )),
      ]),
    );
  }
}

class _DiezmoCard extends StatelessWidget {
  final double ingresoBruto, costoStarlinks, subtotal, diezmo, neto;
  const _DiezmoCard(
      {required this.ingresoBruto, required this.costoStarlinks, required this.subtotal, required this.diezmo, required this.neto});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_C.purple.withOpacity(0.10), _C.purple.withOpacity(0.02)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.purple.withOpacity(0.28), width: 1.2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _C.purple.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.volunteer_activism_rounded, color: _C.purple, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Desglose financiero completo', style: _f(14, w: FontWeight.w700, c: _C.purple)),
          ]),
          const SizedBox(height: 16),
          _DiezmoRow(label: 'Ingreso bruto (clientes activos)', value: _pesos(ingresoBruto), color: _C.primary),
          const Divider(height: 22, color: _C.border),
          _DiezmoRow(label: 'Costo Starlinks (mensual)', value: '-${_pesos(costoStarlinks)}', color: _C.danger),
          const Divider(height: 22, color: _C.border),
          _DiezmoRow(label: 'Subtotal', value: _pesos(subtotal), color: _C.accent),
          const Divider(height: 22, color: _C.border),
          _DiezmoRow(label: 'Diezmo (10% del subtotal)', value: '-${_pesos(diezmo)}', color: _C.purple),
          const Divider(height: 22, color: _C.border),
          _DiezmoRow(label: 'Neto final disponible', value: _pesos(neto), color: _C.success, bold: true),
        ]),
      );
}

class _DiezmoRow extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;
  const _DiezmoRow({required this.label, required this.value, required this.color, this.bold = false});
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(label, style: _f(12, c: _C.textSec))),
        Text(value, style: _f(bold ? 15 : 13, w: bold ? FontWeight.w800 : FontWeight.w700, c: color)),
      ]);
}

// ═══════════════════════════════════════════════════════════════════════════
//  PESTAÑA 2 — CLIENTES
// ═══════════════════════════════════════════════════════════════════════════
class _TabClientes extends StatelessWidget {
  final List<_ClienteData> clientes;
  const _TabClientes({required this.clientes});

  @override
  Widget build(BuildContext context) {
    if (clientes.isEmpty) {
      return const _EmptyState(
          icon: Icons.people_outline_rounded,
          title: 'Sin clientes registrados',
          subtitle: 'Los clientes que agregues aparecerán aquí con su estado y evolución mensual.');
    }

    final activo = clientes.where((c) => c.status == 'activo').length;
    final mora = clientes.where((c) => c.status == 'mora').length;
    final inactivo = clientes.where((c) => c.status == 'inactivo').length;

    final now = DateTime.now();
    final Map<String, int> porMes = {};
    for (int i = 0; i < 6; i++) {
      final idx = ((now.month - 5 + i - 1) % 12 + 12) % 12;
      porMes[_mesesCortos[idx]] = 0;
    }
    for (final c in clientes) {
      if (c.fecha == null) continue;
      final diff = now.difference(c.fecha!).inDays;
      if (diff > 180 || diff < 0) continue;
      final key = _mesesCortos[(c.fecha!.month - 1) % 12];
      if (porMes.containsKey(key)) porMes[key] = (porMes[key] ?? 0) + 1;
    }
    final barData = porMes.entries.map((e) => _ChartPoint(e.key, e.value.toDouble())).toList();

    final ordenados = [...clientes]..sort((a, b) {
        if (a.fecha == null && b.fecha == null) return 0;
        if (a.fecha == null) return 1;
        if (b.fecha == null) return -1;
        return b.fecha!.compareTo(a.fecha!);
      });
    final ultimos = ordenados.take(5).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const _SectionHeader(icon: Icons.groups_rounded, title: 'Totales'),
        const SizedBox(height: 12),
        Row(children: [
          _StatPill(label: 'Total', value: '${clientes.length}', color: _C.primary),
          const SizedBox(width: 8),
          _StatPill(label: 'Activos', value: '$activo', color: _C.success),
          const SizedBox(width: 8),
          _StatPill(label: 'Mora', value: '$mora', color: _C.danger),
          const SizedBox(width: 8),
          _StatPill(label: 'Inactivos', value: '$inactivo', color: _C.warning),
        ]),
        const SizedBox(height: 22),
        const _SectionHeader(icon: Icons.pie_chart_rounded, title: 'Estado de la cartera'),
        const SizedBox(height: 12),
        _DonutChart(activo: activo, mora: mora, inactivo: inactivo, total: clientes.length),
        const SizedBox(height: 22),
        const _SectionHeader(icon: Icons.person_add_alt_1_rounded, title: 'Nuevos clientes por mes'),
        const SizedBox(height: 12),
        _BarChartPro(data: barData, color: _C.accent, currency: false),
        const SizedBox(height: 22),
        const _SectionHeader(icon: Icons.history_rounded, title: 'Últimos registrados'),
        const SizedBox(height: 10),
        ...ultimos.map((c) => _UltimoClienteTile(c: c)),
      ],
    ).animate().fadeIn(duration: 260.ms);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  PESTAÑA 3 — PLANES
// ═══════════════════════════════════════════════════════════════════════════
class _TabPlanes extends StatelessWidget {
  final List<_ClienteData> clientes;
  const _TabPlanes({required this.clientes});

  @override
  Widget build(BuildContext context) {
    final activos = clientes.where((c) => c.status == 'activo').toList();

    if (activos.isEmpty) {
      return const _EmptyState(
          icon: Icons.category_outlined,
          title: 'Sin planes activos',
          subtitle: 'Cuando tengas clientes activos con un plan asignado, verás aquí el desglose por plan.');
    }

    final Map<String, List<_ClienteData>> grupos = {};
    for (final c in activos) {
      grupos.putIfAbsent(c.planCliente, () => []).add(c);
    }

    final planStats = grupos.entries.map((e) {
      final total = e.value.fold(0.0, (s, c) => s + c.planValor);
      return _PlanStat(nombre: e.key, count: e.value.length, ingresoTotal: total, diezmo: total * 0.10);
    }).toList()
      ..sort((a, b) => b.ingresoTotal.compareTo(a.ingresoTotal));

    final ingresoTotal = planStats.fold(0.0, (s, p) => s + p.ingresoTotal);
    final maxCount = planStats.map((p) => p.count).reduce(max);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const _SectionHeader(icon: Icons.bar_chart_rounded, title: 'Resumen de planes'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _KpiCard(label: 'Planes activos', value: '${planStats.length}', icon: Icons.category_rounded, color: _C.accent)),
          const SizedBox(width: 10),
          Expanded(
              child:
                  _KpiCard(label: 'Ingreso total', value: _pesosShort(ingresoTotal), icon: Icons.attach_money_rounded, color: _C.primary)),
        ]),
        const SizedBox(height: 22),
        const _SectionHeader(icon: Icons.stacked_bar_chart_rounded, title: 'Detalle por plan'),
        const SizedBox(height: 10),
        ...planStats
            .asMap()
            .entries
            .map((e) => _PlanCard(plan: e.value, totalClientes: activos.length, maxCount: maxCount, esTop: e.key == 0)),
        const SizedBox(height: 22),
        const _SectionHeader(icon: Icons.table_rows_rounded, title: 'Tabla resumen'),
        const SizedBox(height: 10),
        _PlanTable(plans: planStats, ingresoTotal: ingresoTotal),
      ],
    ).animate().fadeIn(duration: 260.ms);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  PESTAÑA 4 — CONSUMO (fusionada desde ReporteConsumoWidget)
// ═══════════════════════════════════════════════════════════════════════════
class _ConsumoTab extends StatefulWidget {
  const _ConsumoTab();
  @override
  State<_ConsumoTab> createState() => _ConsumoTabState();
}

class _ConsumoTabState extends State<_ConsumoTab> {
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  late int _anioSel;
  late int _mesSel;
  bool _cargando = true;
  bool _cargandoHistorico = true;
  List<_ConsumoCliente> _datos = [];
  List<_ChartPoint> _historicoGB = [];
  late List<Map<String, int>> _meses;

  // Ciclo de facturación: inicia el día 25. Un ciclo que arranca el 25 de un
  // mes se etiqueta con ese mismo mes (ej. 25 jun → 24 jul = ciclo "Junio").
  // Si tu script del VPS etiqueta el campo 'mes' distinto, ajusta esta función
  // para que la clave generada aquí coincida con la que guarda el backend.
  Map<String, int> _cicloDe(DateTime d) {
    if (d.day >= 25) return {'anio': d.year, 'mes': d.month};
    final prev = DateTime(d.year, d.month - 1, 1);
    return {'anio': prev.year, 'mes': prev.month};
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final ciclo = _cicloDe(now);
    _anioSel = ciclo['anio']!;
    _mesSel = ciclo['mes']!;
    _meses = List.generate(6, (i) {
      final d = DateTime(ciclo['anio']!, ciclo['mes']! - i, 1);
      return {'anio': d.year, 'mes': d.month};
    });
    _cargar();
    _cargarHistorico();
  }

  String _mesKey(int anio, int mes) => '$anio-${mes.toString().padLeft(2, '0')}';

  Future<void> _cargar() async {
    if (_uid.isEmpty) return;
    setState(() => _cargando = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('consumo_mensual')
          .where('propietarioUid', isEqualTo: _uid)
          .where('mes', isEqualTo: _mesKey(_anioSel, _mesSel))
          .get();
      final lista = snap.docs.map((d) => _ConsumoCliente.fromDoc(d)).toList()..sort((a, b) => b.totalGB.compareTo(a.totalGB));
      if (!mounted) return;
      setState(() {
        _datos = lista;
        _cargando = false;
      });
    } catch (e) {
      debugPrint('[CONSUMO] Error: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  // Suma el GB de TODOS los clientes por cada uno de los últimos 6 ciclos,
  // para poder comparar qué mes tuvo mayor consumo total.
  Future<void> _cargarHistorico() async {
    if (_uid.isEmpty) return;
    setState(() => _cargandoHistorico = true);
    try {
      final ciclosOrdenados = _meses.reversed.toList(); // más antiguo → más reciente
      final resultados = await Future.wait(ciclosOrdenados.map((c) => FirebaseFirestore.instance
          .collection('consumo_mensual')
          .where('propietarioUid', isEqualTo: _uid)
          .where('mes', isEqualTo: _mesKey(c['anio']!, c['mes']!))
          .get()));

      final puntos = <_ChartPoint>[];
      for (int i = 0; i < ciclosOrdenados.length; i++) {
        final c = ciclosOrdenados[i];
        final docs = resultados[i].docs;
        final totalGB = docs.fold<double>(0, (s, d) {
          final data = d.data() as Map<String, dynamic>;
          final up = ((data['totalUpBytes'] ?? 0) as num) / 1e9;
          final down = ((data['totalDownBytes'] ?? 0) as num) / 1e9;
          return s + up + down;
        });
        puntos.add(_ChartPoint(_mesesCortos[c['mes']! - 1], totalGB));
      }
      if (!mounted) return;
      setState(() {
        _historicoGB = puntos;
        _cargandoHistorico = false;
      });
    } catch (e) {
      debugPrint('[CONSUMO HISTORICO] Error: $e');
      if (mounted) setState(() => _cargandoHistorico = false);
    }
  }

  String _fmtGB(double gb) => gb < 1.0 ? '${(gb * 1024).toStringAsFixed(0)} MB' : '${gb.toStringAsFixed(2)} GB';

  Color _colorPorConsumo(double gb) {
    if (gb >= 200) return _C.danger;
    if (gb >= 120) return _C.warning;
    return _C.success;
  }

  double get _totalUp => _datos.fold(0.0, (s, c) => s + c.upGB);
  double get _totalDown => _datos.fold(0.0, (s, c) => s + c.downGB);
  double get _totalGB => _totalUp + _totalDown;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _C.primary,
      onRefresh: () => Future.wait([_cargar(), _cargarHistorico()]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const _SectionHeader(icon: Icons.calendar_month_rounded, title: 'Periodo'),
          const SizedBox(height: 10),
          _MesSelector(
            meses: _meses,
            anioSel: _anioSel,
            mesSel: _mesSel,
            onSel: (a, m) {
              setState(() {
                _anioSel = a;
                _mesSel = m;
              });
              _cargar();
            },
          ),
          const SizedBox(height: 18),
          if (_cargando)
            const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: _LoadingState(text: 'Cargando consumo...'))
          else ...[
            const _SectionHeader(icon: Icons.data_usage_rounded, title: 'Resumen'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _KpiCard(label: 'Total', value: _fmtGB(_totalGB), icon: Icons.data_usage_rounded, color: _C.primary)),
              const SizedBox(width: 8),
              Expanded(child: _KpiCard(label: 'Subida', value: _fmtGB(_totalUp), icon: Icons.upload_rounded, color: _C.success)),
              const SizedBox(width: 8),
              Expanded(child: _KpiCard(label: 'Bajada', value: _fmtGB(_totalDown), icon: Icons.download_rounded, color: _C.accent)),
            ]),
            const SizedBox(height: 22),
            const _SectionHeader(icon: Icons.bar_chart_rounded, title: 'Top clientes (ciclo actual)'),
            const SizedBox(height: 12),
            if (_datos.isEmpty)
              const SizedBox()
            else
              _BarChartPro(
                data: _datos.take(6).map((c) {
                  final corto = c.nombre.length > 10 ? '${c.nombre.substring(0, 9)}…' : c.nombre;
                  return _ChartPoint(corto, c.totalGB);
                }).toList(),
                color: _C.accent,
                currency: false,
                formatter: (v) => v < 1 ? '${(v * 1024).toStringAsFixed(0)}MB' : '${v.toStringAsFixed(1)}GB',
              ),
            const SizedBox(height: 22),
            const _SectionHeader(icon: Icons.show_chart_rounded, title: 'Histórico de consumo (6 ciclos)'),
            const SizedBox(height: 12),
            if (_cargandoHistorico)
              const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: _LoadingState(text: 'Calculando histórico...'))
            else if (_historicoGB.every((p) => p.value == 0))
              const _EmptyState(
                icon: Icons.show_chart_rounded,
                title: 'Sin histórico disponible',
                subtitle: 'Aún no hay suficientes ciclos con datos para comparar meses.',
              )
            else ...[
              _BarChartPro(
                data: _historicoGB,
                color: _C.purple,
                currency: false,
                formatter: (v) => '${v.toStringAsFixed(0)}GB',
              ),
              const SizedBox(height: 10),
              _MesMayorConsumoBadge(historico: _historicoGB),
            ],
            const SizedBox(height: 22),
            const _SectionHeader(icon: Icons.leaderboard_rounded, title: 'Consumo por cliente'),
            const SizedBox(height: 10),
            if (_datos.isEmpty)
              const _EmptyState(
                icon: Icons.data_usage_rounded,
                title: 'Sin datos de consumo',
                subtitle: 'No hay registros para este periodo. Verifica que el tracking esté activo en el VPS.',
              )
            else
              ..._datos.asMap().entries.map((e) {
                final i = e.key;
                final c = e.value;
                final col = _colorPorConsumo(c.totalGB);
                final pct = (c.totalGB / 200).clamp(0.0, 1.0);
                return _ConsumoCard(rank: i + 1, cliente: c, color: col, porcentaje: pct, fmtGB: _fmtGB)
                    .animate()
                    .fadeIn(duration: 260.ms, delay: (i * 25).ms)
                    .slideY(begin: 0.04, end: 0);
              }),
          ],
        ],
      ),
    );
  }
}

class _MesSelector extends StatelessWidget {
  final List<Map<String, int>> meses;
  final int anioSel, mesSel;
  final void Function(int anio, int mes) onSel;
  const _MesSelector({required this.meses, required this.anioSel, required this.mesSel, required this.onSel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: meses.length,
        itemBuilder: (_, i) {
          final m = meses[i];
          final anio = m['anio']!;
          final mes = m['mes']!;
          final sel = anio == anioSel && mes == mesSel;
          return GestureDetector(
            onTap: () => onSel(anio, mes),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                gradient: sel ? const LinearGradient(colors: [_C.primary, _C.accent]) : null,
                color: sel ? null : _C.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? Colors.transparent : _C.border, width: 1.1),
                boxShadow: sel ? [BoxShadow(color: _C.primary.withOpacity(0.28), blurRadius: 8, offset: const Offset(0, 3))] : [],
              ),
              child: Text(
                i == 0 ? 'Este mes' : '${_mesesCortos[mes - 1]} $anio',
                style: _f(12, w: sel ? FontWeight.w700 : FontWeight.w500, c: sel ? Colors.white : _C.textSec),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MesMayorConsumoBadge extends StatelessWidget {
  final List<_ChartPoint> historico;
  const _MesMayorConsumoBadge({required this.historico});

  @override
  Widget build(BuildContext context) {
    final validos = historico.where((p) => p.value > 0).toList();
    if (validos.isEmpty) return const SizedBox();
    final top = validos.reduce((a, b) => b.value > a.value ? b : a);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _C.purple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.purple.withOpacity(0.22)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: _C.purple.withOpacity(0.15), shape: BoxShape.circle),
          child: const Icon(Icons.emoji_events_rounded, color: _C.purple, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Mes con mayor consumo: ${top.label} · ${top.value.toStringAsFixed(1)} GB',
              style: _f(12, w: FontWeight.w700, c: _C.purple)),
        ),
      ]),
    );
  }
}

class _ConsumoCard extends StatelessWidget {
  final int rank;
  final _ConsumoCliente cliente;
  final Color color;
  final double porcentaje;
  final String Function(double) fmtGB;
  const _ConsumoCard({required this.rank, required this.cliente, required this.color, required this.porcentaje, required this.fmtGB});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(borderColor: color.withOpacity(0.22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: rank <= 3 ? color.withOpacity(0.14) : _C.surfaceDim, borderRadius: BorderRadius.circular(9)),
            child: Center(child: Text('#$rank', style: _f(11, w: FontWeight.w700, c: rank <= 3 ? color : _C.textSec))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cliente.nombre, style: _f(14, w: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              Row(children: [
                const Icon(Icons.router_rounded, size: 10, color: _C.textSec),
                const SizedBox(width: 3),
                Text(cliente.ip, style: _f(11, c: _C.textSec)),
              ]),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
            child: Text(fmtGB(cliente.totalGB), style: _f(13, w: FontWeight.w800, c: color)),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: porcentaje),
            duration: const Duration(milliseconds: 600),
            builder: (context, val, _) => LinearProgressIndicator(
                value: val, minHeight: 7, backgroundColor: color.withOpacity(0.1), valueColor: AlwaysStoppedAnimation(color)),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _MiniStat(icon: Icons.upload_rounded, color: _C.success, label: 'Subida', valor: fmtGB(cliente.upGB)),
          const SizedBox(width: 12),
          _MiniStat(icon: Icons.download_rounded, color: _C.accent, label: 'Bajada', valor: fmtGB(cliente.downGB)),
        ]),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, valor;
  const _MiniStat({required this.icon, required this.color, required this.label, required this.valor});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, color: color, size: 12)),
        const SizedBox(width: 5),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: _f(9, c: _C.textSec)),
          Text(valor, style: _f(11, w: FontWeight.w700)),
        ]),
      ]);
}

// ═══════════════════════════════════════════════════════════════════════════
//  COMPONENTES COMUNES
// ═══════════════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: _C.primary.withOpacity(0.09), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 14, color: _C.primary)),
        const SizedBox(width: 8),
        Text(title, style: _f(15, w: FontWeight.w800)),
      ]);
}

class _KpiCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(borderColor: color.withOpacity(0.18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 16)),
          const SizedBox(height: 10),
          Text(value, style: _f(15, w: FontWeight.w800, c: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: _f(10.5, c: _C.textSec), maxLines: 2),
        ]),
      );
}

class _StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.22))),
          child: Column(children: [
            Text(value, style: _f(19, w: FontWeight.w800, c: color)),
            const SizedBox(height: 2),
            Text(label, style: _f(10, c: _C.textSec), textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _ClientStatusBar extends StatelessWidget {
  final int activo, mora, inactivo, total;
  const _ClientStatusBar({required this.activo, required this.mora, required this.inactivo, required this.total});

  @override
  Widget build(BuildContext context) {
    final t = total == 0 ? 1 : total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(children: [
        Row(children: [
          _StatusDot(color: _C.success, label: 'Activo', count: activo),
          const SizedBox(width: 16),
          _StatusDot(color: _C.danger, label: 'Mora', count: mora),
          const SizedBox(width: 16),
          _StatusDot(color: _C.warning, label: 'Inactivo', count: inactivo),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Row(children: [
            if (activo > 0) Flexible(flex: activo, child: Container(height: 12, color: _C.success)),
            if (mora > 0) Flexible(flex: mora, child: Container(height: 12, color: _C.danger)),
            if (inactivo > 0) Flexible(flex: inactivo, child: Container(height: 12, color: _C.warning)),
            if (activo == 0 && mora == 0 && inactivo == 0) Flexible(child: Container(height: 12, color: _C.border)),
          ]),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${(activo / t * 100).toStringAsFixed(1)}% activos', style: _f(11, w: FontWeight.w600, c: _C.success)),
          Text('${(mora / t * 100).toStringAsFixed(1)}% en mora', style: _f(11, w: FontWeight.w600, c: _C.danger)),
        ]),
      ]),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  const _StatusDot({required this.color, required this.label, required this.count});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label ($count)', style: _f(12, c: _C.textSec)),
      ]);
}

// ─── GRÁFICA DE BARRAS PROFESIONAL, ANIMADA, CON GRID Y LEYENDA ─────────────
class _ChartPoint {
  final String label;
  final double value;
  const _ChartPoint(this.label, this.value);
}

class _BarChartPro extends StatelessWidget {
  final List<_ChartPoint> data;
  final Color color;
  final bool currency;
  final Color? overlayColor;
  final double overlayFraction;
  final String? legendPrimary;
  final String? legendSecondary;
  final String Function(double)? formatter;
  static const double _chartH = 150;

  const _BarChartPro({
    required this.data,
    required this.color,
    this.currency = true,
    this.overlayColor,
    this.overlayFraction = 0,
    this.legendPrimary,
    this.legendSecondary,
    this.formatter,
  });

  String _fmt(double v) {
    if (formatter != null) return formatter!(v);
    if (!currency) return v.toInt().toString();
    return _pesosShort(v);
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();
    final maxVal = data.map((d) => d.value).fold<double>(0, (a, b) => b > a ? b : a);
    final safeMax = maxVal <= 0 ? 1.0 : maxVal;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: _cardDecoration(),
      child: Column(children: [
        SizedBox(
          height: _chartH,
          child: Stack(children: [
            Positioned.fill(
              child: Column(
                children: List.generate(
                  4,
                  (i) => Expanded(
                    child: Container(decoration: const BoxDecoration(border: Border(top: BorderSide(color: _C.border, width: 1)))),
                  ),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((d) {
                final frac = (d.value / safeMax).clamp(0.0, 1.0);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (d.value > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(_fmt(d.value), style: _f(9, w: FontWeight.w700, c: color)),
                          ),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: frac),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (context, val, _) => Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              Container(
                                height: (_chartH - 30) * val,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color, color.withOpacity(0.5)]),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                ),
                              ),
                              if (overlayColor != null && overlayFraction > 0)
                                Container(
                                  height: (_chartH - 30) * val * overlayFraction,
                                  decoration: BoxDecoration(
                                      color: overlayColor!.withOpacity(0.9),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Row(
          children: data
              .map((d) => Expanded(
                    child: Text(d.label,
                        textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: _f(10, c: _C.textSec)),
                  ))
              .toList(),
        ),
        if (overlayColor != null && legendPrimary != null) ...[
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, color.withOpacity(0.5)]), borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 5),
            Text(legendPrimary!, style: _f(11, c: _C.textSec)),
            const SizedBox(width: 16),
            Container(width: 10, height: 10, decoration: BoxDecoration(color: overlayColor, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 5),
            Text(legendSecondary ?? '', style: _f(11, c: _C.textSec)),
          ]),
        ],
      ]),
    );
  }
}

// ─── DONUT CON TOTAL AL CENTRO ───────────────────────────────────────────────
class _DonutChart extends StatelessWidget {
  final int activo, mora, inactivo, total;
  const _DonutChart({required this.activo, required this.mora, required this.inactivo, required this.total});

  @override
  Widget build(BuildContext context) {
    final t = total == 0 ? 1 : total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(children: [
        SizedBox(
          width: 116,
          height: 116,
          child: Stack(alignment: Alignment.center, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, val, _) => CustomPaint(
                size: const Size.square(116),
                painter: _DonutPainter(activo: (activo / t) * val, mora: (mora / t) * val, inactivo: (inactivo / t) * val),
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$total', style: _f(22, w: FontWeight.w800)),
              Text('clientes', style: _f(10, c: _C.textSec)),
            ]),
          ]),
        ),
        const SizedBox(width: 22),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _LegendRow(color: _C.success, label: 'Activos', count: activo, total: t),
            const SizedBox(height: 10),
            _LegendRow(color: _C.danger, label: 'En mora', count: mora, total: t),
            const SizedBox(height: 10),
            _LegendRow(color: _C.warning, label: 'Inactivos', count: inactivo, total: t),
          ]),
        ),
      ]),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int count, total;
  const _LegendRow({required this.color, required this.label, required this.count, required this.total});
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Expanded(child: Text('$label · $count (${(count / total * 100).toStringAsFixed(1)}%)', style: _f(12, c: _C.textSec))),
      ]);
}

class _DonutPainter extends CustomPainter {
  final double activo, mora, inactivo;
  const _DonutPainter({required this.activo, required this.mora, required this.inactivo});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 5;
    const strokeWidth = 16.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const start = -pi / 2;
    final segments = [
      [activo, _C.success],
      [mora, _C.danger],
      [inactivo, _C.warning],
    ];

    double current = start;
    bool any = false;
    for (final seg in segments) {
      final sweep = (seg[0] as double) * 2 * pi;
      if (sweep > 0.001) {
        any = true;
        paint.color = seg[1] as Color;
        canvas.drawArc(Rect.fromCircle(center: c, radius: r), current, max(sweep - 0.04, 0.01), false, paint);
        current += sweep;
      }
    }
    if (!any) {
      paint.color = _C.border;
      canvas.drawCircle(c, r, paint);
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.activo != activo || old.mora != mora || old.inactivo != inactivo;
}

class _UltimoClienteTile extends StatelessWidget {
  final _ClienteData c;
  const _UltimoClienteTile({required this.c});

  Color get _color {
    switch (c.status) {
      case 'activo':
        return _C.success;
      case 'mora':
        return _C.danger;
      default:
        return _C.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fecha = c.fecha != null ? '${c.fecha!.day}/${c.fecha!.month}/${c.fecha!.year}' : 'Sin fecha';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: _cardDecoration(radius: 13),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(c.planCliente, style: _f(13, w: FontWeight.w600))),
        Text(fecha, style: _f(11, c: _C.textSec)),
        const SizedBox(width: 8),
        Text(_pesosShort(c.planValor), style: _f(12, w: FontWeight.w700, c: _C.primary)),
      ]),
    );
  }
}

class _PlanStat {
  final String nombre;
  final int count;
  final double ingresoTotal, diezmo;
  _PlanStat({required this.nombre, required this.count, required this.ingresoTotal, required this.diezmo});
}

class _PlanCard extends StatelessWidget {
  final _PlanStat plan;
  final int totalClientes, maxCount;
  final bool esTop;
  const _PlanCard({required this.plan, required this.totalClientes, required this.maxCount, this.esTop = false});

  @override
  Widget build(BuildContext context) {
    final pctClientes = totalClientes == 0 ? 0.0 : plan.count / totalClientes;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(borderColor: esTop ? _C.primary.withOpacity(0.35) : _C.border),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Row(children: [
              Flexible(child: Text(plan.nombre, style: _f(14, w: FontWeight.w700), overflow: TextOverflow.ellipsis)),
              if (esTop) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: _C.primary, borderRadius: BorderRadius.circular(6)),
                  child: Text('TOP', style: _f(9, w: FontWeight.w800, c: Colors.white)),
                ),
              ],
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _C.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text('${plan.count} clientes', style: _f(12, w: FontWeight.w600, c: _C.primary)),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pctClientes),
            duration: const Duration(milliseconds: 600),
            builder: (context, val, _) => LinearProgressIndicator(
                value: val, minHeight: 8, backgroundColor: _C.border, valueColor: const AlwaysStoppedAnimation(_C.primary)),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${(pctClientes * 100).toStringAsFixed(1)}% del total', style: _f(11, c: _C.textSec)),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Ingreso: ${_pesosShort(plan.ingresoTotal)}', style: _f(11, w: FontWeight.w600, c: _C.success)),
            Text('Diezmo: ${_pesosShort(plan.diezmo)}', style: _f(11, c: _C.purple)),
          ]),
        ]),
      ]),
    );
  }
}

class _PlanTable extends StatelessWidget {
  final List<_PlanStat> plans;
  final double ingresoTotal;
  const _PlanTable({required this.plans, required this.ingresoTotal});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: _C.surfaceDim,
          child: Row(children: [
            Expanded(flex: 3, child: Text('Plan', style: _f(11, w: FontWeight.w700, c: _C.textSec))),
            Expanded(child: Text('Cli.', style: _f(11, w: FontWeight.w700, c: _C.textSec), textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text('Ingreso', style: _f(11, w: FontWeight.w700, c: _C.textSec), textAlign: TextAlign.right)),
            Expanded(flex: 2, child: Text('Diezmo', style: _f(11, w: FontWeight.w700, c: _C.textSec), textAlign: TextAlign.right)),
          ]),
        ),
        ...plans.map((p) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: _C.border, width: 0.6))),
              child: Row(children: [
                Expanded(flex: 3, child: Text(p.nombre, style: _f(12), overflow: TextOverflow.ellipsis)),
                Expanded(child: Text('${p.count}', style: _f(12, w: FontWeight.w600, c: _C.primary), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text(_pesosShort(p.ingresoTotal), style: _f(11, c: _C.success), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text(_pesosShort(p.diezmo), style: _f(11, c: _C.purple), textAlign: TextAlign.right)),
              ]),
            )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: const BoxDecoration(color: _C.surfaceDim, border: Border(top: BorderSide(color: _C.border, width: 1))),
          child: Row(children: [
            Expanded(flex: 3, child: Text('TOTAL', style: _f(12, w: FontWeight.w800))),
            Expanded(
                child: Text('${plans.fold(0, (s, p) => s + p.count)}',
                    style: _f(12, w: FontWeight.w800, c: _C.primary), textAlign: TextAlign.center)),
            Expanded(
                flex: 2,
                child: Text(_pesosShort(ingresoTotal), style: _f(12, w: FontWeight.w800, c: _C.success), textAlign: TextAlign.right)),
            Expanded(
                flex: 2,
                child: Text(_pesosShort(ingresoTotal * 0.10), style: _f(12, w: FontWeight.w800, c: _C.purple), textAlign: TextAlign.right)),
          ]),
        ),
      ]),
    );
  }
}
