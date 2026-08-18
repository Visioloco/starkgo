import 'package:flutter/material.dart';
import 'package:stark_go/services/mikrotik_local_api.dart';

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {}

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  // ─── MENÚ ITEMS ───
  List<String> _menuItems = ['Home', 'Search', 'Directory', 'Book', 'Profile'];
  List<String> get menuItems => _menuItems;
  set menuItems(List<String> value) {
    _menuItems = value;
  }

  void addToMenuItems(String value) {
    menuItems.add(value);
  }

  void removeFromMenuItems(String value) {
    menuItems.remove(value);
  }

  void removeAtIndexFromMenuItems(int index) {
    menuItems.removeAt(index);
  }

  void updateMenuItemsAtIndex(
    int index,
    String Function(String) updateFn,
  ) {
    menuItems[index] = updateFn(_menuItems[index]);
  }

  void insertAtIndexInMenuItems(int index, String value) {
    menuItems.insert(index, value);
  }

  // ─── MENÚ ACTIVO ───
  String _menuActiveItem = 'Home';
  String get menuActiveItem => _menuActiveItem;
  set menuActiveItem(String value) {
    _menuActiveItem = value;
  }

  // ─── COLORES DEL MENÚ ───
  List<Color> _menuItemColors = [Color(4283120111), Color(4281979584), Color(4293823328), Color(4294924643), Color(4287566292)];
  List<Color> get menuItemColors => _menuItemColors;
  set menuItemColors(List<Color> value) {
    _menuItemColors = value;
  }

  void addToMenuItemColors(Color value) {
    menuItemColors.add(value);
  }

  void removeFromMenuItemColors(Color value) {
    menuItemColors.remove(value);
  }

  void removeAtIndexFromMenuItemColors(int index) {
    menuItemColors.removeAt(index);
  }

  void updateMenuItemColorsAtIndex(
    int index,
    Color Function(Color) updateFn,
  ) {
    menuItemColors[index] = updateFn(_menuItemColors[index]);
  }

  void insertAtIndexInMenuItemColors(int index, Color value) {
    menuItemColors.insert(index, value);
  }

  // ─── ESTADOS UI ───
  bool _drawer = false;
  bool get drawer => _drawer;
  set drawer(bool value) {
    _drawer = value;
  }

  bool _buscando = false;
  bool get buscando => _buscando;
  set buscando(bool value) {
    _buscando = value;
  }

  // ════════════════════════════════════════════════════════════
  // ✅ NUEVO: ESTADOS DE CONEXIÓN LOCAL
  // ════════════════════════════════════════════════════════════

  // ─── Estado de conexión local ───
  bool _isConnectedLocal = false;
  bool get isConnectedLocal => _isConnectedLocal;
  set isConnectedLocal(bool value) {
    _isConnectedLocal = value;
    notifyListeners();
  }

  // ─── API de MikroTik local ───
  MikrotikLocalApi? _mikrotikLocalApi;
  MikrotikLocalApi? get mikrotikLocalApi => _mikrotikLocalApi;
  set mikrotikLocalApi(MikrotikLocalApi? value) {
    _mikrotikLocalApi = value;
    notifyListeners();
  }

  // ─── Nombre del router local ───
  String _nombreRouterLocal = '';
  String get nombreRouterLocal => _nombreRouterLocal;
  set nombreRouterLocal(String value) {
    _nombreRouterLocal = value;
    notifyListeners();
  }

  // ─── IP del router local ───
  String _ipRouterLocal = '';
  String get ipRouterLocal => _ipRouterLocal;
  set ipRouterLocal(String value) {
    _ipRouterLocal = value;
    notifyListeners();
  }

  // ─── Método para desconectar ───
  void desconectarLocal() {
    _isConnectedLocal = false;
    _mikrotikLocalApi = null;
    _nombreRouterLocal = '';
    _ipRouterLocal = '';
    notifyListeners();
  }

  // ─── Método para conectar ───
  void conectarLocal({
    required MikrotikLocalApi api,
    required String nombre,
    required String ip,
  }) {
    _mikrotikLocalApi = api;
    _nombreRouterLocal = nombre;
    _ipRouterLocal = ip;
    _isConnectedLocal = true;
    notifyListeners();
  }
}

Color? _colorFromIntValue(int? val) {
  if (val == null) {
    return null;
  }
  return Color(val);
}
