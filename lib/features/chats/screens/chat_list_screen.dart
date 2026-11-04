import 'package:flutter/material.dart';
import '../../../models/chat_model.dart';
import '../../../models/user_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../contacts/screens/search_screen.dart';
import '../../profile/screens/profile_screen.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _firestoreService = FirestoreService();
  final _authService = FirebaseAuthService();

  @override
  void initState() {
    super.initState();
    // Create a profile for accounts that don't have one yet.
    final user = _authService.currentUser;
    if (user != null) {
      _firestoreService.ensureUserExists(user);
    }
  }

  /// Today -> "14:05", older -> "03/11"
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final isToday = time.year == now.year &&
        time.month == now.month &&
        time.day == now.day;

    if (isToday) {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    final d = time.day.toString().padLeft(2, '0');
    final mo = time.month.toString().padLeft(2, '0');
    return '$d/$mo';
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 56, color: Color(0xFF94A3B8)),
            SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF172554),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the button below to find people and start chatting.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6366F1);
    final myUid = _authService.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF172554),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_rounded, color: Color(0xFF64748B)),
            tooltip: 'My profile',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B)),
            tooltip: 'Log out',
            onPressed: () => _authService.logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        tooltip: 'Find people',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SearchScreen()),
          );
        },
        child: const Icon(Icons.edit_rounded),
      ),
      body: StreamBuilder<List<ChatModel>>(
        stream: _firestoreService.chatsStream(myUid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Could not load chats.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          final chats = snapshot.data!;
          if (chats.isEmpty) return _buildEmpty();

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
            itemCount: chats.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final chat = chats[index];
              return _ChatTile(
                chat: chat,
                myUid: myUid,
                timeText: _formatTime(chat.lastMessageTime),
                firestoreService: _firestoreService,
              );
            },
          );
        },
      ),
    );
  }
}

/// One row in the chat list. It loads the other person's profile live,
/// so a name change shows up here automatically.
class _ChatTile extends StatelessWidget {
  final ChatModel chat;
  final String myUid;
  final String timeText;
  final FirestoreService firestoreService;

  const _ChatTile({
    required this.chat,
    required this.myUid,
    required this.timeText,
    required this.firestoreService,
  });

  @override
  Widget build(BuildContext context) {
    final otherUid = chat.otherUserId(myUid);

    return StreamBuilder<UserModel?>(
      stream: firestoreService.userStream(otherUid),
      builder: (context, snapshot) {
        final other = snapshot.data;
        final name = other?.name ?? 'Loading...';
        final preview = chat.lastSenderId == myUid
            ? 'You: ${chat.lastMessage}'
            : chat.lastMessage;

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: other == null
                ? null
                : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(otherUser: other),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF172554),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    timeText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
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