import 'package:an_do/features/sos/data/sos_repository.dart';
import 'package:an_do/features/sos_chat/data/sos_chat_repository.dart';

/// Shared in-memory repos for offline / unit tests — **no seed data**.
abstract final class DemoWorld {
  static LocalSosChatRepository? _chat;
  static LocalSosRepository? _sos;

  static LocalSosChatRepository get chat =>
      _chat ??= LocalSosChatRepository();

  static LocalSosRepository get sos => _sos ??= LocalSosRepository();

  static void reset() {
    _chat = null;
    _sos = null;
  }
}
