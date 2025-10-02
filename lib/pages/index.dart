import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/material.dart';

class Index extends StatefulWidget {
  const Index({super.key, this.initialIndex = 0});
  final int initialIndex; // รองรับอนาคตถ้าจะส่งค่าเริ่มจาก router

  @override
  State<Index> createState() => _IndexState();
}

class _IndexState extends State<Index> {
  static const Color kDarkBg = Color(0xFF111827);

  late int currentIndex;

  // เพจแต่ละแท็บ (ตัวอย่าง placeholder — ใส่หน้าแท้จริงของคุณแทนได้เลย)
  final List<Widget> pages = [
    HomeTab(),
    ShipmentTab(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,                // ให้ body ขยายใต้ bottom bar
      backgroundColor: kDarkBg,        // กันขอบขาวใต้ bottom bar
      body: IndexedStack(              // เก็บ state ของแต่ละแท็บ
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: currentIndex,
        onTap: (i) => setState(() => currentIndex = i),
      ),
    );
  }
}

/// -------------------- Bottom Nav (แบบภาพเดิม + ปรับเสถียร) --------------------
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const Color bg     = Color(0xFF0B0F19);  // พื้นหลังเข้ม
  static const Color white  = Colors.white;       // ไอคอน/ข้อความปิด
  static const Color active = Color(0xFF16A34A);  // เขียวแท็บที่เลือก

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: bg,
          boxShadow: [
            BoxShadow(
              blurRadius: 14,
              offset: Offset(0, -6),
              color: Colors.black26,
            )
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: NavItem(
                    icon: BootstrapIcons.house_fill,
                    label: 'หน้าแรก',
                    selected: currentIndex == 0,
                    onTap: () => onTap(0),
                  ),
                ),
                Expanded(
                  child: NavItem(
                    icon: BootstrapIcons.box_seam_fill,
                    label: 'การจัดส่ง',
                    selected: currentIndex == 1,
                    onTap: () => onTap(1),
                  ),
                ),
                Expanded(
                  child: NavItem(
                    icon: BootstrapIcons.person_fill,
                    label: 'โปรไฟล์',
                    selected: currentIndex == 2,
                    onTap: () => onTap(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NavItem extends StatelessWidget {
  const NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const Color active = BottomNavBar.active;
    const Color white  = BottomNavBar.white;

    final Color iconColor = selected ? active : white;
    final Color textColor = selected ? active : white.withOpacity(0.9);

    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 26, color: iconColor),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.0,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// -------------------- ตัวอย่างเพจของแต่ละแท็บ (แทนที่ด้วยหน้าจริงของคุณได้) --------------------
class HomeTab extends StatelessWidget {
  const HomeTab();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: _IndexState.kDarkBg,
      child: Center(child: Text('หน้าแรก')),
    );
  }
}

class ShipmentTab extends StatelessWidget {
  const ShipmentTab();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: _IndexState.kDarkBg,
      child: Center(child: Text('การจัดส่ง')),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: _IndexState.kDarkBg,
      child: Center(child: Text('โปรไฟล์')),
    );
  }
}
