import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:stark_go/services/antenas_service.dart';
import 'package:stark_go/services/vps_service.dart';
import 'package:stark_go/services/wireguard_keygen.dart';

// ══════════════════════════════════════════════════════════════
//  ConfigVpnWidget — crea/edita la configuración del túnel en
//  Firestore (`vpn_config/{uid}`) por empresa/técnico autenticado.
//
//  · Endpoint del servidor WireGuard (ej: 10.50.50.2:13231)
//  · Par de claves generado en el dispositivo (cliente)
//  · Clave pública del servidor (Peer)
//  · IP del cliente asignada dinámicamente desde 10.10.15.0/24
//  · AllowedIPs / DNS / Keepalive
// ══════════════════════════════════════════════════════════════

class _C {
  static const Color primary = Color(0xFF1A73E8);
  static const Color accent = Color(0xFF00C6AE);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFE53935);
  static const Color dark = Color(0xFF0F172A);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF1F5F9);
  static const Color textPri = Color(0xFF0F172A);
  static const Color textSec = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);

  /// Enmascara una clave para mostrarla (nunca en texto plano).
  static String mask(String s) =>
      s.length < 8 ? '***' : '${s.substring(0, 4)}…${s.substring(s.length - 4)}';
}

class ConfigVpnWidget extends StatefulWidget {
  const ConfigVpnWidget({super.key});

  static String routeName = 'VpnConfig';
  static String routePath = 'vpn-config';

  @override
  State<ConfigVpnWidget> createState() => _ConfigVpnWidgetState();
}

