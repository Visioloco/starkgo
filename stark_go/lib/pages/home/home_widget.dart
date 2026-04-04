import 'package:stark_go/pages/ConfigMikroTik/config_mikro_tik_widget.dart';
import 'package:stark_go/pages/lista_equipos/lista_equipos_widget.dart';
import 'package:stark_go/pages/lista_starlinks/lista_starlinks_widget.dart';
import 'package:stark_go/pages/planes/planes_widget.dart';
import 'package:stark_go/pages/config_ultra_msg/config_ultra_msg_widget.dart';

import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:text_search/text_search.dart';
import 'home_model.dart';
export 'home_model.dart';

// ─────────────────────────────────────────────
//  PALETA
// ─────────────────────────────────────────────
class _AppColors {
  static const Color primary = Color(0xFF1A73E8);
  static const Color accent = Color(0xFF00C6AE);
  static const Color danger = Color(0xFFE53935);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF22C55E);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF1F5F9);
  static const Color textPri = Color(0xFF0F172A);
  static const Color textSec = Color(0xFF64748B);
  static const Color drawerBg = Color(0xFF0F172A);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color purple = Color(0xFF7C3AED);
}

// ─────────────────────────────────────────────
//  HELPER
// ─────────────────────────────────────────────
double _parsePlanCliente(dynamic plan) {
  if (plan == null) return 50000.0;
  if (plan is double) return plan;
  if (plan is int) return plan.toDouble();
  if (plan is num) return plan.toDouble();
  final cleaned = plan.toString().replaceAll('.', '').replaceAll(',', '').trim();
  return double.tryParse(cleaned) ?? 50000.0;
}

// ─────────────────────────────────────────────
//  MODELO STARLINK
// ─────────────────────────────────────────────
class _StarlinkInfo {
  final String id;
  final String nombre;
  final String ubicacion;
  final bool activo;
  final int clientesCount;

  const _StarlinkInfo({
    required this.id,
    required this.nombre,
    required this.ubicacion,
    required this.activo,
    required this.clientesCount,
  });

  factory _StarlinkInfo.fromDoc(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _StarlinkInfo(
      id: doc.id,
      nombre: d['nombre'] ?? 'Sin nombre',
      ubicacion: d['ubicacion'] ?? '',
      activo: d['activo'] ?? false,
      clientesCount: d['clientes_count'] ?? 0,
    );
  }
}

// ─────────────────────────────────────────────
//  CHIP DE STARLINK
// ─────────────────────────────────────────────
class _StarlinkChip extends StatelessWidget {
  final _StarlinkInfo starlink;
  final bool selected;
  final VoidCallback onTap;

