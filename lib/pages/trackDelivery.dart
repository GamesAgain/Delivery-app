import 'dart:async';
import 'dart:math';

import 'package:bootstrap_icons/bootstrap_icons.dart';
// import 'package:bootstrap_icons/bootstrap_icons.dart'; // <- ลบออกแล้ว
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_map/flutter_map.dart' as fl;
import 'package:latlong2/latlong.dart' as fl;
// ---
import 'package:google_fonts/google_fonts.dart';

class TrackDeliveryPage extends StatefulWidget {
  const TrackDeliveryPage({super.key, this.deliveryId, this.itemName});

  final String? deliveryId;
  final String? itemName;

  @override
  State<TrackDeliveryPage> createState() => _TrackDeliveryPageState();
}

class _TrackDeliveryPageState extends State<TrackDeliveryPage> {
  // --- ค่าคงที่ของ Page ---
  static const Color _background = Color(0xFF0B0F19);
  static const Color _panel = Color(0xFF111827);
  static const Color _green = Color(0xFF16A34A);
  static const Color _white = Colors.white;

  static const Map<int, String> _statusLabels = {
    1: 'รอไรเดอร์มารับสินค้า', // Waiting for rider pickup
    2: 'ไรเดอร์รับงาน', // Rider accepted
    3: 'ไรเดอร์รับสินค้าแล้ว', // Rider picked up item
    4: 'ไรเดอร์นำส่งสินค้าแล้ว', // Rider delivered item
  };

  // --- (แก้ไข) เปลี่ยน CameraPosition เป็น LatLng ของ latlong2 ---
  static final fl.LatLng _initialCameraPosition = fl.LatLng(
    13.736717,
    100.523186,
  );
  // ---

  // --- State Variables ---
  final Map<String, Future<_DeliveryDetails?>> _deliveryCache = {};
  final Map<String, Future<_UserProfile?>> _userCache = {};
  final Map<String, Future<_RiderProfile?>> _riderCache = {};
  final Map<String, Future<String?>> _addressCache = {};

  // --- (แก้ไข) เปลี่ยน MapController ---
  final fm.MapController _mapController = fm.MapController();
  // ---
  late final Stream<List<_TrackedDelivery>> _deliveriesStream;
  final _locationStreamController =
      StreamController<Map<String, fl.LatLng?>>.broadcast();
  final Map<String, StreamSubscription<rtdb.DatabaseEvent>> _rtdbListeners = {};
  final Map<String, fl.LatLng?> _currentLocations = {};
  StreamSubscription<List<_TrackedDelivery>>? _firestoreSubscription;
  Stream<Map<String, fl.LatLng?>> get _realtimeLocationStream =>
      _locationStreamController.stream;
  // --- (ลบ) ไม่ต้องใช้ไอคอน Marker แบบ Bitmap ---
  // BitmapDescriptor? _defaultMarkerIcon;
  // BitmapDescriptor? _selectedMarkerIcon;
  // ---

  // --- (ลบ) ไม่ต้องเช็ค Map Ready ---
  // bool _isMapReady = false;
  // ---
  String? _pendingFocusDeliveryId;
  String? _focusedDeliveryId;
  String? _lastCameraSignature;

  @override
  void initState() {
    super.initState();
    _pendingFocusDeliveryId = widget.deliveryId;
    _focusedDeliveryId = widget.deliveryId;
    _deliveriesStream = _trackedDeliveriesStream();
    _firestoreSubscription = _deliveriesStream.listen(
      _onDeliveriesUpdated,
      onError: (error, stackTrace) {
        // --- Stream Safety Check ---
        if (_locationStreamController.isClosed) {
          return;
        }
        _locationStreamController.addError(error, stackTrace);
      },
    );
  }


