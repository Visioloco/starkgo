import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:stark_go/services/blindaje_admin_service.dart';
import 'package:stark_go/services/mikrotik_local_api.dart';

// ─────────────────────────────────────────────────────────────────────────
//  🛡️ BLINDAJE DEL ADMINISTRADOR — pestaña del panel local
//
//  Sirve para que TU teléfono (el que usa el operador para crear fichas o
//  configurar el hotspot) NO tenga que autenticarse con una ficha/PIN en el
//  portal cautivo: queda "bypassed" en el MikroTik.
//
//  Se puede blindar:
//    · por MAC  → sobrevive a los cambios de IP del DHCP;
//    · por IP   → útil si el teléfono usa MAC aleatoria (Android 10+/iPhone);
//    · automáticamente al crear fichas.
// ─────────────────────────────────────────────────────────────────────────

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

class BlindajeLocalWidget extends StatefulWidget {
  final MikrotikLocalApi api;

  const BlindajeLocalWidget({Key? key, required this.api}) : super(key: key);

  @override
  State<BlindajeLocalWidget> createState() => _BlindajeLocalWidgetState();
}

class _BlindajeLocalWidgetState extends State<BlindajeLocalWidget> {
  BlindajeAdminConfig _cfg = const BlindajeAdminConfig();
  List<String> _misIps = const [];
  bool _cargando = true;
  bool _trabajando = false;
  String? _estado;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (mounted) setState(() => _cargando = true);
    final cfg = await BlindajeAdminService.cargar();
    final ips = await BlindajeAdminService.misIps();
    if (!mounted) return;
    setState(() {
      _cfg = cfg;
      _misIps = ips;
      _cargando = false;
    });
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.spaceGrotesk(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  /// Aplica el blindaje a las MACs/IPs indicadas (vía local + cola del VPS).
  Future<void> _blindar({
    List<String> macs = const [],
    List<String> ips = const [],
    bool guardar = true,
  }) async {
    if (_trabajando) return;
    setState(() => _trabajando = true);
    try {
      final r = await BlindajeAdminService.blindar(
        macs: macs,
        ips: ips,
        apiLocal: widget.api,
        guardarConfig: guardar,
      );
      final cfg = await BlindajeAdminService.cargar();
      final ipsActuales = await BlindajeAdminService.misIps();
      if (!mounted) return;
      setState(() {
        _cfg = cfg;
        _misIps = ipsActuales;
        _estado = r.detalle;
      });
      _snack(r.detalle, r.ok ? _C.success : _C.warning);
    } catch (e) {
      if (mounted) setState(() => _estado = 'Error: $e');
      _snack('Error al blindar: $e', _C.danger);
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _olvidar({String? ip, String? mac}) async {
    final cfg = await BlindajeAdminService.olvidar(ip: ip, mac: mac);
    if (!mounted) return;
    setState(() => _cfg = cfg);
    _snack('Quitado de la lista (el binding del router se borra desde el '
        'MikroTik).', _C.warning);
  }

  Future<void> _cambiarAuto(bool valor) async {
    final cfg = _cfg.copyWith(auto: valor);
    await BlindajeAdminService.guardar(cfg);
    if (!mounted) return;
    setState(() => _cfg = cfg);
    _snack(
      valor ? 'Listo: blindo tu equipo cada vez que crees fichas.' : 'Auto-blindaje apagado.',
      valor ? _C.success : _C.warning,
    );
  }

  /// Busca mi equipo en la lista de dispositivos que ve el hotspot.
  Future<void> _detectar() async {
    if (_trabajando) return;
    setState(() => _trabajando = true);
    try {
      final hosts = await widget.api.obtenerHostsHotspot();
      final ips = await BlindajeAdminService.misIps();
      final mios = BlindajeAdminService.detectarme(hosts, ips);
      if (!mounted) return;
      setState(() => _misIps = ips);

      if (hosts.isEmpty) {
        _snack(
          'El hotspot todavía no ve ningún equipo. Probá abriendo esta '
          'pantalla desde el teléfono conectado al Wi-Fi del hotspot.',
          _C.warning,
        );
        return;
      }
      await _elegirEquipo(hosts: hosts, mios: mios);
    } catch (e) {
      _snack('No pude leer los equipos del hotspot: $e', _C.danger);
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  /// Hoja con la lista de equipos del hotspot para elegir el mío.
  Future<void> _elegirEquipo({
    required List<Map<String, dynamic>> hosts,
    required List<Map<String, String>> mios,
  }) async {
    final misIps = mios.map((m) => m['ip'] ?? '').toSet();
    final misMacs = mios.map((m) => m['mac'] ?? '').toSet();
    final lista = List<Map<String, dynamic>>.from(hosts)
      ..sort((a, b) =>
          _ordenMio(a, misIps, misMacs).compareTo(_ordenMio(b, misIps, misMacs)));

    final elegido = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bctx) => Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(bctx).size.height * 0.75),
        decoration: const BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 14),
          Text('Equipos en el hotspot',
              style: GoogleFonts.spaceGrotesk(
                  color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              misIps.isEmpty
                  ? 'Elegí tu teléfono (el que estás usando ahora).'
                  : 'Arriba están los que coinciden con la IP de este teléfono.',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12),
            ),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              itemCount: lista.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _filaEquipo(bctx, lista[i], misIps, misMacs),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );

    if (elegido == null) return;
    final ip = elegido['ip'] ?? '';
    final mac = elegido['mac'] ?? '';
    if (ip.isEmpty && mac.isEmpty) return;
    await _blindar(
      macs: mac.isEmpty ? const [] : [mac],
      ips: ip.isEmpty ? const [] : [ip],
    );
  }

  static String _campoHost(Map<String, dynamic> h, List<String> claves) {
    for (final k in claves) {
      final v = h[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return '';
  }

  /// `'0'` si ese equipo es este teléfono (para ordenarlo primero).
  String _ordenMio(Map<String, dynamic> h, Set<String> misIps, Set<String> misMacs) {
    final ip = _campoHost(h, const ['address']);
    final mac = BlindajeAdminService.normalizarMac(
            _campoHost(h, const ['mac-address', 'macAddress'])) ??
        '';
    final mio = misIps.contains(ip) || (mac.isNotEmpty && misMacs.contains(mac));
    return mio ? '0' : '1';
  }

  Widget _filaEquipo(
    BuildContext bctx,
    Map<String, dynamic> h,
    Set<String> misIps,
    Set<String> misMacs,
  ) {
    final ip = _campoHost(h, const ['address']);
    final mac = _campoHost(h, const ['mac-address', 'macAddress']);
    final nombre = _campoHost(h, const ['host-name', 'hostName', 'comment']);
    final soyYo = _ordenMio(h, misIps, misMacs) == '0';
    return ListTile(
      dense: true,
      leading: Icon(
        soyYo ? Icons.smartphone_rounded : Icons.devices_other_rounded,
        color: soyYo ? _C.accent : _C.textSec,
        size: 20,
      ),
      title: Text(
        soyYo ? 'Este teléfono' : (nombre.isEmpty ? ip : nombre),
        style: GoogleFonts.spaceGrotesk(
            color: _C.textPri,
            fontSize: 13.5,
            fontWeight: soyYo ? FontWeight.w700 : FontWeight.w500),
      ),
      subtitle: Text('$ip${mac.isEmpty ? '' : '  ·  $mac'}',
          style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11.5)),
      trailing: TextButton(
        onPressed: () => Navigator.pop(bctx, {'ip': ip, 'mac': mac}),
        child: Text('Blindar',
            style: GoogleFonts.spaceGrotesk(
                color: _C.primary, fontWeight: FontWeight.w700)),
      ),
    );
  }

  /// Agregar una MAC o una IP a mano.
  Future<void> _agregarManual() async {
    final ctrl = TextEditingController();
    final valor = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Agregar equipo',
            style: GoogleFonts.spaceGrotesk(
                color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pegá la MAC (AA:BB:CC:DD:EE:FF) o la IP de tu teléfono.',
                style:
                    GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12.5)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: GoogleFonts.spaceGrotesk(color: _C.textPri),
              decoration: InputDecoration(
                hintText: 'AA:BB:CC:DD:EE:FF  ·  192.168.10.50',
                filled: true,
                fillColor: _C.surfaceDim,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text('Cancelar',
                style: GoogleFonts.spaceGrotesk(color: _C.textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx, ctrl.text.trim()),
            child: Text('Blindar',
                style: GoogleFonts.spaceGrotesk(
                    color: _C.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (valor == null || valor.isEmpty) return;
    if (BlindajeAdminService.esMac(valor)) {
      await _blindar(macs: [valor]);
    } else if (BlindajeAdminService.esIp(valor)) {
      await _blindar(ips: [valor]);
    } else {
      _snack('Eso no parece una MAC ni una IP válida.', _C.warning);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: _C.primary));
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      color: _C.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _cabecera(),
          const SizedBox(height: 14),
          _cardEstado(),
          const SizedBox(height: 14),
          _cardMisIps(),
          const SizedBox(height: 14),
          _cardAuto(),
          const SizedBox(height: 14),
          _cardAcciones(),
          if (_estado != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _C.border),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: _C.textSec),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_estado!,
                      style: GoogleFonts.spaceGrotesk(
                          color: _C.textSec, fontSize: 12, height: 1.3)),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Tarjetas de la pantalla
  // ─────────────────────────────────────────────────────────────

  Widget _card({required List<Widget> hijos}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: hijos,
      ),
    );
  }

  Widget _titulo(String texto, {IconData? icono, Color color = _C.textPri}) {
    return Row(children: [
      if (icono != null) ...[
        Icon(icono, size: 16, color: color),
        const SizedBox(width: 8),
      ],
      Expanded(
        child: Text(texto,
            style: GoogleFonts.spaceGrotesk(
                color: color, fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    ]);
  }

  Widget _cabecera() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _C.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_rounded, color: _C.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Blindaje del administrador',
                style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 12),
        Text(
          'Mientras creás fichas o configurás el hotspot, tu teléfono queda '
          '"blindado" en el MikroTik: el portal cautivo no te pide ficha ni PIN '
          'y podés seguir trabajando.',
          style: GoogleFonts.spaceGrotesk(
              color: Colors.white70, fontSize: 12.5, height: 1.45),
        ),
        const SizedBox(height: 10),
        Text(
          'Se puede blindar por MAC (aguanta el cambio de IP) y/o por IP '
          '(sirve si tu Android usa MAC aleatoria).',
          style: GoogleFonts.spaceGrotesk(
              color: Colors.white38, fontSize: 11.5, height: 1.4),
        ),
      ]),
    );
  }

