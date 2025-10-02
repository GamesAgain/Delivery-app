import 'dart:developer';
import 'dart:io';

import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:delivery_app/pages/register_rider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  final String role;
  const RegisterPage({super.key, required this.role});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool obscurePassword = true;
  bool obscureConfirm = true;
  File? avatarImage;
  final ImagePicker picker = ImagePicker();

  final Future<FirebaseApp> firebase = Firebase.initializeApp();

  // ✅ controllers
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();
  final TextEditingController confirmCtrl = TextEditingController();

  Widget buildTextField({
    required String label,
    required String hint,
    required Icon prefix,
    required TextEditingController controller,
    bool obscure = false,
    Widget? suffix,
    TextInputType? type,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFFBBB9B9), fontSize: 12),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            readOnly: readOnly,
            style: const TextStyle(color: Colors.black),
            obscureText: obscure,
            keyboardType: type,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF848484),
                fontSize: 12,
              ),
              prefixIcon: prefix,
              suffixIcon: suffix,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFFC7C0C0),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Register method
  Future<void> register() async {
    try {
      if (passCtrl.text != confirmCtrl.text) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("รหัสผ่านไม่ตรงกัน")));
        return;
      }

      // 1) สมัคร Auth ด้วย Email จริง
      final userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailCtrl.text.trim(),
            password: passCtrl.text.trim(),
          );

      // 2) เลือก collection ตาม role
      final collectionName = (widget.role == "ผู้ใช้") ? "users" : "riders";

      // 3) กำหนด avatar path
      String avatarPath;
      if (avatarImage != null) {
        avatarPath = avatarImage!.path; // local file path
      } else {
        avatarPath = "assets/images/avatar.png"; // default asset
      }

      // 4) บันทึกข้อมูลลง Firestore
      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(userCred.user!.uid)
          .set({
            "uid": userCred.user!.uid,
            "email": emailCtrl.text.trim(),
            "phone": phoneCtrl.text.trim(),
            "username": nameCtrl.text.trim(),
            "role": widget.role,
            "avatar": avatarPath,
            "created_at": FieldValue.serverTimestamp(),
          });

      log("สมัครสำเร็จ ✅ -> $collectionName");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("สมัครสมาชิก${widget.role}สำเร็จ")),
      );

      context.go("/"); // ไปหน้า Login
    } on FirebaseAuthException catch (e) {
      log("Auth Error: ${e.message}");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาด: ${e.message}")));
    } catch (e) {
      log("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF0B0F19),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
          child: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    // === Logo Delivery ===
                    Row(
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
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.green,
                                  child: Icon(
                                    BootstrapIcons.bag_check,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
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
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // === Title สมัครสมาชิก ===
                    Row(
                      children: [
                        Text(
                          "สมัครสมาชิก${widget.role}",
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
                        const SizedBox(width: 8),
                        (widget.role == "ผู้ใช้")
                            ? const Icon(
                                BootstrapIcons.person_circle,
                                size: 28,
                                color: Colors.white,
                              )
                            : SvgPicture.asset(
                                "assets/icons/rider.svg",
                                width: 28,
                                height: 28,
                              ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.role == "ผู้ใช้"
                            ? "ยินดีต้อนรับ สมัครบัญชีผู้ใช้เพื่อรับ/ส่งสินค้า"
                            : "ยินดีต้อนรับ สมัครบัญชีไรเดอร์เพื่อบริการจัดส่งสินค้า",
                        style: const TextStyle(
                          color: Color(0xFFBBB9B9),
                          fontSize: 14,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // === Avatar ===
                    CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.white,
                      child: ClipOval(
                        child: avatarImage == null
                            ? Image.asset(
                                "assets/images/avatar.png",
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                avatarImage!,
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // === เลือกรูป ===
                    buildTextField(
                      controller: TextEditingController(),
                      readOnly: true,
                      label: "เลือกรูปโปรไฟล์",
                      hint: "กรุณาเลือกรูปโปรไฟล์",
                      prefix: const Icon(
                        BootstrapIcons.image,
                        color: Colors.black87,
                        size: 20,
                      ),
                      suffix: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => pickImage(ImageSource.camera),
                            icon: const Icon(
                              Icons.camera_alt,
                              color: Colors.black87,
                            ),
                          ),
                          IconButton(
                            onPressed: () => pickImage(ImageSource.gallery),
                            icon: const Icon(
                              Icons.photo_library,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // === Email ===
                    buildTextField(
                      controller: emailCtrl,
                      label: "อีเมล",
                      hint: "กรอกอีเมล",
                      type: TextInputType.emailAddress,
                      prefix: const Icon(Icons.email, color: Colors.black87),
                    ),

                    // === Phone ===
                    buildTextField(
                      controller: phoneCtrl,
                      label: "หมายเลขโทรศัพท์",
                      hint: "กรอกหมายเลขโทรศัพท์",
                      type: TextInputType.phone,
                      prefix: const Icon(Icons.phone, color: Colors.black87),
                    ),

                    // === Username ===
                    buildTextField(
                      controller: nameCtrl,
                      label: "ชื่อผู้ใช้",
                      hint: "กรอกชื่อผู้ใช้",
                      prefix: const Icon(
                        BootstrapIcons.person_badge,
                        color: Colors.black87,
                      ),
                    ),

                    // === Password ===
                    buildTextField(
                      controller: passCtrl,
                      label: "รหัสผ่าน",
                      hint: "กรอกรหัสผ่าน",
                      obscure: obscurePassword,
                      prefix: const Icon(
                        BootstrapIcons.lock,
                        color: Colors.black87,
                      ),
                      suffix: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? BootstrapIcons.eye
                              : BootstrapIcons.eye_slash,
                        ),
                        onPressed: () {
                          setState(() => obscurePassword = !obscurePassword);
                        },
                      ),
                    ),

                    // === Confirm Password ===
                    buildTextField(
                      controller: confirmCtrl,
                      label: "ยืนยันรหัสผ่าน",
                      hint: "กรอกยืนยันรหัสผ่าน",
                      obscure: obscureConfirm,
                      prefix: const Icon(
                        BootstrapIcons.lock,
                        color: Colors.black87,
                      ),
                      suffix: IconButton(
                        icon: Icon(
                          obscureConfirm
                              ? BootstrapIcons.eye
                              : BootstrapIcons.eye_slash,
                        ),
                        onPressed: () {
                          setState(() => obscureConfirm = !obscureConfirm);
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // === ปุ่มสมัคร ===
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          if (widget.role != "ผู้ใช้") {
                            // Navigator.of(context).push(
                            //   MaterialPageRoute(
                            //     builder: (_) => RegisterRiderPage(
                            //       role: widget.role,
                            //       imagePath:
                            //           avatarImage?.path ??
                            //           "assets/images/avatar.png",
                            //       emailCtrl: emailCtrl,
                            //       nameCtrl: nameCtrl.text,
                            //       phoneCtrl: phoneCtrl.text,
                            //       passCtrl: passCtrl.text,
                            //       confirmCtrl: confirmCtrl.text,
                            //     ),
                            //   ),
                            // );
                          } else {
                            register();
                          }
                        },
                        child: Text(
                          widget.role == "ผู้ใช้" ? "สมัครสมาชิก" : "ต่อไป",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // === ไปหน้า Login ===
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        children: [
                          const TextSpan(text: "มีบัญชีผู้ใช้อยู่แล้วใช่มั้ย "),
                          TextSpan(
                            text: "เข้าสู่ระบบเลย!",
                            style: const TextStyle(
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                context.push('/');
                              },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pickImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        avatarImage = File(pickedFile.path);
      });
    }
  }
}
