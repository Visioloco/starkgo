import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ── Páginas existentes ────────────────────────────────────────────────────────
import 'package:stark_go/pages/ConfigMikroTik/config_mikro_tik_widget.dart';
import 'package:stark_go/pages/lista_equipos/lista_equipos_widget.dart';
import 'package:stark_go/pages/lista_starlinks/lista_starlinks_widget.dart';
import 'package:stark_go/pages/planes/planes_widget.dart';
import 'package:stark_go/pages/crear_cuenta/crear_cuenta_widget.dart';
import 'package:stark_go/pages/tutorial/tutorial_widget.dart';
import 'package:stark_go/pages/Registro/registro_widget.dart';
import 'package:stark_go/pages/reporte_consumo/reporte_consumo_widget.dart';
// ── NUEVA página Evolution API ✅ ─────────────────────────────────────────────
import 'package:stark_go/pages/config_evolution_api/config_evolution_api_widget.dart';
// ── CONEXIÓN LOCAL MIKROTIK (NUEVO) ──────────────────────────────────────────
import 'package:stark_go/pages/config_mikrotik_local/conectar_mikrotik_local_widget.dart';
import 'package:stark_go/pages/config_mikrotik_local/dashboard_local_widget.dart';
// ── NUEVA página Configuración de Facturación ✅ ──────────────────────────────
import 'package:stark_go/pages/config_facturacion/config_facturacion_widget.dart';
import 'package:stark_go/pages/informes/informes_widget.dart';
import 'package:stark_go/pages/lista_operadores/lista_operadores_widget.dart';
import 'package:stark_go/pages/pppoe_clientes/crear_pppoe_widget.dart';
import 'package:stark_go/pages/pppoe_clientes/pppoe_clientes_widget.dart';
import 'package:stark_go/pages/renovar_membresia/renovar_membresia_widget.dart';
import 'package:stark_go/pages/activar_membresia/activar_membresia_widget.dart';
import 'package:stark_go/pages/lista_starlinks_clientes/lista_starlinks_clientes_widget.dart';

import '/auth/base_auth_user_provider.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';

export 'package:go_router/go_router.dart';
export 'serialization_util.dart';

import 'package:stark_go/pages/splash/splash_widget.dart';
import 'package:stark_go/pages/config_ultra_msg/config_ultra_msg_widget.dart';
import 'package:stark_go/pages/config_mikro_tik/config_mikro_tik_widget.dart';
import 'package:stark_go/pages/config_velocidades/config_velocidades_widget.dart';

const kTransitionInfoKey = '__transition_info__';

GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

// ══════════════════════════════════════════════════════════════════════════════
// AppStateNotifier (sin cambios)
// ══════════════════════════════════════════════════════════════════════════════
class AppStateNotifier extends ChangeNotifier {
  AppStateNotifier._();

  static AppStateNotifier? _instance;
  static AppStateNotifier get instance => _instance ??= AppStateNotifier._();

  BaseAuthUser? initialUser;
  BaseAuthUser? user;
  bool showSplashImage = true;
  String? _redirectLocation;

  bool notifyOnAuthChange = true;

  bool get loading => user == null || showSplashImage;
  bool get loggedIn => user?.loggedIn ?? false;
  bool get initiallyLoggedIn => initialUser?.loggedIn ?? false;
  bool get shouldRedirect => loggedIn && _redirectLocation != null;

  String getRedirectLocation() => _redirectLocation!;
  bool hasRedirect() => _redirectLocation != null;
  void setRedirectLocationIfUnset(String loc) => _redirectLocation ??= loc;
  void clearRedirectLocation() => _redirectLocation = null;

  void updateNotifyOnAuthChange(bool notify) => notifyOnAuthChange = notify;

  void update(BaseAuthUser newUser) {
    final shouldUpdate = user?.uid == null || newUser.uid == null || user?.uid != newUser.uid;
    initialUser ??= newUser;
    user = newUser;
    if (notifyOnAuthChange && shouldUpdate) {
      notifyListeners();
    }
    updateNotifyOnAuthChange(true);
  }

