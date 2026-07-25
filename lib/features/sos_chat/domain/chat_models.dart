enum ChatMessageType { text, audio }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.type,
    required this.createdAt,
    this.text = '',
    this.audioUrl,
    this.audioPath,
    this.durationMs,
    this.readAt,
  });

  final String id;
  final String senderId;
  final ChatMessageType type;
  final DateTime createdAt;
  final String text;
  final String? audioUrl;
  final String? audioPath;
  final int? durationMs;
  final DateTime? readAt;

  bool get isAudio => type == ChatMessageType.audio;

  factory ChatMessage.fromJson(String id, Map<Object?, Object?> json) {
    final typeRaw = json['type']?.toString() ?? 'text';
    return ChatMessage(
      id: id,
      senderId: json['senderId']?.toString() ?? '',
      type: typeRaw == 'audio' ? ChatMessageType.audio : ChatMessageType.text,
      text: json['text']?.toString() ?? '',
      audioUrl: json['audioUrl']?.toString(),
      audioPath: json['audioPath']?.toString(),
      durationMs: (json['durationMs'] as num?)?.toInt(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num?)?.toInt() ?? 0,
      ),
      readAt: json['readAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (json['readAt'] as num).toInt(),
            ),
    );
  }

  Map<String, Object?> toJson() => {
        'senderId': senderId,
        'type': type == ChatMessageType.audio ? 'audio' : 'text',
        'text': text,
        if (audioUrl != null) 'audioUrl': audioUrl,
        if (audioPath != null) 'audioPath': audioPath,
        if (durationMs != null) 'durationMs': durationMs,
        'createdAt': createdAt.millisecondsSinceEpoch,
        if (readAt != null) 'readAt': readAt!.millisecondsSinceEpoch,
      };
}

class ChatThreadMeta {
  const ChatThreadMeta({
    required this.sosId,
    required this.helperId,
    this.lastMessage = '',
    this.lastType = ChatMessageType.text,
    this.updatedAt,
    this.unreadForOwner = 0,
    this.unreadForHelper = 0,
  });

  final String sosId;
  final String helperId;
  final String lastMessage;
  final ChatMessageType lastType;
  final DateTime? updatedAt;
  final int unreadForOwner;
  final int unreadForHelper;

  int unreadFor({required String viewerId, required String ownerId}) =>
      viewerId == ownerId ? unreadForOwner : unreadForHelper;

  factory ChatThreadMeta.fromJson(
    String sosId,
    String helperId,
    Map<Object?, Object?> json,
  ) {
    final typeRaw = json['lastType']?.toString() ?? 'text';
    return ChatThreadMeta(
      sosId: sosId,
      helperId: helperId,
      lastMessage: json['lastMessage']?.toString() ?? '',
      lastType:
          typeRaw == 'audio' ? ChatMessageType.audio : ChatMessageType.text,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (json['updatedAt'] as num).toInt(),
            ),
      unreadForOwner: (json['unreadForOwner'] as num?)?.toInt() ?? 0,
      unreadForHelper: (json['unreadForHelper'] as num?)?.toInt() ?? 0,
    );
  }
}
