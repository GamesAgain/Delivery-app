import 'package:cloud_firestore/cloud_firestore.dart';

class Address {
  Address({
    required this.id,
    required this.uid,
    required this.label,
    required this.fullAddress,
    required this.isDefault,
    this.lat,
    this.lng,
    this.createdAt,
    this.updatedAt,
    this.extra,
  });

  final String id;
  final String uid;
  final String label;
  final String fullAddress;
  final int isDefault;
  final double? lat;
  final double? lng;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Map<String, dynamic>? extra;

  factory Address.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return Address(
      id: data['addr_id'] as String? ?? doc.id,
      uid: data['uid'] as String? ?? '',
      label: data['label'] as String? ?? data['addressName'] as String? ?? '-',
      fullAddress: data['fullAddress'] as String? ?? '-',
      isDefault: (data['is_default'] as num?)?.toInt() ?? 1,
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
      createdAt: data['create_at'] as Timestamp?,
      updatedAt: data['update_at'] as Timestamp?,
      extra: data,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'addr_id': id,
      'uid': uid,
      'label': label,
      'fullAddress': fullAddress,
      'lat': lat,
      'lng': lng,
      'is_default': isDefault,
      'create_at': createdAt,
      'update_at': updatedAt,
    };
  }
}
