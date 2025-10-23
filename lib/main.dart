import 'package:delivery_app/models/address.dart';
import 'package:delivery_app/models/user.dart';
import 'package:delivery_app/pages/addNewAddress.dart';
import 'package:delivery_app/pages/assignDetail.dart';
import 'package:delivery_app/pages/assignmentList.dart';
import 'package:delivery_app/pages/deliveryHistory.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:delivery_app/pages/editAddress.dart';
import 'package:delivery_app/pages/editProfile.dart';
import 'package:delivery_app/pages/index.dart';
import 'package:delivery_app/pages/login.dart';
import 'package:delivery_app/pages/passwordManagement.dart';
import 'package:delivery_app/pages/pickAddressMap.dart';
import 'package:delivery_app/pages/profile.dart';
import 'package:delivery_app/pages/registerChoice.dart';
import 'package:delivery_app/pages/register.dart';
import 'package:delivery_app/pages/trackingmapPage.dart';
import 'package:delivery_app/pages/useraddress.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:delivery_app/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) =>
              buildTransitionPage(key: state.pageKey, child: const LoginPage()),
        ),
        GoRoute(
          path: '/register',
          pageBuilder: (context, state) => buildTransitionPage(
            key: state.pageKey,
            child: const RegisterChoicePage(),
          ),
        ),
        GoRoute(
          path: '/register/user',
          pageBuilder: (context, state) => buildTransitionPage(
            key: state.pageKey,
            child: RegisterPage(role: 'ผู้ใช้'), // ฟอร์มผู้ใช้
          ),
        ),
        GoRoute(
          path: '/register/rider',
          pageBuilder: (context, state) => buildTransitionPage(
            key: state.pageKey,
            child: RegisterPage(role: 'ไรเดอร์'), // ฟอร์มไรเดอร์
          ),
        ),
        GoRoute(
          path: '/index',
          name: 'index',
          pageBuilder: (context, state) {
            final uid = state.uri.queryParameters['uid'];
            final profile = state.extra as Users;
            return buildTransitionPage(
              key: state.pageKey,
              child: Index(uid: uid, profile: profile),
            );
          },
        ),
        GoRoute(
          path: '/profile',
          name: 'profile',
          pageBuilder: (context, state) {
            final uid = state.uri.queryParameters['uid'];
            final profile = state.extra as Users;
            return buildTransitionPage(
              key: state.pageKey,
              child: ProfilePage(uid: uid, profile: profile),
            );
          },
        ),
        GoRoute(
          path: '/profile/edit',
          name: 'editProfile',
          pageBuilder: (context, state) {
            final profile = state.extra as Users;
            return buildTransitionPage(
              key: state.pageKey,
              child: EditProfilePage(profile: profile),
            );
          },
        ),
        GoRoute(
          path: '/profile/password',
          name: 'passwordManagement',
          pageBuilder: (context, state) {
            final profile = state.extra as Users;
            return buildTransitionPage(
              key: state.pageKey,
              child: PasswordManagementPage(profile: profile),
            );
          },
        ),
        GoRoute(
          path: '/address',
          name: 'address',
          pageBuilder: (context, state) {
            final uid = state.uri.queryParameters['uid'];
            return buildTransitionPage(
              key: state.pageKey,
              child: UserAddressPage(uid: uid),
            );
          },
        ),
        GoRoute(
          path: '/addnewaddress',
          name: 'addnewaddress',
          pageBuilder: (context, state) {
            final uid = state.uri.queryParameters['uid'];
            return buildTransitionPage(
              key: state.pageKey,
              child: AddNewAddress(uid: uid),
            );
          },
        ),
        GoRoute(
          path: '/editAddress',
          name: 'editAddress',
          pageBuilder: (context, state) {
            final address = state.extra as Address?;
            return buildTransitionPage(
              key: state.pageKey,
              child: address == null
                  ? const Scaffold(
                      body: Center(
                        child: Text('ไม่พบข้อมูลที่อยู่สำหรับแก้ไข'),
                      ),
                    )
                  : EditAddressPage(address: address),
            );
          },
        ),
        GoRoute(
          path: '/pickerAddress',
          name: 'pickerAddress',
          pageBuilder: (context, state) {
            final uid = state.uri.queryParameters['uid'];
            return buildTransitionPage(
              key: state.pageKey,
              child: PickAddressMapPage(uid: uid),
            );
          },
        ),
        GoRoute(
          path: '/assingmentlist',
          name: 'assingmentlist',
          pageBuilder: (context, state) {
            final uid = state.uri.queryParameters['uid'];
            return buildTransitionPage(
              key: state.pageKey,
              child: Assignmentlist(uid: uid),
            );
          },
        ),
        GoRoute(
          path: '/assignmentDetail',
          name: 'assignmentDetail',
          pageBuilder: (context, state) {
            final did = state.uri.queryParameters['did'];
            return buildTransitionPage(
              key: state.pageKey,
              child: AssignDetailPage(did: did!),
            );
          },
        ),
        GoRoute(
          path: '/trackingPage',
          name: 'trackingPage',
          pageBuilder: (context, state) {
            final did = state.uri.queryParameters['did'];
            return buildTransitionPage(
              key: state.pageKey,
              child: TrackingMapPage(did: did),);},),
        GoRoute(
          path: '/deliveryHistory/:did',
          name: 'deliveryHistory',
          pageBuilder: (context, state) {
            final did = state.pathParameters['did'];
            final args = state.extra as DeliveryHistoryPageArgs?;
            if (did == null || did.isEmpty) {
              return buildTransitionPage(
                key: state.pageKey,
                child: const Scaffold(
                  backgroundColor: AppColors.bg,
                  body: Center(
                    child: Text(
                      'ไม่พบรหัสการจัดส่ง',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              );
            }
            return buildTransitionPage(
              key: state.pageKey,
              child: DeliveryHistoryPage(
                deliveryId: did,
                initialItemName: args?.itemName,
                initialStatusLabel: args?.statusLabel,
              ),
            );
          },
        ),
      ],
    );

    return MaterialApp.router(
      routerConfig: router,
      title: 'Delivery App',
      theme: ThemeData(
        textTheme: GoogleFonts.sarabunTextTheme().apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF16A34A)),
      ),
    );
  }
}

/// ฟังก์ชันสำหรับสร้าง Transition แบบกำหนดเอง
CustomTransitionPage buildTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 100), // เวลา transition
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}
