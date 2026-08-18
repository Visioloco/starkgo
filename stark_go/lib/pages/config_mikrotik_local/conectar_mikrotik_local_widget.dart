import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stark_go/app_state.dart';
import 'package:stark_go/services/mikrotik_local_api.dart';
import 'dashboard_local_widget.dart';

// ─────────────────────────────────────────────────────────────────────────
// Paleta — misma que el resto del flujo local.
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

class ConectarMikrotikLocalWidget extends StatefulWidget {
  const ConectarMikrotikLocalWidget({Key? key}) : super(key: key);

  @override
  State<ConectarMikrotikLocalWidget> createState() => _ConectarMikrotikLocalWidgetState();
}

class _ConectarMikrotikLocalWidgetState extends State<ConectarMikrotikLocalWidget> {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController();
  final _usuarioController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController();
  final _puertoController = TextEditingController(text: '8728');
  bool _useSsl = false;
  bool _isLoading = false;
  String _ssid = 'Desconocido';
  String? _errorMessage;
  bool _sinPermisoUbicacion = false;

  final NetworkInfo _networkInfo = NetworkInfo();

  @override
  void initState() {
    super.initState();
    _detectarRed();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _usuarioController.dispose();
    _passwordController.dispose();
    _puertoController.dispose();
    super.dispose();
  }

  Future<void> _detectarRed() async {
    // Android/iOS requieren permiso de ubicación para leer el SSID/gateway real.
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      setState(() {
        _sinPermisoUbicacion = true;
        _ipController.text = '192.168.88.1';
      });
      return;
    }

    setState(() => _sinPermisoUbicacion = false);

