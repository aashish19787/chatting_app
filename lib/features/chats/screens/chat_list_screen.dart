import '../../../services/block_list.dart';
import '../widgets/chat_options.dart';
import '../widgets/active_now_strip.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../common/widgets/user_avatar.dart';
import '../../../models/chat_model.dart';
import '../../../models/user_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/notification_service.dart';
import '../../contacts/screens/search_screen.dart';
import '../widgets/group_tile.dart';
import 'chat_screen.dart';

enum ChatFilter { all, unread, groups }

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with WidgetsBindingObserver {
  static const _primary = Color(0xFF0F8A5D);

  final _firestoreService = FirestoreService();
  final _authService = FirebaseAuthService();
  final _searchController = TextEditingController();

  Timer? _heartbeat;
  StreamSubscription<List<ChatModel>>? _chatSub;
  final Map<String, DateTime> _knownTimes = {};
  bool _firstChatEvent = true;

  ChatFilter _filter = ChatFilter.all;
  String _query = '';

  // Names of the people in 1-to-1 chats (used by the search bar).
  final Map<String, UserModel> _users = {};
  final Set<String> _requested = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BlockList.instance.ids.addListener(_onBlocksChanged);
    _init();
  }

  void _onBlocksChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _init() async {
    final user = _authService.currentUser;
    if (user == null) return;

    await _firestoreService.ensureUserExists(user);
    await NotificationService.instance.init();
    _goOnline();
    _listenForNewMessages(user.uid);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    BlockList.instance.ids.removeListener(_onBlocksChanged);
    _heartbeat?.cancel();
    _chatSub?.cancel();
    _searchController.dispose();
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

    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 60), (_) {
      final id = _authService.currentUser?.uid;
      if (id != null) _firestoreService.setOnlineStatus(id, true);
    });
  }

  Future<void> _goOffline() async {
    _heartbeat?.cancel();
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      await _firestoreService.setOnlineStatus(uid, false);
    }
  }

  /// Shows a banner when another person sends a new message.
  void _listenForNewMessages(String myUid) {
    _chatSub = _firestoreService.chatsStream(myUid).listen((chats) async {
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
        if (chat.isMutedFor(myUid)) continue;
        if (NotificationService.instance.activeChatId == chat.id) continue;

        final sender = await _firestoreService.getUser(chat.lastSenderId);
        await NotificationService.instance.showMessage(
          chatId: chat.id,
          title: chat.isGroup
              ? chat.groupName
              : (sender?.name ?? 'New message'),
          body: chat.isGroup && sender != null
              ? '${sender.name}: ${chat.lastMessage}'
              : chat.lastMessage,
        );
      }
    });
  }

  void _loadNames(List<ChatModel> chats, String myUid) {
    final missing = chats
        .where((c) => !c.isGroup)
        .map((c) => c.otherUserId(myUid))
        .where(
          (u) =>
              u.isNotEmpty && !_users.containsKey(u) && !_requested.contains(u),
        )
        .toList();
    if (missing.isEmpty) return;
    _requested.addAll(missing);
    _firestoreService.getUsers(missing).then((found) {
      if (!mounted) return;
      setState(() => _users.addAll(found));
    });
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final isToday =
        time.year == now.year && time.month == now.month && time.day == now.day;

    if (isToday) {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    final d = time.day.toString().padLeft(2, '0');
    final mo = time.month.toString().padLeft(2, '0');
    return '$d/$mo';
  }

  bool _matchesQuery(ChatModel chat, String myUid) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (chat.isGroup) return chat.groupName.toLowerCase().contains(q);
    final name = _users[chat.otherUserId(myUid)]?.name.toLowerCase() ?? '';
    return name.contains(q);
  }

  List<ChatModel> _applyFilters(List<ChatModel> chats, String myUid) {
    return chats.where((c) {
      switch (_filter) {
        case ChatFilter.unread:
          if (c.unreadFor(myUid) == 0) return false;
          break;
        case ChatFilter.groups:
          if (!c.isGroup) return false;
          break;
        case ChatFilter.all:
          break;
      }
      return _matchesQuery(c, myUid);
    }).toList();
  }

  Widget _buildSearchBar() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: 'Search',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
          filled: true,
          fillColor: cs.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, ChatFilter value) {
    final selected = _filter == value;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: _primary.withValues(alpha: 0.18),
        backgroundColor: cs.surfaceContainerHighest,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: selected ? _primary : cs.onSurface,
        ),
      ),
    );
  }

  Widget _buildFilters(int unreadCount) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip('All', ChatFilter.all),
          _chip(
            unreadCount > 0 ? 'Unread ($unreadCount)' : 'Unread',
            ChatFilter.unread,
          ),
          _chip('Groups', ChatFilter.groups),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool noChatsAtAll) {
    String title;
    String subtitle;

    if (noChatsAtAll) {
      title = 'No conversations yet';
      subtitle = 'Tap the button below to find people and start chatting.';
    } else if (_query.trim().isNotEmpty) {
      title = 'No results';
      subtitle = 'Nothing matches "${_query.trim()}".';
    } else if (_filter == ChatFilter.unread) {
      title = 'All caught up';
      subtitle = 'You have no unread chats.';
    } else {
      title = 'No groups yet';
      subtitle = 'Create one from the Menu tab.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 56,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _authService.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Chat App',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const SearchScreen()));
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
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }

          final blockedIds = BlockList.instance.ids.value;
          final all = snapshot.data!
              .where(
                (c) => c.isGroup || !blockedIds.contains(c.otherUserId(myUid)),
              )
              .toList();
          _loadNames(all, myUid);

          final unreadCount = all.where((c) => c.unreadFor(myUid) > 0).length;
          final filtered = _applyFilters(all, myUid);
          final chats = [
            ...filtered.where((c) => c.isPinnedFor(myUid)),
            ...filtered.where((c) => !c.isPinnedFor(myUid)),
          ];

          return Column(
            children: [
              _buildSearchBar(),
              if (_query.trim().isEmpty)
                ActiveNowStrip(
                  myUid: myUid,
                  partnerUids: all
                      .where((c) => !c.isGroup)
                      .map((c) => c.otherUserId(myUid))
                      .toList(),
                ),
              _buildFilters(unreadCount),
              const SizedBox(height: 4),
              Expanded(
                child: chats.isEmpty
                    ? _buildEmpty(all.isEmpty)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                        itemCount: chats.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 2),
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          final time = _formatTime(chat.lastMessageTime);

                          if (chat.isGroup) {
                            return GroupTile(
                              chat: chat,
                              myUid: myUid,
                              timeText: time,
                              firestoreService: _firestoreService,
                            );
                          }
                          return _ChatTile(
                            chat: chat,
                            myUid: myUid,
                            timeText: time,
                            firestoreService: _firestoreService,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One 1-to-1 row. Loads the other person live (name, photo, online dot).
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
    final cs = Theme.of(context).colorScheme;
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
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onLongPress: () =>
                showChatOptions(context, chat, myUid, firestoreService),
            onTap: other == null
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(otherUser: other),
                      ),
                    );
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  Stack(
                    children: [
                      UserAvatar(
                        name: name,
                        photoBase64: other?.photoBase64 ?? '',
                        size: 52,
                      ),
                      if (isOnline)
                        Positioned(
                          right: 1,
                          bottom: 1,
                          child: Container(
                            height: 14,
                            width: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E),
                              shape: BoxShape.circle,
                              border: Border.all(color: cs.surface, width: 2),
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
                                : const Color(0xFF6B7280),
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
                              ? const Color(0xFF0F8A5D)
                              : const Color(0xFF6B7280),
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
                            color: const Color(0xFF0F8A5D),
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
