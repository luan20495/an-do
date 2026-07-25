import 'dart:async';

import 'package:an_do/core/firebase/fcm_bootstrap.dart';
import 'package:an_do/core/i18n/app_language_controller.dart';
import 'package:an_do/core/theme/app_theme.dart';
import 'package:an_do/features/map/presentation/map_screen.dart';
import 'package:an_do/features/onboarding/presentation/language_gate.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AnDoApp extends StatefulWidget {
  const AnDoApp({required this.firebaseReady, super.key});
  final bool firebaseReady;

  @override
  State<AnDoApp> createState() => _AnDoAppState();
}

class _AnDoAppState extends State<AnDoApp> {
  final AppLanguageController _language = AppLanguageController();

  static const _localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    // Cupertino has no Vietnamese pack; use a delegate that accepts all locales.
    _FallbackCupertinoLocalizationsDelegate(),
  ];

  @override
  void initState() {
    super.initState();
    // Never block first frame on prefs — hydrate in background.
    unawaited(_hydrateLanguage());
  }

  Future<void> _hydrateLanguage() async {
    try {
      await _language.load().timeout(const Duration(seconds: 3));
      if (mounted) setState(() {});
    } catch (error, stack) {
      debugPrint('Language prefs load failed: $error\n$stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _language,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: anDoNavigatorKey,
        title: 'An Đồ',
        locale: _language.locale,
        supportedLocales: AppLanguageController.supportedLocales,
        localizationsDelegates: _localizationsDelegates,
        theme: AppTheme.light,
        home: _language.hasChosenLanguage
            ? MapScreen(language: _language, firebaseReady: widget.firebaseReady)
            : LanguageGate(language: _language),
      ),
    );
  }
}

/// Provides Cupertino strings for locales Flutter doesn't ship (e.g. `vi`).
class _FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _FallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      DefaultCupertinoLocalizations.load(locale);

  @override
  bool shouldReload(_FallbackCupertinoLocalizationsDelegate old) => false;
}
