import 'package:flutter/material.dart';

import '../../../models/chat_model.dart';
import '../../../services/firestore_service.dart';

/// Long-press menu on a chat row: Pin / Mute.
void showChatOptions(
  BuildContext context,
  ChatModel chat,
  String myUid,
  FirestoreService service,
) {
  final pinned = chat.isPinnedFor(myUid);
  final muted = chat.isMutedFor(myUid);
  final messenger = ScaffoldMessenger.of(context);

  Future<void> run(String field, bool on) async {
    try {
      await service.setChatFlag(chat.id, field, myUid, on);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  showModalBottomSheet(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
            ),
            title: Text(pinned ? 'Unpin chat' : 'Pin chat'),
            onTap: () {
              Navigator.pop(sheetContext);
              run('pinned', !pinned);
            },
          ),
          ListTile(
            leading: Icon(
              muted
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
            ),
            title: Text(muted ? 'Unmute notifications' : 'Mute notifications'),
            onTap: () {
              Navigator.pop(sheetContext);
              run('muted', !muted);
            },
          ),
        ],
      ),
    ),
  );
}

/// Tiny pin / mute icons shown on a chat row.
class ChatFlags extends StatelessWidget {
  final ChatModel chat;
  final String myUid;

  const ChatFlags({super.key, required this.chat, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final pinned = chat.isPinnedFor(myUid);
    final muted = chat.isMutedFor(myUid);
    if (!pinned && !muted) return const SizedBox.shrink();

    const color = Color(0xFF94A3B8);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (muted)
            const Icon(
              Icons.notifications_off_outlined,
              size: 14,
              color: color,
            ),
          if (muted && pinned) const SizedBox(width: 4),
          if (pinned)
            const Icon(Icons.push_pin_rounded, size: 14, color: color),
        ],
      ),
    );
  }
}
