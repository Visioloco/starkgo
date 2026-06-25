// ════════════════════════════════════════════════════════════════
//  consumo_widgets.dart
//
//  Widgets reutilizables de consumo para:
//   • ConsumoBarCard  → barra de progreso en la card del Home
//   • ConsumoSection  → sección completa en DetalleCliente
// ════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class _C {
  static const Color primary = Color(0xFF1A73E8);
  static const Color accent = Color(0xFF00C6AE);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFE53935);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF1F5F9);
  static const Color textPri = Color(0xFF0F172A);
  static const Color textSec = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
}

// ─── Helper ──────────────────────────────────────────────────────────────────
String _fmtGB(double gb) {
  if (gb < 0.001) return '0 MB';
  if (gb < 1.0) return '${(gb * 1024).toStringAsFixed(0)} MB';
  return '${gb.toStringAsFixed(2)} GB';
}

String _mesKeyActual() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}

Future<Map<String, double>?> fetchConsumoMes(String clienteId, {String? mesKey}) async {
  final key = mesKey ?? _mesKeyActual();
  try {
    final doc = await FirebaseFirestore.instance.collection('consumo_mensual').doc('${clienteId}_$key').get();
    if (!doc.exists) return null;
    final d = doc.data()!;
    return {
      'up': ((d['totalUpBytes'] ?? 0) as num) / 1e9,
      'down': ((d['totalDownBytes'] ?? 0) as num) / 1e9,
    };
  } catch (_) {
    return null;
  }
}

// ════════════════════════════════════════════════════════════════
//  1. ConsumoBarCard — para la card del Home
//     Uso:
//       ConsumoBarCard(clienteId: c.reference.id, limiteGB: 50)
// ════════════════════════════════════════════════════════════════
class ConsumoBarCard extends StatefulWidget {
  /// ID del documento del cliente en Firestore
  final String clienteId;

  /// Límite opcional en GB para calcular % (si null, la barra
  /// muestra progreso relativo al máximo visto este mes)
  final double? limiteGB;

  const ConsumoBarCard({super.key, required this.clienteId, this.limiteGB});

  @override
  State<ConsumoBarCard> createState() => _ConsumoBarCardState();
}

