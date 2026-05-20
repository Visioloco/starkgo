// ══════════════════════════════════════════════════════════════════
//  lista_starlinks_clientes_widget.dart
//  Gestión de Starlinks de clientes · StarkGo
//  Colección Firebase: starlink_clientes_pago
//  Incluye: registro, WhatsApp (opción 1 profesional), notificaciones locales
// ══════════════════════════════════════════════════════════════════
//
//  DEPENDENCIAS requeridas en pubspec.yaml:
//  flutter_local_notifications: ^17.0.0
//  http: ^1.2.0
//  cloud_firestore: ^4.x
//  firebase_auth: ^4.x
//  google_fonts: ^6.x
//  flutter_animate: ^4.x
//  font_awesome_flutter: ^10.x
//  timezone: ^0.9.0
//
//  PERMISOS Android (AndroidManifest.xml):
//  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
//  <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
//  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
//
//  PERMISOS iOS (Info.plist): No se requieren extras para notificaciones locales
// ══════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// ─────────────────────────────────────────────
//  COLECCIÓN FIREBASE
// ─────────────────────────────────────────────
const String _kColeccion = 'starlink_clientes_pago';

// ─────────────────────────────────────────────
//  PALETA (coherente con home_widget)
// ─────────────────────────────────────────────
class _C {
  static const Color primary = Color(0xFF1A73E8);
  static const Color accent = Color(0xFF00C6AE);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFE53935);
  static const Color purple = Color(0xFF7C3AED);
  static const Color whatsapp = Color(0xFF25D366);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF1F5F9);
  static const Color drawerBg = Color(0xFF0F172A);
  static const Color textPri = Color(0xFF0F172A);
  static const Color textSec = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
}

// ─────────────────────────────────────────────
//  MODELO STARLINK CLIENTE PAGO
// ─────────────────────────────────────────────
class StarlinkClientePago {
  final String id;
  final String nombreCliente;
  final String lugar;
  final int diaVencimiento; // día del mes (1-31)
  final double montoQuePago; // lo que yo pago a Starlink
  final double montoQueCobro; // lo que cobro al cliente
  final String telefono;
  final String estado; // 'al_dia' | 'pendiente' | 'vencido'
  final String propietarioUid;
  final DateTime creadoEn;
  final int diasAvisoPrevio; // cuántos días antes notificar
  final String? notasExtra;

  const StarlinkClientePago({
    required this.id,
    required this.nombreCliente,
    required this.lugar,
    required this.diaVencimiento,
    required this.montoQuePago,
    required this.montoQueCobro,
    required this.telefono,
    required this.estado,
    required this.propietarioUid,
    required this.creadoEn,
    required this.diasAvisoPrevio,
    this.notasExtra,
  });

  factory StarlinkClientePago.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return StarlinkClientePago(
      id: doc.id,
      nombreCliente: d['nombreCliente'] ?? '',
      lugar: d['lugar'] ?? '',
      diaVencimiento: (d['diaVencimiento'] as int?) ?? 1,
      montoQuePago: ((d['montoQuePago'] as num?) ?? 0).toDouble(),
      montoQueCobro: ((d['montoQueCobro'] as num?) ?? 0).toDouble(),
      telefono: d['telefono'] ?? '',
      estado: d['estado'] ?? 'pendiente',
      propietarioUid: d['propietarioUid'] ?? '',
      creadoEn: (d['creadoEn'] as Timestamp?)?.toDate() ?? DateTime.now(),
      diasAvisoPrevio: (d['diasAvisoPrevio'] as int?) ?? 2,
      notasExtra: d['notasExtra'],
    );
  }

  Map<String, dynamic> toMap(String uid) => {
        'nombreCliente': nombreCliente,
        'lugar': lugar,
        'diaVencimiento': diaVencimiento,
        'montoQuePago': montoQuePago,
        'montoQueCobro': montoQueCobro,
        'telefono': telefono,
        'estado': estado,
        'propietarioUid': uid,
        'creadoEn': FieldValue.serverTimestamp(),
        'diasAvisoPrevio': diasAvisoPrevio,
        'notasExtra': notasExtra ?? '',
      };

  Color get estadoColor {
    switch (estado) {
      case 'al_dia':
        return _C.success;
      case 'pendiente':
        return _C.warning;
      case 'vencido':
        return _C.danger;
      default:
        return _C.textSec;
    }
  }

  String get estadoLabel {
    switch (estado) {
      case 'al_dia':
        return 'Al día';
      case 'pendiente':
        return 'Pendiente';
      case 'vencido':
        return 'Vencido';
      default:
        return estado;
    }
  }

  IconData get estadoIcon {
    switch (estado) {
      case 'al_dia':
        return Icons.check_circle_rounded;
      case 'pendiente':
        return Icons.schedule_rounded;
      case 'vencido':
        return Icons.warning_amber_rounded;
      default:
        return Icons.help_outline;
    }
  }
}

