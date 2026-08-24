import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Servicio global de notificaciones locales.
///
/// Se inicializa una sola vez en `main()` para que las notificaciones
/// programadas (zonedSchedule) funcionen correctamente desde el arranque
/// de la app, incluso si el usuario no ha abierto la pantalla de Starlinks.
class NotificacionesService {
  NotificacionesService._();

  static final NotificacionesService instance = NotificacionesService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  FlutterLocalNotificationsPlugin get plugin => _plugin;

  /// Inicializa el plugin y fija la zona horaria local del dispositivo.
  /// Debe llamarse una sola vez, idealmente en `main()`.
  Future<void> init() async {
    if (_initialized) return;

    // ── Zona horaria local ─────────────────────────────
    // Sin esto, tz.local queda en UTC y las notificaciones
    // se programan en la hora equivocada (o no se disparan).
    tz.initializeTimeZones();
    try {
      final localName = tz.local.name;
      if (localName == 'UTC' || localName.isEmpty) {
        final detected = DateTime.now().timeZoneName;
        tz.setLocalLocation(tz.getLocation(_mapTzName(detected)));
      }
    } catch (_) {
      // Fallback: Bogotá (Colombia)
      tz.setLocalLocation(tz.getLocation('America/Bogota'));
    }

    // ── Configuración del plugin ───────────────────────
    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings);

    // ── Permisos en runtime ────────────────────────────
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final notifGranted = await androidImpl?.requestNotificationsPermission();
    final exactGranted = await androidImpl?.requestExactAlarmsPermission();
    debugPrint('🔔 Permiso notificaciones: $notifGranted | Alarmas exactas: $exactGranted');

    // ── Excepción de optimización de batería ───────────
    // Necesario para que la alarma sobreviva con la app cerrada/Doze.
    try {
      final bateriaStatus = await Permission.ignoreBatteryOptimizations.status;
      if (!bateriaStatus.isGranted) {
        final resultado = await Permission.ignoreBatteryOptimizations.request();
        debugPrint('🔋 Excepción de batería: $resultado');
      }
    } catch (e) {
      debugPrint('⚠️ Error pidiendo excepción de batería: $e');
    }

    final iosImpl = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
    debugPrint('🔔 NotificacionesService inicializado correctamente');
  }

  /// Programa una notificación mensual (día del mes + hora) para recordar un cobro.
  Future<void> programarRecordatorio({
    required int id,
    required String titulo,
    required String cuerpo,
    required int diaDelMes,
    required int hora,
    required int minuto,
  }) async {
    await init();

    final now = DateTime.now();
    DateTime fecha = DateTime(now.year, now.month, diaDelMes, hora, minuto);
    if (fecha.isBefore(now)) {
      fecha = DateTime(now.year, now.month + 1, diaDelMes, hora, minuto);
    }

    final tzFecha = tz.TZDateTime.from(fecha, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'starlink_cobros',
      'Cobros Starlink',
      channelDescription: 'Recordatorios de cobro a clientes Starlink',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      color: Color(0xFF1A73E8),
      styleInformation: BigTextStyleInformation(''),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      id,
      titulo,
      cuerpo,
      tzFecha,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );

    debugPrint('🔔 Recordatorio programado → id=$id | próxima fecha: $tzFecha');
  }

  /// Cancela una notificación programada.
  Future<void> cancelar(int id) async {
    await init();
    await _plugin.cancel(id);
  }

  /// Muestra una notificación local INMEDIATA (no programada).
  /// Se usa para confirmar al dueño de la app si el mensaje de WhatsApp
  /// se envió correctamente o si falló.
  Future<void> mostrarNotificacion({
    required int id,
    required String titulo,
    required String cuerpo,
  }) async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'starlink_cobros',
      'Cobros Starlink',
      channelDescription: 'Recordatorios de cobro a clientes Starlink',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      color: Color(0xFF1A73E8),
      styleInformation: BigTextStyleInformation(''),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(id, titulo, cuerpo, details);
    debugPrint('🔔 Notificación inmediata mostrada → id=$id | $titulo');
  }

  /// Convierte el nombre de zona horaria del dispositivo (ej. "COT", "GMT-5")
  /// a un nombre de zona IANA válido para el paquete timezone.
  static String _mapTzName(String raw) {
    final t = raw.trim().toUpperCase();
    const map = <String, String>{
      'COT': 'America/Bogota',
      'COST': 'America/Bogota',
      'GMT-5': 'America/Bogota',
      'UTC-5': 'America/Bogota',
      'EST': 'America/Bogota',
      'PET': 'America/Lima',
      'ECT': 'America/Guayaquil',
      'CST': 'America/Mexico_City',
      'ART': 'America/Argentina/Buenos_Aires',
      'CLT': 'America/Santiago',
      'PYT': 'America/Asuncion',
      'BOT': 'America/La_Paz',
      'VET': 'America/Caracas',
      'AMT': 'America/Manaus',
      'BRT': 'America/Sao_Paulo',
      'AST': 'America/Puerto_Rico',
      'CDT': 'America/Chicago',
      'EDT': 'America/New_York',
      'PDT': 'America/Los_Angeles',
      'MDT': 'America/Denver',
    };
    if (map.containsKey(t)) return map[t]!;
    final offsetMatch = RegExp(r'^(?:GMT|UTC)([+-]\d{1,2})(?::\d{2})?$').firstMatch(t);
    if (offsetMatch != null) {
      final h = int.parse(offsetMatch.group(1)!);
      if (h == -5) return 'America/Bogota';
      if (h == -4) return 'America/New_York';
      if (h == -6) return 'America/Mexico_City';
      if (h == -3) return 'America/Argentina/Buenos_Aires';
      if (h == -8) return 'America/Los_Angeles';
      if (h == 0) return 'UTC';
    }
    return 'America/Bogota';
  }
}
