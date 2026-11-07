import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastSenderId;
  final Map<String, int> unreadCount;
  final Map<String, DateTime> lastRead;
  final Map<String, DateTime> typingAt;
  final bool isGroup;
  final String groupName;
  final String createdBy;
  final String groupPhoto;

  /// Message IDs each user hid with "Delete for me".
  final Map<String, List<String>> hidden;

  /// uid -> true, for people who pinned / muted this chat.
  final Map<String, bool> pinned;
  final Map<String, bool> muted;

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
    this.groupPhoto = '',
    this.hidden = const {},
    this.pinned = const {},
    this.muted = const {},
  });

  static Map<String, DateTime> _times(dynamic raw) {
    final result = <String, DateTime>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is Timestamp) result[key.toString()] = value.toDate();
      });
    }
    return result;
  }

  static Map<String, bool> _flags(dynamic raw) {
    final result = <String, bool>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value == true) result[key.toString()] = true;
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

    final rawHidden = map['hidden'];

    return ChatModel(
      id: id,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime:
          (map['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSenderId: map['lastSenderId'] ?? '',
      unreadCount: unread,
      lastRead: _times(map['lastRead']),
      typingAt: _times(map['typingAt']),
      isGroup: map['isGroup'] ?? false,
      groupName: map['groupName'] ?? '',
      createdBy: map['createdBy'] ?? '',
      groupPhoto: map['groupPhoto'] ?? '',
      hidden: rawHidden is Map
          ? rawHidden.map(
              (k, v) => MapEntry(k.toString(), List<String>.from(v as List)),
            )
          : const {},
      pinned: _flags(map['pinned']),
      muted: _flags(map['muted']),
    );
  }

  String otherUserId(String myUid) {
    return participants.firstWhere((id) => id != myUid, orElse: () => '');
  }

  int unreadFor(String uid) => unreadCount[uid] ?? 0;

  bool isTyping(String uid) {
    final time = typingAt[uid];
    if (time == null) return false;
    return DateTime.now().difference(time) < const Duration(seconds: 6);
  }

  List<String> hiddenFor(String uid) => hidden[uid] ?? const [];
  bool isPinnedFor(String uid) => pinned[uid] ?? false;
  bool isMutedFor(String uid) => muted[uid] ?? false;
}
