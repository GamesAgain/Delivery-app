import 'dart:async';
import 'dart:io';
import 'package:bootstrap_icons/bootstrap_icons.dart'; // Ensure this is imported if used in helpers
import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:go_router/go_router.dart';
// import 'package:open_route_service/open_route_service.dart'; // ‼ ลบออก

class TrackingMapPage extends StatefulWidget {
  final String? did; // Delivery ID passed to this page
  const TrackingMapPage({super.key, this.did});

  @override
  State<TrackingMapPage> createState() => _TrackingMapPageState();
}

class _TrackingMapPageState extends State<TrackingMapPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
  StreamSubscription<Position>? _locationSubscription; // For rider location updates
  StreamSubscription? _assignmentSubscription; // For assignment status updates

  // --- Map Markers (flutter_map) ---
  List<Marker> _markers = []; // List to hold map markers

  String? _riderUid;
  bool _isTracking = false;
  DateTime? _lastUpdateTime;
  final Duration _updateThreshold = const Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _initializePage(); // Call initialization logic
  }

  // Handles initial checks and starts data loading
  void _initializePage() {
    final riderId = _auth.currentUser?.uid;
    _riderUid = riderId;

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
    _locationSubscription?.cancel();
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
    final permissionGranted = await _handleLocationPermission();
    if (!permissionGranted || !mounted) {
      if (mounted) {
        setState(() {
          _isTracking = false;
        });
      }
      return;
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high, // Use high accuracy for tracking
      distanceFilter: 10, // Update only when moved at least 10 meters
    );

    await _locationSubscription?.cancel();
    if (mounted) {
      setState(() {
        _isTracking = true;
      });
    }

    _locationSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        final now = DateTime.now();
        final shouldUpdate = _lastUpdateTime == null ||
            now.difference(_lastUpdateTime!) >= _updateThreshold;

        if (shouldUpdate) {
          unawaited(_updateLocationToFirestore(position));
          _lastUpdateTime = now;
        }

        if (!mounted) return;

        final newPos = LatLng(position.latitude, position.longitude);
        final bool needsCameraMove = _riderPosition == null;
        setState(() {
          _riderPosition = position;
          _updateDistances(); // Recalculate distances with new position
          _updateMapMarkers(); // Update rider marker position
        });
        if (needsCameraMove) {
          _moveCamera(newPos, 16.5); // Zoom in closer on first update
        }
      },
      onError: (error, stackTrace) {
        debugPrint('Error listening to rider location: $error');
        debugPrintStack(stackTrace: stackTrace);
        if (mounted) {
          setState(() {
            _isTracking = false;
          });
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

  Future<void> _updateLocationToFirestore(Position position) async {
    final riderUid = _riderUid;
    if (riderUid == null) return;

    try {
      await _firestore.collection('RiderLocation').doc(riderUid).set(
        {
          'rid': riderUid,
          'lat': position.latitude,
          'lng': position.longitude,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e, stackTrace) {
      debugPrint('Failed to update rider location: $e');
      debugPrintStack(stackTrace: stackTrace);
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
  Widget _buildTrackingStatusBanner() {
    final bool hasLocation = _riderPosition != null;
    final String message;
    final IconData icon;
    final Color color;

    if (!_isTracking) {
      message = 'Location tracking paused';
      icon = Icons.pause_circle_filled_outlined;
      color = Colors.orange.shade700;
    } else if (!hasLocation) {
      message = 'Waiting for GPS signal...';
      icon = Icons.location_searching;
      color = Colors.amber.shade800;
    } else {
      final lat = _riderPosition!.latitude.toStringAsFixed(5);
      final lng = _riderPosition!.longitude.toStringAsFixed(5);
      message = 'Live location sharing ($lat, $lng) · ${_formatLastSync()}';
      icon = Icons.navigation_rounded;
      color = AppColors.primary;
    }

    return Card(
      color: Colors.white.withOpacity(0.95),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastSync() {
    if (_lastUpdateTime == null) {
      return 'syncing...';
    }
    final difference = DateTime.now().difference(_lastUpdateTime!);
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }
    return '${difference.inDays}d ago';
  }

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
          'assets/icons/rider_marker.png',
          Colors.blue,
        ), // Custom widget for marker
      ),
    );

    int? statusCode = _assignment?.statusCode; // Get current assignment status

    // ‼ Logic ใหม่: แสดงหมุดผู้ส่ง (Sender) เสมอ ถ้ามีที่อยู่
    if (_senderAddress?.lat != null) {
      currentMarkers.add(
        Marker(
          width: 40.0,
          height: 40.0,
          point: LatLng(_senderAddress!.lat!, _senderAddress!.lng!),
          child: _buildMarkerWidget(
            'assets/icons/sender_marker.png',
            Colors.green,
          ),
        ),
      );
    }

    // ‼ Logic ใหม่: แสดงหมุดผู้รับ (Receiver) ต่อเมื่อรับของแล้ว (status 3) หรือส่งแล้ว (status 4)
    if ((statusCode == 3 || statusCode == 4) && _receiverAddress?.lat != null) {
      currentMarkers.add(
        Marker(
          width: 40.0,
          height: 40.0,
          point: LatLng(_receiverAddress!.lat!, _receiverAddress!.lng!),
          child: _buildMarkerWidget(
            'assets/icons/receiver_marker.png',
            Colors.red,
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
  Widget _buildMarkerWidget(String iconPath, Color fallbackColor) {
    // Ensure the asset path is declared in pubspec.yaml under flutter -> assets
    return Image.asset(
      iconPath,
      width: 40,
      height: 40, // Ensure size consistency
      errorBuilder: (context, error, stackTrace) {
        // Log error and return a fallback icon if image fails to load
        print("Error loading marker icon '$iconPath': $error");
        return Icon(Icons.location_pin, color: fallbackColor, size: 40);
      },
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

  // Handles the process of confirming pickup or delivery, including image capture and upload
  Future<void> _handleStatusUpdate(
    int nextStatusCode, {
    required bool isPickup,
  }) async {
    if (_isUploading) return; // Prevent multiple simultaneous uploads

    final riderId = FirebaseAuth.instance.currentUser?.uid;
    // Ensure assignment data is available
    if (riderId == null || _assignment == null) {
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

    setState(() => _isUploading = true); // Indicate start of upload process

    try {
      // Launch camera to capture image
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);

      // If user cancels image capture
      if (image == null) {
        if (mounted) setState(() => _isUploading = false);
        return;
      }

      // Show uploading indicator
      if (!mounted) return; // Check if widget is still mounted after await
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploading image...'),
          duration: Duration(seconds: 15),
        ), // Longer duration for upload
      );

      // Prepare image upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref();
      final imageFileName =
          '${isPickup ? 'pickup' : 'delivery'}_${_assignment!.aid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      // Define storage path (e.g., assignment_images/assignment_id/image_name.jpg)
      final imageRef = storageRef.child(
        'assignment_images/${_assignment!.aid}/$imageFileName',
      );

      // Upload the file
      final uploadTask = imageRef.putFile(File(image.path));
      final snapshot = await uploadTask; // Wait for upload completion
      final downloadUrl = await snapshot.ref
          .getDownloadURL(); // Get the public URL

      if (!mounted) return; // Check again after upload
      ScaffoldMessenger.of(
        context,
      ).hideCurrentSnackBar(); // Hide uploading indicator

      // Prepare data to update in Firestore Assignment document
      final assignmentRef = FirebaseFirestore.instance
          .collection('assignment')
          .doc(_assignment!.aid);
      Map<String, dynamic> updateData = {
        'status_code': nextStatusCode,
        // Add timestamp and image URL based on whether it's pickup or delivery
        if (isPickup) 'picked_at': FieldValue.serverTimestamp(),
        if (isPickup) 'pickup_image_url': downloadUrl,
        if (!isPickup) 'delivered_at': FieldValue.serverTimestamp(),
        if (!isPickup) 'delivery_image_url': downloadUrl,
      };

      // Use Firestore Batch Write for atomic update of Assignment and potentially Rider status
      WriteBatch batch = FirebaseFirestore.instance.batch();
      batch.update(assignmentRef, updateData); // Update assignment data

      // If this is the final delivery step (status code 4), also update the Rider document
      if (!isPickup && nextStatusCode == 4) {
        final riderRef = FirebaseFirestore.instance
            .collection('riders')
            .doc(riderId);
        // Set active_assignment_id to null to indicate rider is free
        batch.update(riderRef, {'active_assignment_id': null});
      }

      await batch.commit(); // Commit all updates in the batch

      // Handle post-update actions (navigation or confirmation message)
      if (!isPickup && nextStatusCode == 4) {
        _handleCompletionNavigation(); // Navigate away on completion
      } else if (mounted) {
        // Show confirmation for pickup
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pickup Confirmed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Handle errors during the process
      print("Error updating status: $e");
      if (mounted) {
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
  void _handleCompletionNavigation() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery Completed!'),
          backgroundColor: Colors.green,
        ),
      );
      // Ensure 'assignmentList' is a valid named route in your GoRouter config
      context.goNamed('assignmentList');
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

            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _buildTrackingStatusBanner(),
            ),

            // --- Bottom Sheet ---
            DraggableScrollableSheet(
              initialChildSize: 0.35,
              minChildSize: 0.15,
              maxChildSize: 0.6,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white, // Bottom sheet background
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(blurRadius: 10, color: Colors.black26),
                    ],
                  ),
                  child: SingleChildScrollView(
                    // Allows content to scroll if it overflows
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- Address Rows ---
                          _buildAddressRow(
                            'ผู้ส่ง',
                            _senderAddress?.fullAddress ??
                                (_isLoading ? 'Loading...' : 'N/A'),
                            Icons.arrow_upward,
                          ),
                          const SizedBox(height: 10),
                          _buildAddressRow(
                            'ผู้รับ',
                            _receiverAddress?.fullAddress ??
                                (_isLoading ? 'Loading...' : 'N/A'),
                            Icons.arrow_downward,
                          ),
                          const Divider(height: 30, thickness: 1),

                          // --- Dynamic Content based on loading/error/data state ---
                          if (_isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (_errorMessage != null)
                            Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'Error: $_errorMessage',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            )
                          // Display Rider info and button only when data is loaded successfully
                          else if (_delivery != null && _assignment != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildRiderInfoCard(
                                  riderName: _riderName ?? "Rider",
                                  statusText: _getStatusText(
                                    _assignment!.statusCode,
                                  ),
                                  // Show appropriate address based on status
                                  address:
                                      (_assignment!.statusCode == 2
                                          ? _senderAddress?.fullAddress
                                          : _receiverAddress?.fullAddress) ??
                                      "Loading address...",
                                ),
                                const SizedBox(height: 20),
                                // Show action button if applicable for current status
                                if (actionButton != null) actionButton,
                                // Show completion message if status is 4 or more
                                if ((_assignment?.statusCode ?? 0) >= 4)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 20.0,
                                      ),
                                      child: Text(
                                        "Delivery Completed!",
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          // Fallback message if data is unexpectedly null after loading
                          else
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'Waiting for assignment details...',
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 2),
              // Handle potential long addresses
              Text(
                address,
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Builds the card displaying rider information in the bottom sheet
  Widget _buildRiderInfoCard({
    required String riderName,
    required String statusText,
    required String address,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgsecondary, // Dark background for the card
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Placeholder for rider avatar - replace with actual image if available
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.primary.withOpacity(
              0.2,
            ), // Use theme color variant
            child: const Icon(
              BootstrapIcons.person,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  riderName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                // Display current status text (e.g., "Heading to pickup")
                Text(
                  statusText,
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
                const SizedBox(height: 6),
                // Display relevant address (pickup or dropoff)
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
      distanceText = "(Checking...)";
    } else if (!isEnabled) {
      distanceText = "(${distance.toStringAsFixed(0)}m away)";
    } // Show distance if out of range
    else {
      distanceText = "(In range)";
    } // Indicate when in range

    return SizedBox(
      width: double.infinity, // Make button full width
      child: ElevatedButton.icon(
        // Show loading indicator inside button when uploading
        icon: isLoading
            ? Container(
                width: 20,
                height: 20,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          '$label $distanceText',
        ), // Button text includes distance info
        onPressed: isLoading
            ? null
            : onPressed, // Disable button while uploading or if not enabled (null onPressed)
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled
              ? AppColors.primary
              : Colors.grey[500], // Green when enabled, grey otherwise
          disabledBackgroundColor:
              Colors.grey[500], // Explicitly grey when disabled
          foregroundColor: Colors.white, // Text/icon color
          padding: const EdgeInsets.symmetric(vertical: 14), // Button padding
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ), // Button text style
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ), // Rounded corners
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
      4 => 'Delivery completed',
      _ => 'Loading status...', // Default/fallback text
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
