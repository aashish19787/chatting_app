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

  /// Save a user profile. The document ID is the user's uid.
  Future<void> saveUser(UserModel user) async {
    await _users.doc(user.uid).set(user.toMap());
  }

  /// Read one user's profile once (null if it doesn't exist).
  Future<UserModel?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!);
  }

  /// Change only the name.
  Future<void> updateUserName(String uid, String name) async {
    await _users.doc(uid).update({
      'name': name,
      'nameLower': name.toLowerCase(),
    });
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

  /// Make sure a profile exists for this logged-in user.
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

  /// Live updates of one user's profile.
  Stream<UserModel?> userStream(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.data()!);
    });
  }

  // ---------------------------------------------------------------
  // CHATS
  // ---------------------------------------------------------------

  /// The same two users always get the same chat ID,
  /// no matter who starts the conversation.
  String getChatId(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return ids.join('_');
  }

  /// Send a message. Creates the chat on the first message.
  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    final chatId = getChatId(senderId, receiverId);
    final chatRef = _chats.doc(chatId);

    // Sorted, so the list is identical no matter who sends first.
    final participants = [senderId, receiverId]..sort();

    // 1. Create or update the chat summary (used by the chat list).
    await chatRef.set({
      'participants': participants,
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': senderId,
    }, SetOptions(merge: true));

    // 2. Add the message itself. Our rules check the chat exists first,
    //    which is why step 1 happens before step 2.
    final message = MessageModel(
      id: '',
      senderId: senderId,
      text: text,
      createdAt: DateTime.now(),
    );
    await chatRef.collection('messages').add(message.toMap());
  }

  /// Live list of messages in one chat, newest first.
  Stream<List<MessageModel>> messagesStream(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
        .toList());
  }

  /// Live list of all chats you are part of, newest first.
  Stream<List<ChatModel>> chatsStream(String uid) {
    return _chats
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      final chats = snapshot.docs
          .map((doc) => ChatModel.fromMap(doc.id, doc.data()))
          .toList();

      // Sorted here instead of in the query, so we don't need to
      // create a Firestore index.
      chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return chats;
    });
  }
}