  @override
  void dispose() {
    // --- (แก้ไข) dispose controller ใหม่ ---
    _mapController.dispose();
    // ---
    final firestoreSubscription = _firestoreSubscription;
    _firestoreSubscription = null; // Set to null *before* cancelling
    if (firestoreSubscription != null) {
      unawaited(firestoreSubscription.cancel());
    }

    // Cancel all RTDB listeners
    for (final subscription in _rtdbListeners.values) {
      unawaited(subscription.cancel());
    }
    _rtdbListeners.clear();

    // Close the location stream controller
    unawaited(_locationStreamController.close());

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: _white),
        title: Text(
          widget.deliveryId == null ? 'Track Deliveries' : 'Delivery Tracking',
          style: GoogleFonts.poppins(
            color: _white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          // Listen to the main delivery data stream from Firestore
          child: StreamBuilder<List<_TrackedDelivery>>(
            stream: _deliveriesStream,
            builder: (context, snapshot) {
              // Show loading indicator while waiting for data
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Show error message if Firestore stream fails
              if (snapshot.hasError) {
                print("Firestore Stream Error: ${snapshot.error}"); // Log error
                return Center(
                  child: Text(
                    'ไม่สามารถโหลดข้อมูลการติดตามได้', // Cannot load tracking data
                    style: GoogleFonts.poppins(color: Colors.white70),
                  ),
                );
              }

              // Get the list of deliveries (or empty list if none)
              final deliveries = snapshot.data ?? const <_TrackedDelivery>[];

              return StreamBuilder<Map<String, fl.LatLng?>>(
                stream: _realtimeLocationStream,
                builder: (context, locationSnapshot) {
                  // Get latest realtime positions (or empty map)
                  final realtimePositions =
                      locationSnapshot.data ?? const <String, fl.LatLng?>{};
                  final finalPositions =
                      _mergePositions(deliveries, realtimePositions);

                  // Schedule camera updates and focusing after the frame builds
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    // --- (แก้ไข) ลบการเช็ค _isMapReady ---
                    _updateCamera(deliveries, finalPositions);
                    // ---
                    if (_pendingFocusDeliveryId != null) {
                      final target = _findDeliveryById(
                        deliveries,
                        _pendingFocusDeliveryId!,
                      );
                      if (target != null) {
                        final didFocus = _focusDeliveryOnMap(
                          target,
                          updateState: true, // Update state to reflect focus change
                          positionOverride: finalPositions[target.did],
                        );
                        // If focusing was successful, clear the pending ID
                        if (didFocus) {
                          _pendingFocusDeliveryId = null;
                        }
                      }
                    }
                  });

                  // Build the main page layout
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(deliveries), // Title, subtitle, latest update time
                      const SizedBox(height: 16),
                      Expanded(
                        child: _buildMap( // The map widget itself
                          deliveries,
                          finalPositions,
                          // Pass loading/error state from the location stream
                          isLoading: locationSnapshot.connectionState ==
                              ConnectionState.waiting,
                          error: locationSnapshot.hasError
                              ? 'เกิดข้อผิดพลาดในการเชื่อมต่อข้อมูลตำแหน่ง' // Error connecting to location data
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // List of delivery info cards at the bottom
                      _buildDeliveryList(deliveries, finalPositions),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // Called when the Firestore stream provides a new list of deliveries
  void _onDeliveriesUpdated(List<_TrackedDelivery> deliveries) {
    if (!mounted) return; // Safety check

    final newDeliveryIds = deliveries.map((delivery) => delivery.did).toSet();
    final existingDeliveryIds = _rtdbListeners.keys.toSet();

    // Remove listeners for deliveries no longer being tracked
    final idsToRemove = existingDeliveryIds.difference(newDeliveryIds);
    for (final id in idsToRemove) {
      final subscription = _rtdbListeners.remove(id);
      if (subscription != null) {
        unawaited(subscription.cancel());
      }
      _currentLocations.remove(id); // Remove location if listener is removed
    }

    // Add listeners for new deliveries
    final idsToAdd = newDeliveryIds.difference(existingDeliveryIds);
    for (final id in idsToAdd) {
      if (id.isEmpty) {
        print("Warning: Empty delivery ID encountered."); // Log warning
        continue; // Skip empty IDs
      }

      // --- (แก้ไข) เปลี่ยน Path การฟัง RTDB ---
      // ให้ตรงกับ Rider's App (deliveries/$id/riderLocation)
      final ref = rtdb.FirebaseDatabase.instance
          .ref('deliveries/$id/riderLocation');
      // ---
      final subscription = ref.onValue.listen(
        (event) {
          // --- Stream Safety Check ---
          if (_locationStreamController.isClosed) return;

          // Extract location from the RTDB snapshot
          final latLng = _extractRealtimeLocation(event.snapshot.value);
          if (latLng != null) {
            _currentLocations[id] = latLng; // Update current location
          } else {
            // Optional: Handle case where location becomes null (e.g., rider stopped sharing)
             _currentLocations.remove(id); // Or keep the last known? Decide based on UX needs.
             print("RTDB: Location for $id became null.");
          }
          // Push the updated map of all current locations to the stream
          _locationStreamController
              .add(Map<String, fl.LatLng?>.from(_currentLocations));
        },
        onError: (error, stackTrace) {
          // --- Stream Safety Check ---
          if (_locationStreamController.isClosed) return;
          print("RTDB Listener Error for $id: $error"); // Log RTDB error
          // Propagate the error to the main location stream
          _locationStreamController.addError(error, stackTrace);
        },
      );
      _rtdbListeners[id] = subscription; // Store the subscription
    }

    if (_locationStreamController.isClosed) {
      return;
    }
    _locationStreamController.add(Map<String, fl.LatLng?>.from(_currentLocations));
  }

  // --- (แก้ไข) ปรับฟังก์ชันให้รับข้อมูลจาก Path ใหม่ ---
  fl.LatLng? _extractRealtimeLocation(dynamic data) {
    // ข้อมูลจาก 'deliveries/$id/riderLocation'
    // จะเป็น Map ของ location โดยตรง เช่น { 'latitude': ..., 'longitude': ... }
    // จึงเรียก _latLngFromDynamic ได้เลย
    return _latLngFromDynamic(data);
  }
  // ---

  // --- (แก้ไข) เปลี่ยนชนิดข้อมูลที่ return เป็น fl.LatLng ---
  fl.LatLng? _latLngFromDynamic(dynamic value) {
    if (value is GeoPoint) {
      return fl.LatLng(value.latitude, value.longitude);
    }
    // Handle Map containing lat/lng keys (various casings)
    if (value is Map) {
      final lat = _tryParseDouble(
        value['lat'] ??
            value['latitude'] ??
            value['Lat'] ??
            value['latLng']?['lat'], // Handle nested structure
      );
      final lng = _tryParseDouble(
        value['lng'] ??
            value['longitude'] ??
            value['Lng'] ??
            value['latLng']?['lng'], // Handle nested structure
      );
      if (lat != null && lng != null) {
        return fl.LatLng(lat, lng);
      }
    }
    return null; // Could not parse
  }
  // ---

  // --- (แก้ไข) เปลี่ยนชนิดข้อมูลที่ return ---
  Map<String, fl.LatLng> _mergePositions(
    List<_TrackedDelivery> deliveries,
    Map<String, fl.LatLng?> realtimePositions,
  ) {
    final merged = <String, fl.LatLng>{};
    // ---
    for (final delivery in deliveries) {
      // Prefer the realtime location if available
      final realtime = realtimePositions[delivery.did];
      if (realtime != null) {
        merged[delivery.did] = realtime;
        continue;
      }
      // Otherwise, use the fallback position from Firestore (if it exists)
      final fallback = delivery.position;
      if (fallback != null) {
        merged[delivery.did] = fallback;
      }
      // If neither exists, this delivery won't have a position in the merged map
    }
    return merged;
  }

  // Creates the Firestore query stream for deliveries
  Stream<List<_TrackedDelivery>> _trackedDeliveriesStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    // Return an empty stream immediately if user is not logged in
    if (currentUser == null) {
      print("Error: Current user is null. Cannot fetch deliveries.");
      return Stream<List<_TrackedDelivery>>.value(const []);
    }

    // Base query: deliveries tracked by the current user
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('delivery_tracking') // Assuming this collection exists
        .where('sender_uid', isEqualTo: currentUser.uid); // Filter by sender

    // If a specific deliveryId is provided (e.g., from deep link), filter further
    if (widget.deliveryId != null && widget.deliveryId!.isNotEmpty) {
      query = query.where('did', isEqualTo: widget.deliveryId);
    }

    // Listen to snapshots and asynchronously map them to _TrackedDelivery objects
    return query.snapshots().asyncMap((snapshot) async {
      // Process each document concurrently using Future.wait
      final futures = snapshot.docs.map(_buildTrackedDelivery).toList();
      final results = await Future.wait(futures);
      // Filter out any null results (e.g., failed fetches)
      final filtered =
          results.whereType<_TrackedDelivery>().toList(growable: false);
      // Sort deliveries by last updated time (newest first)
      filtered.sort(
        (a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return filtered;
    });
  }

  // Asynchronously builds a _TrackedDelivery object from a Firestore document
  Future<_TrackedDelivery?> _buildTrackedDelivery(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    try {
      final data = doc.data();
      final did = (data['did'] as String?)?.trim() ?? doc.id;
      if (did.isEmpty) {
         print("Warning: Document ${doc.id} has empty 'did'. Skipping.");
         return null;
      }
      final statusCode = _parseStatusCode(data['status_code']);

      // Fetch related details (delivery, profiles, addresses) concurrently
      // Use null-aware operators for potentially missing UIDs/IDs
      final detailsFuture = _fetchDeliveryDetails(did);
      final riderProfileFuture = _fetchRiderProfile(
        (data['rider_uid'] as String?)?.trim() ?? detailsFuture.then((d) => d?.riderUid),
      );
      final senderProfileFuture = _fetchUserProfile(
        (data['sender_uid'] as String?)?.trim() ?? detailsFuture.then((d) => d?.senderUid),
      );
      final receiverProfileFuture = _fetchUserProfile(
        (data['receiver_uid'] as String?)?.trim() ?? detailsFuture.then((d) => d?.receiverUid),
      );
      final pickupAddressFuture = _resolveAddress(
         (data['pickup_addr_id'] as String?)?.trim() ?? detailsFuture.then((d) => d?.pickupAddressId),
      );
      final dropoffAddressFuture = _resolveAddress(
         (data['dropoff_addr_id'] as String?)?.trim() ?? detailsFuture.then((d) => d?.dropoffAddressId),
      );

      // Await all futures
      final details = await detailsFuture;
      final riderProfile = await riderProfileFuture;
      final senderProfile = await senderProfileFuture;
      final receiverProfile = await receiverProfileFuture;
      final pickupAddress = await pickupAddressFuture;
      final dropoffAddress = await dropoffAddressFuture;

      // Determine the best item name
      final itemNameRaw = (data['item_name'] as String?)?.trim();
      final itemName = (itemNameRaw != null && itemNameRaw.isNotEmpty)
          ? itemNameRaw
          : details?.itemName // Fallback to details collection
              ?? widget.itemName // Fallback to widget parameter
                  ?? 'รายการจัดส่ง'; // Final fallback (Shipment Item)

      // Determine the last updated timestamp
      final updatedAt = (data['updated_at'] as Timestamp?)?.toDate() ??
          details?.updatedAt ??
          (data['last_updated'] as Timestamp?)?.toDate();

      // Determine the position (prefer tracking data, fallback to details)
      final position = _parsePosition(data) ?? details?.position;

      return _TrackedDelivery(
        did: did,
        itemName: itemName,
        position: position,
        statusCode: statusCode,
        statusLabel: _statusLabels[statusCode] ?? 'สถานะไม่ทราบ', // Unknown Status
        updatedAt: updatedAt,
        riderProfile: riderProfile,
        senderProfile: senderProfile,
        receiverProfile: receiverProfile,
        // Use resolved address, fallback to raw address in details
        pickupAddress: pickupAddress ?? details?.pickupAddress,
        dropoffAddress: dropoffAddress ?? details?.dropoffAddress,
      );
    } catch (e, s) {
        print("Error building TrackedDelivery for doc ${doc.id}: $e\n$s");
        return null; // Return null if processing fails
    }
  }

  // Builds the header section (Title, Subtitle, Last Update)
  Widget _buildHeader(List<_TrackedDelivery> deliveries) {
    final isSingle = widget.deliveryId != null;
    // Determine title based on single or multiple deliveries
    final title = isSingle
        ? (widget.itemName ?? deliveries.firstOrNull?.itemName ?? 'Delivery')
        : 'Delivery Tracking';
    // Determine subtitle based on single or multiple deliveries
    final subtitle = isSingle
        ? (deliveries.firstOrNull?.statusLabel ?? 'กำลังตรวจสอบสถานะ') // Checking Status
        : 'คุณมีไรเดอร์ ${deliveries.length} คนกำลังจัดส่ง'; // You have X riders delivering
    final latest = _latestUpdatedAt(deliveries); // Find the most recent update time

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            color: _white,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                subtitle,
                style: GoogleFonts.poppins(
                  color: Colors.white60,
                  fontSize: 13,
                ),
              ),
            ),
            // Show latest update time if available
            if (latest != null)
              Container(
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.2), // Use theme color
                  borderRadius: BorderRadius.circular(18),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min, // Prevent row from expanding
                  children: [
                    const Icon(
                      BootstrapIcons.clock_history,
                      color: _green,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatRelativeTime(latest), // Format time relatively
                      style: GoogleFonts.poppins(
                        color: _green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  // Builds the FlutterMap widget and its overlays
  Widget _buildMap(
    List<_TrackedDelivery> deliveries,
    Map<String, fl.LatLng> positions, {
    required bool isLoading,
    String? error,
  }) {
    final hasDeliveries = deliveries.isNotEmpty;
    // --- (แก้ไข) เปลี่ยนชนิด Marker ---
    final markers = <fm.Marker>{};
    // ---

    // Create markers for each delivery with a valid position
    for (final delivery in deliveries) {
      final position = positions[delivery.did];
      if (position == null) continue; // Skip if no position
      markers.add(_createMarker(delivery, position));
    }

    return Container(
      decoration: BoxDecoration(
        color: _panel, // Background color for the map container
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect( // Clip the map to rounded corners
        borderRadius: BorderRadius.circular(30),
        child: Stack( // Use Stack for overlays
          children: [
            // --- (แก้ไข) เปลี่ยน GoogleMap เป็น FlutterMap ---
            fm.FlutterMap(
              mapController: _mapController,
              options: fm.MapOptions(
                initialCenter: _initialCameraPosition,
                initialZoom: 12,
              ),
              children: [
                // Layer 1: พื้นหลังแผนที่
                fm.TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // *** สำคัญ: ใส่ User Agent ของแอปคุณ ***
                  userAgentPackageName: 'com.example.yourapp',
                ),
                // Layer 2: Markers
                fm.MarkerLayer(markers: markers.toList()),
              ],
            ),
            // ---
            if (!hasDeliveries)
              _buildMapMessage(
                'ยังไม่มีข้อมูลการจัดส่ง', // No delivery data yet
                'เมื่อมีไรเดอร์รับงาน ระบบจะแสดงตำแหน่งที่นี่', // When a rider accepts, position will show here
              )
            // Message when there are deliveries but no positions yet
            else if (positions.isEmpty)
              _buildMapMessage(
                isLoading
                    ? 'กำลังเชื่อมต่อข้อมูลตำแหน่ง...' // Connecting to location data...
                    : 'รอไรเดอร์ส่งตำแหน่งล่าสุด', // Waiting for rider's latest location
                'แสดงผลแบบเรียลไทม์ทันทีที่ไรเดอร์เริ่มเดินทาง', // Realtime display once rider starts moving
              ),
            // Error banner if location stream has an error
            if (error != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _buildErrorBanner(error),
              ),
          ],
        ),
      ),
    );
  }

  // Helper widget for messages overlaid on the map (e.g., "No deliveries")
  Widget _buildMapMessage(String title, String subtitle) {
    return Center( // Center the message container
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6), // Semi-transparent background
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Fit content vertically
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center, // Center subtitle text
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

   // Helper widget for the "Using Fallback Map" notice
  Widget _buildMapNotice(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7), // Slightly darker background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24), // Subtle border
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: Colors.white70,
          fontSize: 11,
        ),
      ),
    );
  }

  // Helper widget for the error banner overlaid on the map
  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x99EF4444), // Semi-transparent red
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(BootstrapIcons.wifi_off, color: Colors.white), // Wifi off icon
          const SizedBox(width: 8),
          Expanded( // Allow text to wrap
            child: Text(
              message,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- (แก้ไข) สร้าง Marker สำหรับ flutter_map ---
  fm.Marker _createMarker(_TrackedDelivery delivery, fl.LatLng position) {
    final isSelected = delivery.did == _focusedDeliveryId;
    return fm.Marker(
      width: 100.0,
      height: 80.0,
      point: position,
      child: GestureDetector(
        onTap: () => _onFocusRequest(
          delivery,
          positionOverride: position,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected
                  ? BootstrapIcons.geo_alt_fill
                  : BootstrapIcons.geo_alt,
              color: isSelected ? _green : Colors.blueAccent,
              size: isSelected ? 45 : 35,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: _panel.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                delivery.riderProfile?.username ?? delivery.itemName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: isSelected ? _green : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ---

  // Builds the horizontal list of delivery info cards
  Widget _buildDeliveryList(
    List<_TrackedDelivery> deliveries,
    Map<String, fl.LatLng> positions,
  ) {
    // Show a message if there are no deliveries
    if (deliveries.isEmpty) {
      return Container(
        width: double.infinity, // Take full width
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12), // Subtle border
        ),
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              BootstrapIcons.truck, // Truck icon
              color: Colors.white54,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'ยังไม่มีไรเดอร์ที่กำลังจัดส่ง', // No riders currently delivering
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              'เมื่อมีไรเดอร์รับงานจะเห็นตำแหน่งได้แบบเรียลไทม์ที่นี่', // When rider accepts, see realtime location here
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // Build a fixed-height horizontal ListView for the cards
    return SizedBox(
      height: 240, // Adjust height as needed
      child: ListView.separated(
        physics: const BouncingScrollPhysics(), // iOS-like scroll physics
        // scrollDirection: Axis.horizontal, // Make it horizontal if desired
        itemCount: deliveries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12), // Spacing between cards
        itemBuilder: (context, index) {
          final delivery = deliveries[index];
          final position = positions[delivery.did]; // Get position for this card
          return _buildDeliveryInfoCard(delivery, position); // Build the card widget
        },
      ),
    );
  }

  // Builds a single delivery information card
  Widget _buildDeliveryInfoCard(
    _TrackedDelivery delivery,
    fl.LatLng? position,
  ) {
    final isSelected = delivery.did == _focusedDeliveryId; // Check if this card is focused
    final statusColor = _statusColor(delivery.statusCode); // Get color for status
    final hasPosition = position != null; // Check if position data is available

    return AnimatedContainer( // Animate background color and border changes
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1F2937) : _panel, // Darker when selected
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSelected ? _green : Colors.white12, // Highlight border when selected
          width: 1.2,
        ),
        boxShadow: const [ // Add subtle shadow
          BoxShadow(
            color: Colors.black38,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18), // Inner padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Status Chip and Delivery ID
          Row(
            children: [
              // Status Chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15), // Tinted background
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _statusIcon(delivery.statusCode), // Status icon
                      color: statusColor,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      delivery.statusLabel, // Status text
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(), // Push ID to the right
              // Shortened Delivery ID
              Text(
                '#${delivery.did.substring(0, min(8, delivery.did.length)).toUpperCase()}',
                style: GoogleFonts.poppins(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Item Name
          Text(
            delivery.itemName,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2, // Allow wrapping if name is long
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Rider Info Row
          Row(
            children: [
              // Rider Avatar Placeholder
              CircleAvatar(
                radius: 18,
                backgroundColor: _kDefaultMarkerColor.withOpacity(0.2),
                child: Icon(
                  BootstrapIcons.person_fill, // Generic person icon
                  color: Colors.white.withOpacity(0.9),
                  size: 18,
                ),
                // TODO: Replace with actual rider avatar if available
                // backgroundImage: delivery.riderProfile?.avatarUrl != null
                //     ? NetworkImage(delivery.riderProfile!.avatarUrl!)
                //     : null,
              ),
              const SizedBox(width: 12),
              // Rider Name and Vehicle Plate
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      delivery.riderProfile?.username ?? 'ไรเดอร์', // Rider or fallback
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                       maxLines: 1,
                       overflow: TextOverflow.ellipsis,
                    ),
                    if (delivery.riderProfile?.vehiclePlate != null &&
                        delivery.riderProfile!.vehiclePlate!.isNotEmpty)
                      Text(
                        'ทะเบียน ${delivery.riderProfile!.vehiclePlate}', // License Plate
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // "View Location" Button or "Not Available" Text
              if (hasPosition)
                TextButton.icon(
                  onPressed: () => _onFocusRequest( // Focus map on rider
                    delivery,
                    positionOverride: position,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: _green,
                    padding: EdgeInsets.zero, // Reduce padding
                    minimumSize: Size.zero, // Allow smaller size
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduce tap area
                  ),
                  icon: const Icon(BootstrapIcons.geo_fill, size: 16),
                  label: const Text('ดูตำแหน่ง'), // View Location
                )
              else
                Text(
                  'ตำแหน่งยังไม่พร้อม', // Location not ready
                  style: GoogleFonts.poppins(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Pickup Address
          _buildAddressRow(
            title: 'สถานที่รับสินค้า', // Pickup Location
            icon: BootstrapIcons.box_seam,
            address: delivery.pickupAddress,
          ),
          const SizedBox(height: 8),
          // Dropoff Address
          _buildAddressRow(
            title: 'สถานที่จัดส่ง', // Dropoff Location
            icon: BootstrapIcons.pin_map,
            address: delivery.dropoffAddress,
          ),
          // Display Lat/Lng if position is available
          if (hasPosition) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _kDefaultMarkerColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    BootstrapIcons.radioactive, // Simple location indicator icon
                    color: Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text( // Format Lat/Lng
                      'Lat ${position!.latitude.toStringAsFixed(5)}, '
                      'Lng ${position.longitude.toStringAsFixed(5)}',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper widget to build a row for showing an address (pickup/dropoff)
  Widget _buildAddressRow({
    required String title,
    required IconData icon,
    String? address,
  }) {
    // Return empty space if address is null or empty
    if (address == null || address.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start, // Align icon and text top
      children: [
        // Icon Container
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kDefaultMarkerColor.withOpacity(0.2),
          ),
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        // Title and Address Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                address,
                style: GoogleFonts.poppins(
                  color: Colors.white60,
                  fontSize: 12,
                  height: 1.3, // Adjust line spacing
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Called when a marker or "View Location" button is tapped
  void _onFocusRequest(
    _TrackedDelivery delivery, {
    fl.LatLng? positionOverride,
  }) {
    // Focus the map, updating the state to highlight the correct card/marker
    _focusDeliveryOnMap(
      delivery,
      positionOverride: positionOverride,
      updateState: true, // Make sure UI updates
    );
  }

  // Animates the map camera to focus on a specific delivery's position
  bool _focusDeliveryOnMap(
    _TrackedDelivery delivery, {
    bool updateState = true,
    double zoom = 16,
    fl.LatLng? positionOverride,
  }) {
    // Update the focused delivery ID (conditionally calls setState)
    if (updateState) {
      // Avoid unnecessary rebuilds if already focused
      if (_focusedDeliveryId != delivery.did) {
        setState(() {
          _focusedDeliveryId = delivery.did;
        });
      }
    } else {
      _focusedDeliveryId = delivery.did;
    }

    // Determine the target position
    final position = positionOverride ?? delivery.position;

    // If position is not available yet, mark it as pending and return false
    if (position == null) {
      _pendingFocusDeliveryId = delivery.did;
      return false;
    }

    // --- (แก้ไข) เปลี่ยน animateCamera เป็น move และลบ _isMapReady ---
    _mapController.move(position, zoom);
    // ---
    _pendingFocusDeliveryId = null;
    return true;
  }

  // Updates the map camera view based on the number and positions of markers
  void _updateCamera(
    List<_TrackedDelivery> deliveries,
    Map<String, fl.LatLng> positions,
  ) {
    // Do nothing if there are no positions to show
    if (positions.isEmpty) {
      _lastCameraSignature = null; // Reset signature if map becomes empty
      return;
    }

    // Create a signature of current positions to prevent unnecessary animations
    final signature = positions.entries
        .map((entry) =>
            '${entry.key}:${entry.value.latitude.toStringAsFixed(6)},${entry.value.longitude.toStringAsFixed(6)}')
        .join('|');

    // If positions haven't changed significantly, do nothing
    if (signature == _lastCameraSignature) {
      return;
    }
    _lastCameraSignature = signature; // Update the signature

    // If only one delivery, focus on it
    if (positions.length == 1) {
      final did = positions.keys.first;
      final delivery = _findDeliveryById(deliveries, did);
      if (delivery != null) {
        _focusDeliveryOnMap(
          delivery,
          updateState: false, // Don't call setState here, prevents loop
          positionOverride: positions[did],
        );
      }
      return;
    }

    // _mapController ไม่จำเป็นต้องเช็ค null เพราะเป็น final
    // if (_mapController == null) {
    //   return;
    // }

    // If multiple deliveries, calculate bounds and fit them
    final bounds = _createBounds(positions.values);
    if (bounds != null) {
      // --- (แก้ไข) เปลี่ยน animateCamera เป็น fitCamera ---
      _mapController.fitCamera(
        fm.CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(100.0), // ใส่ padding
        ),
      );
      // ---
    }
  }

  // --- (แก้ไข) เปลี่ยนชนิดข้อมูลที่ return ---
  fm.LatLngBounds? _createBounds(Iterable<fl.LatLng> points) {
    // ---
    final iterator = points.iterator;
    // Return null if the iterable is empty
    if (!iterator.moveNext()) {
      return null;
    }

    // Initialize min/max with the first point
    double minLat = iterator.current.latitude;
    double maxLat = iterator.current.latitude;
    double minLng = iterator.current.longitude;
    double maxLng = iterator.current.longitude;

    // Iterate through the rest of the points to find true min/max
    while (iterator.moveNext()) {
      final point = iterator.current;
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    // --- (แก้ไข) ใช้ LatLngBounds ของ latlong2 ---
    return fl.LatLngBounds(
      fl.LatLng(minLat, minLng), // Southwest
      fl.LatLng(maxLat, maxLng), // Northeast
    );
    // ---
  }

  // --- Data Fetching Helper Functions (with Caching) ---

  Future<_DeliveryDetails?> _fetchDeliveryDetails(String? deliveryId) {
    if (deliveryId == null || deliveryId.isEmpty) {
      return Future.value(null);
    }
    // Return cached future if available, otherwise fetch and cache
    return _deliveryCache.putIfAbsent(deliveryId, () async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('delivery') // Assuming 'delivery' collection
            .doc(deliveryId)
            .get();
        if (!doc.exists || doc.data() == null) {
           print("Delivery details not found for ID: $deliveryId");
          return null;
        }
        final data = doc.data()!;
        return _DeliveryDetails(
          did: deliveryId,
          itemName: (data['item_name'] as String?)?.trim() ?? 'รายการจัดส่ง',
          senderUid: (data['sender_uid'] as String?)?.trim(),
          receiverUid: (data['receiver_uid'] as String?)?.trim(),
          pickupAddressId: (data['pickup_addr_id'] as String?)?.trim(),
          dropoffAddressId: (data['dropoff_addr_id'] as String?)?.trim(),
          pickupAddress: (data['pickup_address'] as String?)?.trim(), // Raw address fallback
          dropoffAddress: (data['dropoff_address'] as String?)?.trim(), // Raw address fallback
          riderUid: (data['rider_uid'] as String?)?.trim() ??
                    (data['assigned_rider_uid'] as String?)?.trim(),
          statusCode: _parseStatusCode(data['status_code']),
          position: _parsePosition(data), // Fallback position
          updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ??
                     (data['status_updated_at'] as Timestamp?)?.toDate(),
        );
      } catch (e, s) {
        print("Error fetching delivery details for $deliveryId: $e\n$s");
        _deliveryCache.remove(deliveryId); // Remove failed entry from cache
        return null;
      }
    });
  }

  Future<_UserProfile?> _fetchUserProfile(String? uid) {
    if (uid == null || uid.isEmpty) {
      return Future.value(null);
    }
    return _userCache.putIfAbsent(uid, () async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users') // Assuming 'users' collection
            .doc(uid)
            .get();
        if (!doc.exists || doc.data() == null) {
           print("User profile not found for UID: $uid");
          return null;
        }
        final data = doc.data()!;
        return _UserProfile(
          uid: uid,
          username: (data['username'] as String?)?.trim() ?? 'ผู้ใช้งาน', // User
        );
      } catch (e, s) {
        print("Error fetching user profile for $uid: $e\n$s");
         _userCache.remove(uid);
        return null;
      }
    });
  }

  Future<_RiderProfile?> _fetchRiderProfile(String? uid) {
    if (uid == null || uid.isEmpty) {
      return Future.value(null);
    }
    return _riderCache.putIfAbsent(uid, () async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('riders') // Assuming 'riders' collection
            .doc(uid)
            .get();
        if (!doc.exists || doc.data() == null) {
          print("Rider profile not found for UID: $uid");
          return null;
        }
        final data = doc.data()!;
        return _RiderProfile(
          uid: uid,
          username: (data['username'] as String?)?.trim() ?? 'Rider',
          avatarUrl: (data['avatar'] as String?)?.trim(),
          vehiclePlate: (data['vehicle_plate'] as String?)?.trim(),
        );
      } catch (e, s) {
        print("Error fetching rider profile for $uid: $e\n$s");
        _riderCache.remove(uid);
        return null;
      }
    });
  }

  Future<String?> _resolveAddress(String? addressId) {
    if (addressId == null || addressId.isEmpty) {
      return Future.value(null);
    }
    return _addressCache.putIfAbsent(addressId, () async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('addresses') // Assuming 'addresses' collection
            .doc(addressId)
            .get();
        if (!doc.exists || doc.data() == null) {
           print("Address not found for ID: $addressId");
          return null;
        }
        final data = doc.data()!;
        // Prioritize full address, then label, then name
        return (data['fullAddress'] as String?)?.trim() ??
               (data['label'] as String?)?.trim() ??
               (data['addressName'] as String?)?.trim();
      } catch (e,s) {
        print("Error resolving address for $addressId: $e\n$s");
         _addressCache.remove(addressId);
        return null;
      }
    });
  }

  // --- (แก้ไข) เปลี่ยนชนิดข้อมูลที่ return ---
  fl.LatLng? _parsePosition(Map<String, dynamic> data) {
    final dynamic locationField = data['location'] ?? data['current_location'];
    if (locationField is GeoPoint) {
      return fl.LatLng(locationField.latitude, locationField.longitude);
    }
    if (locationField is Map<String, dynamic>) {
      final lat =
          _tryParseDouble(locationField['lat'] ?? locationField['latitude']);
      final lng =
          _tryParseDouble(locationField['lng'] ?? locationField['longitude']);
      if (lat != null && lng != null) {
        return fl.LatLng(lat, lng);
      }
    }

    // Try top-level lat/lng keys
    final lat = _tryParseDouble(
      data['lat'] ?? data['latitude'] ?? data['latlng']?['lat'],
    );
    final lng = _tryParseDouble(
      data['lng'] ?? data['longitude'] ?? data['latlng']?['lng'],
    );

    if (lat != null && lng != null) {
      return fl.LatLng(lat, lng);
    }

    // Try 'geo' field (often used for GeoPoint)
    final geo = data['geo'];
    if (geo is GeoPoint) {
      return fl.LatLng(geo.latitude, geo.longitude);
    }
    // ---

    return null; // Could not parse position
  }

  // Safely parses a dynamic value to a double
  double? _tryParseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

 // Safely parses a dynamic status code to an integer (defaults to 1)
  int _parseStatusCode(dynamic raw) {
    if (raw is int) {
      return raw >= 1 && raw <= 4 ? raw : 1; // Basic validation
    }
    if (raw is num) {
       final intVal = raw.toInt();
      return intVal >= 1 && intVal <= 4 ? intVal : 1;
    }
    if (raw is String) {
       final intVal = int.tryParse(raw);
      return intVal != null && intVal >= 1 && intVal <= 4 ? intVal : 1;
    }
    return 1; // Default status
  }

  // Returns a color based on the delivery status code
  Color _statusColor(int statusCode) {
    switch (statusCode) {
      case 1: return const Color(0xFFF97316); // Orange
      case 2: return const Color(0xFF2563EB); // Blue
      case 3: return const Color(0xFFFACC15); // Yellow
      case 4: return _green; // Green
      default: return Colors.white54; // Default grey
    }
  }

  // Returns an icon based on the delivery status code
  IconData _statusIcon(int statusCode) {
    switch (statusCode) {
      case 1: return BootstrapIcons.clock;
      case 2: return BootstrapIcons.bicycle;
      case 3: return BootstrapIcons.box_seam;
      case 4: return BootstrapIcons.check_circle;
      default: return BootstrapIcons.question_circle;
    }
  }

  // Formats a DateTime into a relative time string (e.g., "5 minutes ago")
  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.isNegative) return 'ในอนาคต'; // In the future (shouldn't happen)
    if (diff.inSeconds < 60) return 'เมื่อครู่'; // Just now
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว'; // X minutes ago
    if (diff.inHours < 24) return '${diff.inHours} ชม.ที่แล้ว'; // X hours ago
    return '${diff.inDays} วันที่แล้ว'; // X days ago
  }

  // Finds the most recent update timestamp among all deliveries
  DateTime? _latestUpdatedAt(List<_TrackedDelivery> deliveries) {
    DateTime? latest;
    for (final delivery in deliveries) {
      final updated = delivery.updatedAt;
      if (updated == null) continue; // Skip if no update time
      // Update latest if current is newer
      if (latest == null || updated.isAfter(latest)) {
        latest = updated;
      }
    }
    return latest;
  }

  // Helper to find a specific delivery by ID in the current list
  _TrackedDelivery? _findDeliveryById(
    List<_TrackedDelivery> deliveries,
    String deliveryId,
  ) {
    try {
       return deliveries.firstWhere((d) => d.did == deliveryId);
    } catch (e) {
       return null; // Not found
    }
    // More robust alternative if duplicates are possible (though unlikely with IDs):
    // for (final delivery in deliveries) {
    //   if (delivery.did == deliveryId) {
    //     return delivery;
    //   }
    // }
    // return null;
  }
}

// --- Data Model Classes ---
// (Moved below the main State class for better organization)

// Represents combined data for a single tracked delivery shown in UI
class _TrackedDelivery {
  _TrackedDelivery({
    required this.did,
    required this.itemName,
    required this.statusCode,
    required this.statusLabel,
    // --- (แก้ไข) เปลี่ยนชนิดข้อมูล ---
    this.position,
    // ---
    this.updatedAt,
    this.riderProfile,
    this.senderProfile,
    this.receiverProfile,
    this.pickupAddress,
    this.dropoffAddress,
  });

  final String did;
  final String itemName;
  // --- (แก้ไข) เปลี่ยนชนิดข้อมูล ---
  final fl.LatLng? position;
  // ---
  final int statusCode;
  final String statusLabel;
  final DateTime? updatedAt;
  final _RiderProfile? riderProfile;
  final _UserProfile? senderProfile;
  final _UserProfile? receiverProfile;
  final String? pickupAddress;
  final String? dropoffAddress;
}

// Represents data fetched specifically from the 'delivery' collection
class _DeliveryDetails {
  _DeliveryDetails({
    required this.did,
    required this.itemName,
    this.senderUid,
    this.receiverUid,
    this.pickupAddressId,
    this.dropoffAddressId,
    this.pickupAddress, // Raw address fallback
    this.dropoffAddress, // Raw address fallback
    this.riderUid,
    required this.statusCode,
    // --- (แก้ไข) เปลี่ยนชนิดข้อมูล ---
    this.position,
    // ---
    this.updatedAt,
  });

  final String did;
  final String itemName;
  final String? senderUid;
  final String? receiverUid;
  final String? pickupAddressId;
  final String? dropoffAddressId;
  final String? pickupAddress;
  final String? dropoffAddress;
  final String? riderUid;
  final int statusCode;
  // --- (แก้ไข) เปลี่ยนชนิดข้อมูล ---
  final fl.LatLng? position;
  // ---
  final DateTime? updatedAt;
}

// Represents basic user profile data
class _UserProfile {
  _UserProfile({required this.uid, required this.username});

  final String uid;
  final String username;
}

// Represents basic rider profile data
class _RiderProfile { // <- Ensured correct spelling
  _RiderProfile({
    required this.uid,
    required this.username,
    this.avatarUrl,
    this.vehiclePlate,
  });

  final String uid;
  final String username;
  final String? avatarUrl;
  final String? vehiclePlate;
}

// --- Extensions ---

// Convenience extension to safely get the first element or null
extension ListFirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : this[0];
}
