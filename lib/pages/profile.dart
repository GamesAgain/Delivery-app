import 'package:delivery_app/models/user.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfilePage extends StatefulWidget {
  final String? uid;
  final Users profile;
  const ProfilePage({super.key, required this.uid, required this.profile});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color green = Color(0xFF16A34A);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 230,
            decoration: const BoxDecoration(
              color: Color(0xFF0B0F19),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.only(top: 160, bottom: 30),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              padding: const EdgeInsets.fromLTRB(20, 70, 20, 30),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withOpacity(0.08),
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    widget.profile.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.profile.phone!,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 25),

                  // ✅ ปุ่มคลิกได้จริงทุกอัน
                  _buildMenu(
                    Icons.person_outline,
                    'แก้ไขข้อมูลส่วนตัว',
                    onTap: () {
                      print('แก้ไขข้อมูลส่วนตัว');
                    },
                  ),
                  _buildMenu(
                    Icons.lock_outline,
                    'จัดการรหัสผ่าน',
                    onTap: () {
                      print('Tapped!');
                    },
                  ),
                  _buildMenu(
                    Icons.location_on_outlined,
                    'ที่อยู่',
                    onTap: () {
                      print('Going to address with uid=${widget.uid}');
                      context.pushNamed(
                        'address',
                        queryParameters: {'uid': widget.uid},
                      );
                    },
                  ),

                  const SizedBox(height: 45),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        print('ออกจากระบบ');
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'ออกจากระบบ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: const Color(0xFF0B0F19),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  backgroundImage: NetworkImage(widget.profile.avatar!),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu(IconData icon, String text, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 65,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD9D9D9).withOpacity(0.9),
            foregroundColor: Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: const Color(0xFF16A34A)),
                  const SizedBox(width: 10),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.chevron_right, color: Colors.black87),
            ],
          ),
        ),
      ),
    );
  }
}
