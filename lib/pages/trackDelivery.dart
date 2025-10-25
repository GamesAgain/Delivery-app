import 'dart:async';
import 'dart:math';

import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_map/flutter_map.dart' as ll;
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;

class TrackDeliveryPage extends StatefulWidget {
  const TrackDeliveryPage({super.key, this.deliveryId, this.itemName});

  final String? deliveryId;
  final String? itemName;

  @override
  State<TrackDeliveryPage> createState() => _TrackDeliveryPageState();
}

class _TrackDeliveryPageState extends State<TrackDeliveryPage> {
  static const Color _background = Color(0xFF0B0F19);
  static const Color _panel = Color(0xFF111827);
  static const Color _green = Color(0xFF16A34A);
  static const Color _white = Colors.white;

  static const Map<int, String> _statusLabels = {
    1: 'รอไรเดอร์มารับสินค้า',
    2: 'ไรเดอร์รับงาน',
    3: 'ไรเดอร์รับสินค้าแล้ว',
    4: 'ไรเดอร์นำส่งสินค้าแล้ว',
  };

  static final ll.LatLng _initialCameraPosition = ll.LatLng(
    13.736717,
    100.523186,
  );

  final fm.MapController _mapController = fm.MapController();

  late final Stream<List<_TrackedDelivery>> _deliveriesStream;
  final _locationStreamController =
      StreamController<Map<String, ll.LatLng?>>.broadcast();
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _riderLocationListeners = {};
  final Map<String, String> _deliveryRiderIds = {};
  final Map<String, ll.LatLng?> _currentRiderLocations = {};
  StreamSubscription<List<_TrackedDelivery>>? _firestoreSubscription;

  final Map<String, Future<_UserProfile?>> _userCache = {};
  final Map<String, Future<_RiderProfile?>> _riderCache = {};
  final Map<String, Future<_AddressDetails?>> _addressCache = {};
  final Map<String, Future<_AssignmentDetails?>> _assignmentCache = {};

  String? _pendingFocusDeliveryId;
  String? _focusedDeliveryId;
  String? _lastCameraSignature;

  Stream<Map<String, ll.LatLng?>> get _realtimeLocationStream =>
      _locationStreamController.stream;

