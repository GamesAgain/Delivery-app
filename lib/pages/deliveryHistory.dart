import 'dart:async';

import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/models/address.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';

class DeliveryHistoryPageArgs {
  const DeliveryHistoryPageArgs({this.itemName, this.statusLabel});

  final String? itemName;
  final String? statusLabel;
}

class DeliveryHistoryPage extends StatefulWidget {
  const DeliveryHistoryPage({
    super.key,
    required this.deliveryId,
    this.initialItemName,
    this.initialStatusLabel,
  });

  final String deliveryId;
  final String? initialItemName;
  final String? initialStatusLabel;

  @override
  State<DeliveryHistoryPage> createState() => _DeliveryHistoryPageState();
}

class _DeliveryHistoryPageState extends State<DeliveryHistoryPage> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _deliverySubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _historySubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _assignmentSubscription;

  final Map<String, Future<_UserProfile?>> _userCache = {};
  final Map<String, Future<_RiderProfile?>> _riderCache = {};
  final Map<String, Future<Address?>> _addressCache = {};

  _DeliveryDetail? _deliveryDetail;
  List<_DeliveryStatusStep> _historySteps = const [];
  _AssignmentInfo? _assignmentInfo;

  bool _isLoading = true;
  String? _errorMessage;
  int _currentStatusCode = 0;
  String? _statusLabel;
  String? _itemNameFallback;

  static const List<int> _statusOrder = [1, 2, 3, 4];

  @override
  void initState() {
    super.initState();
    _itemNameFallback = _normalizeText(widget.initialItemName);
    _statusLabel = _normalizeText(widget.initialStatusLabel);
    _subscribeToStreams();
  }

  @override
  void dispose() {
    _deliverySubscription?.cancel();
    _historySubscription?.cancel();
    _assignmentSubscription?.cancel();
    _sheetController.dispose();
    super.dispose();
  }

  void _subscribeToStreams() {
    final did = widget.deliveryId;

    _deliverySubscription = FirebaseFirestore.instance
        .collection('delivery')
        .doc(did)
        .snapshots()
        .listen(
      _onDeliverySnapshot,
      onError: (error, stackTrace) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'ไม่สามารถโหลดข้อมูลการจัดส่งได้';
          _isLoading = false;
        });
      },
    );

    _historySubscription = FirebaseFirestore.instance
        .collection('delivery_status_history')
        .where('did', isEqualTo: did)
        .orderBy('created_at')
        .snapshots()
        .listen(
      _onHistorySnapshot,
      onError: (error, stackTrace) {
        // Keep previous history if loading fails.
      },
    );

    _assignmentSubscription = FirebaseFirestore.instance
        .collection('assignment')
        .where('did', isEqualTo: did)
        .limit(1)
        .snapshots()
        .listen(
      _onAssignmentSnapshot,
      onError: (error, stackTrace) {
        if (!mounted) return;
        setState(() => _assignmentInfo = null);
      },
    );
  }

  Future<void> _onDeliverySnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) async {
    if (!snapshot.exists) {
      if (!mounted) return;
      setState(() {
        _deliveryDetail = null;
        _isLoading = false;
        _errorMessage = 'ไม่พบข้อมูลการจัดส่ง';
      });
      return;
    }

    final data = snapshot.data();
    if (data == null) {
      if (!mounted) return;
      setState(() {
        _deliveryDetail = null;
        _isLoading = false;
        _errorMessage = 'ข้อมูลการจัดส่งไม่ถูกต้อง';
      });
      return;
    }

    try {
      final detail = await _buildDeliveryDetail(snapshot);
      if (!mounted) return;
      setState(() {
        _deliveryDetail = detail;
        _currentStatusCode = detail.statusCode;
        _statusLabel = detail.statusLabel ?? _statusLabel;
        _itemNameFallback ??= detail.itemName;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'เกิดข้อผิดพลาดระหว่างโหลดข้อมูลการจัดส่ง';
      });
    }
  }

  void _onHistorySnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final steps = snapshot.docs.map(_mapHistoryDocToStep).toList(growable: false);
    final highestHistoryStatus = steps.isEmpty
        ? 0
        : steps.map((step) => step.code).reduce((a, b) => a > b ? a : b);

    if (!mounted) return;
    setState(() {
      _historySteps = steps;
      if (_deliveryDetail != null) {
        _currentStatusCode = _deliveryDetail!.statusCode;
      } else if (highestHistoryStatus > 0) {
        _currentStatusCode = highestHistoryStatus;
      }
    });
  }

  Future<void> _onAssignmentSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    if (snapshot.docs.isEmpty) {
      if (!mounted) return;
      setState(() => _assignmentInfo = null);
      return;
    }

    final doc = snapshot.docs.first;
    final data = doc.data();
    final riderUid =
        _normalizeText(data['rid']) ?? _normalizeText(data['rider_uid']);
    final assignedAt = _toDate(
          data['assigned_at'] as Timestamp?,
        ) ??
        _toDate(data['created_at'] as Timestamp?);

    final rider = await _fetchRiderProfile(riderUid);
    if (!mounted) return;
    setState(() {
      _assignmentInfo = _AssignmentInfo(rider: rider, assignedAt: assignedAt);
    });
  }

  Future<_DeliveryDetail> _buildDeliveryDetail(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final data = snapshot.data()!;
    final did = _normalizeText(data['did']) ?? snapshot.id;
    final itemName =
        _normalizeText(data['item_name']) ?? _itemNameFallback ?? 'รายการจัดส่ง';
    final statusCode = _parseStatusCode(data['status_code']);
    final statusLabel =
        _normalizeText(data['status']) ?? _normalizeText(data['status_label']);
    final createdAt = _toDate(data['created_at'] as Timestamp?);
    final updatedAt =
        _toDate(data['updated_at'] as Timestamp?) ??
        _toDate(data['status_updated_at'] as Timestamp?);
    final note = _normalizeText(data['note']);
    final itemImageUrl = _normalizeText(data['item_image']);

    final sender =
        await _fetchUserProfile(_normalizeText(data['sender_uid']));
    final receiver =
        await _fetchUserProfile(_normalizeText(data['receiver_uid']));

    final pickupAddressId = _normalizeText(data['pickup_addr_id']) ??
        _normalizeText(data['pickup_address_id']) ??
        _normalizeText(data['pickupAddressId']);
    final dropoffAddressId = _normalizeText(data['dropoff_addr_id']) ??
        _normalizeText(data['dropoff_address_id']) ??
        _normalizeText(data['dropoffAddressId']);

    final pickupAddress = await _fetchAddress(pickupAddressId);
    final dropoffAddress = await _fetchAddress(dropoffAddressId);

    final riderUid =
        _normalizeText(data['rider_uid']) ?? _normalizeText(data['assigned_rider_uid']);

    return _DeliveryDetail(
      did: did,
      itemName: itemName,
      statusCode: statusCode,
      statusLabel: statusLabel,
      createdAt: createdAt,
      updatedAt: updatedAt,
      note: note,
      itemImageUrl: itemImageUrl,
      sender: sender,
      receiver: receiver,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      riderUid: riderUid,
    );
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
        final displayName = _normalizeText(data['username']) ??
            _normalizeText(data['display_name']) ??
            'ผู้ใช้งาน';
        return _UserProfile(uid: uid, displayName: displayName);
      } catch (_) {
        return null;
      }
    });
  }

  Future<Address?> _fetchAddress(String? addressId) {
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
        return Address.fromFirestore(doc);
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
        final riderDoc = await FirebaseFirestore.instance
            .collection('riders')
            .doc(uid)
            .get();
        Map<String, dynamic>? data = riderDoc.data();
        if (data == null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          if (!userDoc.exists) {
            return null;
          }
          data = userDoc.data();
        }
        if (data == null) {
          return null;
        }
        return _RiderProfile(
          uid: uid,
          displayName: _normalizeText(data['username']) ??
              _normalizeText(data['display_name']) ??
              'ไรเดอร์',
          avatarUrl:
              _normalizeText(data['avatar']) ?? _normalizeText(data['profile_image']),
          vehiclePlate: _normalizeText(data['vehicle_plate']) ??
              _normalizeText(data['plate']),
        );
      } catch (_) {
        return null;
      }
    });
  }

  _DeliveryStatusStep _mapHistoryDocToStep(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final statusCode = _parseStatusCode(data['status_code']);
    final timestamp = _toDate(data['created_at'] as Timestamp?);
    final label = _normalizeText(
      data['status_label'] ?? data['status'] ?? data['headline'],
    );
    final detail = _normalizeText(data['detail'] ?? data['note']);
    final imageUrl = _normalizeText(data['image'] ?? data['image_url']);

    final definition = _statusDefinitions[statusCode];

    return _DeliveryStatusStep(
      code: statusCode,
      timestamp: timestamp,
      headline: label ?? definition?.title ?? 'สถานะที่ $statusCode',
      detail: detail ?? definition?.description,
      imageUrl: imageUrl,
    );
  }

  int _parseStatusCode(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) {
      return int.tryParse(raw) ?? 0;
    }
    return 0;
  }

  DateTime? _toDate(Timestamp? timestamp) => timestamp?.toDate().toLocal();

  String? _normalizeText(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return trimmed;
    }
    return null;
  }

  LatLng? _addressToLatLng(Address? address) {
    final lat = address?.lat;
    final lng = address?.lng;
    if (lat == null || lng == null) {
      return null;
    }
    return LatLng(lat, lng);
  }

  String _composeAddressLine(_UserProfile? profile, Address? address) {
    final addressText =
        _normalizeText(address?.label) ?? _normalizeText(address?.fullAddress);
    if (profile != null && profile.displayName.isNotEmpty) {
      if (addressText != null && addressText.isNotEmpty) {
        return '${profile.displayName} • $addressText';
      }
      return profile.displayName;
    }
    return addressText ?? 'ไม่พบที่อยู่';
  }

  String _statusLabelForCode(int code, String? fallback) {
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }
    final definition = _statusDefinitions[code];
    return definition?.title ?? 'สถานะที่ $code';
  }

  String _formatFullDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final month = _thaiShortMonths[local.month - 1];
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} $month ${local.year} • $hour:$minute น.';
  }

  AppBar _buildAppBar(TextTheme textTheme) {
    return AppBar(
      backgroundColor: AppColors.bg,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: AppColors.onBg),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(
        'ประวัติการจัดส่ง',
        style: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.onBg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading && _deliveryDetail == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: _buildAppBar(textTheme),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: _buildAppBar(textTheme),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    final detail = _deliveryDetail;
    if (detail == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: _buildAppBar(textTheme),
        body: const Center(
          child: Text(
            'ไม่พบข้อมูลการจัดส่ง',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(textTheme),
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildMapCard(textTheme, detail),
                ),
              ],
            ),
          ),
          _buildBottomSheet(textTheme, detail),
        ],
      ),
    );
  }

  Widget _buildMapCard(TextTheme textTheme, _DeliveryDetail detail) {
    final pickupLatLng = _addressToLatLng(detail.pickupAddress);
    final dropoffLatLng = _addressToLatLng(detail.dropoffAddress);

    final routePoints = <LatLng>[
      if (pickupLatLng != null) pickupLatLng,
      if (dropoffLatLng != null) dropoffLatLng,
    ];

    final hasRoute = routePoints.length >= 2;
    final hasAnyPoint = routePoints.isNotEmpty;
    final fallbackCenter =
        pickupLatLng ?? dropoffLatLng ?? const LatLng(13.7563, 100.5018);

    final initialCenter = hasRoute
        ? LatLng(
            (routePoints[0].latitude + routePoints[1].latitude) / 2,
            (routePoints[0].longitude + routePoints[1].longitude) / 2,
          )
        : fallbackCenter;
    final initialZoom = hasRoute ? 12.8 : 14.4;

    final markers = <Marker>[
      if (pickupLatLng != null)
        Marker(
          point: pickupLatLng,
          width: 52,
          height: 52,
          alignment: Alignment.topCenter,
          child: _buildMapMarker('A', AppColors.primary),
        ),
      if (dropoffLatLng != null)
        Marker(
          point: dropoffLatLng,
          width: 52,
          height: 52,
          alignment: Alignment.topCenter,
          child: _buildMapMarker('B', const Color(0xFFE11D48)),
        ),
    ];

    final senderLine = _composeAddressLine(detail.sender, detail.pickupAddress);
    final receiverLine =
        _composeAddressLine(detail.receiver, detail.dropoffAddress);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 340,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: initialZoom,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.pinchMove |
                      InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.delivery.app',
                ),
                if (hasRoute)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        strokeWidth: 6,
                        color: AppColors.primary.withOpacity(0.85),
                        borderStrokeWidth: 9,
                        borderColor: Colors.white.withOpacity(0.3),
                      ),
                    ],
                  ),
                if (markers.isNotEmpty) MarkerLayer(markers: markers),
              ],
            ),
            if (!hasAnyPoint)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.black26,
                    alignment: Alignment.center,
                    child: Text(
                      'ไม่พบข้อมูลพิกัดสำหรับการจัดส่งนี้',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 18,
              right: 18,
              top: 18,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.itemName,
                      style: textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    _MapInfoRow(
                      icon: BootstrapIcons.geo_alt_fill,
                      color: AppColors.primary,
                      label: 'ต้นทาง',
                      value: senderLine,
                    ),
                    const SizedBox(height: 10),
                    _MapInfoRow(
                      icon: BootstrapIcons.pin_map_fill,
                      color: const Color(0xFFE11D48),
                      label: 'ปลายทาง',
                      value: receiverLine,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapMarker(String label, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              width: 4,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheet(TextTheme textTheme, _DeliveryDetail detail) {
    final steps = _historySteps;
    final firstStep = steps.isNotEmpty ? steps.first : null;
    final dispatchTime = firstStep?.timestamp ?? detail.createdAt;
    final dispatchLabel = dispatchTime != null
        ? _formatFullDateTime(dispatchTime)
        : 'ไม่พบข้อมูลเวลาเริ่ม';
    final statusChipLabel =
        _statusLabelForCode(_currentStatusCode, detail.statusLabel ?? _statusLabel);

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.35,
      minChildSize: 0.3,
      maxChildSize: 0.88,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bgsecondary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 24,
                offset: Offset(0, -12),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 52,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'จัดส่งเมื่อ',
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dispatchLabel,
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.onBg,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.primary),
                                ),
                                child: Text(
                                  statusChipLabel,
                                  style: textTheme.titleSmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Divider(
                            color: Colors.white.withOpacity(0.12),
                            thickness: 1,
                          ),
                          const SizedBox(height: 18),
                          _buildRiderSection(textTheme, _assignmentInfo),
                          const SizedBox(height: 24),
                          Text(
                            'สถานะการจัดส่ง',
                            style: textTheme.titleSmall?.copyWith(
                              color: AppColors.onBg,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildProgressIndicators(
                            _currentStatusCode,
                            true,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'ประวัติการจัดส่ง',
                            style: textTheme.titleMedium?.copyWith(
                              color: AppColors.onBg,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (steps.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        'ยังไม่มีประวัติการอัปเดตสถานะสำหรับการจัดส่งนี้',
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 40),
                  sliver: SliverList.separated(
                    itemCount: steps.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final step = steps[index];
                      final isLast = index == steps.length - 1;
                      final isFirst = index == 0;
                      final isCompleted = _currentStatusCode >= step.code;
                      return Padding(
                        padding: EdgeInsets.only(
                          left: 24,
                          right: 24,
                          bottom: isLast ? 24 : 0,
                        ),
                        child: _TimelineEntry(
                          step: step,
                          isCompleted: isCompleted,
                          isFirst: isFirst,
                          isLast: isLast,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRiderSection(
    TextTheme textTheme,
    _AssignmentInfo? assignment,
  ) {
    final rider = assignment?.rider;
    if (rider != null) {
      final vehiclePlate = rider.vehiclePlate;
      final subtitle = vehiclePlate != null && vehiclePlate.isNotEmpty
          ? 'ทะเบียนรถ: $vehiclePlate'
          : 'ไรเดอร์มืออาชีพ พร้อมให้บริการคุณ';

      final ImageProvider avatarProvider = rider.avatarUrl != null &&
              rider.avatarUrl!.isNotEmpty
          ? NetworkImage(rider.avatarUrl!)
          : const AssetImage('assets/images/rider_avatar.png');

      return Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: avatarProvider,
            backgroundColor: Colors.white12,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ชื่อไรเดอร์ : ${rider.displayName}',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onBg,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(
            BootstrapIcons.person_exclamation,
            color: Colors.white54,
            size: 26,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'ยังไม่มีไรเดอร์รับงาน',
              style: textTheme.titleSmall?.copyWith(
                color: AppColors.onBg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicators(int statusCode, bool isDarkCard) {
    final children = <Widget>[];

    for (var i = 0; i < _statusOrder.length; i++) {
      final code = _statusOrder[i];
      final isActive = statusCode >= code;
      children.add(
        _buildStatusStep(
          statusCode: code,
          isActive: isActive,
          isDarkCard: isDarkCard,
        ),
      );

      if (i < _statusOrder.length - 1) {
        final connectorActive = statusCode > code;
        children.add(_buildConnector(connectorActive, isDarkCard));
      }
    }

    return Row(children: children);
  }

  Widget _buildStatusStep({
    required int statusCode,
    required bool isActive,
    required bool isDarkCard,
  }) {
    final backgroundColor = isActive
        ? AppColors.primary
        : (isDarkCard ? Colors.white24 : const Color(0xFFE2E8F0));
    final inactiveIconColor =
        isDarkCard ? Colors.white70 : const Color(0xFF64748B);

    Widget icon;
    switch (statusCode) {
      case 1:
        icon = Icon(
          BootstrapIcons.box_seam,
          size: 14,
          color: isActive ? Colors.white : inactiveIconColor,
        );
        break;
      case 2:
      case 3:
        icon = Icon(
          Icons.pedal_bike,
          size: 14,
          color: isActive ? Colors.white : inactiveIconColor,
        );
        break;
      default:
        icon = SvgPicture.asset(
          'assets/icons/packageCorrect.svg',
          width: 14,
          height: 14,
          colorFilter: isActive
              ? null
              : ColorFilter.mode(inactiveIconColor, BlendMode.srcIn),
        );
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: backgroundColor,
        child: icon,
      ),
    );
  }

  Widget _buildConnector(bool isActive, bool isDarkCard) {
    final color = isActive
        ? AppColors.primary
        : (isDarkCard ? Colors.white24 : const Color(0xFFCBD5F5));
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(100),
        ),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.step,
    required this.isCompleted,
    required this.isFirst,
    required this.isLast,
  });

  final _DeliveryStatusStep step;
  final bool isCompleted;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lineColor = isCompleted ? AppColors.primary : Colors.white24;
    final indicatorColor = isCompleted ? AppColors.primary : Colors.white24;
    final hasImage = step.imageUrl != null && step.imageUrl!.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDateLabel(step.timestamp),
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatTimeLabel(step.timestamp),
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.onBg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          children: [
            if (!isFirst)
              _DashedLine(
                height: 28,
                color: lineColor,
              ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: indicatorColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            if (!isLast)
              _DashedLine(
                height: hasImage ? 158 : 96,
                color: lineColor,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.headline,
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.onBg,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (step.detail != null && step.detail!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  step.detail!,
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ],
              if (hasImage) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _TimelineImage(url: step.imageUrl!),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineImage extends StatelessWidget {
  const _TimelineImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      height: 132,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        final expected = loadingProgress.expectedTotalBytes;
        final loaded = loadingProgress.cumulativeBytesLoaded;
        return SizedBox(
          height: 132,
          child: Center(
            child: CircularProgressIndicator(
              value: expected != null ? loaded / expected : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 132,
          color: Colors.white10,
          alignment: Alignment.center,
          child: const Icon(
            BootstrapIcons.image,
            color: Colors.white54,
            size: 30,
          ),
        );
      },
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({
    required this.height,
    required this.color,
    this.dashLength = 6,
    this.gap = 4,
  });

  final double height;
  final Color color;
  final double dashLength;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: 2,
      child: CustomPaint(
        painter: _DashedLinePainter(
          color: color,
          dashLength: dashLength,
          gap: gap,
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({
    required this.color,
    required this.dashLength,
    required this.gap,
  });

  final Color color;
  final double dashLength;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width
      ..strokeCap = StrokeCap.round;

    double y = 0;
    while (y < size.height) {
      final endY = (y + dashLength).clamp(0.0, size.height);
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, endY),
        paint,
      );
      y += dashLength + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gap != gap;
  }
}

class _DeliveryStatusStep {
  const _DeliveryStatusStep({
    required this.code,
    required this.timestamp,
    required this.headline,
    this.detail,
    this.imageUrl,
  });

  final int code;
  final DateTime? timestamp;
  final String headline;
  final String? detail;
  final String? imageUrl;
}

class _DeliveryDetail {
  _DeliveryDetail({
    required this.did,
    required this.itemName,
    required this.statusCode,
    this.statusLabel,
    this.createdAt,
    this.updatedAt,
    this.note,
    this.itemImageUrl,
    this.sender,
    this.receiver,
    this.pickupAddress,
    this.dropoffAddress,
    this.riderUid,
  });

  final String did;
  final String itemName;
  final int statusCode;
  final String? statusLabel;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? note;
  final String? itemImageUrl;
  final _UserProfile? sender;
  final _UserProfile? receiver;
  final Address? pickupAddress;
  final Address? dropoffAddress;
  final String? riderUid;
}

class _AssignmentInfo {
  _AssignmentInfo({this.rider, this.assignedAt});

  final _RiderProfile? rider;
  final DateTime? assignedAt;
}

class _UserProfile {
  _UserProfile({required this.uid, required this.displayName});

  final String uid;
  final String displayName;
}

class _RiderProfile {
  _RiderProfile({
    required this.uid,
    required this.displayName,
    this.avatarUrl,
    this.vehiclePlate,
  });

  final String uid;
  final String displayName;
  final String? avatarUrl;
  final String? vehiclePlate;
}

class _StatusDefinition {
  const _StatusDefinition({required this.title, this.description});

  final String title;
  final String? description;
}

const Map<int, _StatusDefinition> _statusDefinitions = {
  1: _StatusDefinition(
    title: 'กำลังรอไรเดอร์มารับ',
    description: 'ร้านค้ายืนยันคำสั่งซื้อ กำลังรอไรเดอร์มารับสินค้า',
  ),
  2: _StatusDefinition(
    title: 'ไรเดอร์รับงาน',
    description: 'ไรเดอร์กำลังเดินทางไปรับสินค้า',
  ),
  3: _StatusDefinition(
    title: 'ไรเดอร์รับสินค้าแล้วและกำลังเดินทางไปส่ง',
    description: 'ไรเดอร์ออกเดินทางจากร้านและกำลังมุ่งหน้าไปยังปลายทาง',
  ),
  4: _StatusDefinition(
    title: 'ไรเดอร์นำส่งสินค้าแล้ว',
    description: 'ผู้รับได้รับสินค้าเรียบร้อย ขอบคุณที่ใช้บริการ',
  ),
};

const List<String> _thaiShortMonths = [
  'ม.ค.',
  'ก.พ.',
  'มี.ค.',
  'เม.ย.',
  'พ.ค.',
  'มิ.ย.',
  'ก.ค.',
  'ส.ค.',
  'ก.ย.',
  'ต.ค.',
  'พ.ย.',
  'ธ.ค.',
];

String _formatDateLabel(DateTime? dateTime) {
  if (dateTime == null) {
    return '-';
  }
  final local = dateTime.toLocal();
  final month = _thaiShortMonths[local.month - 1];
  return '${local.day} $month';
}

String _formatTimeLabel(DateTime? dateTime) {
  if (dateTime == null) {
    return '--:--';
  }
  final local = dateTime.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute$period';
}

class _MapInfoRow extends StatelessWidget {
  const _MapInfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
