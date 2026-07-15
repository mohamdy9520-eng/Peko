import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String username;
  final String phone;
  final String image;
  final String? bio;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final String? fcmToken;
  final Map<String, dynamic>? preferences;
  final int version;
  final String? avatarBase64;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.username,
    required this.phone,
    required this.image,
    this.bio,
    this.createdAt,
    this.updatedAt,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    this.fcmToken,
    this.preferences,
    this.version = 1,
    this.avatarBase64,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, {String? documentId}) {
    return UserModel(
      uid: documentId ?? data['uid'] ?? '',
      name: data['name'] ?? 'User',
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      phone: data['phone'] ?? '',
      image: data['image'] ?? '',
      bio: data['bio'],
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      isEmailVerified: data['isEmailVerified'] ?? false,
      isPhoneVerified: data['isPhoneVerified'] ?? false,
      fcmToken: data['fcmToken'],
      preferences: data['preferences'] != null
          ? Map<String, dynamic>.from(data['preferences'])
          : null,
      version: data['version'] ?? 1,
      avatarBase64: data['avatarBase64'],
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'username': username,
      'phone': phone,
      'image': image,
      'bio': bio,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'isEmailVerified': isEmailVerified,
      'isPhoneVerified': isPhoneVerified,
      'fcmToken': fcmToken,
      'preferences': preferences,
      'version': version,
      'avatarBase64': avatarBase64,
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? username,
    String? phone,
    String? image,
    String? bio,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isEmailVerified,
    bool? isPhoneVerified,
    String? fcmToken,
    Map<String, dynamic>? preferences,
    int? version,
    String? avatarBase64,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      image: image ?? this.image,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      fcmToken: fcmToken ?? this.fcmToken,
      preferences: preferences ?? this.preferences,
      version: version ?? this.version,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
    );
  }

  static const UserModel empty = UserModel(
    uid: '', name: 'Loading...', email: '',
    username: '', phone: '', image: '',
  );

  bool get isEmpty => uid.isEmpty;
  bool get hasImage => image.isNotEmpty;
  bool get hasAvatar => avatarBase64 != null && avatarBase64!.isNotEmpty;
  String get displayName => name.isNotEmpty ? name : username;
  String get initials => name.isNotEmpty
      ? name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
      : '?';

  @override
  String toString() => 'UserModel(uid: $uid, name: $name, email: $email)';
}