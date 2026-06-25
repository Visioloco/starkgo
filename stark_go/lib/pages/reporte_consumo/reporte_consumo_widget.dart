import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ─── Paleta (igual que el resto de la app) ───────────────────────────────────
class _C {
  static const Color primary = Color(0xFF1A73E8);
  static const Color accent = Color(0xFF00C6AE);
  static const Color danger = Color(0xFFE53935);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF22C55E);
  static const Color dark = Color(0xFF0F172A);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF1F5F9);
  static const Color textPri = Color(0xFF0F172A);
  static const Color textSec = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color purple = Color(0xFF7C3AED);
}

// ─── Modelo ──────────────────────────────────────────────────────────────────
class _ConsumoCliente {
  final String clienteId;
  final String nombre;
  final String ip;
  final double upGB;
  final double downGB;
  double get totalGB => upGB + downGB;

  const _ConsumoCliente({
    required this.clienteId,
    required this.nombre,
    required this.ip,
    required this.upGB,
    required this.downGB,
  });

  factory _ConsumoCliente.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _ConsumoCliente(
      clienteId: (d['clienteId'] ?? '').toString(),
      nombre: (d['nombre'] ?? 'Sin nombre').toString(),
      ip: (d['ip'] ?? '').toString(),
      upGB: ((d['totalUpBytes'] ?? 0) as num) / 1e9,
      downGB: ((d['totalDownBytes'] ?? 0) as num) / 1e9,
    );
  }
}

// ─── Widget principal ─────────────────────────────────────────────────────────
class ReporteConsumoWidget extends StatefulWidget {
  const ReporteConsumoWidget({super.key});
  static const String routeName = 'ReporteConsumo';
  static const String routePath = 'reporteConsumo';

  @override
  State<ReporteConsumoWidget> createState() => _ReporteConsumoWidgetState();
}

class _ReporteConsumoWidgetState extends State<ReporteConsumoWidget> {
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  late int _anioSel;
  late int _mesSel;

  bool _cargando = false;
  List<_ConsumoCliente> _datos = [];
  double _maxGB = 1.0; // para escalar barras

  // Meses disponibles: mes actual y los 5 anteriores
  late List<Map<String, int>> _mesesDisponibles;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anioSel = now.year;
    _mesSel = now.month;
    _mesesDisponibles = _generarMeses(now);
    _cargar();
  }

  List<Map<String, int>> _generarMeses(DateTime now) {
    final lista = <Map<String, int>>[];
    for (int i = 0; i < 6; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      lista.add({'anio': d.year, 'mes': d.month});
    }
    return lista;
  }

  String _mesKey(int anio, int mes) => '$anio-${mes.toString().padLeft(2, '0')}';

  String _nombreMes(int mes) {
    const nombres = [
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
      'Diciembre',
    ];
    return nombres[mes];
  }

  Future<void> _cargar() async {
    if (_uid.isEmpty) return;
    setState(() => _cargando = true);
    try {
      final key = _mesKey(_anioSel, _mesSel);
      final snap = await FirebaseFirestore.instance
          .collection('consumo_mensual')
          .where('propietarioUid', isEqualTo: _uid)
          .where('mes', isEqualTo: key)
          .get();

      final lista = snap.docs.map((d) => _ConsumoCliente.fromDoc(d)).toList();
      lista.sort((a, b) => b.totalGB.compareTo(a.totalGB));

      double max = 0;
      for (final c in lista) {
        if (c.totalGB > max) max = c.totalGB;
      }

      setState(() {
        _datos = lista;
        _maxGB = max < 0.001 ? 1.0 : max;
        _cargando = false;
      });
    } catch (e) {
      debugPrint('[CONSUMO] Error: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ─── Formato ────────────────────────────────────────────────────────────────
  String _fmtGB(double gb) {
    if (gb < 1.0) return '${(gb * 1024).toStringAsFixed(0)} MB';
    return '${gb.toStringAsFixed(2)} GB';
  }

  Color _colorPorConsumo(double gb, double max) {
    if (gb >= 200) return _C.danger;
    if (gb >= 120) return _C.warning;
    return _C.success;
  }

  // ─── Resumen total ──────────────────────────────────────────────────────────
  double get _totalUpGB => _datos.fold(0.0, (s, c) => s + c.upGB);
  double get _totalDownGB => _datos.fold(0.0, (s, c) => s + c.downGB);
  double get _totalGB => _totalUpGB + _totalDownGB;

  // ─── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surfaceDim,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          _buildSelectorMes(),
          if (!_cargando) _buildResumenCards(),
          Expanded(child: _cargando ? _buildLoading() : _buildLista()),
        ]),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
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
            Text('Reporte de Consumo', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 18, fontWeight: FontWeight.w800)),
            Text('Datos por cliente · ${_nombreMes(_mesSel)} $_anioSel', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
          ]),
        ),
        // Botón refrescar
        GestureDetector(
          onTap: _cargar,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _C.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.primary.withOpacity(0.3)),
            ),
            child: const Icon(Icons.refresh_rounded, color: _C.primary, size: 20),
          ),
        ),
      ]),
    );
  }

  // ─── Selector horizontal de meses ───────────────────────────────────────────
  Widget _buildSelectorMes() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _mesesDisponibles.length,
        itemBuilder: (_, i) {
          final m = _mesesDisponibles[i];
          final anio = m['anio']!;
          final mes = m['mes']!;
          final sel = anio == _anioSel && mes == _mesSel;
          return GestureDetector(
            onTap: () {
              setState(() {
                _anioSel = anio;
                _mesSel = mes;
              });
              _cargar();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: sel
                    ? const LinearGradient(colors: [_C.primary, _C.accent], begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                color: sel ? null : _C.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: sel ? Colors.transparent : _C.border,
                  width: 1.2,
                ),
                boxShadow: sel ? [BoxShadow(color: _C.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
              ),
              child: Text(
                i == 0 ? 'Este mes' : '${_nombreMes(mes).substring(0, 3)} $anio',
                style: GoogleFonts.spaceGrotesk(
                  color: sel ? Colors.white : _C.textSec,
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Cards de resumen ───────────────────────────────────────────────────────
  Widget _buildResumenCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        _ResumenCard(
          label: 'Total consumido',
          valor: _fmtGB(_totalGB),
          icon: Icons.data_usage_rounded,
          color: _C.primary,
        ),
        const SizedBox(width: 8),
        _ResumenCard(
          label: 'Subida total',
          valor: _fmtGB(_totalUpGB),
          icon: Icons.upload_rounded,
          color: _C.success,
        ),
        const SizedBox(width: 8),
        _ResumenCard(
          label: 'Bajada total',
          valor: _fmtGB(_totalDownGB),
          icon: Icons.download_rounded,
          color: _C.accent,
        ),
      ]),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildLoading() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: _C.primary, strokeWidth: 2.5),
        const SizedBox(height: 14),
        Text('Cargando consumo...', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13)),
      ]),
    );
  }

  Widget _buildLista() {
    if (_datos.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.data_usage_rounded, size: 64, color: _C.textSec.withOpacity(0.2)),
          const SizedBox(height: 14),
          Text('Sin datos de consumo', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('No hay registros para ${_nombreMes(_mesSel)} $_anioSel.\nVerifica que el tracking esté activo en el VPS.',
              style: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.6), fontSize: 12), textAlign: TextAlign.center),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _datos.length,
      itemBuilder: (_, i) {
        final c = _datos[i];
        final col = _colorPorConsumo(c.totalGB, _maxGB);
        final pct = (c.totalGB / 200).clamp(0.0, 1.0);
        return _ConsumoCard(
          rank: i + 1,
          cliente: c,
          color: col,
          porcentaje: pct,
          fmtGB: _fmtGB,
        ).animate().fadeIn(duration: 280.ms, delay: (i * 30).ms).slideY(begin: 0.04, end: 0);
      },
    );
  }
}

