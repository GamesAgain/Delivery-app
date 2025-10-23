import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_gate.dart';
import '../../features/auth/login.dart';
import '../../features/auth/register_rider.dart';
import '../../features/auth/register_user.dart';
import '../../features/dashboard/dashboard_placeholder.dart';
import '../../features/shipment_create/shipment_create_page.dart';
import '../../features/shared_map/shared_map_page.dart';

class AppRouter {
  AppRouter();

  static const splash = '/';
  static const login = '/login';
  static const registerUser = '/register-user';
  static const registerRider = '/register-rider';
  static const dashboard = '/dashboard';
  static const shipmentCreate = '/shipments/create';
  static const shipmentDetail = '/shipments/:id';
  static const sharedMap = '/shared-map';
  static const riderJobs = '/rider/jobs';
  static const riderActive = '/rider/active/:id';
  static const addressBook = '/addresses';

  late final GoRouter router = GoRouter(
    initialLocation: splash,
    routes: <GoRoute>[
      GoRoute(
        path: splash,
        builder: (context, state) => const AuthGatePage(),
      ),
      GoRoute(
        path: login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: registerUser,
        builder: (context, state) => const RegisterUserPage(),
      ),
      GoRoute(
        path: registerRider,
        builder: (context, state) => const RegisterRiderPage(),
      ),
      GoRoute(
        path: dashboard,
        builder: (context, state) => const DashboardPlaceholderPage(),
      ),
      GoRoute(
        path: shipmentCreate,
        builder: (context, state) => const ShipmentCreatePage(),
      ),
      GoRoute(
        path: sharedMap,
        builder: (context, state) => const SharedMapPage(),
      ),
    ],
  );
}
