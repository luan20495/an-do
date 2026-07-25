import 'dart:async';

/// Road hazard shown on the map (demo or synced later).
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

class DemoRoadHazardRepository implements RoadHazardRepository {
  DemoRoadHazardRepository() {
    _items.addAll(const [
      RoadHazard(
        id: 'warn-1',
        latitude: 21.0390,
        longitude: 105.8260,
        type: 'flood',
        label: 'Ngập sâu 40–50 cm',
        severity: 'high',
      ),
      RoadHazard(
        id: 'warn-2',
        latitude: 21.0450,
        longitude: 105.8208,
        type: 'fallen_tree',
        label: 'Cây đổ chắn nửa đường',
        severity: 'medium',
      ),
    ]);
  }

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