    try {
      final wifiName = await _networkInfo.getWifiName();
      final wifiIP = await _networkInfo.getWifiIP();
      final gateway = await _networkInfo.getWifiGatewayIP();

      String ipSugerida = '192.168.88.1';
      if (gateway != null && gateway.isNotEmpty) {
        ipSugerida = gateway;
      } else if (wifiIP != null && wifiIP.isNotEmpty) {
        final parts = wifiIP.split('.');
        if (parts.length == 4) ipSugerida = '${parts[0]}.${parts[1]}.${parts[2]}.1';
      }

      setState(() {
        _ssid = wifiName?.replaceAll('"', '') ?? 'Desconocido';
        _ipController.text = ipSugerida;
      });
    } catch (e) {
      setState(() => _ipController.text = '192.168.88.1');
    }
  }

  Future<void> _probarConexion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final api = MikrotikLocalApi(
      ip: _ipController.text.trim(),
      usuario: _usuarioController.text.trim(),
      password: _passwordController.text.trim(),
      puerto: int.tryParse(_puertoController.text.trim()) ?? 8728,
      useSsl: _useSsl,
      timeout: const Duration(seconds: 10),
    );

    try {
      final nombreRouter = await api.probarConexion();

      final appState = FFAppState();
      appState.conectarLocal(api: api, nombre: nombreRouter, ip: api.ip);

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DashboardLocalWidget(api: api, nombreRouter: nombreRouter)),
      );
    } on MikrotikLocalException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.mensaje;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error inesperado: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final yaConectado = FFAppState().isConnectedLocal;

    return Scaffold(
      backgroundColor: _C.surfaceDim,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(context, yaConectado),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
              child: Form(
                key: _formKey,
                child: Column(children: [
                  if (yaConectado) _buildEstadoConectado().animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
                  if (yaConectado) const SizedBox(height: 14),
                  _buildBanner().animate().fadeIn(duration: 300.ms, delay: 40.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 14),
                  if (_sinPermisoUbicacion) _buildAvisoPermiso().animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
                  if (_sinPermisoUbicacion) const SizedBox(height: 14),
                  _buildRedInfo().animate().fadeIn(duration: 300.ms, delay: 80.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 14),
                  _buildFormulario().animate().fadeIn(duration: 300.ms, delay: 120.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 14),
                  if (_errorMessage != null) _buildErrorBox().animate().fadeIn(duration: 250.ms).shake(hz: 3, curve: Curves.easeOut),
                  if (_errorMessage != null) const SizedBox(height: 14),
                  _buildBotones().animate().fadeIn(duration: 300.ms, delay: 160.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 14),
                  _buildNotaServicioApi().animate().fadeIn(duration: 300.ms, delay: 200.ms),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool yaConectado) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Modo Local', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 20, fontWeight: FontWeight.w800)),
              Text('Conexión directa por red', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
            ],
          ),
        ),
        if (yaConectado)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _C.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.success.withOpacity(0.3)),
            ),
            child: Row(children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: _C.success, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('En línea', style: GoogleFonts.spaceGrotesk(color: _C.success, fontSize: 11.5, fontWeight: FontWeight.w700)),
            ]),
          ),
      ]),
    );
  }

  Widget _buildEstadoConectado() {
    final appState = FFAppState();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.success.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: _C.success.withOpacity(0.15), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_rounded, color: _C.success, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ya conectado localmente',
                  style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13.5, fontWeight: FontWeight.w700)),
              Text('${appState.nombreRouterLocal} · ${appState.ipRouterLocal}',
                  style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11.5)),
            ],
          ),
        ),
        TextButton(
          onPressed: () {
            FFAppState().desconectarLocal();
            setState(() {});
          },
          child: Text('Desconectar', style: GoogleFonts.spaceGrotesk(color: _C.danger, fontWeight: FontWeight.w600, fontSize: 12.5)),
        ),
      ]),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_C.dark, Color(0xFF1E293B)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _C.dark.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_C.success, Color(0xFF16A34A)]), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.wifi_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Conexión directa al router',
                  style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('Sin VPS, sin túnel — solo tu red WiFi/LAN.', style: GoogleFonts.spaceGrotesk(color: Colors.white60, fontSize: 11)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildAvisoPermiso() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.warning.withOpacity(0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.location_off_rounded, color: _C.warning, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Permiso de ubicación necesario',
                  style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('El sistema lo exige para leer el nombre de tu red WiFi. Puedes ingresar la IP manualmente sin él.',
                  style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, height: 1.4)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _detectarRed,
                child: Text('Reintentar permiso',
                    style: GoogleFonts.spaceGrotesk(color: _C.warning, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildRedInfo() {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: _C.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.wifi_rounded, color: _C.accent, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_ssid, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            GestureDetector(
              onTap: _detectarRed,
              child: Icon(Icons.refresh_rounded, color: _C.textSec, size: 18),
            ),
          ]),
          const SizedBox(height: 10),
          Text('IP sugerida: ${_ipController.text}', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
          const SizedBox(height: 4),
          Text('Asegúrate de estar en la misma red que el MikroTik.',
              style: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.8), fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _buildFormulario() {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_C.primary, _C.accent]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.router_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Datos del router', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 18),
          _field(
            controller: _ipController,
            label: 'IP DEL MIKROTIK',
            hint: '192.168.88.1',
            icon: Icons.dns_rounded,
            color: _C.accent,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa la IP del MikroTik';
              final parts = v.split('.');
              if (parts.length != 4) return 'IP inválida';
              for (var part in parts) {
                if (int.tryParse(part) == null) return 'IP inválida';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          _field(
            controller: _usuarioController,
            label: 'USUARIO',
            hint: 'admin',
            icon: Icons.person_rounded,
            color: _C.primary,
            validator: (v) => (v == null || v.isEmpty) ? 'Ingresa el usuario' : null,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _passwordController,
            label: 'CONTRASEÑA',
            hint: '••••••••',
            icon: Icons.lock_rounded,
            color: _C.purple,
            obscure: true,
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: _field(
                controller: _puertoController,
                label: 'PUERTO',
                hint: '8728',
                icon: Icons.settings_ethernet_rounded,
                color: _C.warning,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (int.tryParse(v) == null) return 'Número inválido';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 6),
                    child: Text('SSL',
                        style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: _C.surfaceDim, borderRadius: BorderRadius.circular(12)),
                    child: SwitchListTile(
                      value: _useSsl,
                      onChanged: (value) {
                        setState(() {
                          _useSsl = value;
                          _puertoController.text = value ? '8729' : '8728';
                        });
                      },
                      activeColor: _C.warning,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(_useSsl ? 'Activo' : 'Inactivo',
                          style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    String? Function(String?)? validator,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child:
            Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      ),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        validator: validator,
        style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.5), fontSize: 13),
          prefixIcon: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: color, size: 16),
          ),
          filled: true,
          fillColor: _C.surfaceDim,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(14)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: color, width: 1.6), borderRadius: BorderRadius.circular(14)),
          errorBorder:
              OutlineInputBorder(borderSide: const BorderSide(color: _C.danger, width: 1.4), borderRadius: BorderRadius.circular(14)),
          errorStyle: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 10.5),
        ),
      ),
    ]);
  }

  Widget _buildErrorBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.danger.withOpacity(0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline_rounded, color: _C.danger, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(_errorMessage!, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 12, height: 1.4)),
        ),
      ]),
    );
  }

  Widget _buildBotones() {
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: _isLoading ? null : _detectarRed,
          icon: const Icon(Icons.wifi_find_rounded, size: 17, color: _C.textSec),
          label: Text('Detectar red', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            side: const BorderSide(color: _C.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_C.success, Color(0xFF16A34A)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: _C.success.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 5))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _isLoading ? null : _probarConexion,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.link_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text('Conectar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                        ]),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildNotaServicioApi() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _C.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline_rounded, color: _C.primary, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Asegúrate que el servicio API esté habilitado en el MikroTik (IP → Services → api / api-ssl).',
            style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11.5, height: 1.4),
          ),
        ),
      ]),
    );
  }
}
