import 'dart:ui';

import 'package:stark_go/pages/ConfigMikroTik/config_mikro_tik_widget.dart';
import 'package:stark_go/pages/lista_equipos/lista_equipos_widget.dart';
import 'package:stark_go/pages/lista_starlinks/lista_starlinks_widget.dart';
import 'package:stark_go/pages/planes/planes_widget.dart';
import 'package:stark_go/pages/config_evolution_api/config_evolution_api_widget.dart';
import 'package:stark_go/pages/crear_cuenta/crear_cuenta_widget.dart';
import 'package:stark_go/pages/config_facturacion/config_facturacion_widget.dart';
import 'package:stark_go/pages/config_velocidades/config_velocidades_widget.dart';
import 'package:stark_go/pages/informes/informes_widget.dart';
import 'package:stark_go/pages/lista_operadores/lista_operadores_widget.dart';
import 'package:stark_go/pages/tutorial/tutorial_widget.dart';
import 'package:stark_go/pages/pppoe_clientes/pppoe_clientes_widget.dart';
import '/pages/renovar_membresia/renovar_membresia_widget.dart';
import 'package:stark_go/pages/activar_membresia/activar_membresia_widget.dart';
import 'package:stark_go/pages/lista_starlinks_clientes/lista_starlinks_clientes_widget.dart';
import 'package:stark_go/widgets/consumo_widgets.dart';
import 'package:stark_go/theme/app_theme.dart';
import 'package:stark_go/widgets/day_background.dart';
import 'package:stark_go/pages/reporte_consumo/reporte_consumo_widget.dart';
import 'package:stark_go/pages/leases_mikrotik/leases_mikrotik_widget.dart';
import 'package:stark_go/pages/completar_perfil/completar_perfil_widget.dart';
import 'package:stark_go/pages/finanzas/finanzas_widget.dart';
import 'package:stark_go/services/bienvenida_service.dart';
import 'package:stark_go/services/dispositivo_service.dart';
import 'package:stark_go/services/mora_automatica_service.dart';
import 'dart:ui' as ui;

// ✅ CONEXIÓN LOCAL MIKROTIK
import 'package:stark_go/pages/config_mikrotik_local/conectar_mikrotik_local_widget.dart';
import 'package:stark_go/pages/config_mikrotik_local/dashboard_local_widget.dart';

// ✅ VPN WIREGUARD · ANTENAS
import 'package:stark_go/pages/vpn/vpn_widget.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:text_search/text_search.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'home_model.dart';
export 'home_model.dart';

// Los colores viven en lib/theme/app_theme.dart (AppColors · modo Día/Noche).

// ─────────────────────────────────────────────
//  TONO DE ESTADO — fondo, color, etiqueta e ícono por estado.
//  Mora = ámbar, Inactivo = gris, Activo = verde (según spec).
//  Son getters (no const) porque los colores cambian con el tema.
// ─────────────────────────────────────────────
class _EstadoTono {
  const _EstadoTono({
    required this.fondo,
    required this.contenido,
    required this.etiqueta,
    required this.icono,
  });

  final Color fondo;
  final Color contenido;
  final String etiqueta;
  final IconData icono;

  Color get borde => contenido.withOpacity(0.28);

  static _EstadoTono get activo => _EstadoTono(
        fondo: AppColors.successBg,
        contenido: AppColors.success,
        etiqueta: 'Activo',
        icono: Icons.wifi_rounded,
      );

  static _EstadoTono get mora => _EstadoTono(
        fondo: AppColors.warningBg,
        contenido: AppColors.warning,
        etiqueta: 'En mora',
        icono: Icons.warning_amber_rounded,
      );

  static _EstadoTono get inactivo => _EstadoTono(
        fondo: AppColors.neutralBg,
        contenido: AppColors.neutral,
        etiqueta: 'Inactivo',
        icono: Icons.wifi_off_rounded,
      );

  static _EstadoTono de(String? status) {
    switch (status) {
      case 'activo':
        return activo;
      case 'mora':
        return mora;
      case 'inactivo':
        return inactivo;
      default:
        return inactivo;
    }
  }
}

// ─────────────────────────────────────────────
//  AVATAR DEL CLIENTE — gris neutro por defecto, bronce en mora,
//  rojo para inactivo.
// ─────────────────────────────────────────────
class _AvatarCliente extends StatelessWidget {
  const _AvatarCliente({
    required this.inicial,
    required this.status,
    this.tamano = 52,
  });

  final String inicial;
  final String? status;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    late final Color fondo;
    late final Color texto;
    Color? borde;

