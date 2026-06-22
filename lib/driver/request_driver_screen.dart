// lib/driver/request_driver_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
//  Request Ride screen — redesigned UI to match app design language.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'driver_api.dart';
import 'booking_status_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kPrimary     = Color(0xFF2D2D5A);
const _kPrimaryDark = Color(0xFF1F2040);
const _kAccent      = Color(0xFF6470D2);
const _kGold        = Color(0xFFEDCC6F);
const _kBg          = Color(0xFFF6F8FD);
const _kCard        = Color(0xFFFFFFFF);
const _kLine        = Color(0xFFE8EBF5);
const _kMuted       = Color(0xFF7B7F98);
const _kSoft        = Color(0xFFEEEDFE);
const _kGreen       = Color(0xFF16A34A);
const _kGreenSoft   = Color(0xFFEEFBF3);

class RequestDriverScreen extends StatefulWidget {
  final int patientId;
  const RequestDriverScreen({super.key, required this.patientId});

  @override
  State<RequestDriverScreen> createState() => _RequestDriverScreenState();
}

class _RequestDriverScreenState extends State<RequestDriverScreen>
    with TickerProviderStateMixin {

  // ── Map ───────────────────────────────────────────────────────────────────
  final _mapController = MapController();
  static const _cairo  = LatLng(30.0444, 31.2357);

  // ── Pins ──────────────────────────────────────────────────────────────────
  LatLng? pickupLocation;
  LatLng? destinationLocation;
  String  pickupAddress      = '';
  String  destinationAddress = '';

  // ── Form ──────────────────────────────────────────────────────────────────
  String requestType   = 'instant';
  String paymentMethod = 'cash';
  DateTime?  _schedDate;
  TimeOfDay? _schedTime;

  // ── Pricing ───────────────────────────────────────────────────────────────
  double estimatedPrice = 0.0;
  double distanceKm     = 0.0;
  bool   _calcLoading   = false;

  // ── Submit ────────────────────────────────────────────────────────────────
  bool   isSubmitting = false;
  String _error       = '';

  // ── Active booking check ──────────────────────────────────────────────────
  bool _checkingActive = true;

  // ── Controllers ───────────────────────────────────────────────────────────
  final _pickupCtrl = TextEditingController();
  final _destCtrl   = TextEditingController();

  // ── Panel animation ───────────────────────────────────────────────────────
  late final AnimationController _panelAnim;
  late final Animation<Offset>   _panelSlide;
  late final Animation<double>   _panelFade;

  @override
  void initState() {
    super.initState();
    _panelAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _panelSlide = Tween<Offset>(
            begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _panelAnim, curve: Curves.easeOutCubic));
    _panelFade = CurvedAnimation(parent: _panelAnim, curve: Curves.easeOut);
    _panelAnim.forward();
    _init();
  }

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    _panelAnim.dispose();
    super.dispose();
  }

  // ── Init: check for active instant booking first ──────────────────────────
  Future<void> _init() async {
    final active = await DriverApi.getActiveBooking(widget.patientId);
    if (!mounted) return;

    if (active != null) {
      final bookingRequestType = (active['request_type'] as String? ?? '').toLowerCase().trim();
      final status             = (active['status'] as String? ?? '').toLowerCase().trim();
      final bookingId          = active['booking_id'] as int? ?? 0;

      final isTerminal = status == 'completed' ||
          status == 'cancelled' ||
          status == 'declined';

      // Only block re-entry for active INSTANT bookings.
      // Scheduled bookings allow the user to come back and book again.
      final shouldRedirect = !isTerminal &&
          bookingRequestType == 'instant' &&
          bookingId > 0;

      debugPrint('[_init] type=$bookingRequestType status=$status '
          'terminal=$isTerminal redirect=$shouldRedirect');

      if (shouldRedirect) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BookingStatusScreen(
              bookingId: bookingId,
              patientId: widget.patientId,
            ),
          ),
        );
        return;
      }
    }

    setState(() => _checkingActive = false);
    _getCurrentLocation();
  }

  // ── Address search ────────────────────────────────────────────────────────
  Future<List<Map>> _searchAddress(String query) async {
    if (query.trim().length < 3) return [];
    const viewbox = '24.7,22.0,37.0,31.7';
    final url =
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json&limit=8&countrycodes=eg'
        '&viewbox=$viewbox&bounded=1&addressdetails=1';
    try {
      final res = await http.get(Uri.parse(url), headers: {
        'User-Agent':      'RafiqApp/1.0',
        'Accept-Language': 'en,ar',
      }).timeout(const Duration(seconds: 15)); // ← was 6, now 15
      if (res.statusCode == 200) {
        return (jsonDecode(res.body) as List).cast<Map>();
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }
    return [];
  }

  // ── Reverse geocode ───────────────────────────────────────────────────────
  Future<String> _reverseGeocode(LatLng ll) async {
    try {
      final url =
          'https://nominatim.openstreetmap.org/reverse'
          '?format=jsonv2&lat=${ll.latitude}&lon=${ll.longitude}';
      final res = await http.get(Uri.parse(url),
          headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        return (jsonDecode(res.body)['display_name'] as String? ?? '');
      }
    } catch (_) {}
    return '';
  }

  // ── GPS ───────────────────────────────────────────────────────────────────
  Future<void> _getCurrentLocation() async {
    final svc = await Geolocator.isLocationServiceEnabled();
    if (!svc) { _showMsg('Please turn on GPS.'); return; }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) return;

    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final ll   = LatLng(pos.latitude, pos.longitude);
      final addr = await _reverseGeocode(ll);
      if (!mounted) return;
      setState(() {
        pickupLocation   = ll;
        pickupAddress    = addr;
        _pickupCtrl.text = addr;
        _mapController.move(ll, 15);
      });
      _calculatePrice();
    } catch (e) {
      _showMsg('Location error: $e');
    }
  }

  // ── OSRM route distance ───────────────────────────────────────────────────
  Future<void> _calculatePrice() async {
    if (pickupLocation == null || destinationLocation == null) return;
    setState(() => _calcLoading = true);
    try {
      final p = pickupLocation!;
      final d = destinationLocation!;
      final url =
          'https://router.project-osrm.org/route/v1/driving/'
          '${p.longitude},${p.latitude};${d.longitude},${d.latitude}'
          '?overview=false&alternatives=false&steps=false';
      final res = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j['code'] == 'Ok') {
          final meters = (j['routes'][0]['distance'] as num).toDouble();
          if (!mounted) return;
          setState(() {
            distanceKm     = meters / 1000;
            estimatedPrice = distanceKm <= 4 ? 50.0 : 50.0 + (distanceKm - 4) * 15;
            _calcLoading   = false;
          });
          return;
        }
      }
    } catch (_) {}
    const calc = Distance();
    final km = calc.as(LengthUnit.Kilometer, pickupLocation!, destinationLocation!);
    setState(() {
      distanceKm     = km;
      estimatedPrice = km <= 4 ? 50.0 : 50.0 + (km - 4) * 15;
      _calcLoading   = false;
    });
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submitRideRequest() async {
    HapticFeedback.mediumImpact();
    if (pickupLocation == null) {
      _showMsg('Pickup location is missing.'); return;
    }
    if (destinationLocation == null) {
      _showMsg('Please choose your destination first.'); return;
    }
    if (requestType == 'scheduled' && (_schedDate == null || _schedTime == null)) {
      _showMsg('Please select a date and time for your scheduled ride.'); return;
    }

    setState(() { isSubmitting = true; _error = ''; });

    final result = await DriverApi.requestDriverBooking(
      patientId:     widget.patientId,
      pickupLat:     pickupLocation!.latitude,
      pickupLng:     pickupLocation!.longitude,
      destLat:       destinationLocation!.latitude,
      destLng:       destinationLocation!.longitude,
      pickupAddress: pickupAddress,
      destination:   destinationAddress,
      requestType:   requestType,
      schedDate:     _schedDate,
      schedTime:     _schedTime,
      distanceKm:    distanceKm,
      totalFare:     estimatedPrice,
    );

    if (!mounted) return;
    setState(() => isSubmitting = false);

    if (result['ok'] == true) {
      final bookingId = result['booking_id'] as int;
      if (requestType == 'instant') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BookingStatusScreen(
              bookingId: bookingId,
              patientId: widget.patientId,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingStatusScreen(
              bookingId: bookingId,
              patientId: widget.patientId,
            ),
          ),
        );
      }
    } else {
      setState(() => _error = result['error']?.toString() ?? 'Booking failed.');
      _showMsg(_error);
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────
  void _resetPins() {
    HapticFeedback.lightImpact();
    _pickupCtrl.clear();
    _destCtrl.clear();
    setState(() {
      pickupLocation      = null;
      destinationLocation = null;
      pickupAddress       = '';
      destinationAddress  = '';
      estimatedPrice      = 0.0;
      distanceKm          = 0.0;
      _error              = '';
      _schedDate          = null;
      _schedTime          = null;
    });
    _getCurrentLocation();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // ── Show spinner while checking for an active booking ──────────────────
    if (_checkingActive) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(
          child: CircularProgressIndicator(color: _kPrimary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // ── Map (top 55% of screen) ──────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            height: MediaQuery.of(context).size.height * 0.55,
            child: _buildMap(),
          ),

          // ── Custom AppBar overlay ────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildAppBarOverlay(),
          ),

          // ── Bottom panel ─────────────────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: FadeTransition(
              opacity: _panelFade,
              child: SlideTransition(
                position: _panelSlide,
                child: _buildBottomPanel(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Map widget ────────────────────────────────────────────────────────────
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _cairo,
        initialZoom: 13,
        onTap: (_, point) async {
          if (pickupLocation == null) {
            final addr = await _reverseGeocode(point);
            setState(() {
              pickupLocation   = point;
              pickupAddress    = addr;
              _pickupCtrl.text = addr;
            });
          } else {
            final addr = await _reverseGeocode(point);
            setState(() {
              destinationLocation = point;
              destinationAddress  = addr;
              _destCtrl.text      = addr;
            });
            _calculatePrice();
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.rafiq.app.v2',
        ),
        if (pickupLocation != null && destinationLocation != null)
          PolylineLayer(polylines: [
            Polyline(
              points: [pickupLocation!, destinationLocation!],
              color: _kAccent.withOpacity(0.7),
              strokeWidth: 3.5,
              isDotted: true,
            ),
          ]),
        MarkerLayer(markers: _buildMarkers()),
      ],
    );
  }

  // ── AppBar overlay on map ─────────────────────────────────────────────────
  Widget _buildAppBarOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Back button
            _MapIconBtn(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(width: 10),
            // Title pill
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: _kPrimary.withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_kPrimary, _kAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.directions_car_rounded,
                        color: Colors.white, size: 15),
                  ),
                  const SizedBox(width: 10),
                  const Text('Request a Ride',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: _kPrimary)),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            // Reset button
            _MapIconBtn(
              icon: Icons.refresh_rounded,
              onTap: _resetPins,
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom panel ──────────────────────────────────────────────────────────
  Widget _buildBottomPanel() {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 16),
      decoration: const BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Color(0x1A2D2D5A), blurRadius: 32, offset: Offset(0, -8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: _kLine, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          const SizedBox(height: 18),

          // Route inputs
          _buildRouteCard(),
          const SizedBox(height: 14),

          // Ride type + Payment in one row
          Row(children: [
            Expanded(child: _buildSegmentRow()),
          ]),
          const SizedBox(height: 14),

          // Scheduled pickers
          if (requestType == 'scheduled') ...[
            _buildScheduledRow(),
            const SizedBox(height: 14),
          ],

          // Fare + Confirm row
          _buildFareConfirmRow(),

          // Error
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildErrorBanner(),
          ],
        ],
      ),
    );
  }

  // ── Route card ────────────────────────────────────────────────────────────
  Widget _buildRouteCard() {
    return Container(
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kLine),
      ),
      child: Column(children: [
        _buildSearchField(
          hint: 'Pickup location',
          dotColor: _kGreen,
          currentValue: pickupAddress,
          onClear: () => setState(() { pickupLocation = null; pickupAddress = ''; }),
          onSelected: (lat, lng, name) async {
            final ll = LatLng(lat, lng);
            setState(() {
              pickupLocation = ll;
              pickupAddress  = name;
              _mapController.move(ll, 15);
            });
            _calculatePrice();
          },
          trailing: _SmallIconBtn(
            icon: Icons.gps_fixed_rounded,
            color: _kGreen,
            onTap: _getCurrentLocation,
            tooltip: 'Use current location',
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 36, right: 16),
          child: Divider(height: 1, color: _kLine),
        ),
        _buildSearchField(
          hint: 'Where to?',
          dotColor: _kPrimary,
          currentValue: destinationAddress,
          onClear: () => setState(() { destinationLocation = null; destinationAddress = ''; }),
          onSelected: (lat, lng, name) {
            final ll = LatLng(lat, lng);
            setState(() {
              destinationLocation = ll;
              destinationAddress  = name;
              _mapController.move(ll, 15);
            });
            _calculatePrice();
          },
          trailing: _SmallIconBtn(
            icon: Icons.touch_app_rounded,
            color: _kAccent,
            onTap: () => _showMsg('Tap the map to set destination'),
            tooltip: 'Tap map',
          ),
        ),
      ]),
    );
  }

  // ── Search field with Nominatim autocomplete ──────────────────────────────
  Widget _buildSearchField({
    required String hint,
    required Color dotColor,
    required String currentValue,
    required Function(double, double, String) onSelected,
    required VoidCallback onClear,
    Widget? trailing,
  }) {
    return Autocomplete<Map>(
      optionsBuilder: (tv) async {
        if (tv.text.trim().length < 3) return const [];
        await Future.delayed(const Duration(milliseconds: 400)); // debounce
        if (tv.text.trim().length < 3) return const [];          // re-check after delay
        return _searchAddress(tv.text);
      },
      displayStringForOption: (o) => o['display_name'] as String? ?? '',
      onSelected: (o) {
        final lat  = double.tryParse('${o['lat']}') ?? 0.0;
        final lng  = double.tryParse('${o['lon']}') ?? 0.0;
        final name = o['display_name'] as String? ?? '';
        onSelected(lat, lng, name);
      },
      fieldViewBuilder: (ctx, ctrl, focus, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(children: [
            Container(
              width: 10, height: 10,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                  color: dotColor, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: dotColor.withOpacity(0.3),
                      blurRadius: 6, spreadRadius: 1)]),
            ),
            Expanded(
              child: TextField(
                controller: ctrl,
                focusNode: focus,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _kPrimary),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                      color: _kMuted.withOpacity(0.6), fontWeight: FontWeight.w500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  isDense: true,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ]),
        );
      },
      optionsViewBuilder: (ctx, onSel, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(18),
            color: _kCard,
            child: Container(
              width: MediaQuery.of(ctx).size.width - 52,
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final o = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    leading: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                          color: _kSoft, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.place_outlined, size: 16, color: _kAccent),
                    ),
                    title: Text(
                      o['display_name'] as String? ?? 'Location',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: _kPrimary),
                      maxLines: 2,
                    ),
                    onTap: () => onSel(o),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Segment controls: Instant/Scheduled + Cash/Visa ───────────────────────
  Widget _buildSegmentRow() {
    return Column(children: [
      // Ride type
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kLine),
        ),
        child: Row(children: [
          _SegmentBtn(
            icon: Icons.bolt_rounded,
            label: 'Instant',
            selected: requestType == 'instant',
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                requestType = 'instant';
                _schedDate  = null;
                _schedTime  = null;
              });
            },
          ),
          _SegmentBtn(
            icon: Icons.calendar_today_rounded,
            label: 'Scheduled',
            selected: requestType == 'scheduled',
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => requestType = 'scheduled');
            },
          ),
        ]),
      ),
      const SizedBox(height: 10),
      // Payment
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kLine),
        ),
        child: Row(children: [
          _SegmentBtn(
            icon: Icons.payments_rounded,
            label: 'Cash',
            selected: paymentMethod == 'cash',
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => paymentMethod = 'cash');
            },
          ),
          _SegmentBtn(
            icon: Icons.credit_card_rounded,
            label: 'Visa',
            selected: paymentMethod == 'visa',
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => paymentMethod = 'visa');
            },
          ),
        ]),
      ),
    ]);
  }

  // ── Scheduled date/time pickers ───────────────────────────────────────────
  Widget _buildScheduledRow() {
    return Row(children: [
      Expanded(child: _buildSchedPicker(
        icon: Icons.calendar_today_rounded,
        label: 'Date',
        value: _schedDate == null
            ? null
            : '${_schedDate!.day}/${_schedDate!.month}/${_schedDate!.year}',
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: DateTime.now().add(const Duration(days: 1)),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 30)),
            builder: (ctx, child) => Theme(
              data: Theme.of(ctx).copyWith(
                colorScheme: const ColorScheme.light(
                    primary: _kPrimary, onPrimary: Colors.white)),
              child: child!,
            ),
          );
          if (d != null) setState(() => _schedDate = d);
        },
      )),
      const SizedBox(width: 10),
      Expanded(child: _buildSchedPicker(
        icon: Icons.access_time_rounded,
        label: 'Time',
        value: _schedTime?.format(context),
        onTap: () async {
          final t = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(
                      primary: _kPrimary, onPrimary: Colors.white)),
                child: child!,
              ));
          if (t != null) setState(() => _schedTime = t);
        },
      )),
    ]);
  }

  Widget _buildSchedPicker({
    required IconData icon,
    required String label,
    required String? value,
    required VoidCallback onTap,
  }) {
    final hasValue = value != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hasValue ? _kSoft : _kBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: hasValue ? _kAccent.withOpacity(0.4) : _kLine,
              width: hasValue ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(icon,
              size: 16,
              color: hasValue ? _kAccent : _kMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: hasValue ? _kAccent : _kMuted,
                      letterSpacing: 0.4)),
              Text(
                value ?? 'Pick $label',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: hasValue ? _kPrimary : _kMuted),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Fare + confirm ────────────────────────────────────────────────────────
  Widget _buildFareConfirmRow() {
    final canSubmit = pickupLocation != null && destinationLocation != null && !isSubmitting;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Fare display
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '${distanceKm.toStringAsFixed(1)} KM',
              style: const TextStyle(
                  color: _kMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2),
            ),
            const SizedBox(height: 2),
            _calcLoading
                ? const SizedBox(
                    width: 80, height: 32,
                    child: Center(
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: _kPrimary, strokeWidth: 2.5),
                      ),
                    ))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        estimatedPrice > 0
                            ? estimatedPrice.toStringAsFixed(0)
                            : '—',
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: _kPrimary,
                            height: 1.0),
                      ),
                      if (estimatedPrice > 0) ...[
                        const SizedBox(width: 4),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text('EGP',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _kMuted)),
                        ),
                      ],
                    ],
                  ),
          ]),
        ),

        // Confirm button
        GestureDetector(
          onTap: canSubmit ? _submitRideRequest : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            decoration: BoxDecoration(
              gradient: canSubmit
                  ? const LinearGradient(
                      colors: [_kPrimary, _kAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight)
                  : null,
              color: canSubmit ? null : _kLine,
              borderRadius: BorderRadius.circular(20),
              boxShadow: canSubmit
                  ? [
                      BoxShadow(
                          color: _kPrimary.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6))
                    ]
                  : null,
            ),
            child: isSubmitting
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      requestType == 'scheduled'
                          ? Icons.schedule_send_rounded
                          : Icons.local_taxi_rounded,
                      color: canSubmit ? Colors.white : _kMuted,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      requestType == 'scheduled' ? 'Schedule' : 'Confirm',
                      style: TextStyle(
                          color: canSubmit ? Colors.white : _kMuted,
                          fontWeight: FontWeight.w900,
                          fontSize: 15),
                    ),
                  ]),
          ),
        ),
      ],
    );
  }

  // ── Error banner ──────────────────────────────────────────────────────────
  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3BCBC)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded,
            color: Color(0xFFB53535), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(_error,
              style: const TextStyle(
                  color: Color(0xFFB53535),
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  // ── Markers ───────────────────────────────────────────────────────────────
  List<Marker> _buildMarkers() {
    final list = <Marker>[];
    if (pickupLocation != null) {
      list.add(Marker(
        point: pickupLocation!,
        width: 28, height: 28,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: _kGreen, width: 4),
            boxShadow: [
              BoxShadow(
                  color: _kGreen.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
        ),
      ));
    }
    if (destinationLocation != null) {
      list.add(Marker(
        point: destinationLocation!,
        width: 44, height: 56,
        child: Column(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_kPrimary, _kAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kGold, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 12,
                      offset: Offset(0, 5))
                ],
              ),
              child: const Icon(Icons.place_rounded,
                  color: Colors.white, size: 22),
            ),
            Container(
              width: 2, height: 8,
              color: _kPrimary.withOpacity(0.4),
            ),
          ],
        ),
      ));
    }
    return list;
  }

  // ── Snackbar ──────────────────────────────────────────────────────────────
  void _showMsg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: _kPrimary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Frosted icon button overlaid on the map
class _MapIconBtn extends StatelessWidget {
  const _MapIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: _kPrimary.withOpacity(0.12),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Icon(icon, color: _kPrimary, size: 20),
    ),
  );
}

/// Small icon button inside search fields
class _SmallIconBtn extends StatelessWidget {
  const _SmallIconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 30, height: 30,
      margin: const EdgeInsets.only(left: 6),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 15),
    ),
  );
}

/// Pill-style segment button
class _SegmentBtn extends StatelessWidget {
  const _SegmentBtn({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [_kPrimary, _kAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)
                : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: _kPrimary.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3))
                  ]
                : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                size: 15,
                color: selected ? Colors.white : _kMuted),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : _kMuted)),
          ]),
        ),
      ),
    );
  }
}