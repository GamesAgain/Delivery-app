import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/address.dart';

final addressServiceProvider = Provider<AddressService>((ref) {
  return AddressService(FirebaseFirestore.instance);
});

final userAddressesProvider = StreamProvider.family<List<Address>, String>(
  (ref, uid) => Address.collection(FirebaseFirestore.instance, uid)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList()),
);

class AddressService {
  AddressService(this.firestore);

  final FirebaseFirestore firestore;

  Future<void> addAddress(String uid, Address address) async {
    await Address.collection(firestore, uid).doc(address.id).set(address);
  }
}
