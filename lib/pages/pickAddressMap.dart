import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class PickAddressMapPage extends StatefulWidget {
  final String? uid;
  const PickAddressMapPage({super.key, this.uid});

  @override
  State<PickAddressMapPage> createState() => _PickAddressMapPageState();
}

class _PickAddressMapPageState extends State<PickAddressMapPage> {
  final MapController _mapController = MapController();
  final Dio _dio = Dio();

  // --- State Variables ---
  LatLng? _currentCenter;
  String _currentAddress = 'เลื่อนแผนที่เพื่อเลือกตำแหน่ง';
  bool _isFirstTimeLoading = true; // สำหรับโหลดครั้งแรกที่เข้าหน้า
  bool _isGeocoding = false; // สำหรับตอนกำลังแปลงพิกัดเป็นที่อยู่
  Timer? _debounce;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _determineInitialPosition();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // Step 1: หาตำแหน่งเริ่มต้นของผู้ใช้ (ทำงานครั้งเดียว)
  Future<void> _determineInitialPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentCenter = LatLng(position.latitude, position.longitude);
        _isFirstTimeLoading = false;
        _mapController.move(_currentCenter!, 17.0);
        _startGeocode(_currentCenter!);
      });
    } catch (e) {
      // กรณีหาตำแหน่งไม่ได้จริงๆ ให้ใช้ค่าเริ่มต้น (กรุงเทพ)
      setState(() {
        _currentCenter = const LatLng(13.7563, 100.5018);
        _isFirstTimeLoading = false;
        _errorMessage = "ไม่สามารถเข้าถึงตำแหน่งปัจจุบันได้";
        _startGeocode(_currentCenter!);
      });
    }
  }

  // Step 2: เริ่มกระบวนการแปลงพิกัด (ทำงานเมื่อแผนที่หยุดเลื่อน)
  void _startGeocode(LatLng point) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      // ลดเวลา debounce ลงเล็กน้อย
      _reverseGeocode(point);
    });
  }

  // Step 3: แปลงพิกัดเป็นที่อยู่จริงๆ ผ่าน API
  Future<void> _reverseGeocode(LatLng point) async {
    setState(() {
      _isGeocoding = true;
    });

    final url =
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${point.latitude}&lon=${point.longitude}&accept-language=th';

    try {
      final response = await _dio.get(
        url,
        options: Options(headers: {'User-Agent': 'Stegosight Flutter App'}),
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _currentAddress =
              response.data['display_name'] ?? 'ไม่พบข้อมูลที่อยู่';
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // ไม่ต้องเปลี่ยน _currentAddress แต่แสดง error แทน
          _errorMessage = "การเชื่อมต่อมีปัญหา";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeocoding = false;
        });
      }
    }
  }

  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ส่วนแผนที่และหมุด (อยู่ด้านหลังสุด)
          _buildMap(),
          _buildCenterMarker(),

          // UI ด้านบน (ปุ่ม Back และช่องค้นหา)
          _buildTopUI(),

          // UI ด้านล่าง (ข้อมูลที่อยู่และปุ่มยืนยัน)
          if (!_isFirstTimeLoading) _buildAddressInfoCard(),

          // Loading Indicator สำหรับครั้งแรก
          if (_isFirstTimeLoading)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("กำลังค้นหาตำแหน่งของคุณ..."),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentCenter ?? const LatLng(13.7563, 100.5018),
        initialZoom: 17.0,
        onPositionChanged: (position, hasGesture) {
          if (hasGesture && position.center != null) {
            _startGeocode(position.center!);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.tile.thunderforest.com/atlas/{z}/{x}/{y}.png?apikey=fa73e7cfa2dc480da8d4a68fef53f9e1',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.app',
        ),
      ],
    );
  }

  Widget _buildCenterMarker() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: 40.0), // ขยับให้ปลายหมุดอยู่ตรงกลาง
        child: Icon(Icons.location_pin, color: Colors.green, size: 50.0),
      ),
    );
  }

  Widget _buildTopUI() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 15,
      right: 15,
      child: Row(
        children: [
          FloatingActionButton.small(
            onPressed: () => Navigator.of(context).pop(),
            backgroundColor: Colors.white,
            child: const Icon(Icons.arrow_back, color: Colors.black),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Card(
              elevation: 4,
              color: Color.fromARGB(255, 255, 255, 255),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'ค้นหาที่อยู่หรือชื่ออาคาร',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
                style: TextStyle(color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressInfoCard() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Card(
        margin: EdgeInsets.zero,
        color: const Color(0xFF0B0F19),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        elevation: 10,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ที่อยู่จัดส่ง',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- UI ที่ปรับปรุงแล้ว ---
                  Expanded(
                    child: Text(
                      _currentAddress,
                      style: Theme.of(context).textTheme.bodyLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isGeocoding) // แสดง Indicator เฉพาะตอนโหลด
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                ],
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context, {
                        'address': _currentAddress,
                        'latlng': _currentCenter,
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'ยืนยันที่อยู่จัดส่ง',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
