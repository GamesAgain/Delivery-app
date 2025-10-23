import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';

final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  return GeocodingService();
});

class GeocodingService {
  GeocodingService() : _dio = Dio(BaseOptions(baseUrl: Env.nominatimBaseUrl));

  final Dio _dio;
  DateTime? _lastRequestTime;

  Future<List<GeocodingResult>> search(String query) async {
    await _throttle();
    final response = await _dio.get('/search', queryParameters: {
      'format': 'jsonv2',
      'limit': 5,
      'q': query,
    });
    final list = response.data as List<dynamic>? ?? [];
    return list
        .map((item) => GeocodingResult.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<GeocodingResult?> reverse({
    required double lat,
    required double lon,
  }) async {
    await _throttle();
    final response = await _dio.get('/reverse', queryParameters: {
      'format': 'jsonv2',
      'lat': lat,
      'lon': lon,
    });
    if (response.data is Map<String, dynamic>) {
      return GeocodingResult.fromJson(response.data as Map<String, dynamic>);
    }
    return null;
  }

  Future<void> _throttle() async {
    final last = _lastRequestTime;
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      const minDelay = Duration(milliseconds: 1100);
      if (elapsed < minDelay) {
        await Future<void>.delayed(minDelay - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
  }
}

class GeocodingResult {
  GeocodingResult({required this.displayName, required this.lat, required this.lon});

  factory GeocodingResult.fromJson(Map<String, dynamic> json) {
    return GeocodingResult(
      displayName: json['display_name'] as String? ?? '',
      lat: double.tryParse(json['lat']?.toString() ?? '') ?? 0,
      lon: double.tryParse(json['lon']?.toString() ?? '') ?? 0,
    );
  }

  final String displayName;
  final double lat;
  final double lon;
}
