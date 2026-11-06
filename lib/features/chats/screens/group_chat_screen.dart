import 'group_info_screen.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/chat_model.dart';
import '../../../models/message_model.dart';
import '../../../models/user_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/storage_service.dart';

class GroupChatScreen extends StatefulWidget {
  final String chatId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.chatId,
    required this.groupName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  static const _primary = Color(0xFF6366F1);
  static const _secondary = Color(0xFF8B5CF6);

  final _messageController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _authService = FirebaseAuthService();
  final _storageService = StorageService();

  late final String _myUid;
  bool _isSending = false;
  bool _isUploadingImage = false;
  String? _lastMarkedMessageId;
  MessageModel? _replyingTo;

  // Latest member list (from the chat document)
  List<String> _participants = [];

  // Member profiles, loaded as needed
  final Map<String, UserModel> _users = {};
  final Set<String> _requested = {};

  @override
  void initState() {
    super.initState();
    _myUid = _authService.currentUser!.uid;
    NotificationService.instance.activeChatId = widget.chatId;
  }

  @override
  void dispose() {
    if (NotificationService.instance.activeChatId == widget.chatId) {
      NotificationService.instance.activeChatId = null;
    }
    _messageController.dispose();
    super.dispose();
  }

  void _ensureUsers(List<String> uids) {
    final missing = uids
        .where((u) => !_users.containsKey(u) && !_requested.contains(u))
        .toList();
    if (missing.isEmpty) return;
    _requested.addAll(missing);
    _firestoreService.getUsers(missing).then((found) {
      if (!mounted) return;
      setState(() => _users.addAll(found));
    });
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: Colors.redAccent),
    );
  }

  String _nameOf(String uid) =>
      uid == _myUid ? 'You' : (_users[uid]?.name ?? 'Someone');

  String _previewOf(MessageModel m) {
    if (m.deleted) return 'Message deleted';
    final text = m.hasImage ? '📷 Photo' : m.text;
    return text.length > 100 ? '${text.substring(0, 100)}...' : text;
  }

  Color _nameColor(String uid) {
    const colors = [
      Color(0xFF6366F1),
      Color(0xFFDB2777),
      Color(0xFF059669),
      Color(0xFFD97706),
      Color(0xFF0891B2),
      Color(0xFF9333EA),
    ];
    return colors[uid.hashCode.abs() % colors.length];
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending || _participants.isEmpty) return;

    final reply = _replyingTo;
    _messageController.clear();
    setState(() {
      _isSending = true;
      _replyingTo = null;
    });

    try {
      await _firestoreService.sendGroupMessage(
        chatId: widget.chatId,
        senderId: _myUid,
        participants: _participants,
        text: text,
        replyToId: reply?.id ?? '',
        replyToText: reply == null ? '' : _previewOf(reply),
        replyToSenderId: reply?.senderId ?? '',
      );
    } catch (_) {
      if (!mounted) return;
      _messageController.text = text;
      setState(() => _replyingTo = reply);
      _showError('Message not sent. Please try again.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendImage() async {
    if (_isUploadingImage || _participants.isEmpty) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        imageQuality: 75,
      );
      if (picked == null) return;

      setState(() => _isUploadingImage = true);
      final url = await _storageService.uploadChatImage(picked);

      await _firestoreService.sendGroupMessage(
        chatId: widget.chatId,
        senderId: _myUid,
        participants: _participants,
        imageUrl: url,
      );
    } catch (e) {
      debugPrint('Group image send failed: $e');
      if (!mounted) return;
      _showError('Could not send the photo. Please try again.');
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _markReadIfNeeded(List<MessageModel> messages) {
    if (messages.isEmpty) return;
    final newest = messages.first;
    if (newest.senderId == _myUid) return;
    if (newest.id == _lastMarkedMessageId) return;
    _lastMarkedMessageId = newest.id;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _firestoreService.markChatAsRead(widget.chatId, _myUid);
    });
  }

  void _showMessageMenu(MessageModel message, bool isNewest) {
    final isMe = message.senderId == _myUid;

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Delete for me'),
              onTap: () {
                Navigator.pop(sheetContext);
                _hideForMe(message);
              },
            ),
            if (!message.deleted)
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _replyingTo = message);
                },
              ),
            if (isMe && !message.deleted)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Delete for everyone',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(message, isNewest);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _hideForMe(MessageModel message) async {
    try {
      await _firestoreService.hideMessage(widget.chatId, _myUid, message.id);
    } catch (_) {
      if (!mounted) return;
      _showError('Could not delete the message.');
    }
  }

  Future<void> _confirmDelete(MessageModel message, bool isNewest) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('It will be removed for everyone in the group.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _firestoreService.deleteMessage(
        chatId: widget.chatId,
        messageId: message.id,
        isNewest: isNewest,
      );
    } catch (_) {
      if (!mounted) return;
      _showError('Could not delete the message.');
    }
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Today';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildDayChip(DateTime date) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _dayLabel(date),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  void _openImage(String url) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => _FullScreenImage(url: url)));
  }

  Widget _buildReplyQuote(MessageModel m, bool isMe, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.18)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          left: BorderSide(color: isMe ? Colors.white : _primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _nameOf(m.replyToSenderId),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Text(
            m.replyToText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(MessageModel message, bool isNewest) {
    final cs = Theme.of(context).colorScheme;
    final isMe = message.senderId == _myUid;
    final textColor = isMe ? Colors.white : cs.onSurface;
    final showImage = message.hasImage && !message.deleted;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageMenu(message, isNewest),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: showImage
              ? const EdgeInsets.all(4)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe
                ? null
                : Theme.of(context).colorScheme.surfaceContainerHigh,
            gradient: isMe
                ? const LinearGradient(
                    colors: [_primary, _secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            border: isMe
                ? null
                : Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
          ),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sender name (only for other people)
              if (!isMe)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: 3,
                    left: showImage ? 8 : 0,
                    top: showImage ? 4 : 0,
                  ),
                  child: Text(
                    _nameOf(message.senderId),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _nameColor(message.senderId),
                    ),
                  ),
                ),

              if (message.hasReply && !message.deleted)
                Padding(
                  padding: showImage
                      ? const EdgeInsets.fromLTRB(6, 6, 6, 0)
                      : EdgeInsets.zero,
                  child: _buildReplyQuote(message, isMe, textColor),
                ),

              if (message.deleted)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.block_rounded,
                      size: 14,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'This message was deleted',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),

              if (showImage)
                GestureDetector(
                  onTap: () => _openImage(message.imageUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      message.imageUrl,
                      width: 240,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          width: 240,
                          height: 180,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (_, _, _) => const SizedBox(
                        width: 240,
                        height: 120,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              if (!message.deleted && message.text.isNotEmpty)
                Text(
                  message.text,
                  style: TextStyle(fontSize: 15, color: textColor),
                ),

              Padding(
                padding: EdgeInsets.only(
                  top: 3,
                  right: showImage ? 8 : 0,
                  bottom: showImage ? 4 : 0,
                ),
                child: Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyBar() {
    final reply = _replyingTo!;
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      child: Row(
        children: [
          Container(width: 3, height: 36, color: _primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_nameOf(reply.senderId)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _primary,
                  ),
                ),
                Text(
                  _previewOf(reply),
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
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupAvatar() {
    return Container(
      height: 38,
      width: 38,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_primary, _secondary]),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Icon(Icons.groups_rounded, color: Colors.white, size: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<ChatModel?>(
      stream: _firestoreService.chatStream(widget.chatId),
      builder: (context, chatSnapshot) {
        final chat = chatSnapshot.data;

        if (chat != null) {
          _participants = chat.participants;
          _ensureUsers(chat.participants);
        }

        final title = (chat?.groupName.isNotEmpty ?? false)
            ? chat!.groupName
            : widget.groupName;
        final count = chat?.participants.length;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: cs.surface,
            elevation: 0,
            titleSpacing: 0,
            title: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GroupInfoScreen(chatId: widget.chatId),
                ),
              ),
              child: Row(
                children: [
                  _buildGroupAvatar(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (count != null)
                          Text(
                            '$count members',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: chatSnapshot.hasError
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: Text(
                      'You can no longer open this group.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: StreamBuilder<List<MessageModel>>(
                        stream: _firestoreService.messagesStream(widget.chatId),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Center(
                              child: Text(
                                'Could not load messages.',
                                style: TextStyle(color: Color(0xFF64748B)),
                              ),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(color: _primary),
                            );
                          }

                          final hidden =
                              chat?.hiddenFor(_myUid) ?? const <String>[];
                          final messages = snapshot.data!
                              .where((m) => !hidden.contains(m.id))
                              .toList();
                          if (messages.isEmpty) {
                            return const Center(
                              child: Text(
                                'No messages yet. Say hi 👋',
                                style: TextStyle(color: Color(0xFF64748B)),
                              ),
                            );
                          }

                          _markReadIfNeeded(messages);

                          return ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final bubble = _buildBubble(message, index == 0);

                              final isLast = index == messages.length - 1;
                              final showDay =
                                  isLast ||
                                  !_isSameDay(
                                    message.createdAt,
                                    messages[index + 1].createdAt,
                                  );

                              if (!showDay) return bubble;
                              return Column(
                                children: [
                                  _buildDayChip(message.createdAt),
                                  bubble,
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),

                    if (_isUploadingImage)
                      Container(
                        width: double.infinity,
                        color: cs.surfaceContainerHighest,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _primary,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Sending photo...',
                              style: TextStyle(color: _primary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),

                    if (_replyingTo != null) _buildReplyBar(),

                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(6, 8, 14, 10),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          border: Border(
                            top: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _isUploadingImage ? null : _sendImage,
                              tooltip: 'Send a photo',
                              icon: const Icon(
                                Icons.image_outlined,
                                color: _primary,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                minLines: 1,
                                maxLines: 4,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: InputDecoration(
                                  hintText: 'Type a message',
                                  filled: true,
                                  fillColor: cs.surfaceContainerHighest,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _send,
                              child: Container(
                                height: 48,
                                width: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [_primary, _secondary],
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 22,
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
      },
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  final String url;

  const _FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const CircularProgressIndicator(color: Colors.white);
            },
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}
