import 'package:cloud_firestore/cloud_firestore.dart';

class StatusHistoryEntry {
  StatusHistoryEntry({
    required this.id,
    required this.code,
    required this.label,
    required this.timestamp,
    required this.byUid,
    this.photoUrl,
  });

  factory StatusHistoryEntry.fromJson(String id, Map<String, dynamic> json) {
    return StatusHistoryEntry(
      id: id,
      code: json['code'] as int? ?? 0,
      label: json['label'] as String? ?? '',
      timestamp: (json['ts'] as Timestamp?)?.toDate() ?? DateTime.now(),
      byUid: json['byUid'] as String? ?? '',
      photoUrl: json['photoURL'] as String?,
    );
  }

  final String id;
  final int code;
  final String label;
  final DateTime timestamp;
  final String byUid;
  final String? photoUrl;

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'label': label,
      'ts': Timestamp.fromDate(timestamp),
      'byUid': byUid,
      if (photoUrl != null) 'photoURL': photoUrl,
    };
  }

  static CollectionReference<StatusHistoryEntry> collection(
    FirebaseFirestore firestore,
    String shipmentId,
  ) {
    return firestore
        .collection('shipments')
        .doc(shipmentId)
        .collection('history')
        .withConverter<StatusHistoryEntry>(
          fromFirestore: (snapshot, _) =>
              StatusHistoryEntry.fromJson(snapshot.id, snapshot.data() ?? {}),
          toFirestore: (entry, _) => entry.toJson(),
        );
  }
}
