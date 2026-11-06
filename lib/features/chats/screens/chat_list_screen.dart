
import 'dart:async';
import 'package:flutter/material.dart';

import '../../../models/chat_model.dart';
import '../../../models/user_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../common/widgets/user_avatar.dart';
import '../../../services/notification_service.dart';

import '../../contacts/screens/search_screen.dart';
import '../../profile/screens/profile_screen.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with WidgetsBindingObserver {
  final _firestoreService = FirestoreService();
  final _authService = FirebaseAuthService();

  Timer? _heartbeat;

  StreamSubscription<List<ChatModel>>? _chatSub;
  final Map<String, DateTime> _knownTimes = {};
  bool _firstChatEvent = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final user = _authService.currentUser;
    if (user == null) return;

    await _firestoreService.ensureUserExists(user);
    await NotificationService.instance.init();
    _goOnline();
    _listenForNewMessages(user.uid);
  }

  /// Shows a notification when another person sends a new message.
  void _listenForNewMessages(String myUid) {
    _chatSub = _firestoreService.chatsStream(myUid).listen((chats) async {
      // The first batch is just the existing chats.
      // Remember them, but don't notify about old messages.
      if (_firstChatEvent) {
        _firstChatEvent = false;

        for (final chat in chats) {
          _knownTimes[chat.id] = chat.lastMessageTime;
        }

        return;
      }

      for (final chat in chats) {
        final previous = _knownTimes[chat.id];
        _knownTimes[chat.id] = chat.lastMessageTime;

        final isNew =
            previous == null || chat.lastMessageTime.isAfter(previous);

        if (!isNew) continue;
        if (chat.lastSenderId == myUid) continue;
        if (NotificationService.instance.activeChatId == chat.id) continue;

        final sender = await _firestoreService.getUser(chat.lastSenderId);

        await NotificationService.instance.showMessage(
          chatId: chat.id,
          title: sender?.name ?? 'New message',
          body: chat.lastMessage,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeat?.cancel();
    _chatSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _goOnline();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _goOffline();
    }
  }

  void _goOnline() {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    _firestoreService.setOnlineStatus(uid, true);

    // Refresh "last seen" every minute while the app is open.
    _heartbeat?.cancel();

    _heartbeat = Timer.periodic(const Duration(seconds: 60), (_) {
      final id = _authService.currentUser?.uid;

      if (id != null) {
        _firestoreService.setOnlineStatus(id, true);
      }
    });
  }

  Future<void> _goOffline() async {
    _heartbeat?.cancel();

    final uid = _authService.currentUser?.uid;

    if (uid != null) {
      await _firestoreService.setOnlineStatus(uid, false);
    }
  }

  Future<void> _logout() async {
    // Must happen BEFORE signing out, because the write needs a login.
    await _goOffline();
    await _authService.logout();
  }

  // Today -> "14:05", older -> "03/11"
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
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 56,
              color: Color(0xFF94A3B8),
            ),
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
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
              ),
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
            icon: const Icon(
              Icons.person_rounded,
              color: Color(0xFF64748B),
            ),
            tooltip: 'My profile',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: Color(0xFF64748B),
            ),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        tooltip: 'Find people',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const SearchScreen(),
            ),
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
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            );
          }

          final chats = snapshot.data!;

          if (chats.isEmpty) return _buildEmpty();

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
            itemCount: chats.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
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
/// so name changes, profile pictures and online status update automatically.
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
    final unread = chat.unreadFor(myUid);
    final hasUnread = unread > 0;

    return StreamBuilder<UserModel?>(
      stream: firestoreService.userStream(otherUid),
      builder: (context, snapshot) {
        final other = snapshot.data;
        final name = other?.name ?? 'Loading...';
        final isOnline = other?.isActive ?? false;

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
                border: Border.all(
                  color: hasUnread
                      ? const Color(0xFF6366F1)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  // Profile picture with a green dot when online.
                  Stack(
                    children: [
                      UserAvatar(
                        name: name,
                        photoBase64: other?.photoBase64 ?? '',
                        size: 52,
                      ),
                      if (isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: 14,
                            width: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
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
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: hasUnread
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: hasUnread
                                ? const Color(0xFF172554)
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
