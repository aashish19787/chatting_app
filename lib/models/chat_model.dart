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

  /// When each user last pressed a key in this chat.
  final Map<String, DateTime> typingAt;

  /// Group chat info.
  final bool isGroup;
  final String groupName;
  final String createdBy;

  ChatModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastSenderId,
    this.unreadCount = const {},
    this.lastRead = const {},
    this.typingAt = const {},
    this.isGroup = false,
    this.groupName = '',
    this.createdBy = '',
  });

  static Map<String, DateTime> _readTimes(dynamic raw) {
    final result = <String, DateTime>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is Timestamp) result[key.toString()] = value.toDate();
      });
    }
    return result;
  }

  factory ChatModel.fromMap(String id, Map<String, dynamic> map) {
    final unread = <String, int>{};
    final rawUnread = map['unreadCount'];
    if (rawUnread is Map) {
      rawUnread.forEach((key, value) {
        if (value is num) unread[key.toString()] = value.toInt();
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
      lastRead: _readTimes(map['lastRead']),
      typingAt: _readTimes(map['typingAt']),
      isGroup: map['isGroup'] ?? false,
      groupName: map['groupName'] ?? '',
      createdBy: map['createdBy'] ?? '',
    );
  }

  String otherUserId(String myUid) {
    return participants.firstWhere((id) => id != myUid, orElse: () => '');
  }

  int unreadFor(String uid) => unreadCount[uid] ?? 0;

  /// True if this user typed something in the last 6 seconds.
  bool isTyping(String uid) {
    final time = typingAt[uid];
    if (time == null) return false;
    return DateTime.now().difference(time) < const Duration(seconds: 6);
  }
}
