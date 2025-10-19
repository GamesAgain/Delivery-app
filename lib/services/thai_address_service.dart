import 'dart:convert';

import 'package:delivery_app/models/thai_address.dart';
import 'package:dio/dio.dart';

class ThaiAddressService {
  ThaiAddressService({
    Dio? dio,
    String? provinceUrl,
    String? districtUrl,
    String? subDistrictUrl,
  })  : _dio = dio ?? Dio(BaseOptions(headers: _defaultHeaders)),
        _provinceUrl = provinceUrl ?? _defaultProvinceUrl,
        _districtUrl = districtUrl ?? _defaultDistrictUrl,
        _subDistrictUrl = subDistrictUrl ?? _defaultSubDistrictUrl;

  static const _defaultHeaders = <String, dynamic>{
    'User-Agent': 'DeliveryApp/1.0 (https://github.com)',
  };

  final Dio _dio;
  final String _provinceUrl;
  final String _districtUrl;
  final String _subDistrictUrl;
  List<Province>? _cachedProvinces;
  List<District>? _cachedDistricts;
  List<SubDistrict>? _cachedSubDistricts;

  static const _defaultProvinceUrl =
      'https://raw.githubusercontent.com/kongvut/thai-province-data/refs/heads/master/api/latest/province.json';
  static const _defaultDistrictUrl =
      'https://raw.githubusercontent.com/kongvut/thai-province-data/refs/heads/master/api/latest/district.json';
  static const _defaultSubDistrictUrl =
      'https://raw.githubusercontent.com/kongvut/thai-province-data/refs/heads/master/api/latest/sub_district.json';

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
    dynamic body = response.data;

    if (body is String) {
      if (body.trim().isEmpty) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: 'ไม่พบข้อมูลจังหวัด/อำเภอ/ตำบล',
        );
      }
      try {
        body = jsonDecode(body);
      } on FormatException catch (error) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error:
              'รูปแบบข้อมูลจังหวัด/อำเภอ/ตำบลไม่ถูกต้อง: ${error.message}',
        );
      }
    }

    if (body is List) {
      return body;
    }

    if (body is Map<String, dynamic>) {
      for (final key in const ['data', 'results', 'items']) {
        final dynamic data = body[key];
        if (data is List) {
          return data;
        }
      }
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      error: 'รูปแบบข้อมูลจังหวัด/อำเภอ/ตำบลไม่ถูกต้อง',
    );
  }
}
