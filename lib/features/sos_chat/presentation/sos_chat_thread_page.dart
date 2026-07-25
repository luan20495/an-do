import 'dart:async';
import 'dart:io';

import 'package:an_do/core/i18n/strings.dart';
import 'package:an_do/core/theme/app_theme.dart';
import 'package:an_do/features/sos_chat/data/sos_chat_repository.dart';
import 'package:an_do/features/sos_chat/domain/chat_models.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class SosChatThreadPage extends StatefulWidget {
  const SosChatThreadPage({
    required this.sosId,
    required this.helperId,
    required this.ownerId,
    required this.viewerId,
    required this.peerLabel,
    required this.chatRepository,
    super.key,
  });

  final String sosId;
  final String helperId;
  final String ownerId;
  final String viewerId;
  final String peerLabel;
  final SosChatRepository chatRepository;

  @override
  State<SosChatThreadPage> createState() => _SosChatThreadPageState();
}

class _SosChatThreadPageState extends State<SosChatThreadPage> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  AudioRecorder? _recorder;
  AudioPlayer? _player;
  StreamSubscription<List<ChatMessage>>? _sub;
  List<ChatMessage> _messages = const [];
  bool _recording = false;
  bool _cancelRecording = false;
  DateTime? _recordStartedAt;
  String? _playingId;
  Offset? _pointerStart;

  AudioRecorder get _audioRecorder => _recorder ??= AudioRecorder();
  AudioPlayer get _audioPlayer => _player ??= AudioPlayer();

  @override
  void initState() {
    super.initState();
    _sub = widget.chatRepository
        .watchMessages(sosId: widget.sosId, helperId: widget.helperId)
        .listen(
      (messages) {
        if (!mounted) return;
        setState(() => _messages = messages);
        unawaited(_markRead());
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      },
      onError: (Object error) => debugPrint('Chat messages stream: $error'),
    );
    unawaited(_markRead());
  }

  Future<void> _markRead() async {
    try {
      await widget.chatRepository.markRead(
        sosId: widget.sosId,
        helperId: widget.helperId,
        ownerId: widget.ownerId,
        viewerId: widget.viewerId,
      );
    } catch (error) {
      debugPrint('Chat markRead skipped: $error');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _text.dispose();
    _scroll.dispose();
    unawaited(_recorder?.dispose() ?? Future<void>.value());
    unawaited(_player?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  Future<void> _sendText() async {
    final value = _text.text;
    _text.clear();
    try {
      await widget.chatRepository
          .sendText(
            sosId: widget.sosId,
            helperId: widget.helperId,
            ownerId: widget.ownerId,
            senderId: widget.viewerId,
            text: value,
          )
          .timeout(const Duration(seconds: 12));
    } catch (error) {
      debugPrint('Chat sendText failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không gửi được tin nhắn. Thử lại.')),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S(context).micPermissionDenied)),
          );
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/sos_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _recording = true;
        _cancelRecording = false;
        _recordStartedAt = DateTime.now();
      });
      unawaited(HapticFeedback.mediumImpact());
    } catch (error) {
      debugPrint('Chat record start failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không ghi âm được. Thử lại.')),
        );
      }
    }
  }

  Future<void> _stopRecording({required bool send}) async {
    if (!_recording) return;
    try {
      final path = await _audioRecorder.stop();
      final started = _recordStartedAt;
      if (!mounted) return;
      setState(() {
        _recording = false;
        _recordStartedAt = null;
      });
      if (!send || _cancelRecording || path == null || started == null) {
        if (path != null) {
          try {
            await File(path).delete();
          } catch (_) {}
        }
        return;
      }
      final durationMs = DateTime.now().difference(started).inMilliseconds;
      if (durationMs < 400) {
        try {
          await File(path).delete();
        } catch (_) {}
        return;
      }
      await widget.chatRepository
          .sendAudio(
            sosId: widget.sosId,
            helperId: widget.helperId,
            ownerId: widget.ownerId,
            senderId: widget.viewerId,
            file: File(path),
            durationMs: durationMs,
          )
          .timeout(const Duration(seconds: 30));
    } catch (error) {
      debugPrint('Chat sendAudio failed: $error');
      if (mounted) {
        setState(() {
          _recording = false;
          _recordStartedAt = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không gửi được tin thoại. Thử lại.')),
        );
      }
    }
  }

  Future<void> _togglePlay(ChatMessage message) async {
    final source = message.audioUrl ?? message.audioPath;
    if (source == null) return;
    try {
      if (_playingId == message.id) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _playingId = null);
        return;
      }
      await _audioPlayer.stop();
      if (source.startsWith('http')) {
        await _audioPlayer.play(UrlSource(source));
      } else {
        await _audioPlayer.play(DeviceFileSource(source));
      }
      if (!mounted) return;
      setState(() => _playingId = message.id);
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playingId = null);
      });
    } catch (error) {
      debugPrint('Chat play failed: $error');
      if (mounted) {
        setState(() => _playingId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không phát được tin thoại.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = S(context);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.peerLabel,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            Text(
              'SOS ${widget.sosId}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        strings.chatEmptyHint,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final mine = message.senderId == widget.viewerId;
                      return _Bubble(
                        mine: mine,
                        message: message,
                        playing: _playingId == message.id,
                        onPlay: () => unawaited(_togglePlay(message)),
                      );
                    },
                  ),
          ),
          if (_recording)
            Container(
              width: double.infinity,
              color: _cancelRecording
                  ? const Color(0xFFFFE7E9)
                  : const Color(0xFFE7F5F1),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Text(
                _cancelRecording
                    ? strings.chatReleaseToCancel
                    : strings.chatRecording,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _cancelRecording ? AppTheme.danger : AppTheme.brand,
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => unawaited(_sendText()),
                      decoration: InputDecoration(
                        hintText: strings.chatHint,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => unawaited(_sendText()),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.brand,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.send_rounded),
                  ),
                  const SizedBox(width: 4),
                  Listener(
                    onPointerDown: (event) {
                      _pointerStart = event.position;
                      unawaited(_startRecording());
                    },
                    onPointerMove: (event) {
                      final start = _pointerStart;
                      if (start == null) return;
                      final cancel = start.dy - event.position.dy > 80;
                      if (cancel != _cancelRecording) {
                        setState(() => _cancelRecording = cancel);
                      }
                    },
                    onPointerUp: (_) {
                      unawaited(_stopRecording(send: !_cancelRecording));
                      _pointerStart = null;
                    },
                    onPointerCancel: (_) {
                      unawaited(_stopRecording(send: false));
                      _pointerStart = null;
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: _recording ? 64 : 52,
                      height: _recording ? 64 : 52,
                      decoration: BoxDecoration(
                        color: _recording
                            ? (_cancelRecording
                                ? AppTheme.danger
                                : AppTheme.brand)
                            : AppTheme.brand.withValues(alpha: .12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mic_rounded,
                        color: _recording ? Colors.white : AppTheme.brand,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.mine,
    required this.message,
    required this.playing,
    required this.onPlay,
  });

  final bool mine;
  final ChatMessage message;
  final bool playing;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final align = mine ? Alignment.centerRight : Alignment.centerLeft;
    final bg = mine ? AppTheme.brand : Colors.white;
    final fg = mine ? Colors.white : AppTheme.ink;
    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 6),
            bottomRight: Radius.circular(mine ? 6 : 18),
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: message.isAudio
            ? InkWell(
                onTap: onPlay,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      color: fg,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(message.durationMs ?? 0),
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              )
            : Text(
                message.text,
                style: TextStyle(color: fg, height: 1.35),
              ),
      ),
    );
  }

  String _formatDuration(int ms) {
    final total = (ms / 1000).round().clamp(0, 9999);
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