  @override
  void initState() {
    super.initState();
    _pendingFocusDeliveryId = widget.deliveryId;
    _focusedDeliveryId = widget.deliveryId;
    _deliveriesStream = _trackedDeliveriesStream();
    _firestoreSubscription = _deliveriesStream.listen(
      _onDeliveriesUpdated,
      onError: (error, stackTrace) {
        if (_locationStreamController.isClosed) {
          return;
        }
        _locationStreamController.addError(error, stackTrace);
      },
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    final firestoreSubscription = _firestoreSubscription;
    _firestoreSubscription = null;
    if (firestoreSubscription != null) {
      unawaited(firestoreSubscription.cancel());
    }
    for (final subscription in _riderLocationListeners.values) {
      unawaited(subscription.cancel());
    }
    _riderLocationListeners.clear();
    _deliveryRiderIds.clear();
    _currentRiderLocations.clear();
    unawaited(_locationStreamController.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: _white),
        title: Text(
          widget.deliveryId == null ? 'Track Deliveries' : 'Delivery Tracking',
          style: GoogleFonts.poppins(
            color: _white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: StreamBuilder<List<_TrackedDelivery>>(
            stream: _deliveriesStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'ไม่สามารถโหลดข้อมูลการติดตามได้',
                    style: GoogleFonts.poppins(color: Colors.white70),
                  ),
                );
              }

              final deliveries = snapshot.data ?? const <_TrackedDelivery>[];

              return StreamBuilder<Map<String, ll.LatLng?>>(
                stream: _realtimeLocationStream,
                builder: (context, locationSnapshot) {
                  final realtimePositions =
                      locationSnapshot.data ?? const <String, ll.LatLng?>{};
                  final finalPositions = _mergePositions(
                    deliveries,
                    realtimePositions,
                  );

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _updateCamera(deliveries, finalPositions);
                    if (_pendingFocusDeliveryId != null) {
                      final target = _findDeliveryById(
                        deliveries,
                        _pendingFocusDeliveryId!,
                      );
                      if (target != null) {
                        final didFocus = _focusDeliveryOnMap(
                          target,
                          updateState: true,
                          positionOverride: finalPositions[target.did]?.primary,
                        );
                        if (didFocus) {
                          _pendingFocusDeliveryId = null;
                        }
                      }
                    }
                  });

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(deliveries),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _buildMap(
                          deliveries,
                          finalPositions,
                          isLoading:
                              locationSnapshot.connectionState ==
                              ConnectionState.waiting,
                          error: locationSnapshot.hasError
                              ? 'เกิดข้อผิดพลาดในการเชื่อมต่อข้อมูลตำแหน่ง'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDeliveryList(deliveries, finalPositions),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _onDeliveriesUpdated(List<_TrackedDelivery> deliveries) {
    if (!mounted) {
      return;
    }

    final newDeliveryIds = deliveries.map((delivery) => delivery.did).toSet();
    final existingDeliveryIds = _riderLocationListeners.keys.toSet();

    final idsToRemove = existingDeliveryIds.difference(newDeliveryIds);
    for (final id in idsToRemove) {
      final subscription = _riderLocationListeners.remove(id);
      _deliveryRiderIds.remove(id);
      if (subscription != null) {
        unawaited(subscription.cancel());
      }
      _currentRiderLocations.remove(id);
    }

    for (final delivery in deliveries) {
      final rid = delivery.riderProfile?.uid ?? delivery.riderId;
      final currentRid = _deliveryRiderIds[delivery.did];
      if (rid == null || rid.isEmpty) {
        if (currentRid != null) {
          final subscription = _riderLocationListeners.remove(delivery.did);
          _deliveryRiderIds.remove(delivery.did);
          if (subscription != null) {
            unawaited(subscription.cancel());
          }
          _currentRiderLocations.remove(delivery.did);
        }
        continue;
      }

      if (currentRid == rid) {
        continue;
      }

      final subscription = _riderLocationListeners.remove(delivery.did);
      if (subscription != null) {
        unawaited(subscription.cancel());
      }
      _listenToRiderLocation(delivery.did, rid);
    }

    if (_locationStreamController.isClosed) {
      return;
    }
    _locationStreamController.add(
      Map<String, ll.LatLng?>.from(_currentRiderLocations),
    );
  }

  void _listenToRiderLocation(String deliveryId, String riderId) {
    final docRef = FirebaseFirestore.instance
        .collection('RiderLocation')
        .doc(deliveryId);

    final subscription = docRef.snapshots().listen(
      (snapshot) {
        if (_locationStreamController.isClosed) {
          return;
        }

        ll.LatLng? latLng;
        if (snapshot.exists) {
          final data = snapshot.data();
          if (data != null) {
            final docRid = data['rid'] as String?;
            if (docRid == null || docRid == riderId) {
              latLng = _latLngFromDynamic(data);
            } else {
              latLng = null;
            }
          }
        }

        if (latLng != null) {
          _currentRiderLocations[deliveryId] = latLng;
        } else {
          _currentRiderLocations.remove(deliveryId);
        }

        _locationStreamController.add(
          Map<String, ll.LatLng?>.from(_currentRiderLocations),
        );
      },
      onError: (error, stackTrace) {
        if (_locationStreamController.isClosed) {
          return;
        }
        _locationStreamController.addError(error, stackTrace);
      },
    );

    _riderLocationListeners[deliveryId] = subscription;
    _deliveryRiderIds[deliveryId] = riderId;
  }

  Map<String, _DeliveryMapData> _mergePositions(
    List<_TrackedDelivery> deliveries,
    Map<String, ll.LatLng?> realtimePositions,
  ) {
    final merged = <String, _DeliveryMapData>{};
    for (final delivery in deliveries) {
      final rider =
          realtimePositions[delivery.did] ?? delivery.riderLastKnownPosition;
      merged[delivery.did] = _DeliveryMapData(
        pickup: delivery.pickupAddress?.position,
        dropoff: delivery.dropoffAddress?.position,
        rider: rider,
      );
    }
    return merged;
  }

  Stream<List<_TrackedDelivery>> _trackedDeliveriesStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Stream<List<_TrackedDelivery>>.value(const []);
    }

    final deliveryId = widget.deliveryId;
    if (deliveryId != null && deliveryId.isNotEmpty) {
      final docRef = FirebaseFirestore.instance
          .collection('delivery')
          .doc(deliveryId);
      return docRef.snapshots().asyncMap((snapshot) async {
        if (!snapshot.exists || snapshot.data() == null) {
          return const <_TrackedDelivery>[];
        }
        final tracked = await _buildTrackedDeliveryFromSnapshot(snapshot);
        if (tracked == null) {
          return const <_TrackedDelivery>[];
        }
        return <_TrackedDelivery>[tracked];
      });
    }

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('delivery')
        .where('sender_uid', isEqualTo: currentUser.uid);

    return query.snapshots().asyncMap((snapshot) async {
      final futures = snapshot.docs.map(_buildTrackedDelivery).toList();
      final results = await Future.wait(futures);
      final filtered = results.whereType<_TrackedDelivery>().toList(
        growable: false,
      );
      filtered.sort(
        (a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return filtered;
    });
  }

  Future<_TrackedDelivery?> _buildTrackedDelivery(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return _buildTrackedDeliveryFromSnapshot(doc);
  }

  Future<_TrackedDelivery?> _buildTrackedDeliveryFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    if (data == null) {
      return null;
    }

    final did = (data['did'] as String?) ?? doc.id;
    final itemNameRaw = (data['item_name'] as String?)?.trim();
    final itemName = (itemNameRaw != null && itemNameRaw.isNotEmpty)
        ? itemNameRaw
        : widget.itemName ?? 'รายการจัดส่ง';

    final statusCode = _parseStatusCode(data['status_code']);
    final statusText = (data['status'] as String?)?.trim();

    final assignment = await _fetchAssignment(did);
    final riderId = assignment?.rid ?? data['rid'] as String?;

    final pickupAddress = await _fetchAddressDetails(
      data['pickup_addr_id'] as String?,
    );
    final dropoffAddress = await _fetchAddressDetails(
      data['dropoff_addr_id'] as String?,
    );

    final riderProfile = await _fetchRiderProfile(riderId);
    final senderProfile = await _fetchUserProfile(
      data['sender_uid'] as String?,
    );
    final receiverProfile = await _fetchUserProfile(
      data['receiver_uid'] as String?,
    );

    final updatedAt =
        (data['updated_at'] as Timestamp?)?.toDate() ??
        (data['created_at'] as Timestamp?)?.toDate();
    final riderFallback =
        _latLngFromDynamic(data['rider_location']) ??
        _latLngFromDynamic(data['current_location']);

    return _TrackedDelivery(
      did: did,
      itemName: itemName,
      statusCode: statusCode,
      statusLabel: (statusText != null && statusText.isNotEmpty)
          ? statusText
          : _statusLabels[statusCode] ?? 'สถานะไม่ทราบ',
      updatedAt: updatedAt,
      riderProfile:
          riderProfile ??
          (riderId != null && riderId.isNotEmpty
              ? _RiderProfile(uid: riderId, username: 'ไรเดอร์')
              : null),
      senderProfile: senderProfile,
      receiverProfile: receiverProfile,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      riderId: riderId,
      riderLastKnownPosition: riderFallback,
      senderUid: data['sender_uid'] as String?,
      receiverUid: data['receiver_uid'] as String?,
    );
  }

  Widget _buildHeader(List<_TrackedDelivery> deliveries) {
    final isSingle = widget.deliveryId != null;
    final title = isSingle
        ? (widget.itemName ?? deliveries.firstOrNull?.itemName ?? 'Delivery')
        : 'Delivery Tracking';
    final subtitle = isSingle
        ? (deliveries.firstOrNull?.statusLabel ?? 'กำลังตรวจสอบสถานะ')
        : 'คุณมี ${deliveries.length} รายการที่กำลังจัดส่ง';
    final latest = _latestUpdatedAt(deliveries);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            color: _white,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                subtitle,
                style: GoogleFonts.poppins(color: Colors.white60, fontSize: 13),
              ),
            ),
            if (latest != null)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0x3316A34A),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    const Icon(
                      BootstrapIcons.clock_history,
                      color: _green,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatRelativeTime(latest),
                      style: GoogleFonts.poppins(
                        color: _green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMap(
    List<_TrackedDelivery> deliveries,
    Map<String, _DeliveryMapData> positions, {
    required bool isLoading,
    String? error,
  }) {
    final hasDeliveries = deliveries.isNotEmpty;
    final markers = <fm.Marker>[];

    for (final delivery in deliveries) {
      final data = positions[delivery.did];
      if (data == null) continue;
      final pickup = data.pickup;
      final dropoff = data.dropoff;
      final rider = data.rider;
      if (pickup != null) {
        markers.add(
          _createMarker(
            delivery: delivery,
            position: pickup,
            type: _MarkerType.pickup,
          ),
        );
      }
      if (dropoff != null) {
        markers.add(
          _createMarker(
            delivery: delivery,
            position: dropoff,
            type: _MarkerType.dropoff,
          ),
        );
      }
      if (rider != null) {
        markers.add(
          _createMarker(
            delivery: delivery,
            position: rider,
            type: _MarkerType.rider,
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            fm.FlutterMap(
              mapController: _mapController,
              options: fm.MapOptions(
                initialCenter: _initialCameraPosition,
                initialZoom: 12,
              ),
              children: [
                fm.TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.delivery.app',
                ),
                fm.MarkerLayer(markers: markers),
              ],
            ),
            if (!hasDeliveries)
              _buildMapMessage(
                'ยังไม่มีข้อมูลการจัดส่ง',
                'เมื่อมีไรเดอร์รับงาน ระบบจะแสดงตำแหน่งที่นี่',
              )
            else if (positions.values.every(
              (data) =>
                  data.rider == null &&
                  data.pickup == null &&
                  data.dropoff == null,
            ))
              _buildMapMessage(
                isLoading
                    ? 'กำลังเชื่อมต่อข้อมูลตำแหน่ง...'
                    : 'ยังไม่มีตำแหน่งสำหรับงานนี้',
                'จะแสดงผลแบบเรียลไทม์ทันทีที่มีการอัปเดต',
              ),
            if (error != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _buildErrorBanner(error),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapMessage(String title, String subtitle) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x99EF4444),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(BootstrapIcons.wifi_off, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  fm.Marker _createMarker({
    required _TrackedDelivery delivery,
    required ll.LatLng position,
    required _MarkerType type,
  }) {
    final isSelected = delivery.did == _focusedDeliveryId;
    final icon = _markerIcon(type);
    final color = _markerColor(type, isSelected: isSelected);
    final label = _markerLabel(delivery, type);

    return fm.Marker(
      width: 110,
      height: 90,
      point: position,
      child: GestureDetector(
        onTap: () => _onFocusRequest(delivery, positionOverride: position),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: type == _MarkerType.rider ? 42 : 34),
            if (label.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _panel.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryList(
    List<_TrackedDelivery> deliveries,
    Map<String, _DeliveryMapData> positions,
  ) {
    if (deliveries.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(BootstrapIcons.truck, color: Colors.white54, size: 40),
            const SizedBox(height: 12),
            Text(
              'ยังไม่มีไรเดอร์ที่กำลังจัดส่ง',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              'เมื่อมีไรเดอร์รับงานจะเห็นตำแหน่งได้แบบเรียลไทม์ที่นี่',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 280,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        itemCount: deliveries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final delivery = deliveries[index];
          final mapData = positions[delivery.did];
          return _buildDeliveryInfoCard(delivery, mapData);
        },
      ),
    );
  }

  Widget _buildDeliveryInfoCard(
    _TrackedDelivery delivery,
    _DeliveryMapData? mapData,
  ) {
    final isSelected = delivery.did == _focusedDeliveryId;
    final statusColor = _statusColor(delivery.statusCode);
    final riderPosition = mapData?.rider;
    final dropoffPosition = mapData?.dropoff;
    final pickupPosition = mapData?.pickup;
    final focusPosition =
        riderPosition ??
        dropoffPosition ??
        pickupPosition ??
        delivery.riderLastKnownPosition;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1F2937) : _panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSelected ? _green : Colors.white12,
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      _statusIcon(delivery.statusCode),
                      color: statusColor,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      delivery.statusLabel,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '#${delivery.did.substring(0, min(8, delivery.did.length)).toUpperCase()}',
                style: GoogleFonts.poppins(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            delivery.itemName,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildParticipantRow(
            icon: BootstrapIcons.person_circle,
            title: 'ผู้ส่ง',
            value:
                delivery.senderProfile?.username ??
                delivery.senderUid ??
                'ไม่ระบุ',
          ),
          const SizedBox(height: 6),
          _buildParticipantRow(
            icon: BootstrapIcons.phone,
            title: 'เบอร์โทรผู้ส่ง',
            value: delivery.senderProfile?.phone ?? 'ไม่ระบุ',
          ),
          const SizedBox(height: 6),
          _buildParticipantRow(
            icon: BootstrapIcons.person,
            title: 'ผู้รับ',
            value:
                delivery.receiverProfile?.username ??
                delivery.receiverUid ??
                'ไม่ระบุ',
          ),
          const SizedBox(height: 6),
          _buildParticipantRow(
            icon: BootstrapIcons.phone,
            title: 'เบอร์โทรผู้รับ',
            value: delivery.receiverProfile?.phone ?? 'ไม่ระบุ',
          ),
          const SizedBox(height: 6),
          _buildParticipantRow(
            icon: BootstrapIcons.bicycle,
            title: 'ไรเดอร์',
            value: delivery.riderProfile?.username ?? 'ไม่พบข้อมูล',
            trailing: (focusPosition != null)
                ? TextButton.icon(
                    onPressed: () => _onFocusRequest(
                      delivery,
                      positionOverride: focusPosition,
                    ),
                    style: TextButton.styleFrom(foregroundColor: _green),
                    icon: const Icon(BootstrapIcons.geo_fill, size: 16),
                    label: const Text('ดูตำแหน่ง'),
                  )
                : null,
          ),
          const SizedBox(height: 14),
          _buildAddressRow(
            title: 'สถานที่รับสินค้า',
            icon: BootstrapIcons.box_seam,
            address: delivery.pickupAddress,
          ),
          const SizedBox(height: 10),
          _buildAddressRow(
            title: 'สถานที่จัดส่ง',
            icon: BootstrapIcons.pin_map,
            address: delivery.dropoffAddress,
          ),
          if (pickupPosition != null ||
              dropoffPosition != null ||
              riderPosition != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (pickupPosition != null)
                  _buildCoordinateChip(
                    label: 'จุดรับสินค้า',
                    position: pickupPosition,
                    icon: BootstrapIcons.geo,
                    color: Colors.blueAccent,
                  ),
                if (dropoffPosition != null)
                  _buildCoordinateChip(
                    label: 'ปลายทาง',
                    position: dropoffPosition,
                    icon: BootstrapIcons.pin_map_fill,
                    color: Colors.purpleAccent,
                  ),
                if (riderPosition != null)
                  _buildCoordinateChip(
                    label: 'ไรเดอร์',
                    position: riderPosition,
                    icon: BootstrapIcons.geo_alt_fill,
                    color: _green,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParticipantRow({
    required IconData icon,
    required String title,
    required String value,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0x332563EB),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildCoordinateChip({
    required String label,
    required ll.LatLng position,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              Text(
                'Lat ${position.latitude.toStringAsFixed(5)}, '
                'Lng ${position.longitude.toStringAsFixed(5)}',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow({
    required String title,
    required IconData icon,
    _AddressDetails? address,
  }) {
    final hasAddress = address != null && address.displayText.isNotEmpty;
    if (!hasAddress) {
      return Row(
        children: [
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x332563EB),
            ),
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: Colors.white38, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'ไม่มีข้อมูล $title',
              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0x332563EB),
          ),
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                address!.displayText,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
              if (address.position != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Lat ${address.position!.latitude.toStringAsFixed(5)}, '
                    'Lng ${address.position!.longitude.toStringAsFixed(5)}',
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _onFocusRequest(
    _TrackedDelivery delivery, {
    ll.LatLng? positionOverride,
  }) {
    _focusDeliveryOnMap(delivery, positionOverride: positionOverride);
  }

  bool _focusDeliveryOnMap(
    _TrackedDelivery delivery, {
    bool updateState = true,
    double zoom = 16,
    ll.LatLng? positionOverride,
  }) {
    if (updateState) {
      setState(() {
        _focusedDeliveryId = delivery.did;
      });
    } else {
      _focusedDeliveryId = delivery.did;
    }

    final realtime = _currentRiderLocations[delivery.did];
    final position =
        positionOverride ??
        realtime ??
        delivery.riderLastKnownPosition ??
        delivery.dropoffAddress?.position ??
        delivery.pickupAddress?.position;

    if (position == null) {
      _pendingFocusDeliveryId = delivery.did;
      return false;
    }

    _mapController.move(position, zoom);
    _pendingFocusDeliveryId = null;
    return true;
  }

  void _updateCamera(
    List<_TrackedDelivery> deliveries,
    Map<String, _DeliveryMapData> positions,
  ) {
    if (positions.isEmpty) {
      _lastCameraSignature = null;
      return;
    }

    final keys = positions.keys.toList()..sort();
    final buffer = StringBuffer();
    for (final key in keys) {
      buffer.write(key);
      final data = positions[key];
      if (data == null) continue;
      for (final point in data.nonNullPoints) {
        buffer.write(
          ':${point.latitude.toStringAsFixed(6)},'
          '${point.longitude.toStringAsFixed(6)}',
        );
      }
      buffer.write('|');
    }

    final signature = buffer.toString();
    if (signature == _lastCameraSignature) {
      return;
    }
    _lastCameraSignature = signature;

    if (positions.length == 1) {
      final did = positions.keys.first;
      final delivery = _findDeliveryById(deliveries, did);
      if (delivery != null) {
        _focusDeliveryOnMap(
          delivery,
          updateState: false,
          positionOverride: positions[did]?.primary,
        );
      }
      return;
    }

    final points = <ll.LatLng>[];
    for (final data in positions.values) {
      points.addAll(data.nonNullPoints);
    }

    if (points.isEmpty) {
      return;
    }

    final bounds = _createBounds(points);
    if (bounds != null) {
      _mapController.fitCamera(
        fm.CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
      );
    }
  }

  ll.LatLngBounds? _createBounds(Iterable<ll.LatLng> points) {
    final iterator = points.iterator;
    if (!iterator.moveNext()) {
      return null;
    }

    double minLat = iterator.current.latitude;
    double maxLat = iterator.current.latitude;
    double minLng = iterator.current.longitude;
    double maxLng = iterator.current.longitude;

    while (iterator.moveNext()) {
      final point = iterator.current;
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    return ll.LatLngBounds(
      ll.LatLng(minLat, minLng),
      ll.LatLng(maxLat, maxLng),
    );
  }

  Future<_AssignmentDetails?> _fetchAssignment(String deliveryId) {
    return _assignmentCache.putIfAbsent(deliveryId, () async {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('assignment')
            .where('did', isEqualTo: deliveryId)
            .orderBy('accepted_at', descending: true)
            .limit(1)
            .get();
        if (snapshot.docs.isEmpty) {
          return null;
        }
        final data = snapshot.docs.first.data();
        return _AssignmentDetails(
          rid: data['rid'] as String?,
          statusCode: _parseStatusCode(data['status_code']),
        );
      } on FirebaseException catch (error) {
        if (error.code != 'failed-precondition') {
          return null;
        }
        final fallback = await FirebaseFirestore.instance
            .collection('assignment')
            .where('did', isEqualTo: deliveryId)
            .limit(1)
            .get();
        if (fallback.docs.isEmpty) {
          return null;
        }
        final data = fallback.docs.first.data();
        return _AssignmentDetails(
          rid: data['rid'] as String?,
          statusCode: _parseStatusCode(data['status_code']),
        );
      }
    });
  }

  Future<_UserProfile?> _fetchUserProfile(String? uid) {
    if (uid == null || uid.isEmpty) {
      return Future.value(null);
    }

    return _userCache.putIfAbsent(uid, () async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (!doc.exists) {
          return null;
        }
        final data = doc.data();
        if (data == null) {
          return null;
        }
        return _UserProfile(
          uid: uid,
          username: (data['username'] as String?) ?? 'ผู้ใช้งาน',
          phone: (data['phone'] as String?) ?? '',
        );
      } catch (_) {
        return null;
      }
    });
  }

  Future<_RiderProfile?> _fetchRiderProfile(String? uid) {
    if (uid == null || uid.isEmpty) {
      return Future.value(null);
    }

    return _riderCache.putIfAbsent(uid, () async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('riders')
            .doc(uid)
            .get();
        if (!doc.exists) {
          return null;
        }
        final data = doc.data();
        if (data == null) {
          return null;
        }
        return _RiderProfile(
          uid: uid,
          username: (data['username'] as String?) ?? 'Rider',
          avatarUrl: data['avatar'] as String?,
          vehiclePlate: data['vehicle_plate'] as String?,
        );
      } catch (_) {
        return null;
      }
    });
  }

  Future<_AddressDetails?> _fetchAddressDetails(String? addressId) {
    if (addressId == null || addressId.isEmpty) {
      return Future.value(null);
    }

    return _addressCache.putIfAbsent(addressId, () async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('addresses')
            .doc(addressId)
            .get();
        if (!doc.exists) {
          return null;
        }
        final data = doc.data();
        if (data == null) {
          return null;
        }
        final lat = _tryParseDouble(data['lat'] ?? data['latitude']);
        final lng = _tryParseDouble(data['lng'] ?? data['longitude']);
        ll.LatLng? position;
        if (lat != null && lng != null) {
          position = ll.LatLng(lat, lng);
        }
        final addressLine = (data['fullAddress'] as String?)?.trim();
        final label = (data['label'] as String?)?.trim();
        final number = (data['addressNumber'] as String?)?.trim();

        final buffer = StringBuffer();
        if (addressLine != null && addressLine.isNotEmpty) {
          buffer.write(addressLine);
        } else {
          if (label != null && label.isNotEmpty) {
            buffer.write(label);
          }
          if (number != null && number.isNotEmpty) {
            if (buffer.isNotEmpty) buffer.write(' ');
            buffer.write(number);
          }
          final district = (data['subDistrict'] as String?)?.trim();
          final province = (data['province'] as String?)?.trim();
          if (district != null && district.isNotEmpty) {
            if (buffer.isNotEmpty) buffer.write(' ');
            buffer.write(district);
          }
          if (province != null && province.isNotEmpty) {
            if (buffer.isNotEmpty) buffer.write(' ');
            buffer.write(province);
          }
        }

        final display = buffer.isNotEmpty
            ? buffer.toString()
            : (label?.isNotEmpty == true ? label! : addressId);

        return _AddressDetails(
          id: addressId,
          displayText: display,
          position: position,
          label: label,
        );
      } catch (_) {
        return null;
      }
    });
  }

  ll.LatLng? _latLngFromDynamic(dynamic value) {
    if (value is GeoPoint) {
      return ll.LatLng(value.latitude, value.longitude);
    }
    if (value is Map) {
      final lat = _tryParseDouble(
        value['lat'] ??
            value['latitude'] ??
            value['Lat'] ??
            value['latLng']?['lat'],
      );
      final lng = _tryParseDouble(
        value['lng'] ??
            value['longitude'] ??
            value['Lng'] ??
            value['latLng']?['lng'],
      );
      if (lat != null && lng != null) {
        return ll.LatLng(lat, lng);
      }
    }
    return null;
  }

  double? _tryParseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  int _parseStatusCode(dynamic raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw) ?? 1;
    }
    return 1;
  }

  Color _statusColor(int statusCode) {
    switch (statusCode) {
      case 1:
        return const Color(0xFFF97316);
      case 2:
        return const Color(0xFF2563EB);
      case 3:
        return const Color(0xFFFACC15);
      case 4:
        return const Color(0xFF16A34A);
      default:
        return Colors.white54;
    }
  }

  IconData _statusIcon(int statusCode) {
    switch (statusCode) {
      case 1:
        return BootstrapIcons.clock;
      case 2:
        return BootstrapIcons.bicycle;
      case 3:
        return BootstrapIcons.box_seam;
      case 4:
        return BootstrapIcons.check_circle;
      default:
        return BootstrapIcons.question_circle;
    }
  }

  Color _markerColor(_MarkerType type, {required bool isSelected}) {
    switch (type) {
      case _MarkerType.pickup:
        return isSelected ? Colors.blueAccent : Colors.lightBlueAccent;
      case _MarkerType.dropoff:
        return isSelected ? Colors.purpleAccent : Colors.purple;
      case _MarkerType.rider:
        return isSelected ? _green : const Color(0xFF22C55E);
    }
  }

  IconData _markerIcon(_MarkerType type) {
    switch (type) {
      case _MarkerType.pickup:
        return BootstrapIcons.house_door_fill;
      case _MarkerType.dropoff:
        return BootstrapIcons.geo_alt;
      case _MarkerType.rider:
        return BootstrapIcons.geo_alt_fill;
    }
  }

  String _markerLabel(_TrackedDelivery delivery, _MarkerType type) {
    switch (type) {
      case _MarkerType.pickup:
        return delivery.senderProfile?.username ?? 'ผู้ส่ง';
      case _MarkerType.dropoff:
        return delivery.receiverProfile?.username ?? 'ผู้รับ';
      case _MarkerType.rider:
        return delivery.riderProfile?.username ?? 'ไรเดอร์';
    }
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) {
      return 'เมื่อครู่';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} นาทีที่แล้ว';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} ชม.ที่แล้ว';
    }
    return '${diff.inDays} วันที่แล้ว';
  }

  DateTime? _latestUpdatedAt(List<_TrackedDelivery> deliveries) {
    DateTime? latest;
    for (final delivery in deliveries) {
      final updated = delivery.updatedAt;
      if (updated == null) continue;
      if (latest == null || updated.isAfter(latest)) {
        latest = updated;
      }
    }
    return latest;
  }

  _TrackedDelivery? _findDeliveryById(
    List<_TrackedDelivery> deliveries,
    String deliveryId,
  ) {
    for (final delivery in deliveries) {
      if (delivery.did == deliveryId) {
        return delivery;
      }
    }
    return null;
  }
}

class _TrackedDelivery {
  const _TrackedDelivery({
    required this.did,
    required this.itemName,
    required this.statusCode,
    required this.statusLabel,
    this.updatedAt,
    this.riderProfile,
    this.senderProfile,
    this.receiverProfile,
    this.pickupAddress,
    this.dropoffAddress,
    this.riderId,
    this.riderLastKnownPosition,
    this.senderUid,
    this.receiverUid,
  });

  final String did;
  final String itemName;
  final int statusCode;
  final String statusLabel;
  final DateTime? updatedAt;
  final _RiderProfile? riderProfile;
  final _UserProfile? senderProfile;
  final _UserProfile? receiverProfile;
  final _AddressDetails? pickupAddress;
  final _AddressDetails? dropoffAddress;
  final String? riderId;
  final ll.LatLng? riderLastKnownPosition;
  final String? senderUid;
  final String? receiverUid;
}

class _AddressDetails {
  const _AddressDetails({
    required this.id,
    required this.displayText,
    this.position,
    this.label,
  });

  final String id;
  final String displayText;
  final ll.LatLng? position;
  final String? label;
}

class _AssignmentDetails {
  const _AssignmentDetails({this.rid, this.statusCode});

  final String? rid;
  final int? statusCode;
}

class _DeliveryMapData {
  const _DeliveryMapData({this.pickup, this.dropoff, this.rider});

  final ll.LatLng? pickup;
  final ll.LatLng? dropoff;
  final ll.LatLng? rider;

  Iterable<ll.LatLng> get nonNullPoints sync* {
    if (pickup != null) yield pickup!;
    if (dropoff != null) yield dropoff!;
    if (rider != null) yield rider!;
  }

  ll.LatLng? get primary {
    return rider ?? dropoff ?? pickup;
  }
}

class _UserProfile {
  const _UserProfile({
    required this.uid,
    required this.username,
    required this.phone,
  });

  final String uid;
  final String username;
  final String phone;
}

class _RiderProfile {
  const _RiderProfile({
    required this.uid,
    required this.username,
    this.avatarUrl,
    this.vehiclePlate,
  });

  final String uid;
  final String username;
  final String? avatarUrl;
  final String? vehiclePlate;
}

enum _MarkerType { pickup, dropoff, rider }

extension ListFirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : this[0];
}
