import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user.dart';
import '../../data/services/auth_service.dart';
import '../rider_active/rider_active_page.dart';
import '../rider_jobs/rider_job_board_page.dart';
import '../shipments_receiver/shipments_receiver_page.dart';
import '../shipments_sender/shipments_sender_page.dart';
import '../shared_map/shared_map_page.dart';
import '../address_book/address_book_page.dart';

class DashboardPlaceholderPage extends ConsumerWidget {
  const DashboardPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (profile.role == UserRole.rider) {
          return _RiderHome(profile: profile);
        }
        return _UserHome(profile: profile);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Failed to load profile: $error')),
      ),
    );
  }
}

class _UserHome extends StatefulWidget {
  const _UserHome({required this.profile});

  final UserProfile profile;

  @override
  State<_UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<_UserHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ShipmentsSenderPage(profile: widget.profile),
      ShipmentsReceiverPage(profile: widget.profile),
      const SharedMapPage(),
      AddressBookPage(profile: widget.profile),
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.send_outlined),
            label: 'Sender',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            label: 'Receiver',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_pin_circle_outlined),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _RiderHome extends StatefulWidget {
  const _RiderHome({required this.profile});

  final UserProfile profile;

  @override
  State<_RiderHome> createState() => _RiderHomeState();
}

class _RiderHomeState extends State<_RiderHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      RiderJobBoardPage(profile: widget.profile),
      RiderActivePage(profile: widget.profile),
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            label: 'Jobs',
          ),
          NavigationDestination(
            icon: Icon(Icons.delivery_dining_outlined),
            label: 'Active',
          ),
        ],
      ),
    );
  }
}
