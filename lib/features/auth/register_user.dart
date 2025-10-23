import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../core/env/env.dart';
import '../../core/router/app_router.dart';
import '../../data/models/address.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/location_service.dart';
import '../../data/services/storage_service.dart';

class RegisterUserPage extends ConsumerStatefulWidget {
  const RegisterUserPage({super.key});

  @override
  ConsumerState<RegisterUserPage> createState() => _RegisterUserPageState();
}

class _RegisterUserPageState extends ConsumerState<RegisterUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _addresses = <_AddressDraft>[];
  final _picker = ImagePicker();
  XFile? _avatar;
  Uint8List? _avatarBytes;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addAddress() async {
    final draft = await showModalBottomSheet<_AddressDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _AddressPickerSheet(),
    );
    if (draft != null) {
      setState(() => _addresses.add(draft));
    }
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _avatar = file;
        _avatarBytes = bytes;
      });
    }
  }

  Future<void> _submit() async {
    if (_addresses.isEmpty) {
      setState(() => _error = 'Add at least one address.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final credential = await ref.read(authServiceProvider).registerUser(
            phone: _phoneController.text.trim(),
            password: _passwordController.text,
            name: _nameController.text.trim(),
          );
      final uid = credential.user!.uid;
      final firestore = FirebaseFirestore.instance;
      if (_avatar != null) {
        final avatarUrl = await ref
            .read(storageServiceProvider)
            .uploadUserAvatar(uid: uid, file: _avatar!);
        await firestore.collection('users').doc(uid).update({
          'avatarURL': avatarUrl,
        });
      }
      final addressCollection = Address.collection(firestore, uid);
      for (final addr in _addresses) {
        final id = const Uuid().v4();
        final address = Address(
          id: id,
          ownerUid: uid,
          label: addr.label,
          fullAddress: addr.fullAddress,
          latitude: addr.lat,
          longitude: addr.lng,
          notes: addr.notes,
        );
        await addressCollection.doc(id).set(address);
      }
      if (!mounted) return;
      context.go(AppRouter.splash);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register as sender/receiver')),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 24,
          top: 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: CircleAvatar(
                    radius: 44,
                    backgroundImage:
                        _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                    child: _avatarBytes == null
                        ? const Icon(Icons.camera_alt, size: 32)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+12065550123',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter your phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Minimum 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Addresses',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addAddress,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
              if (_addresses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No addresses yet. Add at least one.',
                      style: TextStyle(color: Colors.red)),
                ),
              for (final addr in _addresses)
                Card(
                  child: ListTile(
                    title: Text(addr.label),
                    subtitle: Text(
                      '${addr.fullAddress}\n${addr.lat.toStringAsFixed(5)}, ${addr.lng.toStringAsFixed(5)}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        setState(() => _addresses.remove(addr));
                      },
                    ),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create account'),
              ),
              TextButton(
                onPressed: () => context.go(AppRouter.login),
                child: const Text('Back to login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressDraft {
  _AddressDraft({
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

class _AddressPickerSheet extends ConsumerStatefulWidget {
  const _AddressPickerSheet();

  @override
  ConsumerState<_AddressPickerSheet> createState() => _AddressPickerSheetState();
}

class _AddressPickerSheetState extends ConsumerState<_AddressPickerSheet> {
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  LatLng? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _labelController.text = 'Home';
    _loadInitialLocation();
  }

  Future<void> _loadInitialLocation() async {
    final service = ref.read(locationServiceProvider);
    final hasPermission = await service.ensurePermission();
    if (hasPermission) {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _selected = LatLng(position.latitude, position.longitude);
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
    if (_labelController.text.isEmpty || _addressController.text.isEmpty) {
      return;
    }
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
                            additionalOptions: const {
                              'attribution': '',
                            },
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
                child: const Text('Use this address'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
