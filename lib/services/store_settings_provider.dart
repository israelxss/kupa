import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  system,
  light,
  dark,
}

class StoreSettingsProvider extends ChangeNotifier {
  static const String _kSelectedChainsKey = 'selected_chains_v1';
  static const String _kThemeModeKey = 'theme_mode_v2';
  static const String _kOnboardingCompletedKey = 'onboarding_completed_v1';

  List<String> _myChains = [];
  AppThemeMode _themeMode = AppThemeMode.system;
  bool _isOnboardingCompleted = false;
  bool _isLoaded = false;

  List<String> get myChains => _myChains;
  AppThemeMode get themeMode => _themeMode;
  bool get isOnboardingCompleted => _isOnboardingCompleted;
  bool get isLoaded => _isLoaded;

  // חובה לפחות רשת אחת מוגדרת
  bool get hasConfiguredChains => _myChains.isNotEmpty;

  ThemeMode get flutterThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
      default:
        return ThemeMode.system;
    }
  }

  // רשימת 26 הרשתות המובילות בישראל
  static const List<Map<String, String>> allChains = [
    {'id': 'cerberus:ramilevi', 'name': 'רמי לוי'},
    {'id': 'shufersal:shufersal', 'name': 'שופרסל'},
    {'id': 'cerberus:osherad', 'name': 'אושר עד'},
    {'id': 'cerberus:yohananof', 'name': 'יוחננוף'},
    {'id': 'carrefour:carrefour', 'name': 'קרפור'},
    {'id': 'laib:victory', 'name': 'ויקטורי'},
    {'id': 'laib:mshuk', 'name': 'מחסני השוק'},
    {'id': 'cerberus:tivtaam', 'name': 'טיב טעם'},
    {'id': 'cerberus:keshet', 'name': 'קשת טעמים'},
    {'id': 'hazihinam:hazihinam', 'name': 'חצי חינם'},
    {'id': 'superpharm:superpharm', 'name': 'סופר פארם'},
    {'id': 'bina:kingstore', 'name': 'קינג סטור'},
    {'id': 'bina:zolvebegadol', 'name': 'זול ובגדול'},
    {'id': 'bina:maayan2000', 'name': 'מעיין 2000'},
    {'id': 'bina:superbareket', 'name': 'סופר ברקת'},
    {'id': 'cerberus:stop_market', 'name': 'סטופ מרקט'},
    {'id': 'cerberus:freshmarket', 'name': 'פרש מרקט'},
    {'id': 'cerberus:salachd', 'name': 'דבאח'},
    {'id': 'wolt:wolt', 'name': 'וולט מרקט'},
    {'id': 'kt:kt', 'name': 'משנת יוסף'},
    {'id': 'netivhesed:netivhesed', 'name': 'נתיב החסד'},
    {'id': 'citymarket:citymarket', 'name': 'סיטי מרקט'},
    {'id': 'bina:goodpharm', 'name': 'גוד פארם'},
    {'id': 'bina:supersapir', 'name': 'סופר ספיר'},
    {'id': 'bina:shuk-hayir', 'name': 'שוק העיר'},
    {'id': 'bina:shefabirkathashem', 'name': 'שפע ברכת השם'},
  ];

  StoreSettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_kThemeModeKey);
    if (savedMode == 'light') {
      _themeMode = AppThemeMode.light;
    } else if (savedMode == 'dark') {
      _themeMode = AppThemeMode.dark;
    } else {
      _themeMode = AppThemeMode.system;
    }

    _myChains = prefs.getStringList(_kSelectedChainsKey) ?? [];
    _isOnboardingCompleted = prefs.getBool(_kOnboardingCompletedKey) ?? false;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    if (_myChains.isEmpty) return; // לא ניתן להמשיך ללא בחירת לפחות רשת אחת
    _isOnboardingCompleted = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingCompletedKey, true);
    await prefs.setStringList(_kSelectedChainsKey, _myChains);
  }

  Future<void> cycleThemeMode() async {
    if (_themeMode == AppThemeMode.system) {
      _themeMode = AppThemeMode.dark;
    } else if (_themeMode == AppThemeMode.dark) {
      _themeMode = AppThemeMode.light;
    } else {
      _themeMode = AppThemeMode.system;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, _themeMode.name);
  }

  bool isChainSelected(String chainNameOrId) {
    return _myChains.contains(chainNameOrId);
  }

  Future<void> toggleChain(String chainName) async {
    if (_myChains.contains(chainName)) {
      _myChains.remove(chainName);
    } else {
      _myChains.add(chainName);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSelectedChainsKey, _myChains);
  }

  bool get isAllSelected => _myChains.length == allChains.length;

  Future<void> toggleSelectAll() async {
    if (isAllSelected) {
      _myChains.clear();
    } else {
      _myChains = allChains.map((c) => c['name']!).toList();
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSelectedChainsKey, _myChains);
  }

  Future<void> selectAllPopularChains() async {
    final popular = ['רמי לוי', 'שופרסל', 'אושר עד', 'יוחננוף', 'ויקטורי', 'קרפור'];
    for (var p in popular) {
      if (!_myChains.contains(p)) _myChains.add(p);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSelectedChainsKey, _myChains);
  }

  Future<void> clearFilter() async {
    _myChains.clear();
    _isOnboardingCompleted = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSelectedChainsKey);
    await prefs.remove(_kOnboardingCompletedKey);
  }
}
