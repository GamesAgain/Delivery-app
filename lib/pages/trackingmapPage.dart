import 'dart:async';
import 'dart:math';

import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app/services/upload_img.dart'; // สมมติว่าไฟล์นี้มีอยู่จริง
import 'package:delivery_app/models/user.dart'; // เพิ่ม import สำหรับ Users model

class TrackingMapPage extends StatefulWidget {
  final String? did; // Delivery ID passed to this page
  const TrackingMapPage({super.key, this.did});

  @override
  State<TrackingMapPage> createState() => _TrackingMapPageState();
}

class _TrackingMapPageState extends State<TrackingMapPage> {
  // --- UI Constants from TrackDeliveryPage ---
  static const Color _background = Color(0xFF0B0F19);
  static const Color _panel = Color(0xFF111827);
  static const Color _green = Color(0xFF16A34A);
  static const Color _white = Colors.white;

  static const Map<int, String> _statusLabels = {
    1: 'รอไรเดอร์', // Status code from sender
    2: 'ไรเดอร์รับงาน', // Rider accepted
    3: 'ไรเดอร์รับสินค้าแล้ว', // Rider picked up
    4: 'ไรเดอร์นำส่งสินค้าแล้ว', // Rider delivered
  };

  // --- State Variables from TrackingMapPage ---
  bool _isLoading = true; // Tracks initial data loading
  bool _isUploading = false; // Tracks image upload process
  String? _errorMessage; // Stores any error messages for display
  Delivery? _delivery; // Holds fetched delivery details
  UserAddress? _senderAddress; // Holds fetched sender address details
  UserAddress? _receiverAddress; // Holds fetched receiver address details
  Assignment? _assignment; // Holds fetched assignment details (real-time)
  Position? _riderPosition; // Holds current rider position (real-time)
  String? _senderName; // Holds fetched sender name
  String? _receiverName; // Holds fetched receiver name
  String? _riderName; // Holds fetched rider name
  double _distanceToPickup = double.infinity; // Calculated distance to pickup
  double _distanceToDropoff = double.infinity; // Calculated distance to dropoff

  // --- Map Controller (flutter_map) ---
  final fm.MapController _mapController =
      fm.MapController(); // Controller for map interactions

  // --- Stream Subscriptions ---
  StreamSubscription<Position>?
      _riderLocationSubscription; // For rider location updates
  StreamSubscription? _assignmentSubscription; // For assignment status updates

  // --- Map Markers (flutter_map) ---
  List<fm.Marker> _markers = []; // List to hold map markers

  @override
  void initState() {
    super.initState();
    _initializePage(); // Call initialization logic
  }

