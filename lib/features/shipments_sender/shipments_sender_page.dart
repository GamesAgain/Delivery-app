import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../data/models/shipment.dart';
import '../../data/models/user.dart';
import '../../data/services/shipments_service.dart';
import '../shipment_detail/shipment_detail_page.dart';

class ShipmentsSenderPage extends ConsumerWidget {
  const ShipmentsSenderPage({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shipmentsAsync = ref.watch(senderShipmentsProvider(profile.uid));
    return Scaffold(
      appBar: AppBar(
        title: const Text('My shipments'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRouter.shipmentCreate),
        icon: const Icon(Icons.add_box_outlined),
        label: const Text('New shipment'),
      ),
      body: shipmentsAsync.when(
        data: (shipments) {
          if (shipments.isEmpty) {
            return const Center(
              child: Text('No shipments yet. Create your first delivery.'),
            );
          }
          return ListView.separated(
            itemCount: shipments.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final shipment = shipments[index];
              return ListTile(
                leading: CircleAvatar(child: Text('${shipment.statusCode}')),
                title: Text(shipment.item.name),
                subtitle: Text(shipment.statusLabel),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ShipmentDetailPage(
                      shipmentId: shipment.id,
                      currentUser: profile,
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load: $error')),
      ),
    );
  }
}
