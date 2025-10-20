import 'dart:math';

import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

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

  final MapController _mapController = MapController();
  final Map<String, Future<_DeliveryDetails?>> _deliveryCache = {};
  final Map<String, Future<_UserProfile?>> _userCache = {};
  final Map<String, Future<_RiderProfile?>> _riderCache = {};
  final Map<String, Future<String?>> _addressCache = {};

  bool _isMapReady = false;
  String? _pendingFocusDeliveryId;
  String? _focusedDeliveryId;
  String? _lastCameraSignature;

  @override
  void initState() {
    super.initState();
    _pendingFocusDeliveryId = widget.deliveryId;
    _focusedDeliveryId = widget.deliveryId;
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
            stream: _trackedDeliveriesStream(),
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

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (_isMapReady) {
                  _updateCamera(deliveries);
                }
                if (_pendingFocusDeliveryId != null) {
                  final target = _findDeliveryById(
                    deliveries,
                    _pendingFocusDeliveryId!,
                  );
                  if (target != null) {
                    _focusDeliveryOnMap(target, updateState: false);
                    _pendingFocusDeliveryId = null;
                    setState(() {});
                  }
                }
              });

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(deliveries),
                  const SizedBox(height: 16),
                  Expanded(child: _buildMap(deliveries)),
                  const SizedBox(height: 16),
                  _buildDeliveryList(deliveries),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Stream<List<_TrackedDelivery>> _trackedDeliveriesStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Stream<List<_TrackedDelivery>>.value(const []);
    }

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('delivery_tracking')
        .where('sender_uid', isEqualTo: currentUser.uid);

    if (widget.deliveryId != null) {
      query = query.where('did', isEqualTo: widget.deliveryId);
    }

    return query.snapshots().asyncMap((snapshot) async {
      final futures = snapshot.docs.map(_buildTrackedDelivery).toList();
      final results = await Future.wait(futures);
      final filtered =
          results.whereType<_TrackedDelivery>().toList(growable: false);
      filtered.sort(
        (a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return filtered;
    });
  }

  Future<_TrackedDelivery?> _buildTrackedDelivery(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final did = (data['did'] as String?) ?? doc.id;
    final position = _parsePosition(data);
    if (position == null) {
      return null;
    }

    final statusCode = _parseStatusCode(data['status_code']);
    final details = await _fetchDeliveryDetails(did);

    final itemNameRaw = (data['item_name'] as String?)?.trim();
    final itemName = (itemNameRaw != null && itemNameRaw.isNotEmpty)
        ? itemNameRaw
        : details?.itemName ?? widget.itemName ?? 'รายการจัดส่ง';

    final riderProfile = await _fetchRiderProfile(
      (data['rider_uid'] as String?) ?? details?.riderUid,
    );

    final senderProfile = await _fetchUserProfile(
      (data['sender_uid'] as String?) ?? details?.senderUid,
    );

    final receiverProfile = await _fetchUserProfile(
      (data['receiver_uid'] as String?) ?? details?.receiverUid,
    );

    final pickupAddress = await _resolveAddress(
      details?.pickupAddressId ?? data['pickup_addr_id'] as String?,
    );
    final dropoffAddress = await _resolveAddress(
      details?.dropoffAddressId ?? data['dropoff_addr_id'] as String?,
    );

    final updatedAt = (data['updated_at'] as Timestamp?)?.toDate() ??
        details?.updatedAt ??
        (data['last_updated'] as Timestamp?)?.toDate();

    return _TrackedDelivery(
      did: did,
      itemName: itemName,
      position: position,
      statusCode: statusCode,
      statusLabel: _statusLabels[statusCode] ?? 'สถานะไม่ทราบ',
      updatedAt: updatedAt,
      riderProfile: riderProfile,
      senderProfile: senderProfile,
      receiverProfile: receiverProfile,
      pickupAddress: pickupAddress ?? details?.pickupAddress,
      dropoffAddress: dropoffAddress ?? details?.dropoffAddress,
    );
  }

  Widget _buildHeader(List<_TrackedDelivery> deliveries) {
    final isSingle = widget.deliveryId != null;
    final title = isSingle
        ? (widget.itemName ?? deliveries.firstOrNull?.itemName ?? 'Delivery')
        : 'Delivery Tracking';
    final subtitle = isSingle
        ? (deliveries.firstOrNull?.statusLabel ?? 'กำลังตรวจสอบสถานะ')
        : 'คุณมีไรเดอร์ ${deliveries.length} คนกำลังจัดส่ง';
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
                style: GoogleFonts.poppins(
                  color: Colors.white60,
                  fontSize: 13,
                ),
              ),
            ),
            if (latest != null)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0x3316A34A),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  Widget _buildMap(List<_TrackedDelivery> deliveries) {
    final defaultCenter = deliveries.firstOrNull?.position ??
        const LatLng(13.736717, 100.523186);

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
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: defaultCenter,
                initialZoom: 13,
                backgroundColor: _background,
                onMapReady: () {
                  if (mounted) {
                    setState(() => _isMapReady = true);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.delivery.app',
                ),
                MarkerLayer(
                  markers: deliveries
                      .map((delivery) => _buildMarker(delivery))
                      .toList(),
                ),
              ],
            ),
            if (deliveries.isEmpty)
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'ยังไม่มีข้อมูลตำแหน่งแบบเรียลไทม์',
                    style: GoogleFonts.poppins(color: Colors.white70),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Marker _buildMarker(_TrackedDelivery delivery) {
    final isSelected = delivery.did == _focusedDeliveryId;
    final color =
        isSelected ? _green : const Color.fromARGB(220, 31, 41, 55);

    return Marker(
      point: delivery.position,
      width: 140,
      height: 120,
      builder: (context) => GestureDetector(
        onTap: () => _onFocusRequest(delivery),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              constraints: const BoxConstraints(maxWidth: 120),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                delivery.riderProfile?.username ?? delivery.itemName,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: Icon(
                BootstrapIcons.geo_alt_fill,
                color: Colors.white,
                size: isSelected ? 24 : 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryList(List<_TrackedDelivery> deliveries) {
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
            const Icon(
              BootstrapIcons.truck,
              color: Colors.white54,
              size: 40,
            ),
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
      height: 240,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        itemCount: deliveries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _buildDeliveryInfoCard(deliveries[index]),
      ),
    );
  }

  Widget _buildDeliveryInfoCard(_TrackedDelivery delivery) {
    final isSelected = delivery.did == _focusedDeliveryId;
    final statusColor = _statusColor(delivery.statusCode);

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              color: _white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          _buildLocationRow(
            title: 'ผู้ส่ง',
            name: delivery.senderProfile?.username,
            address: delivery.pickupAddress,
            icon: BootstrapIcons.box,
          ),
          const SizedBox(height: 10),
          _buildLocationRow(
            title: 'ผู้รับ',
            name: delivery.receiverProfile?.username,
            address: delivery.dropoffAddress,
            icon: BootstrapIcons.house,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white10,
                backgroundImage: delivery.riderProfile?.avatarUrl != null &&
                        delivery.riderProfile!.avatarUrl!.startsWith('http')
                    ? NetworkImage(delivery.riderProfile!.avatarUrl!)
                    : null,
                child: (delivery.riderProfile?.avatarUrl == null ||
                        delivery.riderProfile!.avatarUrl!.isEmpty ||
                        !delivery.riderProfile!.avatarUrl!.startsWith('http'))
                    ? const Icon(
                        BootstrapIcons.person_fill,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivery.riderProfile?.username ?? 'รอจัดสรรไรเดอร์',
                      style: GoogleFonts.poppins(
                        color: _white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if ((delivery.riderProfile?.vehiclePlate ?? '').isNotEmpty)
                      Text(
                        'ทะเบียน: ${delivery.riderProfile!.vehiclePlate}',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    if (delivery.updatedAt != null)
                      Text(
                        'อัปเดตล่าสุด ${_formatRelativeTime(delivery.updatedAt!)}',
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _onFocusRequest(delivery),
                icon: const Icon(
                  BootstrapIcons.geo_alt,
                  color: Colors.white,
                  size: 16,
                ),
                label: FittedBox(
                  child: Text(
                    'Delivery Tracking',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required String title,
    required IconData icon,
    String? name,
    String? address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0x2216A34A),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: _green,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (name != null && name.isNotEmpty)
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (address != null && address.isNotEmpty)
                Text(
                  address,
                  style: GoogleFonts.poppins(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _onFocusRequest(_TrackedDelivery delivery) {
    _focusDeliveryOnMap(delivery);
  }

  void _focusDeliveryOnMap(_TrackedDelivery delivery,
      {bool updateState = true, double zoom = 16}) {
    if (updateState) {
      setState(() {
        _focusedDeliveryId = delivery.did;
      });
    } else {
      _focusedDeliveryId = delivery.did;
    }

    if (_isMapReady) {
      _mapController.move(delivery.position, zoom);
    } else {
      _pendingFocusDeliveryId = delivery.did;
    }
  }

  void _updateCamera(List<_TrackedDelivery> deliveries) {
    if (deliveries.isEmpty) {
      return;
    }

    final signature = deliveries
        .map((d) =>
            '${d.did}:${d.position.latitude.toStringAsFixed(6)},${d.position.longitude.toStringAsFixed(6)}')
        .join('|');

    if (signature == _lastCameraSignature) {
      return;
    }

    _lastCameraSignature = signature;

    if (deliveries.length == 1) {
      _focusDeliveryOnMap(deliveries.first);
      return;
    }

    final bounds = LatLngBounds.fromPoints(
      deliveries.map((d) => d.position).toList(growable: false),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(100),
      ),
    );
  }

  Future<_DeliveryDetails?> _fetchDeliveryDetails(String? deliveryId) {
    if (deliveryId == null || deliveryId.isEmpty) {
      return Future.value(null);
    }

    return _deliveryCache.putIfAbsent(deliveryId, () async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('delivery')
            .doc(deliveryId)
            .get();
        if (!doc.exists) {
          return null;
        }
        final data = doc.data();
        if (data == null) {
          return null;
        }
        return _DeliveryDetails(
          did: deliveryId,
          itemName: (data['item_name'] as String?) ?? 'รายการจัดส่ง',
          senderUid: data['sender_uid'] as String?,
          receiverUid: data['receiver_uid'] as String?,
          pickupAddressId: data['pickup_addr_id'] as String?,
          dropoffAddressId: data['dropoff_addr_id'] as String?,
          pickupAddress: data['pickup_address'] as String?,
          dropoffAddress: data['dropoff_address'] as String?,
          riderUid:
              data['rider_uid'] as String? ?? data['assigned_rider_uid'] as String?,
          statusCode: _parseStatusCode(data['status_code']),
          updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ??
              (data['status_updated_at'] as Timestamp?)?.toDate(),
        );
      } catch (_) {
        return null;
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

  Future<String?> _resolveAddress(String? addressId) {
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
        return (data['fullAddress'] as String?) ??
            (data['label'] as String?) ??
            (data['addressName'] as String?);
      } catch (_) {
        return null;
      }
    });
  }

  LatLng? _parsePosition(Map<String, dynamic> data) {
    final dynamic locationField = data['location'] ?? data['current_location'];
    if (locationField is GeoPoint) {
      return LatLng(locationField.latitude, locationField.longitude);
    }
    if (locationField is Map<String, dynamic>) {
      final lat = _tryParseDouble(
          locationField['lat'] ?? locationField['latitude']);
      final lng = _tryParseDouble(
          locationField['lng'] ?? locationField['longitude']);
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }

    final lat = _tryParseDouble(
      data['lat'] ?? data['latitude'] ?? data['latlng']?['lat'],
    );
    final lng = _tryParseDouble(
      data['lng'] ?? data['longitude'] ?? data['latlng']?['lng'],
    );

    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }

    final geo = data['geo'];
    if (geo is GeoPoint) {
      return LatLng(geo.latitude, geo.longitude);
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
  _TrackedDelivery({
    required this.did,
    required this.itemName,
    required this.position,
    required this.statusCode,
    required this.statusLabel,
    this.updatedAt,
    this.riderProfile,
    this.senderProfile,
    this.receiverProfile,
    this.pickupAddress,
    this.dropoffAddress,
  });

  final String did;
  final String itemName;
  final LatLng position;
  final int statusCode;
  final String statusLabel;
  final DateTime? updatedAt;
  final _RiderProfile? riderProfile;
  final _UserProfile? senderProfile;
  final _UserProfile? receiverProfile;
  final String? pickupAddress;
  final String? dropoffAddress;
}

class _DeliveryDetails {
  _DeliveryDetails({
    required this.did,
    required this.itemName,
    required this.senderUid,
    required this.receiverUid,
    required this.pickupAddressId,
    required this.dropoffAddressId,
    this.pickupAddress,
    this.dropoffAddress,
    this.riderUid,
    required this.statusCode,
    this.updatedAt,
  });

  final String did;
  final String itemName;
  final String? senderUid;
  final String? receiverUid;
  final String? pickupAddressId;
  final String? dropoffAddressId;
  final String? pickupAddress;
  final String? dropoffAddress;
  final String? riderUid;
  final int statusCode;
  final DateTime? updatedAt;
}

class _UserProfile {
  _UserProfile({required this.uid, required this.username});

  final String uid;
  final String username;
}

class _RiderProfile {
  _RiderProfile({
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

extension ListFirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : this[0];
}
