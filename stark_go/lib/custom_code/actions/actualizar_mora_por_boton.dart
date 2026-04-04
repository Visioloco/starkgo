// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'index.dart'; // Imports other custom actions

import 'package:cloud_firestore/cloud_firestore.dart';

Future<String> actualizarMoraPorBoton(
    List<DocumentReference> listaClientes) async {
  // 1. Verificamos si la lista que pasamos tiene datos
  if (listaClientes.isEmpty) {
    return "No se encontraron clientes con status 'activo'.";
  }

  final firestore = FirebaseFirestore.instance;
  int contador = 0;

  try {
    // 2. Procesamos en lotes de 500 (límite de Firebase)
    for (var i = 0; i < listaClientes.length; i += 500) {
      WriteBatch batch = firestore.batch();

      var fin =
          (i + 500 < listaClientes.length) ? i + 500 : listaClientes.length;
      var subLista = listaClientes.sublist(i, fin);

      for (var docRef in subLista) {
        // IMPORTANTE: Cambiado a 'status' y 'mora' según tu instrucción
        batch.update(docRef, {'status': 'mora'});
        contador++;
      }

      // Guardamos los cambios en Firebase
      await batch.commit();
    }
    return "¡Listo! Se actualizaron $contador clientes a 'mora'.";
  } catch (e) {
    return "Error al actualizar: $e";
  }
}
