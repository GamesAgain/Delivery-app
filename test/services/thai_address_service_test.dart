import 'dart:convert';

import 'package:delivery_app/services/thai_address_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const provinceUrl = 'https://example.com/provinces';
  const districtUrl = 'https://example.com/districts';
  const subDistrictUrl = 'https://example.com/subDistricts';

  group('ThaiAddressService', () {
    test('loads and caches sorted provinces', () async {
      final adapter = _MockHttpClientAdapter({
        Uri.parse(provinceUrl): [
          {'id': '2', 'name_th': 'ขอนแก่น', 'name_en': 'Khon Kaen'},
          {'id': 1, 'name_th': 'กรุงเทพมหานคร', 'name_en': 'Bangkok'},
        ],
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final service = ThaiAddressService(
        dio: dio,
        provinceUrl: provinceUrl,
        districtUrl: districtUrl,
        subDistrictUrl: subDistrictUrl,
      );

      final provinces = await service.getProvinces();

      expect(provinces, hasLength(2));
      expect(provinces.map((e) => e.nameTh), ['กรุงเทพมหานคร', 'ขอนแก่น']);
      expect(adapter.callCounts[Uri.parse(provinceUrl)], 1);

      final cached = await service.getProvinces();
      expect(identical(provinces, cached), isTrue);
      expect(adapter.callCounts[Uri.parse(provinceUrl)], 1);
    });

    test('filters and sorts districts by province id', () async {
      final adapter = _MockHttpClientAdapter({
        Uri.parse(provinceUrl): {
          'data': [
            {'id': 1, 'name_th': 'กรุงเทพมหานคร', 'name_en': 'Bangkok'},
          ]
        },
        Uri.parse(districtUrl): [
          {
            'id': 10,
            'province_id': 1,
            'name_th': 'เขตบางกอกน้อย',
            'name_en': 'Bangkok Noi',
          },
          {
            'id': 9,
            'province_id': 1,
            'name_th': 'เขตคลองสาน',
            'name_en': 'Khlong San',
          },
          {
            'id': 1,
            'province_id': 2,
            'name_th': 'เมืองเชียงใหม่',
            'name_en': 'Mueang Chiang Mai',
          },
        ],
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final service = ThaiAddressService(
        dio: dio,
        provinceUrl: provinceUrl,
        districtUrl: districtUrl,
        subDistrictUrl: subDistrictUrl,
      );

      final districts = await service.getDistricts(1);

      expect(districts, hasLength(2));
      expect(districts.first.nameTh, 'เขตคลองสาน');
      expect(districts.last.nameTh, 'เขตบางกอกน้อย');
      expect(adapter.callCounts[Uri.parse(districtUrl)], 1);

      final districtsAgain = await service.getDistricts(1);
      expect(districtsAgain, hasLength(2));
      expect(adapter.callCounts[Uri.parse(districtUrl)], 1);
    });

    test('filters sub-districts and exposes zip code', () async {
      final adapter = _MockHttpClientAdapter({
        Uri.parse(provinceUrl): [
          {'id': 1, 'name_th': 'เชียงใหม่', 'name_en': 'Chiang Mai'},
        ],
        Uri.parse(districtUrl): [
          {
            'id': 1,
            'province_id': 1,
            'name_th': 'เมืองเชียงใหม่',
            'name_en': 'Mueang Chiang Mai',
          },
        ],
        Uri.parse(subDistrictUrl): [
          {
            'id': 11,
            'district_id': 1,
            'name_th': 'สุเทพ',
            'name_en': 'Suthep',
            'zip_code': 50200,
          },
          {
            'id': 12,
            'district_id': 1,
            'name_th': 'ช้างเผือก',
            'name_en': 'Chang Phueak',
            'zip_code': '50300',
          },
          {
            'id': 13,
            'district_id': 2,
            'name_th': 'สันทราย',
            'name_en': 'San Sai',
            'zip_code': 50210,
          },
        ],
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final service = ThaiAddressService(
        dio: dio,
        provinceUrl: provinceUrl,
        districtUrl: districtUrl,
        subDistrictUrl: subDistrictUrl,
      );

      final subDistricts = await service.getSubDistricts(1);

      expect(subDistricts, hasLength(2));
      expect(subDistricts.first.zipCode, '50200');
      expect(subDistricts.last.nameTh, 'ช้างเผือก');
      expect(adapter.callCounts[Uri.parse(subDistrictUrl)], 1);
    });

    test('throws DioException when data format is invalid', () async {
      final adapter = _MockHttpClientAdapter({
        Uri.parse(provinceUrl): {'unexpected': []},
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final service = ThaiAddressService(
        dio: dio,
        provinceUrl: provinceUrl,
        districtUrl: districtUrl,
        subDistrictUrl: subDistrictUrl,
      );

      await expectLater(
        service.getProvinces(),
        throwsA(isA<DioException>()),
      );
    });
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  _MockHttpClientAdapter(this._responses);

  final Map<Uri, dynamic> _responses;
  final Map<Uri, int> callCounts = <Uri, int>{};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = options.uri;
    callCounts[uri] = (callCounts[uri] ?? 0) + 1;
    if (!_responses.containsKey(uri)) {
      throw StateError('No mock response registered for $uri');
    }

    final body = jsonEncode(_responses[uri]);
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
