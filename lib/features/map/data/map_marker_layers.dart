import 'package:an_do/features/report/data/road_hazard_repository.dart';
import 'package:an_do/features/sos/domain/sos_models.dart';
import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Fast marker updates via one GeoJSON source (avoids N× addCircle ANRs).
class MapMarkerLayers {
  MapMarkerLayers(this._controller);

  static const sosSource = 'an_do_sos_src';
  static const sosLayer = 'an_do_sos_lyr';
  static const hazardSource = 'an_do_hazard_src';
  static const hazardLayer = 'an_do_hazard_lyr';

  final MapLibreMapController _controller;
  bool _ready = false;
  String? _signature;

  Future<void> ensureLayers() async {
    if (_ready) return;
    try {
      await _controller.addGeoJsonSource(sosSource, _emptyCollection());
      await _controller.addCircleLayer(
        sosSource,
        sosLayer,
        const CircleLayerProperties(
          circleRadius: [Expressions.get, 'r'],
          circleColor: [Expressions.get, 'c'],
          circleOpacity: 0.92,
          circleStrokeWidth: 3,
          circleStrokeColor: '#FFFFFF',
        ),
      );

      await _controller.addGeoJsonSource(hazardSource, _emptyCollection());
      await _controller.addCircleLayer(
        hazardSource,
        hazardLayer,
        const CircleLayerProperties(
          circleRadius: [Expressions.get, 'r'],
          circleColor: [Expressions.get, 'c'],
          circleOpacity: 0.94,
          circleStrokeWidth: 3,
          circleStrokeColor: '#FFFFFF',
        ),
      );
      _ready = true;
    } catch (error, stack) {
      debugPrint('Map marker layers init failed: $error\n$stack');
      _ready = false;
    }
  }

  Future<void> sync({
    required List<SosSession> sessions,
    required List<RoadHazard> hazards,
    String? selectedSosId,
    String? selectedHazardId,
  }) async {
    await ensureLayers();
    if (!_ready) return;

    final cappedSessions = sessions.take(25).toList();
    final cappedHazards = hazards.take(25).toList();
    final signature =
        '${cappedSessions.map((e) => '${e.id}:${e.latitude.toStringAsFixed(4)}:${e.longitude.toStringAsFixed(4)}').join('|')}'
        '#${cappedHazards.map((e) => e.id).join('|')}'
        '#$selectedSosId#$selectedHazardId';
    if (signature == _signature) return;
    _signature = signature;

    try {
      await _controller.setGeoJsonSource(
        sosSource,
        _collection(
          cappedSessions.map(
            (s) => _pointFeature(
              id: s.id,
              lat: s.latitude,
              lng: s.longitude,
              selected: s.id == selectedSosId,
              kind: 'sos',
              color: s.id == selectedSosId ? '#9F1239' : '#E11D48',
              radius: s.id == selectedSosId ? 15.0 : 11.0,
            ),
          ),
        ),
      );
      // Yield so input events can flush between platform calls.
      await Future<void>.delayed(Duration.zero);
      await _controller.setGeoJsonSource(
        hazardSource,
        _collection(
          cappedHazards.map(
            (h) => _pointFeature(
              id: h.id,
              lat: h.latitude,
              lng: h.longitude,
              selected: h.id == selectedHazardId,
              kind: 'hazard',
              color: h.id == selectedHazardId ? '#B45309' : '#D97706',
              radius: h.id == selectedHazardId ? 14.0 : 11.0,
            ),
          ),
        ),
      );
    } catch (error) {
      debugPrint('Map marker sync skipped: $error');
      _signature = null;
    }
  }

  void invalidate() => _signature = null;

  static Map<String, dynamic> _emptyCollection() => _collection(const []);

  static Map<String, dynamic> _collection(
    Iterable<Map<String, dynamic>> features,
  ) =>
      {
        'type': 'FeatureCollection',
        'features': features.toList(),
      };

  static Map<String, dynamic> _pointFeature({
    required String id,
    required double lat,
    required double lng,
    required bool selected,
    required String kind,
    required String color,
    required double radius,
  }) =>
      {
        'type': 'Feature',
        'id': id,
        'properties': {
          'id': id,
          'kind': kind,
          'selected': selected ? 1 : 0,
          'c': color,
          'r': radius,
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [lng, lat],
        },
      };
}
