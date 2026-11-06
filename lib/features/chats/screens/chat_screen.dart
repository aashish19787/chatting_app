import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../common/widgets/user_avatar.dart';
import '../../../models/chat_model.dart';
import '../../../models/message_model.dart';
import '../../../models/user_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/notification_service.dart';

class ChatScreen extends StatefulWidget {
  final UserModel otherUser;

  const ChatScreen({super.key, required this.otherUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
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

  @override
  void initState() {
    super.initState();
    _myUid = _authService.currentUser!.uid;
    _chatId = _firestoreService.getChatId(_myUid, widget.otherUser.uid);
    NotificationService.instance.activeChatId = _chatId;

    _statusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _messageController.dispose();
    if (NotificationService.instance.activeChatId == _chatId) {
      NotificationService.instance.activeChatId = null;
    }
    super.dispose();
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      await _firestoreService.sendMessage(
        senderId: _myUid,
        receiverId: widget.otherUser.uid,
        text: text,
      );
    } catch (_) {
      if (!mounted) return;
      _messageController.text = text;
      _showError('Message not sent. Please try again.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Pick a photo, upload it to Cloudinary, then send its link.
  Future<void> _sendImage() async {
    if (_isUploadingImage) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280, // shrink big photos before uploading
        imageQuality: 75,
      );
      if (picked == null) return; // cancelled

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

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _statusText(UserModel user) {
    if (user.isActive) return 'Online';
    final seen = user.lastSeen;
    if (seen == null) return 'Offline';

    final now = DateTime.now();
    final isToday = seen.year == now.year &&
        seen.month == now.month &&
        seen.day == now.day;

    if (isToday) return 'Last seen today at ${_formatTime(seen)}';
    final d = seen.day.toString().padLeft(2, '0');
    final m = seen.month.toString().padLeft(2, '0');
    return 'Last seen $d/$m at ${_formatTime(seen)}';
  }

  void _openImage(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _FullScreenImage(url: url)),
    );
  }

  Widget _buildBubble(MessageModel message, DateTime? otherLastRead) {
    const primaryColor = Color(0xFF6366F1);
    final isMe = message.senderId == _myUid;

    final isSeen = isMe &&
        otherLastRead != null &&
        !message.createdAt.isAfter(otherLastRead);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: message.hasImage
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? primaryColor : Colors.white,
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
            // The photo (tap to open full screen)
            if (message.hasImage)
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
                        child: Icon(Icons.broken_image_outlined,
                            color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                ),
              ),

            // The text (only if there is some)
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: TextStyle(
                  fontSize: 15,
                  color: isMe ? Colors.white : const Color(0xFF172554),
                ),
              ),

            Padding(
              padding: EdgeInsets.only(
                top: 3,
                right: message.hasImage ? 8 : 0,
                bottom: message.hasImage ? 4 : 0,
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
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isSeen ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 14,
                      color:
                      isSeen ? const Color(0xFF7DD3FC) : Colors.white70,
                    ),
                  ],
                ],
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
    const secondaryColor = Color(0xFF8B5CF6);
    final other = widget.otherUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF172554)),
        titleSpacing: 0,
        title: StreamBuilder<UserModel?>(
          stream: _firestoreService.userStream(other.uid),
          builder: (context, snapshot) {
            final user = snapshot.data ?? other;

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
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF172554),
                        ),
                      ),
                      Text(
                        _statusText(user),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: user.isActive
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
                        child: CircularProgressIndicator(color: primaryColor),
                      );
                    }

                    final messages = snapshot.data!;

                    if (messages.isEmpty) {
                      return Center(
                        child: Text(
                          'Say hi to ${other.name} 👋',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 15,
                          ),
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
                      itemBuilder: (context, index) =>
                          _buildBubble(messages[index], otherLastRead),
                    );
                  },
                );
              },
            ),
          ),

          // "Sending photo..." bar
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
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Sending photo...',
                    style: TextStyle(color: primaryColor, fontSize: 13),
                  ),
                ],
              ),
            ),

          // Input bar
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 8, 14, 10),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(
                    onPressed: _isUploadingImage ? null : _sendImage,
                    tooltip: 'Send a photo',
                    icon: const Icon(
                      Icons.image_outlined,
                      color: primaryColor,
                    ),
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
                        fillColor: const Color(0xFFF8FAFC),
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
                          borderSide:
                          const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: primaryColor,
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
                          colors: [primaryColor, secondaryColor],
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