class _ConsumoBarCardState extends State<ConsumoBarCard> {
  double? _upGB;
  double? _downGB;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final data = await fetchConsumoMes(widget.clienteId);
    if (!mounted) return;
    setState(() {
      _upGB = data?['up'];
      _downGB = data?['down'];
      _cargando = false;
    });
  }

  Color _colorPorGB(double gb) {
    if (gb >= 200) return _C.danger;
    if (gb >= 120) return _C.warning;
    return _C.success;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(
          height: 6,
          decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(3)),
        ),
      );
    }

    if (_upGB == null && _downGB == null) {
      // Sin datos aún — no mostrar nada para no ensuciar la card
      return const SizedBox.shrink();
    }

    final total = (_upGB ?? 0) + (_downGB ?? 0);
    final color = _colorPorGB(total);

    double pct = 0.0;
    if (widget.limiteGB != null && widget.limiteGB! > 0) {
      pct = (total / widget.limiteGB!).clamp(0.0, 1.0);
    } else {
      // Sin límite: barra siempre al 100% del color informativo
      pct = 1.0;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Fila: ícono + datos
        Row(children: [
          Icon(Icons.data_usage_rounded, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            '📶 ${_fmtGB(total)}',
            style: GoogleFonts.spaceGrotesk(color: color, fontSize: 10, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Text(
            '↑${_fmtGB(_upGB ?? 0)}  ↓${_fmtGB(_downGB ?? 0)}',
            style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 9),
          ),
        ]),
        const SizedBox(height: 4),
        // Barra
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 5,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  2. ConsumoSection — sección en DetalleCliente
//     Uso:
//       ConsumoSection(clienteId: c.reference.id)
// ════════════════════════════════════════════════════════════════
class ConsumoSection extends StatefulWidget {
  final String clienteId;

  const ConsumoSection({super.key, required this.clienteId});

  @override
  State<ConsumoSection> createState() => _ConsumoSectionState();
}

class _ConsumoSectionState extends State<ConsumoSection> {
  double? _upGB;
  double? _downGB;
  bool _cargando = true;

  // Para el gráfico de días
  List<Map<String, dynamic>> _diasData = [];
  bool _cargandoDias = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final data = await fetchConsumoMes(widget.clienteId);
    if (!mounted) return;
    setState(() {
      _upGB = data?['up'];
      _downGB = data?['down'];
      _cargando = false;
    });
    _cargarDias();
  }

  Future<void> _cargarDias() async {
    setState(() => _cargandoDias = true);
    try {
      final now = DateTime.now();
      final mesKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final snap = await FirebaseFirestore.instance
          .collection('consumo_diario')
          .where('clienteId', isEqualTo: widget.clienteId)
          .where('mes', isEqualTo: mesKey)
          .get();

      final lista = snap.docs.map((d) {
        final data = d.data();
        final upGB = ((data['totalUpBytes'] ?? 0) as num) / 1e9;
        final downGB = ((data['totalDownBytes'] ?? 0) as num) / 1e9;
        return {
          'fecha': (data['fecha'] ?? '').toString(),
          'totalGB': upGB + downGB,
          'upGB': upGB,
          'downGB': downGB,
        };
      }).toList();

      lista.sort((a, b) => (a['fecha'] as String).compareTo(b['fecha'] as String));

      if (!mounted) return;
      setState(() {
        _diasData = lista;
        _cargandoDias = false;
      });
    } catch (e) {
      debugPrint('[CONSUMO] Error días: $e');
      if (mounted) setState(() => _cargandoDias = false);
    }
  }

  String get _mesNombre {
    const meses = [
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
    return meses[DateTime.now().month];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
        border: Border.all(color: _C.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_C.primary, _C.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.data_usage_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Consumo de Datos', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
                Text('$_mesNombre ${DateTime.now().year} · Actualiza cada 30 min',
                    style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10)),
              ]),
            ),
            GestureDetector(
              onTap: _cargar,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _C.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.refresh_rounded, color: _C.primary, size: 16),
              ),
            ),
          ]),
          const SizedBox(height: 14),

          if (_cargando)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (_upGB == null && _downGB == null)
            _buildSinDatos()
          else ...[
            _buildGaugeRow(),
            const SizedBox(height: 14),
            _buildDetalleRow(),
            const SizedBox(height: 14),
            if (_cargandoDias)
              Center(
                  child: Padding(
                padding: const EdgeInsets.all(8),
                child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary),
              ))
            else if (_diasData.isNotEmpty)
              _buildGraficaDias(),
          ],
        ]),
      ),
    );
  }

  Widget _buildSinDatos() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surfaceDim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Row(children: [
        Icon(Icons.signal_wifi_statusbar_null_rounded, color: _C.textSec.withOpacity(0.4), size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sin datos este mes', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13, fontWeight: FontWeight.w600)),
            Text('El tracking comienza cuando el VPS conecta al MikroTik por primera vez.',
                style: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.7), fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildGaugeRow() {
    final total = (_upGB ?? 0) + (_downGB ?? 0);
    Color color;
    if (total >= 200)
      color = _C.danger;
    else if (total >= 120)
      color = _C.warning;
    else
      color = _C.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.08), color.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3), width: 2),
          ),
          child: Center(child: Icon(Icons.data_usage_rounded, color: color, size: 26)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total consumido este mes', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
            Text(_fmtGB(total), style: GoogleFonts.spaceGrotesk(color: color, fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (total / 200).clamp(0.0, 1.0), // referencia: 200 GB
                minHeight: 6,
                backgroundColor: color.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildDetalleRow() {
    return Row(children: [
      Expanded(
          child: _StatBox(
        icon: Icons.upload_rounded,
        color: _C.success,
        label: 'Subida',
        valor: _fmtGB(_upGB ?? 0),
      )),
      const SizedBox(width: 10),
      Expanded(
          child: _StatBox(
        icon: Icons.download_rounded,
        color: _C.accent,
        label: 'Bajada',
        valor: _fmtGB(_downGB ?? 0),
      )),
    ]);
  }

  // ─── Gráfica de barras por día ───────────────────────────────────────────
  Widget _buildGraficaDias() {
    if (_diasData.isEmpty) return const SizedBox.shrink();

    final maxGB = _diasData.fold(0.0, (m, d) => (d['totalGB'] as double) > m ? (d['totalGB'] as double) : m);
    final max = maxGB < 0.001 ? 1.0 : maxGB;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Consumo diario', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      SizedBox(
        height: 80,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: _diasData.map((d) {
            final gb = (d['totalGB'] as double);
            final pct = (gb / max).clamp(0.0, 1.0);
            final dia = (d['fecha'] as String).split('-').last;
            Color barColor;
            if (pct >= 0.75)
              barColor = _C.danger;
            else if (pct >= 0.4)
              barColor = _C.warning;
            else
              barColor = _C.primary;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Flexible(
                    child: FractionallySizedBox(
                      heightFactor: pct < 0.05 ? 0.05 : pct,
                      child: Container(
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(dia, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 7), textAlign: TextAlign.center),
                ]),
              ),
            );
          }).toList(),
        ),
      ),
    ]);
  }
}

// ─── Caja de estadística ─────────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, valor;
  const _StatBox({required this.icon, required this.color, required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10, fontWeight: FontWeight.w500)),
          Text(valor, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}
