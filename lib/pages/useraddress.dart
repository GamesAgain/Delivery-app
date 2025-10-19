import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/models/address.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UserAddressPage extends StatefulWidget {
  const UserAddressPage({super.key, this.uid});

  final String? uid;

  @override
  State<UserAddressPage> createState() => _UserAddressPageState();
}

class _UserAddressPageState extends State<UserAddressPage> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _addressStream;

  @override
  void initState() {
    super.initState();
    _addressStream = FirebaseFirestore.instance
        .collection('addresses')
        .where('uid', isEqualTo: widget.uid)
        .orderBy('is_default')
        .orderBy('create_at', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F19),
        title: const Text(
          'ที่อยู่ของฉัน',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: Offset(1.5, 1.5),
                blurRadius: 2.0,
                color: Color(0xFF16A34A),
              ),
            ],
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _addressStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'เกิดข้อผิดพลาดในการโหลดข้อมูล',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: Colors.redAccent),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  final addresses =
                      docs.map(Address.fromFirestore).toList(growable: false);

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    itemCount: addresses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final address = addresses[index];
                      return _AddressTile(address: address);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await context.pushNamed(
                'addnewaddress',
                queryParameters: {'uid': widget.uid},
              );
            },
            icon: const Icon(
              Icons.add_circle_outline,
              color: Color(0xFF16A34A),
              size: 26,
            ),
            label: const Text(
              'เพิ่มที่อยู่จัดส่งใหม่',
              style: TextStyle(
                color: Color(0xFF16A34A),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            BootstrapIcons.geo_alt,
            color: Color(0xFF16A34A),
            size: 56,
          ),
          SizedBox(height: 16),
          Text(
            'ยังไม่มีที่อยู่ที่บันทึกไว้',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'กดปุ่มด้านล่างเพื่อเพิ่มที่อยู่ใหม่',
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({required this.address});

  final Address address;

  @override
  Widget build(BuildContext context) {
    final isDefault = address.isDefault == 0;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDefault ? const Color(0xFF16A34A) : Colors.white12,
          width: 1.3,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                BootstrapIcons.geo_alt,
                color: Color(0xFF16A34A),
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            address.label.isNotEmpty
                                ? address.label
                                : 'ไม่ระบุชื่อที่อยู่',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: const Text(
                              'ค่าเริ่มต้น',
                              style: TextStyle(
                                color: Color(0xFF16A34A),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      address.fullAddress,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (address.lat != null && address.lng != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  BootstrapIcons.pin_map,
                  color: Colors.white60,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '${address.lat?.toStringAsFixed(6)}, ${address.lng?.toStringAsFixed(6)}',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
