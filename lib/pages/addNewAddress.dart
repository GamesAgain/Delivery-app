import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/components/custom_dialog.dart';
import 'package:delivery_app/models/thai_address.dart';
import 'package:delivery_app/services/thai_address_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

class AddNewAddress extends StatefulWidget {
  const AddNewAddress({super.key, this.uid});

  final String? uid;

  @override
  State<AddNewAddress> createState() => _AddNewAddressState();
}

class _AddNewAddressState extends State<AddNewAddress> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _addressNumberController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final ThaiAddressService _thaiAddressService = ThaiAddressService();
  final Dio _dio = Dio(
    BaseOptions(headers: const {'User-Agent': 'DeliveryApp/1.0 (https://github.com)'}),
  );

  late final Future<void> _initialDataFuture;

  List<Province> _provinces = <Province>[];
  List<District> _districts = <District>[];
  List<SubDistrict> _subDistricts = <SubDistrict>[];
  Province? _selectedProvince;
  District? _selectedDistrict;
  SubDistrict? _selectedSubDistrict;

  bool _loadingDistricts = false;
  bool _loadingSubDistricts = false;
  bool _isSaving = false;
  bool _setAsDefault = false;

  LatLng? _selectedLatLng;
  String? _resolvedAddress;

  String? _provinceError;
  String? _districtError;
  String? _subDistrictError;

  @override
  void initState() {
    super.initState();
    _initialDataFuture = _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final provinces = await _thaiAddressService.getProvinces();
      if (mounted) {
        setState(() {
          _provinces = provinces;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _provinceError = 'ไม่สามารถโหลดรายชื่อจังหวัดได้';
        });
      }
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressNumberController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F19),
        title: const Text(
          'ที่อยู่จัดส่งสินค้าใหม่',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: Offset(1.5, 1.5),
                blurRadius: 2.0,
                color: Color(0xFF16A34A),
              ),
            ],
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _initialDataFuture,
          builder: (context, snapshot) {
            final isLoading = snapshot.connectionState == ConnectionState.waiting &&
                _provinces.isEmpty;
            if (isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextFormField(
                      controller: _labelController,
                      label: 'ชื่อของที่อยู่',
                      hint: 'เช่น บ้าน, ที่ทำงาน',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'กรุณาระบุชื่อของที่อยู่';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ที่อยู่',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: const Color(0xFFBBB9B9)),
                    ),
                    const SizedBox(height: 8),
                    _buildPickFromMapButton(),
                    if (_resolvedAddress != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2937),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Text(
                          _resolvedAddress!,
                          style: const TextStyle(color: Colors.white70, height: 1.4),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _buildProvinceDropdown(),
                    const SizedBox(height: 16),
                    _buildDistrictDropdown(),
                    const SizedBox(height: 16),
                    _buildSubDistrictDropdown(),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                      controller: _addressNumberController,
                      label: 'เลขที่อยู่',
                      hint: 'กรุณากรอกเลขที่อยู่และรายละเอียดเพิ่มเติม',
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'กรุณากรอกเลขที่อยู่';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextFormField(
                      controller: _postalCodeController,
                      label: 'รหัสไปรษณีย์',
                      hint: 'กรุณากรอกรหัสไปรษณีย์',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'กรุณากรอกรหัสไปรษณีย์';
                        }
                        if (value.trim().length != 5) {
                          return 'กรุณากรอกรหัสไปรษณีย์ 5 หลัก';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'ตั้งเป็นที่อยู่หลัก',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'ระบบจะใช้ที่อยู่นี้เป็นค่าเริ่มต้นสำหรับการจัดส่ง',
                        style: TextStyle(color: Colors.white60),
                      ),
                      value: _setAsDefault,
                      onChanged: (value) {
                        setState(() {
                          _setAsDefault = value;
                        });
                      },
                      activeColor: const Color(0xFF16A34A),
                    ),
                    if (_provinceError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _provinceError!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveAddress,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'บันทึกที่อยู่',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildPickFromMapButton() {
    return FilledButton(
      onPressed: _handlePickFromMap,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF16A34A).withOpacity(0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Row(
            children: [
              Icon(Icons.location_on_outlined, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'เลือกจากแผนที่',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
          Icon(Icons.chevron_right, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildProvinceDropdown() {
    return DropdownButtonFormField<Province>(
      value: _selectedProvince,
      isExpanded: true,
      decoration: _dropdownDecoration('จังหวัด'),
      items: _provinces
          .map(
            (province) => DropdownMenuItem<Province>(
              value: province,
              child: Text(province.nameTh, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        _onProvinceChanged(value);
      },
      validator: (_) {
        if (_selectedProvince == null) {
          return 'กรุณาเลือกจังหวัด';
        }
        return null;
      },
    );
  }

  Widget _buildDistrictDropdown() {
    return DropdownButtonFormField<District>(
      value: _selectedDistrict,
      isExpanded: true,
      decoration: _dropdownDecoration('อำเภอ'),
      items: _districts
          .map(
            (district) => DropdownMenuItem<District>(
              value: district,
              child: Text(district.nameTh, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: _districts.isEmpty
          ? null
          : (value) {
              if (value == null) return;
              _onDistrictChanged(value);
            },
      validator: (_) {
        if (_selectedProvince == null) {
          return 'กรุณาเลือกจังหวัดก่อน';
        }
        if (_selectedDistrict == null) {
          return _districtError ?? 'กรุณาเลือกอำเภอ';
        }
        return null;
      },
      disabledHint: _loadingDistricts
          ? const Text('กำลังโหลดอำเภอ...', style: TextStyle(color: Colors.white54))
          : const Text('เลือกจังหวัดก่อน', style: TextStyle(color: Colors.white54)),
    );
  }

  Widget _buildSubDistrictDropdown() {
    return DropdownButtonFormField<SubDistrict>(
      value: _selectedSubDistrict,
      isExpanded: true,
      decoration: _dropdownDecoration('ตำบล'),
      items: _subDistricts
          .map(
            (subDistrict) => DropdownMenuItem<SubDistrict>(
              value: subDistrict,
              child: Text(subDistrict.nameTh, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: _subDistricts.isEmpty
          ? null
          : (value) {
              if (value == null) return;
              _onSubDistrictChanged(value);
            },
      validator: (_) {
        if (_selectedDistrict == null) {
          return 'กรุณาเลือกอำเภอก่อน';
        }
        if (_selectedSubDistrict == null) {
          return _subDistrictError ?? 'กรุณาเลือกตำบล';
        }
        return null;
      },
      disabledHint: _loadingSubDistricts
          ? const Text('กำลังโหลดตำบล...', style: TextStyle(color: Colors.white54))
          : const Text('เลือกอำเภอก่อน', style: TextStyle(color: Colors.white54)),
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFFBBB9B9), fontSize: 16),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFC7C0C0), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFC7C0C0), width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFBBB9B9), fontSize: 16),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF848484), fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFC7C0C0), width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFC7C0C0), width: 1.2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ],
    );
  }

  Future<void> _handlePickFromMap() async {
    final result = await context.pushNamed<Map<String, dynamic>>(
      'pickerAddress',
      queryParameters: {'uid': widget.uid ?? ''},
    );
    if (result == null) {
      return;
    }

    final latlng = result['latlng'] as Map<String, dynamic>?;
    final addressText = result['address'] as String?;
    final components =
        (result['addressComponents'] as Map?)?.cast<String, dynamic>();

    if (latlng != null) {
      final lat = (latlng['lat'] as num?)?.toDouble();
      final lng = (latlng['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        _selectedLatLng = LatLng(lat, lng);
      }
    }

    setState(() {
      _resolvedAddress = addressText;
    });

    if (components != null) {
      await _applyAddressComponents(components);
    }
  }

  Future<void> _applyAddressComponents(Map<String, dynamic> components) async {
    await _initialDataFuture;

    final provinceName = _sanitizeName(
      components['state'] ?? components['province'] ?? components['region'],
    );
    if (provinceName != null && _provinces.isNotEmpty) {
      final province = _provinces.firstWhere(
        (element) =>
            _normalize(element.nameTh) == _normalize(provinceName) ||
            _normalize(element.nameEn) == _normalize(provinceName),
        orElse: () => _provinces.first,
      );
      await _onProvinceChanged(province, fromAutoFill: true);
    }

    final districtName = _sanitizeName(
      components['county'] ??
          components['district'] ??
          components['city'] ??
          components['municipality'],
    );
    if (districtName != null && _selectedProvince != null && _districts.isNotEmpty) {
      final match = _districts.firstWhere(
        (element) =>
            _normalize(element.nameTh) == _normalize(districtName) ||
            _normalize(element.nameEn) == _normalize(districtName),
        orElse: () => _districts.first,
      );
      await _onDistrictChanged(match, fromAutoFill: true);
    }

    final subDistrictName = _sanitizeName(
      components['suburb'] ??
          components['town'] ??
          components['village'] ??
          components['subdistrict'] ??
          components['neighbourhood'],
    );
    if (subDistrictName != null &&
        _selectedDistrict != null &&
        _subDistricts.isNotEmpty) {
      final match = _subDistricts.firstWhere(
        (element) =>
            _normalize(element.nameTh) == _normalize(subDistrictName) ||
            _normalize(element.nameEn) == _normalize(subDistrictName),
        orElse: () => _subDistricts.first,
      );
      _onSubDistrictChanged(match);
    }

    final postalCode = components['postcode'] as String?;
    if (postalCode != null && postalCode.length == 5) {
      _postalCodeController.text = postalCode;
    }

    final houseNumber = components['house_number'] as String?;
    final road = components['road'] as String?;
    final neighbourhood = components['residential'] as String?;
    final line = [houseNumber, road, neighbourhood]
        .where((element) => element != null && element.toString().isNotEmpty)
        .join(' ');
    if (line.isNotEmpty) {
      _addressNumberController.text = line;
    }
    setState(() {});
  }

  Future<void> _onProvinceChanged(Province province,
      {bool fromAutoFill = false}) async {
    setState(() {
      _selectedProvince = province;
      _selectedDistrict = null;
      _selectedSubDistrict = null;
      _districts = <District>[];
      _subDistricts = <SubDistrict>[];
      _postalCodeController.clear();
      _districtError = null;
      _subDistrictError = null;
      _loadingDistricts = true;
    });

    try {
      final districts = await _thaiAddressService.getDistricts(province.id);
      if (!mounted) return;
      setState(() {
        _districts = districts;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _districtError = 'โหลดข้อมูลอำเภอไม่สำเร็จ';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingDistricts = false;
        });
      }
    }

    if (!fromAutoFill) {
      _addressNumberController.clear();
      _postalCodeController.clear();
    }
  }

  Future<void> _onDistrictChanged(District district,
      {bool fromAutoFill = false}) async {
    setState(() {
      _selectedDistrict = district;
      _selectedSubDistrict = null;
      _subDistricts = <SubDistrict>[];
      _subDistrictError = null;
      _loadingSubDistricts = true;
    });

    try {
      final subDistricts =
          await _thaiAddressService.getSubDistricts(district.id);
      if (!mounted) return;
      setState(() {
        _subDistricts = subDistricts;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _subDistrictError = 'โหลดข้อมูลตำบลไม่สำเร็จ';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingSubDistricts = false;
        });
      }
    }

    if (!fromAutoFill) {
      _postalCodeController.clear();
    }
  }

  void _onSubDistrictChanged(SubDistrict subDistrict) {
    setState(() {
      _selectedSubDistrict = subDistrict;
      _postalCodeController.text = subDistrict.zipCode;
    });
  }

  Future<void> _saveAddress() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final latLng = await _ensureLatLng();
      if (latLng == null) {
        throw Exception('ไม่พบพิกัดของที่อยู่นี้');
      }

      final uid = widget.uid;
      if (uid == null || uid.isEmpty) {
        throw Exception('ไม่พบผู้ใช้งาน');
      }

      final collection = FirebaseFirestore.instance.collection('addresses');
      final existingSnapshot = await collection
          .where('uid', isEqualTo: uid)
          .get();
      final shouldSetDefault = _setAsDefault || existingSnapshot.docs.isEmpty;

      final docRef = collection.doc();
      final now = FieldValue.serverTimestamp();

      if (_setAsDefault) {
        for (final doc in existingSnapshot.docs
            .where((element) => (element.data()['is_default'] as num?)?.toInt() == 0)) {
          await doc.reference.update({'is_default': 1});
        }
      }

      final newAddress = <String, dynamic>{
        'addr_id': docRef.id,
        'uid': uid,
        'label': _labelController.text.trim(),
        'fullAddress': _buildFullAddress(),
        'province': _selectedProvince?.nameTh,
        'district': _selectedDistrict?.nameTh,
        'subDistrict': _selectedSubDistrict?.nameTh,
        'postalCode': _postalCodeController.text.trim(),
        'lat': latLng.latitude,
        'lng': latLng.longitude,
        'is_default': shouldSetDefault ? 0 : 1,
        'create_at': now,
        'update_at': now,
      };

      await docRef.set(newAddress);

      if (!mounted) return;

      await showSuccessDialog(
        context,
        title: 'สำเร็จ!',
        message: 'บันทึกที่อยู่เรียบร้อยแล้ว 🎉',
      );
      if (mounted) {
        context.pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _buildFullAddress() {
    final parts = <String?>[
      _addressNumberController.text.trim(),
      _selectedSubDistrict?.nameTh,
      _selectedDistrict?.nameTh,
      _selectedProvince?.nameTh,
      _postalCodeController.text.trim(),
    ];
    return parts
        .where((element) => element != null && element!.isNotEmpty)
        .join(' ');
  }

  Future<LatLng?> _ensureLatLng() async {
    if (_selectedLatLng != null) {
      return _selectedLatLng;
    }

    final query = [
      _addressNumberController.text.trim(),
      _selectedSubDistrict?.nameTh,
      _selectedDistrict?.nameTh,
      _selectedProvince?.nameTh,
      'ประเทศไทย',
    ]
        .where((element) => element != null && element!.isNotEmpty)
        .join(' ');

    if (query.isEmpty) {
      return null;
    }

    final url =
        'https://nominatim.openstreetmap.org/search?format=jsonv2&q=${Uri.encodeComponent(query)}&limit=1';
    try {
      final response = await _dio.get(url);
      final results = response.data as List<dynamic>;
      if (results.isEmpty) {
        return null;
      }
      final first = results.first as Map<String, dynamic>;
      final lat = double.tryParse(first['lat'] as String? ?? '');
      final lon = double.tryParse(first['lon'] as String? ?? '');
      if (lat == null || lon == null) {
        return null;
      }
      _selectedLatLng = LatLng(lat, lon);
      return _selectedLatLng;
    } catch (_) {
      return null;
    }
  }

  String? _sanitizeName(dynamic value) {
    if (value == null) return null;
    var name = value.toString();
    name = name.replaceAll(RegExp(r'^จังหวัด'), '');
    name = name.replaceAll(RegExp(r'^เขต'), '');
    name = name.replaceAll(RegExp(r'^อำเภอ'), '');
    name = name.replaceAll(RegExp(r'^เทศบาล'), '');
    name = name.replaceAll(RegExp(r'^ตำบล'), '');
    name = name.replaceAll(RegExp(r'^แขวง'), '');
    name = name.replaceAll(RegExp(r'^ต\.'), '');
    name = name.replaceAll(RegExp(r'^อ\.'), '');
    name = name.replaceAll(RegExp(r'^จ\.'), '');
    return name.trim();
  }

  String _normalize(String? value) {
    if (value == null) {
      return '';
    }
    return value
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('จังหวัด', '')
        .replaceAll('เขต', '')
        .replaceAll('อำเภอ', '')
        .replaceAll('ตำบล', '')
        .replaceAll('แขวง', '');
  }
}
