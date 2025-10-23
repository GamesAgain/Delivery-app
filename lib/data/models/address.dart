import 'package:cloud_firestore/cloud_firestore.dart';

class Address {
  Address({
    required this.id,
    required this.ownerUid,
    required this.label,
    required this.fullAddress,
    this.latitude,
    this.longitude,
    this.notes,
  });

  factory Address.fromJson(String id, Map<String, dynamic> json) {
    final geo = json['geo'] as Map<String, dynamic>?;
    return Address(
      id: id,
      ownerUid: json['ownerUid'] as String? ?? '',
      label: json['label'] as String? ?? '',
      fullAddress: json['fullAddress'] as String? ?? '',
      latitude: (geo?['lat'] as num?)?.toDouble(),
      longitude: (geo?['lng'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );
  }

  final String id;
  final String ownerUid;
  final String label;
  final String fullAddress;
  final double? latitude;
  final double? longitude;
  final String? notes;

  Map<String, dynamic> toJson() {
    return {
      'ownerUid': ownerUid,
      'label': label,
      'fullAddress': fullAddress,
      if (latitude != null && longitude != null)
        'geo': {'lat': latitude, 'lng': longitude},
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }

  static CollectionReference<Address> collection(
    FirebaseFirestore firestore,
    String ownerUid,
  ) {
    return firestore
        .collection('users')
        .doc(ownerUid)
        .collection('addresses')
        .withConverter<Address>(
          fromFirestore: (snapshot, _) =>
              Address.fromJson(snapshot.id, snapshot.data() ?? {}),
          toFirestore: (address, _) => address.toJson(),
        );
  }
}
