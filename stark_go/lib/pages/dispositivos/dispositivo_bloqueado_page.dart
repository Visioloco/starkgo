import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/nav/nav.dart';
import '/index.dart';
import '/services/dispositivo_service.dart';

// ══════════════════════════════════════════════════════════════════
//  LÍMITE DE TELÉFONOS ALCANZADO
//
//  Se muestra cuando la cuenta ya está abierta en
//  [kMaxDispositivosPorCuenta] teléfonos y este es uno nuevo.
//
//  El usuario puede:
//    · Liberar un teléfono de la lista y usar este.
//    · Usar este teléfono liberando el más antiguo.
//    · Cerrar sesión (así libera el lugar de este teléfono).
// ══════════════════════════════════════════════════════════════════

class _C {
  static const Color primary = Color(0xFF1A73E8);
  static const Color accent = Color(0xFF00C6AE);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFE53935);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF1F5F9);
  static const Color textPri = Color(0xFF0F172A);
  static const Color textSec = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
}

class DispositivoBloqueadoWidget extends StatefulWidget {
  const DispositivoBloqueadoWidget({super.key});

  static String routeName = 'DispositivoBloqueado';
  static String routePath = 'dispositivo-bloqueado';

  @override
  State<DispositivoBloqueadoWidget> createState() =>
      _DispositivoBloqueadoWidgetState();
}

