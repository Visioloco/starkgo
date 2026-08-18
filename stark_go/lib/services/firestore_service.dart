import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/mikrotik_local_api.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Guardar configuración local del MikroTik ──
  Future<void> guardarConfiguracionLocal({
    required String uid,
    required String ip,
    required int puerto,
    required String usuario,
    required bool useSsl,
    required String nombreRouter,
  }) async {
    try {
      await _firestore.collection('usuarios').doc(uid).collection('configuracion_local').doc('mikrotik').set({
        'ip': ip,
        'puerto': puerto,
        'usuario': usuario,
        'useSsl': useSsl,
        'nombreRouter': nombreRouter,
        'fechaActualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Error guardando configuración local: $e');
    }
  }

  // ── Obtener configuración local guardada ──
  Future<Map<String, dynamic>?> obtenerConfiguracionLocal(String uid) async {
    try {
      final doc = await _firestore.collection('usuarios').doc(uid).collection('configuracion_local').doc('mikrotik').get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      throw Exception('Error obteniendo configuración local: $e');
    }
  }

  // ── Guardar configuración VPS ──
  Future<void> guardarConfiguracionVPS({
    required String uid,
    required String ipVPS,
    required String token,
  }) async {
    try {
      await _firestore.collection('usuarios').doc(uid).collection('configuracion_vps').doc('mikrotik').set({
        'ipVPS': ipVPS,
        'token': token,
        'fechaActualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Error guardando configuración VPS: $e');
    }
  }

  // ── Obtener configuración VPS guardada ──
  Future<Map<String, dynamic>?> obtenerConfiguracionVPS(String uid) async {
    try {
      final doc = await _firestore.collection('usuarios').doc(uid).collection('configuracion_vps').doc('mikrotik').get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      throw Exception('Error obteniendo configuración VPS: $e');
    }
  }

  // ── Guardar historial de fichas generadas ──
  Future<void> guardarFichaGenerada({
    required String uid,
    required String codigo,
    required String perfil,
    required String modo, // 'local' o 'vps'
  }) async {
    try {
      await _firestore.collection('usuarios').doc(uid).collection('fichas_generadas').add({
        'codigo': codigo,
        'perfil': perfil,
        'modo': modo,
        'fechaCreacion': FieldValue.serverTimestamp(),
        'activa': true,
      });
    } catch (e) {
      throw Exception('Error guardando ficha generada: $e');
    }
  }

  // ── Obtener historial de fichas ──
  Stream<QuerySnapshot> obtenerHistorialFichas(String uid) {
    return _firestore.collection('usuarios').doc(uid).collection('fichas_generadas').orderBy('fechaCreacion', descending: true).snapshots();
  }

  // ── Marcar ficha como usada ──
  Future<void> marcarFichaUsada({
    required String uid,
    required String fichaId,
    required String usuarioConectado,
  }) async {
    try {
      await _firestore.collection('usuarios').doc(uid).collection('fichas_generadas').doc(fichaId).update({
        'activa': false,
        'fechaUso': FieldValue.serverTimestamp(),
        'usuarioConectado': usuarioConectado,
      });
    } catch (e) {
      throw Exception('Error marcando ficha como usada: $e');
    }
  }

  // ── Eliminar configuración local ──
  Future<void> eliminarConfiguracionLocal(String uid) async {
    try {
      await _firestore.collection('usuarios').doc(uid).collection('configuracion_local').doc('mikrotik').delete();
    } catch (e) {
      throw Exception('Error eliminando configuración local: $e');
    }
  }
}
