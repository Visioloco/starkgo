import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class _C {
  static const Color primary = Color(0xFF1A73E8);
  static const Color accent = Color(0xFF00C6AE);
  static const Color danger = Color(0xFFE53935);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF22C55E);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF1F5F9);
  static const Color textPri = Color(0xFF0F172A);
  static const Color textSec = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color purple = Color(0xFF7C3AED);
  static const Color whatsapp = Color(0xFF25D366);
}

const String _kEvolutionBaseUrl = 'http://5.161.88.42:8080';
const String _kEvolutionApiKey = 'starkgo2024secretkey';
const String _kFirebaseCollection = 'whatsapp_instances';

// ─────────────────────────────────────────────────────────────
//  Servicio de instancias (lógica multi-usuario aislada)
// ─────────────────────────────────────────────────────────────
class _EvolutionService {
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'apikey': _kEvolutionApiKey,
      };

  /// Genera un nombre de instancia único y estable por usuario.
  static String instanceName(String uid) => 'user_${uid.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').substring(0, 12).toLowerCase()}';

  /// Devuelve el estado actual de la instancia en el servidor.
  /// Retorna: 'open' | 'close' | 'connecting' | 'not_found'
  static Future<String> fetchState(String instName) async {
    try {
      final resp = await http
          .get(
            Uri.parse('$_kEvolutionBaseUrl/instance/connectionState/$instName'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 404) return 'not_found';
      if (resp.statusCode != 200) return 'close';

      final data = jsonDecode(resp.body);
      final state = (data['instance']?['state'] ?? data['state'] ?? '').toString();
      return state.isEmpty ? 'close' : state;
    } catch (_) {
      return 'close';
    }
  }

  /// Crea la instancia en el servidor si no existe.
  /// Si ya existe pero está cerrada, simplemente la reutiliza.
  static Future<void> ensureInstanceExists(String instName) async {
    final state = await fetchState(instName);
    if (state != 'not_found') return; // ya existe, no recrear

    final resp = await http
        .post(
          Uri.parse('$_kEvolutionBaseUrl/instance/create'),
          headers: _headers,
          body: jsonEncode({
            'instanceName': instName,
            'qrcode': true,
            'integration': 'WHATSAPP-BAILEYS',
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Error creando instancia (${resp.statusCode}): ${resp.body}');
    }
  }

  /// Obtiene el QR en base64 (sin prefijo data-uri).
  static Future<String> fetchQr(String instName) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) await Future.delayed(const Duration(seconds: 2));

      final resp = await http
          .get(
            Uri.parse('$_kEvolutionBaseUrl/instance/connect/$instName'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) continue;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final raw = data['base64'] ?? data['qrcode']?['base64'] ?? (data['qrcode'] is String ? data['qrcode'] : null) ?? data['code'];

      if (raw != null && raw.toString().isNotEmpty) {
        return raw.toString().replaceAll('data:image/png;base64,', '');
      }
    }
    throw Exception('QR no disponible después de 3 intentos');
  }

  /// Cierra sesión de WhatsApp y elimina la instancia del servidor.
  static Future<void> deleteInstance(String instName) async {
    // Ignorar errores: si ya no existe, no importa
    await http
        .delete(
          Uri.parse('$_kEvolutionBaseUrl/instance/logout/$instName'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 8))
        .catchError((_) => http.Response('', 200));

    await Future.delayed(const Duration(milliseconds: 500));

    await http
        .delete(
          Uri.parse('$_kEvolutionBaseUrl/instance/delete/$instName'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 8))
        .catchError((_) => http.Response('', 200));
  }
}

// ─────────────────────────────────────────────────────────────
//  Widget principal
// ─────────────────────────────────────────────────────────────
enum _PageState { idle, cargando, qrListo, qrExpirado, conectado, error }

class ConfigEvolutionApiWidget extends StatefulWidget {
  const ConfigEvolutionApiWidget({super.key});
  static String routeName = 'ConfigEvolutionApi';
  static String routePath = 'configEvolutionApi';

