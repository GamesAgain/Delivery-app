import 'dart:async';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

class AddNewAddress extends StatefulWidget {
  final String? uid;
  const AddNewAddress({super.key, this.uid});

  @override
  State<AddNewAddress> createState() => _AddNewAddressState();
}

class _AddNewAddressState extends State<AddNewAddress> {
  final MapController mapController = MapController();
  final TextEditingController addressNameCtl = TextEditingController();
  final TextEditingController provinceCtl = TextEditingController();
  final TextEditingController districtCtl = TextEditingController();
  final TextEditingController subDistrictCtl = TextEditingController();
  final TextEditingController postCodeCtl = TextEditingController();
  final TextEditingController addressNumberCtl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F19),
        title: const Text(
          'ที่อยู่จัดส่งสินค้าใหม่',
          style: TextStyle(
            fontSize: 20,
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
        leading: IconButton(
          onPressed: () {},
          icon: Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildTextField(
              label: 'ชื่อของที่อยู่',
              hint: 'เช่น บ้าน, ที่ทำงาน',
              controller: addressNameCtl,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Text(
                'ที่อยู่',
                style: const TextStyle(color: Color(0xFFBBB9B9), fontSize: 16),
              ),
            ),
            FilledButton(
              onPressed: () async {
                // var postion = await _determinePosition();
                // mapController;
                // mapController.move(
                //   LatLng(postion.latitude, postion.longitude),
                //   13.0,
                // );
                context.pushNamed(
                  'pickerAddress',
                  queryParameters: {'uid': widget.uid ?? ''},
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A).withOpacity(0.25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'เลือกจากแผนที่',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                  Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),

            buildTextField(
              label: 'จังหวัด',
              hint: 'กรุณาเลือกจังหวัด',
              controller: provinceCtl,
            ),
            buildTextField(
              label: 'อำเภอ',
              hint: 'กรุณาเลือกอำเภอ',
              controller: districtCtl,
            ),
            buildTextField(
              label: 'ตำบล',
              hint: 'กรุณาเลือกตำบล',
              controller: subDistrictCtl,
            ),
            buildTextField(
              label: 'เลขที่อยู่',
              hint: 'กรุณากรอกเลขที่อยู่',
              controller: addressNumberCtl,
            ),
            buildTextField(
              label: 'รหัสไปรษณีย์',
              hint: 'กรุณากรอกรหัสไปรษณีย์',
              controller: postCodeCtl,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        child: ElevatedButton(
          onPressed: addNewAddress,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'บันทึกที่อยู่',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  void addNewAddress() async {
    final collectionName = "addresses";
    print('Add new address for user: ${widget.uid}');

    final docRef = FirebaseFirestore.instance.collection(collectionName).doc();
    final newAddress = {
      'addr_id': docRef.id,
      'uid': widget.uid,
      'addressName': addressNameCtl.text,
      'fullAddress':
          '${addressNumberCtl.text} ${subDistrictCtl.text} ${districtCtl.text} ${provinceCtl.text} ${postCodeCtl.text}',
    };
    await docRef.set(newAddress);

    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      content: AwesomeSnackbarContent(
        title: 'สำเร็จ!',
        message: 'บันทึกที่อยู่เรียบร้อยแล้ว 🎉',
        contentType: ContentType.success,
      ),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(snackBar);
    }
  }
}

Widget buildTextField({
  required String label,
  required String hint,
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
          style: const TextStyle(color: Color(0xFFBBB9B9), fontSize: 16),
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
            hintStyle: const TextStyle(color: Color(0xFF848484), fontSize: 14),
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
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

Future<Position> _determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users of the
    // App to enable the location services.
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (this is also where
      // Android's shouldShowRequestPermissionRationale
      // returned true. According to Android guidelines
      // your App should show an explanatory UI now.
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    return Future.error(
      'Location permissions are permanently denied, we cannot request permissions.',
    );
  }

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  return await Geolocator.getCurrentPosition();
}
