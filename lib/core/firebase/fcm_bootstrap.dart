import 'dart:async';
import 'dart:io';

import 'package:an_do/core/firebase/an_do_firebase.dart';
import 'package:an_do/features/sos_chat/data/sos_chat_repository.dart';
import 'package:an_do/features/sos_chat/presentation/sos_chat_thread_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Global navigator for FCM deep links into SOS chat threads.
final GlobalKey<NavigatorState> anDoNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Data-only handling; system tray shows the notification payload from CF.
  debugPrint('FCM background: ${message.data}');
}

abstract final class FcmBootstrap {
  static StreamSubscription<RemoteMessage>? _opened;
  static StreamSubscription<String>? _tokenRefresh;

  static Future<void> initialize({required bool firebaseReady}) async {
    if (!firebaseReady || kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await messaging.getToken();
    await _persistToken(token);

    await _tokenRefresh?.cancel();
    _tokenRefresh = messaging.onTokenRefresh.listen(_persistToken);

    await _opened?.cancel();
    _opened = FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _openFromMessage(initial);
    }
  }

  static Future<void> _persistToken(String? token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || token == null || token.isEmpty) return;
    await AnDoFirebase.database.ref('user_tokens/$uid').set({
      'token': token,
      'updatedAt': ServerValue.timestamp,
    });
  }

  static void _openFromMessage(RemoteMessage message) {
    final sosId = message.data['sosId'];
    final helperId = message.data['helperId'];
    final ownerId = message.data['ownerId'];
    if (sosId == null || helperId == null || ownerId == null) return;
    final viewerId = FirebaseAuth.instance.currentUser?.uid;
    if (viewerId == null) return;
    final peerLabel = viewerId == ownerId
        ? 'Helper ${helperId.length > 8 ? '${helperId.substring(0, 8)}…' : helperId}'
        : 'SOS $sosId';
    final nav = anDoNavigatorKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => SosChatThreadPage(
          sosId: sosId,
          helperId: helperId,
          ownerId: ownerId,
          viewerId: viewerId,
          peerLabel: peerLabel,
          chatRepository: createSosChatRepository(firebaseReady: true),
        ),
      ),
    );
  }
}