  @override
  State<ConfigEvolutionApiWidget> createState() => _ConfigEvolutionApiWidgetState();
}

class _ConfigEvolutionApiWidgetState extends State<ConfigEvolutionApiWidget> with SingleTickerProviderStateMixin {
  _PageState _pageState = _PageState.idle;
  String? _qrBase64;
  String? _instanceName;
  String? _errorMsg;
  bool _conectado = false;

  Map<String, dynamic>? _configExistente;
  String? _docId;

  Timer? _pollingTimer;
  Timer? _qrCountdown;
  int _qrExpiraSeg = 60;

  final _ctrlPhone = TextEditingController();

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'anonimo';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _cargarConfigExistente();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _qrCountdown?.cancel();
    _ctrlPhone.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Cargar / verificar config existente ──────────────────
  Future<void> _cargarConfigExistente() async {
    final snap = await FirebaseFirestore.instance.collection(_kFirebaseCollection).where('uid', isEqualTo: _uid).limit(1).get();

    if (snap.docs.isEmpty) return;

    final doc = snap.docs.first;
    final data = doc.data();
    final saved = (data['instanceName'] ?? '') as String;

    // Verificar estado real en el servidor (no confiar solo en Firestore)
    final realState = saved.isNotEmpty ? await _EvolutionService.fetchState(saved) : 'not_found';

    final isOpen = realState == 'open';

    setState(() {
      _configExistente = data;
      _docId = doc.id;
      _conectado = isOpen;
      _instanceName = saved;
      _pageState = isOpen ? _PageState.conectado : _PageState.idle;
    });

    // Sincronizar Firestore si el estado cambió
    if (!isOpen && (data['status'] == 'open' || data['status'] == 'connected')) {
      await FirebaseFirestore.instance
          .collection(_kFirebaseCollection)
          .doc(doc.id)
          .update({'status': realState, 'actualizadoEn': FieldValue.serverTimestamp()});
    }

    if (_ctrlPhone.text.isEmpty && data['phone'] != null) {
      _ctrlPhone.text = data['phone'];
    }
  }

  // ── Crear / reconectar instancia ─────────────────────────
  Future<void> _crearInstancia() async {
    final phone = _ctrlPhone.text.trim().replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) {
      _snack('Ingresa tu número de WhatsApp', _C.warning, Icons.warning_rounded);
      return;
    }

    setState(() {
      _pageState = _PageState.cargando;
      _errorMsg = null;
    });

    final instName = _EvolutionService.instanceName(_uid);

