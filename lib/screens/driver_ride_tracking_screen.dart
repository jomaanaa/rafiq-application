// lib/driverdriver_/ride_tracking_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../auth/api_service.dart';

class DriverRideTrackingScreen extends StatefulWidget {
  /// Pass the full booking map from the active trips list.
  /// Required keys: booking_id, first_name, last_name, address,
  ///                destination, payment_total,
  ///                pickup_lat, pickup_lng, dest_lat, dest_lng
  final Map booking;

  const DriverRideTrackingScreen({super.key, required this.booking});

  @override
  State<DriverRideTrackingScreen> createState() => _DriverRideTrackingScreenState();
}

class _DriverRideTrackingScreenState extends State<DriverRideTrackingScreen> {

  // ── Design tokens (matches driver_session_screen palette)
  static const kPrimary = Color(0xff2E2E5D);
  static const kMuted   = Color(0xff7A84A3);

  // ── Phase — mirrors tracking_api trip_status values
  String _phase = 'waiting';

  // ── GPS
  StreamSubscription<Position>? _gpsSub;
  LatLng? _driverPos;
  bool _gpsActive = false;

  // ── Map
  final MapController _mapController = MapController();
  bool _loading = true;

  // ── Booking data (parsed once in initState)
  late final int     _bookingId;
  late final LatLng  _pickupLatLng;
  LatLng?            _destLatLng;
  late final String  _patientName;
  late final String  _pickupAddress;
  late final String  _destination;
  late final String  _fare;

  // ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _parseBooking();
    _loadExistingState();
  }

  void _parseBooking() {
    final b = widget.booking;

    _bookingId = int.tryParse(b['booking_id'].toString()) ?? 0;

    final pLat = double.tryParse(b['pickup_lat']?.toString() ?? '');
    final pLng = double.tryParse(b['pickup_lng']?.toString() ?? '');
    final dLat = double.tryParse(b['dest_lat']?.toString()  ?? '');
    final dLng = double.tryParse(b['dest_lng']?.toString()  ?? '');

    // Cairo fallback if coords missing
    _pickupLatLng = (pLat != null && pLng != null)
        ? LatLng(pLat, pLng)
        : const LatLng(30.0444, 31.2357);

    _destLatLng = (dLat != null && dLng != null) ? LatLng(dLat, dLng) : null;

    _patientName  = '${b['first_name'] ?? ''} ${b['last_name'] ?? ''}'.trim();
    _pickupAddress = b['address']     ?? 'See map';
    _destination   = b['destination'] ?? '—';

    final total = double.tryParse(b['payment_total']?.toString() ?? '0') ?? 0;
    _fare = '${total.toStringAsFixed(2)} EGP';
  }

  // Load existing tracking state from the server (so resuming works)
  Future<void> _loadExistingState() async {
    try {
      final res = await http.get(Uri.parse(
        '${ApiService.baseUrl}/driver_tracking_api.php?action=get&booking_id=$_bookingId',
      ));
      if (!mounted) return; 
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d['ok'] == true && d['tracking'] != null) {
          final t     = d['tracking'] as Map;
          final phase = (t['trip_status'] as String?) ?? 'waiting';
          final lat   = double.tryParse(t['driver_lat']?.toString() ?? '');
          final lng   = double.tryParse(t['driver_lng']?.toString() ?? '');
          if (mounted) {
            setState(() {
              _phase     = phase;
              _driverPos = (lat != null && lng != null) ? LatLng(lat, lng) : null;
            });
          }
          if (['arriving', 'arrived', 'in_progress'].contains(phase)) {
            _startGPS();
          }
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  // ── Phase transitions ──────────────────────────────────────
  Future<void> _setPhase(String phase) async {
    setState(() => _phase = phase);

    // 1. Tell tracking_api the new status
    _postTracking('update_status', {'booking_id': _bookingId, 'status': phase});

    // 2. Side effects
      if (phase == 'arriving') {
        _startGPS();
      }

      if (phase == 'arrived') {
        await ApiService.updateBookingStatus(_bookingId, 'arrived');
      }

      if (phase == 'in_progress') {
        await ApiService.updateBookingStatus(_bookingId, 'in_trip');
      }

      if (phase == 'completed') {
      _stopGPS();
      // Update booking table + wallet via update_booking_status.php
      await ApiService.updateBookingStatus(_bookingId, 'completed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Trip completed! Earnings added to your wallet ✅'),
          backgroundColor: Color(0xff1F9D5A),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── GPS ────────────────────────────────────────────────────
  Future<void> _startGPS() async {
    if (_gpsSub != null) return;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location permission denied. Please enable it in settings.'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    setState(() => _gpsActive = true);

    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // only broadcast if moved ≥ 10 m
      ),
    ).listen((pos) {
      _broadcastLocation(pos.latitude, pos.longitude);
    });
  }

  void _stopGPS() {
    _gpsSub?.cancel();
    _gpsSub = null;
    _gpsActive = false;
    if (mounted) setState(() {});
  }

  Future<void> _broadcastLocation(double lat, double lng) async {
    final pos = LatLng(lat, lng);
    if (mounted) {
      setState(() => _driverPos = pos);
      try { _mapController.move(pos, 15); } catch (_) {}
    }
    _postTracking('update_location', {'booking_id': _bookingId, 'lat': lat, 'lng': lng});
  }

  Future<void> _postTracking(String action, Map<String, dynamic> body) async {
    try {
      await http.post(
        Uri.parse('${ApiService.baseUrl}/driver_tracking_api.php?action=$action'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _gpsSub = null;
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : Stack(children: [

              // ── MAP ─────────────────────────────────────────
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _driverPos ?? _pickupLatLng,
                  initialZoom: 14,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.rafiq.app',
                  ),
                  // Route line
                  if (_driverPos != null)
                    PolylineLayer(polylines: [
                      Polyline(
                        points: [
                          _driverPos!,
                          (_phase == 'in_progress' && _destLatLng != null)
                              ? _destLatLng!
                              : _pickupLatLng,
                        ],
                        strokeWidth: 4,
                        color: kPrimary.withOpacity(0.65),
                        isDotted: true,
                      ),
                    ]),
                  // Markers
                  MarkerLayer(markers: _buildMarkers()),
                ],
              ),

              // ── BACK BUTTON ──────────────────────────────────
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: kPrimary),
                  ),
                ),
              ),

              // ── BOTTOM SHEET ─────────────────────────────────
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: _buildBottomSheet(),
              ),
            ]),
    );
  }

  // ── Markers ────────────────────────────────────────────────
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Pickup (passenger)
    markers.add(Marker(
      point: _pickupLatLng,
      width: 48, height: 48,
      child: _mapPin(
        emoji: '🧑',
        gradient: const LinearGradient(
            colors: [Color(0xfff59e0b), Color(0xffd97706)]),
      ),
    ));

    // Destination
    if (_destLatLng != null) {
      markers.add(Marker(
        point: _destLatLng!,
        width: 44, height: 44,
        child: _mapPin(
          emoji: '📍',
          gradient: const LinearGradient(
              colors: [Color(0xff8b5cf6), Color(0xff7c3aed)]),
          size: 44,
        ),
      ));
    }

    // Driver (live)
    if (_driverPos != null) {
      markers.add(Marker(
        point: _driverPos!,
        width: 50, height: 50,
        child: _mapPin(
          emoji: '🚗',
          gradient: const LinearGradient(
              colors: [Color(0xff3b82f6), Color(0xff1d4ed8)]),
          size: 50,
        ),
      ));
    }

    return markers;
  }

  Widget _mapPin({
    required String emoji,
    required Gradient gradient,
    double size = 48,
  }) =>
      Container(
        width: size, height: size,
        decoration: BoxDecoration(
          gradient: gradient,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8),
          ],
        ),
        child: Center(
            child: Text(emoji,
                style: TextStyle(fontSize: size * 0.42))),
      );

  // ── Bottom Sheet ────────────────────────────────────────────
  Widget _buildBottomSheet() {
    final cfg = _kStatusConfig[_phase] ?? _kStatusConfig['waiting']!;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff1a1b2e), Color(0xff12131f)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Colors.black54,
              blurRadius: 20,
              offset: Offset(0, -4)),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 28 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // Drag bar
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 16),

        // Status banner
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cfg['bg'] as Color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: cfg['dot'] as Color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cfg['label'] as String,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              Text(cfg['sub'] as String,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),

        const SizedBox(height: 14),

        // Trip info tiles
        Row(children: [
          Expanded(child: _infoTile('Passenger', _patientName)),
          const SizedBox(width: 10),
          Expanded(child: _infoTile('Fare', _fare)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _infoTile('Pickup', _pickupAddress, small: true)),
          const SizedBox(width: 10),
          Expanded(
              child: _infoTile('Destination', _destination, small: true)),
        ]),

        const SizedBox(height: 14),

        // Phase button or completion message
        if (_phase == 'completed')
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xff8b5cf6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('Trip Complete ✓',
                  style: TextStyle(
                      color: Color(0xff8b5cf6),
                      fontSize: 15,
                      fontWeight: FontWeight.w900)),
            ),
          )
        else
          _buildPhaseButton(),

        const SizedBox(height: 10),

        // GPS indicator
        Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: _gpsActive
                  ? const Color(0xff10b981)
                  : const Color(0xffef4444),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _gpsActive
                ? 'GPS active — sharing location'
                : 'GPS not active',
            style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
        ]),
      ]),
    );
  }

  Widget _infoTile(String label, String value, {bool small = false}) {
    final display =
        value.length > 42 ? '${value.substring(0, 40)}…' : value;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(display,
            style: TextStyle(
                color: Colors.white,
                fontSize: small ? 11 : 14,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }

  // ── Phase buttons ──────────────────────────────────────────
  Widget _buildPhaseButton() {
    switch (_phase) {
      case 'waiting':
        return _phaseBtn(
          label: '🚗  I\'m on my way',
          c1: const Color(0xff3b82f6),
          c2: const Color(0xff1d4ed8),
          onTap: () => _setPhase('arriving'),
        );
      case 'arriving':
        return _phaseBtn(
          label: '🏁  I\'ve Arrived',
          c1: const Color(0xfff59e0b),
          c2: const Color(0xffd97706),
          onTap: () => _setPhase('arrived'),
        );
      case 'arrived':
        return _phaseBtn(
          label: '▶️  Start Trip',
          c1: const Color(0xff10b981),
          c2: const Color(0xff059669),
          onTap: () => _setPhase('in_progress'),
        );
      case 'in_progress':
        return _phaseBtn(
          label: '✅  Complete Trip',
          c1: const Color(0xff8b5cf6),
          c2: const Color(0xff7c3aed),
          onTap: _confirmComplete,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _phaseBtn({
    required String label,
    required Color c1,
    required Color c2,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity, height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [c1, c2]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: c1.withOpacity(0.30),
                  blurRadius: 14,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      );

  void _confirmComplete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Complete Trip?',
            style: TextStyle(fontWeight: FontWeight.w900, color: kPrimary)),
        content: const Text(
          'This will mark the trip as completed and add earnings to your wallet.',
          style: TextStyle(color: kMuted, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff1F9D5A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _setPhase('completed');
            },
            child: const Text('Complete',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ── Status config (matching driver_tracking.php STATUS_CONFIG) ──
  static const _kStatusConfig = {
    'waiting': {
      'label': 'Ready to go',
      'sub': 'Press "I\'m on my way" to start sharing location',
      'bg': Color(0x1A64748b),
      'dot': Color(0xff64748b),
    },
    'arriving': {
      'label': 'On the way',
      'sub': 'Sharing your location with passenger',
      'bg': Color(0x1A3b82f6),
      'dot': Color(0xff3b82f6),
    },
    'arrived': {
      'label': 'You\'ve arrived',
      'sub': 'Waiting for passenger to board',
      'bg': Color(0x1Af59e0b),
      'dot': Color(0xfff59e0b),
    },
    'in_progress': {
      'label': 'Trip in progress',
      'sub': 'Driving to destination',
      'bg': Color(0x1A10b981),
      'dot': Color(0xff10b981),
    },
    'completed': {
      'label': 'Trip completed! 🎉',
      'sub': 'Thank you. Great job!',
      'bg': Color(0x1A8b5cf6),
      'dot': Color(0xff8b5cf6),
    },
  };
}