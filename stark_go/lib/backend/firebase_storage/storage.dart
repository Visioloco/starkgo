import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mime_type/mime_type.dart';

Future<String?> uploadData(String path, Uint8List data) async {
  try {
    final storageRef = FirebaseStorage.instance.ref().child(path);
    final metadata = SettableMetadata(
      contentType: mime(path) ?? 'image/jpeg',
      customMetadata: {'uploadedAt': DateTime.now().toIso8601String()},
    );

    // ── Upload con timeout de 30 segundos ──
    final UploadTask uploadTask = storageRef.putData(data, metadata);

    final TaskSnapshot result = await uploadTask.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        uploadTask.cancel();
        throw Exception('Tiempo de espera agotado. Verifica tu conexión.');
      },
    );

    if (result.state == TaskState.success) {
      return await result.ref.getDownloadURL();
    }
    return null;
  } on FirebaseException catch (e) {
    // Error específico de Firebase Storage
    throw Exception('Error al subir imagen: ${e.message}');
  } catch (e) {
    rethrow;
  }
}
