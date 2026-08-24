import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../plan_model.dart';

/// Maneja la "bienvenida" que se muestra UNA sola vez al usuario
/// cuando completa una membresía (completa o solo vouchers) y navega
/// al Home.
///
/// La bienvenida se guarda en Firestore asociada al UID:
///   user/{uid}/bienvenida  →  { planId, tipo, duracion, precio, fecha }
///
/// Cuando el usuario entra al Home, se lee y se borra de inmediato
/// (consumir), de modo que solo se muestre una vez.
class BienvenidaService {
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static DocumentReference _ref(String uid) =>
      FirebaseFirestore.instance.collection('user').doc(uid).collection('bienvenida').doc('pendiente');

  /// Marca que el usuario tiene una bienvenida pendiente por ver.
  /// Se llama cuando el pago es exitoso.
  static Future<void> marcarBienvenidaPendiente(Plan plan) async {
    final uid = _uid;
    if (uid == null) return;

    final esCompleto = plan.tipo == TipoPlan.completo;
    await _ref(uid).set({
      'planId': plan.id,
      'tipo': esCompleto ? 'completo' : 'vouchers',
      'duracion': plan.duracion,
      'precio': plan.precio,
      'sublabel': plan.sublabel,
      'fecha': FieldValue.serverTimestamp(),
    });
  }

  /// Lee la bienvenida pendiente y la borra de inmediato (consumir).
  /// Devuelve null si no hay bienvenida pendiente.
  /// Esto garantiza que la bienvenida solo se muestre UNA vez.
  static Future<Map<String, dynamic>?> consumirBienvenida() async {
    final uid = _uid;
    if (uid == null) return null;

    final doc = await _ref(uid).get();
    if (!doc.exists) return null;

    final data = doc.data() as Map<String, dynamic>?;
    // Borrar de inmediato para que no vuelva a salir.
    await _ref(uid).delete();
    return data;
  }
}
