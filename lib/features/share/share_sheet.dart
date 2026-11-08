import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../common/widgets/group_avatar.dart';
import '../../common/widgets/user_avatar.dart';
import '../../models/chat_model.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../services/block_list.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firestore_service.dart';

/// Share a post: pick a chat to send it to, or use the phone's share menu.
Future<void> sharePost(BuildContext context, PostModel post) async {
  final author = await FirestoreService().getUser(post.authorId);
  final name = author?.name ?? 'Someone';
  final caption = post.caption.isEmpty ? '' : '\n${post.caption}';
  if (!context.mounted) return;

  showShareSheet(
    context,
    chatText: '📌 Post by $name$caption',
    imageUrl: post.imageUrl,
    externalText: 'Post by $name$caption\n${post.imageUrl}',
  );
}

/// Share a profile.
Future<void> shareProfile(BuildContext context, String uid) async {
  final user = await FirestoreService().getUser(uid);
  if (user == null || !context.mounted) return;

  final bio = user.bio.isEmpty ? '' : '\n${user.bio}';
  showShareSheet(
    context,
    chatText: '👤 ${user.name}$bio',
    externalText: 'Check out ${user.name} on Chat App$bio',
  );
}

void showShareSheet(
  BuildContext context, {
  required String chatText,
  String imageUrl = '',
  required String externalText,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ShareSheet(
      chatText: chatText,
      imageUrl: imageUrl,
      externalText: externalText,
    ),
  );
}

class _ShareSheet extends StatefulWidget {
  final String chatText;
  final String imageUrl;
  final String externalText;

  const _ShareSheet({
    required this.chatText,
    required this.imageUrl,
    required this.externalText,
  });

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _service = FirestoreService();
  final _auth = FirebaseAuthService();

  late final String _myUid;
  final Set<String> _sent = {};
  final Set<String> _sending = {};

  @override
  void initState() {
    super.initState();
    _myUid = _auth.currentUser!.uid;
  }

  Future<void> _send(ChatModel chat) async {
    if (_sending.contains(chat.id) || _sent.contains(chat.id)) return;
    setState(() => _sending.add(chat.id));

    try {
      if (chat.isGroup) {
        await _service.sendGroupMessage(
          chatId: chat.id,
          senderId: _myUid,
          participants: chat.participants,
          text: widget.chatText,
          imageUrl: widget.imageUrl,
        );
      } else {
        await _service.sendMessage(
          senderId: _myUid,
          receiverId: chat.otherUserId(_myUid),
          text: widget.chatText,
          imageUrl: widget.imageUrl,
        );
      }
      if (mounted) setState(() => _sent.add(chat.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is BlockedException
                ? "You can't message this person."
                : 'Could not send. Please try again.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending.remove(chat.id));
    }
  }

  Widget _trailing(ChatModel chat) {
    if (_sent.contains(chat.id)) {
      return const Text(
        'Sent',
        style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
      );
    }
    if (_sending.contains(chat.id)) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return ElevatedButton(
      onPressed: () => _send(chat),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text('Send'),
    );
  }

  Widget _tile(ChatModel chat) {
    if (chat.isGroup) {
      return ListTile(
        leading: GroupAvatar(photoBase64: chat.groupPhoto, size: 46),
        title: Text(
          chat.groupName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${chat.participants.length} members'),
        trailing: _trailing(chat),
      );
    }

    return StreamBuilder<UserModel?>(
      stream: _service.userStream(chat.otherUserId(_myUid)),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name = user?.name ?? 'Loading...';
        return ListTile(
          leading: UserAvatar(
            name: name,
            photoBase64: user?.photoBase64 ?? '',
            size: 46,
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          trailing: _trailing(chat),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.7;

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Send to',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF6366F1),
                child: Icon(Icons.ios_share_rounded, color: Colors.white),
              ),
              title: const Text('Share outside the app'),
              onTap: () => Share.share(widget.externalText),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<ChatModel>>(
                stream: _service.chatsStream(_myUid),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final blocked = BlockList.instance.ids.value;
                  final chats = snapshot.data!
                      .where(
                        (c) =>
                            c.isGroup ||
                            !blocked.contains(c.otherUserId(_myUid)),
                      )
                      .toList();

                  if (chats.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No chats yet. Start a chat first, or use "Share outside the app".',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: chats.length,
                    itemBuilder: (context, i) => _tile(chats[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
