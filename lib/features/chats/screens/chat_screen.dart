import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../common/widgets/user_avatar.dart';
import '../../../models/chat_model.dart';
import '../../../models/message_model.dart';
import '../../../models/user_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/storage_service.dart';

class ChatScreen extends StatefulWidget {
  final UserModel otherUser;

  const ChatScreen({super.key, required this.otherUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _primary = Color(0xFF6366F1);
  static const _secondary = Color(0xFF8B5CF6);

  final _messageController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _authService = FirebaseAuthService();
  final _storageService = StorageService();

  late final String _myUid;
  late final String _chatId;
  bool _isSending = false;
  bool _isUploadingImage = false;
  String? _lastMarkedMessageId;
  Timer? _statusTimer;

  // The message I am replying to (null = not replying).
  MessageModel? _replyingTo;

  // Limits how often we tell Firestore "I am typing".
  DateTime? _lastTypingWrite;

  @override
  void initState() {
    super.initState();
    _myUid = _authService.currentUser!.uid;
    _chatId = _firestoreService.getChatId(_myUid, widget.otherUser.uid);
    NotificationService.instance.activeChatId = _chatId;

    _messageController.addListener(_onTextChanged);

    // Re-draws every 3 seconds so "online" and "typing..." expire.
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _firestoreService.setTyping(_chatId, _myUid, false);
    if (NotificationService.instance.activeChatId == _chatId) {
      NotificationService.instance.activeChatId = null;
    }
    _statusTimer?.cancel();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_messageController.text.isEmpty) return;

    final now = DateTime.now();
    final last = _lastTypingWrite;
    if (last == null || now.difference(last) > const Duration(seconds: 3)) {
      _lastTypingWrite = now;
      _firestoreService.setTyping(_chatId, _myUid, true);
    }
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: Colors.redAccent),
    );
  }

  String _previewOf(MessageModel m) {
    if (m.deleted) return 'Message deleted';
    final text = m.hasImage ? '📷 Photo' : m.text;
    return text.length > 100 ? '${text.substring(0, 100)}...' : text;
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final reply = _replyingTo;

    _messageController.clear();
    _lastTypingWrite = null;
    setState(() {
      _isSending = true;
      _replyingTo = null;
    });

    try {
      await _firestoreService.sendMessage(
        senderId: _myUid,
        receiverId: widget.otherUser.uid,
        text: text,
        replyToId: reply?.id ?? '',
        replyToText: reply == null ? '' : _previewOf(reply),
        replyToSenderId: reply?.senderId ?? '',
      );
      _firestoreService.setTyping(_chatId, _myUid, false);
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
    if (_isUploadingImage) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        imageQuality: 75,
      );
      if (picked == null) return;

      setState(() => _isUploadingImage = true);

      final url = await _storageService.uploadChatImage(picked);

      await _firestoreService.sendMessage(
        senderId: _myUid,
        receiverId: widget.otherUser.uid,
        imageUrl: url,
      );
    } catch (e) {
      debugPrint('Image send failed: $e');
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
      _firestoreService.markChatAsRead(_chatId, _myUid);
    });
  }

  // ---------------------------------------------------------------
  // Long-press menu: Reply / Delete
  // ---------------------------------------------------------------

  void _showMessageMenu(MessageModel message, bool isNewest) {
    if (message.deleted) return;
    final isMe = message.senderId == _myUid;

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _replyingTo = message);
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Delete message',
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

  Future<void> _confirmDelete(MessageModel message, bool isNewest) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('It will be removed for both of you.'),
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
        chatId: _chatId,
        messageId: message.id,
        isNewest: isNewest,
      );
    } catch (_) {
      if (!mounted) return;
      _showError('Could not delete the message.');
    }
  }

  // ---------------------------------------------------------------
  // Helpers for drawing
  // ---------------------------------------------------------------

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
          color: const Color(0xFFE2E8F0),
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

  String _statusText(UserModel user) {
    if (user.isActive) return 'Online';
    final seen = user.lastSeen;
    if (seen == null) return 'Offline';

    final now = DateTime.now();
    if (_isSameDay(seen, now)) return 'Last seen today at ${_formatTime(seen)}';
    final d = seen.day.toString().padLeft(2, '0');
    final m = seen.month.toString().padLeft(2, '0');
    return 'Last seen $d/$m at ${_formatTime(seen)}';
  }

  void _openImage(String url) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => _FullScreenImage(url: url)));
  }

  /// The small quoted box shown inside a reply.
  Widget _buildReplyQuote(MessageModel m, bool isMe) {
    final name = m.replyToSenderId == _myUid ? 'You' : widget.otherUser.name;
    final textColor = isMe ? Colors.white : const Color(0xFF172554);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.18)
            : const Color(0xFFF1F5F9),
        border: Border(
          left: BorderSide(color: isMe ? Colors.white : _primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
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

  Widget _buildBubble(
    MessageModel message,
    DateTime? otherLastRead,
    bool isNewest,
  ) {
    final isMe = message.senderId == _myUid;
    final textColor = isMe ? Colors.white : const Color(0xFF172554);
    final showImage = message.hasImage && !message.deleted;

    final isSeen =
        isMe &&
        otherLastRead != null &&
        !message.createdAt.isAfter(otherLastRead);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageMenu(message, isNewest),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: showImage
              ? const EdgeInsets.all(4)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? _primary : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quoted message (if this is a reply)
              if (message.hasReply && !message.deleted)
                Padding(
                  padding: showImage
                      ? const EdgeInsets.fromLTRB(6, 6, 6, 0)
                      : EdgeInsets.zero,
                  child: _buildReplyQuote(message, isMe),
                ),

              // Deleted message
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

              // Photo
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

              // Text
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe ? Colors.white70 : const Color(0xFF94A3B8),
                      ),
                    ),
                    if (isMe && !message.deleted) ...[
                      const SizedBox(width: 4),
                      Icon(
                        isSeen ? Icons.done_all_rounded : Icons.done_rounded,
                        size: 14,
                        color: isSeen
                            ? const Color(0xFF7DD3FC)
                            : Colors.white70,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The bar above the input box while replying.
  Widget _buildReplyBar() {
    final reply = _replyingTo!;
    final name = reply.senderId == _myUid ? 'yourself' : widget.otherUser.name;

    return Container(
      color: const Color(0xFFEEF2FF),
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
                  'Replying to $name',
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

  @override
  Widget build(BuildContext context) {
    final other = widget.otherUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        titleSpacing: 0,
        title: StreamBuilder<UserModel?>(
          stream: _firestoreService.userStream(other.uid),
          builder: (context, userSnapshot) {
            final user = userSnapshot.data ?? other;

            return StreamBuilder<ChatModel?>(
              stream: _firestoreService.chatStream(_chatId),
              builder: (context, chatSnapshot) {
                final isTyping =
                    chatSnapshot.data?.isTyping(other.uid) ?? false;

                return Row(
                  children: [
                    UserAvatar(
                      name: user.name,
                      photoBase64: user.photoBase64,
                      size: 38,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            isTyping ? 'typing...' : _statusText(user),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: isTyping
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              color: isTyping
                                  ? _primary
                                  : user.isActive
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<ChatModel?>(
              stream: _firestoreService.chatStream(_chatId),
              builder: (context, chatSnapshot) {
                final otherLastRead = chatSnapshot.data?.lastRead[other.uid];

                return StreamBuilder<List<MessageModel>>(
                  stream: _firestoreService.messagesStream(_chatId),
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

                    final messages = snapshot.data!;

                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            UserAvatar(
                              name: other.name,
                              photoBase64: other.photoBase64,
                              size: 80,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              other.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'No messages yet. Say hi 👋',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 14,
                              ),
                            ),
                          ],
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
                        final bubble = _buildBubble(
                          message,
                          otherLastRead,
                          index == 0,
                        );

                        // The list is newest-first, so the next item is the
                        // OLDER message.
                        final isLast = index == messages.length - 1;
                        final showDay =
                            isLast ||
                            !_isSameDay(
                              message.createdAt,
                              messages[index + 1].createdAt,
                            );

                        if (!showDay) return bubble;

                        return Column(
                          children: [_buildDayChip(message.createdAt), bubble],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          if (_isUploadingImage)
            Container(
              width: double.infinity,
              color: const Color(0xFFEEF2FF),
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
              color: Theme.of(context).colorScheme.surface,
              child: Row(
                children: [
                  IconButton(
                    onPressed: _isUploadingImage ? null : _sendImage,
                    tooltip: 'Send a photo',
                    icon: const Icon(Icons.image_outlined, color: _primary),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: _primary,
                            width: 1.5,
                          ),
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
  }
}

/// Full-screen photo viewer. Pinch to zoom.
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
