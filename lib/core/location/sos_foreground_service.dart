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
        // v2: DEFAULT importance so the ongoing SOS share is visible in the shade
        // (channel settings are immutable after first create on Android 8+).
        channelId: 'an_do_sos_tracking_v2',
        channelName: 'Chia sẻ vị trí SOS',
        channelDescription:
            'Hiển thị khi An Đồ đang cập nhật vị trí cho phiên SOS do bạn chủ động phát.',
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
        onlyAlertOnce: true,
        showWhen: true,
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
    await FlutterForegroundTask.saveData(key: 'helperCount', value: 0);
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    }
    return FlutterForegroundTask.startService(
      serviceId: 7011,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: 'An Đồ đang chia sẻ vị trí',
      notificationText: 'Phiên SOS đang cập nhật vị trí cứu hộ trên nền trước.',
      notificationIcon: null,
      callback: startCallback,
    );
  }

  /// Called from the UI isolate when helper count changes for the active SOS.
  static Future<void> updateHelperCount(int count) async {
    await FlutterForegroundTask.saveData(key: 'helperCount', value: count);
    if (!await FlutterForegroundTask.isRunningService) return;
    if (count <= 0) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'An Đồ đang chia sẻ vị trí',
        notificationText: 'Phiên SOS đang cập nhật vị trí cứu hộ trên nền trước.',
      );
      return;
    }
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Có người đang hỗ trợ bạn',
      notificationText: count == 1
          ? '1 người đang để ý phiên SOS của bạn.'
          : '$count người đang để ý phiên SOS của bạn.',
    );
  }

  static Future<ServiceRequestResult> stop() => FlutterForegroundTask.stopService();
}

class SosLocationTaskHandler extends TaskHandler {
  bool _firebaseReady = false;
  String? _sosId;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      _sosId = await FlutterForegroundTask.getData<String>(key: 'sosId');
      final enabled =
          await FlutterForegroundTask.getData<bool>(key: 'firebaseEnabled') ??
              false;
      if (enabled) {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          ).timeout(const Duration(seconds: 5));
        }
        _firebaseReady = true;
      }
    } catch (_) {
      _firebaseReady = false;
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
      final helpers =
          await FlutterForegroundTask.getData<int>(key: 'helperCount') ?? 0;
      final time =
          '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}';
      if (helpers > 0) {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Có người đang hỗ trợ bạn',
          notificationText: helpers == 1
              ? '1 người đang để ý · GPS $time'
              : '$helpers người đang để ý · GPS $time',
        );
      } else {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'An Đồ đang chia sẻ vị trí',
          notificationText: 'Vị trí SOS cập nhật lúc $time',
        );
      }
    } catch (_) {}
  }

  @override Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
  @override void onReceiveData(Object data) {}
  @override void onNotificationButtonPressed(String id) {}
  @override void onNotificationPressed() { FlutterForegroundTask.launchApp('/'); }
  @override void onNotificationDismissed() {}
}
