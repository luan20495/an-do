import 'package:an_do/features/sos/data/sos_repository.dart';
import 'package:an_do/features/sos/domain/sos_models.dart';
import 'package:an_do/features/sos_chat/data/sos_chat_repository.dart';
import 'package:an_do/features/sos_chat/domain/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real-path logic with empty local repos (no seeded fake SOS / auto-helper).
void main() {
  test('2-user: helper joins manually, chats, unread, owner replies', () async {
    final sos = LocalSosRepository();
    final chat = LocalSosChatRepository();

    const ownerId = 'owner-1';
    const helperId = 'helper-1';
    final session = SosSession(
      id: 'TEST-2U',
      ownerId: ownerId,
      latitude: 21.0285,
      longitude: 105.8542,
      updatedAt: DateTime.now(),
      type: 'other',
      peopleCount: 1,
      description: 'Need help',
      profile: const SosProfile(name: 'Nạn nhân'),
    );

    await sos.upsert(session);
    expect(await sos.watchActive().first, isNotEmpty);

    await sos.acceptHelp(sosId: 'TEST-2U', helperId: helperId);
    expect(await sos.watchHelperIds('TEST-2U').first, contains(helperId));
    expect(await sos.watchHelperCount('TEST-2U').first, 1);

    await chat.sendText(
      sosId: 'TEST-2U',
      helperId: helperId,
      ownerId: ownerId,
      senderId: helperId,
      text: 'Tôi thấy SOS của bạn.',
    );
    await chat.sendText(
      sosId: 'TEST-2U',
      helperId: helperId,
      ownerId: ownerId,
      senderId: helperId,
      text: 'Bạn còn an toàn không?',
    );

    expect(await chat.watchOwnerUnreadTotal('TEST-2U').first, 2);

    await chat.markRead(
      sosId: 'TEST-2U',
      helperId: helperId,
      ownerId: ownerId,
      viewerId: ownerId,
    );
    expect(await chat.watchOwnerUnreadTotal('TEST-2U').first, 0);

    await chat.sendText(
      sosId: 'TEST-2U',
      helperId: helperId,
      ownerId: ownerId,
      senderId: ownerId,
      text: 'Tôi còn ở đây, cần giúp đỡ.',
    );

    final meta = await chat
        .watchThreadMeta(sosId: 'TEST-2U', helperId: helperId)
        .first;
    expect(meta.unreadForHelper, 1);
    expect(meta.unreadForOwner, 0);
    expect(meta.lastType, ChatMessageType.text);

    await sos.finish('TEST-2U');
    expect(
      (await sos.watchActive().first).any((e) => e.id == 'TEST-2U'),
      isFalse,
    );
  });
}
