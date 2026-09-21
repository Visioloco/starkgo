import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:stark_go/services/mikrotik_leases_service.dart';
import 'package:stark_go/services/mikrotik_local_api.dart';
import 'package:stark_go/flutter_flow/flutter_flow_util.dart';
import 'package:stark_go/pages/crear_usuario/crear_usuario_widget.dart';

// ─────────────────────────────────────────────────────────────────────────
//  📌 IPs DEL MIKROTIK (leases DHCP)
//
//  ¿Para qué sirve? Conectás una antena → el MikroTik le da una IP por DHCP →
//  necesitás ESA IP para registrar el cliente (campo `ipatn`). Antes había que
//  entrar a WinBox a verla. Acá la tenés: lista, buscador por IP/MAC/nombre,
//  quién la usa según la app, y botones para **usarla** (te lleva a Crear
//  cliente con la IP puesta) o **marcarla como StarkGo** (la deja ESTÁTICA +
//  comentada + en la lista `starkgo`).
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
}

class LeasesMikrotikWidget extends StatefulWidget {
  /// Panel local conectado (opcional): si viene, se lee **directo al router**.
  final MikrotikLocalApi? apiLocal;

  /// Modo "elegir una IP": al tocar **Usar esta IP** la pantalla se cierra y
  /// devuelve la IP elegida (`Navigator.pop(ip)`) en vez de abrir Crear cliente.
  /// Lo usa el botón "buscarla en el MikroTik" del alta de cliente.
  final bool modoSeleccion;

  const LeasesMikrotikWidget({
    super.key,
    this.apiLocal,
    this.modoSeleccion = false,
  });

  static String routeName = 'LeasesMikrotik';
  static String routePath = 'ips-mikrotik';

  @override
  State<LeasesMikrotikWidget> createState() => _LeasesMikrotikWidgetState();
}