class _ConfigVpnWidgetState extends State<ConfigVpnWidget> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _endpointCtrl =
      TextEditingController(text: '5.161.88.42:1234');
  late final TextEditingController _peerPubCtrl = TextEditingController();
  late final TextEditingController _privCtrl = TextEditingController();
  late final TextEditingController _addressCtrl = TextEditingController();
  late final TextEditingController _allowedCtrl =
      TextEditingController(text: '10.50.50.0/24, 10.10.15.0/24');
  late final TextEditingController _dnsCtrl = TextEditingController();
  late final TextEditingController _keepaliveCtrl =
      TextEditingController(text: '25');

  bool _cargando = true;
  bool _guardando = false;
  bool _generandoClaves = false;
  bool _mostrarPrivada = false;
  bool _mostrarPreview = false;
  String? _error;
  String? _clientPublicKey;

  /// true si la clave privada actual no coincide con la registrada en el VPS.
  bool _claveNoCoincide = false;

  /// Subred de antenas asignada por el VPS (10.10.x.0/24). No editable.
  String? _redAntenas;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _endpointCtrl.dispose();
    _peerPubCtrl.dispose();
    _privCtrl.dispose();
    _addressCtrl.dispose();
    _allowedCtrl.dispose();
    _dnsCtrl.dispose();
    _keepaliveCtrl.dispose();
    super.dispose();
  }
  // ── Cargar config existente / sugerir IP libre ─────────────────
  Future<void> _cargar() async {
    final uid = _uid;
    if (uid == null) {
      if (mounted) setState(() => _cargando = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vpn_config')
          .doc(uid)
          .get();
      if (doc.exists && mounted) {
        final d = doc.data() as Map<String, dynamic>;
        _endpointCtrl.text = (d['endpoint'] ?? '').toString();
        _peerPubCtrl.text = (d['peerPublicKey'] ?? '').toString();
        _privCtrl.text = (d['privateKey'] ?? '').toString();
        _addressCtrl.text = (d['address'] ?? '').toString();
        _dnsCtrl.text = (d['dns'] ?? '').toString();
        _keepaliveCtrl.text = (d['persistentKeepalive'] ?? 25).toString();
        _clientPublicKey = (d['clientPublicKey'] ?? '').toString();
        // Subred de antenas asignada por el VPS (solo lectura).
        _redAntenas = (d['redAntenas'] ?? '').toString().isEmpty
            ? null
            : d['redAntenas'].toString();
        _allowedCtrl.text = _allowedIpsPorDefecto();
        final registrada = (d['clientPublicKey'] ?? '').toString().trim();
        final derivada = _privCtrl.text.isNotEmpty
            ? await WireGuardKeygen.derivarPublica(_privCtrl.text)
            : null;
        if (registrada.isEmpty) {
          _clientPublicKey = derivada;
          _claveNoCoincide = false;
        } else {
          _clientPublicKey = registrada;
          _claveNoCoincide = derivada != null && derivada != registrada;
        }
      }
      // Si no hay config, dejamos la IP vacía: el botón
      // "Registrar en el VPS" la asigna dinámicamente desde el pool.
    } catch (e) {
      if (mounted) _error = 'No se pudo leer la configuración: ${e.runtimeType}';
    }
    if (mounted) setState(() => _cargando = false);
  }

  // ── Generar par de claves ─────────────────────────────────────
  Future<void> _generarClaves() async {
    setState(() => _generandoClaves = true);
    try {
      final par = await WireGuardKeygen.generarParClaves();
      _privCtrl.text = par.privateKey;
      _clientPublicKey = par.publicKey;
      // Nueva clave ≠ la registrada en el VPS hasta que se vuelva a registrar.
      _claveNoCoincide = true;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron generar las claves')),
        );
      }
    } finally {
      if (mounted) setState(() => _generandoClaves = false);
    }
  }

  // ── Derivar pública de la privada escrita a mano ───────────────
  Future<void> _derivarPublica() async {
    final pub = await WireGuardKeygen.derivarPublica(_privCtrl.text);
    if (!mounted) return;
    if (pub == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La clave privada no es válida')),
      );
      return;
    }
    setState(() => _clientPublicKey = pub);
  }

  // ── AllowedIPs por defecto: hub 10.50.50.0/24 + subred de antenas ──
  String _allowedIpsPorDefecto() {
    final red = _redAntenas ?? '10.10.15.0/24';
    return '10.50.50.0/24, $red';
  }

  // ── Registrar el peer en el VPS (IP dinámica del pool) ─────────
  // 1) Obtiene los datos del servidor (public key + endpoint) y los autocompleta.
  // 2) Da de alta el peer del cliente y asigna la próxima IP libre (10.50.50.x).
  Future<void> _registrarEnVps() async {
    var publica = _clientPublicKey;
    if ((publica ?? '').isEmpty) {
      publica = await WireGuardKeygen.derivarPublica(_privCtrl.text);
    }
    if (publica == null || publica.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero generá o pegá tu clave privada')),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      final info = await VpsService.obtenerInfoVps();
      if (info == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo conectar al VPS. Verificá tu apikey en '
                'Config. MikroTik VPS y que el servidor tenga /wg/info.'),
          ),
        );
        return;
      }
      // Autocompletar datos del servidor si faltan.
      if (info.serverPublicKey.isNotEmpty) _peerPubCtrl.text = info.serverPublicKey;
      if (info.endpoint.isNotEmpty) _endpointCtrl.text = info.endpoint;

      final registro = await VpsService.registrarPeerVps(
        publicKey: publica,
        nombre: FirebaseAuth.instance.currentUser?.displayName ?? 'Técnico',
      );
      if (registro == null || registro.ip.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El VPS no pudo asignar una IP. '
              'Revisá que /wg/register esté activo.')),
        );
        return;
      }
      setState(() {
        _addressCtrl.text = registro.address;
        _clientPublicKey = publica;
        _claveNoCoincide = false;
        if (registro.redAntenas != null && registro.redAntenas!.isNotEmpty) {
          _redAntenas = registro.redAntenas;
          _allowedCtrl.text = _allowedIpsPorDefecto();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Peer registrado en el VPS · IP asignada: ${registro.ip}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error registrando en el VPS: ${e.runtimeType}')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
  // ── Guardar en Firestore ──────────────────────────────────────
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = _uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para guardar la configuración')),
      );
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      // Nos aseguramos de tener la pública derivada de la privada actual.
      var publica = _clientPublicKey;
      if ((publica ?? '').isEmpty) {
        publica = await WireGuardKeygen.derivarPublica(_privCtrl.text);
      }

      await FirebaseFirestore.instance.collection('vpn_config').doc(uid).set({
        'privateKey': _privCtrl.text.trim(),
        'clientPublicKey': publica ?? '',
        'peerPublicKey': _peerPubCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'allowedIps': _allowedCtrl.text.trim(),
        'endpoint': _endpointCtrl.text.trim(),
        'dns': _dnsCtrl.text.trim().isEmpty ? null : _dnsCtrl.text.trim(),
        'persistentKeepalive': int.tryParse(_keepaliveCtrl.text.trim()) ?? 25,
        'actualizadoEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración guardada ✓'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).maybePop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar: ${e.runtimeType}');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ── Borrar configuración ──────────────────────────────────────
  Future<void> _borrar() async {
    final uid = _uid;
    if (uid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar configuración VPN?'),
        content: const Text('Se eliminará vpn_config. Tendrás que volver a configurar el túnel.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar', style: TextStyle(color: _C.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await FirebaseFirestore.instance.collection('vpn_config').doc(uid).delete();
      if (mounted) {
        Navigator.of(context).maybePop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo borrar: ${e.runtimeType}');
      }
    }
  }
  // ── Vista previa del wg-quick (privada enmascarada) ────────────
  String _wgQuickPreview() {
    final buf = StringBuffer()
      ..writeln('[Interface]')
      ..writeln('PrivateKey = ${_privCtrl.text.isEmpty ? '…' : _C.mask(_privCtrl.text)}')
      ..writeln('Address = ${_addressCtrl.text.isEmpty ? '…' : _addressCtrl.text}');
    if (_dnsCtrl.text.trim().isNotEmpty) {
      buf.writeln('DNS = ${_dnsCtrl.text.trim()}');
    }
    buf
      ..writeln()
      ..writeln('[Peer]')
      ..writeln('PublicKey = ${_peerPubCtrl.text.isEmpty ? '…' : _C.mask(_peerPubCtrl.text)}')
      ..writeln('AllowedIPs = ${_allowedCtrl.text.isEmpty ? '…' : _allowedCtrl.text}')
      ..writeln('Endpoint = ${_endpointCtrl.text.isEmpty ? '…' : _endpointCtrl.text}')
      ..writeln('PersistentKeepalive = ${_keepaliveCtrl.text.isEmpty ? '…' : _keepaliveCtrl.text}');
    return buf.toString();
  }

  // ── Validadores ───────────────────────────────────────────────
  String? _validarEndpoint(String? v) {
    final valor = (v ?? '').trim();
    if (valor.isEmpty) return 'Ingresá el endpoint';
    final parts = valor.split(':');
    if (parts.length != 2 || parts[0].isEmpty || int.tryParse(parts[1]) == null) {
      return 'Formato: host:puerto (ej: 10.50.50.2:13231)';
    }
    return null;
  }

  String? _validarClave(String? v, String campo) {
    final valor = (v ?? '').trim();
    if (valor.isEmpty) return 'Ingresá la $campo';
    if (!WireGuardKeygen.esClaveValida(valor)) {
      return 'Clave inválida (base64 de 32 bytes)';
    }
    return null;
  }

  String? _validarAddress(String? v) {
    final valor = (v ?? '').trim();
    if (valor.isEmpty) return 'Ingresá la IP (o usá "Registrar en el VPS")';
    final ip = valor.split('/').first.trim();
    if (!AntenasService.ipEnSubred10_10_15(ip) && !_ipEn10_50_50(ip)) {
      return 'La IP debe estar en el pool del VPS (10.50.50.0/24)';
    }
    return null;
  }

  bool _ipEn10_50_50(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    if (parts[0] != '10' || parts[1] != '50' || parts[2] != '50') return false;
    final ultimo = int.tryParse(parts[3]);
    return ultimo != null && ultimo >= 2 && ultimo <= 250;
  }

  String? _validarKeepalive(String? v) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null || n < 0 || n > 65535) return '0-65535';
    return null;
  }

  // ══════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surfaceDim,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator(color: _C.primary))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildForm(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, color: _C.textPri),
          ),
          const SizedBox(width: 4),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_C.primary, _C.accent]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Configurar VPN',
                    style: GoogleFonts.spaceGrotesk(
                        color: _C.textPri, fontSize: 17, fontWeight: FontWeight.w800)),
                Text('vpn_config/<tu usuario>',
                    style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // ── Formulario ───────────────────────────────────────────────
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _bannerInfo(
            icon: Icons.hub_rounded,
            color: _C.primary,
            title: 'Hub WireGuard en el VPS · alta dinámica',
            subtitle: 'Cada empresa/técnico es un peer del VPS (10.50.50.x) con su '
                'propia IP del pool. Usá "Registrar en el VPS" para asignar la IP, '
                'autocompletar la clave pública del servidor y el endpoint. '
                'Los datos se guardan en vpn_config/<tu usuario>.',
          ),
          if (_error != null) _bannerInfo(icon: Icons.error_outline_rounded, color: _C.danger, title: 'Error', subtitle: _error!),
          const SizedBox(height: 16),

          // ── Servidor ──
          _seccionTitulo('Servidor WireGuard (MikroTik)'),
          _campo(
            controller: _endpointCtrl,
            label: 'Endpoint del servidor',
            hint: '10.50.50.2:13231',
            icon: Icons.dns_rounded,
            keyboard: TextInputType.url,
            validator: _validarEndpoint,
          ),
          const SizedBox(height: 8),
          _campo(
            controller: _peerPubCtrl,
            label: 'Clave pública del servidor (Peer)',
            hint: 'Pegá la PublicKey del MikroTik',
            icon: Icons.vpn_key_rounded,
            validator: (v) => _validarClave(v, 'clave pública del servidor'),
          ),

          const SizedBox(height: 18),
          // ── Claves del cliente ──
          _seccionTitulo('Claves del dispositivo (cliente)'),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Generá el par de claves o pegá una privada existente.',
                  style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, height: 1.35),
                ),
              ),
              const SizedBox(width: 8),
              _botonChico(
                onTap: _generandoClaves ? null : _generarClaves,
                label: _generandoClaves ? 'Generando…' : 'Generar claves',
                icon: Icons.auto_fix_high_rounded,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _campo(
            controller: _privCtrl,
            label: 'Clave privada (tu dispositivo)',
            hint: 'Ej: 8Fd…= (44 caracteres)',
            icon: Icons.lock_rounded,
            obscure: !_mostrarPrivada,
            validator: (v) => _validarClave(v, 'clave privada'),
            suffix: IconButton(
              icon: Icon(_mostrarPrivada ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
              onPressed: () => setState(() => _mostrarPrivada = !_mostrarPrivada),
            ),
          ),
          const SizedBox(height: 8),
          _tarjetaPublica(),
          if (_claveNoCoincide)
            _bannerInfo(
              icon: Icons.warning_amber_rounded,
              color: _C.warning,
              title: 'La clave privada cambió respecto a la registrada en el VPS',
              subtitle: 'El servidor no te va a reconocer con esta clave. '
                  'Tocá "Registrar en el VPS" para actualizar tu peer.',
            ),
          const SizedBox(height: 10),
          // Alta automática en el VPS (hub): autocompleta servidor + IP dinámica.
          _botonVps(
            onTap: _guardando ? null : _registrarEnVps,
            loading: _guardando,
          ),

          const SizedBox(height: 18),
          // ── Red ──
          _seccionTitulo('Red del túnel'),
          _bannerInfo(
            icon: Icons.account_tree_rounded,
            color: _C.accent,
            title: _redAntenas != null
                ? 'Subred de antenas asignada: $_redAntenas'
                : 'Subred de antenas: se asigna al registrar en el VPS',
            subtitle: 'Cada empresa/técnico tiene su propia subred 10.10.x.0/24 '
                '(asignada por el VPS, no editable) para que las antenas nunca choquen.',
          ),
          const SizedBox(height: 10),
          _campo(
            controller: _addressCtrl,
            label: 'IP del dispositivo en el túnel',
            hint: '10.50.50.6/32',
            icon: Icons.network_ping_rounded,
            keyboard: TextInputType.url,
            validator: _validarAddress,
          ),
          const SizedBox(height: 8),
          _campo(
            controller: _allowedCtrl,
            label: 'AllowedIPs',
            hint: '10.10.15.0/24',
            icon: Icons.route_rounded,
            keyboard: TextInputType.text,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresá AllowedIPs' : null,
          ),
          const SizedBox(height: 8),
          _campo(
            controller: _dnsCtrl,
            label: 'DNS (opcional)',
            hint: '1.1.1.1',
            icon: Icons.dns_rounded,
            keyboard: TextInputType.url,
          ),
          const SizedBox(height: 8),
          _campo(
            controller: _keepaliveCtrl,
            label: 'PersistentKeepalive (seg)',
            hint: '25',
            icon: Icons.timer_rounded,
            keyboard: const TextInputType.numberWithOptions(decimal: false),
            validator: _validarKeepalive,
          ),

          const SizedBox(height: 18),
          // ── Vista previa (privada enmascarada) ──
          _tarjetaPreview(),

          const SizedBox(height: 18),
          // ── Acciones ──
          _botonPrincipal(
            onTap: _guardando ? null : _guardar,
            label: 'Guardar configuración',
            icon: Icons.save_rounded,
            loading: _guardando,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _borrar,
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _C.danger),
            label: Text('Borrar configuración', style: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: _C.danger.withOpacity(0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  // ══════════════════════════════════════════════════════════
  //  HELPERS UI
  // ══════════════════════════════════════════════════════════

  Widget _seccionTitulo(String titulo) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          titulo.toUpperCase(),
          style: GoogleFonts.spaceGrotesk(
            color: _C.textSec,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      );

  Widget _campo({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboard,
    String? Function(String?)? validator,
    Widget? suffix,
    bool obscure = false,
  }) {
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _C.border),
    );
    final focusOutline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _C.primary, width: 1.5),
    );
    final errorOutline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _C.danger, width: 0.8),
    );
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      validator: validator,
      style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, color: _C.textSec, size: 20) : null,
        suffixIcon: suffix,
        filled: true,
        fillColor: _C.surface,
        labelStyle: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12.5),
        hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.6), fontSize: 12),
        errorStyle: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 10.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        enabledBorder: outline,
        focusedBorder: focusOutline,
        errorBorder: errorOutline,
        focusedErrorBorder: errorOutline,
      ),
    );
  }

  Widget _botonChico({
    required VoidCallback? onTap,
    required String label,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _C.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _C.primary, size: 14),
            const SizedBox(width: 4),
            Text(label,
                style: GoogleFonts.spaceGrotesk(
                    color: _C.primary, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _bannerInfo({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.spaceGrotesk(
                        color: _C.textPri, fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonPrincipal({
    required VoidCallback? onTap,
    required String label,
    required IconData icon,
    bool loading = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_C.primary, _C.accent]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: _C.primary.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 5)),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(label,
                        style: GoogleFonts.spaceGrotesk(
                            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                ),
        ),
      ),
    );
  }
  Widget _botonVps({
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text('Registrar en el VPS (IP dinámica)',
                        style: GoogleFonts.spaceGrotesk(
                            color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Tarjeta: clave pública del cliente (para el MikroTik) ─────
  Widget _tarjetaPublica() {
    final pub = _clientPublicKey ?? '';
    final tienePrivada = _privCtrl.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.vpn_key_rounded, color: _C.primary, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Tu clave pública (agregala como Peer en el MikroTik)',
                    style: GoogleFonts.spaceGrotesk(
                        color: _C.textPri, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
              if (tienePrivada)
                TextButton(
                  onPressed: _derivarPublica,
                  child: Text('Derivar',
                      style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 10.5)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (pub.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    pub,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: _C.textPri),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, color: _C.textSec, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: pub));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Clave pública copiada')),
                    );
                  },
                ),
              ],
            )
          else
            Text('Generá tus claves para obtener tu clave pública.',
                style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
        ],
      ),
    );
  }

  // ── Tarjeta: vista previa del wg-quick (privada enmascarada) ──
  Widget _tarjetaPreview() {
    return Container(
      decoration: BoxDecoration(color: _C.dark, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _mostrarPreview = !_mostrarPreview),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Vista previa wg-quick (privada oculta)',
                        style: GoogleFonts.spaceGrotesk(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  Icon(_mostrarPreview ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: Colors.white38, size: 20),
                ],
              ),
            ),
          ),
          if (_mostrarPreview)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: SelectableText(
                _wgQuickPreview(),
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 11, color: Colors.white70, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}







