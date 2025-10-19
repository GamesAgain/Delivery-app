import 'dart:async';

import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:delivery_app/components/custom_dialog.dart';
import 'package:delivery_app/models/address.dart';
import 'package:delivery_app/models/thai_address.dart';
import 'package:delivery_app/services/thai_address_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

enum AddressFormMode { create, edit }

class AddNewAddress extends AddressFormPage {
  const AddNewAddress({super.key, String? uid})
      : super(uid: uid, mode: AddressFormMode.create);
}

class AddressFormPage extends StatefulWidget {
  const AddressFormPage({
    super.key,
    this.uid,
    this.initialAddress,
    required this.mode,
  });

  final String? uid;
  final Address? initialAddress;
  final AddressFormMode mode;

  bool get isEditing => mode == AddressFormMode.edit;

  @override
  State<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<AddressFormPage> {
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

  bool get _isEditing => widget.isEditing;
  Address? get _initialAddress => widget.initialAddress;

  @override
  void initState() {
    super.initState();
    _prefillInitialFields();
    _initialDataFuture = _loadInitialData();
  }

  void _prefillInitialFields() {
    final address = _initialAddress;
    if (address == null) {
      return;
    }

    final label = address.label.trim();
    if (label.isNotEmpty && label != '-') {
      _labelController.text = label;
    }

    final extra = address.extra ?? <String, dynamic>{};
    final addressNumber = (extra['addressNumber'] as String?) ?? '';
    if (addressNumber.isNotEmpty) {
      _addressNumberController.text = addressNumber;
    }

    final postal = (extra['postalCode'] as String?) ??
        (extra['postcode'] as String?) ??
        (extra['zipCode'] as String?) ?? '';
    if (postal.isNotEmpty) {
      _postalCodeController.text = postal;
    }

    final resolved = address.fullAddress.trim();
    if (resolved.isNotEmpty && resolved != '-') {
      _resolvedAddress = resolved;
    }

    final lat = address.lat;
    final lng = address.lng;
    if (lat != null && lng != null) {
      _selectedLatLng = LatLng(lat, lng);
    }

    _setAsDefault = address.isDefault == 0;
  }

  Future<void> _loadInitialData() async {
    try {
      final provinces = await _thaiAddressService.getProvinces();
      if (!mounted) return;
      setState(() {
        _provinces = provinces;
      });
      if (_isEditing) {
        await _prefillGeographyFromExisting();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _provinceError = 'ไม่สามารถโหลดรายชื่อจังหวัดได้';
      });
    }
  }