    switch (status) {
      case 'mora':
        fondo = AppColors.avatarBronzeBg;
        texto = AppColors.avatarBronzeText;
        borde = AppColors.avatarBronzeBorder;
        break;
      case 'inactivo':
        fondo = AppColors.avatarRedBg;
        texto = AppColors.avatarRedText;
        borde = AppColors.avatarRedBorder;
        break;
      default:
        fondo = AppColors.avatarNeutralBg;
        texto = AppColors.avatarNeutralText;
    }

    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: fondo,
        shape: BoxShape.circle,
        border: borde == null ? null : Border.all(color: borde, width: 1.5),
      ),
      child: Center(
        child: Text(
          inicial,
          style: GoogleFonts.spaceGrotesk(
            color: texto,
            fontSize: tamano * 0.42,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  DIÁLOGO — hereda el tema Material según el modo (claro/oscuro),
//  para que no salga blanco sobre el fondo espacial ni oscuro de día.
// ─────────────────────────────────────────────
Widget _dialogoOscuro({required Widget child}) {
  return Theme(
    data: (AppTheme.instance.esOscuro ? ThemeData.dark() : ThemeData.light()).copyWith(
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceStrong,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: AppColors.textPri,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: GoogleFonts.spaceGrotesk(
          color: AppColors.textSec,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    ),
    child: child,
  );
}

/// Contenedor de carga reutilizable, con el cristal del tema.
Widget _cargando(String texto, Color color) {
  return Center(
    child: Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surfaceStrong,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: color, strokeWidth: 2.5),
        const SizedBox(height: 14),
        Text(texto, style: GoogleFonts.spaceGrotesk(color: AppColors.textPri, fontSize: 14)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────
//  HELPER
// ─────────────────────────────────────────────
double _parsePlanCliente(dynamic plan) {
  if (plan == null) return 50000.0;
  if (plan is double) return plan;
  if (plan is int) return plan.toDouble();
  if (plan is num) return plan.toDouble();
  final cleaned = plan.toString().replaceAll('.', '').replaceAll(',', '').trim();
  return double.tryParse(cleaned) ?? 50000.0;
}

// ─────────────────────────────────────────────
//  MODELO EVOLUTION INSTANCE
// ─────────────────────────────────────────────
class _EvolutionInstance {
  final String serverUrl;
  final String instanceName;
  final String apiKey;
  final String phone;
  final String status;

  const _EvolutionInstance({
    required this.serverUrl,
    required this.instanceName,
    required this.apiKey,
    required this.phone,
    required this.status,
  });

  bool get isConnected => status == 'connected' || status == 'open';
}

// ─────────────────────────────────────────────
//  MODELO STARLINK
// ─────────────────────────────────────────────
class _StarlinkInfo {
  final String id;
  final String nombre;
  final String ubicacion;
  final bool activo;
  final int clientesCount;

  const _StarlinkInfo({
    required this.id,
    required this.nombre,
    required this.ubicacion,
    required this.activo,
    required this.clientesCount,
  });

  factory _StarlinkInfo.fromDoc(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _StarlinkInfo(
      id: doc.id,
      nombre: d['nombre'] ?? 'Sin nombre',
      ubicacion: d['ubicacion'] ?? '',
      activo: d['activo'] ?? false,
      clientesCount: d['clientes_count'] ?? 0,
    );
  }
}

// ─────────────────────────────────────────────
//  CHIP DE STARLINK
// ─────────────────────────────────────────────
class _StarlinkChip extends StatelessWidget {
  final _StarlinkInfo starlink;
  final bool selected;
  final VoidCallback onTap;

  const _StarlinkChip({
    required this.starlink,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = starlink.activo ? AppColors.accent : AppColors.textSec;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withOpacity(0.18) : AppColors.surface,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected ? AppColors.accent.withOpacity(0.55) : AppColors.cardBorder,
            width: 1.4,
          ),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.accent.withOpacity(0.22), blurRadius: 12, offset: const Offset(0, 4))]
              : [BoxShadow(color: AppColors.sombra(0.35), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: selected ? AppColors.accent.withOpacity(0.22) : color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.satellite_alt_rounded, size: 15, color: selected ? AppColors.accent : color),
            ),
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: starlink.activo ? AppColors.success : AppColors.neutral,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surfaceSolid, width: 1.5),
                ),
              ),
            ),
          ]),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(
              starlink.nombre,
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.textPri,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.people_alt_rounded, size: 9, color: AppColors.textSec),
              const SizedBox(width: 3),
              Text(
                '${starlink.clientesCount}',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.textSec,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (starlink.ubicacion.isNotEmpty) ...[
                Text(
                  '  ·  ${starlink.ubicacion}',
                  style: GoogleFonts.spaceGrotesk(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ]),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CHIP "TODOS"
// ─────────────────────────────────────────────
class _AllChip extends StatelessWidget {
  final bool selected;
  final int totalClients;
  final VoidCallback onTap;

  const _AllChip({
    required this.selected,
    required this.totalClients,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withOpacity(0.18) : AppColors.surface,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected ? AppColors.accent.withOpacity(0.55) : AppColors.cardBorder,
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: selected ? AppColors.accent.withOpacity(0.22) : AppColors.sombra(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.apps_rounded, size: 15, color: selected ? AppColors.accent : AppColors.textSec),
          const SizedBox(width: 6),
          Text(
            'Todos',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.textPri,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.neutralBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$totalClients',
              style: GoogleFonts.spaceGrotesk(
                color: selected ? AppColors.accent : AppColors.textSec,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CLIENT CARD
//  · Glassmorphism real (BackdropFilter + blur)
//  · Feedback táctil (escala al presionar)
//  · Avatar neutro/bronce/rojo según estado
//  · Insignia con fondo profundo + texto de color (spec)
// ─────────────────────────────────────────────
class _ClientCard extends StatefulWidget {
  final ClientesRecord cliente;
  final VoidCallback onTap;
  final Future<void> Function() onWhatsapp;

  const _ClientCard({
    super.key,
    required this.cliente,
    required this.onTap,
    required this.onWhatsapp,
  });

  @override
  State<_ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends State<_ClientCard> {
  bool _pressed = false;

  ClientesRecord get cliente => widget.cliente;

  @override
  Widget build(BuildContext context) {
    final tono = _EstadoTono.de(cliente.status);
    final bool esMora = cliente.status == 'mora';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  // Borde de luz; en mora se tiñe de ámbar para que la
                  // fila salte a la vista sin gritar en rojo.
                  border: Border.all(
                    color: esMora ? tono.contenido.withOpacity(0.35) : AppColors.cardBorder,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.sombra(0.40),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    if (esMora)
                      BoxShadow(
                        color: tono.contenido.withOpacity(0.14),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    // ── Avatar ──
                    _AvatarCliente(
                      inicial: (cliente.nombre.isNotEmpty ? cliente.nombre[0] : '?').toUpperCase(),
                      status: cliente.status,
                    ),
                    const SizedBox(width: 12),

                    // ── Info principal ──
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(
                            child: Text(
                              '${cliente.nombre} ${cliente.apellido ?? ''}',
                              style: GoogleFonts.spaceGrotesk(
                                color: AppColors.textPri,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'CC ${cliente.cc}',
                            style: GoogleFonts.spaceGrotesk(
                              color: AppColors.textMuted,
                              fontSize: 10,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ]),
                        const SizedBox(height: 3),
                        _InfoRow(icon: Icons.agriculture_rounded, label: cliente.nombrefinca, color: AppColors.textMuted),
                        const SizedBox(height: 2),
                        _InfoRow(icon: Icons.phone_rounded, label: cliente.numero.toString(), color: AppColors.textMuted, datos: true),
                        const SizedBox(height: 2),
                        _InfoRow(icon: Icons.router_rounded, label: cliente.ipatn, color: AppColors.textMuted, datos: true),
                        if (cliente.starlinkNombre != null && cliente.starlinkNombre!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.satellite_alt_rounded, size: 11, color: AppColors.accent),
                            const SizedBox(width: 3),
                            Text(
                              cliente.starlinkNombre!,
                              style: GoogleFonts.spaceGrotesk(
                                color: AppColors.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ]),
                        ],
                        const SizedBox(height: 6),
                        ConsumoBarCard(clienteId: cliente.reference.id),
                      ]),
                    ),
                    const SizedBox(width: 8),

                    // ── Estado + acción WhatsApp ──
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: tono.fondo,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: tono.borde, width: 1),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(tono.icono, color: tono.contenido, size: 11),
                            const SizedBox(width: 4),
                            Text(
                              tono.etiqueta,
                              style: GoogleFonts.spaceGrotesk(
                                color: tono.contenido,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: widget.onWhatsapp,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.brand.withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 15),
                          ),
                        ),
                      ],
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  /// Datos técnicos (IP, teléfono): cifras tabulares para que alineen.
  final bool datos;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.color,
    this.datos = false,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.textSec,
              fontSize: 11.5,
              fontFeatures: datos ? const [FontFeature.tabularFigures()] : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]);
}

// ─────────────────────────────────────────────
//  STAT CARD
// ─────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, count;
  final IconData icon;
  final Color color;
  final Color? fondo;
  final VoidCallback? onTap;
  final bool selected;

  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    this.fondo,
    this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: selected ? (fondo ?? AppColors.neutralBg) : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? color.withOpacity(0.55) : AppColors.cardBorder,
                width: selected ? 1.6 : 1.2,
              ),
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: (fondo ?? AppColors.neutralBg),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(height: 6),
              Text(
                count,
                style: GoogleFonts.spaceGrotesk(
                  color: selected ? color : AppColors.textPri,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected) ...[
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: GoogleFonts.spaceGrotesk(
                        color: selected ? AppColors.textSec : AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ]),
          ),
        ),
      );
}

// ─────────────────────────────────────────────
//  DRAWER ITEM
// ─────────────────────────────────────────────
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final Color? iconColor;
  final String? badge;
  final Color? badgeColor;

  const _DrawerItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
    this.iconColor,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Material(
          color: active ? AppColors.neutralBg : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            splashColor: AppColors.accent.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: active ? AppColors.accent.withOpacity(0.18) : AppColors.neutralBg,
                    borderRadius: BorderRadius.circular(10),
                    border: active ? Border.all(color: AppColors.accent.withOpacity(0.45)) : null,
                  ),
                  child: Icon(icon, color: active ? AppColors.accent : (iconColor ?? AppColors.textSec), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.spaceGrotesk(
                      color: active ? AppColors.textPri : AppColors.textSec,
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.neutralBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: (badgeColor ?? AppColors.accent).withOpacity(0.45)),
                    ),
                    child: Text(
                      badge!,
                      style: GoogleFonts.spaceGrotesk(
                        color: badgeColor ?? AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 12),
                ] else
                  Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 13),
              ]),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────
//  DRAWER SECTION HEADER
// ─────────────────────────────────────────────
class _DrawerSectionHeader extends StatelessWidget {
  final String title;
  const _DrawerSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(26, 14, 26, 4),
        child: Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

// ═════════════════════════════════════════════
//  MAIN WIDGET
// ═════════════════════════════════════════════
class HomeWidget extends StatefulWidget {
  const HomeWidget({super.key});
  static String routeName = 'Home';
  static String routePath = 'home';

  @override
  State<HomeWidget> createState() => _HomeWidgetState();
}

class _HomeWidgetState extends State<HomeWidget> with TickerProviderStateMixin, WidgetsBindingObserver {
  late HomeModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  /// Key del RepaintBoundary que captura la pantalla para la transición
  /// circular Día/Noche (estilo Telegram).
  final GlobalKey _temaBoundaryKey = GlobalKey();

  late AnimationController _drawerCtrl;
  late Animation<double> _drawerAnim;
  bool _drawerOpen = false;
  bool _dragDesdeBorde = false;

  /// Versión de la app (se lee de pubspec con package_info_plus).
  String _appVersion = 'v1.8.0+18';

  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSearching = false;
  List<ClientesRecord> _searchResults = [];

  // Filtro por estado al tocar las tarjetas de resumen (null = todos).
  String? _filterEstado;

  // ── STARLINKS: Stream en tiempo real ──
  Stream<List<_StarlinkInfo>>? _starlinksStream;
  String? _selectedStarlinkId;

  bool _esAdmin = false;

  // ── Tipo de plan del usuario: 'completo' | 'vouchers' ──
  String _tipoPlanUsuario = 'completo';

  // ── Facturación ──────────────────────────────
  int _diaVencimiento = 0;
  int _diasAviso = 1;
  bool _facturacionCargada = false;

