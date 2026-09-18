import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:stark_go/services/antenas_service.dart';
import 'package:stark_go/services/vps_service.dart';

// ══════════════════════════════════════════════════════════════
//  GuiaVpnPage — guía paso a paso de la configuración manual
//  (VPS + MikroTik + antenas). Lo que ya es automático se marca aparte.
// ══════════════════════════════════════════════════════════════

class _C {
  static const Color primary = Color(0xFF1A73E8);
  static const Color accent = Color(0xFF00C6AE);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color dark = Color(0xFF0F172A);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF1F5F9);
  static const Color textPri = Color(0xFF0F172A);
  static const Color textSec = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
}

class GuiaVpnPage extends StatefulWidget {
  const GuiaVpnPage({super.key});

  @override
  State<GuiaVpnPage> createState() => _GuiaVpnPageState();
}

class _GuiaVpnPageState extends State<GuiaVpnPage> {
  /// Public key del VPS cargada desde /wg/info (no es secreta, es pública).
  String _serverPubKey = '';

  /// IP del dispositivo en el túnel (vpn_config.address) — para poner en el MikroTik.
  String _address = '';

  /// Subred de antenas asignada (vpn_config.redAntenas).
  String _redAntenas = '';

  /// Endpoint del servidor WireGuard.
  String _endpoint = '5.161.88.42:1234';

  /// IP del túnel del MikroTik (config_mikrotik.mikrotikTunelIp).
  String _mikrotikTunelIp = '';

  /// Red local real del operador (config_mikrotik.subredLocal).
  String _subredLocal = '';

  /// Puerta de enlace real (config_mikrotik.ipLocal).
  String _ipLocal = '';

  /// true si el MikroTik usa NAT (netmap) para traducir la subred del túnel.
  bool _usarNetmap = false;

  @override
  void initState() {
    super.initState();
    _cargarPubKey();
    _cargarVpnConfig();
  }

