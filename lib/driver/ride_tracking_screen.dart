// lib/driver/ride_tracking_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
//  Mirrors ride_tracking.php — full-screen live map that polls
//  tracking_api.php every 3 s and shows the driver's current location,
//  a pulsing car marker, polyline to target, and status bottom sheet.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'driver_api.dart';

// ── Shared theme ─────────────────────────────────────────────────────────────
class _T {
  static const primary  = Color(0xFF5B59A6);
  static const navy     = Color(0xFF1F2340);
  static const muted    = Color(0xFF7B7F98);
  static const bg       = Color(0xFFF7F8FC);
  static const card     = Color(0xFFFFFFFF);
  static const line     = Color(0xFFE9EAF5);
  static const shadow   = Color(0x14233B5C);
  static const ok       = Color(0xFF2F8F4E);
  static const bad      = Color(0xFFB53535);
}

// ── Trip status config ────────────────────────────────────────────────────────
class _TripUi {
  final Color bg, border, iconBg, iconColor;
  final IconData icon;
  final String label, sub;
  const _TripUi({
    required this.bg, required this.border, required this.iconBg,
    required this.iconColor, required this.icon,
    required this.label, required this.sub,
  });
}

const _kTripUi = <String, _TripUi>{
  'waiting': _TripUi(
    bg: Color(0xFFEEF2FF), border: Color(0xFFC7D2FE), iconBg: Color(0xFFEEF2FF),
    iconColor: Color(0xFF5B59A6), icon: Icons.access_time_rounded,
    label: 'Waiting for driver',
    sub: 'This page updates automatically when your driver starts moving.'),
  'arriving': _TripUi(
    bg: Color(0xFFEFF6FF), border: Color(0xFFBFDBFE), iconBg: Color(0xFFDBEAFE),
    iconColor: Color(0xFF1D4ED8), icon: Icons.directions_car_rounded,
    label: 'Driver is on the way!',
    sub: 'Your driver is heading to pick you up.'),
  'arrived': _TripUi(
    bg: Color(0xFFFFFBEB), border: Color(0xFFFDE68A), iconBg: Color(0xFFFEF3C7),
    iconColor: Color(0xFFB45309), icon: Icons.location_on_rounded,
    label: 'Driver has arrived!',
    sub: 'Your driver is waiting at the pickup point.'),
  'in_progress': _TripUi(
    bg: Color(0xFFF0FDF4), border: Color(0xFFBBF7D0), iconBg: Color(0xFFDCFCE7),
    iconColor: Color(0xFF15803D), icon: Icons.moving_rounded,
    label: 'Trip in progress',
    sub: 'You\'re on your way. Enjoy the ride!'),
  'completed': _TripUi(
    bg: Color(0xFFF5F3FF), border: Color(0xFFDDD6FE), iconBg: Color(0xFFEDE9FE),
    iconColor: Color(0xFF7C3AED), icon: Icons.check_circle_rounded,
    label: 'Trip completed!',
    sub: 'You have arrived at your destination.'),
};

// ─────────────────────────────────────────────────────────────────────────────
class RideTrackingScreen extends StatefulWidget {
  final int    bookingId;
  final int    patientId;
  final LatLng pickupLocation;
  final LatLng destLocation;
  final String pickupAddress;
  final String destAddress;
  final double fare;