  // ── Datos empresa + plantilla recordatorio ───
  String _nombreEmpresa = 'StarkGo';
  String _nombreTitular = '';
  String _numeroNequi = '';
  String _whatsappSoporte = '';
  String _horarioSoporte = 'Lunes a viernes · 8am – 5pm';
  String _msgRecordatorio = '';

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Lee la versión real instalada.
  Future<void> _cargarVersionApp() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      final v = info.version.trim();
      final b = info.buildNumber.trim();
      if (v.isEmpty) return;
      setState(() => _appVersion = b.isEmpty ? 'v$v' : 'v$v+$b');
    } catch (_) {
      // Si falla, se mantiene el valor por defecto.
    }
  }

  /// El tema cambió (botón del drawer): se reconstruye todo con la paleta nueva.
  void _onTemaCambiado() {
    if (!mounted) return;
    AppTheme.aplicarBarraEstado();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomeModel());

    AppTheme.instance.addListener(_onTemaCambiado);
    AppTheme.instance.cargar();

    _drawerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _drawerAnim = CurvedAnimation(parent: _drawerCtrl, curve: Curves.easeInOutCubic);

    _initStarlinksStream();

    _cargarRolAdmin();
    _cargarConfigFacturacion();
    _verificarMembresia();
    _verificarBienvenida();
    _cargarVersionApp();
    _ejecutarMoraAutomatica();

    // LÍMITE DE TELÉFONOS (2 por cuenta).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      DispositivoService.revisarAlVolver(onBloqueado: () {
        if (mounted) context.goNamed(DispositivoBloqueadoWidget.routeName);
      });
    });

    WidgetsBinding.instance.addObserver(this);

    AppTheme.aplicarBarraEstado();
  }

  @override
  void dispose() {
    AppTheme.instance.removeListener(_onTemaCambiado);
    WidgetsBinding.instance.removeObserver(this);
    _drawerCtrl.dispose();
    _searchCtrl.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verificarMembresia();
      DispositivoService.revisarAlVolver(onBloqueado: () {
        if (mounted) context.goNamed(DispositivoBloqueadoWidget.routeName);
      });
    }
  }

  // ──────────────────────────────────────────
  //  VERIFICAR MEMBRESÍA AL ENTRAR AL HOME
  // ──────────────────────────────────────────
  Future<void> _verificarMembresia() async {
    if (_uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('user').doc(_uid).get();
      final data = doc.data();
      if (data == null) return;

      String tipo = '';
      final planMap = data['plan'];
      final planMembresia = (data['planMembresia'] ?? '').toString().toLowerCase();

      const planesCompletos = {'1m', '3m', '6m', '1a'};
      const planesVouchers = {'v1m', 'v3m', 'v6m', 'v1a'};

      if (planMap is Map) {
        final tipoRaw = (planMap['tipo'] ?? '').toString().toLowerCase();
        if (tipoRaw == 'vouchers') {
          tipo = 'vouchers';
        } else if (tipoRaw == 'completo') {
          tipo = 'completo';
        } else if (planesVouchers.contains(planMembresia)) {
          tipo = 'vouchers';
        } else if (planesCompletos.contains(planMembresia)) {
          tipo = 'completo';
        } else {
          tipo = '';
        }
      } else if (planesVouchers.contains(planMembresia)) {
        tipo = 'vouchers';
      } else if (planesCompletos.contains(planMembresia)) {
        tipo = 'completo';
      } else {
        tipo = '';
      }

      if (tipo.isEmpty) {
        if (mounted) {
          context.goNamed(ActivarMembresiaWidget.routeName);
        }
        return;
      }

      if (mounted && tipo != _tipoPlanUsuario) {
        setState(() => _tipoPlanUsuario = tipo);
      }

      final ts = data['fechaVencimiento'] as Timestamp?;
      if (ts != null && DateTime.now().isAfter(ts.toDate())) {
        if (mounted) {
          context.goNamed(RenovarMembresiaWidget.routeName);
        }
      }
    } catch (_) {}
  }

  // ──────────────────────────────────────────
  //  BIENVENIDA — se muestra UNA sola vez tras pagar
  // ──────────────────────────────────────────
  Future<void> _verificarBienvenida() async {
    if (_uid.isEmpty) return;
    try {
      final bienvenida = await BienvenidaService.consumirBienvenida();
      if (bienvenida == null || !mounted) return;

      final tipo = (bienvenida['tipo'] ?? 'completo').toString();
      final duracion = (bienvenida['duracion'] ?? '').toString();
      final precio = (bienvenida['precio'] ?? 0);
      final sublabel = (bienvenida['sublabel'] ?? '').toString();

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      _showBienvenidaDialog(tipo: tipo, duracion: duracion, precio: precio, sublabel: sublabel);
    } catch (_) {}
  }

  void _showBienvenidaDialog({
    required String tipo,
    required String duracion,
    required dynamic precio,
    required String sublabel,
  }) {
    final esCompleto = tipo == 'completo';
    final color = esCompleto ? AppColors.success : AppColors.accent;
    final fondoTono = esCompleto ? AppColors.successBg : AppColors.neutralBg;
    final icono = esCompleto ? Icons.workspace_premium_rounded : Icons.vpn_key_rounded;
    const titulo = '¡Bienvenido a StarkGo!';
    final precioFmt = precio is num ? '\$${precio.toStringAsFixed(0)} USD' : '\$$precio USD';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceStrong,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [BoxShadow(color: AppColors.sombra(0.5), blurRadius: 30, offset: const Offset(0, 12))],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Ícono ──
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: fondoTono,
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.45), width: 1.5),
                    boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 8))],
                  ),
                  child: Icon(icono, color: color, size: 34),
                ),
                const SizedBox(height: 18),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(color: AppColors.textPri, fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  esCompleto
                      ? 'Tu membresía de acceso completo está activa. Ya puedes gestionar tus clientes, planes, informes y mucho más.'
                      : 'Tu membresía de solo vouchers está activa. Ya puedes gestionar tus vouchers y el módulo MikroTik Local.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(color: AppColors.textSec, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 18),

                // ── Card de lo que compró ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: fondoTono,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.28)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      'Lo que compraste',
                      style: GoogleFonts.spaceGrotesk(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    _bienvenidaFila(Icons.workspace_premium_rounded, 'Plan', duracion, color),
                    _bienvenidaFila(Icons.attach_money_rounded, 'Monto', precioFmt, color),
                    _bienvenidaFila(Icons.category_rounded, 'Tipo', esCompleto ? 'Acceso completo' : 'Solo vouchers', color),
                    if (sublabel.isNotEmpty) _bienvenidaFila(Icons.info_outline_rounded, 'Detalle', sublabel, color),
                  ]),
                ),
                const SizedBox(height: 18),

                // ── Introducción a las funciones ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.neutralBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      '¿Qué puedes hacer ahora?',
                      style: GoogleFonts.spaceGrotesk(color: AppColors.textPri, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    if (esCompleto) ...[
                      _bienvenidaFuncion(Icons.people_alt_rounded, 'Gestiona tus clientes y su estado de pago'),
                      _bienvenidaFuncion(Icons.satellite_alt_rounded, 'Administra tus Starlinks y cobros'),
                      _bienvenidaFuncion(Icons.chat_rounded, 'Envía recordatorios de pago por WhatsApp'),
                      _bienvenidaFuncion(Icons.wifi, 'Conecta tu MikroTik y crea vouchers'),
                      _bienvenidaFuncion(Icons.bar_chart_rounded, 'Genera informes y reportes de consumo'),
                    ] else ...[
                      _bienvenidaFuncion(Icons.wifi, 'Conecta tu MikroTik Local'),
                      _bienvenidaFuncion(Icons.vpn_key_rounded, 'Crea fichas y vouchers de acceso'),
                      _bienvenidaFuncion(Icons.design_services_rounded, 'Personaliza el portal WiFi'),
                    ],
                  ]),
                ),
                const SizedBox(height: 20),

                // ── Botón ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: AppColors.brand.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 6))],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.pop(dialogContext),
                        child: Center(
                          child: Text(
                            'Empezar',
                            style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bienvenidaFila(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 8),
        Text('$label:', style: GoogleFonts.spaceGrotesk(color: AppColors.textSec, fontSize: 12)),
        const Spacer(),
        Text(value, style: GoogleFonts.spaceGrotesk(color: AppColors.textPri, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _bienvenidaFuncion(IconData icon, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.surfaceSolid,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Icon(icon, color: AppColors.accent, size: 13),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(texto, style: GoogleFonts.spaceGrotesk(color: AppColors.textSec, fontSize: 12, height: 1.3)),
        ),
      ]),
    );
  }

  // ──────────────────────────────────────────
  //  STREAM STARLINKS — tiempo real
  // ──────────────────────────────────────────
  void _initStarlinksStream() {
    if (_uid.isEmpty) return;
    _starlinksStream = FirebaseFirestore.instance
        .collection('starlinks')
        .where('propietarioUid', isEqualTo: _uid)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _StarlinkInfo.fromDoc(d)).toList());
  }

  // ──────────────────────────────────────────
  //  CARGAR ROL ADMIN
  // ──────────────────────────────────────────
  Future<void> _cargarRolAdmin() async {
    if (_uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('user').doc(_uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() => _esAdmin = data['admin'] == true);
      }
    } catch (e) {
      debugPrint('[StarkGo] Error leyendo rol admin: $e');
    }
  }

  // ──────────────────────────────────────────
  //  CARGAR CONFIG FACTURACIÓN + EMPRESA
  // ──────────────────────────────────────────
  Future<void> _cargarConfigFacturacion() async {
    if (_uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('config_empresa').doc(_uid).get();
      if (doc.exists && mounted) {
        final d = doc.data() as Map<String, dynamic>;
        setState(() {
          _diaVencimiento = (d['diaVencimiento'] as int?) ?? 0;
          _diasAviso = (d['diasAviso'] as int?) ?? 1;
          _nombreEmpresa = (d['nombreEmpresa'] ?? 'StarkGo').toString();
          _nombreTitular = (d['nombreTitular'] ?? '').toString();
          _numeroNequi = (d['numeroNequi'] ?? '').toString();
          _whatsappSoporte = (d['whatsappSoporte'] ?? '').toString();
          _horarioSoporte = (d['horarioSoporte'] ?? 'Lunes a viernes · 8am – 5pm').toString();
          _msgRecordatorio = (d['msgRecordatorio'] ?? '').toString();
          _facturacionCargada = true;
        });
      } else {
        if (mounted) setState(() => _facturacionCargada = true);
      }
    } catch (e) {
      debugPrint('[StarkGo] Error leyendo config_empresa: $e');
      if (mounted) setState(() => _facturacionCargada = true);
    }
  }

  // ──────────────────────────────────────────
  //  MORA AUTOMÁTICA
  // ──────────────────────────────────────────
  Future<void> _ejecutarMoraAutomatica() async {
    if (_uid.isEmpty) return;
    try {
      await MoraAutomaticaService.ejecutarMoraAutomatica();
    } catch (e) {
      debugPrint('[StarkGo] Error ejecutando mora automática: $e');
    }
  }

  void _toggleDrawer() {
    setState(() => _drawerOpen = !_drawerOpen);
    _drawerOpen ? _drawerCtrl.forward() : _drawerCtrl.reverse();
    FFAppState().drawer = _drawerOpen;
  }

  void _onDragInicio(DragStartDetails d) {
    if (!_drawerOpen && d.globalPosition.dx <= 56) {
      _dragDesdeBorde = true;
    }
  }

  void _onDragFin(DragEndDetails d) {
    final vel = d.primaryVelocity ?? 0;
    if (_dragDesdeBorde && !_drawerOpen && vel > 250) {
      _toggleDrawer();
    } else if (_drawerOpen && vel < -250) {
      _toggleDrawer();
    }
    _dragDesdeBorde = false;
  }

  void _onSearchChanged(String query, List<ClientesRecord> allClients) {
    EasyDebounce.debounce('search', const Duration(milliseconds: 400), () {
      if (query.trim().isEmpty) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
        return;
      }
      final base = _selectedStarlinkId != null ? allClients.where((c) => c.starlinkId == _selectedStarlinkId).toList() : allClients;
      final results = TextSearch(
        base.map((r) => TextSearchItem.fromTerms(r, [r.nombre, r.apellido ?? '', r.nombrefinca, r.ipatn])).toList(),
      ).search(query).map((r) => r.object).toList();
      setState(() {
        _isSearching = true;
        _searchResults = results;
      });
    });
  }

  // ──────────────────────────────────────────
  //  EVOLUTION API — obtener instancia
  // ──────────────────────────────────────────
  Future<_EvolutionInstance?> _obtenerInstanciaEvolution() async {
    if (_uid.isEmpty) return null;
    try {
      final snap = await FirebaseFirestore.instance.collection('whatsapp_instances').where('uid', isEqualTo: _uid).limit(1).get();
      if (snap.docs.isEmpty) return null;
      final d = snap.docs.first.data();
      return _EvolutionInstance(
        serverUrl: d['serverUrl'] ?? '',
        instanceName: d['instanceName'] ?? '',
        apiKey: d['apiKey'] ?? '',
        phone: d['phone'] ?? '',
        status: d['status'] ?? '',
      );
    } catch (e) {
      debugPrint('[StarkGo] Error leyendo whatsapp_instances: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────
  //  ENVIAR WHATSAPP
  // ──────────────────────────────────────────
  Future<void> _sendWhatsapp(
    BuildContext ctx,
    String nombre,
    dynamic numeroRaw,
    double planCliente,
    DocumentReference clienteRef,
  ) async {
    if (_diaVencimiento == 0) {
      _showFechaNoConfiguradaDialog();
      return;
    }

    final ok = await showDialog<bool>(
          context: ctx,
          builder: (_) => _dialogoOscuro(
            child: AlertDialog(
              title: const Text('Reporte de pago'),
              content: Text('¿Enviar recordatorio de pago a $nombre por WhatsApp?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: AppColors.textSec)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('Enviar recordatorio', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!ok || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _cargando('Enviando mensaje…', AppColors.brand),
    );

    _EvolutionInstance? instancia;
    try {
      instancia = await _obtenerInstanciaEvolution();
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showErrorDialog('Error de conexión', 'No se pudo consultar la configuración de WhatsApp.\n\nDetalle: $e');
      return;
    }

    if (instancia == null) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showNoInstanceDialog();
      return;
    }
    if (!instancia.isConnected) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showErrorDialog('WhatsApp desconectado', 'Tu instancia (${instancia.instanceName}) no está conectada.\nEstado: ${instancia.status}');
      return;
    }

    String codigoPais = '57';
    try {
      final clienteSnap = await clienteRef.get();
      final clienteData = clienteSnap.data() as Map<String, dynamic>?;
      final raw = (clienteData?['codigoPais'] ?? '+57').toString();
      codigoPais = raw.replaceAll('+', '').trim();
      if (codigoPais.isEmpty) codigoPais = '57';
    } catch (e) {
      debugPrint('[StarkGo] Error leyendo codigoPais del cliente: $e');
    }

    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    final String numeroDestino = _normalizarNumero(numeroRaw, codigoPais);
    if (numeroDestino.isEmpty) {
      _showErrorDialog('Número inválido', 'El cliente no tiene un número válido registrado.');
      return;
    }

    final now = DateTime.now();
    final diasParaVencer = _diaVencimiento - now.day;

    String estado;
    if (diasParaVencer == 0) {
      estado = '🔴 *Estado:* Vence HOY';
    } else if (diasParaVencer == 1) {
      estado = '🔴 *Estado:* Vence mañana, día $_diaVencimiento';
    } else if (diasParaVencer > 1) {
      estado = '🟡 *Estado:* Vence en $diasParaVencer días (día $_diaVencimiento)';
    } else {
      estado = '🔴 *Estado:* Venció el día $_diaVencimiento (${diasParaVencer.abs()} días de retraso)';
    }

    final valorFmt = _formatearPesos(planCliente);

    String mensaje;
    if (_msgRecordatorio.trim().isEmpty) {
      mensaje = '📢 *$_nombreEmpresa — Recordatorio de Pago*\n\n'
          'Hola *$nombre*, te recordamos que tu factura vence el día '
          '$_diaVencimiento del mes.\n\n'
          '💳 *Valor:* $valorFmt\n'
          '$estado\n\n'
          '💜 Nequi: $_numeroNequi · $_nombreTitular\n'
          'Soporte: $_whatsappSoporte\n$_horarioSoporte\n\n'
          '— *Equipo $_nombreEmpresa* 🌐';
    } else {
      mensaje = _msgRecordatorio
          .replaceAll('{nombre}', nombre)
          .replaceAll('{plan}', '')
          .replaceAll('{valor}', valorFmt)
          .replaceAll('{dia}', '$_diaVencimiento')
          .replaceAll('{estado}', estado)
          .replaceAll('{empresa}', _nombreEmpresa)
          .replaceAll('{nequi}', _numeroNequi)
          .replaceAll('{titular}', _nombreTitular)
          .replaceAll('{soporte}', _whatsappSoporte)
          .replaceAll('{horario}', _horarioSoporte);
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _cargando('Enviando mensaje…', AppColors.brand),
      );
    }

    try {
      final url = Uri.parse('${instancia.serverUrl}/message/sendText/${instancia.instanceName}');
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'apikey': instancia.apiKey,
            },
            body: jsonEncode({'number': numeroDestino, 'text': mensaje}),
          )
          .timeout(const Duration(seconds: 20));

      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Al enviar el recordatorio, el cliente pasa a mora (ámbar).
        // Registrar el pago lo devuelve a activo (verde).
        try {
          await clienteRef.update({
            'status': 'mora',
            'fechaPasoMora': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('[StarkGo] Error marcando cliente en mora: $e');
        }
        _showSuccessDialog(nombre, numeroDestino);
      } else {
        String detalle = '';
        try {
          final body = jsonDecode(response.body);
          detalle = body['message'] ?? body['error'] ?? response.body;
        } catch (_) {
          detalle = response.body;
        }
        _showErrorDialog('Error al enviar (${response.statusCode})', 'No se pudo enviar el mensaje.\n\nDetalle: $detalle');
      }
    } on Exception catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      _showErrorDialog('Error de red', 'No se pudo conectar con Evolution API.\n\nDetalle: $e');
    }
  }

  // ──────────────────────────────────────────
  //  SOPORTE WHATSAPP
  // ──────────────────────────────────────────
  Future<void> _abrirSoporteWhatsApp() async {
    const numero = '573137756497';
    const mensaje = 'Hola, Ing. Fabián 👋. Quiero que me ayudes a configurar y '
        'conectar mi app StarkGo con MikroTik. Quedo atento a tu ayuda. '
        '¡Muchas gracias!';
    final uri = Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent(mensaje)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
        );
      }
    }
  }

  // ──────────────────────────────────────────
  //  HELPERS
  // ──────────────────────────────────────────
  String _normalizarNumero(dynamic raw, String codigoPais) {
    if (raw == null) return '';
    String num = raw.toString().replaceAll(RegExp(r'[^0-9]'), '');
    if (num.isEmpty) return '';

    final prefijo = codigoPais.replaceAll(RegExp(r'[^0-9]'), '');
    if (prefijo.isEmpty) return '';

    if (num.length < 7) return '';

    if (num.startsWith(prefijo)) return num;

    if (num.length >= 11) return num;

    return '$prefijo$num';
  }

  String _formatearPesos(double valor) {
    final partes = valor.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    int count = 0;
    for (int i = partes.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(partes[i]);
      count++;
    }
    return '\$ ${buffer.toString().split('').reversed.join('')}';
  }

  // ──────────────────────────────────────────
  //  MARCAR TODOS EN MORA
  // ──────────────────────────────────────────
  Future<void> _marcarTodosEnMora(List<ClientesRecord> allClients) async {
    final base = _selectedStarlinkId != null ? allClients.where((c) => c.starlinkId == _selectedStarlinkId) : allClients;
    final clientesActivos = base.where((c) => c.status == 'activo').toList();

    if (clientesActivos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay clientes activos para marcar en mora.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => _dialogoOscuro(
            child: AlertDialog(
              title: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.warningBg, shape: BoxShape.circle),
                  child: Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Marcar en mora')),
              ]),
              content: Text(
                '¿Marcar ${clientesActivos.length} cliente${clientesActivos.length != 1 ? 's' : ''} '
                'activo${clientesActivos.length != 1 ? 's' : ''} como en mora?\n\n'
                'Solo cambia su estado. No se corta el internet de nadie.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: AppColors.textSec)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: AppTheme.instance.esOscuro ? const Color(0xFF451A03) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Marcar todos', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!ok || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _cargando('Actualizando estados…', AppColors.warning),
    );

    try {
      const chunkSize = 450;
      for (var i = 0; i < clientesActivos.length; i += chunkSize) {
        final chunk = clientesActivos.skip(i).take(chunkSize);
        final batch = FirebaseFirestore.instance.batch();
        for (final c in chunk) {
          batch.update(c.reference, {
            'status': 'mora',
            'moraDesde': DateTime.now(),
          });
        }
        await batch.commit();
      }

      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${clientesActivos.length} clientes marcados en mora.')),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showErrorDialog('Error al actualizar', 'No se pudo marcar a los clientes en mora.\n\nDetalle: $e');
    }
  }

  // ──────────────────────────────────────────
  //  MARCAR TODOS EN ACTIVO
  // ──────────────────────────────────────────
  Future<void> _marcarTodosActivos(List<ClientesRecord> allClients) async {
    final base = _selectedStarlinkId != null ? allClients.where((c) => c.starlinkId == _selectedStarlinkId) : allClients;
    final clientesEnMora = base.where((c) => c.status == 'mora').toList();

    if (clientesEnMora.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay clientes en mora para reactivar.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => _dialogoOscuro(
            child: AlertDialog(
              title: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.successBg, shape: BoxShape.circle),
                  child: Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Marcar como activos')),
              ]),
              content: Text(
                '¿Marcar ${clientesEnMora.length} cliente${clientesEnMora.length != 1 ? 's' : ''} '
                'en mora como activo?\n\n'
                'Úsalo solo si marcaste en mora por error. No reconecta el internet de nadie.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: AppColors.textSec)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Reactivar todos', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!ok || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _cargando('Actualizando estados…', AppColors.success),
    );

    try {
      const chunkSize = 450;
      for (var i = 0; i < clientesEnMora.length; i += chunkSize) {
        final chunk = clientesEnMora.skip(i).take(chunkSize);
        final batch = FirebaseFirestore.instance.batch();
        for (final c in chunk) {
          batch.update(c.reference, {
            'status': 'activo',
            'moraDesde': FieldValue.delete(),
          });
        }
        await batch.commit();
      }

      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${clientesEnMora.length} clientes reactivados.')),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showErrorDialog('Error al actualizar', 'No se pudo reactivar a los clientes.\n\nDetalle: $e');
    }
  }

  // ── Dialogs ──────────────────────────────────
  void _showFechaNoConfiguradaDialog() {
    showDialog(
      context: context,
      builder: (_) => _dialogoOscuro(
        child: AlertDialog(
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.warningBg, shape: BoxShape.circle),
              child: Icon(Icons.calendar_today_rounded, color: AppColors.warning, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Facturación sin configurar')),
          ]),
          content: const Text(
            'Antes de enviar mensajes de pago, configura el día de vencimiento y los datos de tu empresa.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: AppColors.textSec)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.settings_rounded, size: 16),
              label: Text('Configurar', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
              onPressed: () async {
                Navigator.pop(context);
                await context.pushNamed(ConfigFacturacionWidget.routeName);
                _cargarConfigFacturacion();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNoInstanceDialog() {
    showDialog(
      context: context,
      builder: (_) => _dialogoOscuro(
        child: AlertDialog(
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.warningBg, shape: BoxShape.circle),
              child: Icon(Icons.chat_bubble_outline_rounded, color: AppColors.warning, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('WhatsApp sin configurar')),
          ]),
          content: const Text(
            'No tienes una instancia de Evolution API registrada. Configura WhatsApp para poder enviar mensajes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: AppColors.textSec)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.settings_rounded, size: 16),
              label: Text('Configurar WhatsApp', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
              onPressed: () {
                Navigator.pop(context);
                context.pushNamed(ConfigEvolutionApiWidget.routeName);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(String nombre, String numero) {
    showDialog(
      context: context,
      builder: (_) => _dialogoOscuro(
        child: AlertDialog(
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.successBg, shape: BoxShape.circle),
              child: Icon(FontAwesomeIcons.whatsapp, color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Mensaje enviado')),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('El recordatorio salió sin problemas.'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.28)),
              ),
              child: Row(children: [
                Icon(Icons.person_rounded, size: 16, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nombre, style: GoogleFonts.spaceGrotesk(color: AppColors.textPri, fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('+$numero',
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.textSec,
                          fontSize: 11,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        )),
                  ]),
                ),
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
              ]),
            ),
          ]),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text('Listo', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String titulo, String mensaje) {
    showDialog(
      context: context,
      builder: (_) => _dialogoOscuro(
        child: AlertDialog(
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.avatarRedBg, shape: BoxShape.circle),
              child: Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(titulo)),
          ]),
          content: Text(mensaje),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neutralBg,
                foregroundColor: AppColors.textPri,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.cardBorder),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text('Entendido', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cerrarSesion() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => _dialogoOscuro(
            child: AlertDialog(
              title: const Text('Cerrar sesión'),
              content: const Text('¿Seguro que quieres cerrar sesión?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancelar', style: GoogleFonts.spaceGrotesk(color: AppColors.textSec)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Cerrar sesión', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (ok && mounted) {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ));
      await authManager.signOut();
      if (mounted) {
        context.goNamedAuth(LoginWidget.routeName, context.mounted);
      }
    }
  }

  // ══════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return StreamBuilder<List<ClientesRecord>>(
      stream: queryClientesRecord(
        queryBuilder: (q) => q.where('propietarioUid', isEqualTo: _uid),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Stack(children: [
              const AppBackground(),
              Center(
                child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2.5),
              ),
            ]),
          );
        }

        final allClients = snapshot.data!;
        final filteredByStarlink =
            _selectedStarlinkId != null ? allClients.where((c) => c.starlinkId == _selectedStarlinkId).toList() : allClients;
        final baseList = _isSearching ? _searchResults : filteredByStarlink;
        final displayList = _filterEstado == null ? baseList : baseList.where((c) => c.status == _filterEstado).toList();

        final moraCount = filteredByStarlink.where((c) => c.status == 'mora').length;
        final inactivoCount = filteredByStarlink.where((c) => c.status == 'inactivo').length;
        final activoCount = filteredByStarlink.where((c) => c.status == 'activo').length;

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            if (_drawerOpen) _toggleDrawer();
          },
          onHorizontalDragStart: _onDragInicio,
          onHorizontalDragEnd: _onDragFin,
          onHorizontalDragCancel: () {
            _dragDesdeBorde = false;
          },
          // El RepaintBoundary permite "fotografiar" la pantalla para la
          // transición circular Día/Noche del botón del drawer.
          child: RepaintBoundary(
            key: _temaBoundaryKey,
            child: Scaffold(
              key: scaffoldKey,
              backgroundColor: AppColors.background,
              // ── Botón principal: soporte por WhatsApp ──
              floatingActionButton: FloatingActionButton.extended(
                onPressed: _abrirSoporteWhatsApp,
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                icon: const Icon(FontAwesomeIcons.whatsapp, size: 20),
                label: Text(
                  'Soporte',
                  style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              body: Stack(children: [
                _buildDrawer(context, allClients),
                AnimatedBuilder(
                  animation: _drawerAnim,
                  builder: (ctx, child) {
                    final slide = _drawerAnim.value * 270.0;
                    final scale = 1.0 - _drawerAnim.value * 0.07;
                    final radius = _drawerAnim.value * 28.0;
                    return Transform(
                      transform: Matrix4.identity()
                        ..translate(slide)
                        ..scale(scale),
                      alignment: Alignment.centerLeft,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(radius),
                        // El fondo (espacial de noche / cielo de día) va DENTRO
                        // del recorte animado junto con el contenido, para que
                        // tape al drawer cuando está cerrado.
                        child: Stack(children: [
                          const AppBackground(),
                          child!,
                        ]),
                      ),
                    );
                  },
                  child: _buildMainContent(
                    context,
                    allClients,
                    filteredByStarlink,
                    activoCount,
                    moraCount,
                    inactivoCount,
                    displayList,
                  ),
                ),
                if (_drawerOpen)
                  Positioned(
                    left: 290,
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: _toggleDrawer,
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox.expand(),
                    ),
                  ),
              ]),
            ),
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────
  //  DRAWER
  // ──────────────────────────────────────────
  Widget _buildDrawer(BuildContext context, List<ClientesRecord> allClients) {
    final moraCountDrawer = allClients.where((c) => c.status == 'mora').length;
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: 290,
      child: Container(
        decoration: BoxDecoration(color: AppColors.drawerBg),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                child: FutureBuilder<DocumentSnapshot>(
                  future: _uid.isEmpty ? null : FirebaseFirestore.instance.collection('user').doc(_uid).get(),
                  builder: (context, snap) {
                    final nombre =
                        snap.hasData && snap.data!.exists ? (snap.data!.data() as Map<String, dynamic>)['nombre'] ?? 'Usuario' : 'Usuario';
                    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
                    return Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.avatarNeutralBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            inicial,
                            style: GoogleFonts.spaceGrotesk(
                              color: AppColors.avatarNeutralText,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceGrotesk(
                                  color: AppColors.textPri,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                )),
                            const SizedBox(height: 2),
                            Text(_nombreEmpresa.isEmpty ? 'Panel de gestión' : _nombreEmpresa,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceGrotesk(color: AppColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                      // ── Botón Día / Noche (estilo Telegram) ──
                      const SizedBox(width: 8),
                      ThemeToggleButton(boundaryKey: _temaBoundaryKey),
                    ]);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Divider(color: AppColors.divider, height: 1),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Plan "Solo Vouchers": solo el módulo MikroTik ──
                      if (_tipoPlanUsuario != 'vouchers') ...[
                        _DrawerSectionHeader(title: 'Principal'),
                        _DrawerItem(icon: Icons.dashboard_rounded, label: 'Inicio', active: true, onTap: _toggleDrawer),
                        _DrawerItem(
                          icon: Icons.people_alt_rounded,
                          label: 'Clientes',
                          badge: moraCountDrawer > 0 ? '$moraCountDrawer en mora' : null,
                          badgeColor: AppColors.warning,
                          onTap: () {
                            _toggleDrawer();
                            context.pushNamed(ListaclientesWidget.routeName);
                          },
                        ),
                        _DrawerItem(
                          icon: Icons.add_card_rounded,
                          label: 'Planes',
                          onTap: () {
                            _toggleDrawer();
                            context.pushNamed(PlanesWidget.routeName);
                          },
                        ),
                        _DrawerItem(
                          icon: Icons.cable_rounded,
                          label: 'Clientes PPPoE',
                          iconColor: AppColors.accent,
                          onTap: () {
                            _toggleDrawer();
                            context.pushNamed(PppoeClientesWidget.routeName);
                          },
                        ),
                        _DrawerItem(
                          icon: Icons.router_rounded,
                          label: 'Equipos',
                          onTap: () {
                            _toggleDrawer();
                            context.pushNamed(ListaEquiposWidget.routeName);
                          },
                        ),
                        // 📌 Ver la IP que el MikroTik le dio a una antena
                        // (leases DHCP) y usarla al crear el cliente.
                        _DrawerItem(
                          icon: Icons.wifi_find_rounded,
                          label: 'IPs del MikroTik',
                          iconColor: AppColors.accent,
                          onTap: () {
                            _toggleDrawer();
                            context.pushNamed(LeasesMikrotikWidget.routeName);
                          },
                        ),
                        _DrawerItem(
                          icon: Icons.satellite_alt_rounded,
                          label: 'Starlinks',
                          onTap: () {
                            _toggleDrawer();
                            context.pushNamed(ListaStarlinksWidget.routeName);
                          },
                        ),
                        _DrawerItem(
                          icon: Icons.satellite_alt_rounded,
                          label: 'Mis Starlinks · Cobros',
                          iconColor: AppColors.success,
                          onTap: () {
                            _toggleDrawer();
                            context.pushNamed(ListaStarlinksClientesWidget.routeName);
                          },
                        ),
                        _DrawerItem(
                          icon: Icons.bar_chart_rounded,
                          label: 'Informes',
                          onTap: () {
                            _toggleDrawer();
                            context.pushNamed(InformesWidget.routeName);
                          },
                        ),
                        _DrawerItem(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Mis Finanzas',
                          iconColor: AppColors.stream1,
                          badge: 'Nuevo',
                          badgeColor: AppColors.stream1,
                          onTap: () {
                            _toggleDrawer();
                            context.pushNamed(FinanzasWidget.routeName);
                          },
                        ),
                        _DrawerItem(
                          icon: Icons.play_circle_rounded,
                          label: 'Tutorial',
                          iconColor: AppColors.stream2,
                          onTap: () {
                            _toggleDrawer();
                            context.pushNamed(TutorialWidget.routeName);
                          },
                        ),
                        if (_esAdmin) ...[
                          _DrawerSectionHeader(title: 'Administración'),
                          _DrawerItem(
                            icon: Icons.person_add_rounded,
                            label: 'Crear operador',
                            iconColor: AppColors.stream3,
                            badge: 'Admin',
                            badgeColor: AppColors.stream3,
                            onTap: () {
                              _toggleDrawer();
                              context.pushNamed(CrearCuentaWidget.routeName);
                            },
                          ),
                          _DrawerItem(
                            icon: Icons.people_rounded,
                            label: 'Lista operadores',
                            iconColor: AppColors.stream3,
                            badge: 'Admin',
                            badgeColor: AppColors.stream3,
                            onTap: () {
                              _toggleDrawer();
                              context.pushNamed(ListaOperadoresWidget.routeName);
                            },
                          ),
                        ],
                      ],
                      _DrawerSectionHeader(title: 'MikroTik'),
                      _DrawerItem(
                        icon: Icons.wifi,
                        label: 'Conexión Local',
                        iconColor: FFAppState().isConnectedLocal ? AppColors.success : AppColors.accent,
                        badge: FFAppState().isConnectedLocal ? 'Conectado' : null,
                        badgeColor: AppColors.success,
                        onTap: () {
                          _toggleDrawer();
                          if (FFAppState().isConnectedLocal && FFAppState().mikrotikLocalApi != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DashboardLocalWidget(
                                  api: FFAppState().mikrotikLocalApi!,
                                  nombreRouter: FFAppState().nombreRouterLocal,
                                ),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ConectarMikrotikLocalWidget(),
                              ),
                            );
                          }
                        },
                      ),
                      // ── MikroTik & VPN: SIEMPRE visible (también con el plan
                      //    "Solo Vouchers"). Así el usuario puede AJUSTAR su
                      //    MikroTik y VERLO REMOTAMENTE igual que con el plan
                      //    completo. Toda la configuración se guarda en
                      //    Firebase: config_mikrotik/{uid} y vpn_config/{uid}.
                      _DrawerSectionHeader(title: 'MikroTik & VPN'),
                      _DrawerItem(
                        icon: Icons.vpn_lock_rounded,
                        label: 'VPN · Antenas',
                        iconColor: AppColors.primary,
                        onTap: () {
                          _toggleDrawer();
                          context.pushNamed(VpnWidget.routeName);
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.router_outlined,
                        label: 'Config. MikroTik VPS',
                        iconColor: AppColors.stream3,
                        onTap: () {
                          _toggleDrawer();
                          context.pushNamed(ConfigMikroTikWidget.routeName);
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.speed_rounded,
                        label: 'Velocidades MikroTik',
                        iconColor: AppColors.accent,
                        onTap: () {
                          _toggleDrawer();
                          context.pushNamed(ConfigVelocidadesWidget.routeName);
                        },
                      ),
                      if (_tipoPlanUsuario != 'vouchers') ...[
                        _DrawerSectionHeader(title: 'Configuración'),
                        _DrawerItem(
                          icon: Icons.chat_rounded,
                          label: 'WhatsApp · Evolution',
                          iconColor: AppColors.brand,
                          onTap: () {
                            _toggleDrawer();
                            context.pushNamed(ConfigEvolutionApiWidget.routeName);
                          },
                        ),
                        _DrawerItem(
                          icon: Icons.calendar_month_rounded,
                          label: 'Facturación & Mensajes',
                          iconColor: AppColors.primary,
                          badge: _facturacionCargada && _diaVencimiento == 0 ? 'Pendiente' : null,
                          badgeColor: AppColors.warning,
                          onTap: () async {
                            _toggleDrawer();
                            await context.pushNamed(ConfigFacturacionWidget.routeName);
                            _cargarConfigFacturacion();
                          },
                        ),
                      ],
                      _DrawerSectionHeader(title: 'Cuenta'),
                      _DrawerItem(
                        icon: Icons.person_rounded,
                        label: 'Mi Perfil',
                        iconColor: AppColors.primary,
                        onTap: () {
                          _toggleDrawer();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CompletarPerfilWidget()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Divider(color: AppColors.divider, height: 1),
              ),
              _DrawerItem(icon: Icons.logout_rounded, label: 'Cerrar sesión', iconColor: AppColors.danger, onTap: _cerrarSesion),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(_appVersion, style: GoogleFonts.spaceGrotesk(color: AppColors.textMuted, fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  MAIN CONTENT
  // ──────────────────────────────────────────
  Widget _buildMainContent(
    BuildContext context,
    List<ClientesRecord> allClients,
    List<ClientesRecord> filteredClients,
    int activoCount,
    int moraCount,
    int inactivoCount,
    List<ClientesRecord> displayList,
  ) {
    if (_tipoPlanUsuario == 'vouchers') {
      return Container(
        color: AppColors.surfaceDim,
        child: SafeArea(
          top: false,
          child: Column(children: [
            _buildTopBarPro(context, allClients),
            const SizedBox(height: 4),
            Expanded(child: _buildVouchersHome()),
          ]),
        ),
      );
    }

    return Container(
      color: AppColors.surfaceDim,
      child: SafeArea(
        top: false,
        child: Column(children: [
          _buildTopBarPro(context, allClients),
          const SizedBox(height: 4),
          if (_facturacionCargada && _diaVencimiento == 0) _buildFechaAlertBanner(),
          _buildStatsRow(filteredClients.length, activoCount, moraCount, inactivoCount),
          const SizedBox(height: 10),
          StreamBuilder<List<_StarlinkInfo>>(
            stream: _starlinksStream,
            builder: (context, slSnap) {
              final starlinks = slSnap.data ?? [];
              if (_selectedStarlinkId != null && !starlinks.any((s) => s.id == _selectedStarlinkId)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _selectedStarlinkId = null;
                      _isSearching = false;
                      _searchResults = [];
                      _searchCtrl.clear();
                    });
                  }
                });
              }
              if (starlinks.isEmpty) {
                return const SizedBox.shrink();
              }
              return _buildStarlinkChipsFromList(allClients, starlinks);
            },
          ),
          const SizedBox(height: 8),
          _buildSearchBar(context, filteredClients),
          const SizedBox(height: 6),
          if (_selectedStarlinkId != null) _buildFilterBanner(allClients),
          Expanded(
            child: displayList.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: displayList.length,
                    itemBuilder: (ctx, i) {
                      final c = displayList[i];
                      return _ClientCard(
                        // 🔑 Clave por cliente: sin esto, al filtrar/buscar/ordenar
                        // Flutter reutilizaba el estado de la tarjeta (y su
                        // consumo) para OTRO cliente.
                        key: ValueKey(c.reference.id),
                        cliente: c,
                        onTap: () => context.pushNamed(
                          DetalleClienteWidget.routeName,
                          queryParameters: {'rf': serializeParam(c.reference, ParamType.DocumentReference)}.withoutNulls,
                        ),
                        onWhatsapp: () => _sendWhatsapp(
                          context,
                          c.nombre,
                          c.numero,
                          c.planValor,
                          c.reference,
                        ),
                      ).animate().fadeIn(duration: 280.ms, delay: (i * 35).ms);
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  HOME PARA PLAN "SOLO VOUCHERS"
  // ──────────────────────────────────────────
  Widget _buildVouchersHome() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Hero ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceStrong,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.accent.withOpacity(0.32)),
            boxShadow: [
              BoxShadow(color: AppColors.sombra(0.45), blurRadius: 26, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.neutralBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accent.withOpacity(0.35)),
                ),
                child: Icon(Icons.vpn_key_rounded, color: AppColors.accent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Plan Solo Vouchers',
                      style: GoogleFonts.spaceGrotesk(color: AppColors.textPri, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text('Módulo MikroTik Local activo', style: GoogleFonts.spaceGrotesk(color: AppColors.textSec, fontSize: 12)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.neutralBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: AppColors.accent, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tu plan incluye el módulo MikroTik Local para crear vouchers y también '
                    'puedes ajustar tu MikroTik y verlo remotamente por el túnel VPN. '
                    'Toda la configuración queda guardada en tu cuenta (Firebase).',
                    style: GoogleFonts.spaceGrotesk(color: AppColors.textSec, fontSize: 12, height: 1.4),
                  ),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // ── Accesos rápidos ──
        Text('Accesos rápidos', style: GoogleFonts.spaceGrotesk(color: AppColors.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _VouchersQuickCard(
              icon: Icons.wifi,
              label: 'Conexión Local',
              color: AppColors.accent,
              onTap: () {
                if (FFAppState().isConnectedLocal && FFAppState().mikrotikLocalApi != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DashboardLocalWidget(
                        api: FFAppState().mikrotikLocalApi!,
                        nombreRouter: FFAppState().nombreRouterLocal,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ConectarMikrotikLocalWidget()),
                  );
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _VouchersQuickCard(
              icon: Icons.vpn_key_rounded,
              label: 'Vouchers',
              color: AppColors.stream3,
              onTap: () {
                if (FFAppState().isConnectedLocal && FFAppState().mikrotikLocalApi != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DashboardLocalWidget(
                        api: FFAppState().mikrotikLocalApi!,
                        nombreRouter: FFAppState().nombreRouterLocal,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ConectarMikrotikLocalWidget()),
                  );
                }
              },
            ),
          ),
        ]),
        const SizedBox(height: 12),
        // ── Ajustar el MikroTik (config en Firebase) y verlo remoto (VPN) ──
        Row(children: [
          Expanded(
            child: _VouchersQuickCard(
              icon: Icons.router_outlined,
              label: 'Ajustar MikroTik',
              color: AppColors.stream3,
              onTap: () => context.pushNamed(ConfigMikroTikWidget.routeName),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _VouchersQuickCard(
              icon: Icons.vpn_lock_rounded,
              label: 'Ver remoto',
              color: AppColors.primary,
              onTap: () => context.pushNamed(VpnWidget.routeName),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _VouchersQuickCard(
              icon: Icons.person_rounded,
              label: 'Mi Perfil',
              color: AppColors.primary,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CompletarPerfilWidget()),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _VouchersQuickCard(
              icon: Icons.workspace_premium_rounded,
              label: 'Mejorar Plan',
              color: AppColors.success,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RenovarMembresiaWidget()),
                );
              },
            ),
          ),
        ]),
      ]),
    );
  }

  // ──────────────────────────────────────────
  //  CHIPS
  // ──────────────────────────────────────────
  Widget _buildStarlinkChipsFromList(List<ClientesRecord> allClients, List<_StarlinkInfo> starlinks) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _AllChip(
            selected: _selectedStarlinkId == null,
            totalClients: allClients.length,
            onTap: () => setState(() {
              _selectedStarlinkId = null;
              _isSearching = false;
              _searchResults = [];
              _searchCtrl.clear();
            }),
          ),
          ...starlinks.map((sl) => _StarlinkChip(
                starlink: sl,
                selected: _selectedStarlinkId == sl.id,
                onTap: () => setState(() {
                  _selectedStarlinkId = _selectedStarlinkId == sl.id ? null : sl.id;
                  _isSearching = false;
                  _searchResults = [];
                  _searchCtrl.clear();
                }),
              )),
        ],
      ),
    );
  }

  Widget _buildFechaAlertBanner() {
    return GestureDetector(
      onTap: () async {
        await context.pushNamed(ConfigFacturacionWidget.routeName);
        _cargarConfigFacturacion();
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withOpacity(0.35), width: 1.2),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.calendar_today_rounded, color: AppColors.warning, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Facturación sin configurar',
                style: GoogleFonts.spaceGrotesk(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              Text(
                'Toca aquí para configurarla antes de enviar mensajes.',
                style: GoogleFonts.spaceGrotesk(color: AppColors.textSec, fontSize: 11),
              ),
            ]),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.warning),
        ]),
      ),
    );
  }

  Widget _buildFilterBanner(List<ClientesRecord> allClients) {
    final count = allClients.where((c) => c.starlinkId == _selectedStarlinkId).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: StreamBuilder<List<_StarlinkInfo>>(
        stream: _starlinksStream,
        builder: (context, snap) {
          final starlinks = snap.data ?? [];
          final found = starlinks.firstWhere(
            (s) => s.id == _selectedStarlinkId,
            orElse: () => const _StarlinkInfo(id: '', nombre: '...', ubicacion: '', activo: false, clientesCount: 0),
          );
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder, width: 1),
            ),
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.neutralBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withOpacity(0.35)),
                ),
                child: Icon(Icons.satellite_alt_rounded, color: AppColors.accent, size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Filtrando: ${found.nombre}',
                      style: GoogleFonts.spaceGrotesk(color: AppColors.textPri, fontSize: 12, fontWeight: FontWeight.w700)),
                  Text('$count cliente${count != 1 ? 's' : ''} en esta Starlink',
                      style: GoogleFonts.spaceGrotesk(color: AppColors.textSec, fontSize: 10)),
                ]),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _selectedStarlinkId = null;
                  _isSearching = false;
                  _searchResults = [];
                  _searchCtrl.clear();
                }),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: AppColors.neutralBg, shape: BoxShape.circle),
                  child: Icon(Icons.close_rounded, size: 14, color: AppColors.textSec),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  String get _fechaHoy {
    final d = DateTime.now();
    const meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];
    return '${d.day} de ${meses[d.month - 1]} de ${d.year}';
  }

  void _alternarFiltroEstado(String? estado) {
    setState(() {
      if (_filterEstado == estado) {
        _filterEstado = null;
      } else {
        _filterEstado = estado;
        _selectedStarlinkId = null;
        _isSearching = false;
        _searchResults = [];
        _searchCtrl.clear();
      }
    });
  }

  Widget _glassCircle(IconData icon, Color color, Color fondo) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Icon(icon, color: color, size: 19),
    );
  }

  Widget _buildTopBarPro(BuildContext context, List<ClientesRecord> allClients) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 8, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.barra,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        border: Border(bottom: BorderSide(color: AppColors.cardBorder, width: 1)),
        boxShadow: [BoxShadow(color: AppColors.sombra(0.45), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: _toggleDrawer,
            child: AnimatedBuilder(
              animation: _drawerAnim,
              builder: (_, __) => Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.neutralBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Icon(_drawerOpen ? Icons.close_rounded : Icons.menu_rounded, color: AppColors.textPri, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FutureBuilder<DocumentSnapshot>(
              future: _uid.isEmpty ? null : FirebaseFirestore.instance.collection('user').doc(_uid).get(),
              builder: (context, snap) {
                final nombre =
                    snap.hasData && snap.data!.exists ? (snap.data!.data() as Map<String, dynamic>)['nombre'] ?? 'Usuario' : 'Usuario';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bienvenido de nuevo', style: GoogleFonts.spaceGrotesk(color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text.rich(TextSpan(children: [
                      TextSpan(
                        text: nombre,
                        style: GoogleFonts.spaceGrotesk(color: AppColors.textPri, fontSize: 19, fontWeight: FontWeight.w800),
                      ),
                      TextSpan(
                        text: '  ·  $_nombreEmpresa',
                        style: GoogleFonts.spaceGrotesk(color: AppColors.textSec, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ])),
                  ],
                );
              },
            ),
          ),
          if (_tipoPlanUsuario != 'vouchers') ...[
            GestureDetector(
              onTap: () => _marcarTodosEnMora(allClients),
              child: _glassCircle(Icons.warning_amber_rounded, AppColors.warning, AppColors.warningBg),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _marcarTodosActivos(allClients),
              child: _glassCircle(Icons.check_circle_outline_rounded, AppColors.success, AppColors.successBg),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => context.pushNamed(CrearUsuarioWidget.routeName),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: AppColors.brand.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.person_add_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text('Nuevo', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.neutralBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.calendar_month_rounded, color: AppColors.textSec, size: 14),
              const SizedBox(width: 6),
              Text(_fechaHoy, style: GoogleFonts.spaceGrotesk(color: AppColors.textSec, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _buildStatsRow(int total, int activo, int mora, int inactivo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _StatCard(
          label: 'Clientes',
          count: total.toString(),
          icon: Icons.people_alt_rounded,
          color: AppColors.primary,
          fondo: AppColors.neutralBg,
          selected: _filterEstado == null,
          onTap: () => _alternarFiltroEstado(null),
        ),
        _StatCard(
          label: 'Activos',
          count: activo.toString(),
          icon: _EstadoTono.activo.icono,
          color: _EstadoTono.activo.contenido,
          fondo: _EstadoTono.activo.fondo,
          selected: _filterEstado == 'activo',
          onTap: () => _alternarFiltroEstado('activo'),
        ),
        _StatCard(
          label: 'En mora',
          count: mora.toString(),
          icon: _EstadoTono.mora.icono,
          color: _EstadoTono.mora.contenido,
          fondo: _EstadoTono.mora.fondo,
          selected: _filterEstado == 'mora',
          onTap: () => _alternarFiltroEstado('mora'),
        ),
        _StatCard(
          label: 'Inactivos',
          count: inactivo.toString(),
          icon: _EstadoTono.inactivo.icono,
          color: _EstadoTono.inactivo.contenido,
          fondo: _EstadoTono.inactivo.fondo,
          selected: _filterEstado == 'inactivo',
          onTap: () => _alternarFiltroEstado('inactivo'),
        ),
      ]),
    );
  }

  Widget _buildSearchBar(BuildContext context, List<ClientesRecord> filteredClients) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: AppColors.sombra(0.3), blurRadius: 12, offset: const Offset(0, 4))],
          border: Border.all(
            color: _isSearching ? AppColors.primary.withOpacity(0.5) : AppColors.cardBorder,
            width: 1.2,
          ),
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          Icon(Icons.search_rounded, color: _isSearching ? AppColors.primary : AppColors.textMuted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => _onSearchChanged(v, filteredClients),
              cursorColor: AppColors.primary,
              style: GoogleFonts.spaceGrotesk(color: AppColors.textPri, fontSize: 14),
              decoration: InputDecoration(
                hintText: _selectedStarlinkId != null ? 'Buscar en esta Starlink…' : 'Buscar por nombre, finca o IP',
                hintStyle: GoogleFonts.spaceGrotesk(color: AppColors.textMuted, fontSize: 13),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_isSearching)
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                setState(() {
                  _isSearching = false;
                  _searchResults = [];
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: AppColors.neutralBg, shape: BoxShape.circle),
                  child: Icon(Icons.close_rounded, size: 14, color: AppColors.textSec),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFiltered = _selectedStarlinkId != null;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          isFiltered ? Icons.satellite_alt_rounded : Icons.search_off_rounded,
          size: 60,
          color: AppColors.textMuted,
        ),
        const SizedBox(height: 12),
        Text(
          isFiltered ? 'Esta Starlink no tiene clientes' : 'Sin resultados',
          style: GoogleFonts.spaceGrotesk(color: AppColors.textSec, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        Text(
          isFiltered ? 'Asigna clientes desde el detalle de cada uno' : 'Prueba con otro término',
          style: GoogleFonts.spaceGrotesk(color: AppColors.textMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        if (isFiltered) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => setState(() => _selectedStarlinkId = null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.neutralBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Text('Ver todos los clientes',
                  style: GoogleFonts.spaceGrotesk(color: AppColors.textPri, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  QUICK CARD PARA PLAN "SOLO VOUCHERS"
// ─────────────────────────────────────────────
class _VouchersQuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _VouchersQuickCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder, width: 1.2),
          boxShadow: [
            BoxShadow(color: AppColors.sombra(0.35), blurRadius: 18, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.neutralBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(label,
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.textPri,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 2),
          Text('Toca para abrir',
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.textMuted,
                fontSize: 10,
              )),
        ]),
      ),
    );
  }
}
