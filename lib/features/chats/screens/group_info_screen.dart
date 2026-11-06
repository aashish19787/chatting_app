import 'package:flutter/material.dart';

import '../../../common/widgets/user_avatar.dart';
import '../../../models/chat_model.dart';
import '../../../models/user_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';

class GroupInfoScreen extends StatelessWidget {
  final String chatId;

  GroupInfoScreen({super.key, required this.chatId});

  final _firestoreService = FirestoreService();
  final _authService = FirebaseAuthService();

  Future<void> _leave(BuildContext context, String myUid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave group?'),
        content: const Text(
          'You will no longer receive messages from this group.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Leave',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _firestoreService.leaveGroup(chatId, myUid);
      // Back to the chat list (past the group chat screen).
      navigator.popUntil((route) => route.isFirst);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not leave the group.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _authService.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Group info',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<ChatModel?>(
        stream: _firestoreService.chatStream(chatId),
        builder: (context, snapshot) {
          final chat = snapshot.data;
          if (chat == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  height: 90,
                  width: 90,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  chat.groupName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  '${chat.participants.length} members',
                  style: const TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Members',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              ...chat.participants.map(
                (uid) => StreamBuilder<UserModel?>(
                  stream: _firestoreService.userStream(uid),
                  builder: (context, userSnapshot) {
                    final user = userSnapshot.data;
                    final name = user?.name ?? 'Loading...';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: UserAvatar(
                        name: name,
                        photoBase64: user?.photoBase64 ?? '',
                        size: 44,
                      ),
                      title: Text(uid == myUid ? '$name (You)' : name),
                      subtitle: Text(user?.email ?? ''),
                      trailing: uid == chat.createdBy
                          ? const Text(
                              'Creator',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6366F1),
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _leave(context, myUid),
                icon: const Icon(Icons.exit_to_app_rounded),
                label: const Text('Leave group'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
