import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(FirebaseStorage.instance);
});

class StorageService {
  StorageService(this._storage);

  final FirebaseStorage _storage;

  Future<String> uploadUserAvatar({
    required String uid,
    required XFile file,
  }) async {
    final ref = _storage.ref().child('users/$uid/avatar/${file.name}');
    final uploadTask = ref.putData(await file.readAsBytes());
    final snapshot = await uploadTask.whenComplete(() {});
    return snapshot.ref.getDownloadURL();
  }

  Future<String> uploadRiderPhoto({
    required String uid,
    required XFile file,
    required int index,
  }) async {
    final ref =
        _storage.ref().child('users/$uid/rider/${index}_${file.name}');
    final snapshot = await ref.putData(await file.readAsBytes());
    return snapshot.ref.getDownloadURL();
  }

  Future<String> uploadShipmentPhoto({
    required String shipmentId,
    required String statusCode,
    required XFile file,
  }) async {
    final ref = _storage
        .ref()
        .child('shipments/$shipmentId/status_$statusCode/${file.name}');
    UploadTask uploadTask;
    if (kIsWeb) {
      uploadTask = ref.putData(await file.readAsBytes());
    } else {
      uploadTask = ref.putFile(File(file.path));
    }
    final snapshot = await uploadTask.whenComplete(() {});
    return snapshot.ref.getDownloadURL();
  }

  Future<String> uploadItemPhoto({
    required String shipmentId,
    required XFile file,
  }) async {
    final ref = _storage
        .ref()
        .child('shipments/$shipmentId/item/${file.name}');
    final snapshot = await ref.putData(await file.readAsBytes());
    return snapshot.ref.getDownloadURL();
  }
}