// ─────────────────────────────────────────────
//  SERVICIO DE NOTIFICACIONES LOCALES
// ─────────────────────────────────────────────
class _NotifService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    // Inicializar timezone
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// Programa una notificación diaria a las 8am
  /// para recordar cobrar al cliente en la fecha indicada.
  static Future<void> programarRecordatorio({
    required int id,
    required String nombreCliente,
    required int diaVencimiento,
    required int diasAvisoPrevio,
    required double montoQueCobro,
  }) async {
    await init();

    final now = DateTime.now();
    // Calcular el día de aviso para este mes
    var diaAviso = diaVencimiento - diasAvisoPrevio;
    if (diaAviso < 1) diaAviso = 1;

    DateTime fechaNotif = DateTime(now.year, now.month, diaAviso, 8, 0);
    // Si ya pasó este mes, programar para el mes siguiente
    if (fechaNotif.isBefore(now)) {
      final nextMonth = DateTime(now.year, now.month + 1, diaAviso, 8, 0);
      fechaNotif = nextMonth;
    }

    final tzFecha = tz.TZDateTime.from(fechaNotif, tz.local);
    final monto = _formatPesos(montoQueCobro);

    const androidDetails = AndroidNotificationDetails(
      'starlink_cobros',
      'Cobros Starlink',
      channelDescription: 'Recordatorios de cobro a clientes Starlink',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF1A73E8),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      id,
      '📡 Recordatorio de cobro · Starlink',
      '$nombreCliente · $monto · vence el día $diaVencimiento',
      tzFecha,
      details,
      // DESPUÉS
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  static Future<void> cancelar(int id) async {
    await init();
    await _plugin.cancel(id);
  }

  static String _formatPesos(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (c > 0 && c % 3 == 0) buf.write('.');
      buf.write(s[i]);
      c++;
    }
    return '\$ ${buf.toString().split('').reversed.join('')}';
  }
}

// ─────────────────────────────────────────────
//  HELPERS FORMATO
// ─────────────────────────────────────────────
String _fmtPesos(double v) {
  final s = v.toStringAsFixed(0);
  final buf = StringBuffer();
  int c = 0;
  for (int i = s.length - 1; i >= 0; i--) {
    if (c > 0 && c % 3 == 0) buf.write('.');
    buf.write(s[i]);
    c++;
  }
  return '\$ ${buf.toString().split('').reversed.join('')}';
}

String _normalizarTel(String raw) {
  final num = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (num.isEmpty || num.length < 10) return '';
  if (num.length > 10) return num;
  return '57$num';
}

// ─────────────────────────────────────────────
//  TARJETA DE CLIENTE STARLINK
// ─────────────────────────────────────────────
class _StarClientCard extends StatelessWidget {
  final StarlinkClientePago item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function() onWhatsapp;
  final VoidCallback onToggleEstado;

