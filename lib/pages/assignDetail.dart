import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AssignDetailPage extends StatelessWidget {
  const AssignDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.bgsecondary,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  offset: const Offset(0, 20),
                  blurRadius: 35,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'รายละเอียดการจัดส่ง',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onBg,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'ขนมฝักบัว',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onBg,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: 170,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        'รายละเอียดเพิ่มเติมของงานจัดส่งสามารถแสดงได้ที่นี่',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'ผู้ส่ง:',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onBg,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _AddressCard(
                    address:
                        '12/1 ตำบล ขามเรียง อำเภอกันทรวิชัย มหาสารคาม',
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'ผู้รับ:',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onBg,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _AddressCard(
                    address:
                        '13/5 ตำบล ขามเรียง อำเภอกันทรวิชัย มหาสารคาม',
                  ),
                  const SizedBox(height: 36),
                  FilledButton.icon(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(
                      BootstrapIcons.check2_circle,
                      color: Colors.white,
                      size: 22,
                    ),
                    label: Text(
                      'Accept Delivery',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF101522),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(10),
            child: const Icon(
              BootstrapIcons.geo_alt,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              address,
              style: GoogleFonts.poppins(
                fontSize: 14,
                height: 1.5,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            BootstrapIcons.chevron_down,
            color: Colors.white70,
            size: 18,
          ),
        ],
      ),
    );
  }
}
