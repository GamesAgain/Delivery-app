import 'dart:async'; // ต้อง import Timer ด้วย
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class RegisterChoicePage extends StatefulWidget {
  const RegisterChoicePage({super.key});

  @override
  State<RegisterChoicePage> createState() => _RegisterChoicePageState();
}

class _RegisterChoicePageState extends State<RegisterChoicePage> {
  bool showRider = true;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    // ตั้ง Timer ให้สลับรูปทุก 2 วิ
    timer = Timer.periodic(const Duration(seconds: 3), (t) {
      setState(() {
        showRider = !showRider;
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel(); // ยกเลิก timer ตอนออกจากหน้า
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //--- ส่วนของ Backgroud  ---
      body: Container(
        height: double.infinity,
        color: const Color(0xFF0B0F19),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
          //--- ส่วนของ Card เนื้อหา ---
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(25),
            ),
            //--- ส่วนของเนื้อหา ---
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0x1416A34A),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              offset: Offset(0, 4),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        //--- ส่วนของ Icon Delivery ---
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Row(
                            children: [
                              //Icon Delivery
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.4),
                                      blurRadius: 6,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: const CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.green,
                                  child: Icon(
                                    BootstrapIcons.bag_check,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
          
                              // Label Delivery
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  6,
                                  14,
                                  6,
                                ),
                                child: Text(
                                  'Delivery',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF16A34A),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    shadows: const [
                                      Shadow(
                                        offset: Offset(0, 3),
                                        blurRadius: 4.0,
                                        color: Color(
                                          0x4016A34A,
                                        ), // เขียว + alpha 25%
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 800),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                      child: showRider
                          ? Image.asset(
                              'assets/images/riderInRegister.png',
                              key: const ValueKey("rider"),
                              width: double.infinity,
                              height: 300,
                              fit: BoxFit.cover,
                            )
                          : Image.asset(
                              'assets/images/userInRegister.png',
                              key: const ValueKey("user"),
                              width: double.infinity,
                              height: 300,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  //-- Title เข้าสู่ระบบ
                  Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      "สมัครบัญชีใหม่",
                      style: const TextStyle(
                        fontSize: 26,
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
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          color: Color(0xFFBBB9B9),
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(text: 'ยินดีต้อนรับสู่ '),
                          TextSpan(
                            text: 'Delivery',
                            style: TextStyle(color: Color(0xFF16A34A)),
                          ),
                          TextSpan(text: ' กรุณาเลือกบทบาทของคุณ!!'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  // ปุ่มสมัครผู้ใช้
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                      backgroundColor: const Color(0xFF16A34A),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: () {
                      context.push('/register/user');
                    },
                    icon: const Icon(
                      BootstrapIcons.person_circle,
                      color: Colors.white,
                    ),
                    label: const Text(
                      "สมัครบัญชีผู้ใช้",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 22),
                  // ปุ่มสมัครไรเดอร์
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                      side: const BorderSide(color: Color(0xFF16A34A)),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: () {
                      context.push('/register/rider');
                    },
                    icon: const Icon(
                      Icons.delivery_dining,
                      color: Color(0xFF16A34A),
                    ),
                    label: const Text(
                      "สมัครบัญชีไรเดอร์",
                      style: TextStyle(color: Color(0xFF16A34A)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      children: [
                        const TextSpan(text: 'มีบัญชีผู้ใช้อยู่แล้วใช่มั้ย '),
                        TextSpan(
                          text: 'เข้าสู่ระบบเลย!',
                          style: const TextStyle(
                            color: Color(0xFF16A34A),
                            fontSize: 13, // เขียว
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              context.push('/');
                            },
                        ),
                      ],
                    ),
                  ),
                ], 
              ),
            ),
          ),
        ),
      ),
    );
  }
}
