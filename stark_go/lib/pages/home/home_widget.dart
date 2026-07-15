import 'package:stark_go/pages/ConfigMikroTik/config_mikro_tik_widget.dart';
import 'package:stark_go/pages/lista_equipos/lista_equipos_widget.dart';
import 'package:stark_go/pages/lista_starlinks/lista_starlinks_widget.dart';
import 'package:stark_go/pages/planes/planes_widget.dart';
import 'package:stark_go/pages/config_evolution_api/config_evolution_api_widget.dart';
import 'package:stark_go/pages/Crear_cuenta/crear_cuenta_widget.dart';
import 'package:stark_go/pages/config_facturacion/config_facturacion_widget.dart';
import 'package:stark_go/pages/config_velocidades/config_velocidades_widget.dart';
import 'package:stark_go/pages/informes/informes_widget.dart';
import 'package:stark_go/pages/lista_operadores/lista_operadores_widget.dart';
import 'package:stark_go/pages/tutorial/tutorial_widget.dart';
import 'package:stark_go/pages/pppoe_clientes/pppoe_clientes_widget.dart';
import '/pages/renovar_membresia/renovar_membresia_widget.dart';
import 'package:stark_go/pages/lista_starlinks_clientes/lista_starlinks_clientes_widget.dart';
import 'package:stark_go/widgets/consumo_widgets.dart';
import 'package:stark_go/pages/reporte_consumo/reporte_consumo_widget.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:text_search/text_search.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  static const Color whatsapp = Color(0xFF25D366);
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
//  MODELO EVOLUTION INSTANCE
// ─────────────────────────────────────────────
class _EvolutionInstance {
  final String serverUrl;
  final String instanceName;
  final String apiKey;
  final String phone;
  final String status;

  const _EvolutionInstance({
    required this.serverUrl,
    required this.instanceName,
    required this.apiKey,
    required this.phone,
    required this.status,
  });

  bool get isConnected => status == 'connected' || status == 'open';
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
                    ConsumoBarCard(clienteId: cliente.reference.id),
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
                        decoration: BoxDecoration(
                          color: _AppColors.whatsapp,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 11),
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

class _HomeWidgetState extends State<HomeWidget> with TickerProviderStateMixin, WidgetsBindingObserver {
  late HomeModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _drawerCtrl;
  late Animation<double> _drawerAnim;
  bool _drawerOpen = false;

  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSearching = false;
  List<ClientesRecord> _searchResults = [];

  // ── STARLINKS: ahora con Stream en tiempo real ──
  Stream<List<_StarlinkInfo>>? _starlinksStream;
  String? _selectedStarlinkId;

  bool _esAdmin = false;

  // ── Facturación ──────────────────────────────
  int _diaVencimiento = 0;
  int _diasAviso = 1;
  bool _facturacionCargada = false;

  // ── Datos empresa + plantilla recordatorio ───
  String _nombreEmpresa = 'StarkGo';
  String _nombreTitular = '';
  String _numeroNequi = '';
  String _whatsappSoporte = '';
  String _horarioSoporte = 'Lunes a viernes · 8am – 5pm';
  String _msgRecordatorio = '';

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomeModel());

    _drawerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _drawerAnim = CurvedAnimation(parent: _drawerCtrl, curve: Curves.easeInOutCubic);

    // ── Inicia stream de Starlinks en tiempo real ──
    _initStarlinksStream();

    _cargarRolAdmin();
    _cargarConfigFacturacion();
    _verificarMembresia();

