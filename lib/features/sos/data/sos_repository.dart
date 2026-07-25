import 'dart:async';

import 'package:an_do/core/firebase/an_do_firebase.dart';
import 'package:an_do/features/sos/domain/sos_models.dart';
import 'package:firebase_database/firebase_database.dart';

abstract interface class SosRepository {
  Stream<List<SosSession>> watchActive();
  Future<void> upsert(SosSession session);
  Future<void> finish(String id);
}

class FirebaseSosRepository implements SosRepository {
  FirebaseSosRepository() : _ref = AnDoFirebase.database.ref('active_sos');
  final DatabaseReference _ref;

  @override
  Stream<List<SosSession>> watchActive() => _ref.onValue.map((event) {
        final value = event.snapshot.value;
        if (value is! Map) return const <SosSession>[];
        return value.entries
            .where((e) => e.value is Map)
            .map(
              (e) => SosSession.fromJson(
                e.key.toString(),
                Map<Object?, Object?>.from(e.value as Map),
              ),
            )
            .where((e) => e.active)
            .toList();
      });

  @override
  Future<void> upsert(SosSession session) =>
      _ref.child(session.id).set(session.toJson());

  @override
  Future<void> finish(String id) => _ref.child(id).update({
        'active': false,
        'finishedAt': ServerValue.timestamp,
      });
}

/// Local seed data for UI / rescue flow checks without Firebase.
class DemoSosRepository implements SosRepository {
  DemoSosRepository({DateTime? now}) : _now = now ?? DateTime.now() {
    _items.addAll(_seed(_now));
  }

  final DateTime _now;
  final _controller = StreamController<List<SosSession>>.broadcast();
  final List<SosSession> _items = [];

  static List<SosSession> _seed(DateTime now) => [
        SosSession(
          id: 'AD-742819',
          ownerId: 'demo-1',
          latitude: 21.0486,
          longitude: 105.8187,
          updatedAt: now.subtract(const Duration(seconds: 8)),
          type: 'flood',
          peopleCount: 4,
          description: 'Đang mắc kẹt ở tầng 2, nước tiếp tục dâng.',
          profile: const SosProfile(name: 'Minh Anh', phone: '0901234567'),
          batteryPercent: 42,
          accuracyMeters: 7,
        ),
        SosSession(
          id: 'AD-291604',
          ownerId: 'demo-2',
          latitude: 21.0178,
          longitude: 105.8068,
          updatedAt: now.subtract(const Duration(seconds: 42)),
          type: 'injury',
          peopleCount: 1,
          description: 'Ngã xe, chân khó di chuyển.',
          profile: const SosProfile(name: 'Người dùng An Đồ'),
          batteryPercent: 61,
          accuracyMeters: 11,
        ),
        SosSession(
          id: 'AD-508337',
          ownerId: 'demo-3',
          latitude: 21.0610,
          longitude: 105.8510,
          updatedAt: now.subtract(const Duration(minutes: 2)),
          type: 'vehicle',
          peopleCount: 2,
          description: 'Xe chết máy ở khu vực ngập.',
          profile: const SosProfile(name: 'Hoàng Nam', phone: '0912345678'),
          batteryPercent: 73,
          accuracyMeters: 8,
        ),
      ];

  List<SosSession> get current => List.unmodifiable(_items);

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_items));
    }
  }

  @override
  Stream<List<SosSession>> watchActive() async* {
    yield List.unmodifiable(_items);
    yield* _controller.stream;
  }

  @override
  Future<void> upsert(SosSession session) async {
    _items.removeWhere((e) => e.id == session.id);
    _items.add(session);
    _emit();
  }

  @override
  Future<void> finish(String id) async {
    _items.removeWhere((e) => e.id == id);
    _emit();
  }
}

SosRepository createSosRepository({required bool firebaseReady}) =>
    firebaseReady ? FirebaseSosRepository() : DemoSosRepository();
