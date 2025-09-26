import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ✅ เพิ่มเติม: ใช้ Firebase Auth + init แบบปลอดภัยในฟังก์ชัน
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  List<bool> isSelected = [true, false]; // ค่าเริ่มต้น = ผู้ใช้
  String role = 'ผู้ใช้';
  bool rememberMe = false; // state ของ checkbox
  bool obscureText = true; // ค่าเริ่มต้น: ซ่อนรหัสผ่าน

  // Controller เก็บค่าชื่อผู้ใช้/รหัสผ่าน
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // ===== ฟังก์ชัน Login (อีเมลหรือชื่อผู้ใช้) =====
  Future<void> loginUser() async {
    final inputUser = usernameController.text.trim();
    final inputPass = passwordController.text.trim();

    if (inputUser.isEmpty || inputPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบ')),
      );
      return;
    }

    try {
      // ✅ กันพัง: ถ้ายังไม่ initialize ให้ทำตรงนี้
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      String? emailToLogin;

      if (inputUser.contains('@')) {
        // ผู้ใช้กรอกอีเมลโดยตรง
        emailToLogin = inputUser;
      } else {
        // ผู้ใช้กรอก "ชื่อผู้ใช้" → หาอีเมลจาก Firestore
        // รองรับทั้ง 'users' และ 'user' (กันกรณีสะกดไม่เหมือนในโปรเจ็กต์)
        final usersCol = FirebaseFirestore.instance.collection('users');
        final userCol = FirebaseFirestore.instance.collection('user');

        QuerySnapshot snap = await usersCol
            .where('username', isEqualTo: inputUser)
            .limit(1)
            .get();

        if (snap.docs.isEmpty) {
          // ลองอีกคอลเลกชัน
          snap = await userCol
              .where('username', isEqualTo: inputUser)
              .limit(1)
              .get();
        }

        if (snap.docs.isEmpty) {
          throw Exception('ไม่พบชื่อผู้ใช้');
        }

        final data = snap.docs.first.data() as Map<String, dynamic>;
        emailToLogin = (data['email'] ?? '').toString().trim();

        if (emailToLogin.isEmpty) {
          throw Exception('บัญชีนี้ไม่มีอีเมลสำหรับเข้าสู่ระบบ');
        }
      }

      // ✅ ล็อกอินด้วย Firebase Auth
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailToLogin,
        password: inputPass,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เข้าสู่ระบบสำเร็จ ✅')),
      );

      // ไปหน้า home (เปลี่ยนเป็นเส้นทางของคุณได้)
      context.push('/home');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auth Error: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
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
          child: SingleChildScrollView(
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
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                offset: Offset(0, 4),
                                blurRadius: 4,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.4),
                                        blurRadius: 6,
                                        offset: const Offset(0, 1),
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
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14, 6, 14, 6,
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
                                          color: Color(0x4016A34A),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          height: 30,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(0xFF313131),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                offset: Offset(0, 4),
                                blurRadius: 4,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: ToggleButtons(
                            borderRadius: BorderRadius.circular(8),
                            isSelected: isSelected,
                            fillColor: const Color(0xFF16A34A),
                            selectedColor: Colors.white,
                            color: Colors.white,
                            renderBorder: false,
                            children: const [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text("ผู้ใช้"),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text("ไรเดอร์"),
                              ),
                            ],
                            onPressed: (index) {
                              setState(() {
                                for (int i = 0; i < isSelected.length; i++) {
                                  isSelected[i] = (i == index);
                                }
                                role = (index == 0) ? 'ผู้ใช้' : 'ไรเดอร์';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 80),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                "เข้าสู่ระบบ$role",
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
                              const SizedBox(width: 10),
                              (role == "ผู้ใช้")
                                  ? const Icon(
                                      BootstrapIcons.person_circle,
                                      size: 28,
                                      color: Colors.white,
                                    )
                                  : SvgPicture.asset(
                                      'assets/icons/rider.svg',
                                      width: 28,
                                      height: 28,
                                    ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: (role == 'ผู้ใช้')
                                ? const Text(
                                    'ยินดีต้อนรับกลับ! เข้าสู่ระบบเพื่อจัดส่งของได้เลย',
                                    style: TextStyle(color: Color(0xFFBBB9B9)),
                                  )
                                : const Text(
                                    'ยินดีต้อนรับกลับนักซิ่ง! เข้าสู่ระบบเพื่อแว้นนส่งของได้เลยยย!!',
                                    style: TextStyle(color: Color(0xFFBBB9B9)),
                                  ),
                          ),
                          const SizedBox(height: 30),

                          // ======= ช่องกรอก "อีเมลหรือชื่อผู้ใช้" =======
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'อีเมลหรือชื่อผู้ใช้',
                                    style: TextStyle(
                                      color: Color(0xFFBBB9B9),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: usernameController,
                                  style: const TextStyle(color: Colors.black),
                                  decoration: InputDecoration(
                                    hintText: 'กรอกอีเมลหรือชื่อผู้ใช้',
                                    prefixIcon: const Icon(
                                      BootstrapIcons.person,
                                      color: Colors.black87,
                                      size: 20,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ======= ช่องกรอกรหัสผ่าน =======
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'รหัสผ่าน',
                                    style: TextStyle(
                                      color: Color(0xFFBBB9B9),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: passwordController,
                                  obscureText: obscureText,
                                  style: const TextStyle(color: Colors.black),
                                  decoration: InputDecoration(
                                    hintText: 'กรอกรหัสผ่าน',
                                    prefixIcon: const Icon(
                                      BootstrapIcons.lock,
                                      color: Colors.black87,
                                      size: 20,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        obscureText
                                            ? BootstrapIcons.eye
                                            : BootstrapIcons.eye_slash,
                                        color: Colors.black87,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          obscureText = !obscureText;
                                        });
                                      },
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // จดจำฉันไว้ + ลืมรหัสผ่าน
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Transform.scale(
                                    scale: 0.8,
                                    child: Checkbox(
                                      value: rememberMe,
                                      onChanged: (val) {
                                        setState(() {
                                          rememberMe = val ?? false;
                                        });
                                      },
                                      activeColor: const Color(0xFF16A34A),
                                    ),
                                  ),
                                  const Text(
                                    'จดจำฉันไว้',
                                    style: TextStyle(
                                      color: Color(0xFFBBB9B9),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("ไปหน้าลืมรหัสผ่าน"),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'ลืมรหัสผ่าน?',
                                  style: TextStyle(
                                    color: Color(0xFFBBB9B9),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ปุ่มเข้าสู่ระบบ
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              onPressed: loginUser,
                              child: const Text(
                                'เข้าสู่ระบบ',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "หรือ",
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF16A34A),
                                side: const BorderSide(
                                  color: Color(0xFF16A34A),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              onPressed: () {
                                context.push('/register');
                              },
                              child: const Text(
                                'สมัครบัญชีใหม่',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'การเข้าสู่ระบบแสดงว่าคุณยอมรับ ',
                                ),
                                TextSpan(
                                  text: 'เงื่อนไขการใช้บริการ',
                                  style: const TextStyle(
                                    color: Color(0xFF16A34A),
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      debugPrint(
                                        "เงื่อนไขการใช้บริการ clicked",
                                      );
                                    },
                                ),
                                const TextSpan(text: ' และ '),
                                TextSpan(
                                  text: 'นโยบายความเป็นส่วนตัว',
                                  style: const TextStyle(
                                    color: Color(0xFF16A34A),
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      debugPrint(
                                        "นโยบายความเป็นส่วนตัว clicked",
                                      );
                                    },
                                ),
                              ],
                            ),
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
      ),
    );
  }
}
