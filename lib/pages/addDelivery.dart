import 'dart:io';

import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:delivery_app/components/custom_TextField.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class AddDeliveryPage extends StatefulWidget {
  const AddDeliveryPage({super.key});

  @override
  State<AddDeliveryPage> createState() => _AddDeliveryPageState();
}

class _AddDeliveryPageState extends State<AddDeliveryPage> {
  final TextEditingController deliNameCtrl = TextEditingController();
  final TextEditingController telnoSearchCtrl = TextEditingController();
  final TextEditingController noteCtrl = TextEditingController();
  final ImagePicker picker = ImagePicker();
  File? deliveryImage; // รูปสินค้า
  bool _submitting = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
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
        
                      // === Title สร้างการจัดส่งสินค้า ===
                      Row(
                        children: [
                          const Text(
                            "สร้างการจัดส่งสินค้า",
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
                          "กรุณากรอกข้อมูลสินค้าเบื้องต้น",
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
                        label: "เลือกรูปสินค้า",
                        hint: "เลือกรูปสินค้าที่จะจัดส่ง",
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
        
                      // กรอกชื่อสินค้า
                      buildTextField(
                        controller: deliNameCtrl,
                        readOnly: false,
                        label: "กรอกชื่อสินค้า",
                        hint: "กรุณากรอกชื่อสินค้า",
                        prefix: const Icon(
                          BootstrapIcons.postcard_fill,
                          color: Colors.black87,
                          size: 20,
                        ),
                      ),
        
                      // เลือกผู้รับ
                      buildTextField(
                        controller: deliNameCtrl,
                        readOnly: false,
                        label: "เลือกผู้รับ",
                        hint: "กรอกเบอร์โทรเพื่อค้นหาผู้รับสินค้า",
                        prefix: const Icon(
                          BootstrapIcons.send_fill,
                          color: Colors.black87,
                          size: 20,
                        ),
                      ),

                       // ใส่คำอธิบาย
                      buildTextField(
                        controller: deliNameCtrl,
                        readOnly: false,
                        label: "คำอธิบายสินค้า",
                        hint: "เช่น แตก/หัก ง่าย, ระวังหก . . .",
                        prefix: const Icon(
                          BootstrapIcons.chat_left_text_fill,
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
                                onPressed: (){},
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
                                        "เรียกไรเดอร์",
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
        deliveryImage = File(pickedFile.path);
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
        child: deliveryImage == null
            ? Image.asset("assets/images/vehicle_placeholder_700x360.png", fit: BoxFit.cover)
            : Image.file(deliveryImage!, fit: BoxFit.cover),
      ),
    );
  }
}

