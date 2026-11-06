import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final String imageUrl; // empty = text-only message
  final DateTime createdAt;

  // Reply info (empty = not a reply)
  final String replyToId;
  final String replyToText;
  final String replyToSenderId;

  // true = the sender deleted this message
  final bool deleted;

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
    );
  }
}
