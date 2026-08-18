import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

// ════════════════════════════════════════════════════════════════
//  CONFIG PERFILES — Crear / listar / borrar planes de hotspot
//  Habla con:
//    GET    /hotspot/perfiles?apikey=...            (lista, snapshot del router)
//    POST   /hotspot/perfiles                        (crea/actualiza, se encola)
//    DELETE /hotspot/perfiles/:nombre?apikey=...      (borra, se encola)
// ════════════════════════════════════════════════════════════════

class _VPS {
  static const String url = 'http://5.161.88.42:3000';
}

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

/// Duración en días/horas/minutos/segundos — la misma unidad que usa
/// el backend (segundosDesdeDuracion) para armar el session-timeout.
class DuracionPerfil {
  int dias, horas, minutos, segundos;
  DuracionPerfil({this.dias = 0, this.horas = 0, this.minutos = 0, this.segundos = 0});

  int get totalSegundos => dias * 86400 + horas * 3600 + minutos * 60 + segundos;

  String get etiqueta {
    if (totalSegundos == 0) return 'Sin duración';
    final partes = <String>[];
    if (dias > 0) partes.add('${dias}d');
    if (horas > 0) partes.add('${horas}h');
    if (minutos > 0) partes.add('${minutos}m');
    if (segundos > 0) partes.add('${segundos}s');
    return partes.join(' ');
  }
}

class PerfilHotspot {
  final String nombre;
  final double precio;
  final String rateLimit; // "1M/2M"
  final int sharedUsers;
  final int sessionTimeout; // segundos

  PerfilHotspot({
    required this.nombre,
    required this.precio,
    required this.rateLimit,
    required this.sharedUsers,
    required this.sessionTimeout,
  });

  factory PerfilHotspot.fromJson(Map<String, dynamic> j) {
    // El snapshot que reporta el router trae rate-limit y session-timeout
    // como strings; los demás campos vienen ya calculados/mergeados.
    return PerfilHotspot(
      nombre: (j['name'] ?? j['nombre'] ?? '').toString(),
      precio: (j['precio'] is num) ? (j['precio'] as num).toDouble() : double.tryParse('${j['precio']}') ?? 0,
      rateLimit: (j['rateLimit'] ?? j['rate-limit'] ?? '').toString(),
      sharedUsers: int.tryParse('${j['sharedUsers'] ?? j['shared-users'] ?? 1}') ?? 1,
      sessionTimeout: int.tryParse('${j['sessionTimeout'] ?? j['session-timeout'] ?? 0}') ?? 0,
    );
  }
}

class ConfigPerfilesWidget extends StatefulWidget {
  const ConfigPerfilesWidget({super.key});
  static String routeName = 'ConfigPerfiles';
  static String routePath = 'configPerfiles';

  @override
  State<ConfigPerfilesWidget> createState() => _ConfigPerfilesWidgetState();
}

class _ConfigPerfilesWidgetState extends State<ConfigPerfilesWidget> {
  String? _apikey;
  bool _cargando = true;
  bool _guardando = false;
  List<PerfilHotspot> _perfiles = [];

  // ── Form nuevo perfil ──
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _compartidosCtrl = TextEditingController(text: '1');
  final _velSubidaCtrl = TextEditingController(text: '1M');
  final _velBajadaCtrl = TextEditingController(text: '2M');
  final _duracion = DuracionPerfil(dias: 1); // preset inicial: 1 día

