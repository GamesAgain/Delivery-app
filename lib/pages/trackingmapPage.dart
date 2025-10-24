import 'dart:async';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app/services/upload_img.dart';
// import 'package:open_route_service/open_route_service.dart'; // ‼ ลบออก

class TrackingMapPage extends StatefulWidget {
  final String? did; // Delivery ID passed to this page
  const TrackingMapPage({super.key, this.did});

  @override
  State<TrackingMapPage> createState() => _TrackingMapPageState();
}

class _TrackingMapPageState extends State<TrackingMapPage> {
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

  // --- ‼ ลบตัวแปรเส้นนำทางออก ---

  // --- Map Controller (flutter_map) ---
  final MapController _mapController =
      MapController(); // Controller for map interactions

  // --- Stream Subscriptions ---
  StreamSubscription<Position>?
  _riderLocationSubscription; // For rider location updates
  StreamSubscription? _assignmentSubscription; // For assignment status updates

  // --- Map Markers (flutter_map) ---
  List<Marker> _markers = []; // List to hold map markers

  @override
  void initState() {
    super.initState();
    _initializePage(); // Call initialization logic
  }

  // Handles initial checks and starts data loading
  void _initializePage() {
    final riderId = FirebaseAuth.instance.currentUser?.uid;

    if (riderId == null) {
      _handleErrorAndExit('Rider not found. Please log in.');
      return;
    }
    if (widget.did == null || widget.did!.isEmpty) {
      _handleErrorAndExit('Delivery ID not provided.');
      return;
    }

    // If rider and DID are valid, start loading data and listening
    _initializeData(widget.did!, riderId);
    _startListeningToRiderLocation(riderId);
  }

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
    super.dispose();
  }

  // --- 1. Initial Data Loading ---
  // Fetches initial static data like Delivery details, addresses, and names
  Future<void> _initializeData(String did, String riderId) async {
    // Prevent re-initialization if already loaded or if there was an error
    if (!_isLoading && _errorMessage == null) return;

    // Reset error message for potential retry
    setState(() {
      _errorMessage = null;
    });

    try {
      // Fetch Delivery document
      final deliverySnap = await FirebaseFirestore.instance
          .collection('delivery')
          .doc(did)
          .get();
      if (!deliverySnap.exists || deliverySnap.data() == null)
        throw Exception('Delivery not found');
      _delivery = Delivery.fromSnap(deliverySnap);

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
      _senderAddress = addresses[0];
      _receiverAddress = addresses[1];

      // Optional: Log warnings if addresses weren't found (might indicate data inconsistency)
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
      _senderName = names[0];
      _receiverName = names[1];
      _riderName = names[2];

      // Start listening for real-time Assignment updates *after* basic data is loaded
      _listenToAssignment(did, riderId);

      // Set initial map camera position after a short delay, focusing on sender if available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _riderPosition == null && _senderAddress?.lat != null) {
          _moveCamera(LatLng(_senderAddress!.lat!, _senderAddress!.lng!), 15.0);
        }
      });

      // Update loading state if the assignment listener hasn't provided data yet
      // This makes the UI feel responsive sooner if assignment data takes time
      if (mounted && _assignment == null) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Initialization Error: $e");
      if (mounted) {
        // Ensure widget is still mounted before calling setState
        setState(() {
          _errorMessage = "Failed to load details: ${e.toString()}";
          _isLoading = false; // Stop loading on error
        });
      }
    }
  }

  // Fetches a UserAddress document by its ID from the 'addresses' collection
  Future<UserAddress?> _fetchAddressById(String addrId) async {
    final snap = await FirebaseFirestore.instance
        .collection('addresses')
        .doc(addrId)
        .get(); // Corrected collection
    if (!snap.exists || snap.data() == null) return null;
    return UserAddress.fromSnap(snap);
  }

  // Fetches a username from the 'users' collection by user ID
  Future<String?> _fetchUserName(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get(); // Corrected collection
    if (!snap.exists || snap.data() == null) return 'Unknown User';
    // Ensure the field name 'username' matches your Firestore document
    return snap.data()?['username'] as String?;
  }

  // Fetches a rider's name from the 'riders' collection by rider ID
  Future<String?> _fetchRiderName(String rid) async {
    final snap = await FirebaseFirestore.instance
        .collection('riders')
        .doc(rid)
        .get(); // Corrected collection
    if (!snap.exists || snap.data() == null) return 'Rider';
    // Ensure the field name 'username' matches your Firestore document
    return snap.data()?['username'] as String?;
  }

  // --- 2. Real-time Listeners ---

  // Listens for changes to the specific Assignment document for this delivery and rider
  void _listenToAssignment(String did, String riderId) {
    _assignmentSubscription?.cancel(); // Cancel any previous listener
    _assignmentSubscription = FirebaseFirestore.instance
        .collection('assignment') // Corrected collection
        .where('did', isEqualTo: did)
        .where('rid', isEqualTo: riderId)
        .limit(1) // Expecting only one assignment per did/rid pair
        .snapshots() // Listen for real-time updates
        .listen(
          (snapshot) {
            if (!mounted) return; // Exit if the widget is no longer in the tree

            if (snapshot.docs.isNotEmpty) {
              // Assignment found, update state
              setState(() {
                _assignment = Assignment.fromSnap(snapshot.docs.first);
                _isLoading = false; // Data is loaded
                _errorMessage = null; // Clear any previous errors
                _updateDistances(); // Recalculate distances based on current status/locations
                _updateMapMarkers(); // Update markers based on current status/locations
              });

              // ‼ ลบการเรียก update route ออก

              // If the assignment status indicates completion, navigate away
              if ((_assignment?.statusCode ?? 0) >= 4) {
                _handleCompletionNavigation();
              }
            } else {
              // Assignment document not found or deleted
              // If initial loading is done, show an error. Otherwise, just wait.
              if (!_isLoading) {
                print(
                  "Assignment listener: No documents found after initial load.",
                );
                setState(() {
                  _assignment = null; // Clear assignment data
                  // Only set error if not already showing another error
                  if (_errorMessage == null)
                    _errorMessage = "Assignment details not found.";
                });
              } else {
                print("Assignment listener: Waiting for document...");
              }
            }
          },
          onError: (error) {
            // Handle errors during listening
            if (!mounted) return;
            print("Assignment listener Error: $error");
            setState(() {
              _errorMessage = "Error listening to assignment: $error";
              _isLoading = false; // Stop loading on listener error
            });
          },
        );
  }

  // Starts listening for real-time rider location updates using Geolocator
  void _startListeningToRiderLocation(String riderId) async {
    bool permissionGranted = await _handleLocationPermission();
    if (!permissionGranted || !mounted) return;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high, // Use high accuracy for tracking
      distanceFilter: 1, // Update only when moved at least 10 meters
    );

    _riderLocationSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            if (mounted) {
              final newPos = LatLng(position.latitude, position.longitude);
              // Only move camera automatically on the *first* location update
              bool needsCameraMove = _riderPosition == null;
              setState(() {
                _riderPosition = position;
                _updateDistances(); // Recalculate distances with new position
                _updateMapMarkers(); // Update rider marker position
              });
              if (needsCameraMove) {
                _moveCamera(newPos, 16.5); // Zoom in closer on first update

                // ‼ ลบการเรียก update route ออก
              }
              _updateRiderLocationInFirestore(riderId, position);
            }
          },
          onError: (error) {
            print("Error listening to rider location: $error");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error getting location: $error'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        );
  }

  Future<void> _updateRiderLocationInFirestore(
      String riderId, Position position) async {
    final did = widget.did;
    if (did == null || did.isEmpty) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('RiderLocation').doc(did).set(
        {
          'did': did,
          'rid': riderId,
          'lat': position.latitude,
          'lng': position.longitude,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Failed to update rider location: $e');
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
    if (_riderPosition == null) return; // Need rider position

    // Helper to calculate distance safely
    double calcDistance(UserAddress? address) {
      if (address?.lat == null || address?.lng == null) return double.infinity;
      // Use Geolocator to calculate distance between two coordinates
      return Geolocator.distanceBetween(
        _riderPosition!.latitude,
        _riderPosition!.longitude,
        address!.lat!,
        address.lng!,
      );
    }

    // Calculate and store distances
    _distanceToPickup = calcDistance(_senderAddress);
    _distanceToDropoff = calcDistance(_receiverAddress);
    // Note: No setState here; this is called within other setState blocks
  }

  // --- 4. Map Logic ---
  // Updates the list of markers displayed on the map based on current state
  void _updateMapMarkers() {
    if (!mounted || _riderPosition == null)
      return; // Need rider position and widget mounted

    final List<Marker> currentMarkers = []; // Start with an empty list
    final riderLatLng = LatLng(
      _riderPosition!.latitude,
      _riderPosition!.longitude,
    );

    // Add Rider marker (always shown)
    currentMarkers.add(
      Marker(
        width: 40.0,
        height: 40.0, // Marker size
        point: riderLatLng, // Marker position
        child: _buildMarkerWidget(
          icon: BootstrapIcons.bicycle,
          color: AppColors.primary,
        ), // Custom widget for marker
      ),
    );

    final int statusCode = _assignment?.statusCode ?? 0; // Get current assignment status

    // แสดงหมุดผู้ส่ง (Sender) เฉพาะก่อนรับของ (status < 3)
    if (statusCode < 3 && _senderAddress?.lat != null) {
      currentMarkers.add(
        Marker(
          width: 40.0,
          height: 40.0,
          point: LatLng(_senderAddress!.lat!, _senderAddress!.lng!),
          child: _buildMarkerWidget(
            icon: BootstrapIcons.box,
            color: const Color(0xFF38BDF8),
          ),
        ),
      );
    }

    // แสดงหมุดผู้รับ (Receiver) หลังจากรับของแล้ว (status >= 3)
    if (statusCode >= 3 && _receiverAddress?.lat != null) {
      currentMarkers.add(
        Marker(
          width: 40.0,
          height: 40.0,
          point: LatLng(_receiverAddress!.lat!, _receiverAddress!.lng!),
          child: _buildMarkerWidget(
            icon: BootstrapIcons.geo_alt_fill,
            color: const Color(0xFFF87171),
          ),
        ),
      );
    }

    // Update the state to rebuild the map with the new markers
    setState(() {
      _markers = currentMarkers;
    });
  }

  // Builds the widget used for map markers (Image or fallback Icon)
  Widget _buildMarkerWidget({
    required IconData icon,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.bgsecondary.withOpacity(0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.7), width: 1.6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
        ),
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Moves the map camera to the specified target and zoom level
  void _moveCamera(LatLng target, double zoom) {
    // Use try-catch as the map controller might not be ready immediately
    try {
      // Animate the camera smoothly to the new position
      _mapController.move(target, zoom);
    } catch (e) {
      print("Map not ready for move operation: $e");
    }
  }

  // --- ‼ ลบฟังก์ชัน Routing (6) ออกทั้งหมด ---

  // --- 5. Action Logic (Pickup/Dropoff Confirmation) ---
  // (เดิมคือ 7)

  Future<XFile?> _pickProofImage(bool isPickup) async {
    if (!mounted) return null;

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('ถ่ายรูปด้วยกล้อง'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('เลือกรูปจากแกลเลอรี'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
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
        imageQuality: 85,
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
    if (_isUploading) return; // Prevent multiple simultaneous uploads

    final riderId = FirebaseAuth.instance.currentUser?.uid;
    // Ensure assignment data is available
    if (riderId == null || _assignment == null || _delivery == null) {
      print("Cannot update status: Rider ID or Assignment is null.");
      return;
    }

    // Check Geofence: Rider must be within 20 meters of the target
    final double targetDistance = isPickup
        ? _distanceToPickup
        : _distanceToDropoff;
    if (targetDistance > 20) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Must be closer (${targetDistance.toStringAsFixed(0)}m)',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (mounted) {
      setState(() => _isUploading = true); // Indicate start of upload process
    }

    try {
      final XFile? image = await _pickProofImage(isPickup);
      if (image == null) {
        return;
      }

      if (!mounted) return; // Check if widget is still mounted after await
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploading image...'),
          duration: Duration(seconds: 15),
        ),
      );

      final uploadResult = await UploadImgService.uploadXFile(
        xfile: image,
        folder: 'assignments/${_assignment!.aid}',
        extraFields: {
          'context': isPickup ? 'pickup' : 'delivery',
        },
      );

      final downloadUrl = uploadResult.secureUrl ?? uploadResult.url;
      if (downloadUrl == null || !uploadResult.success) {
        throw Exception('Unable to upload proof image. Please try again.');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final assignmentRef = FirebaseFirestore.instance
          .collection('assignment')
          .doc(_assignment!.aid);
      final deliveryRef = FirebaseFirestore.instance
          .collection('delivery')
          .doc(_delivery!.did);
      final historyRef = FirebaseFirestore.instance
          .collection('delivery_status_history')
          .doc();

      final String statusText = isPickup
          ? 'ไรเดอร์รับสินค้าแล้วและกำลังเดินทางไปส่ง'
          : 'ไรเดอร์นำส่งสินค้าแล้ว';
      final String createdByUserId = isPickup
          ? (_delivery?.senderUid ?? '')
          : (_delivery?.receiverUid ?? '');

      final Map<String, dynamic> assignmentUpdate = {
        'status_code': nextStatusCode,
        if (isPickup) 'picked_at': FieldValue.serverTimestamp(),
        if (isPickup) 'pickup_image_url': downloadUrl,
        if (!isPickup) 'delivered_at': FieldValue.serverTimestamp(),
        if (!isPickup) 'delivery_image_url': downloadUrl,
      };

      final Map<String, dynamic> deliveryUpdate = {
        'status_code': nextStatusCode,
        'status': statusText,
      };

      final Map<String, dynamic> historyData = {
        'did': _delivery!.did,
        'created_at': FieldValue.serverTimestamp(),
        'created_by_rider_id': riderId,
        'created_by_user_id': createdByUserId,
        'image': downloadUrl,
        'status_code': nextStatusCode,
      };

      final WriteBatch batch = FirebaseFirestore.instance.batch();
      batch.update(assignmentRef, assignmentUpdate);
      batch.update(deliveryRef, deliveryUpdate);
      batch.set(historyRef, historyData);

      if (!isPickup && nextStatusCode == 4) {
        final riderRef = FirebaseFirestore.instance
            .collection('riders')
            .doc(riderId);
        batch.update(riderRef, {'active_assignment_id': null});
      }

      await batch.commit();

      if (mounted) {
        setState(() {
          _delivery = _delivery?.copyWith(
            status: statusText,
            statusCode: nextStatusCode,
          );
        });
        _updateDistances();
        _updateMapMarkers();
      }

      if (isPickup) {
        if (_receiverAddress?.lat != null && _receiverAddress?.lng != null) {
          _moveCamera(
            LatLng(_receiverAddress!.lat!, _receiverAddress!.lng!),
            15.5,
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pickup Confirmed!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await _handleCompletionNavigation();
      }
    } catch (e) {
      // Handle errors during the process
      print("Error updating status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Ensure uploading state is reset even if errors occur
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // Navigates back to the assignment list upon successful delivery completion
  Future<void> _handleCompletionNavigation() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('จัดส่งเสร็จสิ้น'),
          content: const Text('ไรเดอร์นำส่งสินค้าแล้ว'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('ตกลง'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    final riderId = FirebaseAuth.instance.currentUser?.uid;
    if (riderId != null && riderId.isNotEmpty) {
      context.goNamed(
        'assingmentlist',
        queryParameters: {'uid': riderId},
      );
    } else {
      context.go('/');
    }
  }

  // --- 6. Build Method (UI Structure) ---
  // (เดิมคือ 8)
  @override
  Widget build(BuildContext context) {
    // Determine if the back button should be allowed (only after completion)
    bool canPop = (_assignment?.statusCode ?? 0) >= 4;

    // Calculate initial map center coordinates
    LatLng initialCenter = LatLng(
      16.47,
      103.25,
    ); // Default fallback (e.g., city center)
    if (_riderPosition != null) {
      initialCenter = LatLng(
        _riderPosition!.latitude,
        _riderPosition!.longitude,
      );
    } else if (_senderAddress?.lat != null) {
      // If no rider pos, center on sender
      initialCenter = LatLng(_senderAddress!.lat!, _senderAddress!.lng!);
    }
    double initialZoom = 15.0; // Initial map zoom level

    // Determine which action button to show based on assignment status
    Widget? actionButton;
    int currentStatus = _assignment?.statusCode ?? 0;
    bool isPickupEnabled =
        _distanceToPickup <= 20; // Check if within pickup range
    bool isDropoffEnabled =
        _distanceToDropoff <= 20; // Check if within dropoff range

    // Build button only if initial data is loaded and assignment details are available
    if (!_isLoading && _assignment != null) {
      if (currentStatus == 2) {
        // Status: Accepted, waiting for pickup
        actionButton = _buildActionButton(
          label: 'Confirm Pickup',
          icon: Icons.inventory_2_outlined, // Changed Icon
          onPressed: isPickupEnabled
              ? () => _handleStatusUpdate(3, isPickup: true)
              : null, // Next status is 3
          isEnabled: isPickupEnabled,
          distance: _distanceToPickup,
          isLoading: _isUploading,
        );
      } else if (currentStatus == 3) {
        // Status: Picked Up, waiting for delivery
        actionButton = _buildActionButton(
          label: 'Confirm Delivery',
          icon: Icons.check_circle_outline, // Changed Icon
          onPressed: isDropoffEnabled
              ? () => _handleStatusUpdate(4, isPickup: false)
              : null, // Next status is 4 (completed)
          isEnabled: isDropoffEnabled,
          distance: _distanceToDropoff,
          isLoading: _isUploading,
        );
      }
    }

    // Main scaffold structure
    return PopScope(
      canPop: canPop, // Control back navigation based on completion status
      onPopInvoked: (didPop) {
        // Show message if back navigation is attempted before completion
        if (!didPop && !canPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please complete the delivery first.'),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Delivery Tracking',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.bg, // Use defined AppBar background color
          iconTheme: const IconThemeData(
            color: Colors.white,
          ), // Make back button white
          elevation: 0, // No shadow
        ),
        backgroundColor:
            AppColors.bgsecondary, // Set a default background for the body
        body: Stack(
          children: [
            // --- FlutterMap ---
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: initialZoom,
                minZoom: 10.0,
                maxZoom: 18.0, // Set zoom limits
                onMapReady: () {
                  // Update markers once map is ready
                  if (mounted) _updateMapMarkers();
                },
                interactionOptions: const InteractionOptions(
                  flags:
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.drag, // Allow drag and zoom
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.thunderforest.com/transport/{z}/{x}/{y}@2x.png?apikey=fa73e7cfa2dc480da8d4a68fef53f9e1',
                  userAgentPackageName: 'com.example.delivery_app',
                ),

                // --- ‼ ลบ PolylineLayer ออก ---
                MarkerLayer(markers: _markers), // Display the markers
              ],
            ),

            // --- Bottom Sheet ---
            DraggableScrollableSheet(
              initialChildSize: 0.38,
              minChildSize: 0.18,
              maxChildSize: 0.68,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgsecondary,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.05),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 24,
                        color: Color(0x66000000),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          _buildAddressRow(
                            'ผู้ส่ง',
                            _senderAddress?.fullAddress ??
                                (_isLoading ? 'Loading...' : 'N/A'),
                            Icons.arrow_upward,
                          ),
                          const SizedBox(height: 12),
                          _buildAddressRow(
                            'ผู้รับ',
                            _receiverAddress?.fullAddress ??
                                (_isLoading ? 'Loading...' : 'N/A'),
                            Icons.arrow_downward,
                          ),
                          const SizedBox(height: 20),
                          if (_isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primary,
                                  ),
                                ),
                              ),
                            )
                          else if (_errorMessage != null)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'Error: $_errorMessage',
                                  style: const TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            )
                          else if (_delivery != null && _assignment != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildRiderInfoCard(
                                  riderName: _riderName ?? "Rider",
                                  statusText: _getStatusText(
                                    _assignment!.statusCode,
                                  ),
                                  address:
                                      (_assignment!.statusCode == 2
                                              ? _senderAddress?.fullAddress
                                              : _receiverAddress?.fullAddress) ??
                                          "Loading address...",
                                ),
                                const SizedBox(height: 24),
                                if (actionButton != null) actionButton,
                                if ((_assignment?.statusCode ?? 0) >= 4)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 24.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.celebration, color: AppColors.primary),
                                        SizedBox(width: 8),
                                        Text(
                                          'Delivery Completed!',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            )
                          else
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'Waiting for assignment details...',
                                  style: const TextStyle(color: Colors.white70),
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

            // --- Removed separate Loading Overlay ---
          ],
        ),
      ),
    );
  }

  // --- 7. Helper Widgets ---
  // (เดิมคือ 9)

  // Builds a row to display address information
  Widget _buildAddressRow(String label, String address, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Builds the card displaying rider information in the bottom sheet
  Widget _buildRiderInfoCard({
    required String riderName,
    required String statusText,
    required String address,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgsecondary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/rider_avatar.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    BootstrapIcons.person,
                    color: AppColors.primary,
                    size: 32,
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  riderName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      BootstrapIcons.geo_alt_fill,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
      distanceText = "(กำลังตรวจสอบตำแหน่ง...)";
    } else if (!isEnabled) {
      distanceText =
          "(${distance.toStringAsFixed(0)}m • ต้องอยู่ในระยะ 20m)";
    } else {
      distanceText = "(พร้อมยืนยัน)";
    }

    final bool canInteract = isEnabled && !isLoading;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: canInteract ? 1.0 : 0.7,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: canInteract ? onPressed : null,
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: canInteract
                  ? const LinearGradient(
                      colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: canInteract ? null : Colors.grey.shade400,
              boxShadow: canInteract
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                Flexible(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text: label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(
                          text: ' $distanceText',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
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

  // --- 8. Helper Function ---
  // (เดิมคือ 10)
  // Converts assignment status code to a user-friendly string
  String _getStatusText(int statusCode) {
    return switch (statusCode) {
      2 => 'ผู้ส่ง (กำลังไปรับของ)',
      3 => 'ผู้รับ (กำลังไปส่งของ)',
      4 => 'จัดส่งสำเร็จแล้ว',
      _ => 'กำลังโหลดสถานะ...',
    };
  }
} // End of _TrackingMapPageState

// ‼ --- Models (Keep within the same file as requested) ---

// Represents the Delivery document structure
class Delivery {
  final String did;
  final String pickupAddrId;
  final String dropoffAddrId;
  final String itemName;
  final String itemImage;
  final String note;
  final String receiverUid;
  final String senderUid;
  final String status;
  final int statusCode;
  final DateTime? createdAt;

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
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  // Factory constructor to create a Delivery object from a Firestore snapshot
  factory Delivery.fromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data()!;
    return Delivery(
      did: snap.id, // Prefer document ID for consistency
      pickupAddrId: d['pickup_addr_id'] as String? ?? '',
      dropoffAddrId: d['dropoff_addr_id'] as String? ?? '',
      itemName: d['item_name'] as String? ?? 'N/A',
      itemImage: d['item_image'] as String? ?? '',
      note: d['note'] as String? ?? '',
      receiverUid: d['receiver_uid'] as String? ?? '',
      senderUid: d['sender_uid'] as String? ?? '',
      status: d['status'] as String? ?? 'Unknown',
      statusCode: (d['status_code'] as num?)?.toInt() ?? 0,
      createdAt: _toDate(d['created_at']),
    );
  }

  Delivery copyWith({
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
      did: did,
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
  final String id;
  final String fullAddress;
  final double? lat;
  final double? lng;

  UserAddress({
    required this.id,
    required this.fullAddress,
    this.lat,
    this.lng,
  });

  // Factory constructor to create a UserAddress object from a Firestore snapshot
  factory UserAddress.fromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data()!;
    return UserAddress(
      id: snap.id,
      fullAddress: (d['fullAddress'] as String? ?? '').trim(),
      // Ensure lat/lng are correctly parsed as doubles
      lat: (d['lat'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble(),
    );
  }
}

// Represents the Assignment (from 'assignment' collection) document structure
class Assignment {
  final String aid; // Assignment ID (document ID)
  final String did; // Delivery ID (foreign key)
  final String rid; // Rider ID (foreign key)
  final int statusCode; // Current status code of the assignment
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
    final d = snap.data()!;
    return Assignment(
      aid: snap.id, // Use document ID
      did: d['did'] as String? ?? '',
      rid: d['rid'] as String? ?? '',
      statusCode: (d['status_code'] as num?)?.toInt() ?? 0,
      acceptedAt: d['accepted_at'] as Timestamp?,
      pickedAt: d['picked_at'] as Timestamp?,
      deliveredAt: d['delivered_at'] as Timestamp?,
      pickupImageUrl: d['pickup_image_url'] as String?,
      deliveryImageUrl: d['delivery_image_url'] as String?,
    );
  }
}
