// ══════════════════════════════════════════════════════════════
//  Puente Dart ↔ nativo para la notificación del servicio en
//  primer plano (Foreground Service) y el Tile de Ajustes Rápidos
//  del túnel WireGuard.
//
//  Import condicional:
//    - Web  → vpn_foreground_stub.dart (no rompe el build web)
//    - IO (Android/iOS) → vpn_foreground_io.dart (MethodChannel)
//
//  Solo Android ejecuta acciones reales; en iOS la notificación
//  persistente la sigue manejando flutter_local_notifications y el
//  sistema muestra su propio aviso de VPN.
// ══════════════════════════════════════════════════════════════
import 'vpn_foreground_stub.dart'
    if (dart.library.io) 'vpn_foreground_io.dart' as impl;

/// Acciones que puede emitir el lado nativo (botón "Apagar VPN" de la
/// notificación o tap en el Tile de Ajustes Rápidos).
abstract class VpnForegroundBridge {
  static const String actionStopVpn = 'stop_vpn';
  static const String actionOpenVpn = 'open_vpn';
  static const String actionToggleVpn = 'toggle_vpn';

  /// Stream de acciones nativas: `stop_vpn`, `open_vpn`, `toggle_vpn`.
  Stream<String> get actions;

  /// Arranca el servicio en primer plano y muestra la notificación persistente
  /// "VPN Activa / Conectado a MikroTik" (solo Android).
  /// Devuelve `true` si el canal nativo existió y el servicio pudo iniciarse.
  Future<bool> start();

  /// Detiene el servicio en primer plano y oculta la notificación (Android).
  Future<bool> stop();

  /// Sincroniza el estado del Tile de Ajustes Rápidos con el túnel real.
  Future<void> setTunnelActive(bool active);
}

/// Instancia global seleccionada por la plataforma.
final VpnForegroundBridge vpnForegroundBridge = impl.createBridge();
