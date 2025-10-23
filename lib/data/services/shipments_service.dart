import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shipment.dart';
import '../models/status_history.dart';

final shipmentsServiceProvider = Provider<ShipmentsService>((ref) {
  return ShipmentsService(
    firestore: FirebaseFirestore.instance,
    functions: FirebaseFunctions.instance,
  );
});

final senderShipmentsProvider = StreamProvider.family<List<Shipment>, String>(
  (ref, uid) => ref.read(shipmentsServiceProvider).shipmentsBySender(uid),
);

final receiverShipmentsProvider = StreamProvider.family<List<Shipment>, String>(
  (ref, uid) => ref.read(shipmentsServiceProvider).shipmentsByReceiver(uid),
);

final shipmentProvider = StreamProvider.family<Shipment?, String>(
  (ref, id) => ref.read(shipmentsServiceProvider).watchShipment(id),
);

final shipmentHistoryProvider = StreamProvider.family<List<StatusHistoryEntry>, String>(
  (ref, id) => ref.read(shipmentsServiceProvider).history(id),
);

final availableShipmentsProvider =
    StreamProvider<List<Shipment>>((ref) => ref.read(shipmentsServiceProvider).availableShipments());

final riderActiveShipmentsProvider = StreamProvider.family<List<Shipment>, String>(
  (ref, uid) => ref.read(shipmentsServiceProvider).riderShipments(uid),
);

class ShipmentsService {
  ShipmentsService({required this.firestore, required this.functions});

  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  CollectionReference<Shipment> get _collection =>
      Shipment.collection(firestore);

  Future<Shipment?> fetchById(String id) async {
    final doc = await _collection.doc(id).get();
    return doc.data();
  }

  Stream<Shipment?> watchShipment(String id) {
    return _collection.doc(id).snapshots().map((doc) => doc.data());
  }

  Stream<List<Shipment>> shipmentsBySender(String uid) {
    return _collection
        .where('senderUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Stream<List<Shipment>> shipmentsByReceiver(String uid) {
    return _collection
        .where('receiverUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Stream<List<Shipment>> availableShipments() {
    return _collection
        .where('statusCode', isEqualTo: 1)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Stream<List<Shipment>> riderShipments(String uid) {
    return _collection
        .where('riderUid', isEqualTo: uid)
        .where('statusCode', isLessThan: 6)
        .orderBy('statusCode', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<String> createShipment({
    required Shipment shipment,
    String? id,
  }) async {
    final doc = id != null ? _collection.doc(id) : _collection.doc();
    await doc.set(shipment.toJson());
    await _appendHistory(
      shipmentId: doc.id,
      entry: StatusHistoryEntry(
        id: '',
        code: shipment.statusCode,
        label: shipment.statusLabel,
        timestamp: shipment.createdAt,
        byUid: shipment.senderUid,
      ),
    );
    return doc.id;
  }

  Future<void> updateStatus({
    required String shipmentId,
    required int code,
    required String label,
    String? photoUrl,
    required String actorUid,
  }) async {
    final now = DateTime.now();
    await _collection.doc(shipmentId).update({
      'statusCode': code,
      'statusLabel': label,
      'updatedAt': FieldValue.serverTimestamp(),
      if (photoUrl != null) 'lastStatusPhotoURL': photoUrl,
    });
    await _appendHistory(
      shipmentId: shipmentId,
      entry: StatusHistoryEntry(
        id: '',
        code: code,
        label: label,
        timestamp: now,
        byUid: actorUid,
        photoUrl: photoUrl,
      ),
    );
  }

  Future<void> _appendHistory({
    required String shipmentId,
    required StatusHistoryEntry entry,
  }) async {
    await StatusHistoryEntry.collection(firestore, shipmentId).add(entry);
  }

  Stream<List<StatusHistoryEntry>> history(String shipmentId) {
    return StatusHistoryEntry.collection(firestore, shipmentId)
        .orderBy('ts', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<bool> assignRider({
    required String shipmentId,
    required String riderUid,
  }) async {
    final callable = functions.httpsCallable('assignRider');
    final result = await callable.call({
      'shipmentId': shipmentId,
      'riderUid': riderUid,
    });
    return result.data == true || result.data == 'ok';
  }

  Future<bool> validateProximity({
    required String shipmentId,
    required double lat,
    required double lng,
    required int targetCode,
  }) async {
    final callable = functions.httpsCallable('validateNear');
    final result = await callable.call({
      'shipmentId': shipmentId,
      'lat': lat,
      'lng': lng,
      'code': targetCode,
    });
    return result.data == true;
  }

  Future<void> updateRiderLocation({
    required String shipmentId,
    required double lat,
    required double lng,
  }) async {
    await _collection.doc(shipmentId).update({
      'riderLocation': {
        'lat': lat,
        'lng': lng,
        'updatedAt': FieldValue.serverTimestamp(),
      }
    });
  }
}
