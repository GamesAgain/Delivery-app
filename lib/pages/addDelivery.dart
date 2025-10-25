import 'dart:io';

import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/components/custom_TextField.dart';
import 'package:delivery_app/components/custom_dialog.dart';
import 'package:delivery_app/services/upload_img.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as ll;

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
  String? _pickupAddressId;
  String? _dropoffAddressId;
  List<Map<String, dynamic>> _pickupAddresses = const [];
  List<Map<String, dynamic>> _dropoffAddresses = const [];
  bool _isLoadingAddresses = false;
  File? deliveryImage;
  bool _submitting = false;
  static const int _initialStatusCode = 1;
  static const String _initialStatusLabel = "รอไรเดอร์มารับสินค้า";
  final fm.MapController _mapController = fm.MapController();
  ll.LatLng? _receiverLatLng;
  static const ll.LatLng _initialMapCenter = ll.LatLng(13.736717, 100.523186);

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
                                  if (_isLoadingAddresses) ...[
                                    const SizedBox(width: 8),
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_selectedReceiver != null) ...[
                      const SizedBox(height: 12),
                      _buildAddressSelectionSection(),
                      const SizedBox(height: 16),
                      _buildReceiverMapSection(),
                    ],

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
      await _onReceiverSelected(result);
    }
  }

  Future<void> _onReceiverSelected(Map<String, dynamic> receiver) async {
    final receiverUid = receiver['uid'] as String?;
    final sender = FirebaseAuth.instance.currentUser;

    if (receiverUid == null || receiverUid.isEmpty) {
      await showErrorDialog(
        context,
        title: "เกิดข้อผิดพลาด",
        message: "ไม่พบข้อมูลผู้รับ กรุณาลองใหม่อีกครั้ง",
      );
      return;
    }

    if (sender == null) {
      await showErrorDialog(
        context,
        title: "เกิดข้อผิดพลาด",
        message: "ไม่สามารถระบุผู้ส่งได้ กรุณาเข้าสู่ระบบอีกครั้ง",
      );
      return;
    }

    if (receiverUid == sender.uid) {
      await showWarningSnackBar(
        context,
        title: "เลือกผู้รับไม่สำเร็จ",
        message: "คุณไม่สามารถเลือกตัวเองเป็นผู้รับสินค้าได้",
      );
      return;
    }

    setState(() {
      _selectedReceiver = receiver;
      _pickupAddressId = null;
      _dropoffAddressId = null;
      _isLoadingAddresses = true;
      _pickupAddresses = const [];
      _dropoffAddresses = const [];
      _receiverLatLng = null;
    });

    try {
      final pickupAddresses = await _fetchAddressesForUser(sender.uid);
      final dropoffAddresses = await _fetchAddressesForUser(receiverUid);

      final pickupId = _resolveDefaultAddressId(pickupAddresses);
      final dropoffId = _resolveDefaultAddressId(dropoffAddresses);
      final pickupAddress =
          _findAddressById(pickupAddresses, pickupId) ?? (pickupAddresses.isEmpty ? null : pickupAddresses.first);
      final dropoffAddress =
          _findAddressById(dropoffAddresses, dropoffId) ?? (dropoffAddresses.isEmpty ? null : dropoffAddresses.first);
      final receiverLocation = _toLatLng(dropoffAddress);

      if (!mounted) return;

      setState(() {
        _pickupAddresses = pickupAddresses;
        _dropoffAddresses = dropoffAddresses;
        _pickupAddressId = pickupAddress?['addr_id'] as String?;
        _dropoffAddressId = dropoffAddress?['addr_id'] as String?;
        _receiverLatLng = receiverLocation;
      });

      _moveMapTo(receiverLocation);

      if (pickupAddresses.isEmpty) {
        await showWarningSnackBar(
          context,
          title: "ข้อมูลไม่ครบ",
          message: "ไม่พบที่อยู่รับสินค้าของคุณ กรุณาเพิ่มที่อยู่เริ่มต้น",
        );
      }

      if (dropoffAddresses.isEmpty) {
        await showWarningSnackBar(
          context,
          title: "ข้อมูลไม่ครบ",
          message: "ไม่พบที่อยู่จัดส่งของผู้รับ กรุณาให้ผู้รับเพิ่มที่อยู่",
        );
      }
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(
        context,
        title: "เกิดข้อผิดพลาด",
        message: "ไม่สามารถโหลดที่อยู่ได้: $e",
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAddresses = false;
        });
      }
    }
  }

  Future<File?> _selectInitialStatusImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _StatusImagePickerSheet(),
    );

    if (source == null) {
      return null;
    }

    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) {
      return null;
    }

    return File(pickedFile.path);
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
    if (_pickupAddressId == null || _pickupAddressId!.isEmpty) {
      await showWarningSnackBar(
        context,
        title: "ข้อมูลไม่ครบ",
        message: "กรุณาตั้งค่าที่อยู่รับสินค้าของคุณ",
      );
      return;
    }
    if (_dropoffAddressId == null || _dropoffAddressId!.isEmpty) {
      await showWarningSnackBar(
        context,
        title: "ข้อมูลไม่ครบ",
        message: "ไม่พบที่อยู่จัดส่งของผู้รับ",
      );
      return;
    }

    final senderUid = FirebaseAuth.instance.currentUser?.uid;
    if (senderUid == null || senderUid.isEmpty) {
      await showErrorDialog(
        context,
        title: "เกิดข้อผิดพลาด",
        message: "ไม่สามารถระบุผู้ส่งได้ กรุณาเข้าสู่ระบบอีกครั้ง",
      );
      return;
    }

    final statusImageFile = await _selectInitialStatusImage();
    if (statusImageFile == null) {
      await showWarningSnackBar(
        context,
        title: "ข้อมูลไม่ครบ",
        message: "กรุณาเลือกรูปภาพยืนยันสถานะแรก",
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final collectionName = "delivery";
      final docRef =
          FirebaseFirestore.instance.collection(collectionName).doc();

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

      final statusImageUploadResult = await UploadImgService.uploadFile(
        file: statusImageFile,
        folder: 'delivery_status_history/${docRef.id}',
      );
      final statusImageUrl =
          statusImageUploadResult.secureUrl ?? statusImageUploadResult.url ?? "";
      if (statusImageUrl.isEmpty) {
        throw Exception("อัปโหลดรูปสถานะแรกไม่สำเร็จ");
      }

      final data = {
        "did": docRef.id,
        "item_name": deliNameCtrl.text.trim(),
        "item_image": itemImageUrl,
        "sender_uid": senderUid,
        "receiver_uid": _selectedReceiver!['uid'],
        "pickup_addr_id": _pickupAddressId,
        "dropoff_addr_id": _dropoffAddressId,
        "note": noteCtrl.text.trim(),
        "created_at": FieldValue.serverTimestamp(),
        "status_code": _initialStatusCode,
        "status": _initialStatusLabel,
      };

      await docRef.set(data);

      final historyCollection =
          FirebaseFirestore.instance.collection('delivery_status_history');
      final historyDoc = historyCollection.doc();
      await historyDoc.set({
        "hid": historyDoc.id,
        "did": docRef.id,
        "status_code": _initialStatusCode,
        "image": statusImageUrl,
        "created_at": FieldValue.serverTimestamp(),
        "created_by_user_id": senderUid,
        "created_by_rider_id": null,
      });

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

  Widget _buildAddressSelectionSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAddressDropdown(
              label: "เลือกที่อยู่รับสินค้า",
              addresses: _pickupAddresses,
              selectedId: _pickupAddressId,
              emptyMessage:
                  "ไม่พบที่อยู่ของคุณ กรุณาเพิ่มที่อยู่ในโปรไฟล์ก่อน",
              onChanged: _pickupAddresses.isEmpty
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _pickupAddressId = value;
                      });
                    },
            ),
            const SizedBox(height: 16),
            _buildAddressDropdown(
              label: "เลือกที่อยู่ผู้รับ",
              addresses: _dropoffAddresses,
              selectedId: _dropoffAddressId,
              emptyMessage:
                  "ไม่พบที่อยู่ผู้รับ กรุณาให้ผู้รับเพิ่มที่อยู่ก่อน",
              onChanged: _dropoffAddresses.isEmpty
                  ? null
                  : (value) {
                      if (value == null) return;
                      final address =
                          _findAddressById(_dropoffAddresses, value);
                      final latLng = _toLatLng(address);
                      setState(() {
                        _dropoffAddressId = value;
                        _receiverLatLng = latLng;
                      });
                      _moveMapTo(latLng);
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressDropdown({
    required String label,
    required List<Map<String, dynamic>> addresses,
    required String? selectedId,
    required String emptyMessage,
    required ValueChanged<String?>? onChanged,
  }) {
    final hasAddresses = addresses.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFBBB9B9),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        if (!hasAddresses)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              emptyMessage,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedId,
                isExpanded: true,
                hint: const Text(
                  "เลือกที่อยู่",
                  style: TextStyle(color: Color(0xFF848484), fontSize: 12),
                ),
                items: addresses.map((address) {
                  final addrId = address['addr_id'] as String? ?? '';
                  final label = address['label'] as String? ?? 'ที่อยู่ไม่ระบุ';
                  final detail = address['fullAddress'] as String? ?? '';
                  return DropdownMenuItem<String>(
                    value: addrId,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (detail.isNotEmpty)
                          Text(
                            detail,
                            style: const TextStyle(
                              color: Color(0xFF4B5563),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReceiverMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "ตำแหน่งผู้รับบนแผนที่",
          style: TextStyle(
            color: Color(0xFFBBB9B9),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 220,
              child: Stack(
                children: [
                  fm.FlutterMap(
                    mapController: _mapController,
                    options: fm.MapOptions(
                      initialCenter: _receiverLatLng ?? _initialMapCenter,
                      initialZoom: 13,
                    ),
                    children: [
                      fm.TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.delivery.app',
                      ),
                      fm.MarkerLayer(
                        markers: [
                          if (_receiverLatLng != null)
                            fm.Marker(
                              width: 40,
                              height: 40,
                              point: _receiverLatLng!,
                              child: const Icon(
                                Icons.location_pin,
                                size: 36,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (_receiverLatLng == null)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _dropoffAddresses.isEmpty
                              ? "ยังไม่มีข้อมูลที่อยู่ของผู้รับ"
                              : "เลือกที่อยู่ผู้รับเพื่อแสดงตำแหน่ง",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAddressesForUser(String uid) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('addresses')
        .where('uid', isEqualTo: uid)
        .get();

    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      final addrId = data['addr_id'];
      return {
        ...data,
        'addr_id': addrId is String && addrId.isNotEmpty ? addrId : doc.id,
      };
    }).toList();
  }

  String? _resolveDefaultAddressId(List<Map<String, dynamic>> addresses) {
    for (final address in addresses) {
      final isDefault = (address['is_default'] as num?)?.toInt() == 0;
      if (isDefault) {
        final addrId = address['addr_id'];
        if (addrId is String && addrId.isNotEmpty) {
          return addrId;
        }
      }
    }
    if (addresses.isEmpty) {
      return null;
    }
    final fallback = addresses.first['addr_id'];
    if (fallback is String && fallback.isNotEmpty) {
      return fallback;
    }
    return null;
  }

  Map<String, dynamic>? _findAddressById(
      List<Map<String, dynamic>> addresses, String? addrId) {
    if (addrId == null) return null;
    for (final address in addresses) {
      final currentId = address['addr_id'];
      if (currentId is String && currentId == addrId) {
        return address;
      }
    }
    return null;
  }

  ll.LatLng? _toLatLng(Map<String, dynamic>? address) {
    if (address == null) return null;
    final lat = (address['lat'] as num?)?.toDouble();
    final lng = (address['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      return null;
    }
    return ll.LatLng(lat, lng);
  }

  void _moveMapTo(ll.LatLng? target) {
    if (target == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(target, 15);
    });
  }
}

class _StatusImagePickerSheet extends StatelessWidget {
  const _StatusImagePickerSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.28,
      minChildSize: 0.22,
      maxChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "เลือกรูปภาพยืนยันสถานะ",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _StatusImageSourceButton(
                      icon: Icons.camera_alt_outlined,
                      label: "กล้อง",
                      onTap: () => Navigator.pop(context, ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatusImageSourceButton(
                      icon: Icons.photo_library_outlined,
                      label: "แกลเลอรี",
                      onTap: () => Navigator.pop(context, ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusImageSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _StatusImageSourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF16A34A), width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: const Color(0xFF16A34A),
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF16A34A),
              ),
            ),
          ],
        ),
      ),
    );
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

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final users = querySnapshot.docs.map((doc) {
        final data =
            doc.data()! as Map<String, dynamic>; // Ensure data is a Map
        data['uid'] = doc.id;
        return data;
      }).where((data) {
        final uid = data['uid'];
        if (uid is! String) {
          return true;
        }
        if (currentUid == null || currentUid.isEmpty) {
          return true;
        }
        return uid != currentUid;
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
      onTap: () async {
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        final userUid = user['uid'];
        if (currentUid != null && currentUid.isNotEmpty && userUid == currentUid) {
          await showWarningSnackBar(
            context,
            title: "เลือกผู้รับไม่สำเร็จ",
            message: "คุณไม่สามารถเลือกตัวเองเป็นผู้รับสินค้าได้",
          );
          return;
        }
        if (!mounted) return;
        Navigator.pop(context, user);
      },
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