  void stopShowingSplashImage() {
    showSplashImage = false;
    notifyListeners();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Router
// ══════════════════════════════════════════════════════════════════════════════
GoRouter createRouter(AppStateNotifier appStateNotifier) => GoRouter(
      initialLocation: '/',
      debugLogDiagnostics: true,
      refreshListenable: appStateNotifier,
      navigatorKey: appNavigatorKey,
      errorBuilder: (context, state) => appStateNotifier.loggedIn ? HomeWidget() : LoginWidget(),
      routes: [
        FFRoute(
          name: '_initialize',
          path: '/',
          builder: (context, _) => SplashWidget(),
          routes: [
            // ── SPLASH ──────────────────────────────────────────────────────
            FFRoute(
              name: SplashWidget.routeName,
              path: SplashWidget.routePath,
              builder: (context, params) => SplashWidget(),
            ),

            // ── AUTH ─────────────────────────────────────────────────────────
            FFRoute(
              name: HomeWidget.routeName,
              path: HomeWidget.routePath,
              builder: (context, params) => HomeWidget(),
            ),
            FFRoute(
              name: LoginWidget.routeName,
              path: LoginWidget.routePath,
              builder: (context, params) => LoginWidget(),
            ),

            // ── CLIENTES ─────────────────────────────────────────────────────
            FFRoute(
              name: CrearUsuarioWidget.routeName,
              path: CrearUsuarioWidget.routePath,
              builder: (context, params) => CrearUsuarioWidget(),
            ),
            FFRoute(
              name: ListaclientesWidget.routeName,
              path: ListaclientesWidget.routePath,
              builder: (context, params) => ListaclientesWidget(),
            ),
            FFRoute(
              name: DetalleClienteWidget.routeName,
              path: DetalleClienteWidget.routePath,
              builder: (context, params) => DetalleClienteWidget(
                rf: params.getParam(
                  'rf',
                  ParamType.DocumentReference,
                  isList: false,
                  collectionNamePath: ['clientes'],
                ),
              ),
            ),

            // ── PAGOS ────────────────────────────────────────────────────────
            FFRoute(
              name: RegistrarPagoWidget.routeName,
              path: RegistrarPagoWidget.routePath,
              builder: (context, params) => RegistrarPagoWidget(
                nombre: params.getParam('nombre', ParamType.String),
                numero: params.getParam('numero', ParamType.int),
                refcliente: params.getParam(
                  'refcliente',
                  ParamType.DocumentReference,
                  isList: false,
                  collectionNamePath: ['clientes'],
                ),
                planCliente: params.getParam('planCliente', ParamType.double),
              ),
            ),
            FFRoute(
              name: DetallesdepagoWidget.routeName,
              path: DetallesdepagoWidget.routePath,
              builder: (context, params) => DetallesdepagoWidget(
                refcliente: params.getParam(
                  'refcliente',
                  ParamType.DocumentReference,
                  isList: false,
                  collectionNamePath: ['clientes'],
                ),
              ),
            ),

            // ── ADMIN ────────────────────────────────────────────────────────
            FFRoute(
              name: CrearStarlinkWidget.routeName,
              path: CrearStarlinkWidget.routePath,
              builder: (context, params) => CrearStarlinkWidget(),
            ),
            FFRoute(
              name: CrearEquipoWidget.routeName,
              path: CrearEquipoWidget.routePath,
              builder: (context, params) => CrearEquipoWidget(),
            ),
            FFRoute(
              name: ListaStarlinksWidget.routeName,
              path: ListaStarlinksWidget.routePath,
              builder: (context, params) => ListaStarlinksWidget(),
            ),
            // ── MIS STARLINKS DE CLIENTES (cobros) ──────────────────────────────────────
            FFRoute(
              name: ListaStarlinksClientesWidget.routeName,
              path: ListaStarlinksClientesWidget.routePath,
              builder: (context, params) => const ListaStarlinksClientesWidget(),
            ),
            FFRoute(
              name: ListaEquiposWidget.routeName,
              path: ListaEquiposWidget.routePath,
              builder: (context, params) => ListaEquiposWidget(),
            ),

            // ── PLANES ───────────────────────────────────────────────────────
            FFRoute(
              name: PlanesWidget.routeName,
              path: PlanesWidget.routePath,
              builder: (context, params) => PlanesWidget(),
            ),

            // ── CREAR CUENTA (ADMIN) ─────────────────────────────────
            FFRoute(
              name: CrearCuentaWidget.routeName,
              path: CrearCuentaWidget.routePath,
              builder: (context, params) => CrearCuentaWidget(),
            ),

// ── LISTA OPERADORES (ADMIN) ─────────────────────────────  ← NUEVA
            FFRoute(
              name: ListaOperadoresWidget.routeName,
              path: ListaOperadoresWidget.routePath,
              builder: (context, params) => const ListaOperadoresWidget(),
            ),

            // ── CONFIG ULTRAMSG ──────────────────────────────────────────────
            FFRoute(
              name: ConfigUltraMsgWidget.routeName,
              path: ConfigUltraMsgWidget.routePath,
              builder: (context, params) => ConfigUltraMsgWidget(),
            ),

            // ── CONFIG MIKROTIK ──────────────────────────────────────────────
            FFRoute(
              name: ConfigMikroTikWidget.routeName,
              path: ConfigMikroTikWidget.routePath,
              builder: (context, params) => ConfigMikroTikWidget(),
            ),
            // ── PPPOE ────────────────────────────────────────────────────
            FFRoute(
              name: CrearPppoeWidget.routeName,
              path: CrearPppoeWidget.routePath,
              builder: (context, params) => const CrearPppoeWidget(),
            ),
            FFRoute(
              name: PppoeClientesWidget.routeName,
              path: PppoeClientesWidget.routePath,
              builder: (context, params) => const PppoeClientesWidget(),
            ),

            // ── CONFIG EVOLUTION API (WhatsApp) ✅ ───────────────────────────
            FFRoute(
              name: ConfigEvolutionApiWidget.routeName,
              path: ConfigEvolutionApiWidget.routePath,
              builder: (context, params) => const ConfigEvolutionApiWidget(),
            ),

            // ── CONFIG FACTURACIÓN ✅ NUEVO ──────────────────────────────────
            FFRoute(
              name: ConfigFacturacionWidget.routeName, // 'ConfigFacturacion'
              path: ConfigFacturacionWidget.routePath, // 'config-facturacion'
              builder: (context, params) => const ConfigFacturacionWidget(),
            ),
            // ── CONFIG VELOCIDADES MIKROTIK ✅ NUEVO ─────────────────────────────
            FFRoute(
              name: ConfigVelocidadesWidget.routeName, // 'ConfigVelocidades'
              path: ConfigVelocidadesWidget.routePath, // 'config-velocidades'
              builder: (context, params) => const ConfigVelocidadesWidget(),
            ),
            // ── INFORMES ✅ NUEVO ────────────────────────────────────────────────────
            FFRoute(
              name: InformesWidget.routeName, // 'Informes'
              path: InformesWidget.routePath, // 'informes'
              builder: (context, params) => const InformesWidget(),
            ),
            FFRoute(
              name: ReporteConsumoWidget.routeName,
              path: ReporteConsumoWidget.routePath,
              builder: (context, params) => const ReporteConsumoWidget(),
            ),
            FFRoute(
              name: RegistroWidget.routeName,
              path: RegistroWidget.routePath,
              builder: (context, params) => const RegistroWidget(),
            ),
            // ── TUTORIAL ─────────────────────────────────────────────────────────────
            // ── RENOVAR MEMBRESÍA ────────────────────────────────────────────────────────
            FFRoute(
              name: ActivarMembresiaWidget.routeName,
              path: ActivarMembresiaWidget.routePath,
              builder: (context, params) => const ActivarMembresiaWidget(),
            ),
            FFRoute(
              name: RenovarMembresiaWidget.routeName,
              path: RenovarMembresiaWidget.routePath,
              builder: (context, params) => const RenovarMembresiaWidget(),
            ),
            FFRoute(
              name: TutorialWidget.routeName,
              path: TutorialWidget.routePath,
              builder: (context, params) => const TutorialWidget(),
            ),
          ].map((r) => r.toRoute(appStateNotifier)).toList(),
        ),
      ].map((r) => r.toRoute(appStateNotifier)).toList(),
    );

// ══════════════════════════════════════════════════════════════════════════════
// Extensiones y clases auxiliares (sin cambios)
// ══════════════════════════════════════════════════════════════════════════════

extension NavParamExtensions on Map<String, String?> {
  Map<String, String> get withoutNulls => Map.fromEntries(
        entries.where((e) => e.value != null).map((e) => MapEntry(e.key, e.value!)),
      );
}

extension NavigationExtensions on BuildContext {
  void goNamedAuth(
    String name,
    bool mounted, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
    bool ignoreRedirect = false,
  }) =>
      !mounted || GoRouter.of(this).shouldRedirect(ignoreRedirect)
          ? null
          : goNamed(
              name,
              pathParameters: pathParameters,
              queryParameters: queryParameters,
              extra: extra,
            );

  void pushNamedAuth(
    String name,
    bool mounted, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
    bool ignoreRedirect = false,
  }) =>
      !mounted || GoRouter.of(this).shouldRedirect(ignoreRedirect)
          ? null
          : pushNamed(
              name,
              pathParameters: pathParameters,
              queryParameters: queryParameters,
              extra: extra,
            );

