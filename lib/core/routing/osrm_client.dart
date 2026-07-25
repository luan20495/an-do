import 'dart:convert';
import 'dart:math' as math;

import 'package:an_do/core/routing/route_models.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

class OsrmClient {
  OsrmClient({
    http.Client? client,
    this.baseUrl = 'https://router.project-osrm.org',
    this.allowDemoFallback = false,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  final bool allowDemoFallback;

  Future<List<RescueRoute>> routes({
    required LatLng from,
    required LatLng to,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/route/v1/driving/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?alternatives=true&overview=full&geometries=geojson&steps=false',
      );
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Routing failed: ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes =
          (body['routes'] as List? ?? const []).cast<Map<String, dynamic>>();
      if (routes.isEmpty) throw Exception('No routes');
      return routes.take(3).toList().asMap().entries.map((entry) {
        final route = entry.value;
        final geometry = route['geometry'] as Map<String, dynamic>;
        final coordinates = (geometry['coordinates'] as List).cast<List>();
        return RescueRoute(
          id: 'route-${entry.key}',
          title: entry.key == 0 ? 'Nhanh nhất' : 'Tuyến thay thế ${entry.key}',
          distanceMeters: (route['distance'] as num).toDouble(),
          durationSeconds: (route['duration'] as num).toDouble(),
          riskScore: entry.key * 18,
          points: coordinates
              .map(
                (c) => LatLng(
                  (c[1] as num).toDouble(),
                  (c[0] as num).toDouble(),
                ),
              )
              .toList(),
        );
      }).toList();
    } catch (_) {
      if (!allowDemoFallback) return const [];
      return demoFallbackRoutes(from: from, to: to);
    }
  }

  /// Offline / OSRM-down fallback so rescue UI stays usable with dummy data.
  static List<RescueRoute> demoFallbackRoutes({
    required LatLng from,
    required LatLng to,
  }) {
    final meters = _haversineMeters(from, to);
    final midA = LatLng(
      (from.latitude * 2 + to.latitude) / 3,
      (from.longitude * 2 + to.longitude) / 3 + 0.004,
    );
    final midB = LatLng(
      (from.latitude + to.latitude * 2) / 3,
      (from.longitude + to.longitude * 2) / 3 - 0.003,
    );
    return [
      RescueRoute(
        id: 'demo-fast',
        title: 'Nhanh nhất (demo)',
        distanceMeters: meters,
        durationSeconds: meters / 8.5,
        riskScore: 12,
        points: [from, midA, to],
      ),
      RescueRoute(
        id: 'demo-safe',
        title: 'Tuyến an toàn (demo)',
        distanceMeters: meters * 1.18,
        durationSeconds: meters / 7.2,
        riskScore: 4,
        points: [from, midB, to],
      ),
      RescueRoute(
        id: 'demo-alt',
        title: 'Tuyến thay thế (demo)',
        distanceMeters: meters * 1.32,
        durationSeconds: meters / 6.5,
        riskScore: 22,
        points: [
          from,
          LatLng(from.latitude + 0.006, from.longitude - 0.002),
          midB,
          to,
        ],
      ),
    ];
  }

  static double _haversineMeters(LatLng a, LatLng b) {
    const earth = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * earth * math.asin(math.sqrt(h));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
