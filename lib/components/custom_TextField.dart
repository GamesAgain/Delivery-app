import 'package:flutter/material.dart';
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