  void safePop() {
    if (canPop()) {
      pop();
    } else {
      go('/');
    }
  }
}

extension GoRouterExtensions on GoRouter {
  AppStateNotifier get appState => AppStateNotifier.instance;
  void prepareAuthEvent([bool ignoreRedirect = false]) =>
      appState.hasRedirect() && !ignoreRedirect ? null : appState.updateNotifyOnAuthChange(false);
  bool shouldRedirect(bool ignoreRedirect) => !ignoreRedirect && appState.hasRedirect();
  void clearRedirectLocation() => appState.clearRedirectLocation();
  void setRedirectLocationIfUnset(String location) => appState.updateNotifyOnAuthChange(false);
}

extension _GoRouterStateExtensions on GoRouterState {
  Map<String, dynamic> get extraMap => extra != null ? extra as Map<String, dynamic> : {};
  Map<String, dynamic> get allParams => <String, dynamic>{}
    ..addAll(pathParameters)
    ..addAll(uri.queryParameters)
    ..addAll(extraMap);
  TransitionInfo get transitionInfo =>
      extraMap.containsKey(kTransitionInfoKey) ? extraMap[kTransitionInfoKey] as TransitionInfo : TransitionInfo.appDefault();
}

class FFParameters {
  FFParameters(this.state, [this.asyncParams = const {}]);

