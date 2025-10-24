import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

class AssignDetailPage extends StatefulWidget {
  final String did;
  const AssignDetailPage({super.key, required this.did});

  @override
  State<AssignDetailPage> createState() => _AssignDetailPageState();
}

class _AssignDetailPageState extends State<AssignDetailPage> {
  bool _isLoading = false;
  Future<_DeliveryGeoData>? _geoFuture;
  String? _geoFutureKey;

  Stream<Delivery?> watchDeliveryByDid(String did) {
    return FirebaseFirestore.instance
        .collection('delivery')
        .doc(did)
        .snapshots()
        .map(
          (s) => (s.exists && s.data() != null) ? Delivery.fromSnap(s) : null,
        );
  }

  Future<UserAddress?> fetchAddressById(String addrId) async {
    final snap = await FirebaseFirestore.instance
        .collection('addresses')
        .doc(addrId)
        .get();

    if (!snap.exists || snap.data() == null) return null;
    return UserAddress.fromSnap(snap);
  }

  Future<_DeliveryGeoData> _fetchGeoData({
    required String pickupAddrId,
    required String dropoffAddrId,
  }) async {
    final riderId = FirebaseAuth.instance.currentUser?.uid;
    if (riderId == null) {
      throw Exception('Rider not logged in.');
    }

    final db = FirebaseFirestore.instance;

    final results = await Future.wait([
      db.collection('RiderLocation').doc(riderId).get(),
      db.collection('addresses').doc(pickupAddrId).get(),
    ]);

    final riderLocSnap = results[0];
    final pickupSnap = results[1];
    DocumentSnapshot<Map<String, dynamic>>? dropoffSnap;
    if (dropoffAddrId.isNotEmpty) {
      dropoffSnap = await db.collection('addresses').doc(dropoffAddrId).get();
    }

    if (!riderLocSnap.exists || !pickupSnap.exists) {
      throw Exception('Could not find location data.');
    }

    final riderLat = (riderLocSnap.data()?['lat'] as num?)?.toDouble();
    final riderLng = (riderLocSnap.data()?['lng'] as num?)?.toDouble();
    final pickupLat = (pickupSnap.data()?['lat'] as num?)?.toDouble();
    final pickupLng = (pickupSnap.data()?['lng'] as num?)?.toDouble();
    final dropoffLat = (dropoffSnap?.data()?['lat'] as num?)?.toDouble();
    final dropoffLng = (dropoffSnap?.data()?['lng'] as num?)?.toDouble();

    if (riderLat == null ||
        riderLng == null ||
        pickupLat == null ||
        pickupLng == null) {
      throw Exception('ไม่สามารถคำนวณพิกัดได้');
    }

    final pickupPoint = LatLng(pickupLat, pickupLng);
    final dropoffPoint = (dropoffLat != null && dropoffLng != null)
        ? LatLng(dropoffLat, dropoffLng)
        : null;
    final riderPoint = LatLng(riderLat, riderLng);

    final distanceToPickup = Geolocator.distanceBetween(
      riderLat,
      riderLng,
      pickupLat,
      pickupLng,
    );

    final double? distanceToDropoff = (dropoffPoint != null)
        ? Geolocator.distanceBetween(
            riderLat,
            riderLng,
            dropoffPoint.latitude,
            dropoffPoint.longitude,
          )
        : null;

    final pickupAddress = (pickupSnap.data()?['fullAddress'] as String?)
        ?.trim();
    final dropoffAddress = (dropoffSnap?.data()?['fullAddress'] as String?)
        ?.trim();

    return _DeliveryGeoData(
      riderPoint: riderPoint,
      pickupPoint: pickupPoint,
      dropoffPoint: dropoffPoint,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      distanceToPickup: distanceToPickup,
      distanceToDropoff: distanceToDropoff,
    );
  }

  Future<_DeliveryGeoData> _ensureGeoFuture(Delivery delivery) {
    final shouldRefresh = _geoFuture == null || _geoFutureKey != delivery.did;
    if (shouldRefresh) {
      _geoFutureKey = delivery.did;
      _geoFuture = _fetchGeoData(
        pickupAddrId: delivery.pickupAddrId,
        dropoffAddrId: delivery.dropoffAddrId,
      );
    }
    return _geoFuture!;
  }