class _DispositivoBloqueadoWidgetState
    extends State<DispositivoBloqueadoWidget> {
  bool _cargando = true;
  bool _ocupado = false;
  List<DispositivoInfo> _dispositivos = const [];
  String? _aviso;

  @override
  void initState() {
    super.initState();
    _verificar();
  }

  /// Consulta el estado actual: si ya hay lugar (por ejemplo, liberaron un
  /// teléfono desde otro celular), entra directo al Home.
  Future<void> _verificar() async {
    final r = await DispositivoService.verificarYRegistrar();
    if (!mounted) return;
    if (r.permitido) {
      _entrar();
      return;
    }
    setState(() {
      _dispositivos = r.dispositivos;
      _cargando = false;
    });
  }

  void _entrar() {
    if (!mounted) return;
    context.goNamed(HomeWidget.routeName);
  }

  /// Libera un teléfono de la lista y vuelve a intentar entrar.
  Future<void> _liberar(DispositivoInfo d) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    final ok = await DispositivoService.liberar(d.id);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _ocupado = false;
        _aviso = 'No se pudo liberar. Revisá tu conexión e intentá de nuevo.';
      });
      return;
    }
    setState(() {
      _ocupado = false;
      _aviso = 'Liberaste "${d.nombre}". Ahora este teléfono puede entrar.';
    });
    await _verificar();
  }

  /// Libera el teléfono más antiguo y entra con este.
  Future<void> _liberarMasAntiguo() async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    final liberado = await DispositivoService.liberarMasAntiguo(_dispositivos);
    if (!mounted) return;
    setState(() => _ocupado = false);
    if (liberado == null) {
      setState(() => _aviso =
          'No hay otro teléfono para liberar. Cerrá sesión en uno de ellos.');
      return;
    }
    await _verificar();
    if (mounted && _aviso == null) {
      setState(() => _aviso = 'Liberaste "$liberado".');
    }
  }

  Future<void> _cerrarSesion() async {
    if (_ocupado) return;
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Cerrar sesión',
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
            content: Text(
                '¿Cerrar sesión en este teléfono? Se libera su lugar en la cuenta.',
                style: GoogleFonts.spaceGrotesk()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancelar',
                    style: GoogleFonts.spaceGrotesk(color: _C.textSec)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.danger,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Cerrar sesión',
                    style: GoogleFonts.spaceGrotesk(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;
    setState(() => _ocupado = true);
    await authManager.signOut();
    if (!mounted) return;
    context.goNamed(LoginWidget.routeName);
  }

  // ══════════════════════════════════════════
  //  UI
  // ══════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surfaceDim,
      body: SafeArea(
        child: _cargando
            ? Center(
                child: CircularProgressIndicator(
                    color: _C.primary, strokeWidth: 2.5))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildEncabezado(),
                    const SizedBox(height: 20),
                    _buildLista(),
                    const SizedBox(height: 18),
                    if (_aviso != null) ...[
                      _buildAviso(),
                      const SizedBox(height: 14),
                    ],
                    _buildBotonPrincipal(),
                    const SizedBox(height: 10),
                    _buildBotonSecundario(),
                    const SizedBox(height: 18),
                    _buildNota(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEncabezado() {
    return Column(
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_C.danger, _C.warning]),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: _C.danger.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: const Icon(Icons.phonelink_lock_rounded,
              color: Colors.white, size: 44),
        ).animate().fadeIn(duration: 350.ms).scale(
            begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
        const SizedBox(height: 18),
        Text(
          'Límite de teléfonos alcanzado',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
              color: _C.textPri, fontSize: 22, fontWeight: FontWeight.w800),
        ).animate().fadeIn(duration: 350.ms, delay: 80.ms),
        const SizedBox(height: 8),
        Text(
          'Tu cuenta se puede abrir en $kMaxDispositivosPorCuenta teléfonos '
          'como máximo y ahora mismo está abierta en estos:',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
              color: _C.textSec, fontSize: 13.5, height: 1.4),
        ).animate().fadeIn(duration: 350.ms, delay: 140.ms),
      ],
    );
  }

  Widget _buildLista() {
    if (_dispositivos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
        ),
        child: Text(
          'No pude leer la lista de teléfonos. Cerrá sesión y volvé a entrar.',
          style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13),
        ),
      );
    }
    return Column(
      children: _dispositivos
          .map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildTarjeta(d),
              ))
          .toList(),
    );
  }

  Widget _buildTarjeta(DispositivoInfo d) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: d.esEste ? _C.primary.withOpacity(0.5) : _C.border,
            width: d.esEste ? 1.6 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (d.esEste ? _C.primary : _C.textSec).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
                d.esEste
                    ? Icons.phone_android_rounded
                    : Icons.phone_iphone_rounded,
                color: d.esEste ? _C.primary : _C.textSec,
                size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      d.nombre,
                      style: GoogleFonts.spaceGrotesk(
                          color: _C.textPri,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (d.esEste)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _C.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Este teléfono',
                          style: GoogleFonts.spaceGrotesk(
                              color: _C.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                ]),
                const SizedBox(height: 2),
                Text('Último uso: ${d.ultimoUsoTexto}',
                    style: GoogleFonts.spaceGrotesk(
                        color: _C.textSec, fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!d.esEste)
            TextButton(
              onPressed: _ocupado ? null : () => _liberar(d),
              child: Text('Liberar',
                  style: GoogleFonts.spaceGrotesk(
                      color: _C.danger,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _buildAviso() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _C.accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.accent.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: _C.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_aviso!,
                style: GoogleFonts.spaceGrotesk(
                    color: _C.textPri, fontSize: 12, height: 1.35)),
          ),
        ]),
      );

  Widget _buildBotonPrincipal() => SizedBox(
        height: 54,
        child: ElevatedButton.icon(
          onPressed: _ocupado ? null : _liberarMasAntiguo,
          icon: const Icon(Icons.login_rounded, size: 20),
          label: Text(
            _ocupado ? 'Esperá…' : 'Usar este teléfono aquí',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 15, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.primary,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );

  Widget _buildBotonSecundario() => SizedBox(
        height: 50,
        child: OutlinedButton.icon(
          onPressed: _ocupado ? null : _cerrarSesion,
          icon: const Icon(Icons.logout_rounded, size: 18, color: _C.danger),
          label: Text('Cerrar sesión en este teléfono',
              style:
                  GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 13.5)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _C.danger.withOpacity(0.4)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );

  Widget _buildNota() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'Al liberar un teléfono, ese teléfono deja de ocupar un lugar: la '
          'próxima vez que abra la app tendrá que liberar otro (o cerrar '
          'sesión). Los teléfonos que no abren la app por '
          '$kDiasActividadDispositivo días liberan su lugar solos.',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
              color: _C.textSec, fontSize: 11, height: 1.4),
        ),
      );
}