  final GoRouterState state;
  final Map<String, Future<dynamic> Function(String)> asyncParams;

  Map<String, dynamic> futureParamValues = {};

  bool get isEmpty => state.allParams.isEmpty || (state.allParams.length == 1 && state.extraMap.containsKey(kTransitionInfoKey));
  bool isAsyncParam(MapEntry<String, dynamic> param) => asyncParams.containsKey(param.key) && param.value is String;
  bool get hasFutures => state.allParams.entries.any(isAsyncParam);
  Future<bool> completeFutures() => Future.wait(
        state.allParams.entries.where(isAsyncParam).map(
          (param) async {
            final doc = await asyncParams[param.key]!(param.value).onError((_, __) => null);
            if (doc != null) {
              futureParamValues[param.key] = doc;
              return true;
            }
            return false;
          },
        ),
      ).onError((_, __) => [false]).then((v) => v.every((e) => e));

  dynamic getParam<T>(
    String paramName,
    ParamType type, {
    bool isList = false,
    List<String>? collectionNamePath,
  }) {
    if (futureParamValues.containsKey(paramName)) {
      return futureParamValues[paramName];
    }
    if (!state.allParams.containsKey(paramName)) return null;
    final param = state.allParams[paramName];
    if (param is! String) return param;
    return deserializeParam<T>(param, type, isList, collectionNamePath: collectionNamePath);
  }
}

