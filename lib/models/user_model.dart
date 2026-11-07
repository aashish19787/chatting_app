import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final String photoBase64;
  final String bio;
  final String note;
  final DateTime? noteAt;
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
    this.bio = '',
    this.note = '',
    this.noteAt,
    this.isOnline = false,
    this.lastSeen,
  });

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoUrl,
    String? photoBase64,
    String? bio,
    String? note,
    DateTime? noteAt,
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
      bio: bio ?? this.bio,
      note: note ?? this.note,
      noteAt: noteAt ?? this.noteAt,
      createdAt: createdAt ?? this.createdAt,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  bool get isActive {
    if (!isOnline || lastSeen == null) return false;
    return DateTime.now().difference(lastSeen!) < const Duration(minutes: 2);
  }

  /// A note is shown for 24 hours. A null time means "just written".
  bool get hasNote {
    if (note.isEmpty) return false;
    if (noteAt == null) return true;
    return DateTime.now().difference(noteAt!) < const Duration(hours: 24);
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'nameLower': name.toLowerCase(),
      'email': email,
      'photoUrl': photoUrl,
      'photoBase64': photoBase64,
      'bio': bio,
      'note': note,
      'noteAt': noteAt == null ? null : Timestamp.fromDate(noteAt!),
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
      bio: map['bio'] ?? '',
      note: map['note'] ?? '',
      noteAt: (map['noteAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isOnline: map['isOnline'] ?? false,
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate(),
    );
  }
}
