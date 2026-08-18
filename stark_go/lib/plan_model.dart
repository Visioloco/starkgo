import 'package:flutter/material.dart';

/// Tipo de plan de membresía.
enum TipoPlan {
  /// Acceso completo a toda la app (clientes, planes, informes, etc.)
  completo,

  /// Acceso únicamente al módulo MikroTik Local (Perfiles + Fichas/Vouchers + Hotspot)
  vouchers,
}

class Plan {
  final String id;
  final String duracion;
  final String sublabel;
  final int meses;
  final int precio;
  final int precioBase;
  final int ahorro;
  final Color color;
  final IconData icon;
  final String badge;
  final bool destacado;

  /// Tipo de plan: [TipoPlan.completo] o [TipoPlan.vouchers].
  final TipoPlan tipo;

  const Plan({
    required this.id,
    required this.duracion,
    required this.sublabel,
    required this.meses,
    required this.precio,
    required this.precioBase,
    required this.ahorro,
    required this.color,
    required this.icon,
    required this.badge,
    this.destacado = false,
    this.tipo = TipoPlan.completo,
  });
}

/// Planes de acceso completo a toda la app.
const kPlanes = [
  Plan(
    id: '1m',
    duracion: '1 Mes',
    sublabel: 'Acceso mensual',
    meses: 1,
    precio: 15,
    precioBase: 15,
    ahorro: 0,
    color: Color(0xFF64748B),
    icon: Icons.calendar_today_rounded,
    badge: 'Básico',
  ),
  Plan(
    id: '3m',
    duracion: '3 Meses',
    sublabel: 'Trimestral',
    meses: 3,
    precio: 39,
    precioBase: 45,
    ahorro: 6,
    color: Color(0xFF1A73E8),
    icon: Icons.date_range_rounded,
    badge: 'Popular',
    destacado: true,
  ),
  Plan(
    id: '6m',
    duracion: '6 Meses',
    sublabel: 'Semestral',
    meses: 6,
    precio: 69,
    precioBase: 90,
    ahorro: 21,
    color: Color(0xFF00C6AE),
    icon: Icons.event_rounded,
    badge: 'Recomendado',
  ),
  Plan(
    id: '1a',
    duracion: '1 Año',
    sublabel: 'Anual completo',
    meses: 12,
    precio: 120,
    precioBase: 180,
    ahorro: 60,
    color: Color(0xFF7C3AED),
    icon: Icons.workspace_premium_rounded,
    badge: 'Premium',
  ),
];

/// Planes "Solo Vouchers": acceso únicamente al módulo MikroTik Local
/// (Perfiles + Fichas/Vouchers + Hotspot). Escala de precios con descuento.
const kPlanesVouchers = [
  Plan(
    id: 'v1m',
    duracion: '1 Mes',
    sublabel: 'Solo vouchers',
    meses: 1,
    precio: 3,
    precioBase: 3,
    ahorro: 0,
    color: Color(0xFF0EA5E9),
    icon: Icons.vpn_key_rounded,
    badge: 'Básico',
    tipo: TipoPlan.vouchers,
  ),
  Plan(
    id: 'v3m',
    duracion: '3 Meses',
    sublabel: 'Solo vouchers',
    meses: 3,
    precio: 8,
    precioBase: 9,
    ahorro: 1,
    color: Color(0xFF06B6D4),
    icon: Icons.vpn_key_rounded,
    badge: 'Popular',
    tipo: TipoPlan.vouchers,
  ),
  Plan(
    id: 'v6m',
    duracion: '6 Meses',
    sublabel: 'Solo vouchers',
    meses: 6,
    precio: 15,
    precioBase: 18,
    ahorro: 3,
    color: Color(0xFF00C6AE),
    icon: Icons.vpn_key_rounded,
    badge: 'Recomendado',
    destacado: true,
    tipo: TipoPlan.vouchers,
  ),
  Plan(
    id: 'v1a',
    duracion: '1 Año',
    sublabel: 'Solo vouchers',
    meses: 12,
    precio: 30,
    precioBase: 36,
    ahorro: 6,
    color: Color(0xFF7C3AED),
    icon: Icons.vpn_key_rounded,
    badge: 'Premium',
    tipo: TipoPlan.vouchers,
  ),
];
