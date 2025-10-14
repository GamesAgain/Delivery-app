import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: bg,
          height: 170,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(15, 45, 0, 25),
                child: Text(
                  'ประวัติการจัดส่ง',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(1.5, 1.5),
                        blurRadius: 2.0,
                        color: green,
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(tabs.length, (index) {
                  final isActive = _selectedIndex == index;
                  return Column(
                    children: [
                      FilledButton(
                        onPressed: () {
                          setState(() => _selectedIndex = index);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: green.withOpacity(0.08),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          tabs[index],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 3,
                        width: isActive ? 100 : 0,
                        decoration: BoxDecoration(
                          color: isActive ? green : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9).withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF16A34A).withOpacity(0.3),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      BootstrapIcons.box,
                      color: Colors.white,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'ผู้ส่ง',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'ผู้รับ',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'ไรเดอร์กำลังเดินทางไปรับสินค้า',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'รายละเอียด',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
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
