import 'package:maplibre_gl/maplibre_gl.dart';

class RescueRoute {
  const RescueRoute({required this.id, required this.title, required this.distanceMeters, required this.durationSeconds, required this.points, required this.riskScore});
  final String id, title;
  final double distanceMeters, durationSeconds;
  final List<LatLng> points;
  final int riskScore;
}
