import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stark_go/app_state.dart';
import 'package:stark_go/services/mikrotik_local_api.dart';
import 'perfiles_local_widget.dart';
import 'fichas_local_widget.dart';
import 'hotspot_design_widget.dart'; // <- NUEVO: pantalla de diseño del hotspot

// ─────────────────────────────────────────────────────────────────────────
// Paleta — misma que ConfigMikroTikWidget / PerfilesLocalWidget / FichasLocalWidget.
// ─────────────────────────────────────────────────────────────────────────
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

class DashboardLocalWidget extends StatefulWidget {
  final MikrotikLocalApi api;
  final String nombreRouter;

  const DashboardLocalWidget({
    Key? key,
    required this.api,
    required this.nombreRouter,
  }) : super(key: key);

  @override
  State<DashboardLocalWidget> createState() => _DashboardLocalWidgetState();
}

class _DashboardLocalWidgetState extends State<DashboardLocalWidget> {
  int _selectedIndex = 0;
  late List<Widget> _paginas;

  final List<_TabInfo> _tabs = const [
    _TabInfo(icon: Icons.people_alt_rounded, label: 'Perfiles', color: _C.purple),
    _TabInfo(icon: Icons.vpn_key_rounded, label: 'Fichas', color: _C.accent),
    _TabInfo(icon: Icons.design_services_rounded, label: 'Hotspot', color: _C.primary), // <- NUEVA
  ];

  @override
  void initState() {
    super.initState();
    _paginas = [
      PerfilesLocalWidget(api: widget.api),
      FichasLocalWidget(api: widget.api),
      HotspotDesignWidget(
        host: widget.api.ip,
        usuario: widget.api.usuario,
        clave: widget.api.password, // TODO: confirma que MikrotikLocalApi exponga este getter
        puertoFtp: 21,
      ),
    ];
  }

  void _recargar() {
    setState(() {
      _paginas = [
        PerfilesLocalWidget(api: widget.api),
        FichasLocalWidget(api: widget.api),
        HotspotDesignWidget(
          host: widget.api.ip,
          usuario: widget.api.usuario,
          clave: widget.api.password, // TODO: confirma que MikrotikLocalApi exponga este getter
          puertoFtp: 21,
        ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surfaceDim,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _paginas,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_C.dark, Color(0xFF1E293B)]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: _C.success, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('CONECTADO LOCAL',
                        style: GoogleFonts.spaceGrotesk(color: _C.success, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  ]),
                  const SizedBox(height: 3),
                  Text(widget.nombreRouter,
                      style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            _headerIconBtn(Icons.refresh_rounded, 'Recargar datos', _recargar),
            const SizedBox(width: 8),
            _headerIconBtn(Icons.info_outline_rounded, 'Información de conexión', () => _mostrarInfoConexion(context)),
            const SizedBox(width: 8),
            _headerIconBtn(Icons.logout_rounded, 'Desconectar', () => _confirmarDesconexion(context), color: _C.danger),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            _infoPill(Icons.dns_rounded, widget.api.ip),
            const SizedBox(width: 8),
            _infoPill(Icons.settings_ethernet_rounded, 'Puerto ${widget.api.puerto}'),
            const SizedBox(width: 8),
            if (widget.api.useSsl) _infoPill(Icons.lock_rounded, 'SSL'),
          ]),
        ],
      ),
    );
  }

  Widget _headerIconBtn(IconData icon, String tooltip, VoidCallback onTap, {Color color = Colors.white}) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _infoPill(IconData icon, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: Colors.white60),
        const SizedBox(width: 5),
        Text(texto, style: GoogleFonts.spaceGrotesk(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final tab = _tabs[i];
          final selected = _selectedIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: selected ? tab.color.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(tab.icon, size: 17, color: selected ? tab.color : _C.textSec),
                    const SizedBox(width: 7),
                    Text(tab.label,
                        style: GoogleFonts.spaceGrotesk(
                          color: selected ? tab.color : _C.textSec,
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        )),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  void _mostrarInfoConexion(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: _C.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.router_rounded, color: _C.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Información de conexión',
                    style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 16),
              _infoRow('Router', widget.nombreRouter),
              _infoRow('IP', widget.api.ip),
              _infoRow('Puerto', widget.api.puerto.toString()),
              _infoRow('Usuario', widget.api.usuario),
              _infoRow('SSL', widget.api.useSsl ? 'Sí' : 'No'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _C.surfaceDim, borderRadius: BorderRadius.circular(10)),
                child: Text('Compatible con RouterOS v6 y v7', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: TextButton.styleFrom(
                    backgroundColor: _C.surfaceDim,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Cerrar', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12.5)),
          Text(value, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _confirmarDesconexion(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: _C.danger.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.logout_rounded, color: _C.danger, size: 22),
              ),
              const SizedBox(height: 14),
              Text('Desconectar', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('¿Seguro que quieres desconectarte de "${widget.nombreRouter}"?',
                  textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12.5, height: 1.4)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                    child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: _C.danger, borderRadius: BorderRadius.circular(12)),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          FFAppState().desconectarLocal();
                          Navigator.pop(dialogContext);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Desconectado del router local', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
                            backgroundColor: _C.warning,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ));
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: Center(
                              child:
                                  Text('Desconectar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700))),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabInfo {
  final IconData icon;
  final String label;
  final Color color;
  const _TabInfo({required this.icon, required this.label, required this.color});
}
