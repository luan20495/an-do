import 'dart:async';

import 'package:an_do/app/an_do_app.dart';
import 'package:an_do/core/firebase/fcm_bootstrap.dart';
import 'package:an_do/core/firebase/firebase_bootstrap.dart';
import 'package:an_do/core/location/sos_foreground_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

Future<void> bootstrap() async {
  // Always surface framework errors — never leave them silent for Play crashes.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught: $error\n$stack');
    return true;
  };

  FlutterForegroundTask.initCommunicationPort();

  // Cap cold-start wait so a bad network never freezes launch (Play ANR risk).
  final firebaseReady = await FirebaseBootstrap.initialize()
      .timeout(const Duration(seconds: 6), onTimeout: () {
    debugPrint('Firebase bootstrap timed out — continuing without cloud.');
    return false;
  });

  try {
    await SosForegroundService.initialize();
  } catch (error, stack) {
    debugPrint('Foreground service init skipped: $error\n$stack');
  }

  try {
    await FcmBootstrap.initialize(firebaseReady: firebaseReady)
        .timeout(const Duration(seconds: 4));
  } catch (error, stack) {
    debugPrint('FCM bootstrap skipped: $error\n$stack');
  }

  if (firebaseReady) {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  runApp(AnDoApp(firebaseReady: firebaseReady));
}