    WidgetsBinding.instance.addObserver(this);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _drawerCtrl.dispose();
    _searchCtrl.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verificarMembresia();
    }
  }

  // ──────────────────────────────────────────
  //  VERIFICAR MEMBRESÍA AL ENTRAR AL HOME
  // ──────────────────────────────────────────
  Future<void> _verificarMembresia() async {
    if (_uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('user').doc(_uid).get();
      final ts = doc.data()?['fechaVencimiento'] as Timestamp?;
      if (ts != null && DateTime.now().isAfter(ts.toDate())) {
        if (mounted) {
          context.goNamed(RenovarMembresiaWidget.routeName);
        }
      }
    } catch (_) {}
  }

  // ──────────────────────────────────────────
  //  STREAM STARLINKS — tiempo real
  //  Al borrar/crear/editar una Starlink en
  //  Firestore, el chip se actualiza solo.
  // ──────────────────────────────────────────
  void _initStarlinksStream() {
    if (_uid.isEmpty) return;
    _starlinksStream = FirebaseFirestore.instance
        .collection('starlinks')
        .where('propietarioUid', isEqualTo: _uid)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _StarlinkInfo.fromDoc(d)).toList());
  }

  // ──────────────────────────────────────────
  //  CARGAR ROL ADMIN
  // ──────────────────────────────────────────
  Future<void> _cargarRolAdmin() async {
    if (_uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('user').doc(_uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() => _esAdmin = data['admin'] == true);
      }
    } catch (e) {
      debugPrint('[StarkGo] Error leyendo rol admin: $e');
    }
  }

  // ──────────────────────────────────────────
  //  CARGAR CONFIG FACTURACIÓN + EMPRESA
  // ──────────────────────────────────────────
  Future<void> _cargarConfigFacturacion() async {
    if (_uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('config_empresa').doc(_uid).get();
      if (doc.exists && mounted) {
        final d = doc.data() as Map<String, dynamic>;
        setState(() {
          _diaVencimiento = (d['diaVencimiento'] as int?) ?? 0;
          _diasAviso = (d['diasAviso'] as int?) ?? 1;
          _nombreEmpresa = (d['nombreEmpresa'] ?? 'StarkGo').toString();
          _nombreTitular = (d['nombreTitular'] ?? '').toString();
          _numeroNequi = (d['numeroNequi'] ?? '').toString();
          _whatsappSoporte = (d['whatsappSoporte'] ?? '').toString();
          _horarioSoporte = (d['horarioSoporte'] ?? 'Lunes a viernes · 8am – 5pm').toString();
          _msgRecordatorio = (d['msgRecordatorio'] ?? '').toString();
          _facturacionCargada = true;
        });
      } else {
        if (mounted) setState(() => _facturacionCargada = true);
      }
    } catch (e) {
      debugPrint('[StarkGo] Error leyendo config_empresa: $e');
      if (mounted) setState(() => _facturacionCargada = true);
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

  // ──────────────────────────────────────────
  //  EVOLUTION API — obtener instancia
  // ──────────────────────────────────────────
  Future<_EvolutionInstance?> _obtenerInstanciaEvolution() async {
    if (_uid.isEmpty) return null;
    try {
      final snap = await FirebaseFirestore.instance.collection('whatsapp_instances').where('uid', isEqualTo: _uid).limit(1).get();
      if (snap.docs.isEmpty) return null;
      final d = snap.docs.first.data();
      return _EvolutionInstance(
        serverUrl: d['serverUrl'] ?? '',
        instanceName: d['instanceName'] ?? '',
        apiKey: d['apiKey'] ?? '',
        phone: d['phone'] ?? '',
        status: d['status'] ?? '',
      );
    } catch (e) {
      debugPrint('[StarkGo] Error leyendo whatsapp_instances: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────
  //  ENVIAR WHATSAPP
  // ──────────────────────────────────────────
  Future<void> _sendWhatsapp(
    BuildContext ctx,
    String nombre,
    dynamic numeroRaw,
    double planCliente,
  ) async {
    if (_diaVencimiento == 0) {
      _showFechaNoConfiguradaDialog();
      return;
    }

    final ok = await showDialog<bool>(
          context: ctx,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Reporte de Pago', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
            content: Text('Enviar recordatorio de pago a $nombre vía WhatsApp?', style: GoogleFonts.spaceGrotesk()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _AppColors.textSec)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _AppColors.whatsapp,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Enviar', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: _AppColors.whatsapp, strokeWidth: 2.5),
            const SizedBox(height: 14),
            Text('Enviando mensaje…', style: GoogleFonts.spaceGrotesk(color: _AppColors.textPri, fontSize: 14)),
          ]),
        ),
      ),
    );

    _EvolutionInstance? instancia;
    try {
      instancia = await _obtenerInstanciaEvolution();
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showErrorDialog('Error de conexión', 'No se pudo consultar la configuración de WhatsApp.\n\nDetalle: $e');
      return;
    }

    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    if (instancia == null) {
      _showNoInstanceDialog();
      return;
    }
    if (!instancia.isConnected) {
      _showErrorDialog('WhatsApp desconectado', 'Tu instancia (${instancia.instanceName}) no está conectada.\nEstado: ${instancia.status}');
      return;
    }

    final String numeroDestino = _normalizarNumero(numeroRaw);
    if (numeroDestino.isEmpty) {
      _showErrorDialog('Número inválido', 'El cliente no tiene un número válido registrado.');
      return;
    }

    final now = DateTime.now();
    final diasParaVencer = _diaVencimiento - now.day;

    String estado;
    if (diasParaVencer == 0) {
      estado = '🔴 *Estado:* Vence HOY';
    } else if (diasParaVencer == 1) {
      estado = '🔴 *Estado:* Vence mañana, día $_diaVencimiento';
    } else if (diasParaVencer > 1) {
      estado = '🟡 *Estado:* Vence en $diasParaVencer días (día $_diaVencimiento)';
    } else {
      estado = '🔴 *Estado:* Venció el día $_diaVencimiento (${diasParaVencer.abs()} días de retraso)';
    }

    final valorFmt = _formatearPesos(planCliente);

    String mensaje;
    if (_msgRecordatorio.trim().isEmpty) {
      mensaje = '📢 *$_nombreEmpresa — Recordatorio de Pago*\n\n'
          'Hola *$nombre*, te recordamos que tu factura vence el día '
          '$_diaVencimiento del mes.\n\n'
          '💳 *Valor:* $valorFmt\n'
          '$estado\n\n'
          '💜 Nequi: $_numeroNequi · $_nombreTitular\n'
          'Soporte: $_whatsappSoporte\n$_horarioSoporte\n\n'
          '— *Equipo $_nombreEmpresa* 🌐';
    } else {
      mensaje = _msgRecordatorio
          .replaceAll('{nombre}', nombre)
          .replaceAll('{plan}', '')
          .replaceAll('{valor}', valorFmt)
          .replaceAll('{dia}', '$_diaVencimiento')
          .replaceAll('{estado}', estado)
          .replaceAll('{empresa}', _nombreEmpresa)
          .replaceAll('{nequi}', _numeroNequi)
          .replaceAll('{titular}', _nombreTitular)
          .replaceAll('{soporte}', _whatsappSoporte)
          .replaceAll('{horario}', _horarioSoporte);
    }

    try {
      final url = Uri.parse('${instancia.serverUrl}/message/sendText/${instancia.instanceName}');
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'apikey': instancia.apiKey,
            },
            body: jsonEncode({'number': numeroDestino, 'text': mensaje}),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessDialog(nombre, numeroDestino);
      } else {
        String detalle = '';
        try {
          final body = jsonDecode(response.body);
          detalle = body['message'] ?? body['error'] ?? response.body;
        } catch (_) {
          detalle = response.body;
        }
        _showErrorDialog('Error al enviar (${response.statusCode})', 'No se pudo enviar el mensaje.\n\nDetalle: $detalle');
      }
    } on Exception catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error de red', 'No se pudo conectar con Evolution API.\n\nDetalle: $e');
    }
  }

  // ──────────────────────────────────────────
  //  HELPERS
  // ──────────────────────────────────────────
  String _normalizarNumero(dynamic raw) {
    if (raw == null) return '';
    String num = raw.toString().replaceAll(RegExp(r'[^0-9]'), '');
    if (num.isEmpty) return '';
    if (num.length < 10) return '';
    if (num.length > 10) return num;
    return '57$num';
  }

  String _formatearPesos(double valor) {
    final partes = valor.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    int count = 0;
    for (int i = partes.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(partes[i]);
      count++;
    }
    return '\$ ${buffer.toString().split('').reversed.join('')}';
  }

  // ──────────────────────────────────────────
  //  MARCAR TODOS EN MORA (manual, un tap)
  // ──────────────────────────────────────────
  Future<void> _marcarTodosEnMora(List<ClientesRecord> allClients) async {
    final base = _selectedStarlinkId != null ? allClients.where((c) => c.starlinkId == _selectedStarlinkId) : allClients;
    final clientesActivos = base.where((c) => c.status == 'activo').toList();

    if (clientesActivos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay clientes activos para marcar en mora.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _AppColors.danger.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.warning_amber_rounded, color: _AppColors.danger, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Marcar en mora', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ]),
            content: Text(
              '¿Marcar ${clientesActivos.length} cliente${clientesActivos.length != 1 ? 's' : ''} '
              'activo${clientesActivos.length != 1 ? 's' : ''} como EN MORA?\n\n'
              'Solo cambia su color a rojo. NO se corta el internet de nadie.',
              style: GoogleFonts.spaceGrotesk(color: _AppColors.textSec, fontSize: 13, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _AppColors.textSec)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _AppColors.danger,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Sí, marcar todos', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: _AppColors.danger, strokeWidth: 2.5),
            const SizedBox(height: 14),
            Text('Actualizando estados…', style: GoogleFonts.spaceGrotesk(color: _AppColors.textPri, fontSize: 14)),
          ]),
        ),
      ),
    );

    try {
      const chunkSize = 450; // límite real de batch es 500
      for (var i = 0; i < clientesActivos.length; i += chunkSize) {
        final chunk = clientesActivos.skip(i).take(chunkSize);
        final batch = FirebaseFirestore.instance.batch();
        for (final c in chunk) {
          batch.update(c.reference, {
            'status': 'mora',
            'moraDesde': DateTime.now(),
          });
        }
        await batch.commit();
      }

      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${clientesActivos.length} clientes marcados en mora.')),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showErrorDialog('Error al actualizar', 'No se pudo marcar a los clientes en mora.\n\nDetalle: $e');
    }
  }

  // ──────────────────────────────────────────
  //  MARCAR TODOS EN ACTIVO (deshacer mora masiva)
  // ──────────────────────────────────────────
  Future<void> _marcarTodosActivos(List<ClientesRecord> allClients) async {
    final base = _selectedStarlinkId != null ? allClients.where((c) => c.starlinkId == _selectedStarlinkId) : allClients;
    final clientesEnMora = base.where((c) => c.status == 'mora').toList();

    if (clientesEnMora.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay clientes en mora para reactivar.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _AppColors.success.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.check_circle_outline_rounded, color: _AppColors.success, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Marcar en activo', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ]),
            content: Text(
              '¿Marcar ${clientesEnMora.length} cliente${clientesEnMora.length != 1 ? 's' : ''} '
              'en mora como ACTIVO?\n\n'
              'Úsalo solo si marcaste en mora por error. NO reconecta el internet de nadie.',
              style: GoogleFonts.spaceGrotesk(color: _AppColors.textSec, fontSize: 13, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _AppColors.textSec)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _AppColors.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Sí, reactivar todos', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: _AppColors.success, strokeWidth: 2.5),
            const SizedBox(height: 14),
            Text('Actualizando estados…', style: GoogleFonts.spaceGrotesk(color: _AppColors.textPri, fontSize: 14)),
          ]),
        ),
      ),
    );

    try {
      const chunkSize = 450;
      for (var i = 0; i < clientesEnMora.length; i += chunkSize) {
        final chunk = clientesEnMora.skip(i).take(chunkSize);
        final batch = FirebaseFirestore.instance.batch();
        for (final c in chunk) {
          batch.update(c.reference, {
            'status': 'activo',
            'moraDesde': FieldValue.delete(),
          });
        }
        await batch.commit();
      }

      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${clientesEnMora.length} clientes reactivados.')),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showErrorDialog('Error al actualizar', 'No se pudo reactivar a los clientes.\n\nDetalle: $e');
    }
  }

  // ── Dialogs ──────────────────────────────────
  void _showFechaNoConfiguradaDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _AppColors.warning.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.calendar_today_rounded, color: _AppColors.warning, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Fecha no configurada', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'Antes de enviar mensajes de pago, configura el día '
            'de vencimiento y los datos de tu empresa.',
            style: GoogleFonts.spaceGrotesk(color: _AppColors.textSec, fontSize: 13, height: 1.5),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _AppColors.textSec)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 16),
            label: Text('Configurar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w600)),
            onPressed: () async {
              Navigator.pop(context);
              await context.pushNamed(ConfigFacturacionWidget.routeName);
              _cargarConfigFacturacion();
            },
          ),
        ],
      ),
    );
  }

  void _showNoInstanceDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _AppColors.warning.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.chat_bubble_outline_rounded, color: _AppColors.warning, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('WhatsApp no configurado', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ]),
        content: Text(
          'No tienes una instancia de Evolution API registrada.\n\n'
          'Configura WhatsApp para poder enviar mensajes.',
          style: GoogleFonts.spaceGrotesk(color: _AppColors.textSec, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _AppColors.textSec)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppColors.whatsapp,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 16),
            label: Text('Configurar ahora', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w600)),
            onPressed: () {
              Navigator.pop(context);
              context.pushNamed(ConfigEvolutionApiWidget.routeName);
            },
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String nombre, String numero) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _AppColors.success.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(FontAwesomeIcons.whatsapp, color: _AppColors.whatsapp, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('¡Mensaje enviado!', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('El recordatorio fue enviado exitosamente.', style: GoogleFonts.spaceGrotesk(color: _AppColors.textSec, fontSize: 13)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _AppColors.success.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _AppColors.success.withOpacity(0.2)),
            ),
            child: Row(children: [
              Icon(Icons.person_rounded, size: 16, color: _AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(nombre, style: GoogleFonts.spaceGrotesk(color: _AppColors.textPri, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('+$numero', style: GoogleFonts.spaceGrotesk(color: _AppColors.textSec, fontSize: 11)),
                ]),
              ),
              Icon(Icons.check_circle_rounded, color: _AppColors.success, size: 20),
            ]),
          ),
        ]),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppColors.success,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text('Perfecto', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String titulo, String mensaje) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _AppColors.danger.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.error_outline_rounded, color: _AppColors.danger, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(titulo, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ]),
        content: Text(mensaje, style: GoogleFonts.spaceGrotesk(color: _AppColors.textSec, fontSize: 13, height: 1.5)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text('Entendido', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _cerrarSesion() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Cerrar sesión', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
            content: Text('¿Estás seguro que deseas cerrar sesión?', style: GoogleFonts.spaceGrotesk()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _AppColors.textSec)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _AppColors.danger,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Cerrar sesión', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (ok && mounted) {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ));
      await authManager.signOut();
      if (mounted) {
        context.goNamedAuth(LoginWidget.routeName, context.mounted);
      }
    }
  }

  // ══════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return StreamBuilder<List<ClientesRecord>>(
      stream: queryClientesRecord(
        queryBuilder: (q) => q.where('propietarioUid', isEqualTo: _uid),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: _AppColors.surfaceDim,
            body: Center(
              child: CircularProgressIndicator(color: _AppColors.primary, strokeWidth: 2.5),
            ),
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

  // ──────────────────────────────────────────
  //  DRAWER
  // ──────────────────────────────────────────
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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _DrawerSectionHeader(title: 'Principal'),
                      _DrawerItem(icon: Icons.dashboard_rounded, label: 'Inicio', active: true, onTap: _toggleDrawer),
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
                        icon: Icons.cable_rounded,
                        label: 'Clientes PPPoE',
                        iconColor: Color(0xFF0EA5E9),
                        onTap: () {
                          _toggleDrawer();
                          context.pushNamed(PppoeClientesWidget.routeName);
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
                        icon: Icons.satellite_alt_rounded,
                        label: 'Mis Starlinks · Cobros',
                        iconColor: _AppColors.success,
                        onTap: () {
                          _toggleDrawer();
                          context.pushNamed(ListaStarlinksClientesWidget.routeName);
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.bar_chart_rounded,
                        label: 'Informes',
                        onTap: () {
                          _toggleDrawer();
                          context.pushNamed(InformesWidget.routeName);
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.play_circle_rounded,
                        label: 'Tutorial',
                        iconColor: const Color(0xFFFF6B35),
                        onTap: () {
                          _toggleDrawer();
                          context.pushNamed(TutorialWidget.routeName);
                        },
                      ),
                      if (_esAdmin) ...[
                        const _DrawerSectionHeader(title: 'Administración'),
                        _DrawerItem(
                          icon: Icons.person_add_rounded,
                          label: 'Crear operador',
                          iconColor: _AppColors.purple,
                          badge: 'Admin',
                          onTap: () {
                            _toggleDrawer();
                            context.pushNamed(CrearCuentaWidget.routeName);
                          },
                        ),
                        _DrawerItem(
                          icon: Icons.people_rounded,
                          label: 'Lista operadores',
                          iconColor: _AppColors.purple,
                          badge: 'Admin',
                          onTap: () {
                            _toggleDrawer();
                            context.pushNamed(ListaOperadoresWidget.routeName);
                          },
                        ),
                      ],
                      const _DrawerSectionHeader(title: 'Configuración'),
                      _DrawerItem(
                        icon: Icons.chat_rounded,
                        label: 'WhatsApp · Evolution',
                        iconColor: _AppColors.whatsapp,
                        onTap: () {
                          _toggleDrawer();
                          context.pushNamed(ConfigEvolutionApiWidget.routeName);
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
                        icon: Icons.speed_rounded,
                        label: 'Velocidades MikroTik',
                        iconColor: _AppColors.accent,
                        onTap: () {
                          _toggleDrawer();
                          context.pushNamed(ConfigVelocidadesWidget.routeName);
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.calendar_month_rounded,
                        label: 'Facturación & Mensajes',
                        iconColor: _AppColors.primary,
                        badge: _facturacionCargada && _diaVencimiento == 0 ? '⚠️' : null,
                        onTap: () async {
                          _toggleDrawer();
                          await context.pushNamed(ConfigFacturacionWidget.routeName);
                          _cargarConfigFacturacion();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Divider(color: Colors.white.withOpacity(0.08), height: 1),
              ),
              _DrawerItem(icon: Icons.logout_rounded, label: 'Cerrar sesión', iconColor: _AppColors.danger, onTap: _cerrarSesion),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('v1.0.0+5', style: GoogleFonts.spaceGrotesk(color: Colors.white24, fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  MAIN CONTENT
  // ──────────────────────────────────────────
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
          _buildTopBar(context, allClients),
          const SizedBox(height: 4),
          if (_facturacionCargada && _diaVencimiento == 0) _buildFechaAlertBanner(),
          _buildStatsRow(filteredClients.length, activoCount, moraCount, inactivoCount),
          const SizedBox(height: 10),

          // ── CHIPS STARLINKS — Stream en tiempo real ──
          StreamBuilder<List<_StarlinkInfo>>(
            stream: _starlinksStream,
            builder: (context, slSnap) {
              final starlinks = slSnap.data ?? [];

              // Si la Starlink seleccionada fue borrada,
              // limpia el filtro automáticamente
              if (_selectedStarlinkId != null && !starlinks.any((s) => s.id == _selectedStarlinkId)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _selectedStarlinkId = null;
                      _isSearching = false;
                      _searchResults = [];
                      _searchCtrl.clear();
                    });
                  }
                });
              }

              if (starlinks.isEmpty) {
                return const SizedBox.shrink();
              }

              return _buildStarlinkChipsFromList(allClients, starlinks);
            },
          ),

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
                          c.planValor,
                        ),
                      ).animate().fadeIn(duration: 280.ms, delay: (i * 35).ms);
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  CHIPS desde lista viva del stream
  // ──────────────────────────────────────────
  Widget _buildStarlinkChipsFromList(List<ClientesRecord> allClients, List<_StarlinkInfo> starlinks) {
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
          ...starlinks.map((sl) => _StarlinkChip(
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

  Widget _buildFechaAlertBanner() {
    return GestureDetector(
      onTap: () async {
        await context.pushNamed(ConfigFacturacionWidget.routeName);
        _cargarConfigFacturacion();
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_AppColors.warning.withOpacity(0.15), _AppColors.warning.withOpacity(0.05)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _AppColors.warning.withOpacity(0.4), width: 1.2),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: _AppColors.warning.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.calendar_today_rounded, color: _AppColors.warning, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Facturación no configurada',
                style: GoogleFonts.spaceGrotesk(color: _AppColors.warning, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              Text(
                'Toca aquí para configurar antes de enviar mensajes.',
                style: GoogleFonts.spaceGrotesk(color: _AppColors.textSec, fontSize: 11),
              ),
            ]),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: _AppColors.warning),
        ]),
      ),
    );
  }

  Widget _buildFilterBanner(List<ClientesRecord> allClients) {
    final count = allClients.where((c) => c.starlinkId == _selectedStarlinkId).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: StreamBuilder<List<_StarlinkInfo>>(
        stream: _starlinksStream,
        builder: (context, snap) {
          final starlinks = snap.data ?? [];
          final found = starlinks.firstWhere(
            (s) => s.id == _selectedStarlinkId,
            orElse: () => _StarlinkInfo(id: '', nombre: '...', ubicacion: '', activo: false, clientesCount: 0),
          );
          return Container(
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
                  Text('Filtrando: ${found.nombre}',
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
          );
        },
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, List<ClientesRecord> allClients) {
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
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('user').doc(_uid).get(),
              builder: (context, snap) {
                final nombre =
                    snap.hasData && snap.data!.exists ? (snap.data!.data() as Map<String, dynamic>)['nombre'] ?? 'Usuario' : 'Usuario';
                return RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$nombre, ',
                        style: GoogleFonts.spaceGrotesk(
                          color: _AppColors.textPri,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: 'Ing.',
                        style: GoogleFonts.spaceGrotesk(
                          color: _AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ]),
        ),
        // ── BOTÓN: Marcar todos en mora (manual) ──
        GestureDetector(
          onTap: () => _marcarTodosEnMora(allClients),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _AppColors.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _AppColors.danger.withOpacity(0.3)),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: _AppColors.danger, size: 20),
          ),
        ),
        // ── BOTÓN: Marcar todos en activo (deshacer) ──
        GestureDetector(
          onTap: () => _marcarTodosActivos(allClients),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _AppColors.success.withOpacity(0.3)),
            ),
            child: const Icon(Icons.check_circle_outline_rounded, color: _AppColors.success, size: 20),
          ),
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
