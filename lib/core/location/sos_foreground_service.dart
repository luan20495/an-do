import 'dart:async';

import 'package:an_do/core/firebase/an_do_firebase.dart';
import 'package:an_do/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SosLocationTaskHandler());
}

class SosForegroundService {
  static Future<void> initialize() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'an_do_sos_tracking',
        channelName: 'SOS location tracking',
        channelDescription: 'Keeps SOS location updates active in the background.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(10000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<ServiceRequestResult> start({
    required String sosId,
    required bool firebaseEnabled,
  }) async {
    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    await FlutterForegroundTask.saveData(key: 'sosId', value: sosId);
    await FlutterForegroundTask.saveData(
      key: 'firebaseEnabled',
      value: firebaseEnabled,
    );
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    }
    return FlutterForegroundTask.startService(
      serviceId: 7011,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: 'SOS đang được phát',
      notificationText: 'An Đồ đang cập nhật vị trí cho phiên cứu hộ.',
      notificationIcon: null,
      callback: startCallback,
    );
  }

  static Future<ServiceRequestResult> stop() => FlutterForegroundTask.stopService();
}

class SosLocationTaskHandler extends TaskHandler {
  bool _firebaseReady = false;
  String? _sosId;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _sosId = await FlutterForegroundTask.getData<String>(key: 'sosId');
    final enabled = await FlutterForegroundTask.getData<bool>(key: 'firebaseEnabled') ?? false;
    if (enabled) {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      _firebaseReady = true;
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_capture());
  }

  Future<void> _capture() async {
    final id = _sosId;
    if (id == null) return;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );
      final data = <String, Object>{
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracyMeters': position.accuracy,
        'speed': position.speed,
        'bearing': position.heading,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      FlutterForegroundTask.sendDataToMain(data);
      if (_firebaseReady) {
        await AnDoFirebase.database.ref('active_sos/$id').update(data);
      }
      await FlutterForegroundTask.updateService(
        notificationTitle: 'SOS đang được phát',
        notificationText: 'Vị trí cập nhật lúc ${DateTime.now().hour.toString().padLeft(2,'0')}:${DateTime.now().minute.toString().padLeft(2,'0')}',
      );
    } catch (_) {}
  }

  @override Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
  @override void onReceiveData(Object data) {}
  @override void onNotificationButtonPressed(String id) {}
  @override void onNotificationPressed() { FlutterForegroundTask.launchApp('/'); }
  @override void onNotificationDismissed() {}
}
