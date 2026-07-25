import 'dart:io';

import 'package:an_do/features/report/data/road_hazard_repository.dart';
import 'package:an_do/features/sos/data/sos_repository.dart';
import 'package:an_do/features/sos/domain/sos_models.dart';
import 'package:an_do/features/sos_chat/data/sos_chat_repository.dart';
import 'package:an_do/features/sos_chat/domain/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:an_do/core/routing/osrm_client.dart';

void main() {
  test('local SOS starts empty — no seed markers', () async {
    final repo = LocalSosRepository();
    expect(repo.current, isEmpty);
    expect(await repo.watchActive().first, isEmpty);
  });

  test('local SOS upsert/finish works without fake helpers', () async {
    final repo = LocalSosRepository();
    final session = SosSession(
      id: 'REAL-1',
      ownerId: 'owner-1',
      latitude: 21.03,
      longitude: 105.85,
      updatedAt: DateTime.utc(2026, 7, 25),
      type: 'other',
      peopleCount: 1,
      description: 'real',
      profile: const SosProfile(name: 'Lan'),
    );
    await repo.upsert(session);
    expect(await repo.watchActive().first, hasLength(1));
    expect(await repo.watchHelperCount('REAL-1').first, 0);

    await repo.acceptHelp(sosId: 'REAL-1', helperId: 'helper-a');
    expect(await repo.watchHelperCount('REAL-1').first, 1);

    await repo.finish('REAL-1');
    expect(await repo.watchActive().first, isEmpty);
  });

  test('local chat unread flips for owner and helper', () async {
    final chat = LocalSosChatRepository();
    await chat.sendText(
      sosId: 'AD-1',
      helperId: 'helper-1',
      ownerId: 'owner-1',
      senderId: 'helper-1',
      text: 'Đang tới',
    );
    expect(await chat.watchOwnerUnreadTotal('AD-1').first, 1);
    await chat.markRead(
      sosId: 'AD-1',
      helperId: 'helper-1',
      ownerId: 'owner-1',
      viewerId: 'owner-1',
    );
    expect(await chat.watchOwnerUnreadTotal('AD-1').first, 0);
  });

  test('local road hazards start empty', () async {
    final repo = LocalRoadHazardRepository();
    expect(await repo.watch().first, isEmpty);
  });

  test('OSRM returns empty when request fails (no demo fake routes)', () async {
    final client = MockClient((_) async => http.Response('nope', 500));
    final routes = await OsrmClient(
      client: client,
      allowDemoFallback: false,
    ).routes(
      from: const LatLng(21.0285, 105.8542),
      to: const LatLng(21.0486, 105.8187),
    );
    expect(routes, isEmpty);
  });

  test('victim and helper can exchange text+audio without auto-bot', () async {
    final sos = LocalSosRepository();
    final chat = LocalSosChatRepository();
    const ownerId = 'victim';
    const helperId = 'rescuer';
    const sosId = 'S1';

    await sos.upsert(
      SosSession(
        id: sosId,
        ownerId: ownerId,
        latitude: 21.03,
        longitude: 105.85,
        updatedAt: DateTime.now(),
        type: 'injury',
        peopleCount: 1,
        description: 'need help',
        profile: const SosProfile(name: 'Lan'),
      ),
    );
    await sos.acceptHelp(sosId: sosId, helperId: helperId);

    final tmp = await Directory.systemTemp.createTemp('an_do_audio_');
    final file = File('${tmp.path}/v.m4a')..writeAsBytesSync([1, 2, 3]);

    await chat.sendText(
      sosId: sosId,
      helperId: helperId,
      ownerId: ownerId,
      senderId: helperId,
      text: 'Tôi đang tới',
    );
    await chat.sendAudio(
      sosId: sosId,
      helperId: helperId,
      ownerId: ownerId,
      senderId: helperId,
      file: file,
      durationMs: 1200,
    );
    await chat.sendText(
      sosId: sosId,
      helperId: helperId,
      ownerId: ownerId,
      senderId: ownerId,
      text: 'Ok',
    );

    final msgs =
        await chat.watchMessages(sosId: sosId, helperId: helperId).first;
    expect(msgs, hasLength(3));
    expect(msgs[1].type, ChatMessageType.audio);
    expect(await chat.watchOwnerUnreadTotal(sosId).first, 2);

    await tmp.delete(recursive: true);
  });
}