  Future<void> _cargarVpnConfig() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vpn_config')
          .doc(uid)
          .get();
      if (doc.exists && mounted) {
        final d = doc.data() as Map<String, dynamic>;
        setState(() {
          _address = (d['address'] ?? '').toString().trim();
          _redAntenas = (d['redAntenas'] ?? '').toString().trim();
          _endpoint = (d['endpoint'] ?? '5.161.88.42:1234').toString().trim();
        });
      }
      // IP del túnel del MikroTik (config_mikrotik/{uid}).
      final cfg = await FirebaseFirestore.instance
          .collection('config_mikrotik')
          .doc(uid)
          .get();
      if (cfg.exists && mounted) {
        final d = cfg.data() as Map<String, dynamic>;
        setState(() {
          _mikrotikTunelIp = (d['mikrotikTunelIp'] ?? '').toString().trim();
          _subredLocal = (d['subredLocal'] ?? '').toString().trim();
          _ipLocal = (d['ipLocal'] ?? '').toString().trim();
          _usarNetmap = (d['usarNetmap'] ?? false) == true;
        });
      }
    } catch (_) {}
  }

  Future<void> _cargarPubKey() async {
    final info = await VpsService.obtenerInfoVps();
    if (info != null && info.serverPublicKey.isNotEmpty && mounted) {
      setState(() => _serverPubKey = info.serverPublicKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surfaceDim,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _banner(
                      icon: Icons.auto_awesome_rounded,
                      color: _C.success,
                      title: 'Guía completa · MikroTik + túnel + antenas 🎉',
                      subtitle:
                          'Seguí los pasos en orden. Cada dato que necesitás pegar en el '
                          'MikroTik está abajo con su botón de copiar. No te saltes el paso 2 '
                          '(IP Address): es el que le dice al MikroTik de dónde viene el túnel.',
                    ),
                    const SizedBox(height: 6),
                    _tusDatos(),
                    const SizedBox(height: 6),
                    _paso(
                        context,
                        0,
                        'Entrar al MikroTik (Winbox)',
                        'Conectate al router ANTES de tocar nada.\n'
                            '1) Abrí Winbox (o WebFig).\n'
                            '2) Connect To: poné la IP de tu MikroTik (la que usás siempre, ej: 192.168.88.1).\n'
                            '3) Login: admin · Password: la clave de tu router.\n'
                            '4) Clic en Connect. Ya estás adentro del router.',
                        null),
                    _paso(
                        context,
                        1,
                        'Crear la interfaz WireGuard (wg1)',
                        'Primero entramos a WireGuard y ahí creamos el túnel.\n'
                            '1) En el menú de la IZQUIERDA de Winbox hacé clic en WireGuard.\n'
                            '2) Dejá la pestaña WireGuard Interfaces (en RouterOS v6: Interfaces → pestaña WireGuard).\n'
                            '3) Clic en el botón (+) → New Interface.\n'
                            '4) Name: escribí exactamente wg1\n'
                            '5) Listen Port: podés poner 13231 o dejarlo en blanco.\n'
                            '6) Clic en OK.\n\n'
                            'La interfaz genera su Private Key y Public Key solas. NO las toques: '
                            'esas dos claves son de TU MikroTik.',
                        null),
                    _paso(
                        context,
                        2,
                        'Ponerle la IP al túnel (IP → Addresses) ⭐',
                        'Acá va la IP que la app le asignó a TU MIKROTIK. Está arriba en '
                            '"Tus datos" → "IP del túnel del MIKROTIK".\n'
                            '1) Menú izquierdo → IP → Addresses.\n'
                            '2) Clic en (+) → New Address.\n'
                            '3) Campo Address: escribí la IP del MikroTik y al final /24, por ejemplo: '
                            '${_mikrotikTunelIp.isEmpty ? '10.50.50.X' : _mikrotikTunelIp}/24\n'
                            '4) Campo Interface: elegí wg1 (importante: NO ether1 ni el bridge).\n'
                            '5) Clic en OK.\n\n'
                            '⚠️ Esta IP es la del MIKROTIK dentro del túnel. Cada router tiene la suya '
                            'única (la genera la app) — no la repitas en otro router.',
                        null),
                    _paso(
                        context,
                        3,
                        'Crear el Peer hacia el servidor (VPS) con los datos de la app',
                        'Ahora le decimos al túnel con quién hablar: el servidor. Usás '
                            '"Public key del servidor" y "Endpoint" que están en Tus datos (arriba).\n'
                            '1) En el menú WireGuard (el mismo del paso 1) abrí la pestaña Peers '
                            '(en v6: doble clic sobre wg1 → pestaña WireGuard Peers).\n'
                            '2) Clic en (+) → New Peer.\n'
                            '3) Interface: wg1\n'
                            '4) Public Key: pegá la PUBLIC KEY DEL SERVIDOR (la que empieza con el botón copiar arriba).\n'
                            '5) Endpoint Address: pegá la IP del endpoint (5.161.88.42).\n'
                            '6) Endpoint Port: 1234\n'
                            '7) Allowed Address: escribí 10.50.50.0/24 (es la red del túnel).\n'
                            '8) Persistent Keepalive: 10\n'
                            '9) Clic en OK.\n\n'
                            'Si el peer queda en estado running ya está conectado al servidor.',
                        null),
                    _paso(
                        context,
                        4,
                        _usarNetmap
                            ? 'Traducir tu red con netmap (IP → Firewall → NAT) ⭐'
                            : 'Ruta hacia tu subred de antenas (IP → Routes) ⭐',
                        _usarNetmap
                            ? 'Estás en MODO NETMAP ✅ — tu red local '
                                '(${_subredLocal.isEmpty ? 'ej. 192.168.1.0/24' : _subredLocal}) puede ser igual '
                                'a la de otra empresa, así que NO se agrega ninguna ruta: se traduce la subred del túnel.\n'
                                '1) En Winbox: New Terminal (ícono de consola, arriba a la derecha).\n'
                                '2) Pegá el comando de abajo (es el tuyo, ya completado) y dale Enter.\n'
                                '3) Andá a IP → Firewall → pestaña NAT y comprobá que la regla esté ahí (y arriba de todo).\n'
                                '4) Probá con el botón "Probar la regla netmap" en Configurar VPN.\n\n'
                                '⚠️ Este comando se pega UNA sola vez. No lo repitas: si lo pegás dos veces '
                                'vas a tener dos reglas iguales.\n\n'
                                '👉 Traduce así: la antena real ${_ipLocal.isEmpty ? '192.168.1.20' : '${_ipLocal.split('.').take(3).join('.')}.20'} '
                                'se abre por el túnel como '
                                '${_redAntenas.isEmpty ? '10.10.15' : _redAntenas.split('/').first.split('.').take(3).join('.')}.20'
                                ' — misma última octeta, todos los puertos (http, https, ssh).'
                            : 'Le dice al MikroTik hacia dónde mandar el tráfico de tus antenas por el túnel.\n'
                                '1) Menú izquierdo → IP → Routes.\n'
                                '2) Clic en (+) → New Route.\n'
                                '3) Dst. Address: pegá tu SUBRED DE ANTENAS (está en Tus datos, ej: '
                                '${_redAntenas.isEmpty ? '10.10.15.0/24' : _redAntenas}).\n'
                                '4) Gateway: seleccioná wg1.\n'
                                '5) Clic en OK.\n\n'
                                '💡 ¿Tus antenas están en tu propia red (ej: 192.168.x.x) y otra empresa usa '
                                'la misma? Entonces NO uses esta ruta: en Configurar VPN → "Tu red local" '
                                'activá el switch "Uso NAT (netmap)" y volvé a esta guía: te va a dar el '
                                'comando netmap exacto (así varias empresas pueden repetir 192.168.1.1).',
                        _usarNetmap
                            ? AntenasService.comandoNetmap(
                                redTunel: _redAntenas.isEmpty
                                    ? '10.10.15.0/24'
                                    : _redAntenas,
                                redLocal: _subredLocal.isEmpty
                                    ? '192.168.1.0/24'
                                    : _subredLocal,
                              )
                            : null),
                    _paso(
                        context,
                        5,
                        'Reglas del Firewall para dejar pasar el túnel',
                        'Sin estas reglas el MikroTik bloquea la entrada del túnel.\n'
                            '1) Menú izquierdo → IP → Firewall → pestaña Filter Rules.\n'
                            '2) Clic en (+) y agregá esta PRIMERA regla:\n'
                            '   · Chain: input\n'
                            '   · Protocol: udp\n'
                            '   · Dst. Port: 1234\n'
                            '   · Action: accept\n'
                            '3) Clic en OK.\n'
                            '4) Agregá la SEGUNDA regla (otro +):\n'
                            '   · Chain: input\n'
                            '   · Connection State: established,related\n'
                            '   · Action: accept\n'
                            '5) Clic en OK.\n'
                            '6) Agregá la TERCERA regla (otro +):\n'
                            '   · Chain: input\n'
                            '   · In. Interface: wg1\n'
                            '   · Action: accept\n'
                            '7) Clic en OK.\n\n'
                            'Con estas 3 reglas el túnel puede entrar y responder.',
                        null),
                    _paso(
                        context,
                        6,
                        'Registrar la Public Key del MikroTik (ya es automático)',
                        'Con esta key ya NO tenés que tocar el servidor: la app la registra sola en el VPS.\n'
                            '1) Copiá la Public Key de TU MikroTik: Winbox → WireGuard → doble clic sobre wg1 → campo Public Key.\n'
                            '2) En la app abrí el menú lateral → VPN · Antenas → ⚙️ Configurar (Configurar VPN).\n'
                            '3) Bajá hasta la tarjeta "MikroTik (lado del túnel)".\n'
                            '4) Pegá la Public Key en el campo y tocá "Registrar peer del MikroTik en el VPS".\n'
                            '5) Debe quedar el chip verde "Registrado en el VPS".\n\n'
                            '👉 Si el servidor lo administra OTRA persona (no vos), pasale esa key '
                            'junto con tu IP del túnel y tu subred de antenas.',
                        null),
                    _paso(
                        context,
                        7,
                        'Activar la VPN en la app (teléfono)',
                        '1) Iniciá sesión en la app.\n'
                            '2) Menú → VPN · Antenas → ⚙️ Configurar.\n'
                            '3) Tocá Generar claves y luego Registrar en el VPS (te asigna tu IP y subred automáticamente).\n'
                            '4) Guardá y activá el switch → debe quedar Conectado.\n'
                            '5) Ahora tocá una antena para abrir su pantalla de airOS.',
                        null),
                    _paso(
                        context,
                        8,
                        '¿Preferís terminal? (opcional)',
                        'Si usás New Terminal en vez de Winbox, pegá todo el script de una vez. '
                            'Tus datos ya están completados abajo:',
                        '/interface wireguard add name=wg1 listen-port=13231\n'
                            '# IP del túnel de TU MikroTik (la generó la app en Configurar VPN)\n'
                            '/ip address add address=${_mikrotikTunelIp.isEmpty ? '10.50.50.X/24' : '${_mikrotikTunelIp}/24'} interface=wg1\n'
                            '/interface wireguard peers add interface=wg1 \\\n'
                            '  public-key="${_serverPubKey.isEmpty ? '<PUBLIC_KEY_DEL_VPS>' : _serverPubKey}" \\\n'
                            '  endpoint-address=${_endpoint.split(':').first} endpoint-port=${_endpoint.split(':').length > 1 ? _endpoint.split(':')[1] : '1234'} \\\n'
                            '  allowed-address=10.50.50.0/24 persistent-keepalive=10s\n'
                            '/ip route add dst-address=${_redAntenas.isEmpty ? '10.10.15.0/24' : _redAntenas} gateway=wg1\n'
                            '/ip firewall filter add chain=input protocol=udp dst-port=1234 action=accept\n'
                            '/ip firewall filter add chain=input connection-state=established,related action=accept\n'
                            '/ip firewall filter add chain=input in-interface=wg1 action=accept'),
                    _paso(
                        context,
                        9,
                        'Probar que todo funcione (recomendado)',
                        '1) En la app: VPN · Antenas → activá el switch del túnel (debe quedar Conectado).\n'
                            '2) Tocá una antena: si abre la pantalla de airOS, ya está todo bien.\n'
                            '3) ¿No abre? Tocá el botón azul de "probar" que está en la tarjeta de la antena: '
                            'te dice si responde o no (y por http o https).\n'
                            '4) ¿Usás netmap? En Configurar VPN → "Tu red local" tocá '
                            '"Probar la regla netmap": si sale ✅ la traducción está bien.\n\n'
                            '❌ Si dice que no responde, mirá la tarjeta "Errores comunes" del final.',
                        null),
                    const SizedBox(height: 6),
                    _banner(
                      icon: Icons.language_rounded,
                      color: _C.primary,
                      title: 'WebFig del MikroTik (panel web)',
                      subtitle:
                          'Para abrir el MikroTik por navegador o desde la app (botón MikroTik '
                          'en VPN · Antenas), deja WebFig en el puerto 80. RouterOS nuevo trae '
                          'WebFig en 8085, así que en el MikroTik ejecuta: '
                          '/ip service set www port=80. Después entrás con http://<IP> del router.',
                    ),
                    _banner(
                      icon: Icons.shield_outlined,
                      color: _C.accent,
                      title:
                          'Cada empresa tiene su propia subred, automáticamente',
                      subtitle:
                          'El servidor asigna a cada cliente una subred 10.10.x.0/24 '
                          'distinta (empresa 1 → 10.10.15, empresa 2 → 10.10.16, etc.) y una IP '
                          'única del pool 10.50.50.x. Nadie puede usar la tuya ni pisar otra red: '
                          'esos datos están bloqueados en la app (solo lectura).',
                    ),
                    _banner(
                      icon: Icons.sync_rounded,
                      color: _C.success,
                      title: 'El servidor recibe los datos automáticamente',
                      subtitle:
                          'Cuando tocás "Registrar en el VPS", la app envía tu clave pública '
                          'y el servidor te asigna al momento tu IP del túnel (10.50.50.x) y tu '
                          'subred de antenas (10.10.x) — sin hacer nada manual. Lo único manual '
                          'es el MikroTik: su Public Key se da de alta UNA sola vez en el servidor '
                          '(paso 6). Si vos administrás el VPS la agregás vos; si el servidor lo '
                          'maneja otra persona, se la enviás a esa persona junto con tu subred.',
                    ),
                    const SizedBox(height: 10),
                    _banner(
                      icon: Icons.build_circle_outlined,
                      color: _C.warning,
                      title: 'Errores comunes (y cómo salir)',
                      subtitle:
                          '• "No responde" en una antena usando netmap → falta pegar la regla netmap, '
                          'o el túnel está caído, o la antena no tiene esa IP real.\n'
                          '• El peer del MikroTik no queda en running → revisá la Public Key del servidor '
                          'y el Endpoint (paso 3).\n'
                          '• Te olvidaste la IP en IP → Addresses (paso 2) → el túnel nunca levanta.\n'
                          '• El VPS te dice «esa subred ya está en uso por otra empresa» → es que otra '
                          'empresa declaró tu misma subred: activá el modo netmap (paso 4) y listo.\n'
                          '• Tus antenas están en 192.168.x.x (tu red real) → activá el modo netmap; '
                          'no agregues la ruta del paso 4.\n'
                          '• Abre la antena de OTRO cliente → nunca puentees capa 2 entre sitios ni metas '
                          'un 192.168.1.0/24 en las rutas del VPS.',
                    ),
                    _banner(
                      icon: Icons.check_circle_outline_rounded,
                      color: _C.accent,
                      title: 'Ya está ✅',
                      subtitle:
                          'Túnel conectado + MikroTik dado de alta + antenas en tu subred. '
                          'Antes de dar por cerrado el trabajo, tocá el botón de "probar" en una antena '
                          '(paso 9): si dice ✅ podés abrir todas. Los pasos que más se olvidan son el 2 '
                          '(IP en Addresses) y el 4 (ruta o regla netmap). Cualquier duda, contactá al administrador.',
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, color: _C.textPri),
          ),
          const SizedBox(width: 4),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_C.primary, _C.accent]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.menu_book_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Guía de configuración',
                    style: GoogleFonts.spaceGrotesk(
                        color: _C.textPri,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                Text('Para tu empresa · MikroTik + antenas + app',
                    style: GoogleFonts.spaceGrotesk(
                        color: _C.textSec, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tus datos para copiar ────────────────────────────────────
  Widget _tusDatos() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.primary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  gradient:
                      const LinearGradient(colors: [_C.primary, _C.accent]),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.copy_all_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tus datos (copialos para el MikroTik)',
                        style: GoogleFonts.spaceGrotesk(
                            color: _C.textPri,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800)),
                    Text('Cada valor tiene su botón de copiar',
                        style: GoogleFonts.spaceGrotesk(
                            color: _C.textSec, fontSize: 10.5)),
                  ]),
            ),
          ]),
          const SizedBox(height: 12),
          _datoCopiable(
            'Tu IP en el túnel (la del TELÉFONO — no va en el MikroTik)',
            _address.isEmpty ? 'Se asigna sola al tocar Guardar' : _address,
          ),
          _datoCopiable(
            'IP del túnel del MIKROTIK → va en IP → Addresses (paso 2)',
            _mikrotikTunelIp.isEmpty
                ? 'Generala en Configuración MikroTik (botón "Generar IP del túnel")'
                : _mikrotikTunelIp,
            color: _C.primary,
          ),
          _datoCopiable(
            'Subred de antenas que expone el túnel (va en IP → Routes, paso 4)',
            _redAntenas.isEmpty ? '10.10.15.0/24' : _redAntenas,
            color: _C.accent,
          ),
          _datoCopiable(
            'Tu red local (donde están tus antenas y tu MikroTik)',
            _subredLocal.isEmpty
                ? 'Ponela en Configurar VPN → "Tu red local"'
                : _subredLocal,
            color: _C.accent,
          ),
          _datoCopiable(
            'Modo de entrada de tus antenas (paso 4)',
            _usarNetmap
                ? 'NETMAP: tu red se traduce a ${_redAntenas.isEmpty ? '10.10.15.0/24' : _redAntenas}'
                : 'RUTA: ${_redAntenas.isEmpty ? '10.10.15.0/24' : _redAntenas} por wg1',
            color: _C.primary,
          ),
          _datoCopiable(
            'Public key del servidor → va en el Peer (paso 3)',
            _serverPubKey.isEmpty ? '<Cargando…>' : _serverPubKey,
            color: _C.warning,
          ),
          _datoCopiable(
            'Endpoint del servidor → va en el Peer (paso 3)',
            _endpoint,
            color: _C.warning,
          ),
        ],
      ),
    );
  }

  // ── Fila de dato con botón copiar ────────────────────────────
  Widget _datoCopiable(String label, String valor, {Color? color}) {
    final c = color ?? _C.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.content_copy_rounded, color: c, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.spaceGrotesk(
                        color: _C.textSec,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                SelectableText(valor,
                    style: GoogleFonts.spaceGrotesk(
                            color: _C.textPri,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600)
                        .copyWith(fontFamily: 'monospace')),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: valor));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('$label copiado',
                    style: GoogleFonts.spaceGrotesk(
                        color: Colors.white, fontSize: 13)),
                backgroundColor: _C.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 1),
              ));
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.copy_rounded, color: c, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ── Un paso numerado (con bloque de código opcional) ──────────
  Widget _paso(BuildContext context, int numero, String titulo,
      String descripcion, String? codigo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient:
                      const LinearGradient(colors: [_C.primary, _C.accent]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text('$numero',
                      style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: GoogleFonts.spaceGrotesk(
                            color: _C.textPri,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(descripcion,
                        style: GoogleFonts.spaceGrotesk(
                            color: _C.textSec, fontSize: 11.5, height: 1.45)),
                  ],
                ),
              ),
            ],
          ),
          if (codigo != null) ...[
            const SizedBox(height: 10),
            _bloqueCodigo(context, codigo),
          ],
        ],
      ),
    );
  }

  // ── Bloque de código con botón copiar ─────────────────────────
  Widget _bloqueCodigo(BuildContext context, String codigo) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.dark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              codigo,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.white70,
                  height: 1.5),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: codigo));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Comando copiado'),
                    duration: Duration(seconds: 1)),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.copy_rounded, color: Colors.white38, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ── Banner informativo ────────────────────────────────────────
  Widget _banner({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.spaceGrotesk(
                        color: _C.textPri,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: GoogleFonts.spaceGrotesk(
                        color: _C.textSec, fontSize: 11, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
