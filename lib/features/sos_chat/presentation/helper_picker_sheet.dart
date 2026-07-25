import 'package:an_do/core/i18n/strings.dart';
import 'package:an_do/core/theme/app_theme.dart';
import 'package:an_do/features/sos_chat/data/sos_chat_repository.dart';
import 'package:an_do/features/sos_chat/domain/chat_models.dart';
import 'package:flutter/material.dart';

Future<String?> showHelperPickerSheet({
  required BuildContext context,
  required String sosId,
  required String ownerId,
  required List<String> helperIds,
  required SosChatRepository chatRepository,
}) {
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _HelperPickerSheet(
      sosId: sosId,
      ownerId: ownerId,
      helperIds: helperIds,
      chatRepository: chatRepository,
    ),
  );
}

class _HelperPickerSheet extends StatelessWidget {
  const _HelperPickerSheet({
    required this.sosId,
    required this.ownerId,
    required this.helperIds,
    required this.chatRepository,
  });

  final String sosId;
  final String ownerId;
  final List<String> helperIds;
  final SosChatRepository chatRepository;

  @override
  Widget build(BuildContext context) {
    final strings = S(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: SizedBox(width: 40, child: Divider(thickness: 5))),
          Text(
            strings.chatHelpersTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            strings.chatHelpersSubtitle,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 14),
          if (helperIds.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                strings.helpersWatching(0),
                style: const TextStyle(color: Colors.black54),
              ),
            )
          else
            // Avoid Flexible inside mainAxisSize.min Column (layout thrash / ANR risk).
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: helperIds.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final helperId = helperIds[index];
                return StreamBuilder<ChatThreadMeta>(
                  stream: chatRepository.watchThreadMeta(
                    sosId: sosId,
                    helperId: helperId,
                  ),
                  builder: (context, snap) {
                    final meta = snap.data ??
                        ChatThreadMeta(sosId: sosId, helperId: helperId);
                    final unread = meta.unreadForOwner;
                    final short = helperId.length > 8
                        ? '${helperId.substring(0, 8)}…'
                        : helperId;
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      tileColor: const Color(0xFFF3F7F5),
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.brand.withValues(alpha: .15),
                        child: const Icon(Icons.person, color: AppTheme.brand),
                      ),
                      title: Text(
                        '${strings.helperLabel} $short',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        meta.lastMessage.isEmpty
                            ? strings.chatEmptyThread
                            : meta.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: unread > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.danger,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$unread',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.pop(context, helperId),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