  // Presets rápidos de duración, lo típico en fichas de hotspot
  static final List<MapEntry<String, DuracionPerfil>> _presets = [
    MapEntry('1 hora', DuracionPerfil(horas: 1)),
    MapEntry('3 horas', DuracionPerfil(horas: 3)),
    MapEntry('1 día', DuracionPerfil(dias: 1)),
    MapEntry('7 días', DuracionPerfil(dias: 7)),
    MapEntry('30 días', DuracionPerfil(dias: 30)),
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    _compartidosCtrl.dispose();
    _velSubidaCtrl.dispose();
    _velBajadaCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _cargando = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('config_mikrotik').doc(uid).get();
      _apikey = doc.data()?['vpsApiKey'] as String?;
      if (_apikey != null) await _cargarPerfiles();
    } catch (e) {
      debugPrint('[Perfiles] Error init: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarPerfiles() async {
    if (_apikey == null) return;
    try {
      final res = await http.get(Uri.parse('$_VPS.url/hotspot/perfiles?apikey=$_apikey'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final lista = (data['perfiles'] as List? ?? []).map((p) => PerfilHotspot.fromJson(p as Map<String, dynamic>)).toList();
        if (mounted) setState(() => _perfiles = lista);
      }
    } catch (e) {
      debugPrint('[Perfiles] Error cargando: $e');
    }
  }

  Future<void> _crearPerfil() async {
    if (!_formKey.currentState!.validate() || _apikey == null) return;
    setState(() => _guardando = true);
    try {
      final res = await http.post(
        Uri.parse('$_VPS.url/hotspot/perfiles'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'apikey': _apikey,
          'nombre': _nombreCtrl.text.trim(),
          'precio': double.tryParse(_precioCtrl.text.trim()) ?? 0,
          'usuariosCompartidos': int.tryParse(_compartidosCtrl.text.trim()) ?? 1,
          'velUpl': _velSubidaCtrl.text.trim(),
          'velDow': _velBajadaCtrl.text.trim(),
          'dias': _duracion.dias,
          'horas': _duracion.horas,
          'minutos': _duracion.minutos,
          'segundos': _duracion.segundos,
        }),
      );
      if (res.statusCode == 200) {
        _snack('Perfil encolado — se crea en el router en el próximo ciclo', _C.success);
        _nombreCtrl.clear();
        _precioCtrl.clear();
        // Refrescamos con un pequeño delay; el snapshot tarda hasta el
        // próximo reporte del router (paso 3 de tu config MikroTik).
        await _cargarPerfiles();
      } else {
        final body = jsonDecode(res.body);
        _snack(body['error'] ?? 'Error al crear el perfil', _C.danger);
      }
    } catch (e) {
      _snack('Error de conexión: $e', _C.danger);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _borrarPerfil(String nombre) async {
    if (_apikey == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('¿Borrar "$nombre"?', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
        content: Text(
          'Se eliminará del router en el próximo ciclo. Las fichas ya generadas con este perfil no se borran.',
          style: GoogleFonts.spaceGrotesk(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Borrar', style: GoogleFonts.spaceGrotesk(color: _C.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      final res = await http.delete(Uri.parse('$_VPS.url/hotspot/perfiles/$nombre?apikey=$_apikey'));
      if (res.statusCode == 200) {
        _snack('Perfil "$nombre" encolado para borrar', _C.success);
        setState(() => _perfiles.removeWhere((p) => p.nombre == nombre));
      } else {
        _snack('Error al borrar el perfil', _C.danger);
      }
    } catch (e) {
      _snack('Error de conexión: $e', _C.danger);
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surfaceDim,
      body: SafeArea(
        child: _cargando
            ? Center(child: CircularProgressIndicator(color: _C.primary, strokeWidth: 2.5))
            : _apikey == null
                ? _buildSinConfig()
                : RefreshIndicator(
                    onRefresh: _cargarPerfiles,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: 16),
                        _buildFormNuevoPerfil().animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, end: 0),
                        const SizedBox(height: 18),
                        Text('Perfiles existentes (${_perfiles.length})',
                            style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        if (_perfiles.isEmpty)
                          _buildVacio()
                        else
                          ..._perfiles.asMap().entries.map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildPerfilCard(e.value)
                                    .animate()
                                    .fadeIn(duration: 250.ms, delay: (e.key * 40).ms)
                                    .slideX(begin: 0.03, end: 0),
                              )),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildSinConfig() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.router_rounded, color: _C.textSec, size: 42),
          const SizedBox(height: 12),
          Text('Primero configura tu MikroTik',
              textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Necesitas guardar tu API Key en "Config. MikroTik" antes de crear perfiles.',
              textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
        ]),
      );

  Widget _buildTopBar() => Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))]),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.textPri, size: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Perfiles / Planes', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 20, fontWeight: FontWeight.w800)),
          Text('Duración, precio y velocidad', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
        ])),
      ]);

  Widget _buildVacio() => Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.border)),
        child: Text('Aún no tienes perfiles. Crea el primero arriba.', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
      );

  Widget _buildFormNuevoPerfil() {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _C.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_C.purple, Color(0xFF5B21B6)]), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.add_chart_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Nuevo perfil', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _nombreCtrl,
                style: GoogleFonts.spaceGrotesk(fontSize: 13),
                decoration: _inputDecoration('Nombre (sin espacios)', Icons.label_rounded),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requerido';
                  if (v.contains(' ')) return 'Sin espacios';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _precioCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.spaceGrotesk(fontSize: 13),
                decoration: _inputDecoration('Precio', Icons.attach_money_rounded),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _velSubidaCtrl,
                style: GoogleFonts.spaceGrotesk(fontSize: 13),
                decoration: _inputDecoration('Subida (ej: 1M)', Icons.upload_rounded),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _velBajadaCtrl,
                style: GoogleFonts.spaceGrotesk(fontSize: 13),
                decoration: _inputDecoration('Bajada (ej: 2M)', Icons.download_rounded),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _compartidosCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.spaceGrotesk(fontSize: 13),
                decoration: _inputDecoration('Usuarios', Icons.people_rounded),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Text('DURACIÓN',
              style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((preset) {
              final activo = _duracion.totalSegundos == preset.value.totalSegundos;
              return GestureDetector(
                onTap: () => setState(() {
                  _duracion.dias = preset.value.dias;
                  _duracion.horas = preset.value.horas;
                  _duracion.minutos = preset.value.minutos;
                  _duracion.segundos = preset.value.segundos;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: activo ? _C.primary : _C.surfaceDim,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: activo ? _C.primary : _C.border),
                  ),
                  child: Text(preset.key,
                      style:
                          GoogleFonts.spaceGrotesk(color: activo ? Colors.white : _C.textSec, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _duracionField('Días', _duracion.dias, (v) => setState(() => _duracion.dias = v))),
            const SizedBox(width: 8),
            Expanded(child: _duracionField('Horas', _duracion.horas, (v) => setState(() => _duracion.horas = v))),
            const SizedBox(width: 8),
            Expanded(child: _duracionField('Min', _duracion.minutos, (v) => setState(() => _duracion.minutos = v))),
            const SizedBox(width: 8),
            Expanded(child: _duracionField('Seg', _duracion.segundos, (v) => setState(() => _duracion.segundos = v))),
          ]),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Total: ${_duracion.etiqueta}',
                style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _guardando ? null : _crearPerfil,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _guardando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Crear perfil', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _duracionField(String label, int value, ValueChanged<int> onChanged) {
    final ctrl = TextEditingController(text: '$value');
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: GoogleFonts.spaceGrotesk(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(fontSize: 11, color: _C.textSec),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _C.border)),
      ),
      onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(fontSize: 12, color: _C.textSec),
        prefixIcon: Icon(icon, size: 18, color: _C.textSec),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _C.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _C.primary, width: 1.6)),
      );

  Widget _buildPerfilCard(PerfilHotspot p) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: _C.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.wifi_rounded, color: _C.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.nombre, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('${p.rateLimit} · ${p.sharedUsers} usuario(s) · \$${p.precio.toStringAsFixed(0)}',
                  style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
            ]),
          ),
          IconButton(
            onPressed: () => _borrarPerfil(p.nombre),
            icon: Icon(Icons.delete_outline_rounded, color: _C.danger, size: 20),
          ),
        ]),
      );
}
