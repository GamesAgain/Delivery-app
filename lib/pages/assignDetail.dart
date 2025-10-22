import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AssignDetailPage extends StatefulWidget {
  final String did;
  const AssignDetailPage({super.key, required this.did});

  @override
  State<AssignDetailPage> createState() => _AssignDetailPageState();
}

class _AssignDetailPageState extends State<AssignDetailPage> {
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

  // ----- UI -----
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
                      Text(
                        'รายละเอียดการจัดส่ง',
                        style: TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'สร้างเมื่อ: $created',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 24),

                      // ชื่อสินค้า
                      Text(d.itemName, style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 12),

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
                            (d.note.isEmpty)
                                ? '— ไม่มีโน้ตเพิ่มเติม —'
                                : d.note,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),
                      Text('ผู้ส่ง:', style: TextStyle(fontSize: 14)),
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
                      Text('ผู้รับ:', style: TextStyle(fontSize: 14)),
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
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection('delivery')
                              .doc(d.did)
                              .update({
                                'status': 'ไรเดอร์รับงาน',
                                'status_code': 2,
                              });
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(
                          BootstrapIcons.check2_circle,
                          color: Colors.white,
                          size: 22,
                        ),
                        label: Text(
                          'Accept Delivery',
                          style: TextStyle(fontSize: 17),
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
          Expanded(child: Text(address, style: TextStyle(fontSize: 14))),
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
