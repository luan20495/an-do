import 'dart:async';

/// Road hazard shown on the map (user-reported or synced from cloud).
class RoadHazard {
  const RoadHazard({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.label,
    this.severity = 'medium',
  });

  final String id;
  final double latitude;
  final double longitude;
  final String type;
  final String label;
  final String severity;
}

abstract interface class RoadHazardRepository {
  Stream<List<RoadHazard>> watch();
  Future<void> add(RoadHazard hazard);
}

/// Starts empty — only hazards the user actually reports appear.
class LocalRoadHazardRepository implements RoadHazardRepository {
  final _controller = StreamController<List<RoadHazard>>.broadcast();
  final List<RoadHazard> _items = [];

  List<RoadHazard> get current => List.unmodifiable(_items);

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_items));
    }
  }

  @override
  Stream<List<RoadHazard>> watch() async* {
    yield List.unmodifiable(_items);
    yield* _controller.stream;
  }

  @override
  Future<void> add(RoadHazard hazard) async {
    _items.removeWhere((e) => e.id == hazard.id);
    _items.add(hazard);
    _emit();
  }
}

typedef DemoRoadHazardRepository = LocalRoadHazardRepository;
