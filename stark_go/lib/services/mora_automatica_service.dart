import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Servicio de mora automática.
///
/// Marca en "mora" (rojo) a los clientes que NO han pagado este mes,
/// según el día de vencimiento configurado en `config_empresa/{uid}`.
///
/// IMPORTANTE: SOLO cambia el color/estado del cliente. NO corta el acceso
/// ni envía la cola a MikroTik. Eso se hace manualmente con los botones.
class MoraAutomaticaService {
  /// Ejecuta la marcación automática de mora.
  ///
  /// Retorna la cantidad de clientes marcados en mora (0 si no aplica).
  static Future<int> ejecutarMoraAutomatica() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return 0;

    try {
      // 1. Leer configuración de empresa
      final configRef = FirebaseFirestore.instance.collection('config_empresa').doc(uid);
      final configSnap = await configRef.get();
      if (!configSnap.exists) return 0;

      final config = configSnap.data() ?? {};
      final int diaVencimiento = (config['diaVencimiento'] as int?) ?? 0;
      if (diaVencimiento <= 0) return 0;

      // 2. Evitar repetir la marcación el mismo día
      final now = DateTime.now();
      final ultimaEjecucion = config['ultimaMoraAutomatica'] as DateTime?;
      if (ultimaEjecucion != null &&
          ultimaEjecucion.year == now.year &&
          ultimaEjecucion.month == now.month &&
          ultimaEjecucion.day == now.day) {
        return 0; // Ya se ejecutó hoy
      }

      // 3. Si aún no ha llegado el día de vencimiento, no marcar
      if (now.day < diaVencimiento) return 0;

      // 4. Leer todos los clientes del usuario
      final clientesSnap = await FirebaseFirestore.instance.collection('clientes').where('propietarioUid', isEqualTo: uid).get();

      // 5. Determinar la fecha límite de pago de este mes (día de vencimiento)
      final DateTime limitePagoMes = DateTime(now.year, now.month, diaVencimiento);

      final batch = FirebaseFirestore.instance.batch();
      int contador = 0;

      for (final doc in clientesSnap.docs) {
        final data = doc.data();
        final String status = (data['status'] ?? '').toString();
        // Solo marcar a los que están activos
        if (status != 'activo') continue;

        final DateTime? ultimoPago = data['ultimoPago'] as DateTime?;

        // Si no tiene registro de último pago → está en mora
        // Si su último pago fue ANTES del día de vencimiento de este mes → está en mora
        final bool enMora = ultimoPago == null || ultimoPago.isBefore(limitePagoMes);

        if (enMora) {
          batch.update(doc.reference, {
            'status': 'mora',
            'moraDesde': DateTime.now(),
          });
          contador++;
        }
      }

      if (contador > 0) {
        await batch.commit();
      }

      // 6. Guardar la fecha de ejecución para no repetirla hoy
      await configRef.set({'ultimaMoraAutomatica': DateTime.now()}, SetOptions(merge: true));

      debugPrint('[StarkGo] Mora automática: $contador cliente(s) marcado(s) en mora.');
      return contador;
    } catch (e) {
      debugPrint('[StarkGo] Error en mora automática: $e');
      return 0;
    }
  }
}
