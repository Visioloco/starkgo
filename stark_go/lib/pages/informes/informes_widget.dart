import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  static const Color purple = Color(0xFF7C3AED);
}

// ─────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────
String _pesos(double v) {
  final s = v.toStringAsFixed(0).split('');
  final buf = StringBuffer();
  int cnt = 0;
  for (int i = s.length - 1; i >= 0; i--) {
    if (cnt > 0 && cnt % 3 == 0) buf.write('.');
    buf.write(s[i]);
    cnt++;
  }
  return 'COP \$ ${buf.toString().split('').reversed.join('')}';
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  final c = v.toString().replaceAll('.', '').replaceAll(',', '').trim();
  return double.tryParse(c) ?? 0;
}

// Parsea "$150/mes", "150", "USD 250/mes" → número
double _parsePlanStarlink(dynamic raw) {
  if (raw == null) return 0;
  final nums = RegExp(r'\d+').allMatches(raw.toString());
  if (nums.isEmpty) return 0;
  return double.tryParse(nums.first.group(0)!) ?? 0;
}

// ─────────────────────────────────────────────
//  MODELO CLIENTE
// ─────────────────────────────────────────────
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

// ─────────────────────────────────────────────
//  MODELO STARLINK
// ─────────────────────────────────────────────
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

// ═════════════════════════════════════════════
//  WIDGET PRINCIPAL
// ═════════════════════════════════════════════
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
    _tabs = TabController(length: 3, vsync: this);
    _cargar();
  }

  Future<void> _cargar() async {
    if (_uid.isEmpty) return;
    final results = await Future.wait([
      FirebaseFirestore.instance.collection('clientes').where('propietarioUid', isEqualTo: _uid).get(),
      FirebaseFirestore.instance.collection('starlinks').where('propietarioUid', isEqualTo: _uid).get(),
    ]);

    if (mounted) {
      setState(() {
        _clientes = (results[0] as QuerySnapshot).docs.map((d) => _ClienteData.fromDoc(d)).toList();
        _starlinks = (results[1] as QuerySnapshot).docs.map((d) => _StarlinkData.fromDoc(d)).toList();
        _cargando = false;
      });
    }
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
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _C.textPri),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Informes', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 18, fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: _C.primary,
          unselectedLabelColor: _C.textSec,
          indicatorColor: _C.primary,
          indicatorWeight: 2.5,
          labelStyle: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Financiero'),
            Tab(text: 'Clientes'),
            Tab(text: 'Planes'),
          ],
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _C.primary, strokeWidth: 2))
          : RefreshIndicator(
              color: _C.primary,
              onRefresh: () async {
                setState(() => _cargando = true);
                await _cargar();
              },
              child: TabBarView(
                controller: _tabs,
                children: [
                  _TabFinanciero(
                    clientes: _clientes,
                    starlinks: _starlinks,
                    costoTotalStarlinks: costoTotalStarlinks,
                  ),
                  _TabClientes(clientes: _clientes),
                  _TabPlanes(clientes: _clientes),
                ],
              ),
            ),
    );
  }
}

// ═════════════════════════════════════════════
//  PESTAÑA 1 — FINANCIERO
// ═════════════════════════════════════════════
class _TabFinanciero extends StatelessWidget {
  final List<_ClienteData> clientes;
  final List<_StarlinkData> starlinks;
  final double costoTotalStarlinks;

  const _TabFinanciero({
    required this.clientes,
    required this.starlinks,
    required this.costoTotalStarlinks,
  });

