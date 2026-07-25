import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguageController extends ChangeNotifier {
  static const _languageKey = 'selected_language';
  static const supportedLocales = [Locale('vi'), Locale('en')];

  Locale _locale = const Locale('vi');
  bool _hasChosenLanguage = false;

  Locale get locale => _locale;
  bool get hasChosenLanguage => _hasChosenLanguage;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_languageKey);
    if (code != null) {
      _locale = Locale(code);
      _hasChosenLanguage = true;
    }
  }

  Future<void> choose(String code) async {
    _locale = Locale(code == 'en' ? 'en' : 'vi');
    _hasChosenLanguage = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, _locale.languageCode);
    notifyListeners();
  }

  Future<void> change(String code) => choose(code);
}