  const _StarClientCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onWhatsapp,
    required this.onToggleEstado,
  });

  @override
  Widget build(BuildContext context) {
    final col = item.estadoColor;
    final ganancia = item.montoQueCobro - item.montoQuePago;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: col.withOpacity(0.35), width: 1.4),
          boxShadow: [BoxShadow(color: col.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          // ── Encabezado ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(children: [
              // Avatar inicial
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [col.withOpacity(0.85), col.withOpacity(0.45)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    item.nombreCliente.isNotEmpty ? item.nombreCliente[0].toUpperCase() : '?',
                    style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    item.nombreCliente,
                    style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 15, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.location_on_rounded, size: 12, color: _C.textSec),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(item.lugar,
                          style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11.5), overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.phone_rounded, size: 12, color: _C.primary),
                    const SizedBox(width: 3),
                    Text(item.telefono, style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 11.5)),
                    const SizedBox(width: 10),
                    Icon(Icons.calendar_today_rounded, size: 11, color: _C.textSec),
                    const SizedBox(width: 3),
                    Text('Vence día ${item.diaVencimiento}', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 11)),
                  ]),
                ]),
              ),
              // Badge estado (tappable para cambiar)
              GestureDetector(
                onTap: onToggleEstado,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: col.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: col.withOpacity(0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(item.estadoIcon, color: col, size: 11),
                    const SizedBox(width: 4),
                    Text(item.estadoLabel, style: GoogleFonts.spaceGrotesk(color: col, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),

          // ── Separador ────────────────────────────
          Divider(color: _C.border, height: 1, indent: 14, endIndent: 14),

          // ── Montos ───────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              _MontoChip(label: 'Yo pago', valor: item.montoQuePago, color: _C.danger),
              const SizedBox(width: 8),
              _MontoChip(label: 'Cobro', valor: item.montoQueCobro, color: _C.primary),
              const SizedBox(width: 8),
              _MontoChip(
                label: 'Ganancia',
                valor: ganancia,
                color: ganancia >= 0 ? _C.success : _C.danger,
              ),
            ]),
          ),

          // ── Aviso notificación ───────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
            child: Row(children: [
              Icon(Icons.notifications_active_rounded, size: 12, color: _C.accent),
              const SizedBox(width: 4),
              Text(
                'Notificación ${item.diasAvisoPrevio} día${item.diasAvisoPrevio != 1 ? 's' : ''} antes',
                style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10.5),
              ),
              if (item.notasExtra != null && item.notasExtra!.isNotEmpty) ...[
                const SizedBox(width: 10),
                Icon(Icons.notes_rounded, size: 12, color: _C.textSec),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(item.notasExtra!,
                      style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10.5), overflow: TextOverflow.ellipsis),
                ),
              ],
            ]),
          ),

          // ── Acciones ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(children: [
              // WhatsApp
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: onWhatsapp,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _C.whatsapp,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text('Cobrar', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Editar
              Expanded(
                child: GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _C.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _C.primary.withOpacity(0.25)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.edit_rounded, color: _C.primary, size: 14),
                      const SizedBox(width: 5),
                      Text('Editar', style: GoogleFonts.spaceGrotesk(color: _C.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Eliminar
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _C.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _C.danger.withOpacity(0.2)),
                  ),
                  child: Icon(Icons.delete_rounded, color: _C.danger, size: 18),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _MontoChip extends StatelessWidget {
  final String label;
  final double valor;
  final Color color;
  const _MontoChip({required this.label, required this.valor, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(children: [
            Text(_fmtPesos(valor),
                style: GoogleFonts.spaceGrotesk(color: color, fontSize: 12, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(label, style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10), textAlign: TextAlign.center),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────
//  RESUMEN SUPERIOR
// ─────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final int total;
  final double totalPago;
  final double totalCobro;
  final int alDia, pendiente, vencido;

  const _SummaryCard({
    required this.total,
    required this.totalPago,
    required this.totalCobro,
    required this.alDia,
    required this.pendiente,
    required this.vencido,
  });

  @override
  Widget build(BuildContext context) {
    final ganancia = totalCobro - totalPago;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_C.primary, _C.accent]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.satellite_alt_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Starlinks de clientes', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            Text('$total registrado${total != 1 ? 's' : ''}', style: GoogleFonts.spaceGrotesk(color: Colors.white38, fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _SumItem(label: 'Pago mensual', valor: _fmtPesos(totalPago), color: _C.danger),
          const SizedBox(width: 8),
          _SumItem(label: 'Cobro mensual', valor: _fmtPesos(totalCobro), color: _C.accent),
          const SizedBox(width: 8),
          _SumItem(label: 'Ganancia total', valor: _fmtPesos(ganancia), color: _C.success),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _EstadoBadge(label: 'Al día', count: alDia, color: _C.success),
          const SizedBox(width: 6),
          _EstadoBadge(label: 'Pendiente', count: pendiente, color: _C.warning),
          const SizedBox(width: 6),
          _EstadoBadge(label: 'Vencido', count: vencido, color: _C.danger),
        ]),
      ]),
    );
  }
}