  const _StarlinkChip({
    required this.starlink,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = starlink.activo ? _AppColors.primary : _AppColors.textSec;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [_AppColors.primary, _AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : _AppColors.surface,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected ? Colors.transparent : (starlink.activo ? _AppColors.primary.withOpacity(0.3) : _AppColors.cardBorder),
            width: 1.4,
          ),
          boxShadow: selected
              ? [BoxShadow(color: _AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: selected ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.satellite_alt_rounded, size: 15, color: selected ? Colors.white : color),
            ),
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: starlink.activo ? _AppColors.success : _AppColors.textSec,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? _AppColors.primary : _AppColors.surface,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(
              starlink.nombre,
              style: GoogleFonts.spaceGrotesk(
                color: selected ? Colors.white : _AppColors.textPri,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.people_alt_rounded, size: 9, color: selected ? Colors.white70 : _AppColors.textSec),
              const SizedBox(width: 3),
              Text(
                '${starlink.clientesCount}',
                style: GoogleFonts.spaceGrotesk(
                  color: selected ? Colors.white70 : _AppColors.textSec,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (starlink.ubicacion.isNotEmpty) ...[
                Text(
                  '  ·  ${starlink.ubicacion}',
                  style: GoogleFonts.spaceGrotesk(
                    color: selected ? Colors.white60 : _AppColors.textSec.withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ]),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CHIP "TODOS"
// ─────────────────────────────────────────────
class _AllChip extends StatelessWidget {
  final bool selected;
  final int totalClients;
  final VoidCallback onTap;

  const _AllChip({
    required this.selected,
    required this.totalClients,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _AppColors.textPri : _AppColors.surface,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected ? Colors.transparent : _AppColors.cardBorder,
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: selected ? _AppColors.textPri.withOpacity(0.2) : Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.apps_rounded, size: 15, color: selected ? Colors.white : _AppColors.textSec),
          const SizedBox(width: 6),
          Text(
            'Todos',
            style: GoogleFonts.spaceGrotesk(
              color: selected ? Colors.white : _AppColors.textPri,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: selected ? Colors.white.withOpacity(0.2) : _AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$totalClients',
              style: GoogleFonts.spaceGrotesk(
                color: selected ? Colors.white : _AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CLIENT CARD
// ─────────────────────────────────────────────
class _ClientCard extends StatelessWidget {
  final ClientesRecord cliente;
  final VoidCallback onTap;
  final Future<void> Function() onWhatsapp;

  const _ClientCard({
    required this.cliente,
    required this.onTap,
    required this.onWhatsapp,
  });

  Color get _statusColor {
    switch (cliente.status) {
      case 'activo':
        return _AppColors.success;
      case 'mora':
        return _AppColors.danger;
      case 'inactivo':
        return _AppColors.warning;
      default:
        return _AppColors.textSec;
    }
  }

  String get _statusLabel {
    switch (cliente.status) {
      case 'activo':
        return 'Activo';
      case 'mora':
        return 'Mora';
      case 'inactivo':
        return 'Inactivo';
      default:
        return cliente.status ?? '-';
    }
  }

  IconData get _statusIcon {
    switch (cliente.status) {
      case 'activo':
        return Icons.wifi_rounded;
      case 'mora':
        return Icons.warning_amber_rounded;
      case 'inactivo':
        return Icons.wifi_off_rounded;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: _AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _statusColor.withOpacity(0.35), width: 1.4),
              boxShadow: [BoxShadow(color: _statusColor.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [_statusColor.withOpacity(0.85), _statusColor.withOpacity(0.5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      (cliente.nombre.isNotEmpty ? cliente.nombre[0] : '?').toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      '${cliente.nombre} ${cliente.apellido ?? ''}',
                      style: GoogleFonts.spaceGrotesk(color: _AppColors.textPri, fontSize: 15, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    _InfoRow(icon: Icons.agriculture_rounded, label: cliente.nombrefinca, color: _AppColors.textSec),
                    const SizedBox(height: 2),
                    _InfoRow(icon: Icons.phone_rounded, label: cliente.numero.toString(), color: _AppColors.primary),
                    const SizedBox(height: 2),
                    _InfoRow(icon: Icons.router_rounded, label: cliente.ipatn, color: _AppColors.accent),
                    if (cliente.starlinkNombre != null && cliente.starlinkNombre!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.satellite_alt_rounded, size: 11, color: _AppColors.primary.withOpacity(0.7)),
                        const SizedBox(width: 3),
                        Text(
                          cliente.starlinkNombre!,
                          style: GoogleFonts.spaceGrotesk(
                            color: _AppColors.primary.withOpacity(0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ]),
                    ],
                  ]),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _statusColor.withOpacity(0.4), width: 1),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_statusIcon, color: _statusColor, size: 11),
                        const SizedBox(width: 4),
                        Text(_statusLabel, style: GoogleFonts.spaceGrotesk(color: _statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: onWhatsapp,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: const Color(0xFF25D366), borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 11),
                          const SizedBox(width: 4),
                          Text('WA', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('CC: ${cliente.cc}', style: GoogleFonts.spaceGrotesk(color: _AppColors.textSec, fontSize: 10)),
                  ],
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoRow({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label, style: GoogleFonts.spaceGrotesk(color: _AppColors.textSec, fontSize: 11.5), overflow: TextOverflow.ellipsis),
        ),
      ]);
}

// ─────────────────────────────────────────────
//  STAT CARD
// ─────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, count;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.count, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.09),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.25), width: 1.2),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 6),
            Text(count, style: GoogleFonts.spaceGrotesk(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.spaceGrotesk(color: _AppColors.textSec, fontSize: 10, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────
//  DRAWER ITEM
// ─────────────────────────────────────────────
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final Color? iconColor;
  final String? badge;

  const _DrawerItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
    this.iconColor,
    this.badge,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Material(
          color: active ? _AppColors.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            splashColor: _AppColors.primary.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: active ? _AppColors.primary.withOpacity(0.2) : (iconColor ?? Colors.white).withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: active ? _AppColors.primary : (iconColor ?? Colors.white70), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: GoogleFonts.spaceGrotesk(
                        color: active ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      )),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _AppColors.accent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _AppColors.accent.withOpacity(0.4)),
                    ),
                    child:
                        Text(badge!, style: GoogleFonts.spaceGrotesk(color: _AppColors.accent, fontSize: 10, fontWeight: FontWeight.w700)),
                  )
                else
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 13),
              ]),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────
//  DRAWER SECTION HEADER
// ─────────────────────────────────────────────
class _DrawerSectionHeader extends StatelessWidget {
  final String title;
  const _DrawerSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(26, 10, 26, 4),
        child: Text(
          title.toUpperCase(),
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white24,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );
}

// ═════════════════════════════════════════════
//  MAIN WIDGET
// ═════════════════════════════════════════════
class HomeWidget extends StatefulWidget {
  const HomeWidget({super.key});
  static String routeName = 'Home';
  static String routePath = 'home';

  @override
  State<HomeWidget> createState() => _HomeWidgetState();
}

class _HomeWidgetState extends State<HomeWidget> with TickerProviderStateMixin {
  late HomeModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _drawerCtrl;
  late Animation<double> _drawerAnim;
  bool _drawerOpen = false;

  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSearching = false;
  List<ClientesRecord> _searchResults = [];

  List<_StarlinkInfo> _starlinks = [];
  String? _selectedStarlinkId;
  bool _starlinksCargadas = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomeModel());
    _drawerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _drawerAnim = CurvedAnimation(parent: _drawerCtrl, curve: Curves.easeInOutCubic);
    _cargarStarlinks();
  }

  @override
  void dispose() {
    _drawerCtrl.dispose();
    _searchCtrl.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _cargarStarlinks() async {
    final snap = await FirebaseFirestore.instance.collection('starlinks').orderBy('nombre').get();
    if (mounted) {
      setState(() {
        _starlinks = snap.docs.map((d) => _StarlinkInfo.fromDoc(d)).toList();
        _starlinksCargadas = true;
      });
    }
  }

  void _toggleDrawer() {
    setState(() => _drawerOpen = !_drawerOpen);
    _drawerOpen ? _drawerCtrl.forward() : _drawerCtrl.reverse();
    FFAppState().drawer = _drawerOpen;
  }

  void _onSearchChanged(String query, List<ClientesRecord> allClients) {
    EasyDebounce.debounce('search', const Duration(milliseconds: 400), () {
      if (query.trim().isEmpty) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
        return;
      }
      final base = _selectedStarlinkId != null ? allClients.where((c) => c.starlinkId == _selectedStarlinkId).toList() : allClients;
      final results = TextSearch(
        base.map((r) => TextSearchItem.fromTerms(r, [r.nombre, r.apellido ?? '', r.nombrefinca, r.ipatn])).toList(),
      ).search(query).map((r) => r.object).toList();
      setState(() {
        _isSearching = true;
        _searchResults = results;
      });
    });
  }

  Future<void> _sendWhatsapp(BuildContext ctx, String nombre, int numero, double planCliente) async {
    final ok = await showDialog<bool>(
          context: ctx,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Reporte de Pago', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
            content: Text('Enviar reporte de pago a $nombre vía WhatsApp?', style: GoogleFonts.spaceGrotesk()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _AppColors.textSec)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Enviar', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (ok) {
      final url = await actions.generarMensajeWhatsapp(nombre, numero, planCliente);
      if (url != null) await launchURL(url);
    }
  }

  // ═══════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    return StreamBuilder<List<ClientesRecord>>(
      stream: queryClientesRecord(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: _AppColors.surfaceDim,
            body: Center(child: CircularProgressIndicator(color: _AppColors.primary, strokeWidth: 2.5)),
          );
        }

        final allClients = snapshot.data!;
        final filteredByStarlink =
            _selectedStarlinkId != null ? allClients.where((c) => c.starlinkId == _selectedStarlinkId).toList() : allClients;
        final displayList = _isSearching ? _searchResults : filteredByStarlink;

        final moraCount = filteredByStarlink.where((c) => c.status == 'mora').length;
        final inactivoCount = filteredByStarlink.where((c) => c.status == 'inactivo').length;
        final activoCount = filteredByStarlink.where((c) => c.status == 'activo').length;

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            if (_drawerOpen) _toggleDrawer();
          },
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: _AppColors.surfaceDim,
            body: Stack(children: [
              _buildDrawer(context, allClients),
              AnimatedBuilder(
                animation: _drawerAnim,
                builder: (ctx, child) {
                  final slide = _drawerAnim.value * 270.0;
                  final scale = 1.0 - _drawerAnim.value * 0.07;
                  final radius = _drawerAnim.value * 28.0;
                  return Transform(
                    transform: Matrix4.identity()
                      ..translate(slide)
                      ..scale(scale),
                    alignment: Alignment.centerLeft,
                    child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: child),
                  );
                },
                child: _buildMainContent(
                  context,
                  allClients,
                  filteredByStarlink,
                  activoCount,
                  moraCount,
                  inactivoCount,
                  displayList,
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────
  //  DRAWER  ← método completo y correcto
  // ─────────────────────────────────────────
  Widget _buildDrawer(BuildContext context, List<ClientesRecord> allClients) {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: 290,
      child: Container(
        decoration: const BoxDecoration(color: _AppColors.drawerBg),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_AppColors.primary, _AppColors.accent]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.wifi_tethering_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('StarkGo', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('Panel de gestión', style: GoogleFonts.spaceGrotesk(color: Colors.white38, fontSize: 11)),
                  ]),
                ]),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Divider(color: Colors.white.withOpacity(0.08), height: 1),
              ),

              // ── Items con scroll ─────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _DrawerSectionHeader(title: 'Principal'),
                      _DrawerItem(
                        icon: Icons.dashboard_rounded,
                        label: 'Inicio',
                        active: true,
                        onTap: _toggleDrawer,
                      ),
                      _DrawerItem(
                        icon: Icons.people_alt_rounded,
                        label: 'Clientes',
                        onTap: () {
                          _toggleDrawer();
                          context.pushNamed(ListaclientesWidget.routeName);
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.add_card_rounded,
                        label: 'Planes',
                        onTap: () {
                          _toggleDrawer();
                          context.pushNamed(PlanesWidget.routeName);
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.router_rounded,
                        label: 'Equipos',
                        onTap: () {
                          _toggleDrawer();
                          context.pushNamed(ListaEquiposWidget.routeName);
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.satellite_alt_rounded,
                        label: 'Starlinks',
                        onTap: () {
                          _toggleDrawer();
                          context.pushNamed(ListaStarlinksWidget.routeName);
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.warning_amber_rounded,
                        label: 'Mora',
                        iconColor: _AppColors.warning,
                        onTap: () async {
                          _toggleDrawer();
                          final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: Text('Actualizar Mora', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
                                  content: Text('¿Confirmas que hoy es el día 24 del mes?', style: GoogleFonts.spaceGrotesk()),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('No'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _AppColors.danger,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => Navigator.pop(context, true),
                                      child: Text('Sí, actualizar', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;

                          if (ok) {
                            final allC = await queryClientesRecordOnce();
                            final res = await actions.actualizarMoraPorBoton(allC.map((e) => e.reference).toList());
                            if (mounted) {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: Text('Mora actualizada', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
                                  content: Text(res ?? '', style: GoogleFonts.spaceGrotesk()),
                                  actions: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _AppColors.primary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => Navigator.pop(context),
                                      child: Text('Ok', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.bar_chart_rounded,
                        label: 'Informes',
                        onTap: () {},
                      ),
                      const _DrawerSectionHeader(title: 'Configuración'),
                      _DrawerItem(
                        icon: Icons.chat_rounded,
                        label: 'WhatsApp · UltraMsg',
                        iconColor: const Color(0xFF25D366),
                        onTap: () {
                          _toggleDrawer();
                          context.pushNamed(ConfigUltraMsgWidget.routeName);
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.router_outlined,
                        label: 'Config. MikroTik',
                        iconColor: _AppColors.accent,
                        badge: 'Auto',
                        onTap: () {
                          _toggleDrawer();
                          context.pushNamed(ConfigMikroTikWidget.routeName);
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.settings_rounded,
                        label: 'Configuración',
                        onTap: () {},
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // ── Footer fijo ──────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Divider(color: Colors.white.withOpacity(0.08), height: 1),
              ),

              _DrawerItem(
                icon: Icons.logout_rounded,
                label: 'Cerrar sesión',
                iconColor: _AppColors.danger,
                onTap: () {},
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('v1.0.1', style: GoogleFonts.spaceGrotesk(color: Colors.white24, fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  MAIN CONTENT
  // ─────────────────────────────────────────
  Widget _buildMainContent(
    BuildContext context,
    List<ClientesRecord> allClients,
    List<ClientesRecord> filteredClients,
    int activoCount,
    int moraCount,
    int inactivoCount,
    List<ClientesRecord> displayList,
  ) {
    return Container(
      color: _AppColors.surfaceDim,
      child: SafeArea(
        child: Column(children: [
          _buildTopBar(context),
          const SizedBox(height: 4),
          _buildStatsRow(filteredClients.length, activoCount, moraCount, inactivoCount),
          const SizedBox(height: 10),
          if (_starlinksCargadas && _starlinks.isNotEmpty) _buildStarlinkChips(allClients),
          const SizedBox(height: 8),
          _buildSearchBar(context, filteredClients),
          const SizedBox(height: 6),
          if (_selectedStarlinkId != null) _buildFilterBanner(allClients),
          Expanded(
            child: displayList.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: displayList.length,
                    itemBuilder: (ctx, i) {
                      final c = displayList[i];
                      return _ClientCard(
                        cliente: c,
                        onTap: () => context.pushNamed(
                          DetalleClienteWidget.routeName,
                          queryParameters: {'rf': serializeParam(c.reference, ParamType.DocumentReference)}.withoutNulls,
                        ),
                        onWhatsapp: () => _sendWhatsapp(
                          context,
                          c.nombre,
                          c.numero,
                          _parsePlanCliente(c.planCliente),
                        ),
                      ).animate().fadeIn(duration: 280.ms, delay: (i * 35).ms);
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  CHIPS DE STARLINK
  // ─────────────────────────────────────────
  Widget _buildStarlinkChips(List<ClientesRecord> allClients) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _AllChip(
            selected: _selectedStarlinkId == null,
            totalClients: allClients.length,
            onTap: () => setState(() {
              _selectedStarlinkId = null;
              _isSearching = false;
              _searchResults = [];
              _searchCtrl.clear();
            }),
          ),
          ..._starlinks.map((sl) => _StarlinkChip(
                starlink: sl,
                selected: _selectedStarlinkId == sl.id,
                onTap: () => setState(() {
                  _selectedStarlinkId = _selectedStarlinkId == sl.id ? null : sl.id;
                  _isSearching = false;
                  _searchResults = [];
                  _searchCtrl.clear();
                }),
              )),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  BANNER FILTRO ACTIVO
  // ─────────────────────────────────────────
  Widget _buildFilterBanner(List<ClientesRecord> allClients) {
    final sl = _starlinks.firstWhere(
      (s) => s.id == _selectedStarlinkId,
      orElse: () => _StarlinkInfo(id: '', nombre: '', ubicacion: '', activo: false, clientesCount: 0),
    );
    final count = allClients.where((c) => c.starlinkId == _selectedStarlinkId).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEFF6FF), Color(0xFFE0F7F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _AppColors.primary.withOpacity(0.2), width: 1),
        ),
        child: Row(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_AppColors.primary, _AppColors.accent]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.satellite_alt_rounded, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Filtrando: ${sl.nombre}',
                  style: GoogleFonts.spaceGrotesk(color: _AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
              Text('$count cliente${count != 1 ? 's' : ''} en esta Starlink',
                  style: GoogleFonts.spaceGrotesk(color: _AppColors.textSec, fontSize: 10)),
            ]),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _selectedStarlinkId = null;
              _isSearching = false;
              _searchResults = [];
              _searchCtrl.clear();
            }),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Color(0x1A1A73E8), shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 14, color: _AppColors.primary),
            ),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  TOP BAR
  // ─────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        GestureDetector(
          onTap: _toggleDrawer,
          child: AnimatedBuilder(
            animation: _drawerAnim,
            builder: (_, __) => Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Icon(_drawerOpen ? Icons.close_rounded : Icons.menu_rounded, color: _AppColors.textPri, size: 22),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Bienvenido 👋', style: GoogleFonts.spaceGrotesk(color: _AppColors.textSec, fontSize: 12)),
            Text('Fabian', style: GoogleFonts.spaceGrotesk(color: _AppColors.textPri, fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
        ),
        GestureDetector(
          onTap: () => context.pushNamed(CrearUsuarioWidget.routeName),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_AppColors.primary, _AppColors.accent]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: _AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(children: [
              const Icon(Icons.person_add_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text('Nuevo', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────
  //  STATS ROW
  // ─────────────────────────────────────────
  Widget _buildStatsRow(int total, int activo, int mora, int inactivo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _StatCard(label: 'Clientes', count: total.toString(), icon: Icons.people_alt_rounded, color: _AppColors.primary),
        _StatCard(label: 'Activos', count: activo.toString(), icon: Icons.wifi_rounded, color: _AppColors.success),
        _StatCard(label: 'En Mora', count: mora.toString(), icon: Icons.warning_amber_rounded, color: _AppColors.danger),
        _StatCard(label: 'Inactivos', count: inactivo.toString(), icon: Icons.wifi_off_rounded, color: _AppColors.warning),
      ]),
    );
  }

  // ─────────────────────────────────────────
  //  SEARCH BAR
  // ─────────────────────────────────────────
  Widget _buildSearchBar(BuildContext context, List<ClientesRecord> filteredClients) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: _AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
          border: Border.all(
            color: _isSearching ? _AppColors.primary.withOpacity(0.4) : _AppColors.cardBorder,
            width: 1.2,
          ),
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          Icon(Icons.search_rounded, color: _isSearching ? _AppColors.primary : _AppColors.textSec, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => _onSearchChanged(v, filteredClients),
              style: GoogleFonts.spaceGrotesk(color: _AppColors.textPri, fontSize: 14),
              decoration: InputDecoration(
                hintText: _selectedStarlinkId != null ? 'Buscar en esta Starlink…' : 'Buscar por nombre, finca, IP…',
                hintStyle: GoogleFonts.spaceGrotesk(color: _AppColors.textSec, fontSize: 13),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_isSearching)
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                setState(() {
                  _isSearching = false;
                  _searchResults = [];
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: _AppColors.textSec.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 14, color: _AppColors.textSec),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  EMPTY STATE
  // ─────────────────────────────────────────
  Widget _buildEmptyState() {
    final isFiltered = _selectedStarlinkId != null;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          isFiltered ? Icons.satellite_alt_rounded : Icons.search_off_rounded,
          size: 60,
          color: _AppColors.textSec.withOpacity(0.3),
        ),
        const SizedBox(height: 12),
        Text(
          isFiltered ? 'Sin clientes en esta Starlink' : 'Sin resultados',
          style: GoogleFonts.spaceGrotesk(color: _AppColors.textSec, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        Text(
          isFiltered ? 'Asigna clientes desde el detalle de cada uno' : 'Intenta con otro término',
          style: GoogleFonts.spaceGrotesk(color: _AppColors.textSec.withOpacity(0.6), fontSize: 13),
          textAlign: TextAlign.center,
        ),
        if (isFiltered) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => setState(() => _selectedStarlinkId = null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _AppColors.primary.withOpacity(0.3)),
              ),
              child: Text('Ver todos los clientes',
                  style: GoogleFonts.spaceGrotesk(color: _AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ]),
    );
  }
}
