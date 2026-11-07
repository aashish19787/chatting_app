import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/notification_model.dart';
import '../models/post_model.dart';
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

  // ---------------------------------------------------------------
  // GROUPS
  // ---------------------------------------------------------------

  /// Create a group. Returns the new chat ID.
  Future<String> createGroup({
    required String creatorId,
    required String name,
    required List<String> memberIds,
  }) async {
    final participants = {creatorId, ...memberIds}.toList()..sort();
    final ref = _chats.doc();

    await ref.set({
      'participants': participants,
      'isGroup': true,
      'groupName': name.trim(),
      'createdBy': creatorId,
      'lastMessage': 'Group created',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': creatorId,
      'unreadCount': {for (final id in participants) id: 0},
    });
    return ref.id;
  }

  /// Send a message into a group (chat ID already known).
  Future<void> sendGroupMessage({
    required String chatId,
    required String senderId,
    required List<String> participants,
    String text = '',
    String imageUrl = '',
    String replyToId = '',
    String replyToText = '',
    String replyToSenderId = '',
  }) async {
    final chatRef = _chats.doc(chatId);

    await chatRef.update({
      'lastMessage': imageUrl.isNotEmpty ? '📷 Photo' : text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': senderId,
      for (final id in participants)
        'unreadCount.$id': id == senderId ? 0 : FieldValue.increment(1),
    });

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

  /// Remove myself from a group.
  Future<void> leaveGroup(String chatId, String myUid) async {
    await _chats.doc(chatId).update({
      'participants': FieldValue.arrayRemove([myUid]),
    });
  }

  /// Load several users at once (for member lists and sender names).
  Future<Map<String, UserModel>> getUsers(List<String> uids) async {
    final result = <String, UserModel>{};
    for (final uid in uids) {
      final user = await getUser(uid);
      if (user != null) result[uid] = user;
    }
    return result;
  }

  /// Add people to an existing group.
  Future<void> addGroupMembers(String chatId, List<String> newUids) async {
    await _chats.doc(chatId).update({
      'participants': FieldValue.arrayUnion(newUids),
      for (final id in newUids) 'unreadCount.$id': 0,
    });
  }

  /// "Delete for me": hide a message only on my side.
  Future<void> hideMessage(
    String chatId,
    String myUid,
    String messageId,
  ) async {
    await _chats.doc(chatId).update({
      'hidden.$myUid': FieldValue.arrayUnion([messageId]),
    });
  }

  // ---------------------------------------------------------------
  // PROFILE + FOLLOW
  // ---------------------------------------------------------------

  Future<void> updateBio(String uid, String bio) async {
    await _users.doc(uid).update({'bio': bio});
  }

  /// UIDs of people who follow [uid].
  Stream<List<String>> followersStream(String uid) {
    return _users
        .doc(uid)
        .collection('followers')
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toList());
  }

  /// UIDs of people that [uid] follows.
  Stream<List<String>> followingStream(String uid) {
    return _users
        .doc(uid)
        .collection('following')
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toList());
  }

  Future<void> follow(String myUid, String targetUid) async {
    final batch = _db.batch();
    final data = {'createdAt': FieldValue.serverTimestamp()};
    batch.set(_users.doc(targetUid).collection('followers').doc(myUid), data);
    batch.set(_users.doc(myUid).collection('following').doc(targetUid), data);
    await batch.commit();
    await _notify(targetUid, 'follow_$myUid', {
      'type': 'follow',
      'fromId': myUid,
      'postId': '',
      'postImageUrl': '',
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  Future<void> unfollow(String myUid, String targetUid) async {
    final batch = _db.batch();
    batch.delete(_users.doc(targetUid).collection('followers').doc(myUid));
    batch.delete(_users.doc(myUid).collection('following').doc(targetUid));
    await batch.commit();
    await _removeNotification(targetUid, 'follow_$myUid');
  }

  // ---------------------------------------------------------------
  // POSTS
  // ---------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');

  Future<void> createPost({
    required String authorId,
    required String imageUrl,
    required String caption,
  }) async {
    await _posts.add({
      'authorId': authorId,
      'imageUrl': imageUrl,
      'caption': caption.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'likedBy': <String>[],
    });
  }

  /// A user's posts, newest first (sorted here so no index is needed).
  Stream<List<PostModel>> userPostsStream(String uid) {
    return _posts.where('authorId', isEqualTo: uid).snapshots().map((s) {
      final posts = s.docs
          .map((d) => PostModel.fromMap(d.id, d.data()))
          .toList();
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    });
  }

  Stream<PostModel?> postStream(String postId) {
    return _posts.doc(postId).snapshots().map((d) {
      if (!d.exists || d.data() == null) return null;
      return PostModel.fromMap(d.id, d.data()!);
    });
  }

  Future<void> setLike(String postId, String myUid, bool like) async {
    await _posts.doc(postId).update({
      'likedBy': like
          ? FieldValue.arrayUnion([myUid])
          : FieldValue.arrayRemove([myUid]),
    });
  }

  Future<void> deletePost(String postId) async {
    await _posts.doc(postId).delete();
  }

  // ---------------------------------------------------------------
  // NOTIFICATIONS
  // ---------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _notifications(String uid) =>
      _users.doc(uid).collection('notifications');

  Future<void> _notify(
    String toUid,
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      await _notifications(toUid).doc(id).set(data);
    } catch (_) {
      // Not critical (for example, it already exists).
    }
  }

  Future<void> _removeNotification(String toUid, String id) async {
    try {
      await _notifications(toUid).doc(id).delete();
    } catch (_) {
      // Not critical.
    }
  }

  /// Like or unlike a post, and notify the author.
  Future<void> setPostLike(PostModel post, String myUid, bool like) async {
    await setLike(post.id, myUid, like);
    if (post.authorId == myUid) return;

    final id = 'like_${post.id}_$myUid';
    if (like) {
      await _notify(post.authorId, id, {
        'type': 'like',
        'fromId': myUid,
        'postId': post.id,
        'postImageUrl': post.imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } else {
      await _removeNotification(post.authorId, id);
    }
  }

  Stream<List<NotificationModel>> notificationsStream(String uid) {
    return _notifications(uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => NotificationModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Stream<int> unreadNotificationsCount(String uid) {
    return _notifications(uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Future<void> markAllNotificationsRead(String uid) async {
    try {
      final unread = await _notifications(uid)
          .where('read', isEqualTo: false)
          .get();
      if (unread.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (_) {
      // Not critical.
    }
  }

  // ---------------------------------------------------------------
  // NOTES
  // ---------------------------------------------------------------

  Future<void> setNote(String uid, String text) async {
    await _users.doc(uid).update({
      'note': text.trim(),
      'noteAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteNote(String uid) async {
    await _users.doc(uid).update({'note': '', 'noteAt': FieldValue.delete()});
  }
}
