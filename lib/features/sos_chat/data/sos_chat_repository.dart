import 'dart:async';
import 'dart:io';

import 'package:an_do/core/firebase/an_do_firebase.dart';
import 'package:an_do/features/sos_chat/domain/chat_models.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

abstract interface class SosChatRepository {
  Stream<List<ChatMessage>> watchMessages({
    required String sosId,
    required String helperId,
  });

  Stream<ChatThreadMeta> watchThreadMeta({
    required String sosId,
    required String helperId,
  });

  /// Owner view: total unread across all helper threads for this SOS.
  Stream<int> watchOwnerUnreadTotal(String sosId);

  Future<void> sendText({
    required String sosId,
    required String helperId,
    required String ownerId,
    required String senderId,
    required String text,
  });

  Future<void> sendAudio({
    required String sosId,
    required String helperId,
    required String ownerId,
    required String senderId,
    required File file,
    required int durationMs,
  });

  Future<void> markRead({
    required String sosId,
    required String helperId,
    required String ownerId,
    required String viewerId,
  });
}

class FirebaseSosChatRepository implements SosChatRepository {
  DatabaseReference _thread(String sosId, String helperId) =>
      AnDoFirebase.database.ref('sos_chats/$sosId/$helperId');

  @override
  Stream<List<ChatMessage>> watchMessages({
    required String sosId,
    required String helperId,
  }) =>
      _thread(sosId, helperId).child('messages').onValue.map((event) {
        final value = event.snapshot.value;
        if (value is! Map) return const <ChatMessage>[];
        final list = value.entries
            .where((e) => e.value is Map)
            .map(
              (e) => ChatMessage.fromJson(
                e.key.toString(),
                Map<Object?, Object?>.from(e.value as Map),
              ),
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return list;
      });

  @override
  Stream<ChatThreadMeta> watchThreadMeta({
    required String sosId,
    required String helperId,
  }) =>
      _thread(sosId, helperId).child('meta').onValue.map((event) {
        final value = event.snapshot.value;
        if (value is! Map) {
          return ChatThreadMeta(sosId: sosId, helperId: helperId);
        }
        return ChatThreadMeta.fromJson(
          sosId,
          helperId,
          Map<Object?, Object?>.from(value),
        );
      });

  @override
  Stream<int> watchOwnerUnreadTotal(String sosId) =>
      AnDoFirebase.database.ref('sos_chats/$sosId').onValue.map((event) {
        final value = event.snapshot.value;
        if (value is! Map) return 0;
        var total = 0;
        for (final entry in value.entries) {
          if (entry.value is! Map) continue;
          final thread = Map<Object?, Object?>.from(entry.value as Map);
          final meta = thread['meta'];
          if (meta is Map) {
            total += (meta['unreadForOwner'] as num?)?.toInt() ?? 0;
          }
        }
        return total;
      });

  @override
  Future<void> sendText({
    required String sosId,
    required String helperId,
    required String ownerId,
    required String senderId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final id = const Uuid().v4().substring(0, 12);
    final now = DateTime.now().millisecondsSinceEpoch;
    final message = ChatMessage(
      id: id,
      senderId: senderId,
      type: ChatMessageType.text,
      text: trimmed,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
    final thread = _thread(sosId, helperId);
    await thread.child('messages/$id').set(message.toJson());
    await _bumpMeta(
      thread: thread,
      ownerId: ownerId,
      senderId: senderId,
      preview: trimmed,
      type: ChatMessageType.text,
      now: now,
    );
  }

  @override
  Future<void> sendAudio({
    required String sosId,
    required String helperId,
    required String ownerId,
    required String senderId,
    required File file,
    required int durationMs,
  }) async {
    final id = const Uuid().v4().substring(0, 12);
    final now = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'sos_chat_audio/$sosId/$helperId/$id.m4a';
    final ref = FirebaseStorage.instance.ref(storagePath);
    await ref
        .putFile(
          file,
          SettableMetadata(contentType: 'audio/mp4'),
        )
        .timeout(const Duration(seconds: 25));
    final url = await ref.getDownloadURL().timeout(const Duration(seconds: 8));
    final message = ChatMessage(
      id: id,
      senderId: senderId,
      type: ChatMessageType.audio,
      audioUrl: url,
      audioPath: storagePath,
      durationMs: durationMs,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
    final thread = _thread(sosId, helperId);
    await thread.child('messages/$id').set(message.toJson());
    await _bumpMeta(
      thread: thread,
      ownerId: ownerId,
      senderId: senderId,
      preview: '🎤 Audio',
      type: ChatMessageType.audio,
      now: now,
    );
  }

  Future<void> _bumpMeta({
    required DatabaseReference thread,
    required String ownerId,
    required String senderId,
    required String preview,
    required ChatMessageType type,
    required int now,
  }) async {
    final metaSnap = await thread.child('meta').get();
    var unreadOwner = 0;
    var unreadHelper = 0;
    if (metaSnap.value is Map) {
      final meta = Map<Object?, Object?>.from(metaSnap.value as Map);
      unreadOwner = (meta['unreadForOwner'] as num?)?.toInt() ?? 0;
      unreadHelper = (meta['unreadForHelper'] as num?)?.toInt() ?? 0;
    }
    if (senderId == ownerId) {
      unreadHelper += 1;
    } else {
      unreadOwner += 1;
    }
    await thread.child('meta').update({
      'lastMessage': preview.length > 80 ? '${preview.substring(0, 80)}…' : preview,
      'lastType': type == ChatMessageType.audio ? 'audio' : 'text',
      'updatedAt': now,
      'unreadForOwner': unreadOwner,
      'unreadForHelper': unreadHelper,
    });
  }

  @override
  Future<void> markRead({
    required String sosId,
    required String helperId,
    required String ownerId,
    required String viewerId,
  }) async {
    final thread = _thread(sosId, helperId);
    final field =
        viewerId == ownerId ? 'unreadForOwner' : 'unreadForHelper';
    await thread.child('meta').update({field: 0});
  }
}

class LocalSosChatRepository implements SosChatRepository {
  final _messages = <String, List<ChatMessage>>{};
  final _meta = <String, ChatThreadMeta>{};
  final _msgControllers = <String, StreamController<List<ChatMessage>>>{};
  final _metaControllers = <String, StreamController<ChatThreadMeta>>{};
  final _ownerUnreadControllers = <String, StreamController<int>>{};

  String _key(String sosId, String helperId) => '$sosId|$helperId';

  @override
  Stream<List<ChatMessage>> watchMessages({
    required String sosId,
    required String helperId,
  }) {
    final key = _key(sosId, helperId);
    final controller = _msgControllers.putIfAbsent(
      key,
      StreamController<List<ChatMessage>>.broadcast,
    );
    scheduleMicrotask(() {
      if (!controller.isClosed) {
        controller.add(List.unmodifiable(_messages[key] ?? const []));
      }
    });
    return controller.stream;
  }

  @override
  Stream<ChatThreadMeta> watchThreadMeta({
    required String sosId,
    required String helperId,
  }) {
    final key = _key(sosId, helperId);
    final controller = _metaControllers.putIfAbsent(
      key,
      StreamController<ChatThreadMeta>.broadcast,
    );
    scheduleMicrotask(() {
      if (!controller.isClosed) {
        controller.add(
          _meta[key] ?? ChatThreadMeta(sosId: sosId, helperId: helperId),
        );
      }
    });
    return controller.stream;
  }

  @override
  Stream<int> watchOwnerUnreadTotal(String sosId) {
    final controller = _ownerUnreadControllers.putIfAbsent(
      sosId,
      StreamController<int>.broadcast,
    );
    scheduleMicrotask(() {
      if (!controller.isClosed) controller.add(_ownerTotal(sosId));
    });
    return controller.stream;
  }

  int _ownerTotal(String sosId) {
    var total = 0;
    for (final entry in _meta.entries) {
      if (entry.key.startsWith('$sosId|')) {
        total += entry.value.unreadForOwner;
      }
    }
    return total;
  }

  void _emit(String sosId, String helperId) {
    final key = _key(sosId, helperId);
    final msgs = _msgControllers[key];
    if (msgs != null && !msgs.isClosed) {
      msgs.add(List.unmodifiable(_messages[key] ?? const []));
    }
    final metaC = _metaControllers[key];
    if (metaC != null && !metaC.isClosed) {
      metaC.add(
        _meta[key] ?? ChatThreadMeta(sosId: sosId, helperId: helperId),
      );
    }
    final ownerC = _ownerUnreadControllers[sosId];
    if (ownerC != null && !ownerC.isClosed) {
      ownerC.add(_ownerTotal(sosId));
    }
  }

  @override
  Future<void> sendText({
    required String sosId,
    required String helperId,
    required String ownerId,
    required String senderId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final key = _key(sosId, helperId);
    final id = const Uuid().v4().substring(0, 12);
    final msg = ChatMessage(
      id: id,
      senderId: senderId,
      type: ChatMessageType.text,
      text: trimmed,
      createdAt: DateTime.now(),
    );
    _messages.putIfAbsent(key, () => []).add(msg);
    final prev = _meta[key] ?? ChatThreadMeta(sosId: sosId, helperId: helperId);
    _meta[key] = ChatThreadMeta(
      sosId: sosId,
      helperId: helperId,
      lastMessage: trimmed,
      lastType: ChatMessageType.text,
      updatedAt: msg.createdAt,
      unreadForOwner:
          prev.unreadForOwner + (senderId == ownerId ? 0 : 1),
      unreadForHelper:
          prev.unreadForHelper + (senderId == ownerId ? 1 : 0),
    );
    _emit(sosId, helperId);
  }

  @override
  Future<void> sendAudio({
    required String sosId,
    required String helperId,
    required String ownerId,
    required String senderId,
    required File file,
    required int durationMs,
  }) async {
    final key = _key(sosId, helperId);
    final id = const Uuid().v4().substring(0, 12);
    final msg = ChatMessage(
      id: id,
      senderId: senderId,
      type: ChatMessageType.audio,
      audioPath: file.path,
      audioUrl: file.path,
      durationMs: durationMs,
      createdAt: DateTime.now(),
    );
    _messages.putIfAbsent(key, () => []).add(msg);
    final prev = _meta[key] ?? ChatThreadMeta(sosId: sosId, helperId: helperId);
    _meta[key] = ChatThreadMeta(
      sosId: sosId,
      helperId: helperId,
      lastMessage: '🎤 Audio',
      lastType: ChatMessageType.audio,
      updatedAt: msg.createdAt,
      unreadForOwner:
          prev.unreadForOwner + (senderId == ownerId ? 0 : 1),
      unreadForHelper:
          prev.unreadForHelper + (senderId == ownerId ? 1 : 0),
    );
    _emit(sosId, helperId);
  }

  @override
  Future<void> markRead({
    required String sosId,
    required String helperId,
    required String ownerId,
    required String viewerId,
  }) async {
    final key = _key(sosId, helperId);
    final prev = _meta[key] ?? ChatThreadMeta(sosId: sosId, helperId: helperId);
    _meta[key] = ChatThreadMeta(
      sosId: sosId,
      helperId: helperId,
      lastMessage: prev.lastMessage,
      lastType: prev.lastType,
      updatedAt: prev.updatedAt,
      unreadForOwner: viewerId == ownerId ? 0 : prev.unreadForOwner,
      unreadForHelper: viewerId == ownerId ? prev.unreadForHelper : 0,
    );
    _emit(sosId, helperId);
  }
}

SosChatRepository createSosChatRepository({required bool firebaseReady}) =>
    firebaseReady ? FirebaseSosChatRepository() : LocalSosChatRepository();

typedef DemoSosChatRepository = LocalSosChatRepository;
