import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:stark_go/pages/config_facturacion/config_facturacion_widget.dart';
import 'package:stark_go/pages/config_evolution_api/config_evolution_api_widget.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:text_search/text_search.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'listaclientes_model.dart';
export 'listaclientes_model.dart';

// ─────────────────────────────────────────────
//  PALETA
// ─────────────────────────────────────────────
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
  static const Color whatsapp = Color(0xFF25D366);
  static const Color purple = Color(0xFF7C3AED);
}

// ─────────────────────────────────────────────
//  HELPERS DE ESTADO
// ─────────────────────────────────────────────
Color _statusColor(String status) {
  switch (status) {
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

String _statusLabel(String status) {
  switch (status) {
    case 'activo':
      return 'Activo';
    case 'mora':
      return 'Mora';
    case 'inactivo':
      return 'Inactivo';
    default:
      return status;
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'activo':
      return Icons.wifi_rounded;
    case 'mora':
      return Icons.warning_rounded;
    case 'inactivo':
      return Icons.wifi_off_rounded;
    default:
      return Icons.help_outline;
  }
}

// ─────────────────────────────────────────────
//  MODELO EVOLUTION INSTANCE
// ─────────────────────────────────────────────
class _EvolutionInstance {
  final String serverUrl;
  final String instanceName;
  final String apiKey;
  final String phone;
  final String status;

  const _EvolutionInstance({
    required this.serverUrl,
    required this.instanceName,
    required this.apiKey,
    required this.phone,
    required this.status,
  });

  bool get isConnected => status == 'connected' || status == 'open';
}

// ─────────────────────────────────────────────
//  CARD DE CLIENTE (widget reutilizable) — FIXED
// ─────────────────────────────────────────────
class _ClientCard extends StatelessWidget {
  final ClientesRecord cliente;
  final VoidCallback onTap;
  final Future<void> Function() onWhatsapp;
  final Future<void> Function() onDelete;
  final int index;

  const _ClientCard({
    required this.cliente,
    required this.onTap,
    required this.onWhatsapp,
    required this.onDelete,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final inicial = cliente.nombre.isNotEmpty ? cliente.nombre[0].toUpperCase() : '?';
    final statusColor = _statusColor(cliente.status);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Avatar con inicial ──
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        statusColor.withOpacity(0.85),
                        statusColor.withOpacity(0.45),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      inicial,
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // ── Info principal ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre
                      Text(
                        '${cliente.nombre} ${cliente.apellido}',
                        style: GoogleFonts.spaceGrotesk(
                          color: _C.textPri,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      // Finca
                      Row(
                        children: [
                          Icon(Icons.agriculture_rounded, color: _C.accent, size: 12),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              cliente.nombrefinca,
                              style: GoogleFonts.spaceGrotesk(
                                color: _C.textSec,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Teléfono
                      Row(
                        children: [
                          Icon(Icons.phone_rounded, color: _C.primary, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            cliente.numero.toString(),
                            style: GoogleFonts.spaceGrotesk(
                              color: _C.textSec,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // IP (línea separada → evita overflow)
                      Row(
                        children: [
                          Icon(Icons.router_rounded, color: _C.purple, size: 12),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              cliente.ipatn,
                              style: GoogleFonts.spaceGrotesk(
                                color: _C.textSec,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // ── Columna derecha: status + acciones ──
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Badge de estado
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon(cliente.status), color: statusColor, size: 10),
                          const SizedBox(width: 3),
                          Text(
                            _statusLabel(cliente.status),
                            style: GoogleFonts.spaceGrotesk(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Botón WhatsApp
                    GestureDetector(
                      onTap: onWhatsapp,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: _C.whatsapp,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 11),
                            const SizedBox(width: 4),
                            Text(
                              'WA',
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    // CC + botón eliminar
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'CC ${cliente.cc}',
                          style: GoogleFonts.spaceGrotesk(
                            color: _C.textSec,
                            fontSize: 9,
                          ),
                        ),
                        const SizedBox(width: 5),
                        GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: _C.danger.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.delete_outline_rounded, color: _C.danger, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: (index * 40).ms).slideY(begin: 0.04, end: 0);
  }
}

// ─────────────────────────────────────────────
//  MAIN WIDGET
// ─────────────────────────────────────────────
class ListaclientesWidget extends StatefulWidget {
  const ListaclientesWidget({super.key});

  static String routeName = 'listaclientes';
  static String routePath = 'listaclientes';

  @override
  State<ListaclientesWidget> createState() => _ListaclientesWidgetState();
}

class _ListaclientesWidgetState extends State<ListaclientesWidget> {
  late ListaclientesModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchCtrl = TextEditingController();

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  List<ClientesRecord> _searchResults = [];
  bool _isSearching = false;

  // ── Config facturación + empresa ──────────
  int _diaVencimiento = 0;
  bool _facturacionCargada = false;
  String _nombreEmpresa = 'StarkGo';
  String _nombreTitular = '';
  String _numeroNequi = '';
  String _whatsappSoporte = '';
  String _horarioSoporte = 'Lunes a viernes · 8am – 5pm';
  String _msgRecordatorio = '';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ListaclientesModel());
    _model.textController ??= _searchCtrl;
    _model.textFieldFocusNode ??= FocusNode();
    _cargarConfigFacturacion();
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _model.dispose();
    super.dispose();
  }

  // ── Cargar config_empresa ─────────────────
  Future<void> _cargarConfigFacturacion() async {
    if (_uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('config_empresa').doc(_uid).get();
      if (doc.exists && mounted) {
        final d = doc.data() as Map<String, dynamic>;
        setState(() {
          _diaVencimiento = (d['diaVencimiento'] as int?) ?? 0;
          _nombreEmpresa = (d['nombreEmpresa'] ?? 'StarkGo').toString();
          _nombreTitular = (d['nombreTitular'] ?? '').toString();
          _numeroNequi = (d['numeroNequi'] ?? '').toString();
          _whatsappSoporte = (d['whatsappSoporte'] ?? '').toString();
          _horarioSoporte = (d['horarioSoporte'] ?? 'Lunes a viernes · 8am – 5pm').toString();
          _msgRecordatorio = (d['msgRecordatorio'] ?? '').toString();
          _facturacionCargada = true;
        });
      } else {
        if (mounted) setState(() => _facturacionCargada = true);
      }
    } catch (e) {
      debugPrint('[StarkGo] Error leyendo config_empresa: $e');
      if (mounted) setState(() => _facturacionCargada = true);
    }
  }

  // ── Obtener instancia Evolution API ───────
  Future<_EvolutionInstance?> _obtenerInstanciaEvolution() async {
    if (_uid.isEmpty) return null;
    try {
      final snap = await FirebaseFirestore.instance.collection('whatsapp_instances').where('uid', isEqualTo: _uid).limit(1).get();
      if (snap.docs.isEmpty) return null;
      final d = snap.docs.first.data();
      return _EvolutionInstance(
        serverUrl: d['serverUrl'] ?? '',
        instanceName: d['instanceName'] ?? '',
        apiKey: d['apiKey'] ?? '',
        phone: d['phone'] ?? '',
        status: d['status'] ?? '',
      );
    } catch (e) {
      debugPrint('[StarkGo] Error leyendo whatsapp_instances: $e');
      return null;
    }
  }

  // ── Normalizar número colombiano ──────────
  String _normalizarNumero(dynamic raw) {
    if (raw == null) return '';
    String num = raw.toString().replaceAll(RegExp(r'[^0-9]'), '');
    if (num.isEmpty || num.length < 10) return '';
    if (num.length > 10) return num;
    return '57$num';
  }

  // ── Formatear pesos colombianos ───────────
  String _formatearPesos(double valor) {
    final partes = valor.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    int count = 0;
    for (int i = partes.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(partes[i]);
      count++;
    }
    return '\$ ${buffer.toString().split('').reversed.join('')}';
  }

  // ── Plan del cliente de forma segura ──────
  double _getPlanCliente(ClientesRecord cliente) {
    try {
      // Intenta primero planValor (igual que home)
      final dynamic planV = cliente.planValor;
      if (planV != null) {
        if (planV is double) return planV;
        if (planV is int) return planV.toDouble();
        if (planV is num) return planV.toDouble();
        final cleaned = planV.toString().replaceAll('.', '').replaceAll(',', '').trim();
        return double.tryParse(cleaned) ?? 50000.0;
      }
      // Fallback a planCliente
      final dynamic plan = cliente.planCliente;
      if (plan == null) return 50000.0;
      if (plan is double) return plan;
      if (plan is int) return plan.toDouble();
      if (plan is num) return plan.toDouble();
      return double.tryParse(plan.toString()) ?? 50000.0;
    } catch (_) {
      return 50000.0;
    }
  }

  // ══════════════════════════════════════════
  //  ENVIAR WHATSAPP — Evolution API
  //  (lógica idéntica a home_widget)
  // ══════════════════════════════════════════
  Future<void> _enviarWhatsapp(ClientesRecord c) async {
    if (_diaVencimiento == 0) {
      _showFechaNoConfiguradaDialog();
      return;
    }

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Reporte de Pago', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
            content: Text('¿Enviar recordatorio de pago a ${c.nombre} vía WhatsApp?', style: GoogleFonts.spaceGrotesk()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _C.textSec)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.whatsapp,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Enviar', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok || !mounted) return;

    // Loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: _C.whatsapp, strokeWidth: 2.5),
            const SizedBox(height: 14),
            Text('Enviando mensaje…', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14)),
          ]),
        ),
      ),
    );

    _EvolutionInstance? instancia;
    try {
      instancia = await _obtenerInstanciaEvolution();
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showErrorDialog('Error de conexión', 'No se pudo consultar la configuración de WhatsApp.\n\nDetalle: $e');
      return;
    }

    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    if (instancia == null) {
      _showNoInstanceDialog();
      return;
    }
    if (!instancia.isConnected) {
      _showErrorDialog('WhatsApp desconectado', 'Tu instancia (${instancia.instanceName}) no está conectada.\nEstado: ${instancia.status}');
      return;
    }

    final String numeroDestino = _normalizarNumero(c.numero);
    if (numeroDestino.isEmpty) {
      _showErrorDialog('Número inválido', 'El cliente no tiene un número válido registrado.');
      return;
    }

    // ── Estado dinámico según día de vencimiento ──
    final now = DateTime.now();
    final diasParaVencer = _diaVencimiento - now.day;
    String estado;
    if (diasParaVencer == 0) {
      estado = '🔴 *Estado:* Vence HOY';
    } else if (diasParaVencer == 1) {
      estado = '🔴 *Estado:* Vence mañana, día $_diaVencimiento';
    } else if (diasParaVencer > 1) {
      estado = '🟡 *Estado:* Vence en $diasParaVencer días (día $_diaVencimiento)';
    } else {
      estado = '🔴 *Estado:* Venció el día $_diaVencimiento (${diasParaVencer.abs()} días de retraso)';
    }

    final valorFmt = _formatearPesos(_getPlanCliente(c));

    // ── Construir mensaje desde plantilla (o fallback) ──
    String mensaje;
    if (_msgRecordatorio.trim().isEmpty) {
      mensaje = '📢 *$_nombreEmpresa — Recordatorio de Pago*\n\n'
          'Hola *${c.nombre}*, te recordamos que tu factura vence el día '
          '$_diaVencimiento del mes.\n\n'
          '💳 *Valor:* $valorFmt\n'
          '$estado\n\n'
          '💜 Nequi: $_numeroNequi · $_nombreTitular\n'
          'Soporte: $_whatsappSoporte\n$_horarioSoporte\n\n'
          '— *Equipo $_nombreEmpresa* 🌐';
    } else {
      mensaje = _msgRecordatorio
          .replaceAll('{nombre}', c.nombre)
          .replaceAll('{plan}', '')
          .replaceAll('{valor}', valorFmt)
          .replaceAll('{dia}', '$_diaVencimiento')
          .replaceAll('{estado}', estado)
          .replaceAll('{empresa}', _nombreEmpresa)
          .replaceAll('{nequi}', _numeroNequi)
          .replaceAll('{titular}', _nombreTitular)
          .replaceAll('{soporte}', _whatsappSoporte)
          .replaceAll('{horario}', _horarioSoporte);
    }

    // ── POST a Evolution API ──
    try {
      final url = Uri.parse('${instancia.serverUrl}/message/sendText/${instancia.instanceName}');
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'apikey': instancia.apiKey,
            },
            body: jsonEncode({'number': numeroDestino, 'text': mensaje}),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessDialog(c.nombre, numeroDestino);
      } else {
        String detalle = '';
        try {
          final body = jsonDecode(response.body);
          detalle = body['message'] ?? body['error'] ?? response.body;
        } catch (_) {
          detalle = response.body;
        }
        _showErrorDialog('Error al enviar (${response.statusCode})', 'No se pudo enviar el mensaje.\n\nDetalle: $detalle');
      }
    } on Exception catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error de red', 'No se pudo conectar con Evolution API.\n\nDetalle: $e');
    }
  }

  // ── Eliminar cliente ──────────────────────
  Future<void> _eliminar(ClientesRecord c) async {
    final ok = await _confirm('Eliminar Cliente', '¿Desea eliminar a ${c.nombre} ${c.apellido}?');
    if (ok) await c.reference.delete();
  }

  // ── Navegar a detalle ─────────────────────
  void _verDetalle(ClientesRecord c) {
    context.pushNamed(
      DetalleClienteWidget.routeName,
      queryParameters: {
        'rf': serializeParam(c.reference, ParamType.DocumentReference),
      }.withoutNulls,
    );
  }

  // ── Búsqueda con debounce ─────────────────
  void _onSearchChanged(String query, List<ClientesRecord> allClients) {
    EasyDebounce.debounce(
      'lista_search',
      const Duration(milliseconds: 400),
      () {
        if (query.trim().isEmpty) {
          setState(() {
            _isSearching = false;
            _searchResults = [];
          });
          return;
        }
        final results = TextSearch(
          allClients
              .map((r) => TextSearchItem.fromTerms(r, [
                    r.nombre,
                    r.apellido,
                    r.nombrefinca,
                    r.ipatn,
                  ]))
              .toList(),
        ).search(query).map((r) => r.object).toList();

        setState(() {
          _isSearching = true;
          _searchResults = results;
        });
      },
    );
  }

  void _clearSearch() {
    _searchCtrl.clear();
    EasyDebounce.cancel('lista_search');
    setState(() {
      _isSearching = false;
      _searchResults = [];
    });
  }

  // ── Diálogo de confirmación genérico ──────
  Future<bool> _confirm(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(title, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
            content: Text(content, style: GoogleFonts.spaceGrotesk(color: _C.textSec)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('No', style: GoogleFonts.spaceGrotesk(color: _C.textSec)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Sí', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ══════════════════════════════════════════
  //  DIALOGS (idénticos a home_widget)
  // ══════════════════════════════════════════

  void _showFechaNoConfiguradaDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _C.warning.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.calendar_today_rounded, color: _C.warning, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Fecha no configurada', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ]),
        content: Text(
          'Antes de enviar mensajes de pago, configura el día '
          'de vencimiento y los datos de tu empresa.',
          style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _C.textSec)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 16),
            label: Text('Configurar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w600)),
            onPressed: () async {
              Navigator.pop(context);
              await context.pushNamed(ConfigFacturacionWidget.routeName);
              _cargarConfigFacturacion();
            },
          ),
        ],
      ),
    );
  }

  void _showNoInstanceDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _C.warning.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.chat_bubble_outline_rounded, color: _C.warning, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('WhatsApp no configurado', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ]),
        content: Text(
          'No tienes una instancia de Evolution API registrada.\n\n'
          'Configura WhatsApp para poder enviar mensajes.',
          style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _C.textSec)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.whatsapp,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 16),
            label: Text('Configurar ahora', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w600)),
            onPressed: () {
              Navigator.pop(context);
              context.pushNamed(ConfigEvolutionApiWidget.routeName);
            },
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String nombre, String numero) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _C.success.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(FontAwesomeIcons.whatsapp, color: _C.whatsapp, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('¡Mensaje enviado!', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('El recordatorio fue enviado exitosamente.', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _C.success.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.success.withOpacity(0.2)),
            ),
            child: Row(children: [
              Icon(Icons.person_rounded, size: 16, color: _C.success),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(nombre, style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('+$numero', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
                ]),
              ),
              Icon(Icons.check_circle_rounded, color: _C.success, size: 20),
            ]),
          ),
        ]),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.success,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text('Perfecto', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String titulo, String mensaje) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _C.danger.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.error_outline_rounded, color: _C.danger, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(titulo, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ]),
        content: Text(mensaje, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13, height: 1.5)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text('Entendido', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClientesRecord>>(
      stream: queryClientesRecord(
        queryBuilder: (q) => q.where(
          'propietarioUid',
          isEqualTo: _uid,
        ),
        limit: 50,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: _C.surfaceDim,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(_C.primary),
                    strokeWidth: 2.5,
                  ),
                  const SizedBox(height: 14),
                  Text('Cargando clientes…', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 13)),
                ],
              ),
            ),
          );
        }

        final allClients = snapshot.data!;
        final displayList = _isSearching ? _searchResults : allClients;

        final activos = allClients.where((c) => c.status == 'activo').length;
        final mora = allClients.where((c) => c.status == 'mora').length;
        final inactivos = allClients.where((c) => c.status == 'inactivo').length;

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: _C.surfaceDim,
            body: SafeArea(
              child: Column(
                children: [
                  _buildTopBar(context),
                  _buildStats(allClients.length, activos, mora, inactivos).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, end: 0),
                  _buildSearchBar(allClients),
                  Expanded(
                    child: displayList.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: const EdgeInsets.only(top: 8, bottom: 20),
                            itemCount: displayList.length,
                            itemBuilder: (context, i) {
                              final c = displayList[i];
                              return _ClientCard(
                                cliente: c,
                                index: i,
                                onTap: () => _verDetalle(c),
                                onWhatsapp: () => _enviarWhatsapp(c),
                                onDelete: () => _eliminar(c),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────
  //  TOP BAR
  // ─────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.safePop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.textPri, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lista de Clientes',
                  style: GoogleFonts.spaceGrotesk(
                    color: _C.textPri,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Gestiona y contacta tus clientes',
                  style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  STATS MINI
  // ─────────────────────────────────────────
  Widget _buildStats(int total, int activos, int mora, int inactivos) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_C.dark, Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatChip(label: 'Total', value: total, color: _C.primary),
            _Divider(),
            _StatChip(label: 'Activos', value: activos, color: _C.success),
            _Divider(),
            _StatChip(label: 'Mora', value: mora, color: _C.danger),
            _Divider(),
            _StatChip(label: 'Inactivos', value: inactivos, color: _C.warning),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  SEARCH BAR
  // ─────────────────────────────────────────
  Widget _buildSearchBar(List<ClientesRecord> allClients) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isSearching ? _C.primary.withOpacity(0.5) : _C.border,
            width: _isSearching ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(
              Icons.search_rounded,
              color: _isSearching ? _C.primary : _C.textSec,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                focusNode: _model.textFieldFocusNode,
                onChanged: (q) => _onSearchChanged(q, allClients),
                style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, finca o IP...',
                  hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.6), fontSize: 13),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (_isSearching) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _C.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_searchResults.length}',
                  style: GoogleFonts.spaceGrotesk(
                    color: _C.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _clearSearch,
                child: Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _C.surfaceDim,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close_rounded, color: _C.textSec, size: 16),
                ),
              ),
            ] else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  EMPTY STATE
  // ─────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: _C.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded, color: _C.primary, size: 34),
          ),
          const SizedBox(height: 14),
          Text(
            _isSearching ? 'Sin resultados para esa búsqueda' : 'No hay clientes registrados',
            style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  WIDGETS AUXILIARES
// ─────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: GoogleFonts.spaceGrotesk(color: color, fontSize: 20, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: Colors.white.withOpacity(0.1));
  }
}
