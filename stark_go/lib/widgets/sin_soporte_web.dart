import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ══════════════════════════════════════════════════════════════════
//  "NO DISPONIBLE EN LA WEB"
//
//  Se muestra en las funciones que sólo existen en la app móvil:
//  conexión local al MikroTik (API/FTP), archivos del teléfono y
//  notificaciones locales. En el navegador no se pueden usar porque
//  requieren sockets, FTP o permisos que la web no permite.
// ══════════════════════════════════════════════════════════════════

class SinSoporteWeb extends StatelessWidget {
  const SinSoporteWeb({
    super.key,
    required this.titulo,
    required this.detalle,
  });

  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    final puedeVolver = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 78,
                  height: 78,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A73E8).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.computer_rounded,
                      color: Color(0xFF1A73E8), size: 38),
                ),
                const SizedBox(height: 18),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFF0F172A),
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  detalle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                      color: const Color(0xFF64748B),
                      fontSize: 13.5,
                      height: 1.45),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.3)),
                  ),
                  child: Text(
                    'En el navegador sí podés usar todo lo demás: clientes, planes, '
                    'informes, facturación, pagos, VPN y la configuración del '
                    'MikroTik por el VPS.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFF0F172A),
                        fontSize: 11.5,
                        height: 1.4),
                  ),
                ),
                const SizedBox(height: 18),
                if (puedeVolver)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Volver'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Versión para widgets EMBEBIDOS (dentro de pestañas o columnas): no usa
/// `Scaffold`, sólo un contenedor, para no romper el layout del padre.
class SinSoporteWebInline extends StatelessWidget {
  const SinSoporteWebInline({
    super.key,
    required this.titulo,
    required this.detalle,
  });

  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.computer_rounded,
              color: Color(0xFF1A73E8), size: 34),
          const SizedBox(height: 12),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
                color: const Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            detalle,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
                color: const Color(0xFF64748B), fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

