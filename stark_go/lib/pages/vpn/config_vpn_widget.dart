import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:stark_go/services/vps_service.dart';
import 'package:stark_go/services/antenas_service.dart';
import 'package:stark_go/services/wireguard_keygen.dart';
import 'package:stark_go/pages/ConfigMikroTik/config_mikro_tik_widget.dart';

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
  static String mask(String s) => s.length < 8
      ? '***'
      : '${s.substring(0, 4)}…${s.substring(s.length - 4)}';

  /// Verde de confirmación (mismo tono que el resto de la app).
  static const Color success = Color(0xFF22C55E);
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
  late final TextEditingController _dnsCtrl = TextEditingController();
  late final TextEditingController _keepaliveCtrl =
      TextEditingController(text: '25');

  /// Clave pública del servidor (real, para guardar). Nunca se muestra completa.
  late final TextEditingController _peerPubCtrl = TextEditingController();

  /// Copia enmascarada (primeros 8 + ***) que se muestra en el formulario.
  late final TextEditingController _peerPubDisplayCtrl =
      TextEditingController();
  late final TextEditingController _privCtrl = TextEditingController();
  late final TextEditingController _addressCtrl = TextEditingController();
  late final TextEditingController _allowedCtrl =
      TextEditingController(text: '10.50.50.0/24, 10.10.15.0/24');

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

  // ══════════════════════════════════════════════════════════════
  //  LADO MIKROTIK DEL TÚNEL  (colección `config_mikrotik/{uid}`)
  //
  //  Todo lo que tiene que ver con el túnel vive ACÁ: la IP del
  //  MikroTik en el túnel, su Public Key (peer estático), tu red
  //  local y el modo netmap. En "Config. MikroTik" queda solo la
  //  configuración del router (datos, scheduler, portal y mora).
  // ══════════════════════════════════════════════════════════════
  static const String _colMikrotik = 'config_mikrotik';

  late final TextEditingController _subredLocalCtrl =
      TextEditingController();
  late final TextEditingController _ipLocalCtrl = TextEditingController();
  late final TextEditingController _mikrotikPubKeyCtrl =
      TextEditingController();

  /// IP del MikroTik dentro del túnel (10.50.50.x).
  String _mikrotikTunelIp = '';
  bool _generandoIpTunel = false;

  /// Subred de gestión/antenas activa en el túnel (10.10.x.0/24 o la declarada).
  String _subredAsignada = '';

  /// Modo **netmap**: el MikroTik traduce la subred del túnel ⇄ tu red local.
  bool _usarNetmap = false;

  /// IP (real o virtual) del router y API Key del VPS — solo lectura acá.
  String _mikrotikIp = '';
  String _vpsApiKey = '';

  /// true cuando ya se leyó `config_mikrotik/{uid}`: a partir de ahí los
  /// controladores reflejan lo guardado y es seguro volver a escribir.
  bool _configCargada = false;

  /// Escucha el login para recargar los datos del usuario autenticado si la
  /// pantalla se abrió antes de que Firebase restaurara la sesión.
  StreamSubscription<User?>? _authSub;

  /// Peer del MikroTik en el VPS.
  bool _mikrotikRegistrado = false;
  bool _registrandoMikrotik = false;
  String? _errorRegistro;
  bool _guardandoRedLocal = false;

  /// Prueba de la regla netmap.
  bool _probandoNetmap = false;
  String? _testNetmap;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Enmascara una clave: muestra los primeros 8 caracteres y el resto como ***.
  String _enmascarar(String clave) {
    final c = clave.trim();
    if (c.isEmpty) return '';
    if (c.length <= 8) return '***';
    return '${c.substring(0, 8)}***';
  }

  /// Actualiza la clave real y su copia enmascarada para el formulario.
  void _setPeerPub(String valor) {
    _peerPubCtrl.text = valor.trim();
    _peerPubDisplayCtrl.text = _enmascarar(valor);
  }

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  /// Carga TODO lo del usuario autenticado antes de mostrar el formulario:
  /// el túnel (`vpn_config/{uid}`) y el lado MikroTik
  /// (`config_mikrotik/{uid}`: subred local, puerta de enlace, peer y netmap).
  ///
  /// Si la sesión todavía no está restaurada, se suscribe al login y recarga:
  /// así los datos del uid vuelven siempre al entrar/salir de la cuenta.
  Future<void> _inicializar() async {
    await Future.wait([_cargar(), _cargarMikrotik()]);
    if (mounted) setState(() => _cargando = false);
    if (_uid == null) {
      _authSub?.cancel();
      _authSub = FirebaseAuth.instance.authStateChanges().listen((u) async {
        if (u == null || !mounted) return;
        await Future.wait([_cargar(), _cargarMikrotik()]);
        if (mounted) setState(() => _cargando = false);
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _endpointCtrl.dispose();
    _peerPubCtrl.dispose();
    _peerPubDisplayCtrl.dispose();
    _privCtrl.dispose();
    _addressCtrl.dispose();
    _allowedCtrl.dispose();
    _dnsCtrl.dispose();
    _keepaliveCtrl.dispose();
    _subredLocalCtrl.dispose();
    _ipLocalCtrl.dispose();
    _mikrotikPubKeyCtrl.dispose();
    super.dispose();
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

  // ══════════════════════════════════════════════════════════════
  //  MIKROTIK (lado del túnel) — lectura y guardado
  // ══════════════════════════════════════════════════════════════

  /// Lee `config_mikrotik/{uid}` (IP del túnel, peer, red local, netmap)
  /// y la subred REAL del túnel desde `vpn_config/{uid}.redAntenas`.
  Future<void> _cargarMikrotik() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_colMikrotik)
          .doc(uid)
          .get();
      if (doc.exists) {
        final d = doc.data()!;
        _mikrotikTunelIp = (d['mikrotikTunelIp'] ?? '').toString().trim();
        _mikrotikIp = (d['mikrotikIp'] ?? '').toString().trim();
        _subredLocalCtrl.text = (d['subredLocal'] ?? '').toString();
        _ipLocalCtrl.text = (d['ipLocal'] ?? '').toString();
        _usarNetmap = (d['usarNetmap'] ?? false) == true;
        _subredAsignada = _subredLocalCtrl.text.trim();
        _vpsApiKey = (d['vpsApiKey'] ?? '').toString().trim();
        final pub = (d['mikrotikPublicKey'] ?? '').toString().trim();
        _mikrotikPubKeyCtrl.text = pub;
        _mikrotikRegistrado = pub.isNotEmpty && d['mikrotikRegistradoEn'] != null;
      }
      // La subred del TÚNEL manda: con netmap es distinta de tu red local.
      final vpn = await FirebaseFirestore.instance
          .collection('vpn_config')
          .doc(uid)
          .get();
      final redTunel = (vpn.data()?['redAntenas'] ?? '').toString().trim();
      if (redTunel.isNotEmpty) _subredAsignada = redTunel;
      // Ya leímos la config del usuario: es seguro volver a escribirla.
      _configCargada = true;
    } catch (e) {
      debugPrint('[ConfigVpn] Error leyendo config_mikrotik: $e');
    }
    if (mounted) setState(() {});
  }

  /// Persiste el lado MikroTik del túnel en `config_mikrotik/{uid}` — siempre
  /// con el uid del usuario autenticado, así la configuración es de cada
  /// cuenta y sigue ahí al cerrar/abrir sesión.
  ///
  /// Guarda: **subred local**, **IP local / puerta de enlace**, el switch
  /// netmap y la IP del túnel. Usa `merge` para no pisar el resto de la
  /// config del router (datos, API Key, scheduler, portal).
  ///
  /// Devuelve `false` si no hay usuario o si todavía no se leyó la config
  /// (no se escribe a ciegas para no borrar lo ya guardado).
  Future<bool> _persistirMikrotik() async {
    final uid = _uid;
    if (uid == null || !_configCargada) return false;
    await FirebaseFirestore.instance
        .collection(_colMikrotik)
        .doc(uid)
        .set({
      'propietarioUid': uid,
      'subredLocal': _subredLocalCtrl.text.trim(),
      'ipLocal': _ipLocalCtrl.text.trim(),
      'usarNetmap': _usarNetmap,
      if (_mikrotikTunelIp.trim().isNotEmpty)
        'mikrotikTunelIp': _mikrotikTunelIp.trim(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return true;
  }

  /// Guarda tu red local + la puerta de enlace + el switch netmap.
  Future<void> _guardarRedLocal() async {
    final subred = _subredLocalCtrl.text.trim();
    final ipLocal = _ipLocalCtrl.text.trim();
    if (subred.isNotEmpty && !AntenasService.cidrValido(subred)) {
      _snack('Formato esperado: 192.168.10.0/24', _C.danger);
      return;
    }
    if (_usarNetmap && !AntenasService.cidrValido(subred)) {
      _snack(
          'En modo NAT (netmap) necesito tu subred local real (ej. 192.168.1.0/24)',
          _C.danger);
      return;
    }
    if (ipLocal.isNotEmpty && !_esIpv4(ipLocal)) {
      _snack('IP local inválida (ej. 192.168.1.1)', _C.danger);
      return;
    }
    if (_uid == null) {
      _snack('Iniciá sesión para guardar tu configuración', _C.warning);
      return;
    }
    setState(() => _guardandoRedLocal = true);
    try {
      final ok = await _persistirMikrotik();
      if (!mounted) return;
      _snack(
        ok
            ? 'Red local y puerta de enlace guardadas ✓'
            : 'Esperá un segundo (cargando tu config) y volvé a tocar Guardar',
        ok ? _C.success : _C.warning,
      );
    } catch (e) {
      if (mounted) _snack('No se pudo guardar: $e', _C.danger);
    } finally {
      if (mounted) setState(() => _guardandoRedLocal = false);
    }
  }

  // ── Generar la IP del túnel del MikroTik (10.50.50.x) ──
  Future<void> _generarIpTunel() async {
    final uid = _uid;
    if (uid == null) return;
    setState(() => _generandoIpTunel = true);
    try {
      final ip = await VpsService.generarIpTunelMikrotik();
      if (ip == null) {
        _snack('No hay IPs libres del túnel (2-250)', _C.danger);
        return;
      }
      setState(() => _mikrotikTunelIp = ip);
      await FirebaseFirestore.instance
          .collection(_colMikrotik)
          .doc(uid)
          .set({'mikrotikTunelIp': ip}, SetOptions(merge: true));
      _snack('IP del túnel del MikroTik: $ip', _C.primary);
    } catch (e) {
      _snack('Error: $e', _C.danger);
    } finally {
      if (mounted) setState(() => _generandoIpTunel = false);
    }
  }

  // ── Registrar el PEER del MikroTik en el VPS ──
  // Da de alta el MikroTik como peer estático (IP del túnel + subred de
  // antenas) y persiste lo que el VPS confirma.
  Future<void> _registrarMikrotik() async {
    final pk = _mikrotikPubKeyCtrl.text.trim();
    if (pk.isEmpty) {
      _snack('Pegá primero la Public Key de tu wg1', _C.warning);
      return;
    }
    if (!RegExp(r'^[A-Za-z0-9+/]{43}=$').hasMatch(pk)) {
      _snack('La Public Key no es válida (debe tener 44 caracteres)', _C.danger);
      return;
    }
    if (_mikrotikTunelIp.isEmpty) {
      _snack('Primero generá la IP del túnel del MikroTik (10.50.50.x)',
          _C.danger);
      return;
    }
    final subred = _subredLocalCtrl.text.trim();
    if (subred.isNotEmpty && !AntenasService.cidrValido(subred)) {
      _snack('Formato esperado: 192.168.10.0/24', _C.danger);
      return;
    }
    if (_usarNetmap && !AntenasService.cidrValido(subred)) {
      _snack(
          'En modo NAT (netmap) necesito tu subred local real (ej. 192.168.1.0/24)',
          _C.danger);
      return;
    }
    if (_vpsApiKey.isEmpty) {
      _snack(
          'Falta la API Key del VPS: abrí Config. MikroTik → "Tu clave de acceso" '
          '(se genera sola) y tocá Guardar',
          _C.warning);
      return;
    }
    setState(() {
      _registrandoMikrotik = true;
      _errorRegistro = null;
    });
    // En modo netmap la red local NO se declara (puede repetirse entre
    // empresas): el túnel usa la subred que asigna el VPS (10.10.X.0/24).
    final res = await VpsService.registrarMikrotikVps(
      publicKey: pk,
      subred: _usarNetmap ? '' : subred,
      ipLocal: _ipLocalCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _registrandoMikrotik = false;
      if (res.ok) {
        _mikrotikRegistrado = true;
        final red = res.redAntenas;
        if (red != null && red.isNotEmpty) {
          _subredAsignada = red;
          if (_usarNetmap) {
            // El panel del router se abre por su IP virtual del túnel.
            final base = _ipLocalCtrl.text.trim().isNotEmpty
                ? _ipLocalCtrl.text.trim()
                : _mikrotikIp;
            final virtual = AntenasService.ipVirtual(base, red);
            if (virtual != base) _mikrotikIp = virtual;
          } else {
            _subredLocalCtrl.text = red;
          }
        }
        final ipOk = res.ip;
        if (ipOk != null && ipOk.isNotEmpty) _mikrotikTunelIp = ipOk;
      } else {
        _errorRegistro = res.error;
      }
    });
    if (!res.ok) {
      _snack(res.error ?? 'No se pudo registrar en el VPS.', _C.danger);
      return;
    }
    // Persistimos lo que el VPS confirmó (lo usa el generador de IPs de antena).
    final uid = _uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection(_colMikrotik).doc(uid).set({
        'propietarioUid': uid,
        'mikrotikTunelIp': _mikrotikTunelIp.isEmpty ? null : _mikrotikTunelIp,
        'mikrotikIp': _mikrotikIp.isEmpty ? null : _mikrotikIp,
        'subredLocal': _subredLocalCtrl.text.trim().isEmpty
            ? null
            : _subredLocalCtrl.text.trim(),
        'ipLocal':
            _ipLocalCtrl.text.trim().isEmpty ? null : _ipLocalCtrl.text.trim(),
        'usarNetmap': _usarNetmap,
      }, SetOptions(merge: true));
    }
    if (!mounted) return;
    if (res.ipReasignada) {
      _snack(
        '⚠️ Esa IP del túnel ya la tenía otro equipo. El VPS te asignó '
        '$_mikrotikTunelIp — actualizala en tu MikroTik (wg1).',
        _C.warning,
      );
    } else {
      _snack(
        '✅ Peer del MikroTik registrado · '
        '${_mikrotikTunelIp.isEmpty ? '' : '$_mikrotikTunelIp · '}'
        'subred ${_subredAsignada.isEmpty ? 'asignada por el VPS' : _subredAsignada}',
        _C.success,
      );
    }
  }

  /// Prueba real: HTTP/HTTPS a la IP virtual del router por el túnel.
  Future<void> _probarNetmap() async {
    final redTunel = _subredAsignada.trim();
    final base = _ipLocalCtrl.text.trim().isNotEmpty
        ? _ipLocalCtrl.text.trim()
        : _mikrotikIp;
    if (!_tunelAsignado) {
      setState(() => _testNetmap =
          '❌ Todavía no tengo la subred del túnel: registrá el peer del '
          'MikroTik en el VPS y volvé a probar.');
      return;
    }
    if (!_esIpv4(base)) {
      setState(() => _testNetmap = '❌ Poné tu IP local o la IP del MikroTik '
          '(ej. 192.168.1.1) para saber qué probar.');
      return;
    }
    final virtual = AntenasService.ipVirtual(base, redTunel);
    setState(() {
      _probandoNetmap = true;
      _testNetmap = null;
    });
    final r = await AntenasService.probarIp(virtual);
    if (!mounted) return;
    setState(() {
      _probandoNetmap = false;
      _testNetmap = r.ok
          ? '✅ El router respondió en $virtual (${r.detalle}). '
              'La regla netmap está funcionando.'
          : '❌ No hubo respuesta en $virtual.\n'
              '• ¿Pegaste la regla netmap en el MikroTik? (paso 3)\n'
              '• ¿El túnel está conectado? (andá a VPN · Antenas y activalo)\n'
              '• Confirmá que la subred del túnel es $redTunel.';
    });
  }

  /// true si ya tenemos la subred del TÚNEL (la que asigna el VPS), que es
  /// distinta de tu red local cuando el modo netmap está activo.
  bool get _tunelAsignado {
    if (!AntenasService.cidrValido(_subredAsignada)) return false;
    if (!_usarNetmap) return true;
    return _subredAsignada.trim() != _subredLocalCtrl.text.trim();
  }

  /// true si `s` es una IPv4 válida (a.b.c.d, 0-255 cada octeto).
  static bool _esIpv4(String s) {
    final p = s.trim().split('.');
    if (p.length != 4) return false;
    for (final o in p) {
      final n = int.tryParse(o);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }


  // ── Cargar config existente / sugerir IP libre ─────────────────
  Future<void> _cargar() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vpn_config')
          .doc(uid)
          .get();
      if (doc.exists && mounted) {
        final d = doc.data() as Map<String, dynamic>;
        _endpointCtrl.text = (d['endpoint'] ?? '').toString();
        _setPeerPub((d['peerPublicKey'] ?? '').toString());
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
      if (mounted)
        _error = 'No se pudo leer la configuración: ${e.runtimeType}';
    }
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
  Future<bool> _registrarEnVps() async {
    var publica = _clientPublicKey;
    if ((publica ?? '').isEmpty) {
      publica = await WireGuardKeygen.derivarPublica(_privCtrl.text);
    }
    if (publica == null || publica.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero generá o pegá tu clave privada')),
      );
      return false;
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
        return false;
      }
      // Autocompletar datos del servidor si faltan.
      if (info.serverPublicKey.isNotEmpty) _setPeerPub(info.serverPublicKey);
      if (info.endpoint.isNotEmpty) _endpointCtrl.text = info.endpoint;

      final registro = await VpsService.registrarPeerVps(
        publicKey: publica,
        nombre: FirebaseAuth.instance.currentUser?.displayName ?? 'Técnico',
      );
      if (registro == null || registro.ip.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('El VPS no pudo asignar una IP. '
                  'Revisá que /wg/register esté activo.')),
        );
        return false;
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
          content:
              Text('✅ Peer registrado en el VPS · IP asignada: ${registro.ip}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error registrando en el VPS: ${e.runtimeType}')),
        );
      }
      return false;
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
        const SnackBar(
            content: Text('Inicia sesión para guardar la configuración')),
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

      // Alta automática en el VPS: si aún no hay IP asignada o la clave cambió,
      // el servidor elige una IP libre del pool (10.50.50.x) y la guardamos.
      final necesitaRegistro = _addressCtrl.text.trim().isEmpty ||
          _claveNoCoincide ||
          (publica ?? '').isEmpty;
      if (necesitaRegistro) {
        final ok = await _registrarEnVps();
        if (!ok || !mounted) return;
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

      // Guardamos TAMBIÉN el lado MikroTik con el uid del usuario: la red
      // local y la PUERTA DE ENLACE (IP local) quedan en
      // `config_mikrotik/{uid}`, así no hay que volver a escribirlas al
      // entrar/salir de la cuenta (antes sólo las guardaba el botón
      // "Guardar red local" y este botón las perdía).
      final mikrotikOk = await _persistirMikrotik();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mikrotikOk
              ? 'Configuración guardada ✓'
              : 'Túnel guardado, pero no pude guardar tu red local: esperá la '
                  'carga de la pantalla y tocá Guardar otra vez'),
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
        content: const Text(
            'Se eliminará vpn_config. Tendrás que volver a configurar el túnel.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar', style: TextStyle(color: _C.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await FirebaseFirestore.instance
          .collection('vpn_config')
          .doc(uid)
          .delete();
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
      ..writeln(
          'PrivateKey = ${_privCtrl.text.isEmpty ? '…' : _C.mask(_privCtrl.text)}')
      ..writeln(
          'Address = ${_addressCtrl.text.isEmpty ? '…' : _addressCtrl.text}');
    if (_dnsCtrl.text.trim().isNotEmpty) {
      buf.writeln('DNS = ${_dnsCtrl.text.trim()}');
    }
    buf
      ..writeln()
      ..writeln('[Peer]')
      ..writeln(
          'PublicKey = ${_peerPubCtrl.text.isEmpty ? '…' : _C.mask(_peerPubCtrl.text)}')
      ..writeln(
          'AllowedIPs = ${_allowedCtrl.text.isEmpty ? '…' : _allowedCtrl.text}')
      ..writeln(
          'Endpoint = ${_endpointCtrl.text.isEmpty ? '…' : _endpointCtrl.text}')
      ..writeln(
          'PersistentKeepalive = ${_keepaliveCtrl.text.isEmpty ? '…' : _keepaliveCtrl.text}');
    return buf.toString();
  }

  // ── Validadores ───────────────────────────────────────────────
  String? _validarClave(String? v, String campo) {
    final valor = (v ?? '').trim();
    if (valor.isEmpty) return 'Ingresá la $campo';
    if (!WireGuardKeygen.esClaveValida(valor)) {
      return 'Clave inválida (base64 de 32 bytes)';
    }
    return null;
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
                  ? const Center(
                      child: CircularProgressIndicator(color: _C.primary))
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
            child:
                const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Configurar VPN',
                    style: GoogleFonts.spaceGrotesk(
                        color: _C.textPri,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                Text('vpn_config/<tu usuario>',
                    style: GoogleFonts.spaceGrotesk(
                        color: _C.textSec, fontSize: 11)),
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
            subtitle:
                'Cada empresa/técnico es un peer del VPS (10.50.50.x) con su '
                'propia IP del pool. Al tocar Guardar se registra solo en el VPS (asigna una IP libre, '
                'autocompleta la clave pública del servidor y el endpoint). '
                'Los datos se guardan en vpn_config/<tu usuario>.',
          ),
          if (_error != null)
            _bannerInfo(
                icon: Icons.error_outline_rounded,
                color: _C.danger,
                title: 'Error',
                subtitle: _error!),
          const SizedBox(height: 16),

          // ── Servidor ──
          _seccionTitulo('Servidor WireGuard (VPS)'),
          _bannerInfo(
            icon: Icons.lock_rounded,
            color: _C.textSec,
            title: 'Datos del servidor bloqueados',
            subtitle:
                'Endpoint y clave pública del servidor los asigna el VPS. '
                'Solo se ven, no se pueden editar ni copiar.',
          ),
          const SizedBox(height: 10),
          _campo(
            controller: _endpointCtrl,
            label: 'Endpoint del servidor',
            hint: '5.161.88.42:1234',
            icon: Icons.dns_rounded,
            readOnly: true,
          ),
          const SizedBox(height: 8),
          _campo(
            controller: _peerPubDisplayCtrl,
            label: 'Clave pública del servidor',
            icon: Icons.vpn_key_rounded,
            readOnly: true,
          ),

          const SizedBox(height: 18),
          // ── Claves del cliente ──
          _seccionTitulo('Claves del dispositivo (cliente)'),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Generá el par de claves o pegá una privada existente.',
                  style: GoogleFonts.spaceGrotesk(
                      color: _C.textSec, fontSize: 11, height: 1.35),
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
              icon: Icon(
                  _mostrarPrivada
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 18),
              onPressed: () =>
                  setState(() => _mostrarPrivada = !_mostrarPrivada),
            ),
          ),
          const SizedBox(height: 8),
          _tarjetaPublica(),
          if (_claveNoCoincide)
            _bannerInfo(
              icon: Icons.warning_amber_rounded,
              color: _C.warning,
              title:
                  'La clave privada cambió respecto a la registrada en el VPS',
              subtitle: 'El servidor no te va a reconocer con esta clave. '
                  'Al tocar Guardar se actualiza tu peer automáticamente.',
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
                ? 'Subred de gestión/antenas: $_redAntenas'
                : 'Subred de antenas: se asigna al registrar en el VPS',
            subtitle:
                'Si declarás tu red local acá abajo (ej. 192.168.10.0/24), '
                'se usa ESA subred: así las antenas y tu MikroTik coinciden con tu red '
                'real. Si no, el VPS te asigna una 10.10.x.0/24 libre — nunca choca con '
                'otra empresa.',
          ),
          const SizedBox(height: 10),
          _campo(
            controller: _addressCtrl,
            label: 'IP del dispositivo en el túnel',
            hint: '10.50.50.6/32',
            icon: Icons.network_ping_rounded,
            readOnly: true,
          ),
          const SizedBox(height: 8),
          _campo(
            controller: _allowedCtrl,
            label: 'AllowedIPs (redes del túnel)',
            hint: '10.50.50.0/24, 10.10.15.0/24',
            icon: Icons.route_rounded,
            readOnly: true,
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
          // ── MikroTik (lado del túnel): IP, peer, red local y netmap ──
          _buildMikrotikTunelSection(),

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
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: _C.danger),
            label: Text('Borrar configuración',
                style:
                    GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: _C.danger.withOpacity(0.4)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
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
    bool readOnly = false,
    bool enabled = true,
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
      readOnly: readOnly,
      enabled: enabled,
      style: GoogleFonts.spaceGrotesk(
              color: readOnly ? _C.textSec : _C.textPri, fontSize: 13.5)
          .copyWith(fontFamily: readOnly ? 'monospace' : null),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon:
            icon != null ? Icon(icon, color: _C.textSec, size: 20) : null,
        suffixIcon: readOnly
            ? const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.lock_rounded, color: _C.border, size: 18),
              )
            : suffix,
        filled: true,
        fillColor: readOnly ? _C.surfaceDim.withOpacity(0.55) : _C.surface,
        labelStyle: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12.5),
        hintStyle: GoogleFonts.spaceGrotesk(
            color: _C.textSec.withOpacity(0.6), fontSize: 12),
        errorStyle: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 10.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
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
                    color: _C.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
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
                        color: _C.textPri,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: GoogleFonts.spaceGrotesk(
                        color: _C.textSec, fontSize: 11, height: 1.4)),
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
            BoxShadow(
                color: _C.primary.withOpacity(0.3),
                blurRadius: 14,
                offset: const Offset(0, 5)),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(label,
                        style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
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
          gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_upload_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text('Registrar en el VPS (IP dinámica)',
                        style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700)),
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
                child: Text(
                    'Tu clave pública (agregala como Peer en el MikroTik)',
                    style: GoogleFonts.spaceGrotesk(
                        color: _C.textPri,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700)),
              ),
              if (tienePrivada)
                TextButton(
                  onPressed: _derivarPublica,
                  child: Text('Derivar',
                      style: GoogleFonts.spaceGrotesk(
                          color: _C.primary, fontSize: 10.5)),
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
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: _C.textPri),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded,
                      color: _C.textSec, size: 16),
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
                style:
                    GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  UI — MIKROTIK (LADO DEL TÚNEL)
  //  Acá vive TODO lo del túnel: la IP del MikroTik, su peer en el
  //  VPS, tu red local y el modo netmap.
  // ══════════════════════════════════════════════════════════════

  Widget _buildMikrotikTunelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _seccionTitulo('MikroTik (lado del túnel)'),
        _bannerInfo(
          icon: Icons.router_rounded,
          color: _C.accent,
          title: 'Todo lo del túnel está acá',
          subtitle:
              'La IP del MikroTik dentro del túnel (10.50.50.x), su Public Key '
              'como peer del VPS, tu red local y el modo netmap. En '
              '"Config. MikroTik" queda la configuración del router: datos, '
              'scheduler, portal de morosos y reglas.',
        ),
        const SizedBox(height: 10),
        // La API Key del VPS vive en Config. MikroTik (la usa el router para
        // las colas/scheduler). Acá solo se muestra y se puede ir a editarla.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _vpsApiKey.isEmpty
                ? _C.warning.withOpacity(0.08)
                : _C.surfaceDim,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _vpsApiKey.isEmpty
                    ? _C.warning.withOpacity(0.35)
                    : _C.border),
          ),
          child: Row(
            children: [
              Icon(
                  _vpsApiKey.isEmpty
                      ? Icons.warning_amber_rounded
                      : Icons.key_rounded,
                  color: _vpsApiKey.isEmpty ? _C.warning : _C.textSec,
                  size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _vpsApiKey.isEmpty
                            ? 'Falta la API Key del VPS'
                            : 'API Key del VPS',
                        style: GoogleFonts.spaceGrotesk(
                            color: _C.textPri,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                        _vpsApiKey.isEmpty
                            ? 'Abrí Config. MikroTik → "Tu clave de acceso" (se genera '
                                'sola) y tocá Guardar para poder registrar peers.'
                            : '${_C.mask(_vpsApiKey)} · se edita en Config. MikroTik',
                        style: GoogleFonts.spaceGrotesk(
                            color: _C.textSec, fontSize: 10.5, height: 1.35)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ConfigMikroTikWidget()),
                ),
                child: Text('Abrir',
                    style: GoogleFonts.spaceGrotesk(
                        color: _C.primary, fontSize: 10.5)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildRedLocalCard(),
        const SizedBox(height: 12),
        _buildIpTunelCard(),
        const SizedBox(height: 12),
        _buildMikrotikPeerCard(),
      ],
    );
  }

  // ── Tarjeta: tu red local + switch netmap ──
  Widget _buildRedLocalCard() {
    final activo = _subredAsignada.isNotEmpty &&
        _subredAsignada != _subredLocalCtrl.text.trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.warning.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('TU RED LOCAL (donde están tus antenas)',
              style: GoogleFonts.spaceGrotesk(
                  color: _C.textSec,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3)),
          const SizedBox(height: 10),
          _campo(
            controller: _subredLocalCtrl,
            label: 'MI SUBRED LOCAL (CIDR)',
            hint: '192.168.10.0/24',
            icon: Icons.account_tree_rounded,
            keyboard: TextInputType.url,
          ),
          const SizedBox(height: 8),
          _campo(
            controller: _ipLocalCtrl,
            label: 'MI IP LOCAL / PUERTA DE ENLACE',
            hint: '192.168.10.1',
            icon: Icons.home_rounded,
            keyboard: TextInputType.url,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _C.warning.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.warning.withOpacity(0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.swap_horiz_rounded,
                  color: _C.warning, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Uso NAT (netmap) para las antenas',
                          style: GoogleFonts.spaceGrotesk(
                              color: _C.textPri,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                          'Mantené tu red 192.168.x.x aunque otra empresa use la '
                          'misma: el túnel usa la subred del VPS y la app abre '
                          'cada antena por su IP virtual.',
                          style: GoogleFonts.spaceGrotesk(
                              color: _C.textSec, fontSize: 10, height: 1.35)),
                    ]),
              ),
              Switch(
                value: _usarNetmap,
                activeColor: _C.warning,
                onChanged: (v) {
                  setState(() => _usarNetmap = v);
                  _guardarRedLocal();
                },
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Text(
            _usarNetmap
                ? 'Modo NAT: declaré tu red local REAL (ej. 192.168.1.0/24). No '
                    'se declara al VPS, así que puede repetirse en varias '
                    'empresas. La app abre cada antena por la IP virtual del '
                    'túnel (misma última octeta) y tu MikroTik la traduce con '
                    'una regla netmap.'
                : 'Vacío = el VPS te asigna una 10.10.X.0/24 libre. Si declarás '
                    'tu red real (por ej. 192.168.10.0/24), el túnel expone ESA '
                    'subred: tus antenas y la IP del MikroTik coinciden con tu '
                    'red, sin re-IP-ear nada. El VPS valida que ninguna otra '
                    'empresa use la misma subred.',
            style: GoogleFonts.spaceGrotesk(
                color: _C.textSec, fontSize: 10.5, height: 1.45),
          ),
          if (activo)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded,
                    color: _C.success, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Subred activa en el túnel: $_subredAsignada',
                      style: GoogleFonts.spaceGrotesk(
                          color: _C.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: OutlinedButton.icon(
              onPressed: _guardandoRedLocal ? null : _guardarRedLocal,
              icon: _guardandoRedLocal
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_rounded, size: 16),
              label: Text(_guardandoRedLocal ? 'Guardando…' : 'Guardar red local',
                  style: GoogleFonts.spaceGrotesk(
                      color: _C.warning,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _C.warning.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_usarNetmap) ...[
            const SizedBox(height: 12),
            _buildNetmapCard(),
          ],
        ],
      ),
    );
  }

  // ── Tarjeta: IP del túnel del MikroTik (10.50.50.x) ──
  Widget _buildIpTunelCard() {
    final ip = _mikrotikTunelIp.trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('IP DEL TÚNEL DEL MIKROTIK (10.50.50.x)',
              style: GoogleFonts.spaceGrotesk(
                  color: _C.textSec,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Text(
                ip.isEmpty ? 'Pendiente — tocá "Generar"' : ip,
                style: GoogleFonts.spaceGrotesk(
                        color: ip.isEmpty ? _C.textSec : _C.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)
                    .copyWith(fontFamily: 'monospace'),
              ),
            ),
            if (ip.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: _C.primary),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: ip));
                  _snack('IP copiada: $ip', _C.success);
                },
              ),
          ]),
          const SizedBox(height: 4),
          Text(
            'Es única con DOBLE control: la app busca la primera libre entre los '
            'teléfonos y otros MikroTik, y el VPS la vuelve a verificar al '
            'registrar (si ya la tenía otro equipo, te asigna otra). '
            'Va en el MikroTik: IP → Addresses → (+) → Address: '
            '${ip.isEmpty ? '10.50.50.X' : ip}/24 · Interface: wg1.',
            style: GoogleFonts.spaceGrotesk(
                color: _C.textSec, fontSize: 10.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: OutlinedButton.icon(
              onPressed: _generandoIpTunel ? null : _generarIpTunel,
              icon: _generandoIpTunel
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_fix_high_rounded, size: 16),
              label: Text(
                  _generandoIpTunel ? 'Generando…' : 'Generar IP del túnel',
                  style: GoogleFonts.spaceGrotesk(
                      color: _C.primary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _C.primary.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tarjeta: regla netmap (traduce el túnel ⇄ tu red local) ──
  Widget _buildNetmapCard() {
    final redLocal = _subredLocalCtrl.text.trim();
    // El comando necesita la subred del TÚNEL (10.10.X.0/24), que la asigna el
    // VPS al registrar el peer. Si todavía no está, pedimos registrarlo.
    final cmd = _tunelAsignado
        ? AntenasService.comandoNetmap(
            redTunel: _subredAsignada,
            redLocal: redLocal,
          )
        : '';
    if (cmd.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _C.warning.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _C.warning.withOpacity(0.3)),
        ),
        child: Text(
          '⚠️ ACÁ VA A APARECER TU COMANDO — falta un paso.\n\n'
          '1) Generá la IP del túnel del MikroTik (tarjeta de abajo).\n'
          '2) Pegá la Public Key de tu wg1 y registrá el peer en el VPS.\n'
          '3) Volvé acá: el comando aparece solo, con tus datos.\n\n'
          '💡 Es normal: el comando necesita la subred que el VPS te asigna al '
          'registrar (10.10.X.0/24).',
          style: GoogleFonts.spaceGrotesk(
              color: _C.textPri, fontSize: 10.5, height: 1.45),
        ),
      );
    }
    final l = redLocal.split('/').first.trim().split('.');
    final t = _subredAsignada.split('/').first.trim().split('.');
    final ejemplo = (l.length == 4 && t.length == 4)
        ? '${l[0]}.${l[1]}.${l[2]}.20 ⇄ ${t[0]}.${t[1]}.${t[2]}.20'
        : '';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('PEGÁ ESTO EN TU MIKROTIK (una sola vez)',
          style: GoogleFonts.spaceGrotesk(
              color: _C.textSec,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
        decoration: BoxDecoration(
            color: _C.dark, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Expanded(
            child: SelectableText(
              cmd,
              style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFF7DD3FC),
                      fontSize: 10.5,
                      height: 1.45)
                  .copyWith(fontFamily: 'monospace'),
            ),
          ),
          IconButton(
            tooltip: 'Copiar comando',
            icon: const Icon(Icons.copy_rounded,
                color: Colors.white70, size: 16),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: cmd));
              _snack('Comando netmap copiado', _C.success);
            },
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _C.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _C.primary.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PASO A PASO (en este orden)',
              style: GoogleFonts.spaceGrotesk(
                  color: _C.primary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3)),
          const SizedBox(height: 6),
          _pasoNetmap('1',
              'Registrá el peer del MikroTik en el VPS y esperá el chip verde.'),
          _pasoNetmap('2',
              'Copiá el comando de acá arriba con el botón de copiar.'),
          _pasoNetmap(
              '3', 'En Winbox: Terminal → pegá el comando → Enter (una sola vez).'),
          _pasoNetmap('4',
              'Tocá "Probar" acá abajo: si dice ✅, ya podés abrir tus antenas.'),
        ]),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        height: 42,
        child: OutlinedButton.icon(
          onPressed: _probandoNetmap ? null : _probarNetmap,
          icon: _probandoNetmap
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.network_check_rounded, size: 16),
          label: Text(_probandoNetmap ? 'Probando…' : 'Probar la regla netmap',
              style: GoogleFonts.spaceGrotesk(
                  color: _C.primary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _C.primary.withOpacity(0.4)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      if (_testNetmap != null) ...[
        const SizedBox(height: 8),
        Text(_testNetmap!,
            style: GoogleFonts.spaceGrotesk(
                color: _testNetmap!.startsWith('✅') ? _C.success : _C.danger,
                fontSize: 11,
                height: 1.4)),
      ],
      const SizedBox(height: 6),
      Text(
        'Traduce la subred del túnel ⇄ tu red local (misma última octeta): '
        '${ejemplo.isEmpty ? '' : '$ejemplo · '}'
        'tu MikroTik sigue con su DHCP normal y vos abrís cada antena por la IP '
        'virtual.',
        style: GoogleFonts.spaceGrotesk(
            color: _C.textSec, fontSize: 10, height: 1.4),
      ),
    ]);
  }

  /// Una línea del paso a paso del netmap (número + texto).
  Widget _pasoNetmap(String n, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
              color: _C.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(5)),
          child: Center(
            child: Text(n,
                style: GoogleFonts.spaceGrotesk(
                    color: _C.primary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(texto,
              style: GoogleFonts.spaceGrotesk(
                  color: _C.textPri, fontSize: 10.5, height: 1.35)),
        ),
      ]),
    );
  }

  // ── Tarjeta: Public Key del MikroTik → peer estático en el VPS ──
  Widget _buildMikrotikPeerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.accent.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('PUBLIC KEY DE TU MIKROTIK (wg1)',
                style: GoogleFonts.spaceGrotesk(
                    color: _C.textSec,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3)),
          ),
          if (_mikrotikRegistrado)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: _C.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _C.success.withOpacity(0.4))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_rounded,
                    color: _C.success, size: 13),
                const SizedBox(width: 4),
                Text('Registrado en el VPS',
                    style: GoogleFonts.spaceGrotesk(
                        color: _C.success,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
        ]),
        const SizedBox(height: 2),
        Text('Winbox → WireGuard → doble clic en wg1 → campo Public Key',
            style: GoogleFonts.spaceGrotesk(
                color: _C.textSec, fontSize: 10.5, height: 1.35)),
        const SizedBox(height: 10),
        _campo(
          controller: _mikrotikPubKeyCtrl,
          label: 'PUBLIC KEY',
          hint: 'Pegá la Public Key aquí (ej: Xm9a…fM4=)',
          icon: Icons.key_rounded,
        ),
        if (_mikrotikTunelIp.isEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _C.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.warning.withOpacity(0.3)),
            ),
            child: Text(
                '⚠️ Primero generá la IP del túnel del MikroTik (arriba): el '
                'peer del VPS queda amarrado a esa IP.',
                style: GoogleFonts.spaceGrotesk(
                    color: _C.textPri, fontSize: 10.5, height: 1.4)),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: _registrandoMikrotik ? null : _registrarMikrotik,
            icon: _registrandoMikrotik
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_upload_rounded, size: 18),
            label: Text(
                _registrandoMikrotik
                    ? 'Registrando…'
                    : (_mikrotikRegistrado
                        ? 'Registrar de nuevo'
                        : 'Registrar peer del MikroTik en el VPS'),
                style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _C.border,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (_errorRegistro != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _C.danger.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.danger.withOpacity(0.35)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.error_outline_rounded,
                  color: _C.danger, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_errorRegistro!,
                    style: GoogleFonts.spaceGrotesk(
                        color: _C.danger, fontSize: 10.5, height: 1.4)),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'El VPS lo agrega como peer estático con tu IP '
          '(${_mikrotikTunelIp.isEmpty ? '10.50.50.X' : _mikrotikTunelIp}/32) y '
          'tu subred de antenas.',
          style: GoogleFonts.spaceGrotesk(
              color: _C.textSec, fontSize: 10, height: 1.4),
        ),
      ]),
    );
  }

  // ── Tarjeta: vista previa del wg-quick (privada enmascarada) ──
  Widget _tarjetaPreview() {
    return Container(
      decoration: BoxDecoration(
          color: _C.dark, borderRadius: BorderRadius.circular(14)),
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
                  const Icon(Icons.description_outlined,
                      color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Vista previa wg-quick (privada oculta)',
                        style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  Icon(
                      _mostrarPreview
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: Colors.white38,
                      size: 20),
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
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.white70,
                    height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}
