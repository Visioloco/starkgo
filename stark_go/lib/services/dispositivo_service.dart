import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════════════
//  LÍMITE DE TELÉFONOS POR CUENTA  (máximo 2)
//
//  Cada cuenta (uid) puede tener la app abierta en **2 teléfonos** como
//  máximo. Este servicio registra el teléfono actual y decide si entra o no.
//
//  Dónde se guarda:
//    `dispositivos/{uid}/equipos/{idDispositivo}`
//      · propietarioUid → uid dueño de la cuenta
//      · nombre         → "Android · 7f3a1c" (para que el usuario lo reconozca)
//      · ultimoUso      → latido; si pasa mucho tiempo, el lugar se libera solo
//
//  Cómo se libera un lugar:
//    · Al cerrar sesión en ese teléfono (se borra su documento).
//    · Al tocar "Liberar" en la pantalla de límite alcanzado.
//    · Solo: si el teléfono no abre la app en [kDiasActividadDispositivo] días.
// ══════════════════════════════════════════════════════════════════

/// Cuántos teléfonos pueden tener la cuenta abierta al mismo tiempo.
const int kMaxDispositivosPorCuenta = 2;

/// Un teléfono sigue ocupando su lugar si tuvo actividad en estos días.
/// Pasado ese plazo (celular perdido, roto o app desinstalada) el lugar se
/// libera solo y otro teléfono puede ocuparlo.
const int kDiasActividadDispositivo = 7;

/// Un teléfono registrado en la cuenta.
class DispositivoInfo {
  const DispositivoInfo({
    required this.id,
    required this.nombre,
    this.ultimoUso,
    this.esEste = false,
  });

  final String id;
  final String nombre;
  final DateTime? ultimoUso;

  /// true si es el teléfono desde el que se está mirando la pantalla.
  final bool esEste;

  /// Fecha del último uso en texto corto ("12/05/2026 18:30" o "recién").
  String get ultimoUsoTexto {
    final d = ultimoUso;
    if (d == null) return 'recién';
    final l = d.toLocal();
    final dd = l.day.toString().padLeft(2, '0');
    final mm = l.month.toString().padLeft(2, '0');
    final hh = l.hour.toString().padLeft(2, '0');
    final mi = l.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${l.year} $hh:$mi';
  }
}

/// Resultado de la verificación del límite.
class ResultadoDispositivo {
  const ResultadoDispositivo({
    required this.permitido,
    this.dispositivos = const [],
    this.error,
  });

  /// true si este teléfono puede usar la app.
  final bool permitido;

  /// Teléfonos que hoy ocupan los lugares de la cuenta.
  final List<DispositivoInfo> dispositivos;

  /// Detalle del error (solo informativo; nunca bloquea por un fallo técnico).
  final String? error;
}

class DispositivoService {
  static const String _col = 'dispositivos';
  static const String _sub = 'equipos';
  static const String _prefsKey = 'sg_dispositivo_id';

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _equipos(String uid) =>
      FirebaseFirestore.instance
          .collection(_col)
          .doc(uid)
          .collection(_sub);

  /// Identificador estable de ESTE teléfono. Se genera una vez y queda
  /// guardado en el teléfono (SharedPreferences).
  ///
  /// OJO: si el usuario borra los datos de la app se genera uno nuevo; en ese
  /// caso el teléfono entra como "nuevo" y el usuario puede liberar el viejo
  /// desde la pantalla de límite alcanzado.
  static Future<String> idDispositivo() async {
    final prefs = await SharedPreferences.getInstance();
    final existente = prefs.getString(_prefsKey);
    if (existente != null && existente.length >= 16) return existente;
    final rnd = Random.secure();
    final nuevo =
        List.generate(24, (_) => rnd.nextInt(16).toRadixString(16)).join();
    await prefs.setString(_prefsKey, nuevo);
    return nuevo;
  }