class FFRoute {
  const FFRoute({
    required this.name,
    required this.path,
    required this.builder,
    this.requireAuth = false,
    this.asyncParams = const {},
    this.routes = const [],
  });

  final String name;
  final String path;
  final bool requireAuth;
  final Map<String, Future<dynamic> Function(String)> asyncParams;
  final Widget Function(BuildContext, FFParameters) builder;
  final List<GoRoute> routes;

  GoRoute toRoute(AppStateNotifier appStateNotifier) => GoRoute(
        name: name,
        path: path,
        redirect: (context, state) {
          if (appStateNotifier.shouldRedirect) {
            final redirectLocation = appStateNotifier.getRedirectLocation();
            appStateNotifier.clearRedirectLocation();
            return redirectLocation;
          }
          if (requireAuth && !appStateNotifier.loggedIn) {
            appStateNotifier.setRedirectLocationIfUnset(state.uri.toString());
            return '/login';
          }
          return null;
        },
        pageBuilder: (context, state) {
          fixStatusBarOniOS16AndBelow(context);
          final ffParams = FFParameters(state, asyncParams);
          final page = ffParams.hasFutures
              ? FutureBuilder(
                  future: ffParams.completeFutures(),
                  builder: (context, _) => builder(context, ffParams),
                )
              : builder(context, ffParams);

          final child = appStateNotifier.loading ? SplashWidget() : page;

          final transitionInfo = state.transitionInfo;
          return transitionInfo.hasTransition
              ? CustomTransitionPage(
                  key: state.pageKey,
                  child: child,
                  transitionDuration: transitionInfo.duration,
                  transitionsBuilder: (context, animation, secondaryAnimation, child) => PageTransition(
                    type: transitionInfo.transitionType,
                    duration: transitionInfo.duration,
                    reverseDuration: transitionInfo.duration,
                    alignment: transitionInfo.alignment,
                    child: child,
                  ).buildTransitions(context, animation, secondaryAnimation, child),
                )
              : MaterialPage(key: state.pageKey, child: child);
        },
        routes: routes,
      );
}

class TransitionInfo {
  const TransitionInfo({
    required this.hasTransition,
    this.transitionType = PageTransitionType.fade,
    this.duration = const Duration(milliseconds: 300),
    this.alignment,
  });

  final bool hasTransition;
  final PageTransitionType transitionType;
  final Duration duration;
  final Alignment? alignment;

  static TransitionInfo appDefault() => const TransitionInfo(
        hasTransition: true,
        transitionType: PageTransitionType.fade,
        duration: Duration(milliseconds: 300),
      );
}

class RootPageContext {
  const RootPageContext(this.isRootPage, [this.errorRoute]);
  final bool isRootPage;
  final String? errorRoute;

  static bool isInactiveRootPage(BuildContext context) {
    final rootPageContext = context.read<RootPageContext?>();
    final isRootPage = rootPageContext?.isRootPage ?? false;
    final location = GoRouterState.of(context).uri.toString();
    return isRootPage && location != '/' && location != rootPageContext?.errorRoute;
  }

  static Widget wrap(Widget child, {String? errorRoute}) => Provider.value(
        value: RootPageContext(true, errorRoute),
        child: child,
      );
}

extension GoRouterLocationExtension on GoRouter {
  String getCurrentLocation() {
    final RouteMatch lastMatch = routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch ? lastMatch.matches : routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }
}