  // Handles initial checks and starts data loading
  // --- START MODIFICATION ---
  Future<void> _initializePage() async { // ทำให้เป็น async
    final riderId = FirebaseAuth.instance.currentUser?.uid;

    if (riderId == null) {
      _handleErrorAndExit('Rider not found. Please log in.');
      return;
    }
    if (widget.did == null || widget.did!.isEmpty) {
      _handleErrorAndExit('Delivery ID not provided.');
      return;
    }

    // --- ดึงตำแหน่งเริ่มต้น ---
    try {
      bool permissionGranted = await _handleLocationPermission();
      if (permissionGranted && mounted) {
        Position initialPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          // อาจเพิ่ม timeLimit เพื่อไม่ให้รอนานเกินไป
          // timeLimit: const Duration(seconds: 10),
        );
        if (mounted) { // ตรวจสอบอีกครั้งหลัง await
          final initialLatLng = ll.LatLng(initialPosition.latitude, initialPosition.longitude);
          setState(() {
            _riderPosition = initialPosition;
            // คำนวณระยะทางเบื้องต้น (ถ้า address โหลดมาแล้ว)
            if (_senderAddress != null || _receiverAddress != null) {
              _updateDistances();
            }
             _updateMapMarkers(); // อัปเดต marker ไรเดอร์เริ่มต้น
          });
          _moveCamera(initialLatLng, 16.0); // ย้ายกล้องไปตำแหน่งเริ่มต้น
          _updateRiderLocationInFirestore(riderId, initialPosition); // อัปเดต Firestore ครั้งแรก
        }
      }
    } catch (e) {
       print("Error getting initial location: $e");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('Could not get initial location: $e'),
             backgroundColor: Colors.orange, // Use orange for warnings
           ),
         );
       }
       // ดำเนินการต่อแม้ว่าจะไม่ได้ตำแหน่งเริ่มต้นก็ตาม
    }
    // --- สิ้นสุดการดึงตำแหน่งเริ่มต้น ---


    // If rider and DID are valid, start loading data and listening
    // Note: _initializeData now runs concurrently with initial location fetch,
    // but assignment listener starts inside _initializeData after basic info is fetched.
    _initializeData(widget.did!, riderId); // โหลดข้อมูลอื่นๆ ต่อ
    _startListeningToRiderLocation(riderId); // เริ่มฟังการอัปเดตตำแหน่ง
  }
 // --- END MODIFICATION ---

  // Helper function to show error, stop loading, and navigate away
  void _handleErrorAndExit(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Check if widget is still in the tree
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
        // Try to pop the current route first, if possible
        if (context.canPop()) {
          context.pop();
        } else {
          // Otherwise, navigate to the root or a default screen (e.g., login)
          context.go(
            '/',
          ); // Adjust '/' to your login or home route name if needed
        }
      }
    });
    // Update state to reflect the error and stop loading indicator
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
    }
  }

  @override
  void dispose() {
    // Cancel streams to prevent memory leaks when the widget is removed
    _riderLocationSubscription?.cancel();
    _assignmentSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // --- 1. Initial Data Loading ---
  // Fetches initial static data like Delivery details, addresses, and names
  Future<void> _initializeData(String did, String riderId) async {
    // Don't reset loading state if initial location fetch already set it
    if (!_isLoading && _errorMessage == null && (_delivery != null || _assignment != null)) return;


    // Reset error message for potential retry, keep loading=true if still loading initial location
     if (mounted) {
        setState(() {
            _errorMessage = null;
            // Only set loading true if it wasn't already false due to an error
            if (_errorMessage == null) _isLoading = true;
        });
     }


    try {
      // Fetch Delivery document
      final deliverySnap = await FirebaseFirestore.instance
          .collection('delivery')
          .doc(did)
          .get();
      if (!deliverySnap.exists || deliverySnap.data() == null)
        throw Exception('Delivery not found');

      // Update state with delivery details early if widget still mounted
      if (mounted) {
        setState(() {
          _delivery = Delivery.fromSnap(deliverySnap);
        });
      } else {
        return; // Exit if unmounted after fetching delivery
      }


      // Fetch Sender and Receiver addresses concurrently using Future.wait
      final addresses = await Future.wait([
        if (_delivery!.pickupAddrId.isNotEmpty)
          _fetchAddressById(_delivery!.pickupAddrId)
        else
          Future.value(null),
        if (_delivery!.dropoffAddrId.isNotEmpty)
          _fetchAddressById(_delivery!.dropoffAddrId)
        else
          Future.value(null),
      ]);

      if (!mounted) return; // Check mounted after fetching addresses

      setState(() {
          _senderAddress = addresses[0];
          _receiverAddress = addresses[1];
          // Recalculate distances now that addresses are available
          _updateDistances();
          // Update markers now that addresses might be available
          _updateMapMarkers();
      });


      // Optional: Log warnings if addresses weren't found
      if (_senderAddress == null && _delivery!.pickupAddrId.isNotEmpty)
        print(
          "Warning: Sender address not found for ID: ${_delivery!.pickupAddrId}",
        );
      if (_receiverAddress == null && _delivery!.dropoffAddrId.isNotEmpty)
        print(
          "Warning: Receiver address not found for ID: ${_delivery!.dropoffAddrId}",
        );

      // Fetch Sender, Receiver, and Rider names concurrently
      final names = await Future.wait([
        if (_delivery!.senderUid.isNotEmpty)
          _fetchUserName(_delivery!.senderUid)
        else
          Future.value('Unknown Sender'),
        if (_delivery!.receiverUid.isNotEmpty)
          _fetchUserName(_delivery!.receiverUid)
        else
          Future.value('Unknown Receiver'),
        _fetchRiderName(riderId), // Fetch current rider's name
      ]);

       if (!mounted) return; // Check mounted after fetching names

       setState(() {
         _senderName = names[0];
         _receiverName = names[1];
         _riderName = names[2];
          // Update markers again if rider name changed
         _updateMapMarkers();
       });


      // Start listening for real-time Assignment updates *after* basic data is loaded
      _listenToAssignment(did, riderId);

      // Camera might have already moved based on initial location fetch.
      // Move camera to sender only if rider position is *still* null after initial fetch attempt.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _riderPosition == null && _senderAddress?.lat != null) {
          _moveCamera(ll.LatLng(_senderAddress!.lat!, _senderAddress!.lng!), 15.0);
        }
      });

      // Loading state will be set to false by the assignment listener.

    } catch (e) {
      print("Initialization Error in _initializeData: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load details: ${e.toString()}";
          _isLoading = false; // Stop loading on error
        });
      }
    }
  }

  // Fetches a UserAddress document by its ID from the 'addresses' collection
  Future<UserAddress?> _fetchAddressById(String addrId) async {
    try {
        final snap = await FirebaseFirestore.instance
            .collection('addresses')
            .doc(addrId)
            .get();
        if (!snap.exists || snap.data() == null) return null;
        return UserAddress.fromSnap(snap);
    } catch (e) {
        print("Error fetching address $addrId: $e");
        return null; // Return null on error
    }
  }

  // Fetches a username from the 'users' collection by user ID
  Future<String?> _fetchUserName(String uid) async {
     try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (!snap.exists || snap.data() == null) return 'Unknown User';
        return snap.data()?['username'] as String?;
     } catch(e) {
         print("Error fetching username for $uid: $e");
         return 'Unknown User'; // Return default on error
     }
  }

  // Fetches a rider's name from the 'riders' collection by rider ID
  Future<String?> _fetchRiderName(String rid) async {
     try {
        final snap = await FirebaseFirestore.instance
            .collection('riders')
            .doc(rid)
            .get();
        if (!snap.exists || snap.data() == null) return 'Rider';
        return snap.data()?['username'] as String?;
     } catch (e) {
         print("Error fetching rider name for $rid: $e");
         return 'Rider'; // Return default on error
     }
  }


  // --- 2. Real-time Listeners ---

  // Listens for changes to the specific Assignment document for this delivery and rider
  void _listenToAssignment(String did, String riderId) {
    // Cancel any previous listener to avoid duplicates
    _assignmentSubscription?.cancel();
    _assignmentSubscription = FirebaseFirestore.instance
        .collection('assignment')
        .where('did', isEqualTo: did)
        .where('rid', isEqualTo: riderId)
        .limit(1) // Expecting only one active assignment per did/rid pair
        .snapshots() // Listen for real-time updates
        .listen(
          (snapshot) {
            if (!mounted) return; // Exit if the widget is no longer in the tree

            if (snapshot.docs.isNotEmpty) {
              // --- Assignment found ---
              Assignment newAssignment;
              try {
                newAssignment = Assignment.fromSnap(snapshot.docs.first);
              } catch (e) {
                 print("Error parsing assignment snapshot: $e");
                 setState(() {
                    _errorMessage = "Error loading assignment details.";
                    _isLoading = false;
                    _assignment = null; // Clear potentially corrupt data
                 });
                 return; // Stop processing this snapshot
              }

              // Update state with the new assignment data
              setState(() {
                _assignment = newAssignment;
                _isLoading = false; // Data is loaded (or reloaded)
                _errorMessage = null; // Clear any previous errors
                _updateDistances(); // Recalculate distances based on current status/locations
                _updateMapMarkers(); // Update markers based on current status/locations
              });

              // --- Handle Completion Navigation ---
              // Check if the *new* assignment status indicates completion
              if (newAssignment.statusCode >= 4) {
                 // Delay slightly to ensure UI reflects 'completed' state briefly
                 Future.delayed(const Duration(milliseconds: 200), () {
                    // Check mounted again before navigation, as delay occurred
                    if (mounted) _handleCompletionNavigation();
                 });
              }
            } else {
              // --- Assignment Not Found or Deleted ---
              print(
                "Assignment listener: No documents found for did=$did, rid=$riderId. Assignment might be cancelled or completed by another means.",
              );
              // Update state to reflect missing assignment
              setState(() {
                _assignment = null; // Clear assignment data
                _isLoading = false; // Stop loading indicator
                // Show a specific message if no other error is present
                if (_errorMessage == null) {
                  _errorMessage = "This assignment is no longer active.";
                }
                _updateMapMarkers(); // Update map to remove assignment-related markers
              });
               // Optionally navigate away if assignment disappears unexpectedly
               // _handleErrorAndExit("Assignment not found.");
            }
          },
          onError: (error) {
            // --- Handle Listener Errors ---
            if (!mounted) return;
            print("Assignment stream listener Error: $error");
            setState(() {
              _errorMessage = "Error receiving assignment updates: $error";
              _isLoading = false; // Stop loading on listener error
              _assignment = null; // Clear potentially outdated data
               _updateMapMarkers(); // Clear markers on error
            });
          },
          // Optional: onDone (rarely needed for Firestore streams unless manually closed)
          // onDone: () {
          //   if (mounted) print("Assignment stream closed.");
          // }
        );
  }


  // Starts listening for real-time rider location updates using Geolocator
  void _startListeningToRiderLocation(String riderId) async {
    // Permission check is now done in _initializePage, but double-check service status
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Location services disabled. Cannot track location.')),
        );
        return; // Don't start stream if service is off
    }
     // Permission should already be granted by _initializePage, but check again just in case
    LocationPermission permission = await Geolocator.checkPermission();
     if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
         if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Location permission denied. Cannot track location: $permission')),
             );
         }
         return; // Don't start if permission denied
     }


    // Cancel any existing subscription first
    _riderLocationSubscription?.cancel();

    // Define location settings for the stream
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high, // Use high accuracy for tracking
      distanceFilter: 5, // Update when moved at least 5 meters (adjust as needed for battery/accuracy balance)
      // timeInterval: Duration(seconds: 5), // Alternative: Update every 5 seconds (use either distance or time, not both typically)
    );

    // Start listening to the position stream
    _riderLocationSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
         // Check if the widget is still mounted before processing the update
        if (mounted) {
          final newPos = ll.LatLng(position.latitude, position.longitude);

          // Update state with the new position
          setState(() {
            _riderPosition = position;
            _updateDistances(); // Recalculate distances with new position
            _updateMapMarkers(); // Update rider marker position on the map
          });

          // Update the rider's location in Firestore (can be awaited or run async)
           _updateRiderLocationInFirestore(riderId, position); // No need to await unless critical

          // Optional: Move camera only if rider moves significantly? Or keep centered?
          // For now, let user pan freely after initial centering.
          // _moveCamera(newPos, _mapController.camera.zoom); // Example: Keep zoom level
        }
      },
      onError: (error) {
        // Handle errors from the location stream
        print("Error listening to rider location stream: $error");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location tracking error: $error'),
              backgroundColor: Colors.orange, // Use orange for tracking errors
            ),
          );
           // Consider stopping the stream or attempting to restart?
           // For now, just show error. User might need to toggle location off/on.
        }
      },
       // Optional: Log when the stream is cancelled (e.g., in dispose)
      cancelOnError: false, // Keep listening even after an error, Geolocator might recover
       // onDone: () {
       //   if(mounted) print("Rider location stream closed.");
       // }
    );
  }


  Future<void> _updateRiderLocationInFirestore(
      String riderId, Position position) async {
    final did = widget.did;
    if (did == null || did.isEmpty) {
      return;
    }

    try {
      // Use Rider specific location collection if available, otherwise fallback
      // For now, using a single RiderLocation collection keyed by DID as per original code
      await FirebaseFirestore.instance.collection('RiderLocation').doc(did).set(
        {
          'did': did, // Keep did for potential queries
          'rid': riderId, // Store rider ID
          'lat': position.latitude,
          'lng': position.longitude,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true), // Merge to avoid overwriting unrelated fields if any
      );
    } catch (e) {
      print('Failed to update rider location in Firestore: $e');
      // Optionally show a non-intrusive error indicator to the rider
    }
  }


  // Handles requesting location permissions
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled on the device
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location services are disabled. Please enable them.',
            ),
          ),
        );
      }
      return false;
    }

    // Check the current permission status
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Request permission if denied
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Show message if denied again
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
        }
        return false;
      }
    }

    // Handle case where permission is denied forever (user needs to enable in settings)
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permissions permanently denied, enable in settings.',
            ),
          ),
        );
      }
      return false;
    }

    // Permissions are granted
    return true;
  }

  // --- 3. Geofencing & Distance Calculation ---
  // Calculates distances from rider to pickup and dropoff points
  void _updateDistances() {
    // Only calculate if rider position and relevant addresses are available
    final riderPos = _riderPosition;
    if (riderPos == null) return;

    // Helper to calculate distance safely
    double calcDistance(UserAddress? address) {
      if (address?.lat == null || address?.lng == null) return double.infinity;
      // Use Geolocator to calculate distance between two coordinates
      return Geolocator.distanceBetween(
        riderPos.latitude,
        riderPos.longitude,
        address!.lat!,
        address.lng!,
      );
    }

    // Calculate and store distances (no setState here, called within setState blocks)
    _distanceToPickup = calcDistance(_senderAddress);
    _distanceToDropoff = calcDistance(_receiverAddress);
  }


  // --- 4. Map Logic ---
  // Updates the list of markers displayed on the map based on current state
  void _updateMapMarkers() {
      if (!mounted) return; // Exit if widget is not mounted

      final List<fm.Marker> currentMarkers = []; // Start with an empty list
      final assignmentData = _assignment; // Cache assignment data locally
      final riderPos = _riderPosition;     // Cache rider position locally

      // --- Add Rider Marker ---
      // Add ONLY if position is available
      if (riderPos != null) {
          final riderLatLng = ll.LatLng(
            riderPos.latitude,
            riderPos.longitude,
          );
          currentMarkers.add(
            _createMarker(
              position: riderLatLng,
              type: _MarkerType.rider,
              label: _riderName ?? 'Rider',
              isSelected: true, // Rider is always "selected" on their own screen
            ),
          );
      }

      // --- Add Location Markers (Pickup/Dropoff) ---
      // Need assignment data AND address data to determine which markers to show
      if (assignmentData != null) {
          final int statusCode = assignmentData.statusCode;

          // Add Sender (Pickup) marker if status < 3 and address exists
          final senderAddr = _senderAddress; // Cache locally
          if (statusCode < 3 && senderAddr?.lat != null && senderAddr?.lng != null) {
            currentMarkers.add(
              _createMarker(
                position: ll.LatLng(senderAddr!.lat!, senderAddr.lng!),
                type: _MarkerType.pickup,
                label: _senderName ?? 'ผู้ส่ง',
                isSelected: false,
              ),
            );
          }

          // Add Receiver (Dropoff) marker if status >= 3 and address exists
          final receiverAddr = _receiverAddress; // Cache locally
          if (statusCode >= 3 && receiverAddr?.lat != null && receiverAddr?.lng != null) {
            currentMarkers.add(
              _createMarker(
                position: ll.LatLng(receiverAddr!.lat!, receiverAddr.lng!),
                type: _MarkerType.dropoff,
                label: _receiverName ?? 'ผู้รับ',
                isSelected: false,
              ),
            );
          }
      } else {
        // Optional: Log if assignment data is missing when updating markers
        // This might happen briefly during initial load or if assignment is removed
        print("Debug: _updateMapMarkers called but _assignment is null. Markers might be incomplete.");
      }


      // Update the state to rebuild the map with the new markers
      // Check if mounted again before calling setState, as async operations might have completed after dispose
      if (mounted) {
          // Optimization: Check if markers actually changed before calling setState
          // This avoids unnecessary rebuilds if location updates don't change marker visibility/position significantly
          // For simplicity now, we always call setState. If performance issues arise, add comparison logic here.
          // e.g., if (!listEquals(_markers, currentMarkers)) { ... } // Requires import 'package:flutter/foundation.dart';
          setState(() {
              _markers = currentMarkers;
          });
      }
  }


  // --- Helper for creating markers (from TrackDeliveryPage) ---
  fm.Marker _createMarker({
    required ll.LatLng position,
    required _MarkerType type,
    required String label,
    required bool isSelected,
  }) {
    final icon = _markerIcon(type);
    final color = _markerColor(type, isSelected: isSelected);

    return fm.Marker(
      width: 110,
      height: 90,
      point: position,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: type == _MarkerType.rider ? 42 : 34,
            shadows: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 5,
                  offset: Offset(0, 2))
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _panel.withOpacity(0.75),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Moves the map camera to the specified target and zoom level
  void _moveCamera(ll.LatLng target, double zoom) {
     if (!mounted) return; // Don't attempt if not mounted
    // Use try-catch as the map controller might not be ready immediately
    try {
      // Animate the camera smoothly to the new position
      _mapController.move(target, zoom);
    } catch (e) {
      print("Map not ready for move operation: $e");
      // Optionally schedule a retry after a short delay if needed
      // Future.delayed(Duration(milliseconds: 100), () {
      //   if (mounted) _moveCamera(target, zoom);
      // });
    }
  }


  // --- 5. Action Logic (Pickup/Dropoff Confirmation) ---

  Future<XFile?> _pickProofImage(bool isPickup) async {
    if (!mounted) return null;

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  isPickup ? 'เลือกรูปการรับสินค้า' : 'เลือกรูปการส่งสินค้า',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _white,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: _white),
                title: Text(
                  'ถ่ายรูปด้วยกล้อง',
                  style: GoogleFonts.poppins(color: _white),
                ),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading:
                    const Icon(Icons.photo_library_outlined, color: _white),
                title: Text(
                  'เลือกรูปจากแกลเลอรี',
                  style: GoogleFonts.poppins(color: _white),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (source == null) {
      return null;
    }

    try {
      final ImagePicker picker = ImagePicker();
      return await picker.pickImage(
        source: source,
        imageQuality: 85, // Consider adjusting quality based on needs
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถเลือกรูปภาพได้: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }


  // Handles the process of confirming pickup or delivery, including image capture and upload
  Future<void> _handleStatusUpdate(
    int nextStatusCode, {
    required bool isPickup,
  }) async {
    if (_isUploading || !mounted) return; // Prevent multiple calls & check mounted

    final riderId = FirebaseAuth.instance.currentUser?.uid;
    // Ensure assignment data is available
    if (riderId == null || _assignment == null || _delivery == null) {
      print("Cannot update status: Rider ID, Assignment or Delivery is null.");
       if(mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Missing required data to update status.'), backgroundColor: Colors.orange),
         );
       }
      return;
    }

    // Check Geofence: Rider must be within 20 meters of the target
    final double targetDistance =
        isPickup ? _distanceToPickup : _distanceToDropoff;

     // Add check for infinity distance (means location wasn't available for calculation)
    if (targetDistance == double.infinity) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Cannot verify distance. Please ensure location is active.'),
                backgroundColor: Colors.orange,
            ),
        );
        return;
    }

    if (targetDistance > 20) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Must be closer (${targetDistance.toStringAsFixed(0)}m / 20m)', // Show required distance
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Set loading state
    setState(() => _isUploading = true);

    XFile? image; // Declare image variable outside try block
    String? downloadUrl;

    try {
      image = await _pickProofImage(isPickup);
      if (image == null) {
        // User cancelled image picker
        if (mounted) setState(() => _isUploading = false);
        return; // Exit if no image selected
      }

      if (!mounted) return; // Check mounted after await

      // Show uploading indicator immediately
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploading image... Please wait.'),
          duration: Duration(seconds: 20), // Increase duration slightly
        ),
      );

      // --- Image Upload ---
      final uploadResult = await UploadImgService.uploadXFile(
        xfile: image,
        folder: 'assignments/${_assignment!.aid}', // Use assignment ID for folder
        // Consider unique filename: '${isPickup ? 'pickup' : 'delivery'}_${DateTime.now().millisecondsSinceEpoch}.jpg'
        extraFields: {
          'context': isPickup ? 'pickup' : 'delivery',
          'did': _delivery!.did, // Add delivery ID for context
          'rid': riderId, // Add rider ID for context
        },
      );

       if (!mounted) return; // Check mounted after upload await

      downloadUrl = uploadResult.secureUrl ?? uploadResult.url;
      if (downloadUrl == null || !uploadResult.success) {
         // Use the error message from uploadResult if available
         final errorMsg = uploadResult ?? 'Upload failed. Please try again.';
         throw Exception('Image upload failed: $errorMsg');
      }

       // Hide "Uploading..." snackbar once done
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Image uploaded successfully.'), backgroundColor: Colors.green),
      );


      // --- Firestore Updates (using Batch) ---
      final assignmentRef = FirebaseFirestore.instance
          .collection('assignment')
          .doc(_assignment!.aid); // Use Assignment ID
      final deliveryRef = FirebaseFirestore.instance
          .collection('delivery')
          .doc(_delivery!.did); // Use Delivery ID
      final historyRef = FirebaseFirestore.instance
          .collection('delivery_status_history')
          .doc(); // Auto-generate ID

      final String statusText =
          _statusLabels[nextStatusCode] ?? 'Status Updated'; // Use label map
      final String createdByUserId = isPickup
          ? (_delivery?.senderUid ?? '') // Associate with sender on pickup
          : (_delivery?.receiverUid ?? '');// Associate with receiver on delivery

      // Prepare updates
      final Map<String, dynamic> assignmentUpdate = {
        'status_code': nextStatusCode,
        if (isPickup) 'picked_at': FieldValue.serverTimestamp(),
        if (isPickup) 'pickup_image_url': downloadUrl,
        if (!isPickup) 'delivered_at': FieldValue.serverTimestamp(),
        if (!isPickup) 'delivery_image_url': downloadUrl,
      };

      final Map<String, dynamic> deliveryUpdate = {
        'status_code': nextStatusCode,
        'status': statusText, // Update delivery status text as well
         // Optionally add last known rider location to delivery doc?
         // 'rider_last_location': GeoPoint(_riderPosition!.latitude, _riderPosition!.longitude),
         'updated_at': FieldValue.serverTimestamp(), // Track last update
      };

      final Map<String, dynamic> historyData = {
        'did': _delivery!.did,
        'created_at': FieldValue.serverTimestamp(),
        'created_by_rider_id': riderId, // Log which rider performed action
        'created_by_user_id': createdByUserId, // Log associated user (sender/receiver)
        'image': downloadUrl, // Log image URL for history
        'status_code': nextStatusCode, // Log the new status code
         // Optionally add location where action occurred
         // 'location': GeoPoint(_riderPosition!.latitude, _riderPosition!.longitude),
      };

      // Create and commit batch
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      batch.update(assignmentRef, assignmentUpdate);
      batch.update(deliveryRef, deliveryUpdate);
      batch.set(historyRef, historyData);

      // If completing delivery (status 4), clear active assignment for rider
      if (!isPickup && nextStatusCode == 4) {
        final riderRef =
            FirebaseFirestore.instance.collection('riders').doc(riderId);
        batch.update(riderRef, {'active_assignment_id': FieldValue.delete()}); // Use delete() or null
      }

      await batch.commit();

      // --- Post-Update UI Handling ---
      if (mounted) {
         // No need to manually update _delivery state here,
         // the stream listener for Delivery doc should handle it.
         // Let the assignment stream update _assignment state.
         // setState(() {
         //   _delivery = _delivery?.copyWith(
         //     status: statusText,
         //     statusCode: nextStatusCode,
         //   );
         // });

         // Refresh distances and markers based on potentially updated _assignment state from stream
        _updateDistances();
        _updateMapMarkers();

        if (isPickup) {
           // Move camera towards dropoff after pickup
          if (_receiverAddress?.lat != null && _receiverAddress?.lng != null) {
            _moveCamera(
              ll.LatLng(_receiverAddress!.lat!, _receiverAddress!.lng!),
              15.5, // Maybe slightly different zoom?
            );
          }
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('Pickup Confirmed Successfully!'),
               backgroundColor: Colors.green,
             ),
           );
         } else {
           // Delivery completed, navigate away (handled by stream listener now)
           // await _handleCompletionNavigation(); // Removed from here
            ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('Delivery Confirmed Successfully!'),
               backgroundColor: Colors.green,
             ),
           );
         }
      }

    } catch (e) {
      // Handle errors during the process
      print("Error updating status: $e");
      if (mounted) {
         // Hide "Uploading..." snackbar if it's still showing
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: ${e.toString()}'),
            backgroundColor: Colors.red,
             duration: const Duration(seconds: 5), // Show error longer
          ),
        );
      }
    } finally {
      // Ensure uploading state is reset even if errors occur or process completes
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }


  // Navigates back to the assignment list upon successful delivery completion
  Future<void> _handleCompletionNavigation() async {
    // Ensure this runs only once after completion status is confirmed
    if (!mounted || (_assignment?.statusCode ?? 0) < 4) return;


    // Show completion dialog
    await showDialog<void>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _panel, // Use theme color
          title: Text('จัดส่งเสร็จสิ้น', style: GoogleFonts.poppins(color: _white)),
          content: Text('คุณได้นำส่งสินค้าเรียบร้อยแล้ว', style: GoogleFonts.poppins(color: _white.withOpacity(0.8))),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close the dialog
              },
              child: Text('ตกลง', style: GoogleFonts.poppins(color: _green)),
            ),
          ],
        );
      },
    );

     // Check mounted *after* the dialog is dismissed
    if (!mounted) return;

    final riderId = FirebaseAuth.instance.currentUser?.uid;
    if (riderId != null && riderId.isNotEmpty) {
      try {
        // Fetch the Rider's profile data from 'riders' collection
        final userSnap = await FirebaseFirestore.instance
            .collection('riders') // Corrected collection to 'riders'
            .doc(riderId)
            .get();

        if (userSnap.exists && mounted) { // Check mounted again before navigation
          final profileData = userSnap.data();
           if (profileData == null) {
              throw Exception('Rider profile data is null after fetching.');
           }
          // Use Users.fromMap, ensuring 'uid' is included
          final Users profile = Users.fromMap({
             ...profileData,
             'uid': riderId // Add uid from Auth to the map
          });

          // Navigate to 'index' page, passing uid and profile object
          // Use goNamed for clarity and potential parameter changes
          context.goNamed(
            'index',
            queryParameters: {'uid': riderId},
            extra: profile,
          );
        } else {
          // Fallback if rider profile not found in 'riders' collection
          print("Rider profile not found in 'riders' collection. Navigating to root.");
          context.go('/');
        }
      } catch (e) {
        print("Error fetching rider profile for navigation: $e");
        // Fallback on any error during profile fetch or navigation
         if (mounted) context.go('/');
      }
    } else {
      // Fallback if riderId became null somehow (shouldn't happen if already here)
       if (mounted) context.go('/');
    }
  }


  // --- 6. Build Method (UI Structure) ---
  @override
  Widget build(BuildContext context) {
    // Determine if the back button should be allowed (only after completion)
    bool canPop = (_assignment?.statusCode ?? 0) >= 4;

    // Calculate initial map center coordinates
    ll.LatLng initialCenter = ll.LatLng(
      13.736717, // Bangkok Latitude (fallback)
      100.523186, // Bangkok Longitude (fallback)
    );
    // Prioritize known rider position if available
    if (_riderPosition != null) {
      initialCenter = ll.LatLng(
        _riderPosition!.latitude,
        _riderPosition!.longitude,
      );
    } else if (_senderAddress?.lat != null && _senderAddress?.lng != null) {
      // If no rider pos, center on sender if address is valid
      initialCenter = ll.LatLng(_senderAddress!.lat!, _senderAddress!.lng!);
    }
    // Set a reasonable initial zoom level
    double initialZoom = 15.0;

    // Determine which action button to show based on assignment status
    Widget? actionButton;
    final assignmentData = _assignment; // Cache for readability
    if (!_isLoading && assignmentData != null) {
      int currentStatus = assignmentData.statusCode;
      // Enable button only if distance calculation is valid (not infinity)
      bool isPickupEnabled = _distanceToPickup <= 20 && _distanceToPickup != double.infinity;
      bool isDropoffEnabled = _distanceToDropoff <= 20 && _distanceToDropoff != double.infinity;

      if (currentStatus == 2) {
        // Status: Accepted, waiting for pickup
        actionButton = _buildActionButton(
          label: 'ยืนยันการรับสินค้า', // Thai Label
          icon: BootstrapIcons.box_seam,
          onPressed: isPickupEnabled
              ? () => _handleStatusUpdate(3, isPickup: true) // Go to status 3
              : null, // Disable if not close enough
          isEnabled: isPickupEnabled,
          distance: _distanceToPickup,
          isLoading: _isUploading, // Show loading indicator if uploading
        );
      } else if (currentStatus == 3) {
        // Status: Picked Up, waiting for delivery
        actionButton = _buildActionButton(
          label: 'ยืนยันการจัดส่ง', // Thai Label
          icon: BootstrapIcons.check_circle,
          onPressed: isDropoffEnabled
              ? () => _handleStatusUpdate(4, isPickup: false) // Go to status 4
              : null, // Disable if not close enough
          isEnabled: isDropoffEnabled,
          distance: _distanceToDropoff,
          isLoading: _isUploading, // Show loading indicator if uploading
        );
      }
      // No button needed for status 1 (handled in AssignDetailPage) or status 4+
    }

    // Main scaffold structure
    return PopScope(
      canPop: canPop, // Control back navigation based on completion status
      onPopInvoked: (didPop) {
        // Show message if back navigation is attempted before completion
        if (!didPop && !canPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('กรุณาจัดส่งให้เสร็จสิ้นก่อนย้อนกลับ'), // Thai message
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: _background, // Use dark background consistent theme
        appBar: AppBar(
          title: Text(
            'ติดตามการจัดส่ง', // Thai Title
            style: GoogleFonts.poppins( // Use Poppins for consistency
              color: _white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          backgroundColor: _background, // Dark AppBar background
          iconTheme: const IconThemeData(
            color: _white, // White back arrow
          ),
          elevation: 0, // No shadow for a flatter look
        ),
        body: Stack(
          children: [
            // --- FlutterMap ---
            fm.FlutterMap(
              mapController: _mapController, // Use the defined controller
              options: fm.MapOptions(
                initialCenter: initialCenter, // Use calculated center
                initialZoom: initialZoom,   // Use defined zoom
                minZoom: 10.0, // Prevent zooming out too far
                maxZoom: 18.0, // Allow reasonable zoom in
                onMapReady: () {
                  // Update markers once map is ready and if mounted
                  if (mounted) _updateMapMarkers();
                   // Optionally move camera slightly after map ready if needed
                   // Future.delayed(Duration(milliseconds: 300), () {
                   //    if(mounted) _moveCamera(initialCenter, initialZoom);
                   // });
                },
                interactionOptions: const fm.InteractionOptions(
                  flags: fm.InteractiveFlag.pinchZoom | // Enable pinch zoom
                         fm.InteractiveFlag.drag,     // Enable map drag
                  // Consider adding rotation? fm.InteractiveFlag.rotate
                ),
              ),
              children: [
                fm.TileLayer(
                  // Using OpenStreetMap tile layer
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                   // Important for OSM usage policy
                  userAgentPackageName: 'com.example.delivery_app', // Replace with your actual package name
                   // Optional: Add fallback URL
                  // fallbackUrl: 'https://via.placeholder.com/256/f0f0f0/cccccc?text=Map+Error',
                ),
                fm.MarkerLayer(
                  markers: _markers, // Display the current list of markers
                  // Optional: Adjust marker anchor or rotation if needed
                  // rotate: true,
                  // anchorPos: AnchorPos.align(AnchorAlign.top),
                ),
              ],
            ),

            // --- Bottom Sheet ---
            DraggableScrollableSheet(
              initialChildSize: 0.45, // Start slightly higher
              minChildSize: 0.25,   // Allow shrinking down
              maxChildSize: 0.8,    // Allow expanding significantly
              builder: (context, scrollController) {
                return Container(
                  // Styling consistent with TrackDeliveryPage panel
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 24,
                        color: Color(0x66000000), // Semi-transparent black shadow
                        offset: Offset(0, -4),   // Shadow slightly upwards
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false, // No top padding needed within sheet
                    child: SingleChildScrollView(
                      controller: scrollController, // Link to DraggableScrollableSheet
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), // Consistent padding
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           // Drag handle indicator
                          Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.24),
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),

                          // --- Content Area ---
                          // Show loading indicator centrally if loading
                          if (_isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 40.0), // Add padding
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _green, // Use theme green color
                                  ),
                                ),
                              ),
                            )
                          // Show error message if there's an error
                          else if (_errorMessage != null)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                                child: Text(
                                  'เกิดข้อผิดพลาด: $_errorMessage', // Thai Error prefix
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                      color: Colors.redAccent.shade100, fontSize: 14), // Lighter red
                                ),
                              ),
                            )
                          // Show delivery info and action button if data is ready
                          else if (_delivery != null && _assignment != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // --- Info Card ---
                                _buildDeliveryInfoCard(
                                  delivery: _delivery!,
                                  assignment: _assignment!,
                                  pickup: _senderAddress,
                                  dropoff: _receiverAddress,
                                  riderName: _riderName,
                                  senderName: _senderName,
                                  receiverName: _receiverName,
                                ),
                                const SizedBox(height: 24), // Space before button

                                // --- Action Button (Conditional) ---
                                if (actionButton != null) actionButton,

                                // --- Completion Indicator ---
                                if ((_assignment?.statusCode ?? 0) >= 4)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(top: 24.0, bottom: 8.0), // Add bottom padding too
                                    child: Center( // Center the completion text
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min, // Fit content horizontally
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(BootstrapIcons.check_circle_fill,
                                              color: _green, size: 20), // Slightly smaller icon
                                          const SizedBox(width: 8),
                                          Text(
                                            'จัดส่งเสร็จสมบูรณ์', // Thai Completion text
                                            style: GoogleFonts.poppins(
                                              color: _green,
                                              fontWeight: FontWeight.w600, // Use w600
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          // Fallback message if data is somehow still missing without error/loading
                          else
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40.0),
                                child: Text(
                                  'กำลังรอข้อมูลงาน...', // Thai waiting text
                                  style: GoogleFonts.poppins(
                                      color: Colors.white70, fontSize: 14),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

          ],
        ),
      ),
    );
  }


  // --- 7. Helper Widgets (from TrackDeliveryPage, minor adaptations) ---

  /// Builds the main info card shown in the bottom sheet.
  Widget _buildDeliveryInfoCard({
    required Delivery delivery,
    required Assignment assignment,
    UserAddress? pickup,
    UserAddress? dropoff,
    String? riderName,
    String? senderName,
    String? receiverName,
  }) {
    final statusColor = _statusColor(assignment.statusCode);
    final statusLabel =
        _statusLabels[assignment.statusCode] ?? 'Unknown Status'; // Fallback text
    final statusIcon = _statusIcon(assignment.statusCode);

    return Container(
      // Card styling from TrackDeliveryPage
      decoration: BoxDecoration(
        color: _background, // Slightly darker than panel for contrast
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.1), // Subtle border
          width: 1.0,
        ),
         boxShadow: [ // Add subtle shadow for depth
                BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                ),
            ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Status and ID Row ---
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15), // Use status color accent
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min, // Prevent excessive width
                  children: [
                    Icon(
                      statusIcon,
                      color: statusColor,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(), // Pushes ID to the right
              Text(
                 // Display shortened DID
                '#${delivery.did.substring(0, min(8, delivery.did.length)).toUpperCase()}',
                style: GoogleFonts.poppins(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14), // Increased spacing

          // --- Item Name ---
          Text(
            delivery.itemName.isNotEmpty ? delivery.itemName : "Item (No Name)", // Fallback for item name
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 17, // Slightly larger font
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12), // Increased spacing

          // --- Participant Rows ---
          _buildParticipantRow(
            icon: BootstrapIcons.person_circle,
            title: 'ผู้ส่ง',
            // --- START MODIFICATION ---
            value: senderName ?? (delivery.senderUid.isNotEmpty ? '${delivery.senderUid.substring(0, min(8, delivery.senderUid.length))}...' : 'ไม่ระบุ'),
            // --- END MODIFICATION ---
          ),
          const SizedBox(height: 8), // Consistent spacing
          _buildParticipantRow(
            icon: BootstrapIcons.person,
            title: 'ผู้รับ',
             // --- START MODIFICATION ---
            value: receiverName ?? (delivery.receiverUid.isNotEmpty ? '${delivery.receiverUid.substring(0, min(8, delivery.receiverUid.length))}...' : 'ไม่ระบุ'),
             // --- END MODIFICATION ---
          ),
          const SizedBox(height: 8),
          _buildParticipantRow(
            icon: BootstrapIcons.bicycle,
            title: 'ไรเดอร์',
             // Use riderName if available, otherwise assignment.rid, else fallback
            value: riderName ?? (assignment.rid.isNotEmpty ? '${assignment.rid.substring(0, min(8, assignment.rid.length))}...' : 'รอการมอบหมาย'),
          ),
          const SizedBox(height: 16), // Increased spacing before addresses

          // --- Address Rows ---
          _buildAddressRow(
            title: 'สถานที่รับสินค้า',
            icon: BootstrapIcons.box_seam,
            address: pickup?.fullAddress,
            position:
                pickup?.lat != null ? ll.LatLng(pickup!.lat!, pickup.lng!) : null,
          ),
          const SizedBox(height: 12), // Consistent spacing
          _buildAddressRow(
            title: 'สถานที่จัดส่ง',
            icon: BootstrapIcons.pin_map,
            address: dropoff?.fullAddress,
            position: dropoff?.lat != null
                ? ll.LatLng(dropoff!.lat!, dropoff.lng!)
                : null,
          ),
        ],
      ),
    );
  }


  /// Helper for building rows in the info card (Sender, Receiver, Rider).
  Widget _buildParticipantRow({
    required IconData icon,
    required String title,
    required String value,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
         // Icon container
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2563EB).withOpacity(0.15), // Consistent blue accent
          ),
          child: Icon(icon, color: const Color(0xFF60A5FA), size: 16), // Lighter blue icon
        ),
        const SizedBox(width: 12),
         // Title and Value text column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, // Center vertically
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white60,
                  fontSize: 12,
                  height: 1.2, // Adjust line height
                ),
              ),
              Text(
                value,
                 maxLines: 1, // Prevent long names/UIDs wrapping oddly
                 overflow: TextOverflow.ellipsis, // Add ellipsis if too long
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14, // Slightly smaller font for value
                   height: 1.2,
                ),
              ),
            ],
          ),
        ),
         // Optional trailing widget (like the 'View Location' button)
        if (trailing != null) trailing,
      ],
    );
  }


  /// Helper for building address rows in the info card.
  Widget _buildAddressRow({
    required String title,
    required IconData icon,
    String? address,
    ll.LatLng? position,
  }) {
    final hasAddress = address != null && address.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start, // Align icon to top
      children: [
         // Icon container
        Container(
          padding: const EdgeInsets.all(7), // Slightly smaller padding
           margin: const EdgeInsets.only(top: 2), // Align icon better with text
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2563EB).withOpacity(0.15), // Consistent blue accent
          ),
          child: Icon(icon, color: const Color(0xFF60A5FA), size: 16), // Lighter blue icon
        ),
        const SizedBox(width: 12),
         // Address details column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white, // White title for emphasis
                  fontSize: 13,        // Slightly smaller title
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
               // Show address or placeholder text
              Text(
                hasAddress ? address! : 'ไม่มีข้อมูลที่อยู่', // Thai placeholder
                style: GoogleFonts.poppins(
                  color: hasAddress ? Colors.white70 : Colors.white38, // Dim placeholder
                  fontSize: 12,
                  height: 1.4, // Adjust line height for readability
                ),
              ),
               // Show coordinates if available and address exists
              if (position != null && hasAddress)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Lat ${position.latitude.toStringAsFixed(5)}, Lng ${position.longitude.toStringAsFixed(5)}',
                    style: GoogleFonts.poppins(
                      color: Colors.white54, // Dim coordinates
                      fontSize: 10,       // Smaller font for coordinates
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }


  // Builds the main action button (Confirm Pickup/Delivery)
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isEnabled,
    required double distance,
    required bool isLoading,
  }) {
    String distanceText; // Text indicating distance or status
    if (distance == double.infinity) {
       // Check if rider position is null, meaning location services might be off/denied
      distanceText = _riderPosition == null ? "(รอตำแหน่ง...)" : "(คำนวณระยะ...)";
    } else if (!isEnabled) {
       // Show current distance vs required distance
      distanceText =
          "(${distance.toStringAsFixed(0)}m / 20m)"; // More concise
    } else {
       // Ready state
      distanceText = "(อยู่ในระยะ)"; // Thai "In Range"
    }

     // Button can be interacted with only if enabled AND not currently loading
    final bool canInteract = isEnabled && !isLoading;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250), // Slightly longer fade
      opacity: canInteract ? 1.0 : 0.65, // Make disabled button more visible
      child: Material(
        color: Colors.transparent, // Needed for InkWell splash effect
        child: InkWell(
          borderRadius: BorderRadius.circular(32), // Match Ink decoration radius
          onTap: canInteract ? onPressed : null, // Only allow tap if interactable
           // Disable splash effect when disabled
           splashColor: canInteract ? null : Colors.transparent,
           highlightColor: canInteract ? null : Colors.transparent,
          child: Ink( // Use Ink for decoration and house the content
            width: double.infinity, // Make button full width
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32), // Smooth rounded corners
              gradient: canInteract
                  // Apply gradient only when enabled
                  ? LinearGradient(
                      colors: [_green.withAlpha(230), _green], // Slightly transparent start
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null, // No gradient when disabled
               // Use a grey background when disabled
              color: canInteract ? null : Colors.grey.withOpacity(0.2),
              boxShadow: canInteract
                   // Apply shadow only when enabled
                  ? [
                      BoxShadow(
                        color: _green.withOpacity(0.3), // Softer shadow color
                        blurRadius: 15,
                        offset: const Offset(0, 5), // Slightly lower shadow
                      ),
                    ]
                  : [], // No shadow when disabled
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 // Show loading indicator or icon
                if (isLoading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                 // Button text (Label + Distance/Status)
                Flexible( // Allow text to wrap if needed, though unlikely here
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                       // Main label text
                      text: label,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16, // Slightly smaller font
                        fontWeight: FontWeight.w600, // Use w600
                      ),
                      children: [
                         // Distance/Status text
                        TextSpan(
                          text: ' $distanceText',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.8), // Slightly transparent
                            fontSize: 13, // Smaller font for detail
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // --- 8. Helper Functions (Status/Marker Styling - from TrackDeliveryPage) ---

  // Returns color based on status code
  Color _statusColor(int statusCode) {
    // Using switch expression for conciseness
    return switch (statusCode) {
      1 => const Color(0xFFF97316), // Orange for waiting
      2 => const Color(0xFF3B82F6), // Blue for accepted
      3 => const Color(0xFFEAB308), // Yellow for picked up
      4 => const Color(0xFF22C55E), // Green for delivered
      _ => Colors.grey.shade500,   // Grey for unknown/default
    };
  }

  // Returns icon based on status code
  IconData _statusIcon(int statusCode) {
     // Using switch expression
    return switch (statusCode) {
      1 => BootstrapIcons.clock_history, // Waiting icon
      2 => BootstrapIcons.bicycle,       // Accepted icon
      3 => BootstrapIcons.box_seam_fill, // Picked up icon
      4 => BootstrapIcons.check_circle_fill,// Delivered icon
      _ => BootstrapIcons.question_circle, // Default icon
    };
  }

  // Returns marker color based on type and selection state
  Color _markerColor(_MarkerType type, {required bool isSelected}) {
     // Brighter/more distinct colors
    return switch (type) {
      _MarkerType.pickup  => isSelected ? Colors.blue.shade600 : Colors.blue.shade400,
      _MarkerType.dropoff => isSelected ? Colors.purple.shade600 : Colors.purple.shade400,
      _MarkerType.rider   => isSelected ? _green : Colors.green.shade400, // Use theme green
    };
  }

  // Returns marker icon based on type
  IconData _markerIcon(_MarkerType type) {
    // Using distinct icons
    return switch (type) {
      _MarkerType.pickup  => BootstrapIcons.house_door_fill, // House for pickup
      _MarkerType.dropoff => BootstrapIcons.flag_fill,       // Flag for dropoff
      _MarkerType.rider   => BootstrapIcons.geo_alt_fill,   // Standard location pin for rider
    };
  }

} // End of _TrackingMapPageState

// --- Models (Keep within the same file for simplicity based on original structure) ---

// Represents the Delivery document structure
class Delivery {
  final String did;
  final String pickupAddrId;
  final String dropoffAddrId;
  final String itemName;
  final String itemImage; // URL
  final String note;
  final String receiverUid;
  final String senderUid;
  final String status; // Text status
  final int statusCode; // Numerical status
  final DateTime? createdAt; // Timestamp when created

  Delivery({
    required this.did,
    required this.pickupAddrId,
    required this.dropoffAddrId,
    required this.itemName,
    required this.itemImage,
    required this.note,
    required this.receiverUid,
    required this.senderUid,
    required this.status,
    required this.statusCode,
    this.createdAt,
  });

  // Helper to safely convert Firestore Timestamp or String to DateTime
  static DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v); // Handle potential ISO string format
    return null;
  }

  // Factory constructor to create a Delivery object from a Firestore snapshot
  factory Delivery.fromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data(); // Get data map, can be null
    if (d == null) {
      // Handle cases where data is missing unexpectedly
      throw Exception("Delivery document data is null for ID: ${snap.id}");
    }
    return Delivery(
      // Use document ID as the primary ID if 'did' field is missing or inconsistent
      did: (d['did'] as String?) ?? snap.id,
      pickupAddrId: d['pickup_addr_id'] as String? ?? '',
      dropoffAddrId: d['dropoff_addr_id'] as String? ?? '',
      itemName: d['item_name'] as String? ?? 'Unnamed Item', // Provide default
      itemImage: d['item_image'] as String? ?? '',
      note: d['note'] as String? ?? '',
      receiverUid: d['receiver_uid'] as String? ?? '',
      senderUid: d['sender_uid'] as String? ?? '',
      status: d['status'] as String? ?? 'Unknown Status', // Provide default
      // Safely parse status code, default to 0 or 1 if needed
      statusCode: (d['status_code'] as num?)?.toInt() ?? 0,
      createdAt: _toDate(d['created_at']), // Use helper for timestamp conversion
    );
  }

  // copyWith method for immutable updates (optional but good practice)
  Delivery copyWith({
    // Parameters for fields to update
    String? did, // Allow updating did if necessary, though usually fixed
    String? pickupAddrId,
    String? dropoffAddrId,
    String? itemName,
    String? itemImage,
    String? note,
    String? receiverUid,
    String? senderUid,
    String? status,
    int? statusCode,
    DateTime? createdAt,
  }) {
    return Delivery(
      // Use existing value if new value is null
      did: did ?? this.did,
      pickupAddrId: pickupAddrId ?? this.pickupAddrId,
      dropoffAddrId: dropoffAddrId ?? this.dropoffAddrId,
      itemName: itemName ?? this.itemName,
      itemImage: itemImage ?? this.itemImage,
      note: note ?? this.note,
      receiverUid: receiverUid ?? this.receiverUid,
      senderUid: senderUid ?? this.senderUid,
      status: status ?? this.status,
      statusCode: statusCode ?? this.statusCode,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}


// Represents the UserAddress (from 'addresses' collection) document structure
class UserAddress {
  final String id; // Document ID
  final String fullAddress; // Combined address string
  final double? lat; // Latitude
  final double? lng; // Longitude
  // Add other relevant fields if they exist in your 'addresses' collection
  // final String? label;
  // final String? contactName;
  // final String? contactPhone;

  UserAddress({
    required this.id,
    required this.fullAddress,
    this.lat,
    this.lng,
    // Add other fields to constructor if needed
    // this.label,
    // this.contactName,
    // this.contactPhone,
  });

  // Factory constructor to create a UserAddress object from a Firestore snapshot
  factory UserAddress.fromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data();
    if (d == null) {
       throw Exception("Address document data is null for ID: ${snap.id}");
    }
    return UserAddress(
      id: snap.id, // Use document ID
      // Provide default empty string if 'fullAddress' is missing
      fullAddress: (d['fullAddress'] as String? ?? '').trim(),
      // Safely parse lat/lng as doubles
      lat: (d['lat'] as num?)?.toDouble() ?? (d['latitude'] as num?)?.toDouble(), // Check both 'lat' and 'latitude'
      lng: (d['lng'] as num?)?.toDouble() ?? (d['longitude'] as num?)?.toDouble(),// Check both 'lng' and 'longitude'
      // Parse other fields if added
      // label: d['label'] as String?,
      // contactName: d['contactName'] as String?,
      // contactPhone: d['contactPhone'] as String?,
    );
  }
}


// Represents the Assignment (from 'assignment' collection) document structure
class Assignment {
  final String aid; // Assignment ID (document ID)
  final String did; // Delivery ID (foreign key)
  final String rid; // Rider ID (foreign key)
  final int statusCode; // Current status code of the assignment (e.g., 2=accepted, 3=picked, 4=delivered)
  final Timestamp? acceptedAt; // Time rider accepted the job
  final Timestamp? pickedAt; // Time rider confirmed pickup
  final Timestamp? deliveredAt; // Time rider confirmed delivery
  final String? pickupImageUrl; // URL of the image taken at pickup
  final String? deliveryImageUrl; // URL of the image taken at delivery

  Assignment({
    required this.aid,
    required this.did,
    required this.rid,
    required this.statusCode,
    this.acceptedAt,
    this.pickedAt,
    this.deliveredAt,
    this.pickupImageUrl,
    this.deliveryImageUrl,
  });

  // Factory constructor to create an Assignment object from a Firestore snapshot
  factory Assignment.fromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data();
     if (d == null) {
       throw Exception("Assignment document data is null for ID: ${snap.id}");
    }
    return Assignment(
      aid: snap.id, // Use document ID as assignment ID
      did: d['did'] as String? ?? '', // Delivery ID
      rid: d['rid'] as String? ?? '', // Rider ID
      // Safely parse status code, default to 0
      statusCode: (d['status_code'] as num?)?.toInt() ?? 0,
      // Timestamps can be null
      acceptedAt: d['accepted_at'] as Timestamp?,
      pickedAt: d['picked_at'] as Timestamp?,
      deliveredAt: d['delivered_at'] as Timestamp?,
      // Image URLs can be null
      pickupImageUrl: d['pickup_image_url'] as String?,
      deliveryImageUrl: d['delivery_image_url'] as String?,
    );
  }
}

// --- Enums ---
// Used for marker styling and logic
enum _MarkerType { pickup, dropoff, rider }

