import 'dart:async';

import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const LatLng _defaultMapCenter = LatLng(13.7563, 100.5018);

class TrackDeliveryPage extends StatelessWidget {
  const TrackDeliveryPage({
    super.key,
    String? deliveryId,
    this.itemName,
    List<String>? userDeliveryIds,
  })  : deliveryId = deliveryId?.trim(),
        userDeliveryIds = userDeliveryIds == null
            ? const []
            : List.unmodifiable(
                userDeliveryIds
                    .map((id) => id.trim())
                    .where((id) => id.isNotEmpty),
              ),
        assert(
          deliveryId == null ||
              userDeliveryIds == null ||
              userDeliveryIds.isEmpty,
          'Provide either deliveryId or userDeliveryIds, not both.',
        );

  final String? deliveryId;
  final String? itemName;
  final List<String> userDeliveryIds;

  bool get _hasSingleDelivery =>
      deliveryId != null && deliveryId!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final bool hasMultiDelivery =
        !_hasSingleDelivery && userDeliveryIds.isNotEmpty;

    final title = _hasSingleDelivery
        ? 'Track Delivery${deliveryId != null ? ': $deliveryId' : ''}'
        : hasMultiDelivery
            ? 'Track ${userDeliveryIds.length} Deliveries'
            : 'Track Delivery';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.green,
      ),
      body: _hasSingleDelivery
          ? _SingleDeliveryTrackingView(
              deliveryId: deliveryId!,
              itemName: itemName,
            )
          : hasMultiDelivery
              ? _MultiDeliveryTrackingView(deliveryIds: userDeliveryIds)
              : const _EmptyTrackingState(
                  message:
                      'Select a delivery to start tracking, or provide delivery IDs.',
                ),
    );
  }
}

class _SingleDeliveryTrackingView extends StatefulWidget {
  const _SingleDeliveryTrackingView({
    required this.deliveryId,
    this.itemName,
  });

  final String deliveryId;
  final String? itemName;

  @override
  State<_SingleDeliveryTrackingView> createState() =>
      _SingleDeliveryTrackingViewState();
}

class _SingleDeliveryTrackingViewState
    extends State<_SingleDeliveryTrackingView> {
  final MapController _mapController = MapController();
  LatLng? _lastCenteredPosition;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assignmentQuery = FirebaseFirestore.instance
        .collection('assignment')
        .where('did', isEqualTo: widget.deliveryId)
        .limit(1);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _InfoCard(
            title: widget.itemName ?? 'Delivery ${widget.deliveryId}',
            subtitle: 'Tracking rider updates in real time',
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: assignmentQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return const _TrackingError(
                  message: 'Unable to load assignment information.',
                );
              }

              final docs = snapshot.data?.docs ?? const [];
              if (docs.isEmpty) {
                return const _TrackingError(
                  message: 'Assignment not found for this delivery.',
                );
              }

              final riderId = (docs.first.data()['rid'] as String?)?.trim();
              if (riderId == null || riderId.isEmpty) {
                return const _TrackingError(
                  message: 'No rider assigned to this delivery.',
                );
              }

              final riderLocationStream = FirebaseFirestore.instance
                  .collection('RiderLocation')
                  .doc(riderId)
                  .snapshots();

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: riderLocationStream,
                builder: (context, locSnapshot) {
                  if (locSnapshot.hasError) {
                    return const _TrackingError(
                      message: 'Unable to read rider location.',
                    );
                  }

                  final connection = locSnapshot.connectionState;
                  LatLng? riderPosition;
                  if (locSnapshot.hasData && locSnapshot.data!.exists) {
                    final data = locSnapshot.data!.data();
                    final lat = (data?['lat'] as num?)?.toDouble();
                    final lng = (data?['lng'] as num?)?.toDouble();
                    if (lat != null && lng != null) {
                      riderPosition = LatLng(lat, lng);
                    }
                  }

                  if (riderPosition != null) {
                    _moveCamera(riderPosition);
                  }

                  final statusMessage = connection == ConnectionState.waiting
                      ? 'Waiting for rider location...'
                      : riderPosition == null
                          ? 'Rider location not available.'
                          : 'Rider is on the way.';

                  return _TrackingMapLayout(
                    mapController: _mapController,
                    center: riderPosition ?? _defaultMapCenter,
                    markers: riderPosition == null
                        ? const <Marker>[]
                        : [
                            Marker(
                              width: 70,
                              height: 70,
                              point: riderPosition,
                              child: const Icon(
                                BootstrapIcons.truck,
                                color: Colors.green,
                                size: 36,
                              ),
                            ),
                          ],
                    statusMessage: statusMessage,
                    statusIcon: BootstrapIcons.truck,
                    isLoading: connection == ConnectionState.waiting,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _moveCamera(LatLng position) {
    if (_lastCenteredPosition != null &&
        _coordinatesRoughlyEqual(_lastCenteredPosition!, position)) {
      return;
    }
    _lastCenteredPosition = position;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(position, 16);
    });
  }

  bool _coordinatesRoughlyEqual(LatLng a, LatLng b) {
    const threshold = 0.00001;
    return (a.latitude - b.latitude).abs() < threshold &&
        (a.longitude - b.longitude).abs() < threshold;
  }
}

