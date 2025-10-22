import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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

  @override
  void dispose() {
    super.dispose();
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

    final senderProfile = await _fetchUserProfile(senderUid);
    final senderaddress = await fetchUserDefaultAddress(senderUid);
    final receiverProfile = await _fetchUserProfile(receiverUid);
    final durationText = await _computeDeliveryDuration(deliveryId);

    return _DeliveryUiModel(
      did: deliveryId,
      itemName: (data['item_name'] as String?)?.trim().isNotEmpty == true
          ? (data['item_name'] as String).trim()
          : 'รายการจัดส่ง',
      itemImageUrl: (data['item_image'] as String?)?.trim(),
      senderName: senderProfile?.username ?? 'ไม่พบข้อมูล',
      receiverName: receiverProfile?.username ?? 'ไม่พบข้อมูล',
      statusCode: _parseStatusCode(data['status_code']),
      deliveryDurationLabel: durationText,
      note: (data['note']),
      senderaddress: senderaddress?.fulladdress,
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
        .where('is_default', isEqualTo: 0)
        .limit(1)
        .get();

    if (qs.docs.isEmpty) return null;

    final data = qs.docs.first.data();
    final address = (data['fullAddress'] as String?)?.trim();
    return address == null ? null : UserAddress(fulladdress: address);
  }

  Future<String> _computeDeliveryDuration(String deliveryId) async {
    try {
      final historySnapshot = await FirebaseFirestore.instance
          .collection('delivery_status_history')
          .where('did', isEqualTo: deliveryId)
          .orderBy('created_at')
          .get();

      if (historySnapshot.docs.length < 2) {
        return 'In progress';
      }

      final firstTimestamp =
          historySnapshot.docs.first.data()['created_at'] as Timestamp?;
      final lastTimestamp =
          historySnapshot.docs.last.data()['created_at'] as Timestamp?;

      if (firstTimestamp == null || lastTimestamp == null) {
        return 'N/A';
      }

      final duration = lastTimestamp.toDate().difference(
        firstTimestamp.toDate(),
      );
      return _formatDuration(duration);
    } catch (_) {
      return 'N/A';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes <= 0) {
      return 'Just started';
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0) {
      return '$minutes mins';
    }

    if (minutes == 0) {
      return '$hours hrs';
    }

    return '$hours hrs $minutes mins';
  }

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
                    'Accept Tracking',
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
                                  'คำอธิบาย : ${delivery.note}',
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 12,
                                  ),
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
              const Icon(
                BootstrapIcons.geo_alt_fill,
                color: Color(0xFF16A34A),
                size: 12,
              ),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        BootstrapIcons.clock,
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
                      delivery.deliveryDurationLabel,
                      style: GoogleFonts.poppins(color: green, fontSize: 13),
                    ),
                  ),
                ],
              ),
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

              // ใช้ SizedBox จำกัดความสูง แล้วให้ ListView ภายในเลื่อน
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
    required this.deliveryDurationLabel,
    required this.note,
    required this.senderaddress,
  });

  final String did;
  final String itemName;
  final String? itemImageUrl;
  final String senderName;
  final String receiverName;
  final int statusCode;
  final String deliveryDurationLabel;
  final String note;
  final String? senderaddress;

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
  UserAddress({required this.fulladdress, this.lat = 0, this.lng = 0});

  final String fulladdress;
  final int lat;
  final int lng;
}
