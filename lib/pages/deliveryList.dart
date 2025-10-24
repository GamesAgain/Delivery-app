import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/pages/addDelivery.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:delivery_app/pages/trackDelivery.dart';

class DeliverylistPage extends StatefulWidget {
  const DeliverylistPage({super.key});

  @override
  State<DeliverylistPage> createState() => _DeliverylistPageState();
}

class _DeliverylistPageState extends State<DeliverylistPage> {
  static const Color bg = Color(0xFF0B0F19); // พื้นหลังเข้ม
  static const Color white = Colors.white; // ไอคอน/ข้อความปิด
  static const Color green = Color(0xFF16A34A); // เขียวแท็บที่เลือก

  final Map<String, Future<_UserProfile?>> _userCache = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  _DeliveryFilter _selectedFilter = _DeliveryFilter.toDeliver;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openGlobalTracking(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TrackDeliveryPage()));
  }

  void _openDeliveryTracking(BuildContext context, _DeliveryUiModel delivery) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrackDeliveryPage(
          deliveryId: delivery.did,
          itemName: delivery.itemName,
        ),
      ),
    );
  }

  Stream<List<_DeliveryUiModel>> _deliveryStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Stream<List<_DeliveryUiModel>>.value(const <_DeliveryUiModel>[]);
    }

    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('delivery');

    switch (_selectedFilter) {
      case _DeliveryFilter.toDeliver:
        query = query.where('sender_uid', isEqualTo: currentUser.uid);
        break;
      case _DeliveryFilter.toReceive:
        query = query.where('receiver_uid', isEqualTo: currentUser.uid);
        break;
    }

    return query.snapshots().asyncMap((snapshot) async {
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
            onPressed: () => _openDeliveryTracking(context, delivery),
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
                    'Delivery Tracking',
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
            onPressed: () => _openDeliveryTracking(context, delivery),
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
                    'Delivery Tracking',
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
          _buildProgressIndicators(delivery.clampedStatusCode, isDarkCard),
          const SizedBox(height: 14),
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
                        'Delivery Time',
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

  Widget _buildProgressIndicators(int statusCode, bool isDarkCard) {
    const totalSteps = 4;
    final children = <Widget>[];

    for (var i = 0; i < totalSteps; i++) {
      final stepIndex = i + 1;
      final isActive = statusCode >= stepIndex;
      children.add(
        _buildStatusStep(
          stepIndex: i,
          isActive: isActive,
          isDarkCard: isDarkCard,
        ),
      );

      if (i < totalSteps - 1) {
        final connectorActive = statusCode > stepIndex;
        children.add(_buildConnector(connectorActive, isDarkCard));
      }
    }

    return Row(children: children);
  }

  Widget _buildStatusStep({
    required int stepIndex,
    required bool isActive,
    required bool isDarkCard,
  }) {
    final backgroundColor = isActive
        ? green
        : (isDarkCard ? Colors.white24 : const Color(0xFFE2E8F0));
    final inactiveIconColor = isDarkCard
        ? Colors.white70
        : const Color(0xFF64748B);

    Widget icon;
    switch (stepIndex) {
      case 0:
        icon = Icon(
          BootstrapIcons.box_seam,
          size: 14,
          color: isActive ? Colors.white : inactiveIconColor,
        );
        break;
      case 1:
      case 2:
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
        radius: 12,
        backgroundColor: backgroundColor,
        child: icon,
      ),
    );
  }

  Widget _buildConnector(bool isActive, bool isDarkCard) {
    final color = isActive
        ? const Color(0xFF2B9F5C)
        : (isDarkCard ? Colors.white24 : const Color(0xFFE2E8F0));
    return Expanded(
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ========= HEADER เดิม =========
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

                // -- SearchBar --
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0x1416A34A),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0x3316A34A)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(
                      () => _searchTerm = value.toLowerCase().trim(),
                    ),
                    cursorColor: green,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      icon: const Icon(
                        BootstrapIcons.search,
                        color: Colors.white70,
                      ),
                      hintText: 'Find your Delivery',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      suffixIcon: _searchTerm.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                BootstrapIcons.x,
                                color: Colors.white60,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchTerm = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // -- Buttons --
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AddDeliveryPage(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: bg,
                              child: SvgPicture.asset(
                                'assets/icons/plus_Delivery.svg',
                                width: 22,
                                height: 22,
                              ),
                            ),
                            const SizedBox(width: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'New Delivery',
                                style: GoogleFonts.poppins(
                                  color: white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF16A34A),
                        side: const BorderSide(color: Color(0xFF16A34A)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                      ),
                      onPressed: () => _openGlobalTracking(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: green,
                              child: SvgPicture.asset(
                                'assets/icons/tracking.svg',
                                width: 26,
                                height: 26,
                              ),
                            ),
                            const SizedBox(width: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Track Delivery',
                                style: GoogleFonts.poppins(
                                  color: white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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
          ),
        ),

        // ========= Current Delivery (หัวเรื่อง "คงที่") =========
        Expanded(
          child: Padding(
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

                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0x1AFFFFFF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: DropdownButton<_DeliveryFilter>(
                          value: _selectedFilter,
                          underline: const SizedBox.shrink(),
                          dropdownColor: const Color(0xFF1F2937),
                          iconEnabledColor: white,
                          style: GoogleFonts.poppins(color: white),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _selectedFilter = value;
                            });
                          },
                          items: _DeliveryFilter.values
                              .map(
                                (filter) => DropdownMenuItem(
                                  value: filter,
                                  child: Text(filter.label),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ),

                // ใช้ Expanded ให้ ListView ภายในเลื่อนโดยไม่เกิด overflow
                Expanded(
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

                      final deliveries =
                          snapshot.data ?? const <_DeliveryUiModel>[];
                      final searchQuery = _searchTerm;
                      final filteredDeliveries = searchQuery.isEmpty
                          ? deliveries
                          : deliveries
                                .where(
                                  (delivery) => delivery.itemName
                                      .toLowerCase()
                                      .contains(searchQuery),
                                )
                                .toList();

                      if (deliveries.isEmpty) {
                        return Center(
                          child: Text(
                            'ยังไม่มีรายการจัดส่ง',
                            style: GoogleFonts.poppins(color: white),
                          ),
                        );
                      }

                      if (filteredDeliveries.isEmpty) {
                        return Center(
                          child: Text(
                            'ไม่พบรายการที่ตรงกับคำค้นหา',
                            style: GoogleFonts.poppins(color: white),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.only(bottom: 65),
                        itemCount: filteredDeliveries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _buildDeliveryCard(
                          context,
                          filteredDeliveries[index],
                          index,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
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
  });

  final String did;
  final String itemName;
  final String? itemImageUrl;
  final String senderName;
  final String receiverName;
  final int statusCode;
  final String deliveryDurationLabel;

  int get clampedStatusCode => statusCode.clamp(1, 4);

  String get statusAssetPath =>
      'assets/images/Status${clampedStatusCode.toString()}.png';
}

class _UserProfile {
  _UserProfile({required this.uid, required this.username});

  final String uid;
  final String username;
}

enum _DeliveryFilter {
  toDeliver,
  toReceive,
}

extension on _DeliveryFilter {
  String get label {
    switch (this) {
      case _DeliveryFilter.toDeliver:
        return 'ที่ต้องจัดส่ง';
      case _DeliveryFilter.toReceive:
        return 'ที่ต้องได้รับ';
    }
  }
}
