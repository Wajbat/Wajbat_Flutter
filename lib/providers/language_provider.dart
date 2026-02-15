import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  String _currentLanguage = 'en'; // Default
  SharedPreferences? _prefs;

  String get currentLanguage => _currentLanguage;
  bool get isRTL => _currentLanguage == 'ar';
  Locale get currentLocale => Locale(_currentLanguage);

  LanguageProvider() {
    loadLanguage();
  }

  Future<void> loadLanguage() async {
    _prefs = await SharedPreferences.getInstance();
    _currentLanguage = _prefs?.getString('language_code') ?? 'en';
    notifyListeners();
  }

  Future<void> changeLanguage(String languageCode) async {
    if (_currentLanguage == languageCode) return;
    
    _currentLanguage = languageCode;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString('language_code', languageCode);
    notifyListeners();
  }
}
