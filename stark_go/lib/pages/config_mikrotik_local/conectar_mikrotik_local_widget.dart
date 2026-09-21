import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stark_go/app_state.dart';
import 'package:stark_go/services/mikrotik_local_api.dart';
import 'package:stark_go/services/firestore_service.dart';
import 'package:stark_go/services/vpn_controller.dart';
import 'package:stark_go/services/vps_service.dart';
import 'package:stark_go/widgets/sin_soporte_web.dart';
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
  /// 👁️ Muestra la contraseña del MikroTik mientras la escribís.
  bool _verContrasena = false;
  bool _guardandoConfig = false;
  String _ssid = 'Desconocido';
  String? _errorMessage;
  bool _sinPermisoUbicacion = false;

  // ── Acceso REMOTO por el túnel VPN ──
  // La IP del túnel del MikroTik (10.50.50.Y) y sus credenciales ya están
  // guardadas en `config_mikrotik/{uid}`, así que se pueden autocompletar:
  // con el túnel conectado, el router se administra igual que en la red local.
  String? _ipTunel;
  String _usuarioMikrotik = '';
  String _claveMikrotik = '';
  bool _vpnConectado = false;

  final NetworkInfo _networkInfo = NetworkInfo();

  /// Guarda / lee la conexión local del usuario autenticado
  /// (`configuracion_local/{uid}`).
  final FirestoreService _firestore = FirestoreService();

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  /// Primero recupera la conexión guardada del uid; si no hay, detecta la red.
  /// Después lee la IP del túnel (para poder administrar el MikroTik remoto).
  Future<void> _inicializar() async {
    final teniaGuardada = await _cargarConfigGuardada();
    if (!mounted) return;
    try {
      await _detectarRed(aplicarIp: !teniaGuardada);
    } catch (e) {
      // En la web (o sin permisos) la detección puede fallar: no es crítico,
      // el usuario puede escribir la IP (por ejemplo la del túnel) a mano.
      debugPrint('[ModoLocal] No se pudo detectar la red: $e');
    }
    if (!mounted) return;
    await _cargarDatosTunel();
  }

  /// Lee de `config_mikrotik/{uid}` la IP del túnel del MikroTik (10.50.50.Y),
  /// su usuario/clave y si el túnel está conectado. Con eso, "Conexión Local"
  /// sirve también de forma REMOTA (crear pines por el túnel).
  Future<void> _cargarDatosTunel() async {
    try {
      final cfg = await VpsService.obtenerConfig();
      final status = await VpnController.instance.status();
      if (!mounted) return;
      final ip = (cfg?['mikrotikTunelIp'] ?? '').toString().trim();
      setState(() {
        _ipTunel = ip.isEmpty ? null : ip;
        _usuarioMikrotik = (cfg?['mikrotikUser'] ?? '').toString().trim();
        _claveMikrotik = (cfg?['mikrotikPass'] ?? '').toString();
        _vpnConectado = status == VpnStatus.connected;
      });
    } catch (e) {
      debugPrint('[ModoLocal] No se pudo leer la IP del túnel: $e');
    }
  }

  /// Pone en el formulario la IP del túnel y las credenciales del MikroTik que
  /// ya están en Firebase. Es el camino para crear pines estando lejos: túnel
  /// conectado → misma API 8728, sin estar en la WiFi del router.
  void _usarIpDelTunel() {
    final ip = _ipTunel;
    if (ip == null) return;
    setState(() {
      _ipController.text = ip;
      if (_usuarioMikrotik.isNotEmpty) _usuarioController.text = _usuarioMikrotik;
      if (_claveMikrotik.isNotEmpty) _passwordController.text = _claveMikrotik;
      _puertoController.text = _useSsl ? '8729' : '8728';
    });
    _snack('IP del túnel aplicada: $ip', _C.success);
  }

  /// "Detectar red" NO debe pisar la IP que escribiste a mano (por ejemplo la
  /// IP del túnel): si el campo ya tiene valor, sólo refresca el nombre de la
  /// red; si está vacío, sí completa con la puerta de enlace del WiFi.
  Future<void> _detectarRedBoton() async {
    final teniaIp = _ipController.text.trim().isNotEmpty;
    await _detectarRed(aplicarIp: !teniaIp);
    if (!mounted) return;
    _snack(
      teniaIp ? 'Se refrescó tu red. Se mantuvo la IP que tenías puesta.' : 'IP detectada desde tu red WiFi/LAN',
      teniaIp ? _C.textPri : _C.success,
    );
  }

  /// Lee `configuracion_local/{uid}` y precarga el formulario.
  /// Devuelve `true` si había una IP guardada (para no pisarla con la
  /// detección automática de la red).
  Future<bool> _cargarConfigGuardada() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      final cfg = await _firestore.obtenerConfiguracionLocal(uid);
      if (cfg == null || !mounted) return false;
      final ip = (cfg['ip'] ?? '').toString().trim();
      final usuario = (cfg['usuario'] ?? '').toString().trim();
      final clave = (cfg['clave'] ?? '').toString();
      final puerto = cfg['puerto'];
      setState(() {
        if (ip.isNotEmpty) _ipController.text = ip;
        if (usuario.isNotEmpty) _usuarioController.text = usuario;
        if (clave.isNotEmpty) _passwordController.text = clave;
        if (puerto is int && puerto > 0) _puertoController.text = '$puerto';
        _useSsl = (cfg['useSsl'] ?? false) == true;
      });
      return ip.isNotEmpty;
    } catch (e) {
      debugPrint('[ModoLocal] No se pudo leer la config guardada: $e');
      return false;
    }
  }

  /// Guarda la conexión que funcionó, a nombre del usuario autenticado.
  /// Devuelve `true` si quedó guardada en `configuracion_local/{uid}`.
  Future<bool> _guardarConfigLocal(String nombreRouter) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      await _firestore.guardarConfiguracionLocal(
        uid: uid,
        ip: _ipController.text.trim(),
        puerto: int.tryParse(_puertoController.text.trim()) ?? 8728,
        usuario: _usuarioController.text.trim(),
        clave: _passwordController.text,
        useSsl: _useSsl,
        nombreRouter: nombreRouter,
      );
      return true;
    } catch (e) {
      debugPrint('[ModoLocal] No se pudo guardar la config local: $e');
      return false;
    }
  }

  /// Botón "Guardar configuración": deja los datos de TU MikroTik en Firebase
  /// (`configuracion_local/{uid}`) sin necesidad de que la conexión funcione
  /// en ese momento. Sirve para ajustar la IP/usuario/clave y que la
  /// configuración vuelva sola en este u otro teléfono al iniciar sesión.
  Future<void> _guardarConfigManual() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _snack('Inicia sesión para guardar tu configuración', _C.danger);
      return;
    }

    setState(() => _guardandoConfig = true);
    try {
      final nombreRouter = FFAppState().isConnectedLocal && FFAppState().nombreRouterLocal.isNotEmpty
          ? FFAppState().nombreRouterLocal
          : (_ssid == 'Desconocido' || _ssid.isEmpty ? 'MikroTik' : _ssid);
      final ok = await _guardarConfigLocal(nombreRouter);
      if (!mounted) return;
      _snack(
        ok ? 'Configuración guardada en tu cuenta (Firebase)' : 'No se pudo guardar la configuración',
        ok ? _C.success : _C.danger,
      );
    } finally {
      if (mounted) setState(() => _guardandoConfig = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.spaceGrotesk(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  void dispose() {
    _ipController.dispose();
    _usuarioController.dispose();
    _passwordController.dispose();
    _puertoController.dispose();
    super.dispose();
  }

  /// Detecta el SSID y la puerta de enlace (IP del MikroTik) de la Wi-Fi.
  /// Con `aplicarIp = false` sólo refresca el SSID: sirve cuando ya hay una
  /// IP guardada en la cuenta y no queremos pisarla.
  Future<void> _detectarRed({bool aplicarIp = true}) async {
    final bool puede = aplicarIp || _ipController.text.trim().isEmpty;
    // Android/iOS requieren permiso de ubicación para leer el SSID/gateway real.
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      setState(() {
        _sinPermisoUbicacion = true;
        if (puede) _ipController.text = '192.168.88.1';
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
        if (puede) _ipController.text = ipSugerida;
      });
    } catch (e) {
      setState(() {
        if (puede) _ipController.text = '192.168.88.1';
      });
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

      // Guardamos la conexión en tu cuenta (`configuracion_local/{uid}`) para
      // que la IP/puerta de enlace, el usuario, la clave y el puerto vuelvan
      // solos la próxima vez que entres.
      await _guardarConfigLocal(nombreRouter);

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
    // ── WEB: la conexión local (API/FTP por Wi-Fi) sólo existe en la app ──
    if (kIsWeb) {
      return const SinSoporteWeb(
        titulo: 'Conexión Local no está disponible en la web',
        detalle: 'Esta función se conecta al MikroTik por la red Wi-Fi '
            '(API 8728 / FTP 21) y necesita la app del teléfono: el navegador '
            'no puede abrir ese tipo de conexión.',
      );
    }
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
                  _buildTunelCard().animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 14),
                  _buildFormulario().animate().fadeIn(duration: 300.ms, delay: 120.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 14),
                  if (_errorMessage != null) _buildErrorBox().animate().fadeIn(duration: 250.ms).shake(hz: 3, curve: Curves.easeOut),
                  if (_errorMessage != null) const SizedBox(height: 14),
                  _buildBotones().animate().fadeIn(duration: 300.ms, delay: 160.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 10),
                  _buildGuardarConfig().animate().fadeIn(duration: 300.ms, delay: 180.ms).slideY(begin: 0.05, end: 0),
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
              Text('Por tu red WiFi/LAN o por el túnel VPN: en los dos casos usás la API del MikroTik.',
                  style: GoogleFonts.spaceGrotesk(color: Colors.white60, fontSize: 11)),
            ],
          ),
        ),
      ]),
    );
  }

  /// Tarjeta del túnel: muestra la IP del túnel del MikroTik (10.50.50.Y) y
  /// permite autocompletar el formulario para administrar el router REMOTO.
  Widget _buildTunelCard() {
    final ip = _ipTunel;
    final color = _vpnConectado ? _C.success : _C.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_vpnConectado ? Icons.vpn_lock_rounded : Icons.vpn_lock_outlined, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _vpnConectado ? 'Túnel activo — también podés conectar remoto' : 'Túnel VPN (acceso remoto)',
              style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          ip == null
              ? 'Todavía no generaste la IP del túnel del MikroTik. Andá a VPN · Antenas → Configurar → '
                  '"MikroTik (lado del túnel)" → Generar IP del túnel.'
              : 'Con el túnel conectado, el MikroTik se administra por su IP del túnel: $ip. '
                  'Poné esa IP acá (botón de abajo) y podés crear pines igual que si estuvieras en la red local, '
                  'desde cualquier lugar con internet.',
          style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11.5, height: 1.4),
        ),
        if (ip != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _usarIpDelTunel,
              icon: const Icon(Icons.bolt_rounded, size: 17, color: _C.primary),
              label: Text('Usar IP del túnel · $ip',
                  style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 12.5, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: _C.primary.withOpacity(0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
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
            // 👁️ Ojito para revisar la contraseña antes de conectarse.
            visible: _verContrasena,
            onToggleVisible: () => setState(() => _verContrasena = !_verContrasena),
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
    /// Si el campo es `obscure`, con `visible: true` se muestra el texto y se
    /// dibuja el ojito para alternar (lo maneja `onToggleVisible` del State).
    bool visible = false,
    VoidCallback? onToggleVisible,
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
        obscureText: obscure && !visible,
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
          // 👁️ Ojito para ver la contraseña mientras se escribe.
          suffixIcon: obscure && onToggleVisible != null
              ? IconButton(
                  onPressed: onToggleVisible,
                  splashRadius: 18,
                  tooltip: visible ? 'Ocultar contraseña' : 'Ver contraseña',
                  icon: Icon(
                    visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    color: _C.textSec,
                    size: 20,
                  ),
                )
              : null,
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_errorMessage!, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 12, height: 1.4)),
            // Ayuda extra: si estás lejos del router y el túnel está arriba,
            // seguramente la IP guardada es la de la WiFi vieja.
            if (_ipTunel != null && _ipTunel != _ipController.text.trim()) ...[
              const SizedBox(height: 8),
              Text(
                '¿Estás lejos del router? Tocá "Usar IP del túnel · $_ipTunel" y volvé a conectar (necesitás el túnel activo).',
                style: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 11.5, height: 1.4, fontWeight: FontWeight.w600),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _buildBotones() {
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: _isLoading ? null : _detectarRedBoton,
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

  /// Botón para guardar en Firebase los datos del MikroTik sin necesidad de
  /// conectarse ahora (IP, usuario, clave, puerto y SSL).
  Widget _buildGuardarConfig() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: (_isLoading || _guardandoConfig) ? null : _guardarConfigManual,
        icon: _guardandoConfig
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary))
            : const Icon(Icons.save_rounded, size: 17, color: _C.primary),
        label: Text(
          _guardandoConfig ? 'Guardando…' : 'Guardar configuración',
          style: GoogleFonts.spaceGrotesk(color: _C.primary, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: _C.primary.withOpacity(0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
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
