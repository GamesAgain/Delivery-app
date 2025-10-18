import 'dart:io';

import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/components/custom_dialog.dart';
import 'package:delivery_app/services/upload_img.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class RegisterRiderPage extends StatefulWidget {
  final File? avatarImage; // รูปโปรไฟล์จากหน้าแรก
  final TextEditingController emailCtrl;
  final String? nameCtrl;
  final String? phoneCtrl;
  final String? passCtrl;
  final String? confirmCtrl;
  final String role;

  const RegisterRiderPage({
    super.key,
    required this.avatarImage,
    required this.emailCtrl,
    this.nameCtrl,
    this.phoneCtrl,
    this.passCtrl,
    this.confirmCtrl,
    required this.role,
  });

  @override
  State<RegisterRiderPage> createState() => _RegisterRiderPageState();
}

class _RegisterRiderPageState extends State<RegisterRiderPage> {
  final TextEditingController _plateCtrl = TextEditingController();
  final ImagePicker picker = ImagePicker();
  File? verhicalImage; // รูปยานพาหนะ
  bool _submitting = false;

  @override
  void dispose() {
    _plateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF0B0F19),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
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
                                radius: 22,
                                backgroundColor: Colors.green,
                                child: Icon(
                                  BootstrapIcons.bag_check,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
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

                  // === Title ลงทะเบียนยานพาหนะ ===
                  Row(
                    children: [
                      const Text(
                        "ลงทะเบียนยานพาหนะ",
                        style: TextStyle(
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
                      SvgPicture.asset(
                        "assets/icons/rider.svg",
                        width: 28,
                        height: 28,
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "กรุณากรอกข้อมูลยานพาหนะเบื้องต้น",
                      style: TextStyle(
                        color: Color(0xFFBBB9B9),
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // รูปยานพาหนะ (สี่เหลี่ยม)
                  RectAvatar(width: 350, height: 180, borderRadius: 5),

                  const SizedBox(height: 12),

                  // เลือกรูปยานพาหนะ
                  buildTextField(
                    controller: TextEditingController(),
                    readOnly: true,
                    label: "เลือกรูปยานพาหนะ",
                    hint: "กรุณาเลือกรูปยานพาหนะ",
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
                          icon: const Icon(Icons.camera_alt, color: Colors.black87),
                        ),
                        IconButton(
                          onPressed: () => pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),

                  // กรอกเลขทะเบียน
                  buildTextField(
                    controller: _plateCtrl,
                    readOnly: false,
                    label: "กรอกเลขทะเบียน",
                    hint: "กรุณากรอกเลขทะเบียนรถ",
                    prefix: const Icon(
                      BootstrapIcons.postcard_fill,
                      color: Colors.black87,
                      size: 20,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ปุ่มย้อนกลับ / สมัครบัญชีไรเดอร์
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF16A34A),
                              side: const BorderSide(
                                color: Color(0xFF16A34A),
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: _submitting ? null : () => context.pop(),
                            child: const Text(
                              "ย้อนกลับ",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: _submitting ? null : registerRider,
                            child: _submitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    "สมัครบัญชีไรเดอร์",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ไปหน้า Login
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
    );
  }

  Future<void> pickImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        verhicalImage = File(pickedFile.path);
      });
    }
  }

  Widget RectAvatar({
    double width = 252,
    double height = 139,
    double borderRadius = 5,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: verhicalImage == null
            ? Image.asset("assets/images/vehicle_placeholder_700x360.png", fit: BoxFit.cover)
            : Image.file(verhicalImage!, fit: BoxFit.cover),
      ),
    );
  }

  Future<void> registerRider() async {
    if (_submitting) return;
    try {
      // ✅ ตรวจข้อมูลพื้นฐานที่ส่งมาจากหน้าแรก + หน้านี้
      if (widget.emailCtrl.text.trim().isEmpty ||
          (widget.nameCtrl ?? '').trim().isEmpty ||
          (widget.phoneCtrl ?? '').trim().isEmpty ||
          (widget.passCtrl ?? '').trim().isEmpty ||
          (widget.confirmCtrl ?? '').trim().isEmpty ||
          _plateCtrl.text.trim().isEmpty) {
        await showErrorDialog(
          context,
          title: "ข้อมูลไม่ครบ",
          message: "กรุณากรอกข้อมูลให้ครบทุกช่องก่อนดำเนินการต่อ",
        );
        return;
      }

      if (widget.passCtrl!.trim() != widget.confirmCtrl!.trim()) {
        await showErrorDialog(
          context,
          title: "รหัสผ่านไม่ตรงกัน",
          message: "กรุณากรอกยืนยันรหัสผ่านให้ตรงกับรหัสผ่าน",
        );
        return;
      }

      setState(() => _submitting = true);

      // ===== สร้างบัญชี Firebase Auth =====
      final userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: widget.emailCtrl.text.trim(),
        password: widget.passCtrl!.trim(),
      );
      // ===== อัปโหลดรูปไป Cloudinary ถ้ามี =====
      String avatarUrl;
      if (widget.avatarImage != null) {
        final result = await UploadImgService.uploadFile(
          file: File(widget.avatarImage!.path),
          folder: 'riders/avatars',
        );
        avatarUrl = result.secureUrl ?? result.url ?? "";
        if (avatarUrl.isEmpty) {
          throw Exception("อัปโหลดรูปสำเร็จ แต่ไม่ได้รับ URL");
        }
      } else {
        avatarUrl = "assets/images/avatar.png";
      }


      // ===== อัปโหลดรูปยานพาหนะไป Cloudinary (ถ้ามี) =====
      String vehicleImageUrl;
      if (verhicalImage != null) {
        final result = await UploadImgService.uploadFile(
          file: File(verhicalImage!.path),
          folder: 'riders/vehicles',
        );
        vehicleImageUrl = result.secureUrl ?? result.url ?? "";
        if (vehicleImageUrl.isEmpty) {
          throw Exception("อัปโหลดรูปสำเร็จ แต่ไม่ได้รับ URL");
        }
      } else {
        // ถ้าไม่เลือกรูปยานพาหนะ จะใช้ภาพ default (asset)
        vehicleImageUrl = "assets/images/vehicle_placeholder_700x360.png";
      }

      // ===== บันทึกข้อมูลลง Firestore (collection: riders) =====
      await FirebaseFirestore.instance
          .collection("riders")
          .doc(userCred.user!.uid)
          .set({
        "uid": userCred.user!.uid,
        "email": widget.emailCtrl.text.trim(),
        "phone": widget.phoneCtrl,
        "username": widget.nameCtrl,
        "role": widget.role,
        "vehicle_plate": _plateCtrl.text.trim(),
        "vehicle_image": vehicleImageUrl,
        "avatar": avatarUrl, // รูปโปรไฟล์จากหน้าแรก (ถ้ามี)
        "created_at": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      await showSuccessDialog(
        context,
        message: "สมัครบัญชีสำเร็จ",
        onOk: () => context.go("/"), // กลับหน้า Login
      );
    } on FirebaseAuthException catch (e) {
      String err = "";
      if (e.code == 'email-already-in-use') {
        err = "อีเมลนี้ถูกใช้งานแล้ว";
      } else if (e.code == 'weak-password') {
        err = "รหัสผ่านสั้นเกินไป";
      } else if (e.code == 'invalid-email') {
        err = "รูปแบบอีเมลไม่ถูกต้อง";
      } else {
        err = e.message ?? "เกิดข้อผิดพลาดไม่ทราบสาเหตุ";
      }
      await showErrorDialog(context, title: "สมัครไม่สำเร็จ", message: err);
    } catch (e) {
      await showErrorDialog(context, title: "เกิดข้อผิดพลาด", message: e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// ===== helper textfield (เหมือนหน้าแรก เพื่อโทนเดียวกัน) =====
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
        Text(label, style: const TextStyle(color: Color(0xFFBBB9B9), fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: readOnly,
          style: const TextStyle(color: Colors.black),
          obscureText: obscure,
          keyboardType: type,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF848484), fontSize: 12),
            prefixIcon: prefix,
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFC7C0C0), width: 1.5),
            ),
          ),
        ),
      ],
    ),
  );
}
