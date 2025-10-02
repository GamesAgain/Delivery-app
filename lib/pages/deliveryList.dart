import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DeliverylistPage extends StatefulWidget {
  const DeliverylistPage({super.key});

  @override
  State<DeliverylistPage> createState() => _DeliverylistPageState();
}

class _DeliverylistPageState extends State<DeliverylistPage> {
  static const Color bg = Color(0xFF0B0F19); // พื้นหลังเข้ม
  static const Color white = Colors.white; // ไอคอน/ข้อความปิด
  static const Color green = Color(0xFF16A34A); // เขียวแท็บที่เลือก

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
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Row(
                    children: [
                      Icon(BootstrapIcons.search, color: Colors.white70),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Find  your Delivery',
                          style: TextStyle(color: Colors.white60),
                        ),
                      ),
                    ],
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
                      onPressed: () {},
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
                      onPressed: () {},
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
                // ปรับสัดส่วนให้พอดีกับจอและไม่ซ้อนกับส่วนบน/ล่าง
                height: MediaQuery.of(context).size.height * 0.55,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // ===== การ์ดใบที่ 1 (ของเดิม ไม่แก้) =====
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0x0DD9D9D9),
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
                              const CircleAvatar(
                                radius: 32,
                                backgroundImage: AssetImage(
                                  'assets/images/test.webp',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Asus TUF Gaming F15',
                                        style: const TextStyle(
                                          color: white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Column(
                                            children: [
                                              Text(
                                                'ผู้ส่ง : สรายุทธ บุตรวงษ์',
                                                style: TextStyle(
                                                  color: white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                'ผู้รับ : เพ็ญพิชชา ดวงตา',
                                                style: TextStyle(
                                                  color: white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                left: 12,
                                              ),
                                              child: SizedBox(
                                                width: 85,
                                                height: 70,
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  child: Image.asset(
                                                    'assets/images/Status4.png',
                                                    key: const ValueKey("user"),
                                                    fit: BoxFit.fitHeight,
                                                  ),
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
                              const CircleAvatar(
                                radius: 12,
                                backgroundColor: green,
                                child: Icon(
                                  BootstrapIcons.box_seam,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2B9F5C),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              const CircleAvatar(
                                radius: 12,
                                backgroundColor: green,
                                child: Icon(
                                  Icons.pedal_bike,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2B9F5C),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              const CircleAvatar(
                                radius: 12,
                                backgroundColor: green,
                                child: Icon(
                                  Icons.pedal_bike,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2B9F5C),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: green,
                                child: SvgPicture.asset(
                                  'assets/icons/packageCorrect.svg',
                                  width: 14,
                                  height: 14,
                                ),
                              ),
                              const SizedBox(width: 3),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                                onPressed: () {},
                                child: Row(
                                  children: [
                                    Icon(
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
                              ),

                              const Spacer(),
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        BootstrapIcons.clock,
                                        color: Colors.white70,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Delivery Time',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Align(
                                    alignment: Alignment.center,
                                    child: Text(
                                      '1 hours',
                                      style: GoogleFonts.poppins(
                                        color: green,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ===== การ์ดใบที่ 2 (ของเดิม ไม่แก้) =====
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xCCFFFFFF),
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
                              const CircleAvatar(
                                radius: 32,
                                backgroundImage: AssetImage(
                                  'assets/images/test.webp',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Asus TUF Gaming F15',
                                        style: TextStyle(
                                          color: Color(0xFF0B0F19),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Column(
                                            children: [
                                              Text(
                                                'ผู้ส่ง : สรายุทธ บุตรวงษ์',
                                                style: TextStyle(
                                                  color: Color(0xFF0B0F19),
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                'ผู้รับ : เพ็ญพิชชา ดวงตา',
                                                style: TextStyle(
                                                  color: Color(0xFF0B0F19),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                left: 12,
                                              ),
                                              child: SizedBox(
                                                width: 85,
                                                height: 70,
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  child: Image.asset(
                                                    'assets/images/Status4.png',
                                                    key: const ValueKey("user"),
                                                    fit: BoxFit.fitHeight,
                                                  ),
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
                              const CircleAvatar(
                                radius: 12,
                                backgroundColor: green,
                                child: Icon(
                                  BootstrapIcons.box_seam,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2B9F5C),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              const CircleAvatar(
                                radius: 12,
                                backgroundColor: green,
                                child: Icon(
                                  Icons.pedal_bike,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2B9F5C),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              const CircleAvatar(
                                radius: 12,
                                backgroundColor: green,
                                child: Icon(
                                  Icons.pedal_bike,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2B9F5C),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: green,
                                child: SvgPicture.asset(
                                  'assets/icons/packageCorrect.svg',
                                  width: 14,
                                  height: 14,
                                ),
                              ),
                              const SizedBox(width: 3),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Color(0xFF0B0F19),
                                  foregroundColor: const Color(0xFF16A34A),
                                  side: const BorderSide(
                                    color: Color(0xFF16A34A),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                    horizontal: 8,
                                  ),
                                ),
                                onPressed: () {},
                                child: Row(
                                  children: [
                                    Icon(
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
                                          color: Color(0xFF16A34A),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        BootstrapIcons.clock,
                                        color: Color(0xFF0B0F19),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Delivery Time',
                                        style: GoogleFonts.poppins(
                                          color: Color(0xFF0B0F19),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Align(
                                    alignment: Alignment.center,
                                    child: Text(
                                      '1 hours',
                                      style: GoogleFonts.poppins(
                                        color: green,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),

                    const SizedBox(height: 65), // กันชนท้ายเวลาเลื่อน
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