  Future<void> _confirmAcceptDelivery() async {
    if (_isLoading) return;

    final shouldAccept = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('ยืนยันการรับงาน'),
              content: const Text(
                'หากรับงานนี้แล้วจะไม่สามารถรับงานต่อไปจนกว่าจะจัดส่งสำเร็จ',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('ยืนยัน'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (shouldAccept && mounted) {
      await _handleAcceptDelivery();
    }
  }

  Future<void> _handleAcceptDelivery() async {
    if (_isLoading) return; // ป้องกันการกดซ้ำ

    setState(() {
      _isLoading = true;
    });

    final db = FirebaseFirestore.instance;
    final riderId = FirebaseAuth.instance.currentUser?.uid;
    final deliveryId = widget.did;

    if (riderId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เกิดข้อผิดพลาด: ไม่พบผู้ใช้งาน')),
        );
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      // --- 1. ดึง Delivery Doc เพื่อเอา pickup_addr_id ---
      final deliveryDoc = await db.collection('delivery').doc(deliveryId).get();
      if (!deliveryDoc.exists) throw Exception('ไม่พบงานนี้');
      final pickupAddrId = deliveryDoc.data()?['pickup_addr_id'] as String?;
      if (pickupAddrId == null) throw Exception('ไม่พบที่อยู่ผู้ส่ง');
      final deliveryDocId =
          deliveryDoc.data()?['did'] as String? ?? deliveryDoc.id;

      // --- 2. ตรวจสอบระยะ 20 เมตร ---
      final geoData = await _fetchGeoData(
        pickupAddrId: pickupAddrId,
        dropoffAddrId: deliveryDoc.data()?['dropoff_addr_id'] as String? ?? '',
      );

      final distanceToPickup = geoData.distanceToPickup;
      final distanceToDropoff = geoData.distanceToDropoff;

      if (distanceToPickup > 20) {
        throw Exception(
          'คุณต้องอยู่ใกล้จุดรับสินค้าไม่เกิน 20 เมตร (ปัจจุบัน ${distanceToPickup.toStringAsFixed(0)} ม.)',
        );
      }

      if (distanceToDropoff == null) {
        throw Exception('ไม่พบพิกัดจุดส่งสินค้า');
      }

      if (distanceToDropoff > 20) {
        throw Exception(
          'คุณต้องอยู่ใกล้จุดส่งสินค้าไม่เกิน 20 เมตร (ปัจจุบัน ${distanceToDropoff.toStringAsFixed(0)} ม.)',
        );
      }

      // --- 3. เริ่ม Transaction (Rule #2 & #3) ---
      // Transaction จะช่วยป้องกันการรับงานซ้อน
      await db.runTransaction((transaction) async {
        final deliveryRef = db.collection('delivery').doc(deliveryId);
        final assignmentRef = db.collection('assignment').doc(deliveryDocId);

        // เช็กสถานะงาน (Rule #3: งาน 1 งาน รับได้ 1 คน)
        final deliverySnap = await transaction.get(deliveryRef);
        final currentStatusCode =
            (deliverySnap.data()?['status_code'] as num?)?.toInt() ?? 0;
        if (currentStatusCode != 1) {
          throw Exception('งานนี้ถูกรับไปแล้ว');
        }

        final assignmentSnap = await transaction.get(assignmentRef);
        if (assignmentSnap.exists) {
          throw Exception('มีการรับงานนี้แล้ว');
        }

        // --- ถ้าผ่านทุกเงื่อนไข: รับงาน! ---

        // 3.1 สร้าง Assignment
        transaction.set(assignmentRef, {
          'did': deliveryDocId,
          'rid': riderId,
          'status_code': 2, // 2 = ไรเดอร์รับงาน
          'accepted_at': FieldValue.serverTimestamp(),
          'delivered_at': null,
          'picked_at': null,
        });

        // 3.2 อัปเดตสถานะ Delivery
        transaction.update(deliveryRef, {
          'status': 'ไรเดอร์รับงาน',
          'status_code': 2,
        });

        // 3.3 สร้างประวัติ (DeliveryStatusHistory)
        final newHistoryRef = db.collection('delivery_status_history').doc();
        transaction.set(newHistoryRef, {
          'did': deliveryId,
          'created_at': FieldValue.serverTimestamp(),
          'created_by_user_id': null,
          'created_by_rider_id': riderId,
          'status_code': 2,
        });
      });

      // --- 4. รับงานสำเร็จ: ไปหน้าแผนที่ (Rule #5) ---
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('รับงานสำเร็จ!'),
            backgroundColor: Colors.green,
          ),
        );

        context.pushReplacementNamed(
          'trackingPage',
          queryParameters: {'did': deliveryId},
        );

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('รับงานไม่สำเร็จ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: StreamBuilder<Delivery?>(
          stream: watchDeliveryByDid(widget.did),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('เกิดข้อผิดพลาด: ${snap.error}'));
            }
            final d = snap.data;
            if (d == null) {
              return const Center(child: Text('ไม่พบข้อมูลการจัดส่ง'));
            }

