import 'package:an_do/core/firebase/an_do_firebase.dart';
import 'package:an_do/firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

abstract final class FirebaseBootstrap {
  static const enabled =
      bool.fromEnvironment('FIREBASE_ENABLED', defaultValue: false);
  static const production =
      bool.fromEnvironment('PRODUCTION', defaultValue: false);

  static Future<bool> initialize() async {
    if (!enabled) return false;
    try {
      final packageName = (await PackageInfo.fromPlatform()).packageName;
      final options =
          DefaultFirebaseOptions.androidForPackageName(packageName);
      await _ensureInitialized(options);

      // Auth first — App Check must not block sign-in during early setup.
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      final uid = FirebaseAuth.instance.currentUser?.uid;
      debugPrint('Firebase anonymous uid=$uid');

      try {
        AnDoFirebase.database.setPersistenceEnabled(true);
      } catch (error) {
        debugPrint('RTDB persistence skipped: $error');
      }

      try {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: production
              ? const AndroidPlayIntegrityProvider()
              : const AndroidDebugProvider(),
        );
      } catch (error, stack) {
        debugPrint('App Check skipped: $error\n$stack');
      }

      return uid != null;
    } catch (error, stack) {
      debugPrint('Firebase bootstrap failed: $error\n$stack');
      return false;
    }
  }

  static Future<void> _ensureInitialized(FirebaseOptions options) async {
    if (Firebase.apps.isNotEmpty) return;
    try {
      await Firebase.initializeApp(options: options);
    } on FirebaseException catch (error) {
      // Native google-services may race and create [DEFAULT] first.
      if (error.code != 'duplicate-app') rethrow;
    }
  }
}