  @override
  Widget build(BuildContext context) {
    final activos = clientes.where((c) => c.status == 'activo').toList();
    final mora = clientes.where((c) => c.status == 'mora').toList();
    final inactivo = clientes.where((c) => c.status == 'inactivo').toList();

    final ingresoBruto = activos.fold(0.0, (s, c) => s + c.planValor);
    final ingresoMora = mora.fold(0.0, (s, c) => s + c.planValor);
    final subtotal = ingresoBruto - costoTotalStarlinks;
    final diezmo = subtotal > 0 ? subtotal * 0.10 : 0.0;
    final ingresoNeto = subtotal - diezmo;

    final meses = _generarHistorico(ingresoBruto);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── KPIs ──
        _SectionTitle('Resumen del mes'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            _KpiCard(
              label: 'Ingreso bruto clientes',
              value: _pesos(ingresoBruto),
              icon: Icons.trending_up_rounded,
              color: _C.primary,
            ),
            _KpiCard(
              label: 'Costo Starlinks (${starlinks.length})',
              value: '– ${_pesos(costoTotalStarlinks)}',
              icon: Icons.satellite_alt_rounded,
              color: _C.danger,
            ),
            _KpiCard(
              label: 'En riesgo (mora)',
              value: _pesos(ingresoMora),
              icon: Icons.warning_amber_rounded,
              color: _C.warning,
            ),
            _KpiCard(
              label: 'Neto después diezmo',
              value: _pesos(ingresoNeto),
              icon: Icons.account_balance_wallet_rounded,
              color: _C.success,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Desglose Starlinks ──
        if (starlinks.isNotEmpty) ...[
          _SectionTitle('Costos por Starlink'),
          const SizedBox(height: 10),
          _StarlinkCostosCard(starlinks: starlinks, total: costoTotalStarlinks),
          const SizedBox(height: 20),
        ],

        // ── Distribución clientes ──
        _SectionTitle('Distribución de clientes'),
        const SizedBox(height: 10),
        _ClientStatusBar(
          activo: activos.length,
          mora: mora.length,
          inactivo: inactivo.length,
          total: clientes.length,
        ),
        const SizedBox(height: 20),

        // ── Histórico ──
        _SectionTitle('Histórico 6 meses (estimado)'),
        const SizedBox(height: 10),
        _BarChart(data: meses, diezmoEnabled: true),
        const SizedBox(height: 20),

        // ── Diezmo detallado ──
        _DiezmoCard(
          ingresoBruto: ingresoBruto,
          costoStarlinks: costoTotalStarlinks,
          subtotal: subtotal,
          diezmo: diezmo,
          neto: ingresoNeto,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  List<Map<String, dynamic>> _generarHistorico(double base) {
    final now = DateTime.now();
    final nombres = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final rng = Random(42);
    return List.generate(6, (i) {
      final mes = now.month - 5 + i;
      final idx = (mes - 1) % 12;
      final variacion = 0.85 + rng.nextDouble() * 0.30;
      final val = base * variacion;
      return {'mes': nombres[idx], 'valor': val};
    });
  }
}

// ─────────────────────────────────────────────
//  CARD COSTOS STARLINKS
// ─────────────────────────────────────────────
class _StarlinkCostosCard extends StatelessWidget {
  final List<_StarlinkData> starlinks;
  final double total;

  const _StarlinkCostosCard({required this.starlinks, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.danger.withOpacity(0.25), width: 1.2),
        boxShadow: [BoxShadow(color: _C.danger.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _C.danger.withOpacity(0.06),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(13), topRight: Radius.circular(13)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: _C.danger.withOpacity(0.12), shape: BoxShape.circle),
                child: const Icon(Icons.satellite_alt_rounded, color: _C.danger, size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Starlinks contratadas',
                    style: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Text('Total: ${_pesos(total)}', style: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
          // Lista
          ...starlinks.map((sl) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: _C.cardBorder, width: 0.5))),
                child: Row(children: [
                  const Icon(Icons.satellite_alt_rounded, size: 14, color: _C.textSec),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(sl.nombre, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13)),
                  ),
                  Text(
                    sl.costoMensual > 0 ? '– ${_pesos(sl.costoMensual)}' : 'Sin costo',
                    style: GoogleFonts.spaceGrotesk(
                        color: sl.costoMensual > 0 ? _C.danger : _C.textSec, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ]),
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  DIEZMO CARD COMPLETO
// ─────────────────────────────────────────────
class _DiezmoCard extends StatelessWidget {
  final double ingresoBruto, costoStarlinks, subtotal, diezmo, neto;

  const _DiezmoCard({
    required this.ingresoBruto,
    required this.costoStarlinks,
    required this.subtotal,
    required this.diezmo,
    required this.neto,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_C.purple.withOpacity(0.1), _C.purple.withOpacity(0.03)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.purple.withOpacity(0.3), width: 1.2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _C.purple.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.volunteer_activism_rounded, color: _C.purple, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Desglose financiero completo',
                style: GoogleFonts.spaceGrotesk(color: _C.purple, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          _DiezmoRow(label: 'Ingreso bruto (clientes activos)', value: _pesos(ingresoBruto), color: _C.primary),
          const Divider(height: 20),
          _DiezmoRow(label: 'Costo Starlinks (mensual)', value: '– ${_pesos(costoStarlinks)}', color: _C.danger),
          const Divider(height: 20),
          _DiezmoRow(label: 'Subtotal', value: _pesos(subtotal), color: _C.accent),
          const Divider(height: 20),
          _DiezmoRow(label: 'Diezmo (10% del subtotal)', value: '– ${_pesos(diezmo)}', color: _C.purple),
          const Divider(height: 20),
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
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
          ),
          Text(value,
              style:
                  GoogleFonts.spaceGrotesk(color: color, fontSize: bold ? 14 : 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
        ],
      );
}

// ═════════════════════════════════════════════
//  PESTAÑA 2 — CLIENTES
// ═════════════════════════════════════════════
class _TabClientes extends StatelessWidget {
  final List<_ClienteData> clientes;
  const _TabClientes({required this.clientes});

  @override
  Widget build(BuildContext context) {
    final activo = clientes.where((c) => c.status == 'activo').length;
    final mora = clientes.where((c) => c.status == 'mora').length;
    final inactivo = clientes.where((c) => c.status == 'inactivo').length;

    final now = DateTime.now();
    final nombres = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final Map<String, int> porMes = {};
    for (int i = 0; i < 6; i++) {
      final m = now.month - 5 + i;
      final idx = (m - 1) % 12;
      porMes[nombres[idx]] = 0;
    }
    for (final c in clientes) {
      if (c.fecha == null) continue;
      final diff = now.difference(c.fecha!).inDays;
      if (diff > 180) continue;
      final idx = (c.fecha!.month - 1) % 12;
      final key = nombres[idx];
      if (porMes.containsKey(key)) porMes[key] = (porMes[key] ?? 0) + 1;
    }

    final barData = porMes.entries.map((e) => {'mes': e.key, 'valor': e.value.toDouble()}).toList();

    final ordenados = [...clientes];
    ordenados.sort((a, b) {
      if (a.fecha == null && b.fecha == null) return 0;
      if (a.fecha == null) return 1;
      if (b.fecha == null) return -1;
      return b.fecha!.compareTo(a.fecha!);
    });
    final ultimos = ordenados.take(5).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle('Totales'),
        const SizedBox(height: 10),
        Row(children: [
          _StatPill(label: 'Total', value: '${clientes.length}', color: _C.primary),
          const SizedBox(width: 8),
          _StatPill(label: 'Activos', value: '$activo', color: _C.success),
          const SizedBox(width: 8),
          _StatPill(label: 'Mora', value: '$mora', color: _C.danger),
          const SizedBox(width: 8),
          _StatPill(label: 'Inactivos', value: '$inactivo', color: _C.warning),
        ]),
        const SizedBox(height: 20),
        _SectionTitle('Estado (donut)'),
        const SizedBox(height: 10),
        _DonutChart(activo: activo, mora: mora, inactivo: inactivo, total: clientes.length),
        const SizedBox(height: 20),
        _SectionTitle('Nuevos clientes por mes'),
        const SizedBox(height: 10),
        _BarChart(data: barData, diezmoEnabled: false, isCount: true),
        const SizedBox(height: 20),
        _SectionTitle('Últimos 5 registrados'),
        const SizedBox(height: 8),
        ...ultimos.map((c) => _UltimoClienteTile(c: c)),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ═════════════════════════════════════════════
//  PESTAÑA 3 — PLANES
// ═════════════════════════════════════════════
class _TabPlanes extends StatelessWidget {
  final List<_ClienteData> clientes;
  const _TabPlanes({required this.clientes});

  @override
  Widget build(BuildContext context) {
    final activos = clientes.where((c) => c.status == 'activo').toList();

    final Map<String, List<_ClienteData>> grupos = {};
    for (final c in activos) {
      grupos.putIfAbsent(c.planCliente, () => []).add(c);
    }

    final planStats = grupos.entries.map((e) {
      final total = e.value.fold(0.0, (s, c) => s + c.planValor);
      return _PlanStat(
        nombre: e.key,
        count: e.value.length,
        ingresoTotal: total,
        diezmo: total * 0.10,
      );
    }).toList();
    planStats.sort((a, b) => b.ingresoTotal.compareTo(a.ingresoTotal));

    final ingresoTotal = planStats.fold(0.0, (s, p) => s + p.ingresoTotal);
    final maxCount = planStats.isEmpty ? 1 : planStats.map((p) => p.count).reduce(max);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle('Resumen de planes'),
        const SizedBox(height: 10),
        Row(children: [
          _KpiCard(
            label: 'Planes activos',
            value: '${planStats.length}',
            icon: Icons.category_rounded,
            color: _C.accent,
          ),
          const SizedBox(width: 10),
          _KpiCard(
            label: 'Ingreso total',
            value: _pesos(ingresoTotal),
            icon: Icons.attach_money_rounded,
            color: _C.primary,
          ),
        ]),
        const SizedBox(height: 20),
        _SectionTitle('Detalle por plan'),
        const SizedBox(height: 8),
        ...planStats.map((p) => _PlanCard(
              plan: p,
              totalClientes: activos.length,
              maxCount: maxCount,
            )),
        const SizedBox(height: 20),
        _SectionTitle('Tabla resumen'),
        const SizedBox(height: 8),
        _PlanTable(plans: planStats, ingresoTotal: ingresoTotal),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  COMPONENTES COMUNES
// ─────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700),
      );
}

class _KpiCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2), width: 1.2),
            boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.spaceGrotesk(color: color, fontSize: 13, fontWeight: FontWeight.w700), maxLines: 2),
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
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.cardBorder),
      ),
      child: Column(children: [
        Row(children: [
          _StatusDot(color: _C.success, label: 'Activo', count: activo),
          const SizedBox(width: 16),
          _StatusDot(color: _C.danger, label: 'Mora', count: mora),
          const SizedBox(width: 16),
          _StatusDot(color: _C.warning, label: 'Inactivo', count: inactivo),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(children: [
            if (activo > 0) Flexible(flex: activo, child: Container(height: 10, color: _C.success)),
            if (mora > 0) Flexible(flex: mora, child: Container(height: 10, color: _C.danger)),
            if (inactivo > 0) Flexible(flex: inactivo, child: Container(height: 10, color: _C.warning)),
          ]),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${(activo / t * 100).toStringAsFixed(1)}% activos',
              style: GoogleFonts.spaceGrotesk(color: _C.success, fontSize: 11, fontWeight: FontWeight.w600)),
          Text('${(mora / t * 100).toStringAsFixed(1)}% en mora',
              style: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 11, fontWeight: FontWeight.w600)),
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
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('$label ($count)', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
      ]);
}

class _BarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final bool diezmoEnabled;
  final bool isCount;
  const _BarChart({required this.data, required this.diezmoEnabled, this.isCount = false});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();
    final maxVal = data.map((d) => d['valor'] as double).reduce(max);
    if (maxVal == 0) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.cardBorder),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: data.map((d) {
                final val = d['valor'] as double;
                final pct = val / maxVal;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          isCount ? '${val.toInt()}' : _pesosShort(val),
                          style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 9, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              height: 110 * pct,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [_C.primary, _C.accent],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            if (diezmoEnabled)
                              Container(
                                height: 110 * pct * 0.10,
                                decoration: BoxDecoration(
                                  color: _C.purple.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: data
                .map((d) => Expanded(
                      child: Text(
                        d['mes'].toString(),
                        style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ))
                .toList(),
          ),
          if (diezmoEnabled) ...[
            const SizedBox(height: 10),
            Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: _C.primary, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 5),
              Text('Ingreso', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
              const SizedBox(width: 12),
              Container(width: 10, height: 10, decoration: BoxDecoration(color: _C.purple, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 5),
              Text('Diezmo 10%', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
            ]),
          ],
        ],
      ),
    );
  }

  String _pesosShort(double v) {
    if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '\$${(v / 1000).toStringAsFixed(0)}K';
    return '\$${v.toStringAsFixed(0)}';
  }
}

class _DonutChart extends StatelessWidget {
  final int activo, mora, inactivo, total;
  const _DonutChart({required this.activo, required this.mora, required this.inactivo, required this.total});

  @override
  Widget build(BuildContext context) {
    final t = total == 0 ? 1 : total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _C.cardBorder)),
      child: Row(children: [
        SizedBox(
          width: 110,
          height: 110,
          child: CustomPaint(
            painter: _DonutPainter(
              activo: activo / t,
              mora: mora / t,
              inactivo: inactivo / t,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _LegendRow(color: _C.success, label: 'Activos', count: activo, total: t),
          const SizedBox(height: 10),
          _LegendRow(color: _C.danger, label: 'En mora', count: mora, total: t),
          const SizedBox(height: 10),
          _LegendRow(color: _C.warning, label: 'Inactivos', count: inactivo, total: t),
        ]),
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
        Text('$label · $count (${(count / total * 100).toStringAsFixed(1)}%)',
            style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
      ]);
}

class _DonutPainter extends CustomPainter {
  final double activo, mora, inactivo;
  const _DonutPainter({required this.activo, required this.mora, required this.inactivo});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    const strokeWidth = 18.0;
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
    for (final seg in segments) {
      final sweep = (seg[0] as double) * 2 * pi;
      if (sweep > 0) {
        paint.color = seg[1] as Color;
        canvas.drawArc(Rect.fromCircle(center: c, radius: r), current, sweep - 0.04, false, paint);
        current += sweep;
      }
    }

    if (activo == 0 && mora == 0 && inactivo == 0) {
      paint.color = _C.cardBorder;
      canvas.drawCircle(c, r, paint);
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => false;
}

class _StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(children: [
            Text(value, style: GoogleFonts.spaceGrotesk(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10), textAlign: TextAlign.center),
          ]),
        ),
      );
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.cardBorder),
      ),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(c.planCliente, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w600))),
        Text(fecha, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
        const SizedBox(width: 8),
        Text(_pesos(c.planValor), style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 12, fontWeight: FontWeight.w600)),
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
  const _PlanCard({required this.plan, required this.totalClientes, required this.maxCount});

  @override
  Widget build(BuildContext context) {
    final pctClientes = totalClientes == 0 ? 0.0 : plan.count / totalClientes;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Text(plan.nombre, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _C.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${plan.count} clientes',
                style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pctClientes,
            minHeight: 8,
            backgroundColor: _C.cardBorder,
            valueColor: AlwaysStoppedAnimation(_C.primary),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${(pctClientes * 100).toStringAsFixed(1)}% del total', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Ingreso: ${_pesos(plan.ingresoTotal)}',
                style: GoogleFonts.spaceGrotesk(color: _C.success, fontSize: 11, fontWeight: FontWeight.w600)),
            Text('Diezmo: ${_pesos(plan.diezmo)}', style: GoogleFonts.spaceGrotesk(color: _C.purple, fontSize: 11)),
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
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _C.surfaceDim,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(13), topRight: Radius.circular(13)),
            ),
            child: Row(children: [
              Expanded(
                  flex: 3,
                  child: Text('Plan', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w700))),
              Expanded(
                  child: Text('Cli.',
                      style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center)),
              Expanded(
                  flex: 2,
                  child: Text('Ingreso',
                      style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text('Diezmo',
                      style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.right)),
            ]),
          ),
          ...plans.map((p) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: _C.cardBorder, width: 0.5))),
                child: Row(children: [
                  Expanded(flex: 3, child: Text(p.nombre, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 12))),
                  Expanded(
                      child: Text('${p.count}',
                          style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 12, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center)),
                  Expanded(
                      flex: 2,
                      child: Text(_pesosShort(p.ingresoTotal),
                          style: GoogleFonts.spaceGrotesk(color: _C.success, fontSize: 11), textAlign: TextAlign.right)),
                  Expanded(
                      flex: 2,
                      child: Text(_pesosShort(p.diezmo),
                          style: GoogleFonts.spaceGrotesk(color: _C.purple, fontSize: 11), textAlign: TextAlign.right)),
                ]),
              )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _C.surfaceDim,
              border: Border(top: BorderSide(color: _C.cardBorder, width: 1)),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(13), bottomRight: Radius.circular(13)),
            ),
            child: Row(children: [
              Expanded(
                  flex: 3,
                  child: Text('TOTAL', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 12, fontWeight: FontWeight.w700))),
              Expanded(
                  child: Text('${plans.fold(0, (s, p) => s + p.count)}',
                      style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 12, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center)),
              Expanded(
                  flex: 2,
                  child: Text(_pesosShort(ingresoTotal),
                      style: GoogleFonts.spaceGrotesk(color: _C.success, fontSize: 12, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text(_pesosShort(ingresoTotal * 0.10),
                      style: GoogleFonts.spaceGrotesk(color: _C.purple, fontSize: 12, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.right)),
            ]),
          ),
        ],
      ),
    );
  }

  String _pesosShort(double v) {
    if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return '\$${(v / 1000).toStringAsFixed(1)}K';
    return '\$${v.toStringAsFixed(0)}';
  }
}