  Future<void> _prefillGeographyFromExisting() async {
    final extra = _initialAddress?.extra;
    if (extra == null || _provinces.isEmpty) {
      return;
    }

    final provinceName = _sanitizeName(extra['province'] ?? extra['state']);
    final districtName =
        _sanitizeName(extra['district'] ?? extra['county']);
    final subDistrictName =
        _sanitizeName(extra['subDistrict'] ?? extra['subdistrict']);

    await _selectProvinceByName(provinceName, fromAutoFill: true);
    await _selectDistrictByName(districtName, fromAutoFill: true);
    await _selectSubDistrictByName(subDistrictName);

    final postal = (extra['postalCode'] as String?) ??
        (extra['postcode'] as String?) ??
        (extra['zipCode'] as String?) ?? '';
    if (postal.isNotEmpty) {
      _postalCodeController.text = postal;
    }

    if (mounted) {
      setState(() {});
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
    final title = _isEditing ? 'แก้ไขที่อยู่จัดส่ง' : 'ที่อยู่จัดส่งสินค้าใหม่';
    final submitText = _isEditing ? 'บันทึกการเปลี่ยนแปลง' : 'บันทึกที่อยู่';

    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F19),
        title: Text(
          title,
          style: const TextStyle(
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
          icon: const Icon(BootstrapIcons.arrow_left, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _initialDataFuture,
          builder: (context, snapshot) {
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting &&
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
                          style:
                              const TextStyle(color: Colors.white70, height: 1.4),
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
              : Text(
                  submitText,
                  style: const TextStyle(
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
              Icon(BootstrapIcons.geo_alt, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'เลือกจากแผนที่',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
          Icon(BootstrapIcons.chevron_right, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildProvinceDropdown() {
    return _buildLabeledField(
      label: 'จังหวัด',
      child: DropdownButtonFormField<Province>(
        value: _selectedProvince,
        isExpanded: true,
        decoration: _fieldDecoration(hintText: 'เลือกจังหวัด'),
        style: const TextStyle(color: Colors.black87, fontSize: 14),
        dropdownColor: Colors.white,
        iconEnabledColor: Colors.black87,
        iconDisabledColor: Colors.black45,
        hint: const Text(
          'เลือกจังหวัด',
          style: TextStyle(color: Color(0xFF444444)),
        ),
        items: _provinces
            .map(
              (province) => DropdownMenuItem<Province>(
                value: province,
                child: Text(
                  province.nameTh,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black87),
                ),
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
      ),
    );
  }

  Widget _buildDistrictDropdown() {
    return _buildLabeledField(
      label: 'อำเภอ',
      child: DropdownButtonFormField<District>(
        value: _selectedDistrict,
        isExpanded: true,
        decoration: _fieldDecoration(hintText: 'เลือกอำเภอ'),
        style: const TextStyle(color: Colors.black87, fontSize: 14),
        dropdownColor: Colors.white,
        iconEnabledColor: Colors.black87,
        iconDisabledColor: Colors.black45,
        hint: const Text(
          'เลือกอำเภอ',
          style: TextStyle(color: Color(0xFF444444)),
        ),
        items: _districts
            .map(
              (district) => DropdownMenuItem<District>(
                value: district,
                child: Text(
                  district.nameTh,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black87),
                ),
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
            ? const Text(
                'กำลังโหลดอำเภอ...',
                style: TextStyle(color: Color(0xFF666666)),
              )
            : const Text(
                'เลือกจังหวัดก่อน',
                style: TextStyle(color: Color(0xFF666666)),
              ),
      ),
    );
  }

  Widget _buildSubDistrictDropdown() {
    return _buildLabeledField(
      label: 'ตำบล',
      child: DropdownButtonFormField<SubDistrict>(
        value: _selectedSubDistrict,
        isExpanded: true,
        decoration: _fieldDecoration(hintText: 'เลือกตำบล'),
        style: const TextStyle(color: Colors.black87, fontSize: 14),
        dropdownColor: Colors.white,
        iconEnabledColor: Colors.black87,
        iconDisabledColor: Colors.black45,
        hint: const Text(
          'เลือกตำบล',
          style: TextStyle(color: Color(0xFF444444)),
        ),
        items: _subDistricts
            .map(
              (subDistrict) => DropdownMenuItem<SubDistrict>(
                value: subDistrict,
                child: Text(
                  subDistrict.nameTh,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black87),
                ),
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
            ? const Text(
                'กำลังโหลดตำบล...',
                style: TextStyle(color: Color(0xFF666666)),
              )
            : const Text(
                'เลือกอำเภอก่อน',
                style: TextStyle(color: Color(0xFF666666)),
              ),
      ),
    );
  }

  Widget _buildLabeledField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFBBB9B9), fontSize: 16),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration _fieldDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF777777), fontSize: 14),
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
    return _buildLabeledField(
      label: label,
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.black87),
        decoration: _fieldDecoration(hintText: hint).copyWith(
          alignLabelWithHint: maxLines > 1,
        ),
      ),
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

    final labelCandidate = _sanitizeName(
      _firstNonEmpty(components, const [
        'name',
        'house',
        'building',
        'amenity',
        'shop',
        'tourism',
        'office',
        'neighbourhood',
        'suburb',
      ]),
    );
    if (labelCandidate != null &&
        labelCandidate.isNotEmpty &&
        _labelController.text.trim().isEmpty) {
      _labelController.text = labelCandidate;
    }

    final provinceName = _sanitizeName(
      _firstNonEmpty(components, const [
        'state',
        'province',
        'region',
        'state_district',
      ]),
    );
    final districtName = _sanitizeName(
      _firstNonEmpty(components, const [
        'county',
        'district',
        'city_district',
        'city',
        'municipality',
        'borough',
        'state_district',
      ]),
    );
    final subDistrictName = _sanitizeName(
      _firstNonEmpty(components, const [
        'suburb',
        'town',
        'village',
        'subdistrict',
        'sub_district',
        'neighbourhood',
        'quarter',
        'hamlet',
      ]),
    );

    await _selectProvinceByName(provinceName, fromAutoFill: true);
    await _selectDistrictByName(districtName, fromAutoFill: true);
    await _selectSubDistrictByName(subDistrictName);

    final postalCode = _firstNonEmpty(components, const ['postcode', 'postal_code']);
    if (postalCode != null && postalCode.length == 5) {
      _postalCodeController.text = postalCode;
    }

    final houseNumber = _firstNonEmpty(components, const [
      'house_number',
      'house',
      'building',
    ]);
    final road = _firstNonEmpty(components, const ['road', 'street', 'highway']);
    final neighbourhood = _firstNonEmpty(components, const [
      'residential',
      'neighbourhood',
      'hamlet',
      'quarter',
      'suburb',
    ]);
    final line = [houseNumber, road, neighbourhood]
        .where((element) => element != null && element.toString().isNotEmpty)
        .join(' ');
    if (line.isNotEmpty) {
      _addressNumberController.text = line;
    }

    setState(() {});
  }

  Future<Province?> _selectProvinceByName(String? name,
      {bool fromAutoFill = false}) async {
    if (name == null || name.isEmpty || _provinces.isEmpty) {
      return null;
    }

    final normalized = _normalize(name);
    final match = _provinces.firstWhereOrNull(
      (element) => _normalizedStringsMatch(
            normalized,
            _normalize(element.nameTh),
          ) ||
          _normalizedStringsMatch(
            normalized,
            _normalize(element.nameEn),
          ),
    );

    if (match == null) {
      return null;
    }

    final shouldReload =
        _selectedProvince?.id != match.id || _districts.isEmpty;
    if (shouldReload) {
      await _onProvinceChanged(match, fromAutoFill: fromAutoFill);
    }

    return match;
  }

  Future<District?> _selectDistrictByName(String? name,
      {bool fromAutoFill = false}) async {
    if (name == null || name.isEmpty ||
        _selectedProvince == null ||
        _districts.isEmpty) {
      return null;
    }

    final normalized = _normalize(name);
    final match = _districts.firstWhereOrNull(
      (element) => _normalizedStringsMatch(
            normalized,
            _normalize(element.nameTh),
          ) ||
          _normalizedStringsMatch(
            normalized,
            _normalize(element.nameEn),
          ),
    );

    if (match == null) {
      return null;
    }

    final shouldReload =
        _selectedDistrict?.id != match.id || _subDistricts.isEmpty;
    if (shouldReload) {
      await _onDistrictChanged(match, fromAutoFill: fromAutoFill);
    }

    return match;
  }

  Future<SubDistrict?> _selectSubDistrictByName(String? name) async {
    if (name == null || name.isEmpty ||
        _selectedDistrict == null ||
        _subDistricts.isEmpty) {
      return null;
    }

    final normalized = _normalize(name);
    final match = _subDistricts.firstWhereOrNull(
      (element) => _normalizedStringsMatch(
            normalized,
            _normalize(element.nameTh),
          ) ||
          _normalizedStringsMatch(
            normalized,
            _normalize(element.nameEn),
          ),
    );

    if (match == null) {
      return null;
    }

    if (_selectedSubDistrict?.id != match.id) {
      _onSubDistrictChanged(match);
    }

    return match;
  }

  Future<void> _onProvinceChanged(Province province,
      {bool fromAutoFill = false}) async {
    setState(() {
      _selectedProvince = province;
      _selectedDistrict = null;
      _selectedSubDistrict = null;
      _districts = <District>[];
      _subDistricts = <SubDistrict>[];
      if (!fromAutoFill) {
        _postalCodeController.clear();
      }
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
      if (!fromAutoFill) {
        _postalCodeController.clear();
      }
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
      final existingSnapshot =
          await collection.where('uid', isEqualTo: uid).get();
      final isOnlyAddress = existingSnapshot.docs.length <= 1;

      if (_isEditing) {
        final current = _initialAddress;
        if (current == null) {
          throw Exception('ไม่พบข้อมูลที่อยู่นี้');
        }

        final shouldSetDefault = _setAsDefault || isOnlyAddress;
        if (shouldSetDefault) {
          for (final doc in existingSnapshot.docs
              .where((element) => element.id != current.id)) {
            await doc.reference.update({'is_default': 1});
          }
        }

        final now = FieldValue.serverTimestamp();
        final data = <String, dynamic>{
          'addr_id': current.id,
          'uid': uid,
          'label': _labelController.text.trim(),
          'fullAddress': _buildFullAddress(),
          'province': _selectedProvince?.nameTh,
          'provinceId': _selectedProvince?.id,
          'district': _selectedDistrict?.nameTh,
          'districtId': _selectedDistrict?.id,
          'subDistrict': _selectedSubDistrict?.nameTh,
          'subDistrictId': _selectedSubDistrict?.id,
          'postalCode': _postalCodeController.text.trim(),
          'addressNumber': _addressNumberController.text.trim(),
          'lat': latLng.latitude,
          'lng': latLng.longitude,
          'is_default': shouldSetDefault ? 0 : 1,
          'update_at': now,
        };

        await collection.doc(current.id).update(data);
      } else {
        final shouldSetDefault =
            _setAsDefault || existingSnapshot.docs.isEmpty;

        final docRef = collection.doc();
        final now = FieldValue.serverTimestamp();

        if (_setAsDefault) {
          for (final doc in existingSnapshot.docs
              .where((element) =>
                  (element.data()['is_default'] as num?)?.toInt() == 0)) {
            await doc.reference.update({'is_default': 1});
          }
        }

        final newAddress = <String, dynamic>{
          'addr_id': docRef.id,
          'uid': uid,
          'label': _labelController.text.trim(),
          'fullAddress': _buildFullAddress(),
          'province': _selectedProvince?.nameTh,
          'provinceId': _selectedProvince?.id,
          'district': _selectedDistrict?.nameTh,
          'districtId': _selectedDistrict?.id,
          'subDistrict': _selectedSubDistrict?.nameTh,
          'subDistrictId': _selectedSubDistrict?.id,
          'postalCode': _postalCodeController.text.trim(),
          'addressNumber': _addressNumberController.text.trim(),
          'lat': latLng.latitude,
          'lng': latLng.longitude,
          'is_default': shouldSetDefault ? 0 : 1,
          'create_at': now,
          'update_at': now,
        };

        await docRef.set(newAddress);
      }

      if (!mounted) return;

      await showSuccessDialog(
        context,
        title: 'สำเร็จ!',
        message: _isEditing
            ? 'บันทึกการเปลี่ยนแปลงเรียบร้อยแล้ว 🎉'
            : 'บันทึกที่อยู่เรียบร้อยแล้ว 🎉',
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
    var name = value.toString().trim();
    if (name.isEmpty) return null;

    final patterns = <RegExp>[
      RegExp(r'^จังหวัด'),
      RegExp(r'^เขต'),
      RegExp(r'^อำเภอ'),
      RegExp(r'^เทศบาล'),
      RegExp(r'^ตำบล'),
      RegExp(r'^แขวง'),
      RegExp(r'^ต\.'),
      RegExp(r'^อ\.'),
      RegExp(r'^จ\.'),
      RegExp(r'^(Chang\s*Wat)\s+', caseSensitive: false),
      RegExp(r'^(Province|Prov\.)\s+', caseSensitive: false),
      RegExp(r'^(Amphoe|King\s*Amphoe|Amphur)\s+', caseSensitive: false),
      RegExp(r'^(District|Dist\.)\s+', caseSensitive: false),
      RegExp(r'^(Tambon|Sub[-\s]*district|Subdistrict|Khwaeng)\s+',
          caseSensitive: false),
      RegExp(r'^(Mueang|Muang)\s+', caseSensitive: false),
      RegExp(r'^(City\s*of)\s+', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      name = name.replaceFirst(pattern, '');
    }

    final suffixPatterns = <RegExp>[
      RegExp(r'\s+(Province|Prov\.|Chang\s*Wat)$', caseSensitive: false),
      RegExp(r'\s+(District|Dist\.|County|City)$', caseSensitive: false),
      RegExp(r'\s+(Sub[-\s]*district|Subdistrict|Tambon|Khwaeng)$',
          caseSensitive: false),
      RegExp(r'\s+(Municipality|Borough|Township)$', caseSensitive: false),
    ];

    for (final pattern in suffixPatterns) {
      name = name.replaceAll(pattern, '');
    }

    name = name.replaceAll(RegExp(r'\s+'), ' ');
    return name.trim();
  }

  String _normalize(String? input) {
    var value = (input ?? '').toLowerCase();
    value = value
        .replaceAll(RegExp(r'[\s\-_/\\.,()]+'), '')
        .replaceAll('จ\.', '')
        .replaceAll('อ\.', '')
        .replaceAll('ต\.', '')
        .replaceAll('จังหวัด', '')
        .replaceAll('อำเภอ', '')
        .replaceAll('ตำบล', '')
        .replaceAll('แขวง', '')
        .replaceAll('เขต', '')
        .replaceAll('กรุงเทพมหานคร', 'กรุงเทพ')
        .replaceAll('krungthepmahanakhon', 'bangkok')
        .replaceAll('khet', '')
        .replaceFirst(RegExp(r'^mueang'), '')
        .replaceFirst(RegExp(r'^muang'), '')
        .replaceAll('district', '')
        .replaceAll('province', '')
        .replaceAll('subdistrict', '')
        .replaceAll('tambon', '')
        .replaceAll('khwaeng', '')
        .replaceAll('amphoe', '')
        .replaceAll('kingamphoe', '')
        .replaceAll('amphur', '')
        .replaceAll('city', '')
        .replaceAll('county', '')
        .replaceAll('municipality', '')
        .replaceAll('metropolitan', '')
        .replaceAll('region', '')
        .replaceAll('borough', '')
        .replaceAll('area', '')
        .replaceAll('thailand', '')
        .replaceAll('ofthe', '')
        .replaceAll('bangkokmetropolis', 'bangkok');
    return value;
  }

  bool _normalizedStringsMatch(String a, String b) {
    if (a.isEmpty || b.isEmpty) {
      return false;
    }
    if (a == b) {
      return true;
    }
    return a.contains(b) || b.contains(a);
  }

  String? _firstNonEmpty(
    Map<String, dynamic> components,
    List<String> candidates,
  ) {
    for (final key in candidates) {
      final value = components[key];
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      }
    }
    return null;
  }
}
