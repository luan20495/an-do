import 'dart:io';

import 'package:an_do/features/sos/data/sos_repository.dart';
import 'package:an_do/features/sos/domain/sos_models.dart';
import 'package:an_do/features/sos_chat/data/sos_chat_repository.dart';
import 'package:an_do/features/sos_chat/domain/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  late File victimAudio;
  late File helperAudio;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('an_do_chat_roles_');
    victimAudio = File('${tmp.path}/victim_voice.m4a')
      ..writeAsBytesSync(List<int>.filled(64, 1));
    helperAudio = File('${tmp.path}/helper_voice.m4a')
      ..writeAsBytesSync(List<int>.filled(64, 2));
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('Nạn nhân (owner)', () {
    test('SOS thật → helper accept thật → text+audio 2 chiều', () async {
      final sos = LocalSosRepository();
      final chat = LocalSosChatRepository();
      const ownerId = 'victim-uid';
      const helperId = 'helper-uid';
      const sosId = 'VIC-01';

      await sos.upsert(
        SosSession(
          id: sosId,
          ownerId: ownerId,
          latitude: 21.0285,
          longitude: 105.8542,
          updatedAt: DateTime.now(),
          type: 'injury',
          peopleCount: 1,
          description: 'Bị thương',
          profile: const SosProfile(name: 'Lan'),
        ),
      );
      await sos.acceptHelp(sosId: sosId, helperId: helperId);

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
        file: helperAudio,
        durationMs: 1800,
      );
      expect(await chat.watchOwnerUnreadTotal(sosId).first, 2);

      await chat.markRead(
        sosId: sosId,
        helperId: helperId,
        ownerId: ownerId,
        viewerId: ownerId,
      );

      await chat.sendText(
        sosId: sosId,
        helperId: helperId,
        ownerId: ownerId,
        senderId: ownerId,
        text: 'Tôi còn tỉnh',
      );
      await chat.sendAudio(
        sosId: sosId,
        helperId: helperId,
        ownerId: ownerId,
        senderId: ownerId,
        file: victimAudio,
        durationMs: 2200,
      );

      final meta = await chat
          .watchThreadMeta(sosId: sosId, helperId: helperId)
          .first;
      expect(meta.unreadForHelper, 2);
      expect(meta.lastType, ChatMessageType.audio);
    });
  });

  group('Người cứu hộ', () {
    test('nhận ca → text+audio → nhận phản hồi', () async {
      final sos = LocalSosRepository();
      final chat = LocalSosChatRepository();
      const ownerId = 'victim-uid';
      const helperId = 'rescuer-uid';
      const sosId = 'RES-01';

      await sos.upsert(
        SosSession(
          id: sosId,
          ownerId: ownerId,
          latitude: 21.03,
          longitude: 105.85,
          updatedAt: DateTime.now(),
          type: 'other',
          peopleCount: 1,
          description: 'Cần hỗ trợ',
          profile: const SosProfile(name: 'Lan'),
        ),
      );
      await sos.acceptHelp(sosId: sosId, helperId: helperId);

      await chat.sendText(
        sosId: sosId,
        helperId: helperId,
        ownerId: ownerId,
        senderId: helperId,
        text: 'Giữ máy nhé',
      );
      await chat.sendAudio(
        sosId: sosId,
        helperId: helperId,
        ownerId: ownerId,
        senderId: helperId,
        file: helperAudio,
        durationMs: 1500,
      );
      expect(await chat.watchOwnerUnreadTotal(sosId).first, 2);

      await chat.sendAudio(
        sosId: sosId,
        helperId: helperId,
        ownerId: ownerId,
        senderId: ownerId,
        file: victimAudio,
        durationMs: 900,
      );
      final meta = await chat
          .watchThreadMeta(sosId: sosId, helperId: helperId)
          .first;
      expect(meta.unreadForHelper, 1);
    });
  });
}
