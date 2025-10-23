import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/pages/deliveryHistory.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShipmentPage extends StatefulWidget {
  const ShipmentPage({super.key});

  @override
  State<ShipmentPage> createState() => _ShipmentPageState();
}

class _ShipmentPageState extends State<ShipmentPage> {
  static const Color bg = Color(0xFF0B0F19);
  static const Color green = Color(0xFF16A34A);

  int _selectedIndex = 0;

  final List<String> tabs = ['กำลังดำเนินการ', 'เสร็จสิ้น', 'ยกเลิก/ล้มเหลว'];
  final Map<String, Future<String?>> _userNameCache = {};

  static const Map<int, String> _statusTitleMap = {
    1: 'กำลังรอไรเดอร์มารับ',
    2: 'ไรเดอร์รับงาน',
    3: 'ไรเดอร์รับสินค้าแล้วและกำลังเดินทางไปส่ง',
    4: 'ไรเดอร์นำส่งสินค้าแล้ว',
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            tabs: tabs,
            selectedIndex: _selectedIndex,
            onTabSelected: (index) => setState(() => _selectedIndex = index),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<_ShipmentItem>>( 
              stream: _shipmentsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const _ShipmentMessage(
                    icon: BootstrapIcons.exclamation_triangle_fill,
                    message: 'ไม่สามารถโหลดประวัติการจัดส่งได้',
                  );
                }

                final items = _filterShipments(snapshot.data ?? const <_ShipmentItem>[]);
                if (items.isEmpty) {
                  return const _ShipmentMessage(
                    icon: BootstrapIcons.box,
                    message: 'ไม่มีรายการจัดส่งในหมวดนี้',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _ShipmentCard(
                      sender: item.senderName,
                      receiver: item.receiverName,
                      status: _statusTextForItem(item),
                      onDetails: () => _openDeliveryHistory(context, item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<List<_ShipmentItem>> _shipmentsStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Stream<List<_ShipmentItem>>.value(const <_ShipmentItem>[]);
    }

    return FirebaseFirestore.instance
        .collection('delivery')
        .where('sender_uid', isEqualTo: currentUser.uid)
        .snapshots()
        .asyncMap((snapshot) async {
          final futures = snapshot.docs.map(_mapShipmentItem).toList();
          final results = await Future.wait(futures);
          results.sort((a, b) {
            final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
          return results;
        });
  }

  Future<_ShipmentItem> _mapShipmentItem(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final did = _normalizeText(data['did']) ?? doc.id;
    final itemName =
        _normalizeText(data['item_name']) ?? 'รายการจัดส่ง';
    final senderName =
        await _fetchUserName(_normalizeText(data['sender_uid'])) ?? 'ไม่พบข้อมูล';
    final receiverName =
        await _fetchUserName(_normalizeText(data['receiver_uid'])) ?? 'ไม่พบข้อมูล';
    final statusCode = _parseStatusCode(data['status_code']);
    final statusLabel = _normalizeText(data['status']);
    final updatedAt =
        _toDate(data['updated_at'] as Timestamp?) ??
        _toDate(data['status_updated_at'] as Timestamp?) ??
        _toDate(data['created_at'] as Timestamp?);

    return _ShipmentItem(
      did: did,
      itemName: itemName,
      senderName: senderName,
      receiverName: receiverName,
      statusCode: statusCode,
      statusLabel: statusLabel,
      updatedAt: updatedAt,
    );
  }

  List<_ShipmentItem> _filterShipments(List<_ShipmentItem> items) {
    switch (_selectedIndex) {
      case 0:
        return items.where((item) => item.isInProgress).toList(growable: false);
      case 1:
        return items.where((item) => item.isCompleted).toList(growable: false);
      default:
        return items.where((item) => item.isCancelled).toList(growable: false);
    }
  }

  Future<String?> _fetchUserName(String? uid) {
    if (uid == null || uid.isEmpty) {
      return Future.value(null);
    }

    return _userNameCache.putIfAbsent(uid, () async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final data = doc.data();
        if (!doc.exists || data == null) {
          return null;
        }
        return _normalizeText(data['username']) ??
            _normalizeText(data['display_name']) ??
            'ผู้ใช้งาน';
      } catch (_) {
        return null;
      }
    });
  }

  void _openDeliveryHistory(BuildContext context, _ShipmentItem item) {
    GoRouter.of(context).pushNamed(
      'deliveryHistory',
      pathParameters: {'did': item.did},
      extra: DeliveryHistoryPageArgs(
        itemName: item.itemName,
        statusLabel: item.statusLabel,
      ),
    );
  }

  String _statusTextForItem(_ShipmentItem item) {
    final label = item.statusLabel;
    if (label != null && label.isNotEmpty) {
      return label;
    }
    return _statusTitleMap[item.statusCode] ?? 'สถานะที่ ${item.statusCode}';
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
}

class _Header extends StatelessWidget {
  const _Header({
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  static const EdgeInsets _headerPadding = EdgeInsets.only(
    top: 32,
    left: 20,
    right: 20,
    bottom: 20,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _ShipmentPageState.bg,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: _headerPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ประวัติการจัดส่ง',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(1.5, 1.5),
                  blurRadius: 2.0,
                  color: _ShipmentPageState.green,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Padding(
                    padding: EdgeInsets.only(right: i == tabs.length - 1 ? 0 : 12),
                    child: _TabChip(
                      label: tabs[i],
                      active: selectedIndex == i,
                      onTap: () => onTabSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: active
                ? _ShipmentPageState.green.withOpacity(0.16)
                : _ShipmentPageState.green.withOpacity(0.08),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: const StadiumBorder(),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 3,
          width: active ? 70 : 0,
          decoration: BoxDecoration(
            color: active ? _ShipmentPageState.green : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _ShipmentCard extends StatelessWidget {
  const _ShipmentCard({
    required this.sender,
    required this.receiver,
    required this.status,
    required this.onDetails,
  });

  final String sender;
  final String receiver;
  final String status;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF16A34A).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            BootstrapIcons.box,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  label: 'ผู้ส่ง',
                  value: sender,
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  label: 'ผู้รับ',
                  value: receiver,
                ),
                const SizedBox(height: 10),
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 15,
                    color: _ShipmentPageState.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onDetails,
            style: FilledButton.styleFrom(
              backgroundColor: _ShipmentPageState.green,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: const StadiumBorder(),
            ),
            child: const Text(
              'รายละเอียด',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label : ',
          style: const TextStyle(
            fontSize: 15,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ShipmentMessage extends StatelessWidget {
  const _ShipmentMessage({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white54,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShipmentItem {
  _ShipmentItem({
    required this.did,
    required this.itemName,
    required this.senderName,
    required this.receiverName,
    required this.statusCode,
    this.statusLabel,
    this.updatedAt,
  });

  final String did;
  final String itemName;
  final String senderName;
  final String receiverName;
  final int statusCode;
  final String? statusLabel;
  final DateTime? updatedAt;

  bool get isCompleted => statusCode >= 4;

  bool get isCancelled {
    if (statusCode <= 0) {
      return true;
    }
    final label = statusLabel?.toLowerCase() ?? '';
    return label.contains('ยกเลิก') ||
        label.contains('cancel') ||
        label.contains('ล้มเหลว') ||
        label.contains('fail');
  }

  bool get isInProgress => !isCompleted && !isCancelled;
}
