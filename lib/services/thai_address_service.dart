import 'package:dio/dio.dart';
import 'package:delivery_app/models/thai_address.dart';

class ThaiAddressService {
  ThaiAddressService({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(headers: _defaultHeaders));

  static const _defaultHeaders = <String, dynamic>{
    'User-Agent': 'DeliveryApp/1.0 (https://github.com)',
  };

  final Dio _dio;
  List<Province>? _cachedProvinces;
  List<District>? _cachedDistricts;
  List<SubDistrict>? _cachedSubDistricts;

  static const _provinceUrl =
      'https://raw.githubusercontent.com/kongvut/thai-province-data/main/api_province.json';
  static const _districtUrl =
      'https://raw.githubusercontent.com/kongvut/thai-province-data/main/api_amphure.json';
  static const _subDistrictUrl =
      'https://raw.githubusercontent.com/kongvut/thai-province-data/main/api_tambon.json';

  Future<List<Province>> getProvinces() async {
    if (_cachedProvinces != null) {
      return _cachedProvinces!;
    }
    final response = await _dio.get(_provinceUrl);
    final data = _validateResponseBody(response);
    _cachedProvinces = data
        .map((e) =>
            Province.fromJson(Map<String, dynamic>.from(e as Map<String, dynamic>)))
        .toList()
      ..sort((a, b) => a.nameTh.compareTo(b.nameTh));
    return _cachedProvinces!;
  }

  Future<List<District>> getDistricts(int provinceId) async {
    _cachedDistricts ??= await _loadDistricts();
    return _cachedDistricts!
        .where((district) => district.provinceId == provinceId)
        .toList()
      ..sort((a, b) => a.nameTh.compareTo(b.nameTh));
  }

  Future<List<SubDistrict>> getSubDistricts(int districtId) async {
    _cachedSubDistricts ??= await _loadSubDistricts();
    return _cachedSubDistricts!
        .where((sub) => sub.districtId == districtId)
        .toList()
      ..sort((a, b) => a.nameTh.compareTo(b.nameTh));
  }

  Future<List<District>> _loadDistricts() async {
    final response = await _dio.get(_districtUrl);
    final data = _validateResponseBody(response);
    return data
        .map((e) =>
            District.fromJson(Map<String, dynamic>.from(e as Map<String, dynamic>)))
        .toList();
  }

  Future<List<SubDistrict>> _loadSubDistricts() async {
    final response = await _dio.get(_subDistrictUrl);
    final data = _validateResponseBody(response);
    return data
        .map((e) => SubDistrict.fromJson(
            Map<String, dynamic>.from(e as Map<String, dynamic>)))
        .toList();
  }

  List<dynamic> _validateResponseBody(Response<dynamic> response) {
    if (response.data is! List) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'รูปแบบข้อมูลจังหวัด/อำเภอ/ตำบลไม่ถูกต้อง',
      );
    }
    return response.data as List<dynamic>;
  }
}
