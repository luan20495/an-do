import 'dart:async';

import 'package:an_do/core/firebase/an_do_firebase.dart';
import 'package:an_do/firebase_options.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

abstract final class FirebaseBootstrap {
  static const enabled =
      bool.fromEnvironment('FIREBASE_ENABLED', defaultValue: true);
  static const production =
      bool.fromEnvironment('PRODUCTION', defaultValue: false);

  static Future<bool> initialize() async {
    if (!enabled) return false;
    try {
      final packageName = (await PackageInfo.fromPlatform()).packageName;
      final options =
          DefaultFirebaseOptions.androidForPackageName(packageName);
      await _ensureInitialized(options);

      // Prefer persisted anonymous session (works offline once created).
      var user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        user = await _signInAnonymouslyWithRetry();
      }
      final uid = user?.uid ?? FirebaseAuth.instance.currentUser?.uid;
      debugPrint('Firebase anonymous uid=$uid');

      try {
        AnDoFirebase.database.setPersistenceEnabled(true);
      } catch (error) {
        debugPrint('RTDB persistence skipped: $error');
      }

      try {
        await FirebaseAppCheck.instance
            .activate(
              providerAndroid: production
                  ? const AndroidPlayIntegrityProvider()
                  : const AndroidDebugProvider(),
            )
            .timeout(const Duration(seconds: 3));
      } catch (error, stack) {
        debugPrint('App Check skipped: $error\n$stack');
      }

      if (uid == null) {
        debugPrint(
          'Firebase Auth unavailable (no network / sign-in failed). '
          'App continues in local demo mode.',
        );
        return false;
      }
      return true;
    } catch (error, stack) {
      debugPrint('Firebase bootstrap failed: $error\n$stack');
      return false;
    }
  }

  /// Keep retries short — Play cold start must not sit on a blank/spinner long.
  static Future<User?> _signInAnonymouslyWithRetry() async {
    const attempts = 2;
    for (var i = 0; i < attempts; i++) {
      final online = await _hasUsableNetwork();
      if (!online && i == 0) {
        // One short wait only; then fail soft.
        await _waitForNetwork(timeout: const Duration(seconds: 2));
      }
      try {
        final cred = await FirebaseAuth.instance
            .signInAnonymously()
            .timeout(const Duration(seconds: 4));
        return cred.user;
      } on TimeoutException {
        debugPrint('Firebase Auth sign-in timed out (attempt ${i + 1})');
      } on FirebaseAuthException catch (error) {
        final networkish = error.code == 'network-request-failed' ||
            error.code == 'too-many-requests' ||
            error.code == 'unavailable';
        debugPrint(
          'Firebase Auth sign-in failed '
          '(${error.code}, attempt ${i + 1}/$attempts): ${error.message}',
        );
        if (!networkish || i == attempts - 1) break;
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
    return FirebaseAuth.instance.currentUser;
  }

  static Future<bool> _hasUsableNetwork() async {
    try {
      final results = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(seconds: 1));
      if (results.isEmpty) return false;
      return results.any(
        (r) =>
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.ethernet ||
            r == ConnectivityResult.vpn,
      );
    } catch (_) {
      return true; // Unknown — still attempt Auth once.
    }
  }

  static Future<void> _waitForNetwork({required Duration timeout}) async {
    final online = await _hasUsableNetwork();
    if (online) return;
    try {
      await Connectivity()
          .onConnectivityChanged
          .firstWhere(
            (results) => results.any(
              (r) =>
                  r == ConnectivityResult.mobile ||
                  r == ConnectivityResult.wifi ||
                  r == ConnectivityResult.ethernet ||
                  r == ConnectivityResult.vpn,
            ),
          )
          .timeout(timeout);
    } on TimeoutException {
      // Fall through.
    } catch (_) {}
  }

  static Future<void> _ensureInitialized(FirebaseOptions options) async {
    if (Firebase.apps.isNotEmpty) return;
    try {
      await Firebase.initializeApp(options: options)
          .timeout(const Duration(seconds: 4));
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    } on TimeoutException {
      debugPrint('Firebase.initializeApp timed out');
      rethrow;
    }
  }
}
