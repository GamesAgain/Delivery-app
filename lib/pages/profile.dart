import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color bg = Color(0xFF0B0F19);
  static const Color green = Color(0xFF16A34A);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF111827),
      extendBodyBehindAppBar: true,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),

          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Container(
              width: double.infinity,
              height: 615,
              margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 60),
              padding: const EdgeInsets.fromLTRB(20, 70, 20, 30),
              decoration: BoxDecoration(
                color: Color(0xFF16A34A).withOpacity(0.08),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'สรายุทธ บุตรวงษ์',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '0987654321',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 25),

                  _buildMenu(
                    Icons.person_outline,
                    'แก้ไขข้อมูลส่วนตัว',
                    onTap: () {},
                  ),
                  _buildMenu(
                    Icons.lock_outline,
                    'จัดการรหัสผ่าน',
                    onTap: () {},
                  ),
                  _buildMenu(
                    Icons.location_on_outlined,
                    'ที่อยู่',
                    onTap: () {},
                  ),

                  const SizedBox(height: 45),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {},
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

          // ======= Avatar =======
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: bg,
                child: const CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  backgroundImage: AssetImage('assets/images/avatar.png'),
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 65,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFD9D9D9).withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: green),
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
