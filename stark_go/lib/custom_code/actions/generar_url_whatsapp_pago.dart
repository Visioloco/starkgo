// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

String generarUrlWhatsappPago(
  String nombre,
  String referencia,
  String fecha,
  String valor,
  String numeroTelefono,
) {
  // ── Limpiar y formatear número ──
  String numero = numeroTelefono.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
  if (!numero.startsWith('57')) {
    numero = '57$numero';
  }

  // ── Formatear valor con separador de miles ──
  String valorFormateado = valor;
  try {
    final int v = int.parse(valor.replaceAll(RegExp(r'[^\d]'), ''));
    valorFormateado = '\$${v.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        )}';
  } catch (_) {
    valorFormateado = '\$$valor';
  }

  // ── Emojis como escape Unicode para evitar problemas de encoding ──
  final doc = '\u{1F4C4}'; // 📄
  final wave = '\u{1F44B}'; // 👋
  final check = '\u2705'; // ✅
  final receipt = '\u{1F9FE}'; // 🧾
  final calendar = '\u{1F4C5}'; // 📅
  final money = '\u{1F4B0}'; // 💰
  final pray = '\u{1F64F}'; // 🙏
  final star = '\u{1F31F}'; // 🌟

  final String mensaje = '$doc *Comprobante de Pago Recibido*\n\n'
      'Hola $nombre $wave, hemos registrado tu pago exitosamente $check\n\n'
      '$receipt *Referencia:* $referencia\n'
      '$calendar *Fecha:* $fecha\n'
      '$money *Valor:* $valorFormateado\n\n'
      '$pray \u00A1Gracias por tu pago! Tu servicio est\u00E1 activo.\n'
      'Bendiciones $star';

  return 'https://wa.me/$numero?text=${Uri.encodeComponent(mensaje)}';
}

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
