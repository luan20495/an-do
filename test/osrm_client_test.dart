import 'package:an_do/core/routing/osrm_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  test('parses alternative rescue routes', () async {
    final client = MockClient((request) async => http.Response(
      '{"routes":[{"distance":1200,"duration":300,"geometry":{"coordinates":[[105.8,21.0],[105.81,21.01]]}}]}',
      200,
    ));
    final routes = await OsrmClient(client: client, allowDemoFallback: false).routes(
      from: const LatLng(21, 105.8),
      to: const LatLng(21.01, 105.81),
    );
    expect(routes, hasLength(1));
    expect(routes.first.distanceMeters, 1200);
    expect(routes.first.points.last.latitude, 21.01);
  });
}