class _LeasesMikrotikWidgetState extends State<LeasesMikrotikWidget> {
  List<LeaseDhcp> _leases = const [];
  bool _cargando = true;
  String? _error;
  String _fuente = '';
  String _busqueda = '';
  String _filtro = 'dinamicas';
  String? _marcando;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (mounted) setState(() => _cargando = true);
    final r = await MikrotikLeasesService.cargar(apiLocal: widget.apiLocal);
    if (!mounted) return;
    setState(() {
      _leases = r.leases;
      _fuente = r.fuenteTexto;
      _error = r.error;
      _cargando = false;
    });
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.spaceGrotesk(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  /// 🔎 Filtro + búsqueda (IP, MAC, nombre del equipo, comentario o cliente).
  List<LeaseDhcp> get _visibles {
    final q = _busqueda.trim().toLowerCase();
    return _leases.where((l) {
      switch (_filtro) {
        case 'dinamicas':
          if (!l.dinamica) return false;
          break;
        case 'estaticas':
          if (l.dinamica) return false;
          break;
        case 'libres':
          if (!l.libre) return false;
          break;
        case 'stark':
          if (!l.esStark) return false;
          break;
        default:
          break;
      }
      if (q.isEmpty) return true;
      return l.ip.toLowerCase().contains(q) ||
          l.mac.toLowerCase().contains(q) ||
          l.nombre.toLowerCase().contains(q) ||
          l.comentario.toLowerCase().contains(q) ||
          l.usadoPor.toLowerCase().contains(q);
    }).toList();
  }

  Future<bool?> _confirmar({
    required String titulo,
    required String mensaje,
    required String textoOk,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(titulo,
            style: GoogleFonts.spaceGrotesk(
                color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text(mensaje,
            style: GoogleFonts.spaceGrotesk(
                color: _C.textSec, fontSize: 12.5, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: Text('Cancelar',
                style: GoogleFonts.spaceGrotesk(color: _C.textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(textoOk,
                style: GoogleFonts.spaceGrotesk(
                    color: _C.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// 📌 "Usar esta IP" → abre Crear cliente con la IP ya cargada.
  Future<void> _usar(LeaseDhcp l) async {
    if (!l.libre) {
      final seguir = await _confirmar(
        titulo: 'Esa IP ya está en uso',
        mensaje: '${l.ip} figura como «${l.usadoPor}».\n\n'
            '¿Querés usarla igual para un cliente nuevo?',
        textoOk: 'Usar igual',
      );
      if (seguir != true) return;
    }
    if (!mounted) return;
    // Modo selección (venimos del alta de cliente): devolvemos la IP elegida.
    if (widget.modoSeleccion) {
      Navigator.pop(context, l.ip);
      return;
    }
    await context.pushNamed(
      CrearUsuarioWidget.routeName,
      queryParameters: {
        if (l.ip.isNotEmpty) 'ip': l.ip,
        if (l.nombre.isNotEmpty) 'nombre': l.nombre,
      },
    );
    if (mounted) _cargar();
  }

  /// 🛡️ "Marcar StarkGo" → estática + comentario + address-list `starkgo`.
  Future<void> _marcar(LeaseDhcp l) async {
    final ctrl = TextEditingController(
      text: l.usadoPor.isNotEmpty
          ? l.usadoPor.split(':').last.trim()
          : (l.nombre.isEmpty ? '' : l.nombre),
    );
    final nombre = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Marcar ${l.ip}',
            style: GoogleFonts.spaceGrotesk(
                color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Va a quedar:\n'
              '• IP FIJA (estática) → la antena no cambia de IP\n'
              '• comentario «StarkGo <nombre>» en el MikroTik\n'
              '• la IP en la lista «starkgo»',
              style: GoogleFonts.spaceGrotesk(
                  color: _C.textSec, fontSize: 12.5, height: 1.45),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Nombre para el comentario',
                hintText: 'Ej: Juan Pérez',
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
            child: Text('Marcar',
                style: GoogleFonts.spaceGrotesk(
                    color: _C.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (nombre == null) return;

    setState(() => _marcando = l.ip);
    try {
      final r = await MikrotikLeasesService.marcar(
        ip: l.ip,
        nombre: nombre,
        apiLocal: widget.apiLocal,
      );
      _snack(r.detalle, r.ok ? _C.success : _C.danger);
    } finally {
      if (mounted) setState(() => _marcando = null);
      await _cargar();
    }
  }

  // ══════════════════════════════════════════════════════════
  //  UI
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final visibles = _visibles;
    return Scaffold(
      backgroundColor: _C.surfaceDim,
      body: SafeArea(
        child: Column(children: [
          _header(),
          _buscador(),
          _filtros(),
          const SizedBox(height: 6),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(color: _C.primary))
                : (_error != null && _leases.isEmpty)
                    ? _errorBox()
                    : visibles.isEmpty
                        ? _vacio()
                        : RefreshIndicator(
                            onRefresh: _cargar,
                            color: _C.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
                              itemCount: visibles.length,
                              itemBuilder: (_, i) => _fila(visibles[i]),
                            ),
                          ),
          ),
        ]),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_C.dark, Color(0xFF1E293B)]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('IPs del MikroTik',
                  style: GoogleFonts.spaceGrotesk(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              Text('Leases del DHCP · $_fuente',
                  style: GoogleFonts.spaceGrotesk(color: Colors.white60, fontSize: 11.5)),
            ]),
          ),
          GestureDetector(
            onTap: _cargando ? null : _cargar,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Text(
          'Conectá la antena y buscá acá la IP que le dio el router: la usás al '
          'crear el cliente y la podés dejar fija.',
          style: GoogleFonts.spaceGrotesk(
              color: Colors.white54, fontSize: 11.5, height: 1.35),
        ),
      ]),
    );
  }

  Widget _buscador() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: TextField(
        onChanged: (v) => setState(() => _busqueda = v),
        style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Buscar IP, MAC o nombre…',
          hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13.5),
          prefixIcon: const Icon(Icons.search_rounded, color: _C.textSec, size: 20),
          suffixIcon: _busqueda.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: _C.textSec),
                  onPressed: () => setState(() => _busqueda = ''),
                ),
          filled: true,
          fillColor: _C.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _filtros() {
    const opciones = <List<String>>[
      ['dinamicas', 'Dinámicas'],
      ['libres', 'Sin registrar'],
      ['estaticas', 'Estáticas'],
      ['stark', 'Stark'],
      ['todas', 'Todas'],
    ];
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          for (final o in opciones)
            GestureDetector(
              onTap: () => setState(() => _filtro = o[0]),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _filtro == o[0] ? _C.primary : _C.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _filtro == o[0] ? _C.primary : _C.border),
                ),
                child: Text(o[1],
                    style: GoogleFonts.spaceGrotesk(
                        color: _filtro == o[0] ? Colors.white : _C.textSec,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fila(LeaseDhcp l) {
    final enUso = !l.libre;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: l.esStark ? _C.success.withOpacity(0.45) : _C.border,
          width: l.esStark ? 1.4 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(l.ip,
              style: GoogleFonts.spaceGrotesk(
                  color: _C.textPri,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3)),
          const SizedBox(width: 8),
          _chip(l.dinamica ? 'DINÁMICA' : 'FIJA', l.dinamica ? _C.warning : _C.success),
          if (l.esStark) ...[
            const SizedBox(width: 6),
            _chip('STARK', _C.primary),
          ],
          const Spacer(),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: l.ip));
              _snack('IP copiada: ${l.ip}', _C.primary);
            },
            child: const Icon(Icons.copy_rounded, size: 16, color: _C.textSec),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          '${l.nombre.isEmpty ? '(sin nombre)' : l.nombre}'
          '${l.mac.isEmpty ? '' : ' · ${l.mac}'}',
          style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Row(children: [
          Icon(
            enUso
                ? (l.esSectorial ? Icons.router_rounded : Icons.person_rounded)
                : Icons.check_circle_outline_rounded,
            size: 13,
            color: enUso ? _C.accent : _C.textSec,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              enUso ? l.usadoPor : 'Sin registrar en la app',
              style: GoogleFonts.spaceGrotesk(
                  color: enUso ? _C.accent : _C.textSec,
                  fontSize: enUso ? 12 : 11.5,
                  fontWeight: enUso ? FontWeight.w600 : FontWeight.w400),
            ),
          ),
        ]),
        if (l.comentario.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Comentario: ${l.comentario}',
              style: GoogleFonts.spaceGrotesk(
                  color: _C.textSec, fontSize: 11.5, fontStyle: FontStyle.italic)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _boton(
              icon: Icons.add_circle_outline_rounded,
              texto: 'Usar esta IP',
              color: _C.primary,
              onTap: () => _usar(l),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _boton(
              icon: _marcando == l.ip
                  ? Icons.hourglass_top_rounded
                  : Icons.shield_rounded,
              texto: _marcando == l.ip
                  ? 'Marcando…'
                  : (l.esStark ? 'Re-marcar' : 'Marcar StarkGo'),
              color: _C.success,
              onTap: _marcando == null ? () => _marcar(l) : null,
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _boton({
    required IconData icon,
    required String texto,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: onTap == null ? color.withOpacity(0.4) : color,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(texto,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String texto, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6)),
        child: Text(texto,
            style: GoogleFonts.spaceGrotesk(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4)),
      );

  Widget _vacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_find_rounded, size: 42, color: _C.textSec),
          const SizedBox(height: 12),
          Text(
            _busqueda.isEmpty
                ? 'No hay equipos en este filtro.\nProbá con «Todas» o «Sin registrar».'
                : 'Nada coincide con «$_busqueda».',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
                color: _C.textSec, fontSize: 13, height: 1.4),
          ),
        ]),
      ),
    );
  }

  Widget _errorBox() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.portable_wifi_off_rounded, size: 42, color: _C.danger),
          const SizedBox(height: 12),
          Text('No pude leer los equipos del MikroTik',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                  color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_error ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                  color: _C.textSec, fontSize: 12, height: 1.4)),
          const SizedBox(height: 16),
          _boton(
            icon: Icons.refresh_rounded,
            texto: 'Reintentar',
            color: _C.primary,
            onTap: _cargar,
          ),
        ]),
      ),
    );
  }
}
