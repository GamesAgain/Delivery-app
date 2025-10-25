import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class Assignmentlist extends StatefulWidget {
  final String? uid;
  const Assignmentlist({super.key, this.uid});

  @override
  State<Assignmentlist> createState() => _AssignmentlistState();
}

class _AssignmentlistState extends State<Assignmentlist> {
  static const Color bg = Color(0xFF0B0F19); // พื้นหลังเข้ม
  static const Color white = Colors.white; // ไอคอน/ข้อความปิด
  static const Color green = Color(0xFF16A34A); // เขียวแท็บที่เลือก

  final Map<String, Future<_UserProfile?>> _userCache = {};

  //ตัวแปรสำหรับจัดการ Stream ของ Location
  StreamSubscription<Position>? _locationSubscription;

  //เริ่มติดตามตำแหน่งเมื่อเปิดหน้า
  @override
  void initState() {
    super.initState();
    _initLocationService();
  }

  //หยุดติดตามตำแหน่งเมื่อปิดหน้า
  @override
  void dispose() {
    _locationSubscription?.cancel();
    _userCache.clear();
    super.dispose();
  }

  // ‼ 5. ฟังก์ชันใหม่: เริ่มต้นบริการตำแหน่ง
  void _initLocationService() async {
    // 5.1 ตรวจสอบ Permission
    bool permissionGranted = await _handleLocationPermission();
    if (!permissionGranted) {
      // ถ้าไม่อนุญาต, อาจจะแสดง Dialog แจ้งเตือน
      print("Location permission denied.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied.')),
        );
      }
      return;
    }

