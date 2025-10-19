import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/components/custom_dialog.dart';
import 'package:delivery_app/models/user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PasswordManagementPage extends StatefulWidget {
  const PasswordManagementPage({super.key, required this.profile});

  final Users profile;

  @override
  State<PasswordManagementPage> createState() => _PasswordManagementPageState();
}

class _PasswordManagementPageState extends State<PasswordManagementPage> {
  final TextEditingController _currentPasswordCtrl = TextEditingController();
  final TextEditingController _newPasswordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  bool _currentObscure = true;
  bool _newObscure = true;
  bool _confirmObscure = true;
  bool _isSubmitting = false;

  static const Color _background = Color(0xFF0B0F19);
  static const Color _cardBackground = Color(0xFF111827);
  static const Color _green = Color(0xFF16A34A);

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                decoration: BoxDecoration(
                  color: _cardBackground,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        color: _green,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        BootstrapIcons.shield_lock,
                        color: Colors.white,
                        size: 46,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'จัดการรหัสผ่าน',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.profile.username,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _PasswordField(
                      label: 'รหัสผ่านเดิม',
                      hint: 'กรอกรหัสผ่านเดิม',
                      controller: _currentPasswordCtrl,
                      obscureText: _currentObscure,
                      onToggleVisibility: () => setState(() {
                        _currentObscure = !_currentObscure;
                      }),
                    ),
                    const SizedBox(height: 18),
                    _PasswordField(
                      label: 'รหัสผ่านใหม่',
                      hint: 'กรอกรหัสผ่านใหม่',
                      controller: _newPasswordCtrl,
                      obscureText: _newObscure,
                      onToggleVisibility: () => setState(() {
                        _newObscure = !_newObscure;
                      }),
                    ),
                    const SizedBox(height: 18),
                    _PasswordField(
                      label: 'ยืนยันรหัสผ่านใหม่',
                      hint: 'ยืนยันรหัสผ่านใหม่',
                      controller: _confirmPasswordCtrl,
                      obscureText: _confirmObscure,
                      onToggleVisibility: () => setState(() {
                        _confirmObscure = !_confirmObscure;
                      }),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _handleChangePassword,
                        style: FilledButton.styleFrom(
                          backgroundColor: _green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Text(
                                'บันทึกการเปลี่ยนแปลง',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                Navigator.of(context).maybePop();
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'ย้อนกลับ',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleChangePassword() async {
    final currentPassword = _currentPasswordCtrl.text.trim();
    final newPassword = _newPasswordCtrl.text.trim();
    final confirmPassword = _confirmPasswordCtrl.text.trim();

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      await showWarningSnackBar(
        context,
        title: 'ข้อมูลไม่ครบ',
        message: 'กรุณากรอกข้อมูลให้ครบทุกช่อง',
      );
      return;
    }

    if (newPassword != confirmPassword) {
      await showErrorDialog(
        context,
        title: 'รหัสผ่านไม่ตรงกัน',
        message: 'กรุณายืนยันรหัสผ่านใหม่ให้ตรงกัน',
      );
      return;
    }

    if (newPassword.length < 6) {
      await showWarningSnackBar(
        context,
        title: 'รหัสผ่านสั้นเกินไป',
        message: 'กรุณาตั้งรหัสผ่านอย่างน้อย 6 ตัวอักษร',
      );
      return;
    }

    if (currentPassword == newPassword) {
      await showWarningSnackBar(
        context,
        title: 'รหัสผ่านซ้ำเดิม',
        message: 'กรุณาตั้งรหัสผ่านใหม่ที่แตกต่างจากเดิม',
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await showErrorDialog(
        context,
        title: 'ไม่พบผู้ใช้งาน',
        message: 'กรุณาเข้าสู่ระบบใหม่อีกครั้ง',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final credential = EmailAuthProvider.credential(
        email: widget.profile.email,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      final collection = widget.profile.role == 'ไรเดอร์' ? 'riders' : 'users';
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(widget.profile.uid)
          .update({
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      await showSuccessDialog(
        context,
        message: 'เปลี่ยนรหัสผ่านเรียบร้อยแล้ว',
        onOk: () => Navigator.of(context).maybePop(),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'ไม่สามารถเปลี่ยนรหัสผ่านได้';
      if (e.code == 'wrong-password') {
        message = 'รหัสผ่านเดิมไม่ถูกต้อง';
      } else if (e.code == 'weak-password') {
        message = 'รหัสผ่านใหม่ไม่ปลอดภัย กรุณาตั้งรหัสผ่านให้ซับซ้อนขึ้น';
      } else if (e.code == 'requires-recent-login') {
        message = 'กรุณาเข้าสู่ระบบใหม่แล้วลองอีกครั้ง';
      } else if (e.message?.isNotEmpty ?? false) {
        message = e.message!;
      }

      await showErrorDialog(
        context,
        title: 'เปลี่ยนรหัสผ่านไม่สำเร็จ',
        message: message,
      );
    } catch (e) {
      await showErrorDialog(
        context,
        title: 'เกิดข้อผิดพลาด',
        message: 'ไม่สามารถเปลี่ยนรหัสผ่านได้: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.obscureText,
    required this.onToggleVisibility,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFBBB9B9),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.black87, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(
              BootstrapIcons.lock,
              color: Colors.black87,
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? BootstrapIcons.eye : BootstrapIcons.eye_slash,
                color: Colors.black87,
                size: 18,
              ),
              onPressed: onToggleVisibility,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }
}
