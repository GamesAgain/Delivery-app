import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { user, rider }

class UserProfile {
  UserProfile({
    required this.uid,
    required this.role,
    required this.phone,
    required this.name,
    this.avatarUrl,
    this.createdAt,
  });

  factory UserProfile.fromJson(String id, Map<String, dynamic> json) {
    return UserProfile(
      uid: id,
      role: _parseRole(json['role'] as String?),
      phone: json['phone'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatarURL'] as String?,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static UserRole _parseRole(String? raw) {
    return raw == 'rider' ? UserRole.rider : UserRole.user;
  }

  final String uid;
  final UserRole role;
  final String phone;
  final String name;
  final String? avatarUrl;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() {
    return {
      'role': role.name,
      'phone': phone,
      'name': name,
      if (avatarUrl != null) 'avatarURL': avatarUrl,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }

  static CollectionReference<UserProfile> collection(
    FirebaseFirestore firestore,
  ) {
    return firestore.collection('users').withConverter<UserProfile>(
          fromFirestore: (snapshot, _) =>
              UserProfile.fromJson(snapshot.id, snapshot.data() ?? {}),
          toFirestore: (profile, _) => profile.toJson(),
        );
  }
}
