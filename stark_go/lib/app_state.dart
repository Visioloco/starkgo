import 'package:flutter/material.dart';

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

  String _menuActiveItem = 'Home';
  String get menuActiveItem => _menuActiveItem;
  set menuActiveItem(String value) {
    _menuActiveItem = value;
  }

  List<Color> _menuItemColors = [
    Color(4283120111),
    Color(4281979584),
    Color(4293823328),
    Color(4294924643),
    Color(4287566292)
  ];
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
}

Color? _colorFromIntValue(int? val) {
  if (val == null) {
    return null;
  }
  return Color(val);
}
