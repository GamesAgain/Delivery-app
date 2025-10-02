import 'package:delivery_app/pages/index.dart';
import 'package:delivery_app/pages/login.dart';
import 'package:delivery_app/pages/registerChoice.dart';
import 'package:delivery_app/pages/register.dart';
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
          pageBuilder: (context, state) => buildTransitionPage(
            key: state.pageKey,
            child: Index() // ฟอร์มไรเดอร์
          ),
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
