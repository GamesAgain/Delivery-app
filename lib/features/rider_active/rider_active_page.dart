import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/shipment.dart';
import '../../data/models/user.dart';
import '../../data/services/location_service.dart';
import '../../data/services/shipments_service.dart';
import '../../data/services/storage_service.dart';
import '../shipment_detail/shipment_detail_page.dart';

class RiderActivePage extends ConsumerStatefulWidget {
  const RiderActivePage({super.key, required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<RiderActivePage> createState() => _RiderActivePageState();
}

class _RiderActivePageState extends ConsumerState<RiderActivePage> {
  final _picker = ImagePicker();
  StreamSubscription? _positionSub;
  List<String> _activeIds = [];
  String? _error;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    ref.listen<AsyncValue<List<Shipment>>>(
      riderActiveShipmentsProvider(widget.profile.uid),
      (previous, next) {
        next.whenData((value) {
          setState(() {
            _activeIds = value.map((s) => s.id).toList();
          });
        });
      },
    );
    _startLocationUpdates();
  }

  Future<void> _startLocationUpdates() async {
    final locationService = ref.read(locationServiceProvider);
    final allowed = await locationService.ensurePermission();
    if (!allowed) return;
    _positionSub?.cancel();
    _positionSub = locationService.positionStream().listen((position) {
      for (final id in _activeIds) {
        ref.read(shipmentsServiceProvider).updateRiderLocation(
              shipmentId: id,
              lat: position.latitude,
              lng: position.longitude,
            );
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _advanceStatus(Shipment shipment, int targetCode) async {
    final photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final position = await ref.read(locationServiceProvider).getCurrentPosition();
      if (position == null) {
        setState(() => _error = 'Location permission required.');
        return;
      }
      if (targetCode == 3 || targetCode == 5) {
        final valid = await ref.read(shipmentsServiceProvider).validateProximity(
              shipmentId: shipment.id,
              lat: position.latitude,
              lng: position.longitude,
              targetCode: targetCode,
            );
        if (!valid) {
          setState(() => _error = 'You are too far from the required location.');
          return;
        }
      }
      final photoUrl = await ref.read(storageServiceProvider).uploadShipmentPhoto(
            shipmentId: shipment.id,
            statusCode: '$targetCode',
            file: photo,
          );
      await ref.read(shipmentsServiceProvider).updateStatus(
            shipmentId: shipment.id,
            code: targetCode,
            label: ShipmentStatusHelper.labelFor(targetCode),
            photoUrl: photoUrl,
            actorUid: widget.profile.uid,
          );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(riderActiveShipmentsProvider(widget.profile.uid));
    return activeAsync.when(
      data: (shipments) {
        if (shipments.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Text('No active deliveries. Accept a job to get started.'),
            ),
          );
        }
        final shipment = shipments.first;
        final actions = <Widget>[];
        if (shipment.statusCode < 3) {
          actions.add(_ActionButton(
            label: 'Mark picked up',
            onPressed: _processing ? null : () => _advanceStatus(shipment, 3),
          ));
        }
        if (shipment.statusCode >= 3 && shipment.statusCode < 4) {
          actions.add(_ActionButton(
            label: 'Mark en-route',
            onPressed: _processing ? null : () => _advanceStatus(shipment, 4),
          ));
        }
        if (shipment.statusCode >= 4 && shipment.statusCode < 5) {
          actions.add(_ActionButton(
            label: 'Mark delivered',
            onPressed: _processing ? null : () => _advanceStatus(shipment, 5),
          ));
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Active delivery'),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ShipmentDetailPage(
                      shipmentId: shipment.id,
                      currentUser: widget.profile,
                    ),
                  ),
                ),
              )
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${shipment.statusCode}')),
                    title: Text(shipment.item.name),
                    subtitle: Text(shipment.statusLabel),
                  ),
                ),
                const SizedBox(height: 16),
                ...actions,
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Failed to load active jobs: $error')),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
