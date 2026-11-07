import '../../../common/widgets/group_avatar.dart';
import 'chat_options.dart';

import 'package:flutter/material.dart';

import '../../../models/chat_model.dart';
import '../../../models/user_model.dart';
import '../../../services/firestore_service.dart';
import '../screens/group_chat_screen.dart';

/// One group row in the chat list.
class GroupTile extends StatelessWidget {
  final ChatModel chat;
  final String myUid;
  final String timeText;
  final FirestoreService firestoreService;

  const GroupTile({
    super.key,
    required this.chat,
    required this.myUid,
    required this.timeText,
    required this.firestoreService,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unread = chat.unreadFor(myUid);
    final hasUnread = unread > 0;

    return StreamBuilder<UserModel?>(
      stream: firestoreService.userStream(chat.lastSenderId),
      builder: (context, snapshot) {
        final sender = snapshot.data;
        final who = chat.lastSenderId == myUid
            ? 'You'
            : (sender?.name.split(' ').first ?? '');
        final preview = who.isEmpty
            ? chat.lastMessage
            : '$who: ${chat.lastMessage}';

        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onLongPress: () =>
                showChatOptions(context, chat, myUid, firestoreService),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GroupChatScreen(
                    chatId: chat.id,
                    groupName: chat.groupName,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  GroupAvatar(photoBase64: chat.groupPhoto, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chat.groupName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: hasUnread
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: hasUnread
                                ? cs.onSurface
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 12,
                          color: hasUnread
                              ? const Color(0xFF6366F1)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      ChatFlags(chat: chat, myUid: myUid),
                      if (hasUnread) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