// ─── Card de resumen ──────────────────────────────────────────────────────────
class _ResumenCard extends StatelessWidget {
  final String label, valor;
  final IconData icon;
  final Color color;
  const _ResumenCard({required this.label, required this.valor, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25), width: 1.2),
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 6),
          Text(valor,
              style: GoogleFonts.spaceGrotesk(color: color, fontSize: 14, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 9, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 2),
        ]),
      ),
    );
  }
}

// ─── Card de consumo por cliente ─────────────────────────────────────────────
class _ConsumoCard extends StatelessWidget {
  final int rank;
  final _ConsumoCliente cliente;
  final Color color;
  final double porcentaje;
  final String Function(double) fmtGB;

  const _ConsumoCard({
    required this.rank,
    required this.cliente,
    required this.color,
    required this.porcentaje,
    required this.fmtGB,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25), width: 1.2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Ranking badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rank <= 3 ? color.withOpacity(0.15) : _C.surfaceDim,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: GoogleFonts.spaceGrotesk(
                  color: rank <= 3 ? color : _C.textSec,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cliente.nombre,
                  style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Row(children: [
                Icon(Icons.router_rounded, size: 10, color: _C.textSec),
                const SizedBox(width: 3),
                Text(cliente.ip, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
              ]),
            ]),
          ),
          // Total GB badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              fmtGB(cliente.totalGB),
              style: GoogleFonts.spaceGrotesk(color: color, fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ]),
        const SizedBox(height: 10),

        // Barra de progreso total
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: porcentaje,
            minHeight: 7,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 8),

        // Detalle subida / bajada
        Row(children: [
          _MiniStat(icon: Icons.upload_rounded, color: _C.success, label: '↑ Sub', valor: fmtGB(cliente.upGB)),
          const SizedBox(width: 12),
          _MiniStat(icon: Icons.download_rounded, color: _C.accent, label: '↓ Baj', valor: fmtGB(cliente.downGB)),
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
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, color: color, size: 12),
      ),
      const SizedBox(width: 5),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 9, fontWeight: FontWeight.w500)),
        Text(valor, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    ]);
  }
}
