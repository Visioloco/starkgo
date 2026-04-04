import 'package:stark_go/pages/vps_service.dart';

import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'vps_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'detalle_cliente_model.dart';
export 'detalle_cliente_model.dart';

class _C {
  static const Color primary = Color(0xFF1A73E8);
  static const Color accent = Color(0xFF00C6AE);
  static const Color danger = Color(0xFFE53935);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF22C55E);
  static const Color dark = Color(0xFF0F172A);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF1F5F9);
  static const Color textPri = Color(0xFF0F172A);
  static const Color textSec = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color purple = Color(0xFF7C3AED);
  static const Color whatsapp = Color(0xFF25D366);
}

Color _statusColor(String? s) {
  switch (s) {
    case 'activo':
      return _C.success;
    case 'mora':
      return _C.danger;
    case 'inactivo':
      return _C.warning;
    default:
      return _C.textSec;
  }
}

IconData _statusIcon(String? s) {
  switch (s) {
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

String _statusLabel(String? s) {
  switch (s) {
    case 'activo':
      return 'Activo';
    case 'mora':
      return 'En Mora';
    case 'inactivo':
      return 'Inactivo';
    default:
      return s ?? '-';
  }
}

double _parsePlan(dynamic raw) {
  if (raw == null) return 0.0;
  if (raw is double) return raw;
  if (raw is int) return raw.toDouble();
  if (raw is num) return raw.toDouble();
  final cleaned = raw.toString().replaceAll('.', '').replaceAll(',', '').trim();
  return double.tryParse(cleaned) ?? 0.0;
}

class _DataRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool copyable;
  const _DataRow({required this.icon, required this.iconColor, required this.label, required this.value, this.copyable = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: copyable
          ? () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('"$value" copiado', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
                backgroundColor: _C.primary,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ));
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(color: _C.surfaceDim, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: iconColor, size: 17)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w500)),
            const SizedBox(height: 1),
            Text(value.isEmpty ? '—' : value,
                style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w600)),
          ])),
          if (copyable) Icon(Icons.copy_rounded, color: _C.textSec.withOpacity(0.4), size: 15),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<Widget> children;
  const _Section({required this.icon, required this.color, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
        border: Border.all(color: _C.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, color.withOpacity(0.6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: Colors.white, size: 18)),
            const SizedBox(width: 10),
            Text(title, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          ...children.map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  MODELO DE PLAN (para el dropdown)
// ══════════════════════════════════════════════════════════════
class _PlanItem {
  final String id;
  final String nombre;
  final double valor;
  final String simbolo;
  final String monedaCodigo;

  const _PlanItem({
    required this.id,
    required this.nombre,
    required this.valor,
    required this.simbolo,
    required this.monedaCodigo,
  });

  /// Texto legible: "Plan Básico — COP $ 50,000"
  String get etiqueta => '$nombre — $simbolo ${valor.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}';
}

// ═══════════════════════════════════════════════════════════════
class DetalleClienteWidget extends StatefulWidget {
  const DetalleClienteWidget({super.key, required this.rf});
  final DocumentReference? rf;
  static String routeName = 'DetalleCliente';
  static String routePath = 'detalleCliente';

  @override
  State<DetalleClienteWidget> createState() => _DetalleClienteWidgetState();
}

class _DetalleClienteWidgetState extends State<DetalleClienteWidget> {
  late DetalleClienteModel _model;

  bool _modoEdicion = false;
  bool _guardando = false;
  String? _selectedStatus;

  // ── VPS config ───────────────────────────────────────────────
  static const String _vpsApiKey = 'starkgo2024';
  static const String _vpsBaseUrl = 'http://5.161.88.42:3000';

  // ── Credenciales UltraMsg ────────────────────────────────────
  String? _umInstance;
  String? _umToken;
  String? _nequiNumero;
  bool _configCargada = false;
  bool _configExiste = false;

  static const String _kConfigCol = 'config_ultramsg';

  // ── UID del usuario autenticado ──────────────────────────────
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Planes del usuario ───────────────────────────────────────
  List<_PlanItem> _planesDisponibles = [];
  bool _cargandoPlanes = false;
  _PlanItem? _selPlanItem; // plan seleccionado en edición

  // ── Controllers ──────────────────────────────────────────────
  final _ctrlNombre = TextEditingController();
  final _ctrlApellido = TextEditingController();
  final _ctrlCc = TextEditingController();
  final _ctrlNumero = TextEditingController();
  final _ctrlFinca = TextEditingController();
  final _ctrlVereda = TextEditingController();
  final _ctrlIpAtn = TextEditingController();
  final _ctrlUsuarioAtn = TextEditingController();
  final _ctrlClaveAtn = TextEditingController();
  final _ctrlIpRouter = TextEditingController();
  final _ctrlUsuarioRouter = TextEditingController();
  final _ctrlClaveRouter = TextEditingController();

  List<QueryDocumentSnapshot> _starlinks = [];
  List<QueryDocumentSnapshot> _antenas = [];
  List<QueryDocumentSnapshot> _routers = [];

  String? _selStarlinkId;
  Map<String, dynamic>? _selStarlinkData;
  String? _selAntenaId;
  Map<String, dynamic>? _selAntenaData;
  String? _selRouterId;
  Map<String, dynamic>? _selRouterData;
  String? _selVelocidad;
  String? _selTipoServicio;

  static const _velocidades = [
    '2M/2M',
    '2M/3M',
    '2M/4M',
    '2M/5M',
    '2M/6M',
    '2M/7M',
    '2M/8M',
    '2M/9M',
    '2M/10M',
  ];

  static const _tiposServicio = ['Fibra Óptica', 'Radio Enlace'];

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DetalleClienteModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
    _cargarConfigUltraMsg();
  }

  @override
  void dispose() {
    _ctrlNombre.dispose();
    _ctrlApellido.dispose();
    _ctrlCc.dispose();
    _ctrlNumero.dispose();
    _ctrlFinca.dispose();
    _ctrlVereda.dispose();
    _ctrlIpAtn.dispose();
    _ctrlUsuarioAtn.dispose();
    _ctrlClaveAtn.dispose();
    _ctrlIpRouter.dispose();
    _ctrlUsuarioRouter.dispose();
    _ctrlClaveRouter.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _cargarConfigUltraMsg() async {
    try {
      final snap = await FirebaseFirestore.instance.collection(_kConfigCol).orderBy('creadoEn', descending: false).limit(1).get();
      if (!mounted) return;
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        setState(() {
          _umInstance = data['instance'] as String?;
          _umToken = data['token'] as String?;
          _nequiNumero = data['nequi'] as String?;
          _configExiste = true;
          _configCargada = true;
        });
      } else {
        setState(() {
          _configExiste = false;
          _configCargada = true;
        });
      }
    } catch (e) {
      debugPrint('[StarkGo] Error cargando config UltraMsg: $e');
      if (mounted) setState(() => _configCargada = true);
    }
  }

  // ── Cargar planes del usuario autenticado desde Firestore ──
  Future<void> _cargarPlanesUsuario() async {
    if (_uid == null) return;
    setState(() => _cargandoPlanes = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('planes')
          .where('propietarioUid', isEqualTo: _uid)
          // sin orderBy por ahora
          .get();
      if (!mounted) return;
      setState(() {
        _planesDisponibles = snap.docs.map((doc) {
          final d = doc.data();
          return _PlanItem(
            id: doc.id,
            nombre: (d['nombre'] ?? '').toString(),
            valor: (d['valor'] is num) ? (d['valor'] as num).toDouble() : 0.0,
            simbolo: (d['monedaSimbolo'] ?? '').toString(),
            monedaCodigo: (d['monedaCodigo'] ?? '').toString(),
          );
        }).toList();
        _cargandoPlanes = false;
      });
    } catch (e) {
      debugPrint('[StarkGo] Error cargando planes: $e');
      if (mounted) setState(() => _cargandoPlanes = false);
    }
  }

  static String? _pick(Map<String, dynamic> data, String key) {
    final v = data[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  Future<void> _llamarVPS({required String status, required String ip, required String nombre}) async {
    final endpoint = status == 'mora' ? '/bloquear' : '/desbloquear';
    final body = <String, dynamic>{'apikey': _vpsApiKey, 'nombre': nombre};
    if (status == 'mora') body['ip'] = ip;
    try {
      final response = await http
          .post(Uri.parse('$_vpsBaseUrl$endpoint'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        debugPrint('[StarkGo] VPS OK ($endpoint): ${response.body}');
      } else {
        debugPrint('[StarkGo] VPS error ${response.statusCode}: ${response.body}');
        if (mounted) _snackWarning('VPS respondió con error. MikroTik aplicará el cambio en el próximo ciclo.');
      }
    } catch (e) {
      debugPrint('[StarkGo] VPS no disponible: $e');
      if (mounted) _snackWarning('VPS no disponible. MikroTik aplicará el cambio en el próximo ciclo.');
    }
  }

  Future<void> _enviarWhatsApp({required String numero, required String nombreCliente, required String planCliente}) async {
    if (!_configExiste || _umInstance == null || _umToken == null) {
      _snackWarning('No hay credenciales de WhatsApp. Ve a Configuración → WhatsApp y agrégalas.');
      return;
    }

    String tel = numero.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (tel.startsWith('0')) tel = tel.substring(1);
    if (!tel.startsWith('+') && !tel.startsWith('57')) tel = '57$tel';
    if (!tel.startsWith('+')) tel = '+$tel';

    final plan = planCliente.isNotEmpty ? planCliente : 'mensual';
    final nequi = (_nequiNumero != null && _nequiNumero!.isNotEmpty) ? _nequiNumero! : 'Sin número registrado';

    final mensaje = '''
🚫 *SERVICIO SUSPENDIDO* 🚫

Estimado/a *$nombreCliente*, le informamos que su servicio de internet ha sido *suspendido temporalmente* por falta de pago del plan \$$plan.

━━━━━━━━━━━━━━━━━━━━
💳 *INSTRUCCIONES DE PAGO*
━━━━━━━━━━━━━━━━━━━━

Para restablecer su servicio, realice el pago mediante:

📲 *Nequi:* $nequi

✅ Una vez realizado el pago, envíe el *comprobante* a este número para activar su servicio a la brevedad.

⏰ *Horario de atención:*
Domingo a Viernes · 8:00 am – 6:00 pm

Agradecemos su comprensión y quedamos atentos a su respuesta.

— *Equipo StarkGo* 🌐''';

    try {
      final response = await http.post(
        Uri.parse('https://api.ultramsg.com/$_umInstance/messages/chat'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'token': _umToken!, 'to': tel, 'body': mensaje},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        debugPrint('[StarkGo] WhatsApp enviado a $tel');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.chat_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('WhatsApp enviado a $nombreCliente', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
            ]),
            backgroundColor: _C.whatsapp,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      } else {
        if (mounted) _snackWarning('No se pudo enviar el WhatsApp. Verifica la conexión.');
      }
    } catch (e) {
      if (mounted) _snackWarning('Error al enviar WhatsApp: $e');
    }
  }

  void _snackWarning(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 12))),
      ]),
      backgroundColor: _C.warning,
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _cargarEquipos() async {
    final sl = await FirebaseFirestore.instance.collection('starlinks').orderBy('nombre').get();
    final an = await FirebaseFirestore.instance.collection('equipos').where('tipo', isEqualTo: 'antena').get();
    final ro = await FirebaseFirestore.instance.collection('equipos').where('tipo', isEqualTo: 'router').get();
    if (!mounted) return;
    setState(() {
      _starlinks = sl.docs;
      _antenas = an.docs;
      _routers = ro.docs;
    });
  }

  void _activarEdicion(ClientesRecord c, Map<String, dynamic> raw) {
    _ctrlNombre.text = c.nombre;
    _ctrlApellido.text = c.apellido ?? '';
    _ctrlCc.text = c.cc.toString();
    _ctrlNumero.text = c.numero.toString();
    _ctrlFinca.text = c.nombrefinca;
    _ctrlVereda.text = c.vereda;
    _ctrlIpAtn.text = c.ipatn;
    _ctrlUsuarioAtn.text = c.usuarioatn;
    _ctrlClaveAtn.text = c.claveatn;
    _ctrlIpRouter.text = c.iprouter;
    _ctrlUsuarioRouter.text = c.usuariorouter;
    _ctrlClaveRouter.text = c.claverouter;

    _selStarlinkId = _pick(raw, 'starlinkId');
    _selAntenaId = _pick(raw, 'antenaId');
    _selRouterId = _pick(raw, 'routerId');
    _selVelocidad = _velocidades.contains(_pick(raw, 'velocidadPlan')) ? _pick(raw, 'velocidadPlan') : null;
    _selTipoServicio = _tiposServicio.contains(_pick(raw, 'tipoServicio')) ? _pick(raw, 'tipoServicio') : null;
    _selPlanItem = null;
    _selStarlinkData = null;
    _selAntenaData = null;
    _selRouterData = null;

    setState(() => _modoEdicion = true);

    // Cargar equipos y planes en paralelo
    Future.wait([_cargarEquipos(), _cargarPlanesUsuario()]).then((_) {
      if (!mounted) return;
      final savedPlanId = _pick(raw, 'planId');
      setState(() {
        // Restaurar plan guardado
        if (savedPlanId != null) {
          try {
            _selPlanItem = _planesDisponibles.firstWhere((p) => p.id == savedPlanId);
          } catch (_) {
            _selPlanItem = null;
          }
        }
        // Restaurar equipos
        if (_selStarlinkId != null) {
          final idx = _starlinks.indexWhere((d) => d.id == _selStarlinkId);
          if (idx >= 0) {
            _selStarlinkData = _starlinks[idx].data() as Map<String, dynamic>;
          } else {
            _selStarlinkId = null;
          }
        }
        if (_selAntenaId != null) {
          final idx = _antenas.indexWhere((d) => d.id == _selAntenaId);
          if (idx >= 0) {
            _selAntenaData = _antenas[idx].data() as Map<String, dynamic>;
          } else {
            _selAntenaId = null;
          }
        }
        if (_selRouterId != null) {
          final idx = _routers.indexWhere((d) => d.id == _selRouterId);
          if (idx >= 0) {
            _selRouterData = _routers[idx].data() as Map<String, dynamic>;
          } else {
            _selRouterId = null;
          }
        }
      });
    });
  }

  void _cancelarEdicion() {
    setState(() {
      _modoEdicion = false;
      _selStarlinkId = null;
      _selStarlinkData = null;
      _selAntenaId = null;
      _selAntenaData = null;
      _selRouterId = null;
      _selRouterData = null;
      _selPlanItem = null;
      _selVelocidad = null;
      _selTipoServicio = null;
      _planesDisponibles = [];
    });
  }

  Future<void> _guardarTodo(ClientesRecord c, Map<String, dynamic> raw) async {
    setState(() => _guardando = true);
    try {
      final updates = <String, dynamic>{};
      final nombre = _ctrlNombre.text.trim();
      final apellido = _ctrlApellido.text.trim();
      final finca = _ctrlFinca.text.trim();
      final vereda = _ctrlVereda.text.trim();
      final ccInt = int.tryParse(_ctrlCc.text.trim());
      final numInt = int.tryParse(_ctrlNumero.text.trim());

      if (nombre.isNotEmpty) updates['nombre'] = nombre;
      if (apellido.isNotEmpty) updates['apellido'] = apellido;
      if (finca.isNotEmpty) updates['nombrefinca'] = finca;
      if (vereda.isNotEmpty) updates['vereda'] = vereda;
      if (ccInt != null) updates['cc'] = ccInt;
      if (numInt != null) updates['numero'] = numInt;

      final ipAtn = _ctrlIpAtn.text.trim();
      final usuarioAtn = _ctrlUsuarioAtn.text.trim();
      final claveAtn = _ctrlClaveAtn.text.trim();
      if (ipAtn.isNotEmpty) updates['ipatn'] = ipAtn;
      if (usuarioAtn.isNotEmpty) updates['usuarioatn'] = usuarioAtn;
      if (claveAtn.isNotEmpty) updates['claveatn'] = claveAtn;

      final ipRouter = _ctrlIpRouter.text.trim();
      final usuarioRouter = _ctrlUsuarioRouter.text.trim();
      final claveRouter = _ctrlClaveRouter.text.trim();
      if (ipRouter.isNotEmpty) updates['iprouter'] = ipRouter;
      if (usuarioRouter.isNotEmpty) updates['usuariorouter'] = usuarioRouter;
      if (claveRouter.isNotEmpty) updates['claverouter'] = claveRouter;

      if (_selStarlinkId != null && _selStarlinkData != null) {
        updates['starlinkId'] = _selStarlinkId!;
        updates['starlinkNombre'] = _selStarlinkData!['nombre'] ?? '';
      }
      if (_selAntenaId != null && _selAntenaData != null) {
        updates['antenaId'] = _selAntenaId!;
        updates['antenaMarca'] = _selAntenaData!['marca'] ?? '';
        updates['antenaModelo'] = _selAntenaData!['modelo'] ?? '';
        updates['antenaIp'] = _selAntenaData!['ip'] ?? '';
      }
      if (_selRouterId != null && _selRouterData != null) {
        updates['routerId'] = _selRouterId!;
        updates['routerMarca'] = _selRouterData!['marca'] ?? '';
        updates['routerModelo'] = _selRouterData!['modelo'] ?? '';
        updates['routerIp'] = _selRouterData!['ip'] ?? '';
      }

      // ── NUEVO: guardar planId, nombre, valor y símbolo del plan seleccionado ──
      if (_selPlanItem != null) {
        updates['planId'] = _selPlanItem!.id;
        updates['planCliente'] = _selPlanItem!.nombre;
        updates['planValor'] = _selPlanItem!.valor;
        updates['planSimbolo'] = _selPlanItem!.simbolo;
        updates['planMoneda'] = _selPlanItem!.monedaCodigo;
      }

      if (_selVelocidad != null) updates['velocidadPlan'] = _selVelocidad!;
      if (_selTipoServicio != null) updates['tipoServicio'] = _selTipoServicio!;

      if (updates.isNotEmpty) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) updates['propietarioUid'] = uid;
        await c.reference.update(updates);

        final prevStarlinkId = _pick(raw, 'starlinkId');
        if (_selStarlinkId != null && _selStarlinkId != prevStarlinkId) {
          await FirebaseFirestore.instance.collection('starlinks').doc(_selStarlinkId).update({'clientes_count': FieldValue.increment(1)});
          if (prevStarlinkId != null) {
            await FirebaseFirestore.instance
                .collection('starlinks')
                .doc(prevStarlinkId)
                .update({'clientes_count': FieldValue.increment(-1)});
          }
        }
      }

      if (mounted) {
        setState(() => _modoEdicion = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Cliente actualizado correctamente', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          ]),
          backgroundColor: _C.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          backgroundColor: _C.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cambiarEstado(ClientesRecord cliente, Map<String, dynamic> raw) async {
    if (_selectedStatus == null) return;

    if (_selectedStatus == 'mora' && _configCargada && !_configExiste) {
      _mostrarDialogSinConfig();
      return;
    }

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Confirmar cambio', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
            content: RichText(
                text: TextSpan(
              style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14),
              children: [
                const TextSpan(text: 'Cambiar de '),
                TextSpan(
                    text: _statusLabel(cliente.status).toUpperCase(),
                    style: TextStyle(color: _statusColor(cliente.status), fontWeight: FontWeight.w700)),
                const TextSpan(text: ' → '),
                TextSpan(
                    text: _statusLabel(_selectedStatus).toUpperCase(),
                    style: TextStyle(color: _statusColor(_selectedStatus), fontWeight: FontWeight.w700)),
                if (_selectedStatus == 'mora')
                  TextSpan(
                      text: '\n\n📲 Se enviará un aviso de suspensión por WhatsApp al cliente.',
                      style: TextStyle(color: _C.textSec, fontSize: 12, fontWeight: FontWeight.w500)),
                const TextSpan(text: '\n\n¿Estás seguro?'),
              ],
            )),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _C.textSec))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _statusColor(_selectedStatus),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Confirmar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    await cliente.reference.update(createClientesRecordData(status: _selectedStatus));
    final nuevoStatus = _selectedStatus!;
    setState(() => _selectedStatus = null);

    final ip = cliente.ipatn.trim();
    final nombre = '${cliente.nombre} ${cliente.apellido ?? ''}'.trim();
    if (ip.isNotEmpty) await _llamarVPS(status: nuevoStatus, ip: ip, nombre: nombre);

    await VpsService.cambiarStatus(
      status: nuevoStatus,
      ip: cliente.ipatn.trim(),
      nombre: '${cliente.nombre} ${cliente.apellido ?? ''}'.trim(),
    );
    if (nuevoStatus == 'mora') {
      final numero = cliente.numero.toString().trim();
      final planCliente = _pick(raw, 'planCliente') ?? '';
      if (numero.isNotEmpty && numero != '0') {
        await _enviarWhatsApp(numero: numero, nombreCliente: nombre, planCliente: planCliente);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          Icon(nuevoStatus == 'mora' ? Icons.block_rounded : Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            nuevoStatus == 'mora'
                ? 'Servicio suspendido y cliente notificado por WhatsApp'
                : 'Servicio ${_statusLabel(nuevoStatus).toLowerCase()} correctamente',
            style: GoogleFonts.spaceGrotesk(color: Colors.white),
          ),
        ]),
        backgroundColor: _statusColor(nuevoStatus),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  void _mostrarDialogSinConfig() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: _C.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.settings_rounded, color: _C.warning, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text('Configuración requerida', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 15))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: _C.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.warning.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: _C.warning, size: 18),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                'Para poner un cliente en mora y enviar notificación por WhatsApp, primero debes registrar las credenciales de UltraMsg.',
                style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12),
              )),
            ]),
          ),
          const SizedBox(height: 14),
          Text('¿Qué necesitas registrar?', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _dialogItem(Icons.devices_rounded, _C.accent, 'Instance ID de UltraMsg'),
          _dialogItem(Icons.vpn_key_rounded, _C.purple, 'Token de UltraMsg'),
          _dialogItem(Icons.account_balance_wallet_rounded, _C.success, 'Número de Nequi'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _C.textSec))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _C.whatsapp, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            onPressed: () {
              Navigator.pop(context);
              context.pushNamed(ConfigUltraMsgWidget.routeName);
            },
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.settings_rounded, color: Colors.white, size: 15),
              const SizedBox(width: 6),
              Text('Ir a Configuración', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _dialogItem(IconData icon, Color color, String label) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(7)),
              child: Icon(icon, color: color, size: 14)),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 12, fontWeight: FontWeight.w500)),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ClientesRecord>(
      stream: ClientesRecord.getDocument(widget.rf!),
      builder: (context, snapFF) {
        if (!snapFF.hasData) {
          return Scaffold(
              backgroundColor: _C.surfaceDim, body: Center(child: CircularProgressIndicator(color: _C.primary, strokeWidth: 2.5)));
        }
        final c = snapFF.data!;

        return StreamBuilder<DocumentSnapshot>(
          stream: widget.rf!.snapshots(),
          builder: (context, snapRaw) {
            final raw = (snapRaw.hasData && snapRaw.data!.exists) ? (snapRaw.data!.data() as Map<String, dynamic>) : <String, dynamic>{};

            return GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Scaffold(
                backgroundColor: _C.surfaceDim,
                body: SafeArea(
                  child: Stack(children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 110),
                      child: Column(children: [
                        _buildTopBar(context, c, raw),
                        _buildHeroCard(c),
                        if (_configCargada && !_configExiste) _buildBannerSinConfig(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(children: [
                            if (_modoEdicion) _buildEditBanner(c, raw).animate().fadeIn(duration: 200.ms).slideY(begin: -0.05, end: 0),
                            (_modoEdicion
                                    ? _buildEditPersonal()
                                    : _Section(
                                        icon: Icons.person_rounded,
                                        color: _C.primary,
                                        title: 'Datos Personales',
                                        children: [
                                          _DataRow(
                                              icon: Icons.badge_rounded,
                                              iconColor: _C.primary,
                                              label: 'Nombre completo',
                                              value: '${c.nombre} ${c.apellido}'),
                                          _DataRow(
                                              icon: Icons.credit_card_rounded,
                                              iconColor: _C.primary,
                                              label: 'Cédula',
                                              value: c.cc.toString(),
                                              copyable: true),
                                          _DataRow(
                                              icon: Icons.phone_rounded,
                                              iconColor: _C.success,
                                              label: 'Número telefónico',
                                              value: c.numero.toString(),
                                              copyable: true),
                                          _DataRow(
                                              icon: Icons.location_on_rounded, iconColor: _C.warning, label: 'Vereda', value: c.vereda),
                                          _DataRow(
                                              icon: Icons.agriculture_rounded,
                                              iconColor: _C.accent,
                                              label: 'Nombre de finca',
                                              value: c.nombrefinca),
                                        ],
                                      ))
                                .animate()
                                .fadeIn(duration: 300.ms, delay: 80.ms)
                                .slideY(begin: 0.05, end: 0),
                            (_modoEdicion
                                    ? _buildEditAntena()
                                    : _Section(
                                        icon: Icons.cell_tower_rounded,
                                        color: _C.accent,
                                        title: 'Configuración de Antena',
                                        children: [
                                          _DataRow(
                                              icon: Icons.router_rounded,
                                              iconColor: _C.accent,
                                              label: 'IP Antena',
                                              value: c.ipatn,
                                              copyable: true),
                                          _DataRow(
                                              icon: Icons.person_pin_rounded,
                                              iconColor: _C.accent,
                                              label: 'Usuario Antena',
                                              value: c.usuarioatn,
                                              copyable: true),
                                          _DataRow(
                                              icon: Icons.lock_rounded,
                                              iconColor: _C.accent,
                                              label: 'Clave Antena',
                                              value: c.claveatn,
                                              copyable: true),
                                        ],
                                      ))
                                .animate()
                                .fadeIn(duration: 300.ms, delay: 160.ms)
                                .slideY(begin: 0.05, end: 0),
                            (_modoEdicion
                                    ? _buildEditRouter()
                                    : _Section(
                                        icon: Icons.device_hub_rounded,
                                        color: _C.purple,
                                        title: 'Configuración de Router',
                                        children: [
                                          _DataRow(
                                              icon: Icons.router_rounded,
                                              iconColor: _C.purple,
                                              label: 'IP Router',
                                              value: c.iprouter,
                                              copyable: true),
                                          _DataRow(
                                              icon: Icons.person_pin_rounded,
                                              iconColor: _C.purple,
                                              label: 'Usuario Router',
                                              value: c.usuariorouter,
                                              copyable: true),
                                          _DataRow(
                                              icon: Icons.lock_rounded,
                                              iconColor: _C.purple,
                                              label: 'Clave Router',
                                              value: c.claverouter,
                                              copyable: true),
                                        ],
                                      ))
                                .animate()
                                .fadeIn(duration: 300.ms, delay: 240.ms)
                                .slideY(begin: 0.05, end: 0),
                            _buildStatusSection(c, raw).animate().fadeIn(duration: 300.ms, delay: 300.ms).slideY(begin: 0.05, end: 0),
                            _buildEquiposSection(c, raw).animate().fadeIn(duration: 300.ms, delay: 360.ms).slideY(begin: 0.05, end: 0),
                          ]),
                        ),
                      ]),
                    ),

                    // FAB Registrar Pago
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: GestureDetector(
                          onTap: () => context.pushNamed(RegistrarPagoWidget.routeName,
                              queryParameters: {
                                'nombre': serializeParam(c.nombre, ParamType.String),
                                'numero': serializeParam(c.numero, ParamType.int),
                                'refcliente': serializeParam(c.reference, ParamType.DocumentReference),
                                'planCliente': serializeParam(_parsePlan(raw['planValor']), ParamType.double),
                              }.withoutNulls),
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [_C.primary, _C.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: _C.primary.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))]),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.payments_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text('Registrar Pago',
                                  style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBannerSinConfig() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: () => context.pushNamed(ConfigUltraMsgWidget.routeName),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [_C.warning.withOpacity(0.12), _C.warning.withOpacity(0.04)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.warning.withOpacity(0.4), width: 1.2)),
          child: Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: _C.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.warning_amber_rounded, color: _C.warning, size: 18)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('WhatsApp no configurado',
                  style: GoogleFonts.spaceGrotesk(color: _C.warning, fontSize: 13, fontWeight: FontWeight.w700)),
              Text('Toca aquí para registrar las credenciales de UltraMsg.',
                  style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
            ])),
            const Icon(Icons.arrow_forward_ios_rounded, color: _C.warning, size: 14),
          ]),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.03, end: 0),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, ClientesRecord c, Map<String, dynamic> raw) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(children: [
        GestureDetector(
            onTap: () => context.pushNamed(HomeWidget.routeName),
            child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: _C.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))]),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.textPri, size: 18))),
        const SizedBox(width: 12),
        Expanded(
            child:
                Text('Detalle del Cliente', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 18, fontWeight: FontWeight.w800))),
        GestureDetector(
          onTap: () => _modoEdicion ? _cancelarEdicion() : _activarEdicion(c, raw),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: _modoEdicion ? _C.danger.withOpacity(0.1) : _C.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _modoEdicion ? _C.danger.withOpacity(0.3) : _C.warning.withOpacity(0.4))),
            child: Row(children: [
              Icon(_modoEdicion ? Icons.close_rounded : Icons.edit_rounded, color: _modoEdicion ? _C.danger : _C.warning, size: 15),
              const SizedBox(width: 5),
              Text(_modoEdicion ? 'Cancelar' : 'Editar',
                  style: GoogleFonts.spaceGrotesk(color: _modoEdicion ? _C.danger : _C.warning, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => context.pushNamed(DetallesdepagoWidget.routeName,
              queryParameters: {'refcliente': serializeParam(c.reference, ParamType.DocumentReference)}.withoutNulls),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: _C.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.primary.withOpacity(0.3), width: 1)),
            child: Row(children: [
              Icon(Icons.receipt_long_rounded, color: _C.primary, size: 15),
              const SizedBox(width: 5),
              Text('Pagos', style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeroCard(ClientesRecord c) {
    final sc = _statusColor(c.status);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Container(
        decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_C.dark, Color(0xFF1E293B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: _C.dark.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8))]),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [sc, sc.withOpacity(0.5)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                child: Center(
                    child: Text(c.nombre.isNotEmpty ? c.nombre[0].toUpperCase() : '?',
                        style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)))),
            const SizedBox(width: 16),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${c.nombre} ${c.apellido}',
                  style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(c.nombrefinca, style: GoogleFonts.spaceGrotesk(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 10),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                      color: sc.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sc.withOpacity(0.4), width: 1)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_statusIcon(c.status), color: sc, size: 13),
                    const SizedBox(width: 5),
                    Text(_statusLabel(c.status), style: GoogleFonts.spaceGrotesk(color: sc, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
                if (_modoEdicion) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: _C.warning.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _C.warning.withOpacity(0.5))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.edit_rounded, color: _C.warning, size: 11),
                      const SizedBox(width: 4),
                      Text('Editando', style: GoogleFonts.spaceGrotesk(color: _C.warning, fontSize: 10, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
              ]),
            ])),
          ]),
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0),
    );
  }

  Widget _buildEditBanner(ClientesRecord c, Map<String, dynamic> raw) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          gradient:
              const LinearGradient(colors: [Color(0xFFFFF8E7), Color(0xFFFFF3CD)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.warning.withOpacity(0.4), width: 1.2)),
      child: Row(children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: _C.warning.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.edit_rounded, color: _C.warning, size: 18)),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Modo edición activo', style: GoogleFonts.spaceGrotesk(color: _C.warning, fontSize: 13, fontWeight: FontWeight.w700)),
          Text('Modifica lo que necesites y presiona guardar', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
        ])),
        GestureDetector(
          onTap: _guardando ? null : () => _guardarTodo(c, raw),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
                gradient: _guardando ? null : const LinearGradient(colors: [_C.primary, _C.accent]),
                color: _guardando ? _C.border : null,
                borderRadius: BorderRadius.circular(10),
                boxShadow: _guardando ? [] : [BoxShadow(color: _C.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]),
            child: _guardando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _C.textSec))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.save_rounded, color: Colors.white, size: 15),
                    const SizedBox(width: 5),
                    Text('Guardar todo', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildEditPersonal() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
          border: Border.all(color: _C.warning.withOpacity(0.4), width: 1.5)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [_C.primary, _C.primary.withOpacity(0.6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 18)),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Datos Personales',
                    style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700))),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: _C.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('Editando', style: GoogleFonts.spaceGrotesk(color: _C.warning, fontSize: 10, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 16),
          _editField(controller: _ctrlNombre, label: 'NOMBRE', icon: Icons.badge_rounded, color: _C.primary),
          const SizedBox(height: 10),
          _editField(controller: _ctrlApellido, label: 'APELLIDO', icon: Icons.badge_outlined, color: _C.primary),
          const SizedBox(height: 10),
          _editField(
              controller: _ctrlCc,
              label: 'CÉDULA',
              icon: Icons.credit_card_rounded,
              color: _C.purple,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
          const SizedBox(height: 10),
          _editField(
              controller: _ctrlNumero,
              label: 'TELÉFONO',
              icon: Icons.phone_rounded,
              color: _C.success,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
          const SizedBox(height: 10),
          _editField(controller: _ctrlFinca, label: 'NOMBRE FINCA', icon: Icons.agriculture_rounded, color: _C.accent),
          const SizedBox(height: 10),
          _editField(controller: _ctrlVereda, label: 'VEREDA', icon: Icons.map_rounded, color: _C.warning),
        ]),
      ),
    );
  }

  Widget _buildEditAntena() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
          border: Border.all(color: _C.warning.withOpacity(0.4), width: 1.5)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [_C.accent, _C.accent.withOpacity(0.6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.cell_tower_rounded, color: Colors.white, size: 18)),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Configuración de Antena',
                    style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700))),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: _C.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('Editando', style: GoogleFonts.spaceGrotesk(color: _C.warning, fontSize: 10, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 16),
          _editField(controller: _ctrlIpAtn, label: 'IP ANTENA', icon: Icons.router_rounded, color: _C.accent),
          const SizedBox(height: 10),
          _editField(controller: _ctrlUsuarioAtn, label: 'USUARIO ANTENA', icon: Icons.person_pin_rounded, color: _C.accent),
          const SizedBox(height: 10),
          _editField(controller: _ctrlClaveAtn, label: 'CLAVE ANTENA', icon: Icons.lock_rounded, color: _C.accent),
        ]),
      ),
    );
  }

  Widget _buildEditRouter() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
          border: Border.all(color: _C.warning.withOpacity(0.4), width: 1.5)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [_C.purple, _C.purple.withOpacity(0.6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.device_hub_rounded, color: Colors.white, size: 18)),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Configuración de Router',
                    style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700))),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: _C.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('Editando', style: GoogleFonts.spaceGrotesk(color: _C.warning, fontSize: 10, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 16),
          _editField(controller: _ctrlIpRouter, label: 'IP ROUTER', icon: Icons.router_rounded, color: _C.purple),
          const SizedBox(height: 10),
          _editField(controller: _ctrlUsuarioRouter, label: 'USUARIO ROUTER', icon: Icons.person_pin_rounded, color: _C.purple),
          const SizedBox(height: 10),
          _editField(controller: _ctrlClaveRouter, label: 'CLAVE ROUTER', icon: Icons.lock_rounded, color: _C.purple),
        ]),
      ),
    );
  }

  Widget _editField(
      {required TextEditingController controller,
      required String label,
      required IconData icon,
      required Color color,
      TextInputType keyboardType = TextInputType.text,
      List<TextInputFormatter>? inputFormatters}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 5),
          child: Text(label,
              style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3))),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          prefixIcon: Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 16)),
          filled: true,
          fillColor: _C.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _C.border, width: 1.2), borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: color, width: 1.8), borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ]);
  }

  Widget _buildStatusSection(ClientesRecord c, Map<String, dynamic> raw) {
    final options = ['activo', 'mora', 'inactivo'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
          border: Border.all(color: _C.border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [_C.warning, _C.warning.withOpacity(0.6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18)),
            const SizedBox(width: 10),
            Text('Cambiar Estado', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          Row(
              children: options.map((opt) {
            final isSelected = _selectedStatus == opt;
            final isCurrent = c.status == opt;
            final col = _statusColor(opt);
            return Expanded(
                child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: () => setState(() => _selectedStatus = isSelected ? null : opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                      color: isSelected
                          ? col.withOpacity(0.15)
                          : isCurrent
                              ? col.withOpacity(0.06)
                              : _C.surfaceDim,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isSelected
                              ? col
                              : isCurrent
                                  ? col.withOpacity(0.3)
                                  : _C.border,
                          width: isSelected ? 2 : 1)),
                  child: Column(children: [
                    Icon(_statusIcon(opt), color: isSelected || isCurrent ? col : _C.textSec, size: 18),
                    const SizedBox(height: 4),
                    Text(_statusLabel(opt),
                        style: GoogleFonts.spaceGrotesk(
                            color: isSelected || isCurrent ? col : _C.textSec,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
                        textAlign: TextAlign.center),
                    if (isCurrent && !isSelected)
                      Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text('actual', style: GoogleFonts.spaceGrotesk(color: col.withOpacity(0.7), fontSize: 9))),
                    if (opt == 'mora' && !isCurrent)
                      Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.chat_rounded, size: 9, color: isSelected ? _C.whatsapp : _C.textSec.withOpacity(0.5)),
                            const SizedBox(width: 2),
                            Text('aviso',
                                style:
                                    GoogleFonts.spaceGrotesk(color: isSelected ? _C.whatsapp : _C.textSec.withOpacity(0.5), fontSize: 8)),
                          ])),
                  ]),
                ),
              ),
            ));
          }).toList()),
          if (_selectedStatus != null && _selectedStatus != c.status) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _statusColor(_selectedStatus),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0),
                onPressed: () => _cambiarEstado(c, raw),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _selectedStatus == 'mora' ? 'Suspender y notificar por WhatsApp' : 'Confirmar → ${_statusLabel(_selectedStatus)}',
                    style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  SECCIÓN EQUIPOS — con dropdown de planes desde Firestore
  // ══════════════════════════════════════════════════════════════
  Widget _buildEquiposSection(ClientesRecord c, Map<String, dynamic> raw) {
    final starlinkNombre = _pick(raw, 'starlinkNombre');
    final antenaMarca = _pick(raw, 'antenaMarca');
    final antenaModelo = _pick(raw, 'antenaModelo');
    final antenaIp = _pick(raw, 'antenaIp');
    final routerMarca = _pick(raw, 'routerMarca');
    final routerModelo = _pick(raw, 'routerModelo');
    final routerIp = _pick(raw, 'routerIp');

    // ── Datos del plan guardado en el cliente ──
    final planNombre = _pick(raw, 'planCliente');
    final planValor = raw['planValor'];
    final planSimbolo = _pick(raw, 'planSimbolo') ?? '';
    final planMoneda = _pick(raw, 'planMoneda') ?? '';
    final velocidadPlan = _pick(raw, 'velocidadPlan');
    final tipoServicio = _pick(raw, 'tipoServicio');

    // Texto legible del plan guardado
    String? planTexto;
    if (planNombre != null) {
      final valorFmt =
          planValor != null ? (planValor as num).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.') : '';
      planTexto = '$planNombre${valorFmt.isNotEmpty ? ' — $planSimbolo $valorFmt' : ''}';
    }

    Widget infoChip(IconData icon, Color color, String label, String? value) {
      final isEmpty = value == null;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: isEmpty ? _C.surfaceDim : color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isEmpty ? _C.border : color.withOpacity(0.25), width: 1.2)),
        child: Row(children: [
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: isEmpty ? _C.textSec : color, size: 16)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10, fontWeight: FontWeight.w500)),
            Text(isEmpty ? 'Sin asignar' : value!,
                style: GoogleFonts.spaceGrotesk(color: isEmpty ? _C.textSec : _C.textPri, fontSize: 13, fontWeight: FontWeight.w600)),
          ])),
          if (isEmpty)
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: _C.warning.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text('Pendiente', style: GoogleFonts.spaceGrotesk(color: _C.warning, fontSize: 9, fontWeight: FontWeight.w700))),
        ]),
      );
    }

    Widget drop<T>({
      required String label,
      required IconData icon,
      required Color color,
      required T? value,
      required List<DropdownMenuItem<T>> items,
      required ValueChanged<T?> onChanged,
    }) {
      final safeValue = items.isNotEmpty && items.any((item) => item.value == value) ? value : null;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 5),
            child: Text(label,
                style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3))),
        Container(
            decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: safeValue != null ? color : _C.warning.withOpacity(0.5), width: safeValue != null ? 1.8 : 1.4)),
            child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
              value: safeValue,
              isExpanded: true,
              borderRadius: BorderRadius.circular(13),
              dropdownColor: _C.surface,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              icon: Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.keyboard_arrow_down_rounded, color: _C.textSec)),
              hint: Row(children: [
                Container(
                    margin: const EdgeInsets.only(left: 6, right: 10),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, color: color, size: 15)),
                Text('Seleccionar...', style: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.6), fontSize: 13)),
              ]),
              items: items,
              onChanged: onChanged,
            ))),
      ]);
    }

    Widget dItem(IconData icon, String title, String sub, Color color) => Row(children: [
          Container(
              margin: const EdgeInsets.only(left: 4, right: 10),
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(7)),
              child: Icon(icon, color: color, size: 14)),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(sub, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10)),
          ])),
        ]);

    // ── Widget dropdown de planes con estado vacío ──
    Widget _buildPlanDropdown() {
      if (_cargandoPlanes) {
        return Container(
          height: 56,
          decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: _C.border)),
          child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary)),
            const SizedBox(width: 8),
            Text('Cargando planes...', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13)),
          ])),
        );
      }

      if (_planesDisponibles.isEmpty) {
        // ── Estado vacío: no hay planes creados ──
        return GestureDetector(
          onTap: () => context.pushNamed(PlanesWidget.routeName),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: _C.danger.withOpacity(0.04),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _C.danger.withOpacity(0.35), width: 1.4)),
            child: Row(children: [
              Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: _C.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.add_card_rounded, color: _C.danger, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sin planes creados', style: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 13, fontWeight: FontWeight.w700)),
                Text('Toca aquí para crear tu primer plan de servicio', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
              ])),
              const Icon(Icons.arrow_forward_ios_rounded, color: _C.danger, size: 14),
            ]),
          ),
        );
      }

      // Hay planes → mostrar dropdown normal
      final safeValue = _planesDisponibles.any((p) => p.id == _selPlanItem?.id) ? _selPlanItem : null;

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 5),
            child: Text('PLAN DEL CLIENTE',
                style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3))),
        Container(
            decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(13),
                border:
                    Border.all(color: safeValue != null ? _C.success : _C.warning.withOpacity(0.5), width: safeValue != null ? 1.8 : 1.4)),
            child: DropdownButtonHideUnderline(
                child: DropdownButton<_PlanItem>(
              value: safeValue,
              isExpanded: true,
              borderRadius: BorderRadius.circular(13),
              dropdownColor: _C.surface,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              icon: Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.keyboard_arrow_down_rounded, color: _C.textSec)),
              hint: Row(children: [
                Container(
                    margin: const EdgeInsets.only(left: 6, right: 10),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: _C.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.payments_rounded, color: _C.success, size: 15)),
                Text('Seleccionar plan...', style: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.6), fontSize: 13)),
              ]),
              items: _planesDisponibles
                  .map((p) => DropdownMenuItem<_PlanItem>(
                        value: p,
                        child: dItem(
                          Icons.payments_rounded,
                          p.nombre,
                          '${p.simbolo} ${p.valor.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')} / mes · ${p.monedaCodigo}',
                          _C.success,
                        ),
                      ))
                  .toList(),
              onChanged: (p) => setState(() => _selPlanItem = p),
            ))),
      ]);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
          border: Border.all(color: _modoEdicion ? _C.warning.withOpacity(0.4) : _C.border, width: _modoEdicion ? 1.5 : 1.0)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_C.primary, _C.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.satellite_alt_rounded, color: Colors.white, size: 18)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Red y Equipos', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
              Text(_modoEdicion ? 'Selecciona o cambia los equipos' : 'Starlink, antena, router y plan',
                  style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10)),
            ])),
            if (_modoEdicion)
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: _C.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text('Editando', style: GoogleFonts.spaceGrotesk(color: _C.warning, fontSize: 10, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 14),
          Divider(color: _C.border, height: 1),
          const SizedBox(height: 14),
          if (!_modoEdicion) ...[
            // ── VISTA (solo lectura) ──
            infoChip(Icons.satellite_alt_rounded, _C.primary, 'Starlink', starlinkNombre),
            const SizedBox(height: 8),
            infoChip(Icons.cell_tower_rounded, _C.accent, 'Antena',
                (antenaMarca != null && antenaModelo != null) ? '$antenaMarca $antenaModelo  ·  IP: ${antenaIp ?? "-"}' : null),
            const SizedBox(height: 8),
            infoChip(Icons.router_rounded, _C.purple, 'Router',
                (routerMarca != null && routerModelo != null) ? '$routerMarca $routerModelo  ·  IP: ${routerIp ?? "-"}' : null),
            const SizedBox(height: 8),
            // Plan con nombre y valor del plan real
            infoChip(Icons.payments_rounded, _C.success, 'Plan del cliente', planTexto),
            const SizedBox(height: 8),
            infoChip(Icons.speed_rounded, _C.warning, 'Velocidad (subida/bajada)', velocidadPlan),
            const SizedBox(height: 8),
            infoChip(
              tipoServicio == 'Fibra Óptica' ? Icons.fiber_smart_record_rounded : Icons.cell_tower_rounded,
              _C.purple,
              'Tipo de servicio',
              tipoServicio,
            ),
          ] else ...[
            // ── EDICIÓN ──
            drop<String>(
                label: 'STARLINK',
                icon: Icons.satellite_alt_rounded,
                color: _C.primary,
                value: _selStarlinkId,
                items: _starlinks.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return DropdownMenuItem<String>(
                      value: doc.id, child: dItem(Icons.satellite_alt_rounded, d['nombre'] ?? '', d['ubicacion'] ?? '', _C.primary));
                }).toList(),
                onChanged: (id) {
                  final doc = _starlinks.firstWhere((d) => d.id == id);
                  setState(() {
                    _selStarlinkId = id;
                    _selStarlinkData = doc.data() as Map<String, dynamic>;
                  });
                }),
            const SizedBox(height: 10),
            drop<String>(
                label: 'ANTENA',
                icon: Icons.cell_tower_rounded,
                color: _C.accent,
                value: _selAntenaId,
                items: _antenas.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return DropdownMenuItem<String>(
                      value: doc.id, child: dItem(Icons.cell_tower_rounded, '${d['marca']} ${d['modelo']}', 'IP: ${d['ip']}', _C.accent));
                }).toList(),
                onChanged: (id) {
                  final doc = _antenas.firstWhere((d) => d.id == id);
                  setState(() {
                    _selAntenaId = id;
                    _selAntenaData = doc.data() as Map<String, dynamic>;
                  });
                }),
            const SizedBox(height: 10),
            drop<String>(
                label: 'ROUTER',
                icon: Icons.router_rounded,
                color: _C.purple,
                value: _selRouterId,
                items: _routers.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return DropdownMenuItem<String>(
                      value: doc.id, child: dItem(Icons.router_rounded, '${d['marca']} ${d['modelo']}', 'IP: ${d['ip']}', _C.purple));
                }).toList(),
                onChanged: (id) {
                  final doc = _routers.firstWhere((d) => d.id == id);
                  setState(() {
                    _selRouterId = id;
                    _selRouterData = doc.data() as Map<String, dynamic>;
                  });
                }),
            const SizedBox(height: 10),

            // ── NUEVO: dropdown dinámico de planes ──
            _buildPlanDropdown(),
            const SizedBox(height: 10),

            drop<String>(
                label: 'VELOCIDAD (SUBIDA/BAJADA)',
                icon: Icons.speed_rounded,
                color: _C.warning,
                value: _selVelocidad,
                items: _velocidades.map((v) {
                  final parts = v.split('/');
                  return DropdownMenuItem<String>(
                      value: v, child: dItem(Icons.speed_rounded, v, '↑ ${parts[0]} subida  ·  ↓ ${parts[1]} bajada', _C.warning));
                }).toList(),
                onChanged: (v) => setState(() => _selVelocidad = v)),
            const SizedBox(height: 10),
            drop<String>(
                label: 'TIPO DE SERVICIO',
                icon: Icons.cable_rounded,
                color: _C.purple,
                value: _selTipoServicio,
                items: _tiposServicio.map((t) {
                  final icon = t == 'Fibra Óptica' ? Icons.fiber_smart_record_rounded : Icons.cell_tower_rounded;
                  final sub = t == 'Fibra Óptica' ? 'Conexión por fibra óptica' : 'Enlace punto a punto';
                  return DropdownMenuItem<String>(value: t, child: dItem(icon, t, sub, _C.purple));
                }).toList(),
                onChanged: (v) => setState(() => _selTipoServicio = v)),
            const SizedBox(height: 16),

            // Botón guardar
            SizedBox(
              width: double.infinity,
              height: 50,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                    gradient: _guardando ? null : const LinearGradient(colors: [_C.primary, _C.accent]),
                    color: _guardando ? _C.border : null,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow:
                        _guardando ? [] : [BoxShadow(color: _C.primary.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 5))]),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _guardando ? null : () => _guardarTodo(c, raw),
                    borderRadius: BorderRadius.circular(14),
                    child: Center(
                        child: _guardando
                            ? Row(mainAxisSize: MainAxisSize.min, children: [
                                SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(_C.textSec))),
                                const SizedBox(width: 10),
                                Text('Guardando...',
                                    style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 14, fontWeight: FontWeight.w600)),
                              ])
                            : Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text('Guardar todos los cambios',
                                    style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                              ])),
                  ),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
