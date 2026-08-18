import 'dart:io';
import 'dart:typed_data';

import 'package:ftpconnect/ftpconnect.dart';

/// Sube y descarga los archivos del portal cautivo (carpeta `hotspot/`
/// dentro del router) usando FTP. RouterOS trae servidor FTP integrado;
/// solo hay que activarlo (ver instrucciones más abajo).
class HotspotFtpService {
  final String host;
  final String usuario;
  final String clave;
  final int puerto;

  HotspotFtpService({
    required this.host,
    required this.usuario,
    required this.clave,
    this.puerto = 21,
  });

  FTPConnect _conectar() {
    return FTPConnect(
      host,
      user: usuario,
      pass: clave,
      port: puerto,
      timeout: 20,
    );
  }

  /// Sube (sobrescribe) un archivo dentro de hotspot/. Úsalo tanto para
  /// el HTML (login.html) como para el logo (logo.png, logo.jpg, etc).
  Future<void> subirArchivo({
    required String nombreArchivo,
    required Uint8List contenido,
  }) async {
    final ftp = _conectar();
    File? temporal;
    try {
      await ftp.connect();
      await ftp.changeDirectory('hotspot');
      temporal = await _bytesATemporal(nombreArchivo, contenido);
      final ok = await ftp.uploadFile(temporal, sRemoteName: nombreArchivo);
      if (!ok) {
        throw Exception('El router rechazó la subida de "$nombreArchivo"');
      }
    } finally {
      if (temporal != null && await temporal.exists()) await temporal.delete();
      await ftp.disconnect();
    }
  }

  /// Sube varios archivos en una sola conexión (más rápido que uno por uno).
  Future<void> subirArchivos(Map<String, Uint8List> archivos) async {
    final ftp = _conectar();
    final temporales = <File>[];
    try {
      await ftp.connect();
      await ftp.changeDirectory('hotspot');
      for (final entrada in archivos.entries) {
        final temporal = await _bytesATemporal(entrada.key, entrada.value);
        temporales.add(temporal);
        final ok = await ftp.uploadFile(temporal, sRemoteName: entrada.key);
        if (!ok) {
          throw Exception('El router rechazó la subida de "${entrada.key}"');
        }
      }
    } finally {
      for (final t in temporales) {
        if (await t.exists()) await t.delete();
      }
      await ftp.disconnect();
    }
  }

  Future<List<String>> listarArchivosHotspot() async {
    final ftp = _conectar();
    try {
      await ftp.connect();
      await ftp.changeDirectory('hotspot');
      final lista = await ftp.listDirectoryContent();
      return lista.map((e) => e.name).where((n) => n != '.' && n != '..').toList();
    } finally {
      await ftp.disconnect();
    }
  }

  Future<Uint8List> descargarArchivo(String nombreArchivo) async {
    final ftp = _conectar();
    File? temporal;
    try {
      await ftp.connect();
      await ftp.changeDirectory('hotspot');
      final dir = await Directory.systemTemp.createTemp('hotspot_download');
      temporal = File('${dir.path}/$nombreArchivo');
      final ok = await ftp.downloadFile(nombreArchivo, temporal);
      if (!ok) throw Exception('No se pudo descargar "$nombreArchivo"');
      return await temporal.readAsBytes();
    } finally {
      if (temporal != null && await temporal.exists()) await temporal.delete();
      await ftp.disconnect();
    }
  }

  Future<File> _bytesATemporal(String nombre, Uint8List bytes) async {
    final dir = await Directory.systemTemp.createTemp('hotspot_upload');
    final file = File('${dir.path}/$nombre');
    await file.writeAsBytes(bytes);
    return file;
  }
}
