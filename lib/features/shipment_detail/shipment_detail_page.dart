import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/env/env.dart';
import '../../data/models/shipment.dart';
import '../../data/models/status_history.dart';
import '../../data/models/user.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/shipments_service.dart';

class ShipmentDetailPage extends ConsumerWidget {
  const ShipmentDetailPage({super.key, required this.shipmentId, required this.currentUser});

  final String shipmentId;
  final UserProfile currentUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shipmentAsync = ref.watch(shipmentProvider(shipmentId));
    final historyAsync = ref.watch(shipmentHistoryProvider(shipmentId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shipment detail'),
      ),
      body: shipmentAsync.when(
        data: (shipment) {
          if (shipment == null) {
            return const Center(child: Text('Shipment not found'));
          }
          final counterpartId = currentUser.uid == shipment.senderUid
              ? shipment.receiverUid
              : shipment.senderUid;
          final counterpartProfile = ref.watch(userProfileProvider(counterpartId));
          final dropoff = shipment.dropoff;
          final pickup = shipment.pickup;
          final mapCenter = dropoff.lat != null && dropoff.lng != null
              ? LatLng(dropoff.lat!, dropoff.lng!)
              : pickup.lat != null && pickup.lng != null
                  ? LatLng(pickup.lat!, pickup.lng!)
                  : const LatLng(14.5995, 120.9842);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${shipment.statusCode}')),
                    title: Text(shipment.item.name),
                    subtitle: Text('Status: ${shipment.statusLabel}'),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: counterpartProfile.when(
                    data: (profile) {
                      if (profile == null) {
                        return const ListTile(
                          title: Text('Contact'),
                          subtitle: Text('Loading counterpart info...'),
                        );
                      }
                      return ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(profile.name),
                        subtitle: Text(profile.phone),
                      );
                    },
                    loading: () => const ListTile(
                      title: Text('Loading contact...'),
                    ),
                    error: (error, _) => ListTile(
                      title: const Text('Contact'),
                      subtitle: Text('Failed to load: $error'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: mapCenter,
                      initialZoom: 13,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: Env.mapTileUrl,
                        userAgentPackageName: 'com.delivery.app',
                      ),
                      MarkerLayer(
                        markers: [
                          if (pickup.lat != null && pickup.lng != null)
                            Marker(
                              point: LatLng(pickup.lat!, pickup.lng!),
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.store, color: Colors.purple, size: 36),
                            ),
                          if (dropoff.lat != null && dropoff.lng != null)
                            Marker(
                              point: LatLng(dropoff.lat!, dropoff.lng!),
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.home, color: Colors.green, size: 36),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                historyAsync.when(
                  data: (history) => _HistoryList(entries: history),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text('Failed to load history: $error'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load shipment: $error')),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.entries});

  final List<StatusHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Text('No status updates yet.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status history',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final entry in entries)
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${entry.code}')),
              title: Text(entry.label),
              subtitle: Text(entry.timestamp.toLocal().toString()),
              trailing: entry.photoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        entry.photoUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}
