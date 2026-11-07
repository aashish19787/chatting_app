import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String authorId;
  final String imageUrl;
  final String caption;
  final DateTime createdAt;
  final List<String> likedBy;

  PostModel({
    required this.id,
    required this.authorId,
    required this.imageUrl,
    required this.caption,
    required this.createdAt,
    this.likedBy = const [],
  });

  int get likeCount => likedBy.length;
  bool isLikedBy(String uid) => likedBy.contains(uid);

  factory PostModel.fromMap(String id, Map<String, dynamic> map) {
    return PostModel(
      id: id,
      authorId: map['authorId'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      caption: map['caption'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likedBy: List<String>.from(map['likedBy'] ?? const []),
    );
  }
}
