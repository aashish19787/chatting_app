import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final String imageUrl;
  final DateTime createdAt;
  final String replyToId;
  final String replyToText;
  final String replyToSenderId;
  final bool deleted;

  /// uid -> emoji
  final Map<String, String> reactions;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.imageUrl = '',
    this.replyToId = '',
    this.replyToText = '',
    this.replyToSenderId = '',
    this.deleted = false,
    this.reactions = const {},
  });

  bool get hasImage => imageUrl.isNotEmpty;
  bool get hasReply => replyToId.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'replyToId': replyToId,
      'replyToText': replyToText,
      'replyToSenderId': replyToSenderId,
      'deleted': deleted,
    };
  }

  factory MessageModel.fromMap(String id, Map<String, dynamic> map) {
    final raw = map['reactions'];
    return MessageModel(
      id: id,
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      replyToId: map['replyToId'] ?? '',
      replyToText: map['replyToText'] ?? '',
      replyToSenderId: map['replyToSenderId'] ?? '',
      deleted: map['deleted'] ?? false,
      reactions: raw is Map
          ? raw.map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
    );
  }
}
