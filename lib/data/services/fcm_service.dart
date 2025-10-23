import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(
    messaging: FirebaseMessaging.instance,
    firestore: FirebaseFirestore.instance,
  );
});

class FcmService {
  FcmService({required this.messaging, required this.firestore});

  final FirebaseMessaging messaging;
  final FirebaseFirestore firestore;

  Future<void> initTokenSync() async {
    await messaging.requestPermission();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await messaging.getToken();
    if (token == null) return;
    await firestore.collection('tokens').doc(user.uid).set({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
