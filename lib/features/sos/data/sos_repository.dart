import 'dart:async';

import 'package:an_do/core/firebase/an_do_firebase.dart';
import 'package:an_do/features/sos/domain/sos_models.dart';
import 'package:firebase_database/firebase_database.dart';

abstract interface class SosRepository {
  Stream<List<SosSession>> watchActive();
  Stream<int> watchHelperCount(String sosId);
  Stream<List<String>> watchHelperIds(String sosId);
  Future<void> upsert(SosSession session);
  Future<void> finish(String id);
  Future<void> acceptHelp({required String sosId, required String helperId});
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
  Stream<int> watchHelperCount(String sosId) =>
      watchHelperIds(sosId).map((ids) => ids.length);

  @override
  Stream<List<String>> watchHelperIds(String sosId) => AnDoFirebase.database
      .ref('sos_assignments/$sosId')
      .onValue
      .map((event) {
        final value = event.snapshot.value;
        if (value is! Map) return const <String>[];
        return value.keys.map((e) => e.toString()).toList()..sort();
      });

  @override
  Future<void> upsert(SosSession session) =>
      _ref.child(session.id).set(session.toJson());

  @override
  Future<void> finish(String id) => _ref.child(id).update({
        'active': false,
        'finishedAt': ServerValue.timestamp,
      });

  @override
  Future<void> acceptHelp({
    required String sosId,
    required String helperId,
  }) =>
      AnDoFirebase.database.ref('sos_assignments/$sosId/$helperId').set({
        'acceptedAt': ServerValue.timestamp,
        'status': 'heading_to_scene',
      });
}

/// Empty in-memory SOS store (no seed / no fake helpers).
/// Used only when Firebase is unavailable — starts blank.
class LocalSosRepository implements SosRepository {
  final _controller = StreamController<List<SosSession>>.broadcast();
  final Map<String, StreamController<int>> _helperControllers = {};
  final Map<String, StreamController<List<String>>> _helperIdControllers = {};
  final Map<String, Set<String>> _helpers = {};
  final List<SosSession> _items = [];

  List<SosSession> get current => List.unmodifiable(_items);

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_items));
    }
  }

  void _emitHelpers(String sosId) {
    final ids = (_helpers[sosId]?.toList() ?? <String>[])..sort();
    final countController = _helperControllers[sosId];
    if (countController != null && !countController.isClosed) {
      countController.add(ids.length);
    }
    final idsController = _helperIdControllers[sosId];
    if (idsController != null && !idsController.isClosed) {
      idsController.add(ids);
    }
  }

  @override
  Stream<List<SosSession>> watchActive() async* {
    yield List.unmodifiable(_items);
    yield* _controller.stream;
  }

  @override
  Stream<int> watchHelperCount(String sosId) {
    final controller = _helperControllers.putIfAbsent(
      sosId,
      StreamController<int>.broadcast,
    );
    scheduleMicrotask(() {
      if (!controller.isClosed) {
        controller.add(_helpers[sosId]?.length ?? 0);
      }
    });
    return controller.stream;
  }

  @override
  Stream<List<String>> watchHelperIds(String sosId) {
    final controller = _helperIdControllers.putIfAbsent(
      sosId,
      StreamController<List<String>>.broadcast,
    );
    scheduleMicrotask(() {
      if (!controller.isClosed) {
        final ids = (_helpers[sosId]?.toList() ?? <String>[])..sort();
        controller.add(ids);
      }
    });
    return controller.stream;
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
    _helpers.remove(id);
    _emitHelpers(id);
    _emit();
  }

  @override
  Future<void> acceptHelp({
    required String sosId,
    required String helperId,
  }) async {
    final set = _helpers.putIfAbsent(sosId, () => <String>{});
    if (set.add(helperId)) {
      _emitHelpers(sosId);
    }
  }
}

/// @Deprecated Use [LocalSosRepository]. Kept as typedef for older tests.
typedef DemoSosRepository = LocalSosRepository;

SosRepository createSosRepository({required bool firebaseReady}) =>
    firebaseReady ? FirebaseSosRepository() : LocalSosRepository();
