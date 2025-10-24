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

  Future<Map<String, double?>> _getLocations(String pickupAddrId) async {
    final riderId = FirebaseAuth.instance.currentUser?.uid;
    if (riderId == null) {
      throw Exception('Rider not logged in.');
    }

    // 1. ดึงตำแหน่งไรเดอร์
    final riderLocSnap = await FirebaseFirestore.instance
        .collection('RiderLocation')
        .doc(riderId)
        .get();

    // 2. ดึงตำแหน่งผู้ส่ง (จุดรับของ)
    final senderAddrSnap = await FirebaseFirestore.instance
        .collection('addresses')
        .doc(pickupAddrId)
        .get();

    if (!riderLocSnap.exists || !senderAddrSnap.exists) {
      throw Exception('Could not find location data.');
    }

    return {
      'riderLat': (riderLocSnap.data()?['lat'] as num?)?.toDouble(),
      'riderLng': (riderLocSnap.data()?['lng'] as num?)?.toDouble(),
      'senderLat': (senderAddrSnap.data()?['lat'] as num?)?.toDouble(),
      'senderLng': (senderAddrSnap.data()?['lng'] as num?)?.toDouble(),
    };
  }

  void riderAccepted() async {
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
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // --- 1. ดึง Delivery Doc เพื่อเอา pickup_addr_id ---
      final deliveryDoc = await db.collection('delivery').doc(deliveryId).get();
      if (!deliveryDoc.exists) throw Exception('ไม่พบงานนี้');
      final pickupAddrId = deliveryDoc.data()?['pickup_addr_id'] as String?;
      if (pickupAddrId == null) throw Exception('ไม่พบที่อยู่ผู้ส่ง');

      // --- 2. ตรวจสอบ Geofence 1 กิโลเมตร (Rule #1) ---
      final locations = await _getLocations(pickupAddrId);
      final riderLat = locations['riderLat'];
      final riderLng = locations['riderLng'];
      final senderLat = locations['senderLat'];
      final senderLng = locations['senderLng'];

      if (riderLat == null ||
          riderLng == null ||
          senderLat == null ||
          senderLng == null) {
        throw Exception('ไม่สามารถคำนวณระยะทางได้ (ข้อมูลพิกัดไม่ครบ)');
      }

      double distance = Geolocator.distanceBetween(
        riderLat,
        riderLng,
        senderLat,
        senderLng,
      );

      if (distance > 1000) {
        throw Exception(
          'คุณอยู่ไกลเกินไป (${distance.toStringAsFixed(0)} เมตร)',
        );
      }

      // --- 3. เริ่ม Transaction (Rule #2 & #3) ---
      // Transaction จะช่วยป้องกันการรับงานซ้อน
      await db.runTransaction((transaction) async {
        final deliveryRef = db.collection('delivery').doc(deliveryId);

        // เช็กสถานะงาน (Rule #3: งาน 1 งาน รับได้ 1 คน)
        final deliverySnap = await transaction.get(deliveryRef);
        final currentStatusCode =
            (deliverySnap.data()?['status_code'] as num?)?.toInt() ?? 0;
        if (currentStatusCode != 1) {
          throw Exception('งานนี้ถูกรับไปแล้ว');
        }

        // --- ถ้าผ่านทุกเงื่อนไข: รับงาน! ---

        // 3.1 สร้าง Assignment
        final newAssignmentRef = db.collection('assignment').doc();
        transaction.set(newAssignmentRef, {
          'did': deliveryId,
          'rid': riderId,
          'status_code': 2, // 2 = ไรเดอร์รับงาน
          'accepted_at': FieldValue.serverTimestamp(),
          'picked_at': null,
          'delivered_at': null,
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('รับงานไม่สำเร็จ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
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

                      FutureBuilder<Map<String, double?>>(
                        future: _getLocations(d.pickupAddrId),
                        builder: (context, locSnap) {
                          if (locSnap.connectionState == ConnectionState.waiting) {
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

                          final data = locSnap.data;
                          final riderLat = data?['riderLat'];
                          final riderLng = data?['riderLng'];
                          final destLat = data?['senderLat'];
                          final destLng = data?['senderLng'];

                          if (riderLat == null ||
                              riderLng == null ||
                              destLat == null ||
                              destLng == null) {
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

                          final riderPoint = LatLng(riderLat, riderLng);
                          final destinationPoint = LatLng(destLat, destLng);
                          final bounds = LatLngBounds.fromPoints(
                            [riderPoint, destinationPoint],
                          );

                          return _MapContainer(
                            child: FlutterMap(
                              options: MapOptions(
                                initialCameraFit: CameraFit.bounds(
                                  bounds: bounds,
                                  padding: const EdgeInsets.all(40),
                                ),
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.pinchZoom |
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
                                      point: riderPoint,
                                      width: 60,
                                      height: 60,
                                      child: const _MapMarker(
                                        color: AppColors.primary,
                                        icon: BootstrapIcons.geo_alt_fill,
                                        label: 'ฉัน',
                                      ),
                                    ),
                                    Marker(
                                      point: destinationPoint,
                                      width: 60,
                                      height: 60,
                                      child: const _MapMarker(
                                        color: Color(0xFFEAB308),
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

                      // รูปภาพสินค้า/พัสดุ
                      RectImgNetwork(url: d.itemImage, height: 170, radius: 24),
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
                        onPressed: _isLoading ? null : riderAccepted,
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
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xCC111827),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
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
