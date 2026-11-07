import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String type; // 'follow' or 'like'
  final String fromId;
  final String postId;
  final String postImageUrl;
  final DateTime createdAt;
  final bool read;

  NotificationModel({
    required this.id,
    required this.type,
    required this.fromId,
    required this.createdAt,
    this.postId = '',
    this.postImageUrl = '',
    this.read = false,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return NotificationModel(
      id: id,
      type: map['type'] ?? '',
      fromId: map['fromId'] ?? '',
      postId: map['postId'] ?? '',
      postImageUrl: map['postImageUrl'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: map['read'] ?? false,
    );
  }
}