    // 5.2 ตั้งค่าความแม่นยำและระยะทาง
    // อัปเดตทุกครั้งที่ขยับ 10 เมตร
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    // 5.3 เริ่มฟังการอัปเดตตำแหน่ง
    _locationSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            // เมื่อได้ตำแหน่งใหม่, ให้อัปเดตไปที่ Firestore
            _updateRiderLocation(position);
          },
          onError: (error) {
            print('Error getting location stream: $error');
          },
        );
  }

  // ‼ 6. ฟังก์ชันใหม่: อัปเดตตำแหน่งไปที่ Firestore
  void _updateRiderLocation(Position position) {
    final rider = FirebaseAuth.instance.currentUser;
    if (rider == null) {
      // ถ้าจู่ๆ logout, ให้หยุดติดตาม
      _locationSubscription?.cancel();
      return;
    }

    final riderUid = rider.uid;

    // ใช้ .set() และ doc(riderUid)
    // มันจะสร้างเอกสารใหม่ถ้ายังไม่มี, หรืออัปเดตทับถ้ามีอยู่แล้ว
    FirebaseFirestore.instance
        .collection('RiderLocation')
        .doc(riderUid) // ใช้ ID ของไรเดอร์เป็น ID เอกสาร
        .set(
          {
            'rid': riderUid,
            'lat': position.latitude,
            'lng': position.longitude,
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(
            merge: true,
          ), // merge:true ปลอดภัยกว่า, จะไม่ลบ field อื่นถ้ามี
        )
        .catchError((error) {
          print('Failed to update rider location: $error');
        });
  }

  // ‼ 7. ฟังก์ชันใหม่: จัดการเรื่องขอ Permission
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // ตรวจสอบว่าเปิด GPS (Location Service) ไว้หรือไม่
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location services are disabled. Please enable them.',
            ),
          ),
        );
      }
      return false;
    }

    // ตรวจสอบสถานะ Permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // ผู้ใช้ปฏิเสธถาวร, ต้องไปเปิดเองใน Settings
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permissions are permanently denied, we cannot request permissions.',
            ),
          ),
        );
      }
      return false;
    }

    // ถ้ามาถึงตรงนี้ได้ คือได้รับอนุญาตแล้ว
    return true;
  }

  Stream<List<_DeliveryUiModel>> _deliveryStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Stream<List<_DeliveryUiModel>>.value(const <_DeliveryUiModel>[]);
    }

    return FirebaseFirestore.instance
        .collection('delivery')
        .where('status_code', isEqualTo: 1)
        .snapshots()
        .asyncMap((snapshot) async {
          final futures = snapshot.docs.map(_buildUiModel).toList();
          return Future.wait(futures);
        });
  }

  Future<_DeliveryUiModel> _buildUiModel(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final deliveryId = (data['did'] as String?) ?? doc.id;
    final senderUid = data['sender_uid'] as String?;
    final receiverUid = data['receiver_uid'] as String?;
    final pickupAddrId = data['pickup_addr_id'] as String?;
    final dropoffAddrId = data['dropoff_addr_id'] as String?;

    final senderProfile = await _fetchUserProfile(senderUid);
    final receiverProfile = await _fetchUserProfile(receiverUid);

    final pickupAddress = await fetchAddressById(pickupAddrId);

    final dropoffAddress = await fetchAddressById(dropoffAddrId);

    return _DeliveryUiModel(
      did: deliveryId,
      itemName: (data['item_name'] as String?)?.trim().isNotEmpty == true
          ? (data['item_name'] as String).trim()
          : 'รายการจัดส่ง',
      itemImageUrl: (data['item_image'] as String?)?.trim(),
      senderName: senderProfile?.username ?? 'ไม่พบข้อมูล',
      receiverName: receiverProfile?.username ?? 'ไม่พบข้อมูล',
      statusCode: _parseStatusCode(data['status_code']),
      note: (data['note'] as String?) ?? '', // ‼ ป้องกัน null
      senderaddress: pickupAddress?.fulladdress,
      // ‼ เพิ่ม: ส่ง lat/lng ของผู้ส่งไปเก็บใน Model
      senderLat: pickupAddress?.lat ?? 0.0,
      senderLng: pickupAddress?.lng ?? 0.0,
      dropoffAddress: dropoffAddress?.fulladdress,
      dropoffLat: dropoffAddress?.lat ?? 0.0,
      dropoffLng: dropoffAddress?.lng ?? 0.0,
    );
  }

  int _parseStatusCode(dynamic raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is String) {
      return int.tryParse(raw) ?? 1;
    }
    return 1;
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
        final username = (data?['username'] as String?)?.trim();
        return _UserProfile(uid: uid, username: username ?? 'ผู้ใช้งาน');
      } catch (_) {
        return null;
      }
    });
  }

  Future<UserAddress?> fetchUserDefaultAddress(String? uid) async {
    if (uid == null || uid.isEmpty) return null;

    final qs = await FirebaseFirestore.instance
        .collection('addresses')
        .where('uid', isEqualTo: uid)
        .where('is_default', isEqualTo: 0) // (คงไว้ตามที่คุณต้องการ)
        .limit(1)
        .get();

    if (qs.docs.isEmpty) return null;

    final data = qs.docs.first.data();
    final address = (data['fullAddress'] as String?)?.trim();

    // ‼ เพิ่ม: ดึง lat/lng (แปลงเป็น double)
    final lat = (data['lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (data['lng'] as num?)?.toDouble() ?? 0.0;

    if (address == null) return null;

    // ‼ แก้ไข: คืนค่า UserAddress ที่มี lat/lng ด้วย
    return UserAddress(fulladdress: address, lat: lat, lng: lng);
  }

  Future<UserAddress?> fetchAddressById(String? addrId) async {
    if (addrId == null || addrId.isEmpty) return null;

    final doc = await FirebaseFirestore.instance
        .collection('addresses')
        .doc(addrId)
        .get();

    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    final address = (data['fullAddress'] as String?)?.trim();
    if (address == null || address.isEmpty) return null;

    final lat = (data['lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (data['lng'] as num?)?.toDouble() ?? 0.0;

    return UserAddress(fulladdress: address, lat: lat, lng: lng);
  }

  // ‼ ลบ _formatDuration และ _computeDeliveryDuration (เพราะไม่ได้ใช้แล้ว)

  Widget _buildDeliveryCard(
    BuildContext context,
    _DeliveryUiModel delivery,
    int index,
  ) {
    final isDarkCard = index.isEven;
    final cardColor = isDarkCard
        ? const Color(0x0DD9D9D9)
        : const Color(0xCCFFFFFF);
    final primaryTextColor = isDarkCard ? white : const Color(0xFF0B0F19);
    final secondaryTextColor = isDarkCard
        ? Colors.white70
        : const Color(0xFF0B0F19);
    final subtitleColor = isDarkCard ? Colors.white : const Color(0xFF0B0F19);
    final avatarBackground = isDarkCard
        ? Colors.white10
        : const Color(0xFFE2E8F0);

    final imageProvider =
        (delivery.itemImageUrl != null && delivery.itemImageUrl!.isNotEmpty)
        ? NetworkImage(delivery.itemImageUrl!) as ImageProvider
        : const AssetImage('assets/images/test.webp');

    final trackButton = isDarkCard
        ? ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            onPressed: () {
              context.pushNamed(
                'assignmentDetail',
                queryParameters: {'did': delivery.did},
              );
            },
            child: Row(
              children: [
                const Icon(
                  BootstrapIcons.geo_alt,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Accept Delivery',
                    style: GoogleFonts.poppins(
                      color: white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          )
        : OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFF0B0F19),
              foregroundColor: const Color(0xFF16A34A),
              side: const BorderSide(color: Color(0xFF16A34A)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            ),
            onPressed: () {
              context.pushNamed(
                'assignmentDetail',
                queryParameters: {'did': delivery.did},
              );
            },
            child: Row(
              children: [
                const Icon(
                  BootstrapIcons.geo_alt,
                  color: Color(0xFF16A34A),
                  size: 16,
                ),
                const SizedBox(width: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Accept Delivery',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF16A34A),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          );

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: avatarBackground,
                backgroundImage: imageProvider,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        delivery.itemName,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ผู้ส่ง : ${delivery.senderName}',
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'ผู้รับ : ${delivery.receiverName}',
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  // ‼ แก้ไข: ใช้ note ที่กัน null แล้ว
                                  'คำอธิบาย : ${delivery.note.isEmpty ? '-' : delivery.note}',
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: SizedBox(
                              width: 85,
                              height: 70,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset(
                                  delivery.statusAssetPath,
                                  fit: BoxFit.fitHeight,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                BootstrapIcons.geo_alt_fill,
                color: Color(0xFF16A34A),
                size: 12,
              ),
              const SizedBox(width: 4), // ‼ เพิ่มช่องว่าง
              Align(
                alignment: AlignmentGeometry.bottomLeft,
                child: Text(
                  // ‼ แก้ไข: ใช้ note ที่กัน null แล้ว
                  'จุดรับสินค้า : ',
                  style: TextStyle(color: subtitleColor, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  delivery.senderaddress ?? '',
                  style: TextStyle(color: subtitleColor),
                  maxLines: 2,
                  overflow: TextOverflow.clip,
                ),
              ),
            ],
          ),
          Row(
            children: [
              trackButton,
              const Spacer(),
              // ‼ -----------------------------------------------------------
              // ‼ แก้ไข: เปลี่ยนจาก Column ธรรมดา เป็น StreamBuilder
              // ‼ -----------------------------------------------------------
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                // 1. ดึง ID ไรเดอร์ที่ล็อกอินอยู่
                stream: FirebaseFirestore.instance
                    .collection('RiderLocation')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  String distanceText = '...';
                  Color distanceColor = green;

                  // 2. ตรวจสอบว่ามีพิกัดผู้ส่งหรือไม่
                  if (delivery.senderLat == 0.0 && delivery.senderLng == 0.0) {
                    distanceText = 'No Dropoff GPS';
                    distanceColor = Colors.orange;
                  }
                  // 3. ตรวจสอบสถานะ Stream ของไรเดอร์
                  else if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    distanceText = '...';
                  } else if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data?.data() == null) {
                    distanceText = 'No Rider GPS';
                    distanceColor = Colors.red;
                  } else {
                    // 4. ดึงพิกัดไรเดอร์
                    final data = snapshot.data!.data()!;
                    final riderLat = (data['lat'] as num?)?.toDouble();
                    final riderLng = (data['lng'] as num?)?.toDouble();

                    if (riderLat == null || riderLng == null) {
                      distanceText = 'No Rider GPS';
                      distanceColor = Colors.red;
                    } else {
                      // 5. คำนวณระยะทาง (สำเร็จ)
                      double distanceInMeters = Geolocator.distanceBetween(
                        riderLat,
                        riderLng,
                        delivery.senderLat,
                        delivery.senderLng,
                      );

                      // 6. จัดรูปแบบการแสดงผล
                      if (distanceInMeters < 1000) {
                        distanceText =
                            '${distanceInMeters.toStringAsFixed(0)} m';
                      } else {
                        double distanceInKm = distanceInMeters / 1000.0;
                        distanceText = '${distanceInKm.toStringAsFixed(1)} km';
                      }
                    }
                  }

                  // 7. คืนค่า UI (เหมือนเดิม แต่เปลี่ยนค่า Text)
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            BootstrapIcons.cursor_fill,
                            color: secondaryTextColor,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Delivery Distance',
                            style: GoogleFonts.poppins(
                              color: secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          distanceText, // ‼ แสดงผลระยะทางที่คำนวณได้
                          style: GoogleFonts.poppins(
                            color: distanceColor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              // ‼ -----------------------------------------------------------
              // ‼ จบส่วน StreamBuilder
              // ‼ -----------------------------------------------------------
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(35),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(
              children: [
                Row(
                  children: [
                    // โปรไฟล์/ที่อยู่
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0x1516A34A),
                      ),
                      child: const Icon(
                        BootstrapIcons.geo_alt,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'สรายุทธ บุตรวงษ์',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Maha Sarakham, Thailand',
                            style: TextStyle(color: Color(0xFFB3C0BA)),
                          ),
                        ],
                      ),
                    ),
                    //  Delivery Logo
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0x1416A34A),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                offset: Offset(0, 4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.green,
                                  child: Icon(
                                    BootstrapIcons.bag_check,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    2,
                                    10,
                                    2,
                                  ),
                                  child: Text(
                                    'Delivery',
                                    style: GoogleFonts.poppins(
                                      color: green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // ========= Current Delivery (หัวเรื่อง "คงที่") =========
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    'Current Delivery',
                    style: GoogleFonts.poppins(
                      color: white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              // ---------- List Delivery (เลื่อนเฉพาะส่วนนี้) ----------
              const SizedBox(height: 12),

              // ใช้ SizedBox จำกัดความสูง (คงไว้ตามที่คุณต้องการ)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.68,
                child: StreamBuilder<List<_DeliveryUiModel>>(
                  stream: _deliveryStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'ไม่สามารถโหลดข้อมูลได้',
                          style: GoogleFonts.poppins(color: white),
                        ),
                      );
                    }

                    final deliveries = snapshot.data ?? <_DeliveryUiModel>[];
                    if (deliveries.isEmpty) {
                      return Center(
                        child: Text(
                          'No deliveries',
                          style: GoogleFonts.poppins(color: white),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: deliveries.length,
                      itemBuilder: (context, index) =>
                          _buildDeliveryCard(context, deliveries[index], index),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeliveryUiModel {
  _DeliveryUiModel({
    required this.did,
    required this.itemName,
    required this.itemImageUrl,
    required this.senderName,
    required this.receiverName,
    required this.statusCode,
    required this.note,
    required this.senderaddress,
    required this.senderLat, // ‼ เพิ่ม
    required this.senderLng, // ‼ เพิ่ม
    required this.dropoffAddress,
    required this.dropoffLat,
    required this.dropoffLng,
  });

  final String did;
  final String itemName;
  final String? itemImageUrl;
  final String senderName;
  final String receiverName;
  final int statusCode;
  final String note;
  final String? senderaddress;
  final double senderLat; // ‼ เพิ่ม
  final double senderLng; // ‼ เพิ่ม
  final String? dropoffAddress;
  final double dropoffLat;
  final double dropoffLng;

  int get clampedStatusCode => statusCode.clamp(1, 4);

  String get statusAssetPath =>
      'assets/images/Status${clampedStatusCode.toString()}.png';
}

class _UserProfile {
  _UserProfile({required this.uid, required this.username});

  final String uid;
  final String username;
}

class UserAddress {
  // ‼ แก้ไข: เปลี่ยนค่าเริ่มต้นเป็น 0.0 และประเภทเป็น double
  UserAddress({required this.fulladdress, this.lat = 0.0, this.lng = 0.0});

  final String fulladdress;
  // ‼ แก้ไข: เปลี่ยนเป็น double
  final double lat;
  final double lng;
}
