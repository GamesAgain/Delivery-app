import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/env/env.dart';
import '../../data/models/shipment.dart';
import '../../data/models/user.dart';
import '../../data/services/shipments_service.dart';

class RiderJobBoardPage extends ConsumerStatefulWidget {
  const RiderJobBoardPage({super.key, required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<RiderJobBoardPage> createState() => _RiderJobBoardPageState();
}

class _RiderJobBoardPageState extends ConsumerState<RiderJobBoardPage> {
  String? _acceptingId;
  String? _error;

  Future<void> _accept(String shipmentId) async {
    setState(() {
      _acceptingId = shipmentId;
      _error = null;
    });
    try {
      final success = await ref
          .read(shipmentsServiceProvider)
          .assignRider(shipmentId: shipmentId, riderUid: widget.profile.uid);
      if (!success) {
        setState(() => _error = 'Job already taken.');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _acceptingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(availableShipmentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Available jobs')),
      body: jobsAsync.when(
        data: (jobs) {
          if (jobs.isEmpty) {
            return const Center(child: Text('No shipments awaiting pickup right now.'));
          }
          return ListView.builder(
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final shipment = jobs[index];
              final pickup = shipment.pickup;
              final dropoff = shipment.dropoff;
              final center = pickup.lat != null && pickup.lng != null
                  ? LatLng(pickup.lat!, pickup.lng!)
                  : dropoff.lat != null && dropoff.lng != null
                      ? LatLng(dropoff.lat!, dropoff.lng!)
                      : const LatLng(14.5995, 120.9842);
              final accepting = _acceptingId == shipment.id;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shipment.item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 140,
                        child: FlutterMap(
                          options: MapOptions(initialCenter: center, initialZoom: 13),
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
                                    width: 30,
                                    height: 30,
                                    child: const Icon(Icons.store_mall_directory,
                                        color: Colors.deepPurple),
                                  ),
                                if (dropoff.lat != null && dropoff.lng != null)
                                  Marker(
                                    point: LatLng(dropoff.lat!, dropoff.lng!),
                                    width: 30,
                                    height: 30,
                                    child: const Icon(Icons.home, color: Colors.teal),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Pickup: ${pickup.inlineAddress ?? 'Coordinate'}'),
                      Text('Drop-off: ${dropoff.inlineAddress ?? 'Coordinate'}'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: accepting ? null : () => _accept(shipment.id),
                        child: accepting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Accept job'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load jobs: $error')),
      ),
      bottomNavigationBar: _error == null
          ? null
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
    );
  }
}