class _SumItem extends StatelessWidget {
  final String label, valor;
  final Color color;
  const _SumItem({required this.label, required this.valor, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.spaceGrotesk(color: Colors.white38, fontSize: 9.5)),
          Text(valor,
              style: GoogleFonts.spaceGrotesk(color: color, fontSize: 12.5, fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      );
}

class _EstadoBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _EstadoBadge({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('$count $label', style: GoogleFonts.spaceGrotesk(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
      );
}

// ═════════════════════════════════════════════
//  MAIN WIDGET
// ═════════════════════════════════════════════
class ListaStarlinksClientesWidget extends StatefulWidget {
  const ListaStarlinksClientesWidget({super.key});
  static String routeName = 'ListaStarlinksClientes';
  static String routePath = 'listaStarlinksClientes';

  @override
  State<ListaStarlinksClientesWidget> createState() => _ListaStarlinksClientesWidgetState();
}

class _ListaStarlinksClientesWidgetState extends State<ListaStarlinksClientesWidget> {
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Evolution API ─────────────────────────
  String _serverUrl = '';
  String _instanceName = '';
  String _apiKey = '';
  bool _waConectado = false;

  // ── Empresa ───────────────────────────────
  String _nombreEmpresa = 'StarkGo';
  String _nombreTitular = '';
  String _numeroNequi = '3145336101';
  String _whatsappSop = '';
  String _horarioSop = 'Lunes a viernes · 8am – 5pm';

  @override
  void initState() {
    super.initState();
    _NotifService.init();
    _cargarConfigs();
  }

  Future<void> _cargarConfigs() async {
    if (_uid == null) return;
    final res = await Future.wait([
      FirebaseFirestore.instance.collection('config_empresa').doc(_uid).get(),
      FirebaseFirestore.instance.collection('whatsapp_instances').where('uid', isEqualTo: _uid).limit(1).get(),
    ]);

    final empresa = res[0] as DocumentSnapshot;
    final wa = res[1] as QuerySnapshot;

    if (empresa.exists && mounted) {
      final d = empresa.data() as Map<String, dynamic>;
      setState(() {
        _nombreEmpresa = d['nombreEmpresa'] ?? 'StarkGo';
        _nombreTitular = d['nombreTitular'] ?? '';
        _numeroNequi = d['numeroNequi'] ?? '3145336101';
        _whatsappSop = d['whatsappSoporte'] ?? '';
        _horarioSop = d['horarioSoporte'] ?? 'Lunes a viernes · 8am – 5pm';
      });
    }
    if (wa.docs.isNotEmpty && mounted) {
      final d = wa.docs.first.data() as Map<String, dynamic>;
      setState(() {
        _serverUrl = d['serverUrl'] ?? '';
        _instanceName = d['instanceName'] ?? '';
        _apiKey = d['apiKey'] ?? '';
        _waConectado = d['status'] == 'connected' || d['status'] == 'open';
      });
    }
  }

  // ─────────────────────────────────────────
  //  WHATSAPP — Opción 1 (profesional)
  // ─────────────────────────────────────────
  Future<void> _enviarWhatsapp(StarlinkClientePago item) async {
    if (!_waConectado || _serverUrl.isEmpty) {
      _snack('WhatsApp no configurado o desconectado', _C.danger);
      return;
    }
    final numero = _normalizarTel(item.telefono);
    if (numero.isEmpty) {
      _snack('El número de teléfono no es válido', _C.danger);
      return;
    }

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Enviar recordatorio', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
            content: Text(
              '¿Enviar recordatorio de pago a ${item.nombreCliente}?',
              style: GoogleFonts.spaceGrotesk(),
            ),
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

    if (!ok) return;

    _showLoading();

    final now = DateTime.now();
    final diasParaVencer = item.diaVencimiento - now.day;
    final valorFmt = _fmtPesos(item.montoQueCobro);

    String estadoLinea;
    if (diasParaVencer == 0) {
      estadoLinea = '🔴 *Estado:* Tu factura vence *HOY*';
    } else if (diasParaVencer == 1) {
      estadoLinea = '🔴 *Estado:* Tu factura vence *mañana* (día ${item.diaVencimiento})';
    } else if (diasParaVencer > 1) {
      estadoLinea = '🟡 *Estado:* Tu factura vence en *$diasParaVencer días* (día ${item.diaVencimiento})';
    } else {
      estadoLinea = '🔴 *Estado:* Llevas *${diasParaVencer.abs()} días* de retraso (venció el día ${item.diaVencimiento})';
    }

    // ── MENSAJE PROFESIONAL OPCIÓN 1 ─────────
    final mensaje = '''📡 *$_nombreEmpresa — Recordatorio de Pago*

Hola *${item.nombreCliente}*, esperamos que estés muy bien. 😊

Te informamos que el pago de tu servicio *Starlink* está próximo a vencer.

📅 *Fecha límite:* Día ${item.diaVencimiento} de este mes
💰 *Valor a cancelar:* $valorFmt
$estadoLinea

━━━━━━━━━━━━━━━━━
💳 *¿Cómo pagar?*
▸ *Nequi:* $_numeroNequi
▸ *Titular:* $_nombreTitular
━━━━━━━━━━━━━━━━━

✅ Si ya realizaste el pago, por favor *envíanos tu comprobante* o ignora este mensaje.

📲 Soporte: $_whatsappSop
🕐 Horario: $_horarioSop

— *Equipo $_nombreEmpresa* 🌐''';

    try {
      final url = Uri.parse('$_serverUrl/message/sendText/$_instanceName');
      final res = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json', 'apikey': _apiKey},
            body: jsonEncode({'number': numero, 'text': mensaje}),
          )
          .timeout(const Duration(seconds: 20));

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (res.statusCode == 200 || res.statusCode == 201) {
        _snack('✓ Mensaje enviado a ${item.nombreCliente}', _C.success);
      } else {
        _snack('Error al enviar (${res.statusCode})', _C.danger);
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _snack('Error de red: $e', _C.danger);
    }
  }

  // ─────────────────────────────────────────
  //  CRUD
  // ─────────────────────────────────────────
  Future<void> _guardar(StarlinkClientePago item, {String? docId}) async {
    if (_uid == null) return;
    final col = FirebaseFirestore.instance.collection(_kColeccion);

    if (docId == null) {
      // Crear nuevo
      final ref = await col.add(item.toMap(_uid!));
      // Programar notificación local
      await _NotifService.programarRecordatorio(
        id: ref.id.hashCode.abs() % 100000,
        nombreCliente: item.nombreCliente,
        diaVencimiento: item.diaVencimiento,
        diasAvisoPrevio: item.diasAvisoPrevio,
        montoQueCobro: item.montoQueCobro,
      );
      _snack('Starlink registrada y recordatorio programado 🔔', _C.success);
    } else {
      // Actualizar
      await col.doc(docId).update({
        'nombreCliente': item.nombreCliente,
        'lugar': item.lugar,
        'diaVencimiento': item.diaVencimiento,
        'montoQuePago': item.montoQuePago,
        'montoQueCobro': item.montoQueCobro,
        'telefono': item.telefono,
        'estado': item.estado,
        'diasAvisoPrevio': item.diasAvisoPrevio,
        'notasExtra': item.notasExtra ?? '',
      });
      // Re-programar notificación
      await _NotifService.cancelar(docId.hashCode.abs() % 100000);
      await _NotifService.programarRecordatorio(
        id: docId.hashCode.abs() % 100000,
        nombreCliente: item.nombreCliente,
        diaVencimiento: item.diaVencimiento,
        diasAvisoPrevio: item.diasAvisoPrevio,
        montoQueCobro: item.montoQueCobro,
      );
      _snack('Registro actualizado ✓', _C.success);
    }
  }

  Future<void> _eliminar(StarlinkClientePago item) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Eliminar registro', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
            content: Text('¿Eliminar a ${item.nombreCliente} de la lista?', style: GoogleFonts.spaceGrotesk()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: _C.textSec)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.danger,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Eliminar', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;
    await FirebaseFirestore.instance.collection(_kColeccion).doc(item.id).delete();
    await _NotifService.cancelar(item.id.hashCode.abs() % 100000);
    _snack('Registro eliminado', _C.danger);
  }

  Future<void> _toggleEstado(StarlinkClientePago item) async {
    final estados = ['al_dia', 'pendiente', 'vencido'];
    final idx = estados.indexOf(item.estado);
    final siguiente = estados[(idx + 1) % 3];
    await FirebaseFirestore.instance.collection(_kColeccion).doc(item.id).update({'estado': siguiente});
  }

  // ─────────────────────────────────────────
  //  FORMULARIO (Crear / Editar)
  // ─────────────────────────────────────────
  void _abrirFormulario({StarlinkClientePago? editar}) {
    final ctrlNombre = TextEditingController(text: editar?.nombreCliente ?? '');
    final ctrlLugar = TextEditingController(text: editar?.lugar ?? '');
    final ctrlTel = TextEditingController(text: editar?.telefono ?? '');
    final ctrlPago = TextEditingController(text: editar != null ? editar.montoQuePago.toStringAsFixed(0) : '');
    final ctrlCobro = TextEditingController(text: editar != null ? editar.montoQueCobro.toStringAsFixed(0) : '');
    final ctrlNotas = TextEditingController(text: editar?.notasExtra ?? '');
    int diaVenc = editar?.diaVencimiento ?? 1;
    int diasAviso = editar?.diasAvisoPrevio ?? 2;
    String estado = editar?.estado ?? 'pendiente';
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          height: MediaQuery.of(context).size.height * 0.92,
          decoration: const BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(2)),
            ),
            // Título
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_C.primary, _C.accent]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    editar == null ? Icons.satellite_alt_rounded : Icons.edit_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    editar == null ? 'Nueva Starlink de cliente' : 'Editar registro',
                    style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text('Se guarda en: $_kColeccion', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 10)),
                ]),
              ]),
            ),
            Divider(color: _C.border, height: 1),
            // Formulario
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
                child: Form(
                  key: formKey,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Nombre cliente
                    _ModalField(
                        ctrl: ctrlNombre,
                        label: 'Nombre del cliente',
                        hint: 'Ej: Carlos Rodríguez',
                        icon: Icons.person_rounded,
                        color: _C.primary,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
                    const SizedBox(height: 14),

                    // Lugar
                    _ModalField(
                        ctrl: ctrlLugar,
                        label: 'Lugar / Dirección',
                        hint: 'Ej: Vereda El Porvenir',
                        icon: Icons.location_on_rounded,
                        color: _C.accent,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
                    const SizedBox(height: 14),

                    // Teléfono
                    _ModalField(
                        ctrl: ctrlTel,
                        label: 'Teléfono (WhatsApp)',
                        hint: 'Ej: 3001234567',
                        icon: Icons.phone_rounded,
                        color: _C.success,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) => (v == null || v.length < 10) ? 'Mínimo 10 dígitos' : null),
                    const SizedBox(height: 14),

                    // Día vencimiento
                    _LabelAbove(label: 'DÍA DE VENCIMIENTO MENSUAL'),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: _C.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _C.primary.withOpacity(0.5), width: 1.4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: diaVenc,
                              isExpanded: true,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              borderRadius: BorderRadius.circular(14),
                              dropdownColor: _C.surface,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded),
                              items: List.generate(28, (i) => i + 1)
                                  .map((d) => DropdownMenuItem(
                                        value: d,
                                        child: Text('Día $d', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13)),
                                      ))
                                  .toList(),
                              onChanged: (v) => setModal(() => diaVenc = v ?? 1),
                            ),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    // Montos
                    Row(children: [
                      Expanded(
                        child: _ModalField(
                            ctrl: ctrlPago,
                            label: 'Yo pago (COP)',
                            hint: 'Ej: 60000',
                            icon: Icons.arrow_upward_rounded,
                            color: _C.danger,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ModalField(
                            ctrl: ctrlCobro,
                            label: 'Yo cobro (COP)',
                            hint: 'Ej: 90000',
                            icon: Icons.arrow_downward_rounded,
                            color: _C.success,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    // Días aviso previo
                    _LabelAbove(label: 'RECORDATORIO (DÍAS ANTES DEL VENCIMIENTO)'),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: _C.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _C.accent.withOpacity(0.5), width: 1.4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: diasAviso,
                          isExpanded: true,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          borderRadius: BorderRadius.circular(14),
                          dropdownColor: _C.surface,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          items: [1, 2, 3, 5, 7]
                              .map((d) => DropdownMenuItem(
                                    value: d,
                                    child: Row(children: [
                                      Icon(Icons.notifications_active_rounded, size: 14, color: _C.accent),
                                      const SizedBox(width: 6),
                                      Text('$d día${d != 1 ? 's' : ''} antes',
                                          style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 13)),
                                    ]),
                                  ))
                              .toList(),
                          onChanged: (v) => setModal(() => diasAviso = v ?? 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Estado
                    _LabelAbove(label: 'ESTADO ACTUAL'),
                    const SizedBox(height: 6),
                    Row(children: [
                      _EstadoBtn(
                          label: 'Al día',
                          value: 'al_dia',
                          color: _C.success,
                          selected: estado == 'al_dia',
                          onTap: () => setModal(() => estado = 'al_dia')),
                      const SizedBox(width: 6),
                      _EstadoBtn(
                          label: 'Pendiente',
                          value: 'pendiente',
                          color: _C.warning,
                          selected: estado == 'pendiente',
                          onTap: () => setModal(() => estado = 'pendiente')),
                      const SizedBox(width: 6),
                      _EstadoBtn(
                          label: 'Vencido',
                          value: 'vencido',
                          color: _C.danger,
                          selected: estado == 'vencido',
                          onTap: () => setModal(() => estado = 'vencido')),
                    ]),
                    const SizedBox(height: 14),

                    // Notas
                    _ModalField(
                        ctrl: ctrlNotas,
                        label: 'Notas (opcional)',
                        hint: 'Observaciones del cliente...',
                        icon: Icons.notes_rounded,
                        color: _C.textSec,
                        maxLines: 2),
                    const SizedBox(height: 24),

                    // Botón guardar
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          Navigator.pop(ctx);
                          final nuevo = StarlinkClientePago(
                            id: editar?.id ?? '',
                            nombreCliente: ctrlNombre.text.trim(),
                            lugar: ctrlLugar.text.trim(),
                            diaVencimiento: diaVenc,
                            montoQuePago: double.tryParse(ctrlPago.text) ?? 0,
                            montoQueCobro: double.tryParse(ctrlCobro.text) ?? 0,
                            telefono: ctrlTel.text.trim(),
                            estado: estado,
                            propietarioUid: _uid ?? '',
                            creadoEn: editar?.creadoEn ?? DateTime.now(),
                            diasAvisoPrevio: diasAviso,
                            notasExtra: ctrlNotas.text.trim(),
                          );
                          await _guardar(nuevo, docId: editar?.id);
                        },
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            editar == null ? 'Registrar Starlink' : 'Guardar cambios',
                            style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surfaceDim,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(_kColeccion)
                  .where('propietarioUid', isEqualTo: _uid)
                  .orderBy('creadoEn', descending: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _C.primary, strokeWidth: 2.5));
                }
                final docs = snap.data?.docs ?? [];
                final items = docs.map((d) => StarlinkClientePago.fromDoc(d)).toList();

                // Cálculos resumen
                final totalPago = items.fold(0.0, (a, b) => a + b.montoQuePago);
                final totalCobro = items.fold(0.0, (a, b) => a + b.montoQueCobro);
                final alDia = items.where((i) => i.estado == 'al_dia').length;
                final pendiente = items.where((i) => i.estado == 'pendiente').length;
                final vencido = items.where((i) => i.estado == 'vencido').length;

                return ListView(
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    _SummaryCard(
                      total: items.length,
                      totalPago: totalPago,
                      totalCobro: totalCobro,
                      alDia: alDia,
                      pendiente: pendiente,
                      vencido: vencido,
                    ).animate().fadeIn(duration: 350.ms),
                    if (items.isEmpty) _buildEmpty(),
                    ...items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      return _StarClientCard(
                        item: item,
                        onEdit: () => _abrirFormulario(editar: item),
                        onDelete: () => _eliminar(item),
                        onWhatsapp: () => _enviarWhatsapp(item),
                        onToggleEstado: () => _toggleEstado(item),
                      ).animate().fadeIn(duration: 300.ms, delay: (i * 40).ms).slideY(begin: 0.04, end: 0);
                    }),
                  ],
                );
              },
            ),
          ),
        ]),
      ),

      // FAB — Agregar
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        backgroundColor: _C.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Nueva Starlink', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildTopBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
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
              Text('Mis Starlinks', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 20, fontWeight: FontWeight.w800)),
              Text('Gestión de cobros a clientes', style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 12)),
            ]),
          ),
          // Indicador WA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (_waConectado ? _C.whatsapp : _C.textSec).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: (_waConectado ? _C.whatsapp : _C.textSec).withOpacity(0.3)),
            ),
            child: Row(children: [
              Icon(FontAwesomeIcons.whatsapp, color: _waConectado ? _C.whatsapp : _C.textSec, size: 12),
              const SizedBox(width: 5),
              Text(_waConectado ? 'Conectado' : 'Sin WA',
                  style: GoogleFonts.spaceGrotesk(
                    color: _waConectado ? _C.whatsapp : _C.textSec,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  )),
            ]),
          ),
        ]),
      );

  Widget _buildEmpty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.satellite_alt_rounded, size: 64, color: _C.textSec.withOpacity(0.25)),
            const SizedBox(height: 14),
            Text('Sin Starlinks registradas',
                style: GoogleFonts.spaceGrotesk(color: _C.textSec, fontSize: 16, fontWeight: FontWeight.w600)),
            Text('Presiona "+ Nueva Starlink" para comenzar',
                style: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.6), fontSize: 13)),
          ]),
        ),
      );

  // ── Helpers UI ───────────────────────────
  void _showLoading() => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(color: _C.whatsapp, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text('Enviando mensaje…', style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14)),
            ]),
          ),
        ),
      );

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.spaceGrotesk(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}

