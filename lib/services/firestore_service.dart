import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get _chats =>
      _db.collection('chats');

  // ---------------------------------------------------------------
  // USERS
  // ---------------------------------------------------------------

  Future<void> saveUser(UserModel user) async {
    await _users.doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!);
  }

  Future<void> updateUserName(String uid, String name) async {
    await _users.doc(uid).update({
      'name': name,
      'nameLower': name.toLowerCase(),
    });
  }

  Future<void> updatePhoto(String uid, String photoBase64) async {
    await _users.doc(uid).update({'photoBase64': photoBase64});
  }

  /// Set online/offline and refresh the "last seen" time.
  Future<void> setOnlineStatus(String uid, bool isOnline) async {
    try {
      await _users.doc(uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Not critical.
    }
  }

  /// Find users whose name STARTS WITH the search text.
  Future<List<UserModel>> searchUsers(String query, String currentUid) async {
    final text = query.trim().toLowerCase();
    if (text.isEmpty) return [];

    final snapshot = await _users
        .where('nameLower', isGreaterThanOrEqualTo: text)
        .where('nameLower', isLessThanOrEqualTo: '$text\uf8ff')
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data()))
        .where((user) => user.uid != currentUid)
        .toList();
  }

  Future<void> ensureUserExists(User authUser) async {
    final doc = await _users.doc(authUser.uid).get();
    if (doc.exists) return;

    final email = authUser.email ?? '';
    final name = email.contains('@') ? email.split('@').first : 'User';

    await saveUser(
      UserModel(
        uid: authUser.uid,
        name: name,
        email: email,
        photoUrl: '',
        createdAt: DateTime.now(),
      ),
    );
  }

  Stream<UserModel?> userStream(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.data()!);
    });
  }

  // ---------------------------------------------------------------
  // CHATS
  // ---------------------------------------------------------------

  String getChatId(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return ids.join('_');
  }

  /// Send a text or image message (optionally a reply).
  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    String text = '',
    String imageUrl = '',
    String replyToId = '',
    String replyToText = '',
    String replyToSenderId = '',
  }) async {
    final chatId = getChatId(senderId, receiverId);
    final chatRef = _chats.doc(chatId);
    final participants = [senderId, receiverId]..sort();

    await chatRef.set({
      'participants': participants,
      'lastMessage': imageUrl.isNotEmpty ? '📷 Photo' : text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': senderId,
      'unreadCount': {receiverId: FieldValue.increment(1), senderId: 0},
    }, SetOptions(merge: true));

    final message = MessageModel(
      id: '',
      senderId: senderId,
      text: text,
      imageUrl: imageUrl,
      replyToId: replyToId,
      replyToText: replyToText,
      replyToSenderId: replyToSenderId,
      createdAt: DateTime.now(),
    );
    await chatRef.collection('messages').add(message.toMap());
  }

  /// "Delete" a message: we hide its content but keep the document,
  /// so the other person sees "This message was deleted".
  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
    required bool isNewest,
  }) async {
    final chatRef = _chats.doc(chatId);

    await chatRef.collection('messages').doc(messageId).update({
      'deleted': true,
      'text': '',
      'imageUrl': '',
    });

    // If it was the newest message, fix the chat list preview too.
    if (isNewest) {
      try {
        await chatRef.update({'lastMessage': 'This message was deleted'});
      } catch (_) {}
    }
  }

  /// Tell the other person that I am typing (or that I stopped).
  Future<void> setTyping(String chatId, String uid, bool typing) async {
    try {
      await _chats.doc(chatId).update({
        'typingAt.$uid': typing
            ? FieldValue.serverTimestamp()
            : FieldValue.delete(),
      });
    } catch (_) {
      // The chat may not exist yet. Safe to ignore.
    }
  }

  Stream<List<MessageModel>> messagesStream(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<ChatModel>> chatsStream(String uid) {
    return _chats.where('participants', arrayContains: uid).snapshots().map((
      snapshot,
    ) {
      final chats = snapshot.docs
          .map((doc) => ChatModel.fromMap(doc.id, doc.data()))
          .toList();

      chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return chats;
    });
  }

  Stream<ChatModel?> chatStream(String chatId) {
    return _chats.doc(chatId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return ChatModel.fromMap(doc.id, doc.data()!);
    });
  }

  Future<void> markChatAsRead(String chatId, String myUid) async {
    try {
      await _chats.doc(chatId).update({
        'unreadCount.$myUid': 0,
        'lastRead.$myUid': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // The chat may not exist yet. Safe to ignore.
    }
  }
}
