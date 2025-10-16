import 'dart:developer';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UserAddressPage extends StatefulWidget {
  final String? uid;
  const UserAddressPage({super.key, this.uid});

  @override
  State<UserAddressPage> createState() => _UserAddressPageState();
}

class _UserAddressPageState extends State<UserAddressPage> {
  List<Map<String, dynamic>> addresses = [];
  @override
  void initState() {
    super.initState();
    LoadAddresses();
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
          onPressed: () {},
          icon: Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: addresses.length,
          itemBuilder: (context, index) {
            final addr = addresses[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D9D9).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF16A34A).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              BootstrapIcons.geo_alt,
                              color: Color(0xFF16A34A),
                              size: 25,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  addr['addressName'] ?? 'ไม่ระบุชื่อที่อยู่',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.7,
                                  child: Text(
                                    addr['fullAddress'] ?? '-',
                                    softWrap: true,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Expanded(
                          child: IconButton(
                            onPressed: () {
                              print('Edit address: ${addr['addr_id']}');
                            },
                            icon: const Icon(
                              BootstrapIcons.pencil_square,
                              color: Color(0xFF16A34A),
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              context.pushNamed(
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> LoadAddresses() async {
    log('coming LoadAddresses');
    final uid = widget.uid;
    log('Checking UID: $uid');
    final snapshot = await FirebaseFirestore.instance
        .collection('addresses')
        .where('uid', isEqualTo: uid)
        .get();
    log('Found ${snapshot.docs.length} documents');
    for (final doc in snapshot.docs) {
      log('DocID: ${doc.id} => ${doc.data()}');

      addresses = snapshot.docs.map((doc) => doc.data()).toList();
      setState(() {});
    }
  }
}