// ─────────────────────────────────────────────
//  WIDGETS AUXILIARES DEL MODAL
// ─────────────────────────────────────────────
class _ModalField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final Color color;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final int maxLines;

  const _ModalField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    required this.color,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _LabelAbove(label: label),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          maxLines: maxLines,
          style: GoogleFonts.spaceGrotesk(color: _C.textPri, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.spaceGrotesk(color: _C.textSec.withOpacity(0.55), fontSize: 13),
            prefixIcon: Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: color, size: 17),
            ),
            filled: true,
            fillColor: _C.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder:
                OutlineInputBorder(borderSide: BorderSide(color: _C.border, width: 1.2), borderRadius: BorderRadius.circular(14)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: color, width: 1.8), borderRadius: BorderRadius.circular(14)),
            errorBorder: OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.4), borderRadius: BorderRadius.circular(14)),
            focusedErrorBorder:
                OutlineInputBorder(borderSide: BorderSide(color: _C.danger, width: 1.8), borderRadius: BorderRadius.circular(14)),
            errorStyle: GoogleFonts.spaceGrotesk(color: _C.danger, fontSize: 11),
          ),
        ),
      ]);
}

class _LabelAbove extends StatelessWidget {
  final String label;
  const _LabelAbove({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          color: _C.textSec,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      );
}

class _EstadoBtn extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _EstadoBtn({
    required this.label,
    required this.value,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? color : color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? color : color.withOpacity(0.25), width: selected ? 1.8 : 1),
            ),
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: selected ? Colors.white : color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}
