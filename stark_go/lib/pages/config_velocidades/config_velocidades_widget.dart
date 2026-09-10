import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────
//  PALETA
// ─────────────────────────────────────────────
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
  static const Color cardBorder = Color(0xFFE2E8F0);
}

// ─────────────────────────────────────────────
//  ESTRUCTURA FIRESTORE
//  colección: "velocidades"
//  documento: velocidades/{uid}
//  campos:    { uid, lista: ["2M/10M","512k/2M",...], actualizadoEn }
// ─────────────────────────────────────────────
class ConfigVelocidadesWidget extends StatefulWidget {
  const ConfigVelocidadesWidget({super.key});

  static String routeName = 'ConfigVelocidades';
  static String routePath = 'config-velocidades';

  @override
  State<ConfigVelocidadesWidget> createState() => _ConfigVelocidadesWidgetState();
}

class _ConfigVelocidadesWidgetState extends State<ConfigVelocidadesWidget> {
  // ── colección dedicada por usuario ──────────
  static const String _kCol = 'velocidades'; // velocidades/{uid}

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  List<String> _velocidades = [];
  bool _cargando = true;
  bool _guardando = false;

  final _ctrlSubida = TextEditingController();
  final _ctrlBajada = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ── Ráfagas (Burst) que se enviarán a las Simple Queues ──
  // Valores por defecto sugeridos (los que ya tenés en el router):
  //   Bajada: burst-limit 6M · umbral 1.5M
  //   Subida: burst-limit 2M · umbral 768k
  //   Tiempo de ráfaga: 8 s
  static const String _kBlBajada = '6M';
  static const String _kBlSubida = '2M';
  static const String _kUbBajada = '1.5M';
  static const String _kUbSubida = '768k';
  static const String _kTiempo = '8';

  bool _aplicarBurst = true;
  final _ctrlBlBajada = TextEditingController(text: _kBlBajada); // burst-limit ↓
  final _ctrlBlSubida = TextEditingController(text: _kBlSubida); // burst-limit ↑
  final _ctrlUbBajada = TextEditingController(text: _kUbBajada); // burst-threshold ↓
  final _ctrlUbSubida = TextEditingController(text: _kUbSubida); // burst-threshold ↑
  final _ctrlTiempo = TextEditingController(text: _kTiempo); // burst-time (s)

  /// Perfil de ráfaga armado con los textfields (usa los defaults si están vacíos).
  /// Se guarda POR CADA VELOCIDAD (individual), no para todas las colas.
  Map<String, String> get _perfilCampos => {
        'burstBajada': _ctrlBlBajada.text.trim().toUpperCase().isEmpty ? _kBlBajada : _ctrlBlBajada.text.trim().toUpperCase(),
        'burstSubida': _ctrlBlSubida.text.trim().toUpperCase().isEmpty ? _kBlSubida : _ctrlBlSubida.text.trim().toUpperCase(),
        'umbralBajada': _ctrlUbBajada.text.trim().toUpperCase().isEmpty ? _kUbBajada : _ctrlUbBajada.text.trim().toUpperCase(),
        'umbralSubida': _ctrlUbSubida.text.trim().toUpperCase().isEmpty ? _kUbSubida : _ctrlUbSubida.text.trim().toUpperCase(),
        'tiempo': _ctrlTiempo.text.trim().isEmpty ? _kTiempo : _ctrlTiempo.text.trim(),
      };