            final created = d.createdAt == null
                ? '-'
                : DateFormat('dd MMM yyyy, HH:mm').format(d.createdAt!);

            final geoFuture = _ensureGeoFuture(d);

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.bgsecondary,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      offset: const Offset(0, 20),
                      blurRadius: 35,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('รายละเอียดการจัดส่ง'),
                      const SizedBox(height: 8),
                      Text('สร้างเมื่อ: $created'),
                      const SizedBox(height: 24),

                      // ชื่อสินค้า
                      Text(d.itemName),
                      const SizedBox(height: 12),

                      // รูปภาพสินค้า/พัสดุ
                      RectImgNetwork(url: d.itemImage, height: 170, radius: 24),
                      const SizedBox(height: 16),
                      //แผนที่
                      FutureBuilder<_DeliveryGeoData>(
                        future: geoFuture,
                        builder: (context, locSnap) {
                          if (locSnap.connectionState ==
                              ConnectionState.waiting) {
                            return _MapContainer(
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          if (locSnap.hasError) {
                            return _MapContainer(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'ไม่สามารถโหลดแผนที่ได้',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.white70),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            );
                          }

                          final geo = locSnap.data;

                          if (geo == null) {
                            return _MapContainer(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'ไม่มีพิกัดสำหรับแสดงแผนที่',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.white70),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            );
                          }

                          final points = <LatLng>[
                            geo.riderPoint,
                            geo.pickupPoint,
                            if (geo.dropoffPoint != null) geo.dropoffPoint!,
                          ];

                          final bounds = LatLngBounds.fromPoints(points);

                          return _MapContainer(
                            child: FlutterMap(
                              options: MapOptions(
                                initialCameraFit: CameraFit.bounds(
                                  bounds: bounds,
                                  padding: const EdgeInsets.all(40),
                                ),
                                interactionOptions: const InteractionOptions(
                                  flags:
                                      InteractiveFlag.pinchZoom |
                                      InteractiveFlag.drag |
                                      InteractiveFlag.doubleTapZoom,
                                ),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.delivery.app',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: geo.riderPoint,
                                      width: 60,
                                      height: 60,
                                      child: const _MapMarker(
                                        color: AppColors.primary,
                                        icon: BootstrapIcons.geo_alt_fill,
                                        label: 'ฉัน',
                                      ),
                                    ),
                                    Marker(
                                      point: geo.pickupPoint,
                                      width: 60,
                                      height: 60,
                                      child: _MapMarker(
                                        color: const Color(0xFF22C55E),
                                        icon: BootstrapIcons.box_seam,
                                        label: 'จุดรับ',
                                      ),
                                    ),
                                    if (geo.dropoffPoint != null)
                                      Marker(
                                        point: geo.dropoffPoint!,
                                        width: 60,
                                        height: 60,
                                        child: _MapMarker(
                                          color: const Color(0xFFEAB308),
                                          icon: BootstrapIcons.pin_map,
                                          label: 'ปลายทาง',
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Note
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2937),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            'คำอธิบาย: ${d.note.isEmpty ? '— ไม่มีโน้ตเพิ่มเติม —' : d.note}',
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      FutureBuilder<_DeliveryGeoData>(
                        future: geoFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const _DistanceSkeleton();
                          }

                          if (snapshot.hasError) {
                            return _DistanceError(
                              message: snapshot.error.toString(),
                            );
                          }

                          final geo = snapshot.data;
                          if (geo == null) {
                            return const _DistanceError(
                              message: 'ไม่สามารถคำนวณระยะทางได้',
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _DistanceTile(
                                title: 'ระยะห่างถึงจุดรับสินค้า',
                                distanceInMeters: geo.distanceToPickup,
                              ),
                              if (geo.distanceToDropoff != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: _DistanceTile(
                                    title: 'ระยะห่างถึงปลายทาง',
                                    distanceInMeters: geo.distanceToDropoff!,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 28),
                      Text('ผู้ส่ง:'),
                      const SizedBox(height: 12),

                      FutureBuilder<UserAddress?>(
                        future: fetchAddressById(d.pickupAddrId),
                        builder: (context, a) {
                          if (a.connectionState == ConnectionState.waiting) {
                            return const _AddressSkeleton();
                          }
                          final addr = a.data?.fullAddress ?? '-';
                          return _AddressCard(address: addr);
                        },
                      ),

                      const SizedBox(height: 24),
                      Text('ผู้รับ:'),
                      const SizedBox(height: 12),

                      FutureBuilder<UserAddress?>(
                        future: fetchAddressById(d.dropoffAddrId),
                        builder: (context, a) {
                          if (a.connectionState == ConnectionState.waiting) {
                            return const _AddressSkeleton();
                          }
                          final addr = a.data?.fullAddress ?? '-';
                          return _AddressCard(address: addr);
                        },
                      ),

                      const SizedBox(height: 28),

                      FilledButton.icon(
                        // ‼ เปลี่ยน onPressed เป็นฟังก์ชันใหม่
                        onPressed: _isLoading ? null : _confirmAcceptDelivery,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: Colors.grey[600],
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: _isLoading
                            ? Container(
                                width: 22,
                                height: 22,
                                padding: const EdgeInsets.all(2.0),
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Icon(
                                BootstrapIcons.check2_circle,
                                color: Colors.white,
                                size: 22,
                              ),
                        label: Text(
                          _isLoading ? 'กำลังตรวจสอบ...' : 'Accept Delivery',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address});
  final String address;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF101522),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(10),
            child: const Icon(
              BootstrapIcons.geo_alt,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          // ‼ เพิ่ม Style
          Expanded(
            child: Text(
              address,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            BootstrapIcons.chevron_down,
            color: Colors.white70,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _DistanceTile extends StatelessWidget {
  const _DistanceTile({required this.title, required this.distanceInMeters});

  final String title;
  final double distanceInMeters;

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} กม.';
    }
    return '${meters.toStringAsFixed(0)} ม.';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF101522),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            _formatDistance(distanceInMeters),
            style: textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistanceSkeleton extends StatelessWidget {
  const _DistanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF101522),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: const Center(
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

class _DistanceError extends StatelessWidget {
  const _DistanceError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF101522),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            BootstrapIcons.exclamation_triangle,
            color: Colors.amber,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapContainer extends StatelessWidget {
  const _MapContainer({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF101522),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 8),
            ],
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xCC111827),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeliveryGeoData {
  _DeliveryGeoData({
    required this.riderPoint,
    required this.pickupPoint,
    this.dropoffPoint,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.distanceToPickup,
    required this.distanceToDropoff,
  });

  final LatLng riderPoint;
  final LatLng pickupPoint;
  final LatLng? dropoffPoint;
  final String? pickupAddress;
  final String? dropoffAddress;
  final double distanceToPickup;
  final double? distanceToDropoff;
}

class _AddressSkeleton extends StatelessWidget {
  const _AddressSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF101522),
        borderRadius: BorderRadius.circular(22),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const SizedBox(
        width: 120,
        height: 14,
        child: LinearProgressIndicator(),
      ),
    );
  }
}

class RectImgNetwork extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final double radius;
  const RectImgNetwork({
    super.key,
    required this.url,
    this.width = double.infinity,
    this.height = 170,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final hasUrl = url.trim().isNotEmpty;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasUrl
          ? Image.network(url, fit: BoxFit.cover)
          : Center(
              child: Icon(
                BootstrapIcons.image,
                color: Colors.white54,
                size: height * 0.35,
              ),
            ),
    );
  }
}

class Delivery {
  final String did;
  final String pickupAddrId;
  final String dropoffAddrId;
  final String itemName;
  final String itemImage; // URL
  final String note;
  final String receiverUid;
  final String senderUid;
  final String status;
  final int statusCode;
  final DateTime? createdAt;

  Delivery({
    required this.did,
    required this.pickupAddrId,
    required this.dropoffAddrId,
    required this.itemName,
    required this.itemImage,
    required this.note,
    required this.receiverUid,
    required this.senderUid,
    required this.status,
    required this.statusCode,
    this.createdAt,
  });

  static DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  factory Delivery.fromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data()!;
    return Delivery(
      did: (d['did'] as String?) ?? snap.id,
      pickupAddrId: d['pickup_addr_id'] as String? ?? '',
      dropoffAddrId: d['dropoff_addr_id'] as String? ?? '',
      itemName: d['item_name'] as String? ?? '',
      itemImage: d['item_image'] as String? ?? '',
      note: d['note'] as String? ?? '',
      receiverUid: d['receiver_uid'] as String? ?? '',
      senderUid: d['sender_uid'] as String? ?? '',
      status: d['status'] as String? ?? '',
      statusCode: (d['status_code'] as num?)?.toInt() ?? 0,
      createdAt: _toDate(d['created_at']),
    );
  }
}

class UserAddress {
  final String id;
  final String fullAddress;
  final double? lat;
  final double? lng;

  UserAddress({
    required this.id,
    required this.fullAddress,
    this.lat,
    this.lng,
  });

  factory UserAddress.fromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data()!;
    return UserAddress(
      id: snap.id,
      fullAddress: (d['fullAddress'] as String? ?? '').trim(),
      lat: (d['lat'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble(),
    );
  }
}
