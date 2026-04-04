// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

Future<String> generarMensajeWhatsapp(
  String nombre,
  int numero,
  double planCliente,
) async {
  // Obtener la fecha actual del dispositivo
  final ahora = DateTime.now();
  final diaActual = ahora.day;

  // Calcular días faltantes o de atraso
  int diasDiferencia;
  String mensajeDias;
  String emoji;

  if (diaActual < 25) {
    // Faltan días para el 25
    diasDiferencia = 25 - diaActual;
    if (diasDiferencia == 1) {
      mensajeDias = 'falta *1 día*';
      emoji = '⚠️';
    } else {
      mensajeDias = 'faltan *$diasDiferencia días*';
      emoji = '📅';
    }
  } else if (diaActual == 25) {
    // Hoy es el día límite
    mensajeDias = '¡*HOY* es la fecha límite';
    emoji = '🔴⏰';
    diasDiferencia = 0;
  } else {
    // Ya pasó el día 25 (mora)
    diasDiferencia = diaActual - 25;
    if (diasDiferencia == 1) {
      mensajeDias = 'tienes *1 día de atraso*';
      emoji = '🚨';
    } else {
      mensajeDias = 'tienes *$diasDiferencia días de atraso*';
      emoji = '🚨';
    }
  }

  // Formatear el monto del plan con separador de miles
  String montoFormateado = '\$${planCliente.toStringAsFixed(0)}';
  // Agregar punto como separador de miles
  if (planCliente >= 10000) {
    final partes = montoFormateado.substring(1).split('');
    if (partes.length > 3) {
      partes.insert(partes.length - 3, '.');
      montoFormateado = '\$${partes.join('')}';
    }
  }

  // Construir el mensaje con emojis y texto formateado
  final mensaje = '''
📢 *Aviso de pago de internet*

Hola *$nombre* 👋, recuerda que $emoji $mensajeDias para la *fecha límite de pago* de tu servicio 🌐.

💰 Total a pagar: *$montoFormateado*

Puedes pagar por Nequi al número 👉 *3145336101*

📩 Envía el *comprobante de pago* a este mismo WhatsApp.

🙏 ¡Gracias! *El Señor te bendiga* ✅
''';

  // Construir la URL con el número y mensaje codificado
  final url = "https://wa.me/57$numero?text=${Uri.encodeComponent(mensaje)}";

  return url;
}
