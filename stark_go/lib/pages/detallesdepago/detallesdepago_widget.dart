import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'detallesdepago_model.dart';
export 'detallesdepago_model.dart';

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
  static const Color nequi = Color(0xFF6A0DAD);
  static const Color efectivo = Color(0xFF22C55E);
}

// ─────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────
String _formatMonto(int? valor) {
  if (valor == null) return '0';
  final str = valor.toString();
  final buf = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
    buf.write(str[i]);
  }
  return buf.toString();
}

// Elige icono y color según índice (simula método de pago visual)
_PayBadge _badgeForIndex(int index) {
  final options = [
    _PayBadge(icon: Icons.account_balance_wallet_rounded, color: _C.nequi, label: 'Nequi'),
    _PayBadge(icon: Icons.payments_rounded, color: _C.efectivo, label: 'Efectivo'),
    _PayBadge(icon: Icons.credit_card_rounded, color: _C.primary, label: 'Transferencia'),
    _PayBadge(icon: Icons.smartphone_rounded, color: _C.warning, label: 'Daviplata'),
  ];
  return options[index % options.length];
}

class _PayBadge {
  final IconData icon;
  final Color color;
  final String label;
  const _PayBadge({required this.icon, required this.color, required this.label});
}

// ─────────────────────────────────────────────
//  MAIN WIDGET
// ─────────────────────────────────────────────
class DetallesdepagoWidget extends StatefulWidget {
  const DetallesdepagoWidget({super.key, this.refcliente});

  final DocumentReference? refcliente;

  static String routeName = 'detallesdepago';
  static String routePath = 'detallesdepago';

  @override
  State<DetallesdepagoWidget> createState() => _DetallesdepagoWidgetState();
}

class _DetallesdepagoWidgetState extends State<DetallesdepagoWidget> {
  late DetallesdepagoModel _model;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DetallesdepagoModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReportepagoRecord>>(
      stream: queryReportepagoRecord(
        queryBuilder: (q) => q.where('refcliente', isEqualTo: widget.refcliente),
      ),
      builder: (context, snapshot) {
        // ── Loading ──
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: _C.surfaceDim,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(_C.primary),
                    strokeWidth: 2.5,
                  ),
                  const SizedBox(height: 14),
                  Text('Cargando pagos...', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13)),
                ],
              ),
            ),
          );
        }

        final pagos = snapshot.data!;
        final totalPagado = pagos.fold<int>(0, (sum, p) => sum + (p.valor ?? 0));

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: _C.surfaceDim,
            body: SafeArea(
              child: Column(
                children: [
                  // ── TOP BAR ──
                  _buildTopBar(context),

                  // ── RESUMEN ──
                  if (pagos.isNotEmpty)
                    _buildResumen(pagos.length, totalPagado).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, end: 0),

                  // ── LISTA ──
                  Expanded(
                    child: pagos.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: const EdgeInsets.only(top: 8, bottom: 24),
                            itemCount: pagos.length,
                            itemBuilder: (context, i) => _PagoCard(
                              pago: pagos[i],
                              index: i,
                              badge: _badgeForIndex(i),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────
  //  TOP BAR
  // ─────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.safePop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.textPri, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Historial de Pagos',
                    style: GoogleFonts.spaceGrotesk(
                      color: _C.textPri,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    )),
                Text('Registro de cobros realizados', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  RESUMEN TOTAL
  // ─────────────────────────────────────────
  Widget _buildResumen(int cantidad, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_C.dark, Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: _C.dark.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            // Icono
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_C.primary, _C.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            // Texto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total recaudado', style: GoogleFonts.spaceGrotesk(color: Colors.white54, fontSize: 11)),
                  Text('\$${_formatMonto(total)}',
                      style: GoogleFonts.spaceGrotesk(
                        color: _C.accent,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      )),
                ],
              ),
            ),
            // Cantidad
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
              ),
              child: Column(
                children: [
                  Text('$cantidad',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      )),
                  Text('pagos', style: GoogleFonts.spaceGrotesk(color: Colors.white54, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  EMPTY STATE
  // ─────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _C.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_outlined, color: _C.primary, size: 36),
          ),
          const SizedBox(height: 14),
          Text('Sin pagos registrados', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 14)),
          const SizedBox(height: 4),
          Text('Los pagos aparecerán aquí', style: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.6), fontSize: 12)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CARD DE PAGO
// ─────────────────────────────────────────────
class _PagoCard extends StatelessWidget {
  final ReportepagoRecord pago;
  final int index;
  final _PayBadge badge;

  const _PagoCard({
    required this.pago,
    required this.index,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.border, width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── FILA SUPERIOR: ícono + nombre + monto ──
              Row(
                children: [
                  // Ícono de método de pago
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: badge.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: badge.color.withOpacity(0.25), width: 1),
                    ),
                    child: Icon(badge.icon, color: badge.color, size: 26),
                  ),
                  const SizedBox(width: 12),

                  // Nombre + método
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pago.nombrecliente,
                          style: GoogleFonts.spaceGrotesk(
                            color: _C.textPri,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: badge.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(badge.icon, color: badge.color, size: 10),
                              const SizedBox(width: 4),
                              Text(badge.label,
                                  style: GoogleFonts.spaceGrotesk(
                                    color: badge.color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Monto
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${_formatMonto(pago.valor)}',
                        style: GoogleFonts.spaceGrotesk(
                          color: _C.success,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text('COP', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Divider(color: _C.border, height: 1),
              const SizedBox(height: 12),

              // ── FILA INFERIOR: referencia + fecha + comentario ──
              Row(
                children: [
                  // Referencia
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.tag_rounded,
                      iconColor: _C.primary,
                      label: 'Referencia',
                      value: pago.ref,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Fecha
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.calendar_today_rounded,
                      iconColor: _C.warning,
                      label: 'Fecha',
                      value: pago.fecha != null
                          ? dateTimeFormat(
                              "d/MM/yyyy",
                              pago.fecha!,
                              locale: FFLocalizations.of(context).languageCode,
                            )
                          : '-',
                    ),
                  ),
                ],
              ),

              // Comentario (solo si existe y no es el default)
              if (pago.comentario.isNotEmpty && pago.comentario != 'Sin comentario') ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _C.surfaceDim,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _C.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.comment_rounded, color: _C.textSec, size: 13),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pago.comentario,
                          style: GoogleFonts.spaceGrotesk(
                            color: _C.textSec,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms).slideY(begin: 0.04, end: 0);
  }
}

// ─────────────────────────────────────────────
//  CHIP DE INFO (referencia / fecha)
// ─────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _C.surfaceDim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.spaceGrotesk(
                      color: _C.textSec,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    )),
                Text(
                  value,
                  style: GoogleFonts.spaceGrotesk(
                    color: _C.textPri,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
