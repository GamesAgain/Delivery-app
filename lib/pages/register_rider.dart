import 'dart:io';

import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class RegisterRiderPage extends StatefulWidget {
  // final String? imagePath;
  // final TextEditingController emailCtrl;
  // final String? nameCtrl;
  // final String? phoneCtrl;
  // final String? passCtrl;
  // final String? confirmCtrl;
  // final String role;
  const RegisterRiderPage({
    super.key,
    // required this.imagePath,
    // required this.emailCtrl,
    // this.nameCtrl,
    // this.phoneCtrl,
    // this.passCtrl,
    // this.confirmCtrl,
    // required this.role,
  });

  @override
  State<RegisterRiderPage> createState() => _RegisterRiderPageState();
}

class _RegisterRiderPageState extends State<RegisterRiderPage> {
  final TextEditingController _plateCtrl = TextEditingController();
  File? avatarImage;
  final ImagePicker picker = ImagePicker();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF0B0F19),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
          child: Container(
            height: double.infinity,
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

                  // === Title ลงทะเบียนยานพาหนะ ===
                  Row(
                    children: [
                      Text(
                        "ลงทะเบียนยานพาหนะ",
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
                      SvgPicture.asset(
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
                      "กรุณากรอกข้อมูลยานพาหนะเบื้องต้น",
                      style: const TextStyle(
                        color: Color(0xFFBBB9B9),
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  RectAvatar(width: 350, height: 180, borderRadius: 5),

                  const SizedBox(height: 12),

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

                  const SizedBox(height: 24),

                  // === ปุ่มสมัคร ===
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 140),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              minimumSize: Size(0, 48),
                            ),
                            onPressed: () {},
                            child: const Text(
                              "ย้อนกลับ",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 200),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              minimumSize: Size(0, 48),
                            ),
                            onPressed: () {},
                            child: const Text(
                              "สมัครบัญชีไรเดอร์",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
        child: avatarImage == null
            ? Image.asset("assets/images/avatar.png", fit: BoxFit.cover)
            : Image.file(avatarImage!, fit: BoxFit.cover),
      ),
    );
  }
}

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
            hintStyle: const TextStyle(color: Color(0xFF848484), fontSize: 12),
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
