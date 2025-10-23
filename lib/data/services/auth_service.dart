import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    firebaseAuth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
  );
});

final authStateChangesProvider =
    StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  return auth.authStateChanges().asyncExpand((user) {
    if (user == null) {
      return Stream<UserProfile?>.value(null);
    }
    return UserProfile.collection(firestore)
        .doc(user.uid)
        .snapshots()
        .map((snapshot) => snapshot.data());
  });
});

final userProfileProvider = StreamProvider.family<UserProfile?, String>((ref, uid) {
  final firestore = FirebaseFirestore.instance;
  return UserProfile.collection(firestore)
      .doc(uid)
      .snapshots()
      .map((snapshot) => snapshot.data());
});

class AuthService {
  AuthService({required this.firebaseAuth, required this.firestore});

  final FirebaseAuth firebaseAuth;
  final FirebaseFirestore firestore;

  Future<UserCredential> login({
    required String phone,
    required String password,
  }) async {
    return firebaseAuth.signInWithEmailAndPassword(
      email: _emailFromPhone(phone),
      password: password,
    );
  }

  Future<UserCredential> registerUser({
    required String phone,
    required String password,
    required String name,
    String? avatarUrl,
  }) async {
    final credential = await firebaseAuth.createUserWithEmailAndPassword(
      email: _emailFromPhone(phone),
      password: password,
    );
    final profile = UserProfile(
      uid: credential.user!.uid,
      role: UserRole.user,
      phone: phone,
      name: name,
      avatarUrl: avatarUrl,
      createdAt: DateTime.now(),
    );
    await UserProfile.collection(firestore)
        .doc(profile.uid)
        .set(profile);
    return credential;
  }

  Future<UserCredential> registerRider({
    required String phone,
    required String password,
    required String name,
    required String plate,
    required List<String> riderPhotoUrls,
  }) async {
    final credential = await firebaseAuth.createUserWithEmailAndPassword(
      email: _emailFromPhone(phone),
      password: password,
    );
    final profile = UserProfile(
      uid: credential.user!.uid,
      role: UserRole.rider,
      phone: phone,
      name: name,
      avatarUrl: riderPhotoUrls.isNotEmpty ? riderPhotoUrls.first : null,
      createdAt: DateTime.now(),
    );
    await UserProfile.collection(firestore)
        .doc(profile.uid)
        .set(profile);
    await firestore
        .collection('users')
        .doc(profile.uid)
        .collection('riderMeta')
        .doc('profile')
        .set({
      'plate': plate,
      'photos': riderPhotoUrls,
    });
    return credential;
  }

  Future<void> logout() async {
    await firebaseAuth.signOut();
  }

  String _emailFromPhone(String phone) {
    final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    return '$normalized@delivery-app.local';
  }
}