    try {
      // 1. Asegurar que la instancia exista en el servidor
      await _EvolutionService.ensureInstanceExists(instName);

      // 2. Si ya está abierta (otro dispositivo la conectó antes), ir directo
      final state = await _EvolutionService.fetchState(instName);
      if (state == 'open') {
        await _guardarEnFirebase(instName, phone, 'open');
        if (mounted) {
          setState(() {
            _conectado = true;
            _instanceName = instName;
            _pageState = _PageState.conectado;
          });
        }
        return;
      }

      // 3. Pedir QR
      final qr = await _EvolutionService.fetchQr(instName);

      if (mounted) {
        setState(() {
          _qrBase64 = qr;
          _instanceName = instName;
          _pageState = _PageState.qrListo;
          _qrExpiraSeg = 60;
        });
        _iniciarPolling(instName, phone);
        _iniciarCountdownQR();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pageState = _PageState.error;
          _errorMsg = e.toString();
        });
      }
    }
  }

  // ── Polling: verificar conexión ──────────────────────────
  void _iniciarPolling(String instName, String phone) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final state = await _EvolutionService.fetchState(instName);
      if (state == 'open') {
        _pollingTimer?.cancel();
        _qrCountdown?.cancel();
        await _guardarEnFirebase(instName, phone, 'open');
        if (mounted) {
          setState(() {
            _conectado = true;
            _pageState = _PageState.conectado;
          });
        }
      }
    });
  }

  // ── Countdown QR ─────────────────────────────────────────
  void _iniciarCountdownQR() {
    _qrCountdown?.cancel();
    _qrCountdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _qrExpiraSeg--);
      if (_qrExpiraSeg <= 0) {
        _qrCountdown?.cancel();
        _pollingTimer?.cancel();
        setState(() => _pageState = _PageState.qrExpirado);
      }
    });
  }

  // ── Guardar / actualizar en Firestore ────────────────────
  Future<void> _guardarEnFirebase(String instName, String phone, String status) async {
    final payload = {
      'uid': _uid,
      'instanceName': instName,
      'apiKey': _kEvolutionApiKey,
      'serverUrl': _kEvolutionBaseUrl,
      'phone': phone,
      'status': status,
      'actualizadoEn': FieldValue.serverTimestamp(),
    };

    if (_docId != null) {
      await FirebaseFirestore.instance.collection(_kFirebaseCollection).doc(_docId).update(payload);
    } else {
      payload['creadoEn'] = FieldValue.serverTimestamp();
      final doc = await FirebaseFirestore.instance.collection(_kFirebaseCollection).add(payload);
      _docId = doc.id;
    }
    _configExistente = {...?_configExistente, ...payload};
  }

  // ── Desconectar ──────────────────────────────────────────
  Future<void> _desconectar() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Desconectar WhatsApp', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
            content: Text('¿Seguro que deseas desconectar esta instancia?', style: GoogleFonts.dmSans(color: _C.textSec)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancelar', style: GoogleFonts.dmSans(color: _C.textSec)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _C.danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Desconectar', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok || _instanceName == null) return;

    try {
      setState(() => _pageState = _PageState.cargando);

      await _EvolutionService.deleteInstance(_instanceName!);

      if (_docId != null) {
        await FirebaseFirestore.instance.collection(_kFirebaseCollection).doc(_docId).update({
          'status': 'disconnected',
          'actualizadoEn': FieldValue.serverTimestamp(),
        });
      }

      setState(() {
        _conectado = false;
        _configExistente = null;
        _pageState = _PageState.idle;
        _qrBase64 = null;
        _instanceName = null;
      });
      _snack('WhatsApp desconectado', _C.warning, Icons.logout_rounded);
    } catch (e) {
      _snack('Error al desconectar: $e', _C.danger, Icons.error_rounded);
      setState(() => _pageState = _PageState.conectado);
    }
  }

  // ── Snack helper ─────────────────────────────────────────
  void _snack(String msg, Color bg, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13))),
      ]),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surfaceDim,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              child: Column(children: [
                _buildBanner(),
                const SizedBox(height: 16),
                _buildMainCard(),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTopBar() {
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('WhatsApp Business', style: GoogleFonts.dmSans(color: _C.textPri, fontSize: 17, fontWeight: FontWeight.w800)),
            Text('Evolution API · Conexión', style: GoogleFonts.dmSans(color: _C.textSec, fontSize: 11)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: (_conectado ? _C.success : _C.textSec).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _conectado ? _C.success : _C.border, width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: _conectado ? _C.success : _C.textSec, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              _conectado ? 'Conectado' : 'Desconectado',
              style: GoogleFonts.dmSans(color: _conectado ? _C.success : _C.textSec, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.whatsapp.withOpacity(0.08), _C.accent.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.whatsapp.withOpacity(0.2), width: 1.2),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: _C.whatsapp.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.info_outline_rounded, color: _C.whatsapp, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Conecta tu número de WhatsApp para enviar notificaciones '
            'automáticas a tus clientes UISP. Cada usuario tiene su '
            'propia instancia aislada.',
            style: GoogleFonts.dmSans(color: _C.textSec, fontSize: 11),
          ),
        ),
      ]),
    );
  }

  Widget _buildMainCard() {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
        border: Border.all(color: _C.border, width: 1),
      ),
      child: Column(children: [
        // Cabecera
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_C.whatsapp.withOpacity(0.10), _C.whatsapp.withOpacity(0.03)]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_C.whatsapp, Color(0xFF128C7E)]),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.chat_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Instancia WhatsApp', style: GoogleFonts.dmSans(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
                Text(
                  _instanceName ?? 'Sin instancia activa',
                  style: GoogleFonts.dmSans(color: _C.textSec, fontSize: 11),
                ),
              ]),
            ),
            if (_conectado)
              GestureDetector(
                onTap: _desconectar,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _C.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _C.danger.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.logout_rounded, color: _C.danger, size: 13),
                    const SizedBox(width: 4),
                    Text('Desconectar', style: GoogleFonts.dmSans(color: _C.danger, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: _buildContenidoEstado(),
        ),
      ]),
    );
  }

  Widget _buildContenidoEstado() {
    switch (_pageState) {
      case _PageState.idle:
        return _buildFormConectar();
      case _PageState.cargando:
        return _buildCargando();
      case _PageState.qrListo:
        return _buildQR();
      case _PageState.qrExpirado:
        return _buildQRExpirado();
      case _PageState.conectado:
        return _buildConectado();
      case _PageState.error:
        return _buildError();
    }
  }

  Widget _buildFormConectar() {
    return Column(children: [
      Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(color: _C.whatsapp.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.qr_code_2_rounded, color: _C.whatsapp, size: 38),
      ),
      const SizedBox(height: 16),
      Text('Conecta tu WhatsApp', style: GoogleFonts.dmSans(color: _C.textPri, fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(
        'Ingresa tu número y escanea el código QR con tu WhatsApp.',
        style: GoogleFonts.dmSans(color: _C.textSec, fontSize: 13),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text('NÚMERO DE WHATSAPP',
              style: GoogleFonts.dmSans(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        ),
        TextFormField(
          controller: _ctrlPhone,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.dmSans(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Ej: 573001234567',
            hintStyle: GoogleFonts.dmSans(color: _C.textSec.withOpacity(0.5), fontSize: 13),
            prefixIcon: Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: _C.whatsapp.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.phone_rounded, color: _C.whatsapp, size: 16),
            ),
            filled: true,
            fillColor: _C.surfaceDim,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            enabledBorder:
                OutlineInputBorder(borderSide: const BorderSide(color: _C.border, width: 1.2), borderRadius: BorderRadius.circular(12)),
            focusedBorder:
                OutlineInputBorder(borderSide: const BorderSide(color: _C.whatsapp, width: 1.8), borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: _crearInstancia,
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_C.whatsapp, Color(0xFF128C7E)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _C.whatsapp.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Generar código QR', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildCargando() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(children: [
        const SizedBox(width: 48, height: 48, child: CircularProgressIndicator(color: _C.whatsapp, strokeWidth: 3)),
        const SizedBox(height: 20),
        Text('Procesando...', style: GoogleFonts.dmSans(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Conectando con el servidor', style: GoogleFonts.dmSans(color: _C.textSec, fontSize: 12)),
      ]),
    );
  }

  Widget _buildQR() {
    return Column(children: [
      Text('Escanea con WhatsApp', style: GoogleFonts.dmSans(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(
        'Abre WhatsApp → Dispositivos vinculados → Vincular dispositivo',
        style: GoogleFonts.dmSans(color: _C.textSec, fontSize: 11),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      ScaleTransition(
        scale: _pulseAnim,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.whatsapp.withOpacity(0.3), width: 2),
            boxShadow: [BoxShadow(color: _C.whatsapp.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: _qrBase64 != null
              ? Image.memory(base64Decode(_qrBase64!), width: 220, height: 220)
              : const SizedBox(width: 220, height: 220, child: Center(child: CircularProgressIndicator(color: _C.whatsapp))),
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: (_qrExpiraSeg > 20 ? _C.success : _C.danger).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: (_qrExpiraSeg > 20 ? _C.success : _C.danger).withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.timer_rounded, color: _qrExpiraSeg > 20 ? _C.success : _C.danger, size: 16),
          const SizedBox(width: 6),
          Text('Expira en $_qrExpiraSeg s',
              style: GoogleFonts.dmSans(color: _qrExpiraSeg > 20 ? _C.success : _C.danger, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _C.textSec)),
        const SizedBox(width: 8),
        Text('Esperando escaneo...', style: GoogleFonts.dmSans(color: _C.textSec, fontSize: 12)),
      ]),
    ]);
  }

  Widget _buildQRExpirado() {
    return Column(children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: _C.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.timer_off_rounded, color: _C.warning, size: 32),
      ),
      const SizedBox(height: 16),
      Text('QR expirado', style: GoogleFonts.dmSans(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('El código QR expiró. Genera uno nuevo.', style: GoogleFonts.dmSans(color: _C.textSec, fontSize: 13)),
      const SizedBox(height: 20),
      _botonReintentar(),
    ]);
  }

  Widget _buildConectado() {
    final phone = _configExistente?['phone'] ?? _ctrlPhone.text;
    final instName = _configExistente?['instanceName'] ?? _instanceName ?? '-';

    return Column(children: [
      Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(color: _C.success.withOpacity(0.1), borderRadius: BorderRadius.circular(22)),
        child: const Icon(Icons.check_circle_rounded, color: _C.success, size: 42),
      ),
      const SizedBox(height: 16),
      Text('¡WhatsApp conectado!', style: GoogleFonts.dmSans(color: _C.textPri, fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Tu número está listo para enviar mensajes.',
          style: GoogleFonts.dmSans(color: _C.textSec, fontSize: 13), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      _infoRow(Icons.devices_rounded, _C.accent, 'Instancia', instName, copyValue: instName),
      const SizedBox(height: 8),
      _infoRow(Icons.phone_rounded, _C.whatsapp, 'Número', phone, copyValue: phone),
      const SizedBox(height: 8),
      _infoRow(Icons.cloud_done_rounded, _C.primary, 'Guardado en', 'Firebase ✓'),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        height: 46,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _C.whatsapp, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () async {
            final state = await _EvolutionService.fetchState(_instanceName ?? '');
            _snack(
              state == 'open' ? '¡Instancia activa y funcionando!' : 'Estado: $state',
              state == 'open' ? _C.success : _C.warning,
              state == 'open' ? Icons.check_circle_rounded : Icons.warning_rounded,
            );
          },
          icon: const Icon(Icons.send_rounded, color: _C.whatsapp, size: 16),
          label: Text('Verificar conexión', style: GoogleFonts.dmSans(color: _C.whatsapp, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }

  Widget _buildError() {
    return Column(children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: _C.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.error_rounded, color: _C.danger, size: 32),
      ),
      const SizedBox(height: 16),
      Text('Error de conexión', style: GoogleFonts.dmSans(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: _C.danger.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _C.danger.withOpacity(0.2))),
        child:
            Text(_errorMsg ?? 'Error desconocido', style: GoogleFonts.dmSans(color: _C.danger, fontSize: 11), textAlign: TextAlign.center),
      ),
      const SizedBox(height: 20),
      _botonReintentar(),
    ]);
  }

  Widget _botonReintentar() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: _C.whatsapp, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
        onPressed: () {
          setState(() {
            _pageState = _PageState.idle;
            _qrBase64 = null;
          });
        },
        icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
        label: Text('Intentar de nuevo', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _infoRow(IconData icon, Color color, String label, String value, {String? copyValue}) {
    return GestureDetector(
      onLongPress: copyValue != null
          ? () {
              Clipboard.setData(ClipboardData(text: copyValue));
              _snack('"$label" copiado', _C.primary, Icons.copy_rounded);
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: _C.surfaceDim, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.dmSans(color: _C.textSec, fontSize: 10, fontWeight: FontWeight.w500)),
            Text(value, style: GoogleFonts.dmSans(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w600)),
          ])),
          if (copyValue != null) Icon(Icons.copy_rounded, color: _C.textSec.withOpacity(0.35), size: 14),
        ]),
      ),
    );
  }
}