  /// Ráfagas guardadas por velocidad: `perfiles: { "SUBIDA/BAJADA": {...} }`.
  final Map<String, Map<String, String>> _perfiles = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _ctrlSubida.dispose();
    _ctrlBajada.dispose();
    _ctrlBlBajada.dispose();
    _ctrlBlSubida.dispose();
    _ctrlUbBajada.dispose();
    _ctrlUbSubida.dispose();
    _ctrlTiempo.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────
  //  FIRESTORE — lee velocidades/{uid}
  // ──────────────────────────────────────────
  Future<void> _cargar() async {
    if (_uid.isEmpty) {
      setState(() => _cargando = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection(_kCol).doc(_uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        final raw = data['lista'];
        final perfiles = data['perfiles'];
        setState(() {
          _velocidades = raw is List ? List<String>.from(raw.map((e) => e.toString())) : [];
          _perfiles.clear();
          if (perfiles is Map<String, dynamic>) {
            perfiles.forEach((k, v) {
              if (v is Map) {
                _perfiles[k.toString()] =
                    Map<String, String>.fromEntries(v.entries.map((e) => MapEntry(e.key.toString(), e.value.toString())));
              }
            });
          }
        });
      }
    } catch (e) {
      debugPrint('[StarkGo] Error cargando velocidades: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ── guarda/sobreescribe velocidades/{uid} ──
  Future<void> _guardar() async {
    if (_uid.isEmpty || _guardando) return;
    setState(() => _guardando = true);
    try {
      // Ráfaga individual por velocidad: las velocidades nuevas guardan la suya
      // al agregarse; las viejas (sin perfil) se rellenan con los valores
      // actuales de los campos la primera vez que se toca Guardar.
      final perfilesGuardar = <String, Map<String, String>>{};
      if (_aplicarBurst) {
        for (final v in _velocidades) {
          perfilesGuardar[v] = _perfiles[v] ?? Map.of(_perfilCampos);
        }
      }
      await FirebaseFirestore.instance.collection(_kCol).doc(_uid).set({
        'uid': _uid,
        'lista': _velocidades,
        'perfiles': perfilesGuardar,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });
      if (mounted) _snack('Velocidades guardadas', _C.success);
    } catch (e) {
      if (mounted) _snack('Error al guardar: $e', _C.danger);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _agregarVelocidad() {
    if (!_formKey.currentState!.validate()) return;
    final subida = _ctrlSubida.text.trim().toUpperCase();
    final bajada = _ctrlBajada.text.trim().toUpperCase();
    final nueva = '$subida/$bajada';

    if (_velocidades.contains(nueva)) {
      _snack('Esa velocidad ya existe', _C.warning);
      return;
    }
    setState(() {
      _velocidades.add(nueva);
      if (_aplicarBurst) {
        // Cada velocidad guarda SU propia ráfaga (individual por cliente).
        _perfiles[nueva] = Map.of(_perfilCampos);
      }
      _ctrlSubida.clear();
      _ctrlBajada.clear();
    });
    FocusScope.of(context).unfocus();
  }

  void _eliminar(int i) {
    final v = _velocidades[i];
    setState(() {
      _velocidades.removeAt(i);
      _perfiles.remove(v);
    });
  }

  void _snack(String msg, Color color) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));

  // ──────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _C.surfaceDim,
        appBar: AppBar(
          backgroundColor: _C.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.textPri, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title:
              Text('Velocidades MikroTik', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 17, fontWeight: FontWeight.w700)),
          centerTitle: false,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(color: _C.cardBorder, height: 1),
          ),
        ),
        body: _cargando
            ? Center(child: CircularProgressIndicator(color: _C.primary, strokeWidth: 2.5))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // ── Header gradient ───────────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_C.primary, _C.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: _C.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.speed_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Velocidades MikroTik',
                              style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                          Text(
                            'Define las velocidades en formato MikroTik.\n'
                            'Ej: 2M/10M  ·  512k/2M  ·  5M/20M',
                            style: GoogleFonts.spaceGrotesk(color: Colors.white70, fontSize: 11, height: 1.4),
                          ),
                        ]),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 12),

                  // ── Info aislamiento por usuario ──────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _C.success.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _C.success.withOpacity(0.25)),
                    ),
                    child: Row(children: [
                      Icon(Icons.person_pin_rounded, color: _C.success, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Estas velocidades son exclusivas de tu cuenta. '
                          'Cada usuario administra las suyas de forma independiente.',
                          style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, height: 1.4),
                        ),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 24),

                  // ── Formulario nueva velocidad ────────────
                  Text('AGREGAR VELOCIDAD',
                      style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                  const SizedBox(height: 10),

                  Form(
                    key: _formKey,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _C.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _C.cardBorder, width: 1.2),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
                      ),
                      child: Column(children: [
                        Row(children: [
                          Expanded(
                              child: _velocityField(
                            controller: _ctrlSubida,
                            label: 'SUBIDA',
                            hint: 'Ej: 2M',
                            icon: Icons.upload_rounded,
                            color: _C.primary,
                          )),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('/', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 22, fontWeight: FontWeight.w700)),
                          ),
                          Expanded(
                              child: _velocityField(
                            controller: _ctrlBajada,
                            label: 'BAJADA',
                            hint: 'Ej: 10M',
                            icon: Icons.download_rounded,
                            color: _C.accent,
                          )),
                        ]),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _C.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                            label: Text('Agregar velocidad',
                                style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                            onPressed: _agregarVelocidad,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _C.primary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _C.primary.withOpacity(0.15)),
                          ),
                          child: Row(children: [
                            Icon(Icons.info_outline_rounded, color: _C.primary, size: 15),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Usa formato MikroTik: k = kilobits, M = megabits.\n'
                                'Ejemplos: 512k · 1M · 2M · 5M · 10M · 20M',
                                style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, height: 1.4),
                              ),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const SizedBox(height: 14),

                  // ── Ráfagas (Burst) para las Simple Queues ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _C.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _C.accent.withOpacity(0.35), width: 1.2),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: _C.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.bolt_rounded, color: Color(0xFF00C6AE), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Ráfaga de la velocidad (individual)',
                                style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13.5, fontWeight: FontWeight.w700)),
                            Text('Se guarda con cada velocidad y se aplica solo a la cola de ese cliente',
                                style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10)),
                          ]),
                        ),
                        Switch(
                          value: _aplicarBurst,
                          onChanged: (v) => setState(() => _aplicarBurst = v),
                          activeTrackColor: _C.accent,
                        ),
                      ]),
                      const SizedBox(height: 6),
                      if (_aplicarBurst) ...[
                        Row(children: [
                          Expanded(child: _burstField(_ctrlBlSubida, 'BURST SUBIDA ↑ (máx)', '2M', Icons.arrow_upward_rounded, _C.primary)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _burstField(_ctrlBlBajada, 'BURST BAJADA ↓ (máx)', '6M', Icons.arrow_downward_rounded, _C.accent)),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: _burstField(_ctrlUbSubida, 'UMBRAL SUBIDA ↑', '768k', Icons.trending_up_rounded, _C.primary)),
                          const SizedBox(width: 10),
                          Expanded(child: _burstField(_ctrlUbBajada, 'UMBRAL BAJADA ↓', '1.5M', Icons.trending_down_rounded, _C.accent)),
                        ]),
                        const SizedBox(height: 10),
                        _burstField(_ctrlTiempo, 'TIEMPO DE RÁFAGA (segundos)', '8', Icons.timer_outlined, _C.warning),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _C.accent.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _C.accent.withOpacity(0.15)),
                          ),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(Icons.info_outline_rounded, color: _C.accent, size: 15),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Al agregar una velocidad se guarda con: burst-limit='
                                '${_perfilCampos['burstBajada']}/${_perfilCampos['burstSubida']} · '
                                'burst-threshold='
                                '${_perfilCampos['umbralBajada']}/${_perfilCampos['umbralSubida']} · '
                                'burst-time=${_perfilCampos['tiempo']}s. '
                                'Así, si creás otro cliente con otra velocidad, cada uno '
                                'recibe la ráfaga de SU velocidad.',
                                style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10.5, height: 1.4),
                              ),
                            ),
                          ]),
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Ráfagas apagadas: las colas se crean solo con el '
                            'max-limit (como hasta ahora).',
                            style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11),
                          ),
                        ),
                    ]),
                  ),

                  // ── Lista configuradas ────────────────────
                  Row(children: [
                    Expanded(
                      child: Text('VELOCIDADES CONFIGURADAS',
                          style:
                              GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _C.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${_velocidades.length}',
                          style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 10),

                  if (_velocidades.isEmpty) _buildEmptyState() else ..._velocidades.asMap().entries.map((e) => _buildTile(e.value, e.key)),

                  const SizedBox(height: 28),

                  // ── Guardar ───────────────────────────────
                  if (_velocidades.isNotEmpty)
                    GestureDetector(
                      onTap: _guardando ? null : _guardar,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _guardando ? [_C.cardBorder, _C.cardBorder] : [_C.primary, _C.accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow:
                              _guardando ? [] : [BoxShadow(color: _C.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: Center(
                          child: _guardando
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Guardar velocidades',
                                      style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                                ]),
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),
                ]),
              ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  WIDGETS HELPERS
  // ──────────────────────────────────────────

  Widget _velocityField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 5),
        child:
            Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      ),
      TextFormField(
        controller: controller,
        textCapitalization: TextCapitalization.characters,
        style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Requerido';
          if (!RegExp(r'^\d+[kKmM]$').hasMatch(v.trim())) {
            return 'Ej: 2M ó 512k';
          }
          return null;
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.5), fontSize: 13),
          prefixIcon: Container(
            margin: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          filled: true,
          fillColor: _C.surfaceDim,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          enabledBorder:
              OutlineInputBorder(borderSide: BorderSide(color: _C.cardBorder, width: 1.2), borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: color, width: 1.8), borderRadius: BorderRadius.circular(12)),
          errorBorder: OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.4), borderRadius: BorderRadius.circular(12)),
          focusedErrorBorder:
              OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.8), borderRadius: BorderRadius.circular(12)),
          errorStyle: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 10),
        ),
      ),
    ]);
  }

  Widget _burstField(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon,
    Color color, {
    bool esTiempo = false,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 5),
        child: Text(label,
            style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
      ),
      TextFormField(
        controller: controller,
        textCapitalization: TextCapitalization.characters,
        keyboardType: esTiempo ? TextInputType.number : TextInputType.text,
        style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14, fontWeight: FontWeight.w700),
        validator: (v) {
          final t = (v ?? '').trim();
          if (t.isEmpty) return null; // vacío → usa el default
          final ok = esTiempo ? RegExp(r'^\d{1,3}$').hasMatch(t) : RegExp(r'^\d+(\.\d+)?[kKmMgG]?$').hasMatch(t);
          if (!ok) return esTiempo ? 'Ej: 8' : 'Ej: 6M / 768k';
          return null;
        },
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.5), fontSize: 12),
          prefixIcon: Container(
            margin: const EdgeInsets.fromLTRB(10, 6, 6, 6),
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 15),
          ),
          filled: true,
          fillColor: _C.surfaceDim,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          enabledBorder:
              OutlineInputBorder(borderSide: BorderSide(color: _C.cardBorder, width: 1.1), borderRadius: BorderRadius.circular(11)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: color, width: 1.6), borderRadius: BorderRadius.circular(11)),
          errorBorder: OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.3), borderRadius: BorderRadius.circular(11)),
          focusedErrorBorder:
              OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.6), borderRadius: BorderRadius.circular(11)),
          errorStyle: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 9.5),
        ),
      ),
    ]);
  }

  Widget _buildTile(String velocidad, int index) {
    final parts = velocidad.split('/');
    final subida = parts.isNotEmpty ? parts[0] : '-';
    final bajada = parts.length > 1 ? parts[1] : '-';
    final pf = _perfiles[velocidad];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.cardBorder, width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _C.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.speed_rounded, color: _C.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(velocidad, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
            Row(children: [
              Icon(Icons.upload_rounded, size: 11, color: _C.primary),
              const SizedBox(width: 3),
              Text('$subida subida', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
              const SizedBox(width: 8),
              Icon(Icons.download_rounded, size: 11, color: _C.accent),
              const SizedBox(width: 3),
              Text('$bajada bajada', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
            ]),
            const SizedBox(height: 3),
            if (pf != null)
              Text(
                'Ráfaga ↑${pf['burstSubida']} ↓${pf['burstBajada']} · '
                'Umbral ↑${pf['umbralSubida']} ↓${pf['umbralBajada']} · ${pf['tiempo']}s',
                style: GoogleFonts.spaceGrotesk(color: _C.success.withOpacity(0.9), fontSize: 9.5, fontWeight: FontWeight.w600),
              )
            else
              Text('Sin ráfaga · la cola se crea solo con max-limit',
                  style: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.7), fontSize: 9.5)),
          ]),
        ),
        GestureDetector(
          onTap: () => _abrirEditarVelocidad(index),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _C.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.edit_outlined, color: Color(0xFF1A73E8), size: 18),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => _confirmarEliminar(index, velocidad),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _C.danger.withOpacity(0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: _C.danger, size: 18),
          ),
        ),
      ]),
    );
  }

  Future<void> _abrirEditarVelocidad(int index) async {
    final actual = _velocidades[index];
    final perfil = _perfiles[actual];
    final p = actual.split('/');
    final cSub = TextEditingController(text: p.isNotEmpty ? p[0].trim() : '');
    final cBaj = TextEditingController(text: p.length > 1 ? p[1].trim() : '');
    final cBlS = TextEditingController(text: perfil?['burstSubida'] ?? _kBlSubida);
    final cBlB = TextEditingController(text: perfil?['burstBajada'] ?? _kBlBajada);
    final cUbS = TextEditingController(text: perfil?['umbralSubida'] ?? _kUbSubida);
    final cUbB = TextEditingController(text: perfil?['umbralBajada'] ?? _kUbBajada);
    final cT = TextEditingController(text: perfil?['tiempo'] ?? _kTiempo);
    final fk = GlobalKey<FormState>();
    bool aplicar = perfil != null && _aplicarBurst;
    void disposeC() {
      cSub.dispose();
      cBaj.dispose();
      cBlS.dispose();
      cBlB.dispose();
      cUbS.dispose();
      cUbB.dispose();
      cT.dispose();
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Editar velocidad', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Form(
              key: fk,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                      child: _velocityField(
                          controller: cSub, label: 'SUBIDA', hint: '2M', icon: Icons.arrow_upward_rounded, color: _C.primary)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _velocityField(
                          controller: cBaj, label: 'BAJADA', hint: '6M', icon: Icons.arrow_downward_rounded, color: _C.accent)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFF22C55E), size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text('Ráfaga de esta velocidad',
                          style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 12.5, fontWeight: FontWeight.w700))),
                  Switch(
                      value: _aplicarBurst && aplicar,
                      onChanged: _aplicarBurst ? (v) => setSt(() => aplicar = v) : null,
                      activeTrackColor: _C.accent),
                ]),
                if (!_aplicarBurst)
                  Text('El switch general de ráfagas está apagado.', style: GoogleFonts.spaceGrotesk(color: _C.warning, fontSize: 10.5)),
                if (aplicar) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _burstField(cBlS, 'BURST SUBIDA ↑ (máx)', '2M', Icons.arrow_upward_rounded, _C.primary)),
                    const SizedBox(width: 10),
                    Expanded(child: _burstField(cBlB, 'BURST BAJADA ↓ (máx)', '6M', Icons.arrow_downward_rounded, _C.accent)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _burstField(cUbS, 'UMBRAL SUBIDA ↑', '768k', Icons.trending_up_rounded, _C.primary)),
                    const SizedBox(width: 10),
                    Expanded(child: _burstField(cUbB, 'UMBRAL BAJADA ↓', '1.5M', Icons.trending_down_rounded, _C.accent)),
                  ]),
                  const SizedBox(height: 8),
                  _burstField(cT, 'TIEMPO DE RÁFAGA (segundos)', '8', Icons.timer_outlined, _C.warning, esTiempo: true),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _C.primary, elevation: 0),
              onPressed: () {
                if (fk.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) {
      disposeC();
      return;
    }

    final nS = cSub.text.trim().toUpperCase();
    final nB = cBaj.text.trim().toUpperCase();
    final nueva = '$nS/$nB';
    if (nS.isEmpty || nB.isEmpty) {
      _snack('Completa SUBIDA y BAJADA', _C.warning);
      disposeC();
      return;
    }
    if (nueva != actual && _velocidades.contains(nueva)) {
      _snack('Esa velocidad ya existe', _C.warning);
      disposeC();
      return;
    }

    setState(() {
      _velocidades[index] = nueva;
      _perfiles.remove(actual);
      if (aplicar) {
        _perfiles[nueva] = {
          'burstSubida': cBlS.text.trim().toUpperCase().isEmpty ? _kBlSubida : cBlS.text.trim().toUpperCase(),
          'burstBajada': cBlB.text.trim().toUpperCase().isEmpty ? _kBlBajada : cBlB.text.trim().toUpperCase(),
          'umbralSubida': cUbS.text.trim().toUpperCase().isEmpty ? _kUbSubida : cUbS.text.trim().toUpperCase(),
          'umbralBajada': cUbB.text.trim().toUpperCase().isEmpty ? _kUbBajada : cUbB.text.trim().toUpperCase(),
          'tiempo': cT.text.trim().isEmpty ? _kTiempo : cT.text.trim(),
        };
      }
    });
    disposeC();
    _snack('Velocidad actualizada', _C.success);
  }

  void _confirmarEliminar(int index, String velocidad) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Eliminar velocidad', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
        content: RichText(
          text: TextSpan(
            style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14),
            children: [
              const TextSpan(text: '¿Eliminar '),
              TextSpan(text: velocidad, style: const TextStyle(color: _C.danger, fontWeight: FontWeight.w700)),
              const TextSpan(text: '?\n\nLos clientes con esta velocidad asignada no se verán afectados.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _C.textSec)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              _eliminar(index);
            },
            child: Text('Eliminar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.warning.withOpacity(0.4), width: 1.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _C.warning.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.speed_rounded, color: _C.warning, size: 32),
        ),
        const SizedBox(height: 14),
        Text('Sin velocidades configuradas', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          'Agrega las velocidades que usas en MikroTik\n'
          'para que aparezcan al crear o editar un cliente.',
          style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}
