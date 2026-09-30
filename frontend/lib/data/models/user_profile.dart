import 'dart:typed_data';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.avatarBytes,
  });

  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final Uint8List? avatarBytes;

  UserProfile copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    Uint8List? avatarBytes,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarBytes: avatarBytes ?? this.avatarBytes,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'email': email, 'avatarUrl': avatarUrl};
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}
