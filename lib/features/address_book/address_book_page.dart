import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../core/env/env.dart';
import '../../data/models/address.dart';
import '../../data/models/user.dart';
import '../../data/services/address_service.dart';
import '../../data/services/location_service.dart';

class AddressBookPage extends ConsumerWidget {
  const AddressBookPage({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(userAddressesProvider(profile.uid));
    return Scaffold(
      appBar: AppBar(
        title: const Text('My addresses'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final draft = await showModalBottomSheet<_AddressDraft>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const _AddressSheet(),
          );
          if (draft != null) {
            final id = const Uuid().v4();
            final address = Address(
              id: id,
              ownerUid: profile.uid,
              label: draft.label,
              fullAddress: draft.fullAddress,
              latitude: draft.lat,
              longitude: draft.lng,
              notes: draft.notes,
            );
            await ref.read(addressServiceProvider).addAddress(profile.uid, address);
          }
        },
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add address'),
      ),
      body: addressesAsync.when(
        data: (addresses) {
          if (addresses.isEmpty) {
            return const Center(
              child: Text('No addresses yet. Add your pickup points.'),
            );
          }
          return ListView.builder(
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final address = addresses[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.location_pin),
                  title: Text(address.label),
                  subtitle: Text(
                    '${address.fullAddress}\n${address.latitude?.toStringAsFixed(5) ?? ''}, ${address.longitude?.toStringAsFixed(5) ?? ''}',
                  ),
                  isThreeLine: true,
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

class _AddressDraft {
  const _AddressDraft({
    required this.label,
    required this.fullAddress,
    required this.lat,
    required this.lng,
    this.notes,
  });

  final String label;
  final String fullAddress;
  final double lat;
  final double lng;
  final String? notes;
}

class _AddressSheet extends ConsumerStatefulWidget {
  const _AddressSheet();

  @override
  ConsumerState<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends ConsumerState<_AddressSheet> {
  final _labelController = TextEditingController(text: 'Home');
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  LatLng? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final service = ref.read(locationServiceProvider);
    final allowed = await service.ensurePermission();
    if (allowed) {
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _selected = LatLng(pos.latitude, pos.longitude);
        _loading = false;
      });
    } else {
      setState(() {
        _selected = const LatLng(14.5995, 120.9842);
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final marker = _selected;
    if (marker == null) return;
    if (_labelController.text.isEmpty || _addressController.text.isEmpty) return;
    Navigator.of(context).pop(
      _AddressDraft(
        label: _labelController.text,
        fullAddress: _addressController.text,
        lat: marker.latitude,
        lng: marker.longitude,
        notes: _notesController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SizedBox(
          height: size.height * 0.75,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _labelController,
                decoration: const InputDecoration(labelText: 'Label'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _addressController,
                decoration:
                    const InputDecoration(labelText: 'Full address description'),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading || _selected == null
                    ? const Center(child: CircularProgressIndicator())
                    : FlutterMap(
                        options: MapOptions(
                          initialCenter: _selected!,
                          initialZoom: 15,
                          onTap: (tapPosition, latlng) {
                            setState(() => _selected = latlng);
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: Env.mapTileUrl,
                            userAgentPackageName: 'com.delivery.app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _selected!,
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.location_pin,
                                    color: Colors.red, size: 40),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                decoration:
                    const InputDecoration(labelText: 'Notes (door code, etc.)'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Save address'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