  /// Equipos blindados actualmente (con opción de quitarlos de la lista).
  Widget _cardEstado() {
    final macs = _cfg.macs;
    final ips = _cfg.ips;
    return _card(hijos: [
      _titulo('Equipos blindados',
          icono: Icons.verified_user_rounded, color: _C.success),
      const SizedBox(height: 10),
      if (macs.isEmpty && ips.isEmpty)
        Text(
          'Todavía no blindaste ningún equipo. Probá "Detectar mi equipo" o '
          'agregá la MAC / IP a mano.',
          style: GoogleFonts.spaceGrotesk(
              color: _C.textSec, fontSize: 12.5, height: 1.4),
        )
      else ...[
        for (final mac in macs)
          _chip('MAC · $mac', onQuitar: () => _olvidar(mac: mac)),
        for (final ip in ips) _chip('IP · $ip', onQuitar: () => _olvidar(ip: ip)),
      ],
    ]);
  }

  Widget _chip(String texto, {VoidCallback? onQuitar}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _C.surfaceDim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Row(children: [
        const Icon(Icons.shield_rounded, size: 14, color: _C.success),
        const SizedBox(width: 8),
        Expanded(
          child: Text(texto,
              style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 12.5)),
        ),
        if (onQuitar != null)
          InkWell(
            onTap: onQuitar,
            child: const Icon(Icons.close_rounded, size: 16, color: _C.textSec),
          ),
      ]),
    );
  }

  /// IP detectada de este teléfono (tocar = blindar esa IP).
  Widget _cardMisIps() {
    return _card(hijos: [
      _titulo('IP de este teléfono',
          icono: Icons.wifi_rounded, color: _C.primary),
      const SizedBox(height: 6),
      Text(
        'Es la IP con la que el MikroTik ve este teléfono ahora mismo '
        '(incluye la del túnel VPN). Tocá una para blindarla.',
        style: GoogleFonts.spaceGrotesk(
            color: _C.textSec, fontSize: 11.5, height: 1.35),
      ),
      const SizedBox(height: 10),
      if (_misIps.isEmpty)
        Text(
          'No pude leerla (¿estás en la web?). Podés escribirla a mano.',
          style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12.5),
        )
      else
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final ip in _misIps)
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 14, color: _C.primary),
              label: Text(ip, style: GoogleFonts.spaceGrotesk(fontSize: 12)),
              backgroundColor: _C.surfaceDim,
              onPressed: _trabajando ? null : () => _blindar(ips: [ip]),
            ),
        ]),
    ]);
  }

  /// Switch de auto-blindaje al crear fichas.
  Widget _cardAuto() {
    return _card(hijos: [
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _titulo('Blindar automáticamente',
                icono: Icons.autorenew_rounded, color: _C.accent),
            const SizedBox(height: 6),
            Text(
              'Al crear fichas (o abrir este panel) blindo tu equipo con lo '
              'guardado + la IP actual.',
              style: GoogleFonts.spaceGrotesk(
                  color: _C.textSec, fontSize: 11.5, height: 1.35),
            ),
          ]),
        ),
        Switch(
          value: _cfg.auto,
          activeColor: _C.accent,
          onChanged: _trabajando ? null : _cambiarAuto,
        ),
      ]),
    ]);
  }

  /// Botones de acción.
  Widget _cardAcciones() {
    return _card(hijos: [
      _titulo('Blindar ahora', icono: Icons.bolt_rounded, color: _C.warning),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: _boton('Detectar mi equipo', Icons.search_rounded, _C.primary,
              _trabajando ? null : _detectar),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _boton('Agregar MAC/IP', Icons.add_rounded, _C.textSec,
              _trabajando ? null : _agregarManual),
        ),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: _boton(
          _trabajando ? 'Trabajando…' : 'Blindar mi equipo ahora',
          Icons.shield_rounded,
          _C.success,
          _trabajando
              ? null
              : () => _blindar(
                    macs: _cfg.macs,
                    ips: {..._cfg.ips, ..._misIps}.toList(),
                  ),
        ),
      ),
    ]);
  }

  Widget _boton(
    String texto,
    IconData icono,
    Color color,
    VoidCallback? onTap,
  ) {
    return Material(
      color: onTap == null ? color.withOpacity(0.45) : color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icono, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                texto,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
