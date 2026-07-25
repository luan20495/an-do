import 'package:an_do/core/routing/osrm_client.dart';
import 'package:an_do/features/report/data/road_hazard_repository.dart';
import 'package:an_do/features/sos/data/sos_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  test('demo SOS seed matches prototype cases and replays to listeners', () async {
    final repo = DemoSosRepository(now: DateTime.utc(2026, 7, 25));
    expect(repo.current, hasLength(3));
    expect(repo.current.first.id, 'AD-742819');
    expect(repo.current.first.accuracyMeters, 7);

    final first = await repo.watchActive().first;
    expect(first.map((e) => e.id), [
      'AD-742819',
      'AD-291604',
      'AD-508337',
    ]);

    await repo.finish('AD-291604');
    final after = await repo.watchActive().first;
    expect(after.map((e) => e.id), ['AD-742819', 'AD-508337']);
  });

  test('demo road hazards seed two warnings', () async {
    final repo = DemoRoadHazardRepository();
    final hazards = await repo.watch().first;
    expect(hazards, hasLength(2));
    expect(hazards.first.label, contains('Ngập'));
  });

  test('OSRM falls back to demo routes when request fails', () async {
    final client = MockClient((_) async => http.Response('nope', 500));
    final routes = await OsrmClient(client: client).routes(
      from: const LatLng(21.0285, 105.8542),
      to: const LatLng(21.0486, 105.8187),
    );
    expect(routes, hasLength(3));
    expect(routes.first.title, contains('demo'));
    expect(routes.first.points, isNotEmpty);
  });
}
