import 'package:cloud_firestore/cloud_firestore.dart';

class Users {
  final String uid;
  final String role;
  final String email;
  final String username;
  final String? displayName;
  final String? avatar;
  final String? phone;
  final DateTime? createdAt;

  const Users({
    required this.uid,
    required this.role,
    required this.email,
    required this.username,
    this.displayName,
    this.avatar,
    this.phone,
    this.createdAt,
  });

  /// ✅ แปลงจาก Firestore Map → User object
  factory Users.fromMap(Map<String, dynamic> map) {
    return Users(
      uid: map['uid'] ?? '',
      role: map['role'] ?? '',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      displayName: map['displayName'],
      avatar: map['avatar'],
      phone: map['phone'],
      createdAt: _toDate(map['createdAt']),
    );
  }

  /// ✅ แปลง User object → Map (ไว้บันทึก Firestore)
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'role': role,
      'email': email,
      'username': username,
      'displayName': displayName,
      'avatar': avatar,
      'phone': phone,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  /// แปลง Timestamp / String / DateTime → DateTime?
  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    if (v is DateTime) return v;
    return null;
  }
}
