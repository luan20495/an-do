import 'dart:ui';

import 'package:an_do/app/an_do_app.dart';
import 'package:an_do/core/firebase/firebase_bootstrap.dart';
import 'package:an_do/core/location/sos_foreground_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

Future<void> bootstrap() async {
  FlutterForegroundTask.initCommunicationPort();
  final firebaseReady = await FirebaseBootstrap.initialize();
  await SosForegroundService.initialize();

  if (firebaseReady) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  runApp(AnDoApp(firebaseReady: firebaseReady));
}