  /// Nombre legible de la plataforma (para que el usuario distinga sus
  /// teléfonos en la pantalla del límite).
  static String nombrePlataforma() {
    if (kIsWeb) return 'Navegador';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iPhone';
      case TargetPlatform.macOS:
        return 'Mac';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Teléfono';
    }
  }

  static String _nombreCorto(String id) =>
      id.length <= 6 ? id : id.substring(0, 6);

  /// Verifica el límite de teléfonos de la cuenta autenticada.
  ///
  /// · Si este teléfono ya estaba registrado → refresca su latido y entra.
  /// · Si todavía hay lugar (menos de [kMaxDispositivosPorCuenta] activos) →
  ///   lo registra y entra.
  /// · Si no hay lugar → devuelve `permitido: false` con la lista de teléfonos
  ///   activos, para que el usuario decida cuál liberar.
  ///
  /// Si Firestore falla (sin internet, por ejemplo) NO se bloquea al usuario:
  /// se devuelve `permitido: true` para no dejarlo afuera de su propia cuenta.
  static Future<ResultadoDispositivo> verificarYRegistrar() async {
    final uid = _uid;
    if (uid == null) {
      return const ResultadoDispositivo(permitido: false, error: 'Sin sesión');
    }
    final mio = await idDispositivo();
    try {
      final snap = await _equipos(uid).get();
      final ahora = DateTime.now();
      final activos = <DispositivoInfo>[];
      final vencidos = <String>[];

      for (final d in snap.docs) {
        final data = d.data();
        final ultimo = (data['ultimoUso'] as Timestamp?)?.toDate();
        // Sin fecha (recién creado, aún pendiente) = activo.
        final activo = ultimo == null ||
            ahora.difference(ultimo).inDays < kDiasActividadDispositivo;
        if (activo) {
          activos.add(DispositivoInfo(
            id: d.id,
            nombre: (data['nombre'] ?? 'Teléfono').toString(),
            ultimoUso: ultimo,
            esEste: d.id == mio,
          ));
        } else if (d.id != mio) {
          vencidos.add(d.id);
        }
      }

      // Limpieza: los teléfonos vencidos ya no ocupan lugar.
      for (final id in vencidos) {
        try {
          await _equipos(uid).doc(id).delete();
        } catch (_) {}
      }

      final esMio = activos.any((e) => e.id == mio);
      if (esMio || activos.length < kMaxDispositivosPorCuenta) {
        await _registrar(uid, mio);
        return ResultadoDispositivo(permitido: true, dispositivos: activos);
      }
      return ResultadoDispositivo(permitido: false, dispositivos: activos);
    } catch (e) {
      debugPrint('[Dispositivos] Error verificando el límite: $e');
      return ResultadoDispositivo(permitido: true, error: '$e');
    }
  }

  static Future<void> _registrar(String uid, String id) async {
    await _equipos(uid).doc(id).set({
      'propietarioUid': uid,
      'nombre': '${nombrePlataforma()} · ${_nombreCorto(id)}',
      'ultimoUso': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Latido: marca que este teléfono sigue en uso (se llama al abrir la app y
  /// al volver a ella).
  static Future<void> latido() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _registrar(uid, await idDispositivo());
    } catch (e) {
      debugPrint('[Dispositivos] No se pudo actualizar el latido: $e');
    }
  }

  /// Libera el lugar de ESTE teléfono (se usa al cerrar sesión).
  static Future<void> liberarEste() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _equipos(uid).doc(await idDispositivo()).delete();
    } catch (e) {
      debugPrint('[Dispositivos] No se pudo liberar este teléfono: $e');
    }
  }

  /// Libera otro teléfono de la cuenta (el usuario elige cuál).
  static Future<bool> liberar(String idDispositivo) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await _equipos(uid).doc(idDispositivo).delete();
      return true;
    } catch (e) {
      debugPrint('[Dispositivos] No se pudo liberar $idDispositivo: $e');
      return false;
    }
  }

  /// Libera el teléfono que hace más tiempo no se usa (el "más viejo"),
  /// dejando lugar para este. Devuelve el nombre del liberado, o null.
  static Future<String?> liberarMasAntiguo(
      List<DispositivoInfo> activos) async {
    final mio = await idDispositivo();
    final otros = activos.where((e) => e.id != mio).toList();
    if (otros.isEmpty) return null;
    otros.sort((a, b) => (a.ultimoUso ?? DateTime(2000))
        .compareTo(b.ultimoUso ?? DateTime(2000)));
    final elegido = otros.first;
    final ok = await liberar(elegido.id);
    return ok ? elegido.nombre : null;
  }

  /// Revisa el límite al volver a la app (el teléfono puede haber perdido su
  /// lugar porque lo liberaron desde otro celular). Sirve también de latido.
  static Future<void> revisarAlVolver(
      {required VoidCallback onBloqueado}) async {
    final r = await verificarYRegistrar();
    if (!r.permitido) onBloqueado();
  }
}

