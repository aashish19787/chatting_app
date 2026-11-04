import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastSenderId;

  /// How many unread messages each user has, e.g. {uidA: 0, uidB: 3}
  final Map<String, int> unreadCount;

  /// When each user last opened this chat.
  final Map<String, DateTime> lastRead;

  ChatModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastSenderId,
    this.unreadCount = const {},
    this.lastRead = const {},
  });

  factory ChatModel.fromMap(String id, Map<String, dynamic> map) {
    final unread = <String, int>{};
    final rawUnread = map['unreadCount'];
    if (rawUnread is Map) {
      rawUnread.forEach((key, value) {
        if (value is num) unread[key.toString()] = value.toInt();
      });
    }

    final reads = <String, DateTime>{};
    final rawReads = map['lastRead'];
    if (rawReads is Map) {
      rawReads.forEach((key, value) {
        if (value is Timestamp) reads[key.toString()] = value.toDate();
      });
    }

    return ChatModel(
      id: id,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime:
      (map['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSenderId: map['lastSenderId'] ?? '',
      unreadCount: unread,
      lastRead: reads,
    );
  }

  String otherUserId(String myUid) {
    return participants.firstWhere((id) => id != myUid, orElse: () => '');
  }

  /// Unread messages for this user (0 if none).
  int unreadFor(String uid) => unreadCount[uid] ?? 0;
}