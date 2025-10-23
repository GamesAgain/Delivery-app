import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../core/env/env.dart';
import '../../core/router/app_router.dart';
import '../../data/models/address.dart';
import '../../data/models/shipment.dart';
import '../../data/models/user.dart';
import '../../data/services/address_service.dart';
import '../../data/services/shipments_service.dart';
import '../../data/services/storage_service.dart';

class ShipmentCreatePage extends ConsumerStatefulWidget {
  const ShipmentCreatePage({super.key});

  @override
  ConsumerState<ShipmentCreatePage> createState() => _ShipmentCreatePageState();
}

class _ShipmentCreatePageState extends ConsumerState<ShipmentCreatePage> {
  final _receiverPhoneController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _itemWeightController = TextEditingController();
  final _itemSizeController = TextEditingController();
  final _picker = ImagePicker();
  Address? _selectedPickup;
  Address? _selectedDropoff;
  UserProfile? _receiver;
  List<Address> _receiverAddresses = [];
  Uint8List? _itemPhotoBytes;
  XFile? _itemPhoto;
  bool _sharedMap = true;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _receiverPhoneController.dispose();
    _itemNameController.dispose();
    _itemWeightController.dispose();
    _itemSizeController.dispose();
    super.dispose();
  }

  Future<void> _searchReceiver() async {
    final phone = _receiverPhoneController.text.trim();
    if (phone.isEmpty) return;
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore
        .collection('users')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      setState(() {
        _receiver = null;
        _receiverAddresses = [];
        _selectedDropoff = null;
        _error = 'Receiver not found. Ask them to register first.';
      });
      return;
    }
    final profile = UserProfile.fromJson(
      snapshot.docs.first.id,
      snapshot.docs.first.data(),
    );
    setState(() {
      _receiver = profile;
      _error = null;
    });
    final addresses = await Address.collection(firestore, profile.uid).get();
    setState(() {
      _receiverAddresses = addresses.docs.map((doc) => doc.data()).toList();
      _selectedDropoff = _receiverAddresses.isNotEmpty ? _receiverAddresses.first : null;
    });
  }

  Future<void> _pickItemPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _itemPhoto = file;
        _itemPhotoBytes = bytes;
      });
    }
  }

  Future<void> _createShipment() async {
    if (_receiver == null || _selectedPickup == null || _selectedDropoff == null) {
      setState(() => _error = 'Select pickup and receiver addresses.');
      return;
    }
    if (_itemNameController.text.trim().isEmpty) {
      setState(() => _error = 'Provide item details.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final shipmentsService = ref.read(shipmentsServiceProvider);
      final storage = ref.read(storageServiceProvider);
      final newDoc = FirebaseFirestore.instance.collection('shipments').doc();
      String? itemPhotoUrl;
      if (_itemPhoto != null) {
        itemPhotoUrl = await storage.uploadItemPhoto(
          shipmentId: newDoc.id,
          file: _itemPhoto!,
        );
      }
      final now = DateTime.now();
      final shipment = Shipment(
        id: newDoc.id,
        senderUid: uid,
        receiverUid: _receiver!.uid,
        riderUid: null,
        createdAt: now,
        updatedAt: now,
        pickup: ShipmentPoint(
          addressRef: _selectedPickup!.id,
          inlineAddress: _selectedPickup!.fullAddress,
          lat: _selectedPickup!.latitude,
          lng: _selectedPickup!.longitude,
        ),
        dropoff: ShipmentPoint(
          addressRef: _selectedDropoff!.id,
          inlineAddress: _selectedDropoff!.fullAddress,
          lat: _selectedDropoff!.latitude,
          lng: _selectedDropoff!.longitude,
        ),
        item: ShipmentItem(
          name: _itemNameController.text.trim(),
          weight: double.tryParse(_itemWeightController.text.trim()),
          size: _itemSizeController.text.trim().isEmpty
              ? null
              : _itemSizeController.text.trim(),
        ),
        itemPhotoUrl: itemPhotoUrl,
        statusCode: 1,
        statusLabel: ShipmentStatusHelper.labelFor(1),
        sharedMap: _sharedMap,
      );
      await shipmentsService.createShipment(
        shipment: shipment,
        id: newDoc.id,
      );
      if (!mounted) return;
      context.go(AppRouter.dashboard);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final pickupAddresses = uid == null
        ? const AsyncValue<List<Address>>.loading()
        : ref.watch(userAddressesProvider(uid));
    final dropoffCenter = _selectedDropoff?.latitude != null
        ? LatLng(_selectedDropoff!.latitude!, _selectedDropoff!.longitude!)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Create shipment')),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 24,
          top: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _receiverPhoneController,
              decoration: InputDecoration(
                labelText: 'Receiver phone',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchReceiver,
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            if (_receiver != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(_receiver!.name),
                  subtitle: Text(_receiver!.phone),
                ),
              ),
            pickupAddresses.when(
              data: (addresses) {
                if (addresses.isEmpty) {
                  return const Text(
                    'No saved pickup addresses yet. Add one from your profile.',
                    style: TextStyle(color: Colors.red),
                  );
                }
                _selectedPickup ??= addresses.first;
                return DropdownButtonFormField<Address>(
                  value: _selectedPickup,
                  items: addresses
                      .map((address) => DropdownMenuItem<Address>(
                            value: address,
                            child: Text(address.label),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedPickup = value);
                  },
                  decoration: const InputDecoration(labelText: 'Pickup address'),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text('Failed to load addresses: $error'),
            ),
            const SizedBox(height: 12),
            if (_receiverAddresses.isNotEmpty)
              DropdownButtonFormField<Address>(
                value: _selectedDropoff,
                items: _receiverAddresses
                    .map((address) => DropdownMenuItem<Address>(
                          value: address,
                          child: Text(address.label),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedDropoff = value);
                },
                decoration: const InputDecoration(labelText: 'Drop-off address'),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: dropoffCenter == null
                  ? const Center(child: Text('Select a receiver address to preview'))
                  : FlutterMap(
                      options: MapOptions(
                        initialCenter: dropoffCenter,
                        initialZoom: 15,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: Env.mapTileUrl,
                          userAgentPackageName: 'com.delivery.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: dropoffCenter,
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.flag, color: Colors.blue, size: 38),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _itemNameController,
              decoration: const InputDecoration(labelText: 'Item description'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _itemWeightController,
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _itemSizeController,
              decoration: const InputDecoration(labelText: 'Size / dimensions'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickItemPhoto,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Capture item photo'),
            ),
            if (_itemPhotoBytes != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _itemPhotoBytes!,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            SwitchListTile.adaptive(
              value: _sharedMap,
              onChanged: (value) => setState(() => _sharedMap = value),
              title: const Text('Include in shared map'),
              subtitle: const Text('Allow receiver to follow live map updates'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _createShipment,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create shipment'),
            ),
          ],
        ),
      ),
    );
  }
}
