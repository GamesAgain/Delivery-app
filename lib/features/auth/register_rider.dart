import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/router/app_router.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/storage_service.dart';

class RegisterRiderPage extends ConsumerStatefulWidget {
  const RegisterRiderPage({super.key});

  @override
  ConsumerState<RegisterRiderPage> createState() => _RegisterRiderPageState();
}

class _RegisterRiderPageState extends ConsumerState<RegisterRiderPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _plateController = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _photos = [];
  final List<Uint8List> _photoBytes = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _photos.add(file);
        _photoBytes.add(bytes);
      });
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
      _photoBytes.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (_photos.length < 2) {
      setState(() => _error = 'Capture two rider verification photos.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final credential = await ref.read(authServiceProvider).registerRider(
            phone: _phoneController.text.trim(),
            password: _passwordController.text,
            name: _nameController.text.trim(),
            plate: _plateController.text.trim(),
            riderPhotoUrls: const [],
          );
      final uid = credential.user!.uid;
      final storage = ref.read(storageServiceProvider);
      final firestore = FirebaseFirestore.instance;
      final urls = <String>[];
      for (var i = 0; i < _photos.length; i++) {
        final url = await storage.uploadRiderPhoto(
          uid: uid,
          file: _photos[i],
          index: i,
        );
        urls.add(url);
      }
      if (urls.isNotEmpty) {
        await firestore.collection('users').doc(uid).update({
          'avatarURL': urls.first,
        });
      }
      await firestore
          .collection('users')
          .doc(uid)
          .collection('riderMeta')
          .doc('profile')
          .set({
        'plate': _plateController.text.trim(),
        'photos': urls,
      }, SetOptions(merge: true));
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
      appBar: AppBar(title: const Text('Register as rider')),
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _plateController,
                decoration: const InputDecoration(labelText: 'Vehicle plate'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter your vehicle plate';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Verification photos',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Capture'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < _photoBytes.length; i++)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _photoBytes[i],
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          color: Colors.red,
                          onPressed: () => _removePhoto(i),
                        ),
                      ],
                    ),
                ],
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
                    : const Text('Create rider account'),
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