class _MultiDeliveryTrackingView extends StatefulWidget {
  const _MultiDeliveryTrackingView({required this.deliveryIds});

  final List<String> deliveryIds;

  @override
  State<_MultiDeliveryTrackingView> createState() =>
      _MultiDeliveryTrackingViewState();
}

class _MultiDeliveryTrackingViewState
    extends State<_MultiDeliveryTrackingView> {
  final MapController _mapController = MapController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _lastFitSignature;
  late final List<String> _deliveryIds;

  @override
  void initState() {
    super.initState();
    _deliveryIds = widget.deliveryIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_deliveryIds.isEmpty) {
      return const _EmptyTrackingState(
        message: 'No deliveries to track.',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _InfoCard(
            title: 'Active deliveries',
            subtitle:
                '${_deliveryIds.length} item${_deliveryIds.length == 1 ? '' : 's'} being tracked',
          ),
        ),
        Expanded(
          child:
              StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            stream: _listenAssignments(_deliveryIds),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return const _TrackingError(
                  message: 'Unable to load assignment information.',
                );
              }

              final assignments = snapshot.data ?? const [];
              final riderIds = assignments
                  .map((doc) => (doc.data()['rid'] as String?)?.trim())
                  .where((rid) => rid != null && rid!.isNotEmpty)
                  .cast<String>()
                  .toSet()
                  .toList(growable: false);

              if (riderIds.isEmpty) {
                return _TrackingMapLayout(
                  mapController: _mapController,
                  center: _defaultMapCenter,
                  markers: const [],
                  statusMessage:
                      'No riders currently assigned to these deliveries.',
                  statusIcon: BootstrapIcons.truck,
                );
              }

              return StreamBuilder<
                  List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                stream: _listenRiderLocations(riderIds),
                builder: (context, locationSnapshot) {
                  if (locationSnapshot.hasError) {
                    return const _TrackingError(
                      message: 'Unable to read rider locations.',
                    );
                  }

                  final connection = locationSnapshot.connectionState;
                  final docs = locationSnapshot.data ?? const [];
                  final positions = docs
                      .map((doc) {
                        final data = doc.data();
                        final lat = (data['lat'] as num?)?.toDouble();
                        final lng = (data['lng'] as num?)?.toDouble();
                        if (lat == null || lng == null) return null;
                        return LatLng(lat, lng);
                      })
                      .whereType<LatLng>()
                      .toList(growable: false);

                  _fitCamera(positions);

                  final markers = positions
                      .map(
                        (position) => Marker(
                          width: 64,
                          height: 64,
                          point: position,
                          child: const Icon(
                            BootstrapIcons.truck,
                            color: Colors.blueAccent,
                            size: 32,
                          ),
                        ),
                      )
                      .toList(growable: false);

                  final statusMessage = positions.isEmpty
                      ? 'Waiting for rider locations...'
                      : 'Tracking ${positions.length} rider${positions.length > 1 ? 's' : ''}.';

                  return _TrackingMapLayout(
                    mapController: _mapController,
                    center: positions.isNotEmpty
                        ? positions.first
                        : _defaultMapCenter,
                    markers: markers,
                    statusMessage: statusMessage,
                    statusIcon: BootstrapIcons.truck,
                    isLoading: connection == ConnectionState.waiting,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _listenAssignments(
    List<String> deliveryIds,
  ) {
    return _listenCollectionByChunks(
      collectionPath: 'assignment',
      field: 'did',
      values: deliveryIds,
    );
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _listenRiderLocations(
    List<String> riderIds,
  ) {
    return _listenCollectionByChunks(
      collectionPath: 'RiderLocation',
      field: 'rid',
      values: riderIds,
    );
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _listenCollectionByChunks({
    required String collectionPath,
    required String field,
    required List<String> values,
  }) {
    if (values.isEmpty) {
      return Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>.value(
        const [],
      );
    }

    final uniqueValues = values.toSet().toList(growable: false);
    final chunks = _chunkValues(uniqueValues, 10);

    if (chunks.length == 1) {
      return _firestore
          .collection(collectionPath)
          .where(field, whereIn: chunks.first)
          .snapshots()
          .map((snapshot) => snapshot.docs);
    }

    return Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>.multi(
      (controller) {
        controller.add(const []);
        final subscriptions =
            <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
        final latestDocs =
            <int, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

        void emit() {
          if (controller.isClosed) return;
          final combined =
              latestDocs.values.expand((docs) => docs).toList(growable: false);
          controller.add(combined);
        }

        for (var index = 0; index < chunks.length; index++) {
          final chunk = chunks[index];
          final subscription = _firestore
              .collection(collectionPath)
              .where(field, whereIn: chunk)
              .snapshots()
              .listen((snapshot) {
            latestDocs[index] = snapshot.docs;
            emit();
          }, onError: controller.addError);
          subscriptions.add(subscription);
        }

        controller.onCancel = () async {
          for (final subscription in subscriptions) {
            await subscription.cancel();
          }
        };
      },
    );
  }

  List<List<String>> _chunkValues(List<String> values, int size) {
    final chunks = <List<String>>[];
    for (var i = 0; i < values.length; i += size) {
      final end = (i + size < values.length) ? i + size : values.length;
      chunks.add(values.sublist(i, end));
    }
    return chunks;
  }

  void _fitCamera(List<LatLng> positions) {
    if (positions.isEmpty) return;

    final signature = positions
        .map(
          (position) =>
              '${position.latitude.toStringAsFixed(5)},${position.longitude.toStringAsFixed(5)}',
        )
        .join('|');

    if (_lastFitSignature == signature) {
      return;
    }
    _lastFitSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (positions.length == 1) {
        _mapController.move(positions.first, 15.5);
      } else {
        final bounds = LatLngBounds.fromPoints(positions);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(48),
          ),
        );
      }
    });
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(BootstrapIcons.box_seam, color: Colors.green),
        title: Text(
          title,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _TrackingMapLayout extends StatelessWidget {
  const _TrackingMapLayout({
    required this.mapController,
    required this.center,
    required this.markers,
    required this.statusMessage,
    this.statusIcon = Icons.location_on,
    this.isLoading = false,
  });

  final MapController mapController;
  final LatLng center;
  final List<Marker> markers;
  final String statusMessage;
  final IconData statusIcon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 15,
            minZoom: 4,
            maxZoom: 19,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
            ),
            if (markers.isNotEmpty) MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Card(
            color: Colors.white.withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Icon(statusIcon, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      statusMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isLoading)
          const Positioned(
            right: 24,
            bottom: 24,
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}

class _TrackingError extends StatelessWidget {
  const _TrackingError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Colors.redAccent),
        ),
      ),
    );
  }
}

class _EmptyTrackingState extends StatelessWidget {
  const _EmptyTrackingState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
