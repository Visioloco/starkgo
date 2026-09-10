import 'package:provider/provider.dart';
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'auth/firebase_auth/firebase_user_provider.dart';
import 'auth/firebase_auth/auth_util.dart';
import 'package:flutter/foundation.dart';

import 'backend/firebase/firebase_config.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'flutter_flow/internationalization.dart';
import 'services/notificaciones_service.dart';
import 'services/vpn_controller.dart';
import 'services/vpn_foreground.dart';
import 'pages/vpn/vpn_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();

  await initFirebase();

  // ✅ FIX: Activar App Check con Play Integrity para que
  //    Firebase Functions reciba el token correctamente
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );

  // ✅ Inicializar notificaciones locales al arrancar la app.
  //    Sin esto, las notificaciones programadas (zonedSchedule)
  //    pueden no dispararse o programarse en la hora equivocada.
  await NotificacionesService.instance.init();

  final appState = FFAppState();
  await appState.initializePersistedState();

  runApp(ChangeNotifierProvider(
    create: (context) => appState,
    child: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class MyAppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;
  ThemeMode _themeMode = ThemeMode.system;
  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;
  StreamSubscription<String>? _vpnForegroundSub;

  String getRoute([RouteMatch? routeMatch]) {
    final RouteMatch lastMatch =
        routeMatch ?? _router.routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : _router.routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }

  List<String> getRouteStack() =>
      _router.routerDelegate.currentConfiguration.matches
          .map((e) => getRoute(e))
          .toList();

  late Stream<BaseAuthUser> userStream;
  final authUserSub = authenticatedUserStream.listen((_) {});

  @override
  void initState() {
    super.initState();
    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);

    // Notificación persistente del túnel WireGuard: al tocarla abre la página
    // VPN, y el botón "Apagar túnel" lo desconecta directamente.
    NotificacionesService.instance.onTunelAction = (action) {
      if (action == 'stop_vpn') {
        VpnController.instance.stop();
        NotificacionesService.instance.ocultarTunelActivo();
      } else if (action == 'open_vpn') {
        _router.pushNamed(VpnWidget.routeName);
      }
    };

    // Acciones del servicio en primer plano nativo y del Tile de Ajustes
    // Rápidos de Android (canal com.starkgo.net.cardenCode/vpn_foreground).
    // El stream es vacío en iOS/web, por lo que esto no afecta esas apps.
    _vpnForegroundSub = vpnForegroundBridge.actions.listen(
      (action) {
        switch (action) {
          case VpnForegroundBridge.actionStopVpn:
            VpnController.instance.stop();
            NotificacionesService.instance.ocultarTunelActivo();
            break;
          case VpnForegroundBridge.actionOpenVpn:
          case VpnForegroundBridge.actionToggleVpn:
            try {
              _router.pushNamed(VpnWidget.routeName);
            } catch (_) {
              // Si la sesión aún no está lista, se ignora: el usuario puede
              // entrar a la VPN desde la pantalla principal.
            }
            break;
          default:
            break;
        }
      },
      onError: (_) {
        // Sin canal nativo (iOS/web): no pasa nada.
      },
    );
    userStream = starkGoFirebaseUserStream()
      ..listen((user) {
        _appStateNotifier.update(user);
      });
    jwtTokenStream.listen((_) {});
    Future.delayed(
      Duration(milliseconds: 1000),
      () => _appStateNotifier.stopShowingSplashImage(),
    );
  }

  @override
  void dispose() {
    _vpnForegroundSub?.cancel();
    authUserSub.cancel();
    super.dispose();
  }

  void setLocale(String language) {
    safeSetState(() => _locale = createLocale(language));
  }

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'StarkGo',
      scrollBehavior: MyAppScrollBehavior(),
      localizationsDelegates: [
        FFLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FallbackMaterialLocalizationDelegate(),
        FallbackCupertinoLocalizationDelegate(),
      ],
      locale: _locale,
      supportedLocales: const [
        Locale('es'),
      ],
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: false,
      ),
      themeMode: _themeMode,
      routerConfig: _router,
    );
  }
}
