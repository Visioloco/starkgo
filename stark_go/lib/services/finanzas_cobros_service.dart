import 'package:cloud_firestore/cloud_firestore.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// FinanzasCobrosService
/// Conecta los cobros de clientes con la colección `finanzas`:
///  - Cada pago registrado (reportepago) se guarda automáticamente como INGRESO
///    en `finanzas` (origenCliente = true), sin duplicar (idempotente por
///    origenPagoId).
///  - Permite sincronizar pagos históricos registrados antes de la integración.
/// ─────────────────────────────────────────────────────────────────────────────
class FinanzasCobrosService {
  static const String coleccionFinanzas = 'finanzas';
  static const String coleccionPagos = 'reportepago';
  static const String coleccionClientes = 'clientes';

  /// Crea (o actualiza si ya existe) el ingreso por cobro de un cliente.
  /// [pagoId] es el id del documento en `reportepago` (evita duplicados).
  static Future<void> registrarCobro({
    required String uid,
    required String pagoId,
    required String nombreCliente,
    required double monto,
    required DateTime fecha,
  }) async {
    final colFin = FirebaseFirestore.instance.collection(coleccionFinanzas);
    final existentes =
        await colFin.where('origenPagoId', isEqualTo: pagoId).limit(1).get();

    final data = <String, dynamic>{
      'propietarioUid': uid,
      'tipo': 'ingreso',
      'descripcion': 'Pago de cliente · $nombreCliente',
      'categoria': 'Ventas / Servicios',
      'monto': monto,
      'fecha': Timestamp.fromDate(fecha),
      'origenCliente': true,
      'origenPagoId': pagoId,
      'actualizadoEn': FieldValue.serverTimestamp(),
    };

    if (existentes.docs.isEmpty) {
      data['creadoEn'] = FieldValue.serverTimestamp();
      await colFin.add(data);
    } else {
      await existentes.docs.first.reference.update(data);
    }
  }

  /// Recorre los pagos del usuario que todavía no están en `finanzas`
  /// y los crea como ingresos de cliente. Devuelve cuántos creó.
  static Future<int> sincronizarHistoricos(String uid) async {
    try {
      // 1. Clientes del usuario (para saber qué pagos le pertenecen)
      final clientesSnap = await FirebaseFirestore.instance
          .collection(coleccionClientes)
          .where('propietarioUid', isEqualTo: uid)
          .get();
      final clientesPorRef = <String, String>{};
      for (final c in clientesSnap.docs) {
        final d = c.data();
        final nombre =
            '${(d['nombre'] ?? '').toString()} ${(d['apellido'] ?? '').toString()}'
                .trim();
        clientesPorRef[c.reference.path] = nombre.isEmpty ? 'Cliente' : nombre;
      }

      // 2. Cobros ya sincronizados (evitar duplicados)
      final finSnap = await FirebaseFirestore.instance
          .collection(coleccionFinanzas)
          .where('propietarioUid', isEqualTo: uid)
          .where('origenCliente', isEqualTo: true)
          .get();
      final yaSincronizados = <String>{
        for (final f in finSnap.docs)
          if ((f.data()['origenPagoId'] ?? '').toString().isNotEmpty)
            (f.data()['origenPagoId'] ?? '').toString(),
      };

      // 3. Pagos: nuevos (con propietarioUid) + históricos sin propietario
      final pagosCol = FirebaseFirestore.instance.collection(coleccionPagos);
      final pagosNuevos =
          await pagosCol.where('propietarioUid', isEqualTo: uid).get();
      final pagosLegacy =
          await pagosCol.where('propietarioUid', isEqualTo: null).get();

      final refsCliente = clientesPorRef.keys.toSet();
      final pendientes = <QueryDocumentSnapshot>[];
      for (final p in <QueryDocumentSnapshot>[
        ...pagosNuevos.docs,
        ...pagosLegacy.docs,
      ]) {
        final d = p.data() as Map<String, dynamic>;
        if (yaSincronizados.contains(p.id)) continue;
        final refCliente = d['refcliente'];
        final refPath = refCliente is DocumentReference ? refCliente.path : '';
        final esMio = (d['propietarioUid'] ?? '').toString() == uid ||
            (refPath.isNotEmpty && refsCliente.contains(refPath));
        if (!esMio) continue;
        pendientes.add(p);
      }

      if (pendientes.isEmpty) return 0;

      // 4. Guardar en lotes (máx. 450 operaciones por batch)
      final colFin = FirebaseFirestore.instance.collection(coleccionFinanzas);
      int creados = 0;
      for (int i = 0; i < pendientes.length; i += 90) {
        final batch = FirebaseFirestore.instance.batch();
        final to = i + 90 > pendientes.length ? pendientes.length : i + 90;
        final lote = pendientes.sublist(i, to);
        for (final p in lote) {
          final d = p.data() as Map<String, dynamic>;
          final refPath = d['refcliente'] is DocumentReference
              ? (d['refcliente'] as DocumentReference).path
              : '';
          final nombre = (d['nombrecliente'] ?? '').toString().isNotEmpty
              ? (d['nombrecliente'] ?? '').toString()
              : (clientesPorRef[refPath] ?? 'Cliente');
          final fechaRaw = d['fecha'];
          DateTime fecha = DateTime.now();
          if (fechaRaw is Timestamp) fecha = fechaRaw.toDate();
          final monto = _toDouble(d['valor']);
          if (monto <= 0) continue;
          batch.set(colFin.doc(), {
            'propietarioUid': uid,
            'tipo': 'ingreso',
            'descripcion': 'Pago de cliente · $nombre',
            'categoria': 'Ventas / Servicios',
            'monto': monto,
            'fecha': Timestamp.fromDate(fecha),
            'origenCliente': true,
            'origenPagoId': p.id,
            'creadoEn': FieldValue.serverTimestamp(),
          });
          // Marcar el pago histórico con su dueño para consultas futuras
          if ((d['propietarioUid'] ?? '').toString() != uid) {
            batch.update(p.reference, {'propietarioUid': uid});
          }
          creados++;
        }
        await batch.commit();
      }
      return creados;
    } catch (_) {
      rethrow;
    }
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
  }
}