  const RideTrackingScreen({
    super.key,
    required this.bookingId,
    required this.patientId,
    required this.pickupLocation,
    required this.destLocation,
    required this.pickupAddress,
    required this.destAddress,
    required this.fare,
  });

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen>
    with TickerProviderStateMixin {
  // ── Map ───────────────────────────────────────────────────────────────────
  final _mapCtrl = MapController();

  // ── Tracking state ────────────────────────────────────────────────────────
  LatLng? _driverLocation;
  String  _tripStatus = 'waiting';
  int     _pollCount  = 0;
  Timer?  _pollTimer;

  // ── ETA ───────────────────────────────────────────────────────────────────
  int    _etaSecs   = 0;
  Timer? _etaTimer;

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseScale;

  late AnimationController _sheetCtrl;
  late Animation<Offset>   _sheetSlide;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
    _pulseScale = Tween<double>(begin: 0.6, end: 1.6)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));

    _sheetCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _sheetSlide = Tween<Offset>(
            begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _sheetCtrl, curve: Curves.easeOutCubic));

    _poll();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _etaTimer?.cancel();
    _pulseCtrl.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  // ── Polling ───────────────────────────────────────────────────────────────
  Future<void> _poll() async {
    final res = await DriverApi.getTrackingData(widget.bookingId);
    if (!mounted) return;

    if (res['ok'] == true) {
      final t = res['tracking'];
      final status  = t != null ? (t['trip_status'] as String? ?? 'waiting') : 'waiting';
      final dLat    = t != null ? double.tryParse('${t['driver_lat'] ?? ''}') : null;
      final dLng    = t != null ? double.tryParse('${t['driver_lng'] ?? ''}') : null;

      final hadDriver = _driverLocation != null;
      final newDriver = (dLat != null && dLng != null)
          ? LatLng(dLat, dLng) : null;

      setState(() {
        _tripStatus = status;
        if (newDriver != null) _driverLocation = newDriver;
      });

      if (newDriver != null) {
        _updateEta(newDriver);
        if (!hadDriver) _fitBounds(newDriver);
      }

      if (status == 'completed') return; // stop
    }

    _pollCount++;
    final delay = _pollCount > 100 ? 6000 : 3000;
    _pollTimer = Timer(Duration(milliseconds: delay), _poll);
  }

  // ── ETA calculation (haversine / 40 km/h) ─────────────────────────────────
  void _updateEta(LatLng driver) {
    final target = _tripStatus == 'in_progress'
        ? widget.destLocation
        : widget.pickupLocation;
    final km = _haversine(driver, target);
    final secs = ((km / 40) * 3600).round();

    _etaTimer?.cancel();
    setState(() => _etaSecs = secs > 0 ? secs : 60);

    _etaTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() {
        if (_etaSecs > 60) _etaSecs -= 3;
      });
    });
  }

  double _haversine(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.latitude)) * math.cos(_rad(b.latitude)) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * R * math.atan2(math.sqrt(x), math.sqrt(1 - x));
  }

  double _rad(double deg) => deg * math.pi / 180;

  String get _etaText {
    final m = (_etaSecs / 60).ceil();
    return '$m min';
  }

  String _distText(LatLng? driver) {
    if (driver == null) return '— km';
    final target = _tripStatus == 'in_progress'
        ? widget.destLocation
        : widget.pickupLocation;
    final km = _haversine(driver, target);
    return km < 1
        ? '${(km * 1000).round()} m'
        : '${km.toStringAsFixed(1)} km';
  }

  // ── Fit map bounds to all markers ─────────────────────────────────────────
  void _fitBounds(LatLng driver) {
    final points = [driver, widget.pickupLocation, widget.destLocation];
    final minLat = points.map((p) => p.latitude).reduce(math.min);
    final maxLat = points.map((p) => p.latitude).reduce(math.max);
    final minLng = points.map((p) => p.longitude).reduce(math.min);
    final maxLng = points.map((p) => p.longitude).reduce(math.max);
    _mapCtrl.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
            LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      body: Stack(
        children: [
          // ── Map ──
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: widget.pickupLocation,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),

              // Route line: driver → pickup or driver → dest
              if (_driverLocation != null)
                PolylineLayer(polylines: [
                  Polyline(
                    points: [
                      _driverLocation!,
                      _tripStatus == 'in_progress'
                          ? widget.destLocation
                          : widget.pickupLocation,
                    ],
                    color: _tripStatus == 'in_progress'
                        ? const Color(0xFF10B981)
                        : const Color(0xFF3B82F6),
                    strokeWidth: 5,
                    isDotted: true,
                  ),
                ]),

              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          // ── Top bar ──
          SafeArea(child: _buildTopBar()),

          // ── Bottom sheet ──
          Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _sheetSlide,
              child: _buildBottomSheet(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _T.card,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: _T.shadow, blurRadius: 12, offset: Offset(0, 4))
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _T.navy, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: _T.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: _T.shadow, blurRadius: 20, offset: Offset(0, 6))
              ],
              border: Border.all(color: _T.line),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _T.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.directions_car_rounded,
                      color: _T.primary, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Live Tracking',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w900, color: _T.navy)),
                  Text('Booking #${widget.bookingId}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: _T.muted)),
                ],
              ),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () {
            if (_driverLocation != null) _fitBounds(_driverLocation!);
          },
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _T.primary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x305B59A6), blurRadius: 12, offset: Offset(0, 4))
              ],
            ),
            child: const Icon(Icons.fit_screen_rounded,
                color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }

  // ── Markers ───────────────────────────────────────────────────────────────
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Pickup marker
    markers.add(Marker(
      point: widget.pickupLocation,
      width: 44, height: 44,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
          ],
        ),
        child: const Center(
          child: Icon(Icons.person_rounded, color: Colors.white, size: 20),
        ),
      ),
    ));

    // Destination marker
    markers.add(Marker(
      point: widget.destLocation,
      width: 40, height: 40,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
          ],
        ),
        child: const Icon(Icons.place_rounded, color: Colors.white, size: 20),
      ),
    ));

    // Driver marker with pulse
    if (_driverLocation != null) {
      markers.add(Marker(
        point: _driverLocation!,
        width: 56, height: 56,
        child: Stack(alignment: Alignment.center, children: [
          // Pulse ring
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Transform.scale(
              scale: _pulseScale.value,
              child: Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3B82F6).withOpacity(
                      (1 - _pulseCtrl.value) * 0.4),
                ),
              ),
            ),
          ),
          // Car icon
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 5))
              ],
            ),
            child: const Center(
              child: Icon(Icons.directions_car_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
        ]),
      ));
    }

    return markers;
  }

  // ── Bottom sheet ──────────────────────────────────────────────────────────
  Widget _buildBottomSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Color(0x1A233B5C), blurRadius: 40, offset: Offset(0, -8))
        ],
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: _tripStatus == 'completed'
          ? _buildCompletedSheet()
          : (_driverLocation == null
              ? _buildWaitingSheet()
              : _buildActiveSheet()),
    );
  }

  // ── Waiting state ─────────────────────────────────────────────────────────
  Widget _buildWaitingSheet() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _dragBar(),
      const SizedBox(height: 24),
      SizedBox(
        width: 48, height: 48,
        child: CircularProgressIndicator(
          valueColor: const AlwaysStoppedAnimation(_T.primary),
          backgroundColor: _T.primary.withOpacity(0.1),
          strokeWidth: 4,
        ),
      ),
      const SizedBox(height: 16),
      const Text('Waiting for driver',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w900, color: _T.navy)),
      const SizedBox(height: 6),
      Text(
        "We'll update this page the moment your driver starts moving.",
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: _T.muted),
      ),
      const SizedBox(height: 20),
    ]);
  }

  // ── Active trip state ─────────────────────────────────────────────────────
  Widget _buildActiveSheet() {
    final ui = _kTripUi[_tripStatus] ?? _kTripUi['arriving']!;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      _dragBar(),
      const SizedBox(height: 14),

      // Status banner
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ui.bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ui.border, width: 1.5),
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
                color: ui.iconBg, borderRadius: BorderRadius.circular(14)),
            child: Center(
              child: Icon(ui.icon, color: ui.iconColor, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ui.label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w900, color: _T.navy)),
              const SizedBox(height: 3),
              Text(ui.sub,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: _T.muted)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // ETA / distance / fare chips
      Row(children: [
        _etaChip('ETA', _etaSecs > 0 ? _etaText : '—'),
        const SizedBox(width: 8),
        _etaChip('Distance', _distText(_driverLocation)),
        const SizedBox(width: 8),
        _etaChip('Fare', widget.fare > 0
            ? '${widget.fare.toStringAsFixed(0)} EGP' : '—',
            small: true),
      ]),
      const SizedBox(height: 12),

      // Route row
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _T.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _T.line),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            Container(
                width: 10, height: 10,
                decoration: const BoxDecoration(
                    color: Color(0xFF3B82F6), shape: BoxShape.circle)),
            Container(width: 2, height: 20, color: _T.line),
            Container(
                width: 10, height: 10,
                decoration: const BoxDecoration(
                    color: Color(0xFF8B5CF6), shape: BoxShape.circle)),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _routeLabel('PICKUP', widget.pickupAddress.isNotEmpty
                  ? widget.pickupAddress : 'Your pickup point'),
              const SizedBox(height: 8),
              _routeLabel('DESTINATION', widget.destAddress.isNotEmpty
                  ? widget.destAddress : '—'),
            ]),
          ),
        ]),
      ),
    ]);
  }

  Widget _etaChip(String label, String value, {bool small = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: _T.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _T.line),
        ),
        child: Column(children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w900,
                  color: _T.muted, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: small ? 13 : 18,
                  fontWeight: FontWeight.w900, color: _T.navy),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget _routeLabel(String label, String addr) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w900,
              color: _T.muted, letterSpacing: 0.6)),
      const SizedBox(height: 2),
      Text(addr,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: _T.navy),
          maxLines: 2,
          overflow: TextOverflow.ellipsis),
    ]);
  }

  // ── Completed state ───────────────────────────────────────────────────────
  Widget _buildCompletedSheet() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _dragBar(),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF353B69), Color(0xFF6470D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.25), width: 2),
            ),
            child: const Center(
              child: Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 38),
            ),
          ),
          const SizedBox(height: 16),
          const Text("You've arrived!",
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            'Trip completed. Fare: ${widget.fare > 0 ? "${widget.fare.toStringAsFixed(2)} EGP" : "—"}',
            style: const TextStyle(
                fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white30, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.list_alt_rounded, size: 18),
              label: const Text('My Bookings',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 8),
    ]);
  }

  // ── Drag bar ──────────────────────────────────────────────────────────────
  Widget _dragBar() {
    return Center(
      child: Container(
        width: 40, height: 4,
        decoration: BoxDecoration(
            color: _T.line, borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}