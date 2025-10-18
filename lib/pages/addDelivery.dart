import 'dart:io';

import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/components/custom_TextField.dart';
import 'package:delivery_app/components/custom_dialog.dart';
import 'package:delivery_app/services/upload_img.dart';
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
  final TextEditingController noteCtrl = TextEditingController();
  final ImagePicker picker = ImagePicker();

  Map<String, dynamic>? _selectedReceiver;
  File? deliveryImage;
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

                    // รูปสินค้า
                    RectAvatar(width: 350, height: 180, borderRadius: 5),

                    const SizedBox(height: 12),

                    // เลือกรูปสินค้า
                    buildTextField(
                      controller: TextEditingController(
                        text: deliveryImage != null
                            ? "เลือกรูปภาพเรียบร้อยแล้ว"
                            : "",
                      ),
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

                    // เลือกผู้รับ (Widget ที่กดได้)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "  เลือกผู้รับ",
                            style: TextStyle(
                              color: Color(0xFFBBB9B9),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _showReceiverPicker,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    BootstrapIcons.send_fill,
                                    color: Colors.black87,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _selectedReceiver != null
                                        ? _selectedReceiver!['username']
                                        : "กรอกข้อมูลเพื่อค้นหาผู้รับสินค้า",
                                    style: TextStyle(
                                      color: _selectedReceiver != null
                                          ? Colors.black87
                                          : Color(0xFF848484),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ใส่คำอธิบาย
                    buildTextField(
                      controller: noteCtrl,
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

                    // ปุ่มย้อนกลับ / เรียกไรเดอร์
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
                              ),
                              onPressed: _submitting
                                  ? null
                                  : () => context.pop(),
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
                              ),
                              onPressed: _submitting ? null : addDeliveryItem,
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
            ? Image.asset("assets/images/Delivery Image.png", fit: BoxFit.fill)
            : Image.file(deliveryImage!, fit: BoxFit.fill),
      ),
    );
  }

  void _showReceiverPicker() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) =>
            ReceiverPickerSheet(scrollController: controller),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedReceiver = result;
      });
    }
  }

  void addDeliveryItem() async {
    if (deliNameCtrl.text.trim().isEmpty) {
      await showWarningSnackBar(
        context,
        title: "ข้อมูลไม่ครบ",
        message: "กรุณากรอกชื่อสินค้า",
      );
      return;
    }
    if (_selectedReceiver == null) {
      await showWarningSnackBar(
        context,
        title: "ข้อมูลไม่ครบ",
        message: "กรุณาเลือกผู้รับสินค้า",
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final collectionName = "delivery";

      String itemImageUrl = "";
      if (deliveryImage != null) {
        final result = await UploadImgService.uploadFile(
          file: File(deliveryImage!.path),
          folder: '$collectionName/item_images',
        );
        itemImageUrl = result.secureUrl ?? result.url ?? "";
        if (itemImageUrl.isEmpty) {
          throw Exception("อัปโหลดรูปสำเร็จ แต่ไม่ได้รับ URL");
        }
      }

      final docRef = FirebaseFirestore.instance
          .collection(collectionName)
          .doc();
      final data = {
        "did": docRef.id,
        "item_name": deliNameCtrl.text.trim(),
        "item_image": itemImageUrl,
        "sender_uid": "senderUid", // TODO: แก้ไข
        "receiver_uid": _selectedReceiver!['uid'],
        "pickup_addr_id": "test", // TODO: แก้ไข
        "dropoff_addr_id": "test", // TODO: แก้ไข
        "note": noteCtrl.text.trim(),
        "created_at": FieldValue.serverTimestamp(),
        "status": "pending",
      };

      await docRef.set(data);

      if (!mounted) return;
      await showSuccessDialog(
        context,
        message: "สร้างรายการจัดส่งสำเร็จ!",
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(
        context,
        title: "เกิดข้อผิดพลาด",
        message: "เกิดข้อผิดพลาด: ${e.toString()}",
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }
}

// =======================================================================
// ==       Receiver Picker Bottom Sheet (UPDATED SEARCH LOGIC)       ==
// =======================================================================

class ReceiverPickerSheet extends StatefulWidget {
  final ScrollController scrollController;
  const ReceiverPickerSheet({super.key, required this.scrollController});

  @override
  State<ReceiverPickerSheet> createState() => _ReceiverPickerSheetState();
}

class _ReceiverPickerSheetState extends State<ReceiverPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];
  bool isLoading = false;
  String searchQuery = '';
  String searchType = 'phone';

  Future<void> searchUsers() async {
    final searchTerm = _searchCtrl.text.trim();
    if (searchTerm.isEmpty) return;

    setState(() {
      isLoading = true;
      searchQuery = searchTerm;
      searchResults = [];
    });

    try {
      Query query = FirebaseFirestore.instance.collection('users');

      // --- vvv NEW LOGIC vvv ---
      if (searchType == 'phone') {
        // ค้นหาเบอร์โทรแบบตรงตัว
        query = query.where('phone', isEqualTo: searchTerm);
      } else if (searchType == 'username') {
        // ค้นหาชื่อผู้ใช้แบบ "starts-with"
        // query จะหาเอกสารทั้งหมดที่ field 'username'
        // เริ่มต้นด้วยคำที่ใช้ค้นหา (searchTerm)
        query = query
            .where('username', isGreaterThanOrEqualTo: searchTerm)
            .where('username', isLessThanOrEqualTo: '$searchTerm\uf8ff');
      }
      // --- ^^^ NEW LOGIC ^^^ ---

      final querySnapshot = await query.get();

      final users = querySnapshot.docs.map((doc) {
        final data =
            doc.data()! as Map<String, dynamic>; // Ensure data is a Map
        data['uid'] = doc.id;
        return data;
      }).toList();

      if (mounted) {
        setState(() {
          searchResults = users;
        });
      }
    } catch (e) {
      if (mounted) {
        await showErrorDialog(
          context,
          title: "เกิดข้อผิดพลาด",
          message: "เกิดข้อผิดพลาดในการค้นหา: $e",
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget buildUserCard(Map<String, dynamic> user) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, user),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 5,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 35,
              backgroundImage: NetworkImage(
                user['avatar'] ?? 'https://via.placeholder.com/150',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('ชื่อ', user['username'] ?? 'N/A'),
                  const SizedBox(height: 4),
                  _buildInfoRow('เบอร์โทรศัพท์', user['phone'] ?? 'N/A'),
                  const SizedBox(height: 4),
                  _buildInfoRow(
                    'ตำแหน่งที่รับ',
                    'เชียงยืน, นาทอง, มหาสารคาม 44160',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black87,
          fontFamily: 'Sarabun',
        ),
        children: [
          TextSpan(
            text: '$label : ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // แถบค้นหา
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F19),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 20, 10, 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: const Color(0xFF111827),
                            value: searchType,
                            items: const [
                              DropdownMenuItem(
                                value: 'phone',
                                child: Text(
                                  "เบอร์โทร",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'username',
                                child: Text(
                                  "ชื่อผู้ใช้",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  searchType = newValue;
                                  _searchCtrl.clear();
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                          ),
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: searchType == 'phone'
                                ? "ค้นหาจากเบอร์โทร"
                                : "ค้นหาจากชื่อผู้ใช้",
                            hintStyle: const TextStyle(fontSize: 14),
                            filled: true,
                            fillColor: const Color(0xFFF3F4F6),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                          ),
                          keyboardType: searchType == 'phone'
                              ? TextInputType.phone
                              : TextInputType.text,
                          onSubmitted: (_) => searchUsers(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: searchUsers,
                        icon: const Icon(
                          Icons.search,
                          color: Colors.black54,
                          size: 18,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFF3F4F6),
                          padding: const EdgeInsets.all(14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ส่วนแสดงผลลัพธ์
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : searchResults.isEmpty
                ? Center(
                    child: Text(
                      searchQuery.isEmpty
                          ? "กรอกข้อมูลเพื่อค้นหา"
                          : "ไม่พบข้อมูลจาก: $searchQuery",
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8),
                    controller: widget.scrollController,
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final user = searchResults[index];
                      return buildUserCard(user);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
