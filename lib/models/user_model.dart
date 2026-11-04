import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;

  /// Profile picture, stored as base64 text (empty = no picture).
  final String photoBase64;

  final DateTime createdAt;
  final bool isOnline;
  final DateTime? lastSeen;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.createdAt,
    this.photoBase64 = '',
    this.isOnline = false,
    this.lastSeen,
  });

  /// Returns a copy of this user with only the given fields changed.
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoUrl,
    String? photoBase64,
    DateTime? createdAt,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      photoBase64: photoBase64 ?? this.photoBase64,
      createdAt: createdAt ?? this.createdAt,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  bool get isActive {
    if (!isOnline || lastSeen == null) return false;
    return DateTime.now().difference(lastSeen!) < const Duration(minutes: 2);
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'nameLower': name.toLowerCase(),
      'email': email,
      'photoUrl': photoUrl,
      'photoBase64': photoBase64,
      'createdAt': Timestamp.fromDate(createdAt),
      'isOnline': isOnline,
      'lastSeen': lastSeen == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(lastSeen!),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      photoBase64: map['photoBase64'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isOnline: map['isOnline'] ?? false,
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate(),
    );
  }
}