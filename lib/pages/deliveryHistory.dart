import 'package:delivery_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DeliveryHistoryPage extends StatefulWidget {
  const DeliveryHistoryPage({super.key});

  @override
  State<DeliveryHistoryPage> createState() => _DeliveryHistoryPageState();
}

class _DeliveryHistoryPageState extends State<DeliveryHistoryPage> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  final LatLng _startPoint = const LatLng(13.7545, 100.5402);
  final LatLng _endPoint = const LatLng(13.7362, 100.5336);

  final List<LatLng> _routePoints = const [
    LatLng(13.7545, 100.5402),
    LatLng(13.7480, 100.5400),
    LatLng(13.7445, 100.5365),
    LatLng(13.7390, 100.5350),
    LatLng(13.7362, 100.5336),
  ];

  final List<_DeliveryStatusStep> _historySteps = const [
    _DeliveryStatusStep(
      code: 1,
      dateLabel: '28 ต.ค.',
      timeLabel: '2:13PM',
      headline: 'กำลังรอไรเดอร์มารับ',
      detail: 'ร้านค้ายืนยันคำสั่งซื้อ กำลังรอไรเดอร์มารับสินค้า',
      imageAsset: 'assets/images/Status1.png',
    ),
    _DeliveryStatusStep(
      code: 2,
      dateLabel: '28 ต.ค.',
      timeLabel: '2:13PM',
      headline: 'ไรเดอร์รับงาน (กำลังเดินทางมารับสินค้า)',
    ),
    _DeliveryStatusStep(
      code: 3,
      dateLabel: '28 ต.ค.',
      timeLabel: '2:13PM',
      headline: 'ไรเดอร์รับสินค้าแล้วและกำลังเดินทางไปส่ง',
      detail: 'ไรเดอร์ออกเดินทางจากร้านและกำลังมุ่งหน้าไปยังปลายทาง',
      imageAsset: 'assets/images/Status3.png',
    ),
    _DeliveryStatusStep(
      code: 4,
      dateLabel: '28 ต.ค.',
      timeLabel: '2:13PM',
      headline: 'ไรเดอร์นำส่งสินค้าแล้ว',
      detail: 'ผู้รับได้รับสินค้าเรียบร้อย ขอบคุณที่ใช้บริการ',
      imageAsset: 'assets/images/Status4.png',
    ),
  ];

  static const int _currentStatusCode = 4;

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.onBg),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'ประวัติการจัดส่ง',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.onBg,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildMapCard(textTheme),
                ),
              ],
            ),
          ),
          _buildBottomSheet(textTheme),
        ],
      ),
    );
  }

  Widget _buildMapCard(TextTheme textTheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 340,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(
                  (_startPoint.latitude + _endPoint.latitude) / 2,
                  (_startPoint.longitude + _endPoint.longitude) / 2,
                ),
                initialZoom: 14.5,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.pinchMove |
                      InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.delivery.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 6,
                      color: AppColors.primary.withOpacity(0.85),
                      borderStrokeWidth: 9,
                      borderColor: Colors.white.withOpacity(0.3),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _startPoint,
                      width: 52,
                      height: 52,
                      alignment: Alignment.topCenter,
                      child: _buildMapMarker('A', AppColors.primary),
                    ),
                    Marker(
                      point: _endPoint,
                      width: 52,
                      height: 52,
                      alignment: Alignment.topCenter,
                      child: _buildMapMarker('B', const Color(0xFFE11D48)),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 18,
              top: 18,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ขนมฝักบัว',
                      style: textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_pin,
                          color: AppColors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'เมืองทองธานี, ปากเกร็ด',
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapMarker(String label, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              width: 4,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheet(TextTheme textTheme) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.35,
      minChildSize: 0.3,
      maxChildSize: 0.88,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bgsecondary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 24,
                offset: Offset(0, -12),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 52,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'จัดส่งเมื่อ',
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'พร้อมวันนี้',
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.onBg,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.primary),
                                ),
                                child: Text(
                                  'จัดส่ง',
                                  style: textTheme.titleSmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Divider(
                            color: Colors.white.withOpacity(0.12),
                            thickness: 1,
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 30,
                                backgroundImage:
                                    AssetImage('assets/images/rider_avatar.png'),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ชื่อไรเดอร์ : Kuuga',
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.onBg,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'ไรเดอร์มืออาชีพ พร้อมให้บริการคุณ',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: Colors.white70,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'ประวัติการจัดส่ง',
                            style: textTheme.titleMedium?.copyWith(
                              color: AppColors.onBg,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 40),
                sliver: SliverList.separated(
                  itemCount: _historySteps.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final step = _historySteps[index];
                    final isLast = index == _historySteps.length - 1;
                    final isFirst = index == 0;
                    final isCompleted = _currentStatusCode >= step.code;
                    return Padding(
                      padding: EdgeInsets.only(
                        left: 24,
                        right: 24,
                        bottom: isLast ? 24 : 0,
                      ),
                      child: _TimelineEntry(
                        step: step,
                        isCompleted: isCompleted,
                        isFirst: isFirst,
                        isLast: isLast,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.step,
    required this.isCompleted,
    required this.isFirst,
    required this.isLast,
  });

  final _DeliveryStatusStep step;
  final bool isCompleted;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lineColor = isCompleted ? AppColors.primary : Colors.white24;
    final indicatorColor = isCompleted ? AppColors.primary : Colors.white24;
    final double bottomLineHeight = isLast
        ? 0
        : step.imageAsset != null
            ? 136
            : 88;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                step.dateLabel,
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                step.timeLabel,
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.onBg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          children: [
            if (!isFirst)
              Container(
                width: 2,
                height: 28,
                color: lineColor,
              ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: indicatorColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: bottomLineHeight,
                color: lineColor,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.headline,
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.onBg,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (step.detail != null) ...[
                const SizedBox(height: 6),
                Text(
                  step.detail!,
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ],
              if (step.imageAsset != null) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    step.imageAsset!,
                    height: 132,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DeliveryStatusStep {
  const _DeliveryStatusStep({
    required this.code,
    required this.dateLabel,
    required this.timeLabel,
    required this.headline,
    this.detail,
    this.imageAsset,
  });

  final int code;
  final String dateLabel;
  final String timeLabel;
  final String headline;
  final String? detail;
  final String? imageAsset;
}
