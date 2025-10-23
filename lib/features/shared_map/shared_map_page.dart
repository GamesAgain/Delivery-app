import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/env/env.dart';
import '../../data/models/shipment.dart';
import '../../data/services/shipments_service.dart';

class SharedMapPage extends ConsumerStatefulWidget {
  const SharedMapPage({super.key});

  @override
  ConsumerState<SharedMapPage> createState() => _SharedMapPageState();
}

class _SharedMapPageState extends ConsumerState<SharedMapPage> {
  bool _showAll = true;
  Shipment? _selected;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final senderShipments = ref.watch(senderShipmentsProvider(uid));
    final receiverShipments = ref.watch(receiverShipmentsProvider(uid));

    return senderShipments.when(
      data: (senderList) {
        return receiverShipments.when(
          data: (receiverList) {
            final combined = <Shipment>[...senderList, ...receiverList]
                .where((shipment) => shipment.sharedMap)
                .toList();
            if (!_showAll && _selected != null) {
              combined.retainWhere((element) => element.id == _selected!.id);
            }
            final markers = combined
                .expand((shipment) => [
                      if (shipment.pickup.lat != null && shipment.pickup.lng != null)
                        Marker(
                          point: LatLng(shipment.pickup.lat!, shipment.pickup.lng!),
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.store_mall_directory,
                              color: Colors.deepPurple, size: 36),
                        ),
                      if (shipment.dropoff.lat != null && shipment.dropoff.lng != null)
                        Marker(
                          point: LatLng(shipment.dropoff.lat!, shipment.dropoff.lng!),
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.home, color: Colors.teal, size: 36),
                        ),
                    ])
                .toList();
            final center = markers.isNotEmpty
                ? markers.first.point
                : const LatLng(14.5995, 120.9842);
            return Scaffold(
              appBar: AppBar(
                title: const Text('Shared map'),
              ),
              body: Column(
                children: [
                  SwitchListTile.adaptive(
                    value: _showAll,
                    onChanged: (value) {
                      setState(() {
                        _showAll = value;
                        if (value) {
                          _selected = null;
                        }
                      });
                    },
                    title: const Text('Show all shipments'),
                    subtitle: const Text('Toggle to focus on one shipment'),
                  ),
                  if (!_showAll)
                    SizedBox(
                      height: 72,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: combined
                            .map(
                              (shipment) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                child: ChoiceChip(
                                  label: Text(shipment.item.name),
                                  selected: _selected?.id == shipment.id,
                                  onSelected: (_) {
                                    setState(() => _selected = shipment);
                                  },
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  Expanded(
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: 13,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: Env.mapTileUrl,
                          userAgentPackageName: 'com.delivery.app',
                        ),
                        MarkerLayer(markers: markers),
                      ],
                    ),
                  ),
                  Container(
                    height: 160,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: combined.length,
                      itemBuilder: (context, index) {
                        final shipment = combined[index];
                        return Card(
                          child: Container(
                            width: 220,
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shipment.item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('Status: ${shipment.statusLabel}'),
                                const SizedBox(height: 4),
                                Text('Receiver: ${shipment.receiverUid}'),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Scaffold(
            body: Center(child: Text('Failed to load shipments: $error')),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Failed to load shipments: $error')),
      ),
    );
  }
}
