import 'package:cloud_firestore/cloud_firestore.dart';

class ShipmentPoint {
  const ShipmentPoint({
    this.addressRef,
    this.inlineAddress,
    this.lat,
    this.lng,
  });

  factory ShipmentPoint.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ShipmentPoint();
    }
    return ShipmentPoint(
      addressRef: json['addressRef'] as String?,
      inlineAddress: json['inline'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }

  final String? addressRef;
  final String? inlineAddress;
  final double? lat;
  final double? lng;

  Map<String, dynamic> toJson() {
    return {
      if (addressRef != null) 'addressRef': addressRef,
      if (inlineAddress != null) 'inline': inlineAddress,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    };
  }
}

class ShipmentItem {
  const ShipmentItem({
    required this.name,
    this.weight,
    this.size,
  });

  factory ShipmentItem.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ShipmentItem(name: '');
    }
    return ShipmentItem(
      name: json['name'] as String? ?? '',
      weight: json['weight'] as num?,
      size: json['size'] as String?,
    );
  }

  final String name;
  final num? weight;
  final String? size;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (weight != null) 'weight': weight,
      if (size != null) 'size': size,
    };
  }
}

class Shipment {
  Shipment({
    required this.id,
    required this.senderUid,
    required this.receiverUid,
    this.riderUid,
    required this.createdAt,
    required this.updatedAt,
    required this.pickup,
    required this.dropoff,
    required this.item,
    this.itemPhotoUrl,
    required this.statusCode,
    required this.statusLabel,
    this.sharedMap = true,
  });

  factory Shipment.fromJson(String id, Map<String, dynamic> json) {
    return Shipment(
      id: id,
      senderUid: json['senderUid'] as String? ?? '',
      receiverUid: json['receiverUid'] as String? ?? '',
      riderUid: json['riderUid'] as String?,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pickup: ShipmentPoint.fromJson(json['pickup'] as Map<String, dynamic>?),
      dropoff:
          ShipmentPoint.fromJson(json['dropoff'] as Map<String, dynamic>?),
      item: ShipmentItem.fromJson(json['item'] as Map<String, dynamic>?),
      itemPhotoUrl: json['itemPhotoURL'] as String?,
      statusCode: json['statusCode'] as int? ?? 0,
      statusLabel: json['statusLabel'] as String? ?? '',
      sharedMap: json['sharedMap'] as bool? ?? true,
    );
  }

  final String id;
  final String senderUid;
  final String receiverUid;
  final String? riderUid;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ShipmentPoint pickup;
  final ShipmentPoint dropoff;
  final ShipmentItem item;
  final String? itemPhotoUrl;
  final int statusCode;
  final String statusLabel;
  final bool sharedMap;

  Map<String, dynamic> toJson() {
    return {
      'senderUid': senderUid,
      'receiverUid': receiverUid,
      if (riderUid != null) 'riderUid': riderUid,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'pickup': pickup.toJson(),
      'dropoff': dropoff.toJson(),
      'item': item.toJson(),
      if (itemPhotoUrl != null) 'itemPhotoURL': itemPhotoUrl,
      'statusCode': statusCode,
      'statusLabel': statusLabel,
      'sharedMap': sharedMap,
    };
  }

  Shipment copyWith({
    String? riderUid,
    DateTime? updatedAt,
    int? statusCode,
    String? statusLabel,
    bool? sharedMap,
    String? itemPhotoUrl,
  }) {
    return Shipment(
      id: id,
      senderUid: senderUid,
      receiverUid: receiverUid,
      riderUid: riderUid ?? this.riderUid,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pickup: pickup,
      dropoff: dropoff,
      item: item,
      itemPhotoUrl: itemPhotoUrl ?? this.itemPhotoUrl,
      statusCode: statusCode ?? this.statusCode,
      statusLabel: statusLabel ?? this.statusLabel,
      sharedMap: sharedMap ?? this.sharedMap,
    );
  }

  static CollectionReference<Shipment> collection(
    FirebaseFirestore firestore,
  ) {
    return firestore.collection('shipments').withConverter<Shipment>(
          fromFirestore: (snapshot, _) =>
              Shipment.fromJson(snapshot.id, snapshot.data() ?? {}),
          toFirestore: (shipment, _) => shipment.toJson(),
        );
  }
}

class ShipmentStatusHelper {
  static const Map<int, String> labels = {
    1: 'Awaiting rider',
    2: 'Accepted',
    3: 'Picked up',
    4: 'En-route',
    5: 'Delivered',
    90: 'Cancelled by sender',
    91: 'Cancelled by rider',
  };

  static String labelFor(int code) => labels[code] ?? 'Unknown';
}
