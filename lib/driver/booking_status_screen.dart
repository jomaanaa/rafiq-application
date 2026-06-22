// lib/driver/booking_status_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
//  Mirrors booking_status.php — shows live booking state for a driver request.
//  Polls every 5 s, animates status changes, navigates to RideTrackingScreen
//  when a driver is assigned (status == 'accepted').
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'driver_api.dart';
import 'ride_tracking_screen.dart';

// ── Shared theme ─────────────────────────────────────────────────────────────
class _T {
  static const primary  = Color(0xFF5B59A6);
  static const primary2 = Color(0xFF494788);
  static const navy     = Color(0xFF1F2340);
  static const muted    = Color(0xFF7B7F98);
  static const bg       = Color(0xFFF7F8FC);
  static const card     = Color(0xFFFFFFFF);
  static const line     = Color(0xFFE9EAF5);
  static const ok       = Color(0xFF2F8F4E);
  static const bad      = Color(0xFFB53535);
  static const shadow   = Color(0x14233B5C);
}

// ── Status config (mirrors booking_status.php JS bannerConfig) ────────────────
class _StatusCfg {
  final Color bannerBg, bannerBorder, iconBg, iconColor;
  final IconData icon;
  final String title, sub;
  const _StatusCfg({
    required this.bannerBg, required this.bannerBorder,
    required this.iconBg, required this.iconColor,
    required this.icon, required this.title, required this.sub,
  });
}

const _kStatusCfg = <String, _StatusCfg>{
  'pending': _StatusCfg(
    bannerBg: Color(0xFFEEF2FF), bannerBorder: Color(0xFFC7D2FE),
    iconBg: Color(0xFFEEF2FF), iconColor: Color(0xFF5B59A6),
    icon: Icons.access_time_rounded,
    title: 'Waiting for a driver to accept',
    sub: 'Your request is live and visible to drivers'),
  'accepted': _StatusCfg(
    bannerBg: Color(0xFFEFF6FF), bannerBorder: Color(0xFFBFDBFE),
    iconBg: Color(0xFFDBEAFE), iconColor: Color(0xFF1D4ED8),
    icon: Icons.directions_car_rounded,
    title: 'Driver accepted your request!',
    sub: 'They are on their way to pick you up'),
  'arriving': _StatusCfg(
    bannerBg: Color(0xFFEFF6FF), bannerBorder: Color(0xFFBFDBFE),
    iconBg: Color(0xFFDBEAFE), iconColor: Color(0xFF1D4ED8),
    icon: Icons.directions_car_rounded,
    title: 'Driver is on the way!',
    sub: 'Your driver is heading to pick you up'),
  'arrived': _StatusCfg(
    bannerBg: Color(0xFFFFFBEB), bannerBorder: Color(0xFFFDE68A),
    iconBg: Color(0xFFFEF3C7), iconColor: Color(0xFFB45309),
    icon: Icons.location_on_rounded,
    title: 'Driver has arrived!',
    sub: 'Your driver is waiting at the pickup point'),
  'in_trip': _StatusCfg(
    bannerBg: Color(0xFFF0FDF4), bannerBorder: Color(0xFFBBF7D0),
    iconBg: Color(0xFFDCFCE7), iconColor: Color(0xFF15803D),
    icon: Icons.moving_rounded,
    title: 'Trip in progress',
    sub: 'You\'re on your way — enjoy the ride!'),
  'in_progress': _StatusCfg(
    bannerBg: Color(0xFFF0FDF4), bannerBorder: Color(0xFFBBF7D0),
    iconBg: Color(0xFFDCFCE7), iconColor: Color(0xFF15803D),
    icon: Icons.moving_rounded,
    title: 'Trip in progress',
    sub: 'You\'re on your way — enjoy the ride!'),
  'completed': _StatusCfg(
    bannerBg: Color(0xFFF5F3FF), bannerBorder: Color(0xFFDDD6FE),
    iconBg: Color(0xFFEDE9FE), iconColor: Color(0xFF7C3AED),
    icon: Icons.check_circle_rounded,
    title: 'Trip completed!',
    sub: 'You have arrived at your destination'),
  'declined': _StatusCfg(
    bannerBg: Color(0xFFFEF2F2), bannerBorder: Color(0xFFFECACA),
    iconBg: Color(0xFFFEE2E2), iconColor: Color(0xFFB91C1C),
    icon: Icons.cancel_rounded,
    title: 'Request declined',
    sub: 'The driver could not accept. Please try again'),
  'cancelled': _StatusCfg(
    bannerBg: Color(0xFFFEF2F2), bannerBorder: Color(0xFFFECACA),
    iconBg: Color(0xFFFEE2E2), iconColor: Color(0xFFB91C1C),
    icon: Icons.cancel_rounded,
    title: 'Booking cancelled',
    sub: 'This booking has been cancelled'),
};

// ─────────────────────────────────────────────────────────────────────────────
class BookingStatusScreen extends StatefulWidget {
  final int bookingId;
  final int patientId;

  const BookingStatusScreen({
    super.key,
    required this.bookingId,
    required this.patientId,
  });

  @override
  State<BookingStatusScreen> createState() => _BookingStatusScreenState();
}

class _BookingStatusScreenState extends State<BookingStatusScreen>
    with TickerProviderStateMixin {
  // ── State ─────────────────────────────────────────────────────────────────
  String _status       = 'pending';
  String _providerName = '';
  double _fare         = 0;
  double _distanceKm   = 0;
  String _pickupAddr   = '';
  String _destAddr     = '';
  LatLng? _pickup;
  LatLng? _dest;
  bool   _loading      = true;
  bool   _cancelling   = false;
  String _error        = '';
  int    _attempts     = 0;

  Timer? _pollTimer;

  // ── Pulse animation ───────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _poll();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Polling ───────────────────────────────────────────────────────────────
  Future<void> _poll() async {
    final res = await DriverApi.getBookingStatus(
        widget.bookingId, widget.patientId);

    if (!mounted) return;

    if (res['ok'] == true) {
      final d = res['data'] as Map<String, dynamic>;
      final newStatus = (d['status'] as String? ?? 'pending').toLowerCase();

      setState(() {
        _status      = newStatus;
        _providerName = (d['provider_name'] as String? ?? '').trim();
        _fare        = double.tryParse('${d['payment_total'] ?? 0}') ?? 0;
        _distanceKm  = double.tryParse('${d['distance_km'] ?? 0}') ?? 0;
        _pickupAddr  = d['pickup_address'] as String? ?? '';
        _destAddr    = d['destination'] as String? ?? '';
        _loading     = false;
        _error       = '';

        final plat = double.tryParse('${d['pickup_lat'] ?? ''}');
        final plng = double.tryParse('${d['pickup_lng'] ?? ''}');
        final dlat = double.tryParse('${d['dest_lat'] ?? ''}');
        final dlng = double.tryParse('${d['dest_lng'] ?? ''}');
        if (plat != null && plng != null) _pickup = LatLng(plat, plng);
        if (dlat != null && dlng != null) _dest   = LatLng(dlat, dlng);
      });

      // Stop polling when terminal
      if (newStatus == 'completed' || newStatus == 'declined' ||
          newStatus == 'cancelled') return;
    } else {
      setState(() { _loading = false; });
    }

    _attempts++;
    final delay = _attempts > 24 ? 10000 : 5000;
    _pollTimer = Timer(Duration(milliseconds: delay), _poll);
  }

  // ── Cancel ────────────────────────────────────────────────────────────────
  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Request?',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
            'This will remove your pending booking. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, Cancel',
                  style: TextStyle(color: _T.bad))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _cancelling = true);
    final res = await DriverApi.cancelDriverRequest(
        widget.bookingId, widget.patientId);
    if (!mounted) return;
    setState(() => _cancelling = false);

    if (res['ok'] == true && (res['deleted'] as int? ?? 0) > 0) {
      Navigator.pop(context);
    } else {
      setState(() => _error = 'Could not cancel — driver may have already accepted.');
    }
  }

  // ── Navigate to tracking ──────────────────────────────────────────────────
  void _openTracking() {
    if (_pickup == null || _dest == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RideTrackingScreen(
          bookingId:     widget.bookingId,
          patientId:     widget.patientId,
          pickupLocation: _pickup!,
          destLocation:   _dest!,
          pickupAddress: _pickupAddr,
          destAddress:   _destAddr,
          fare:          _fare,
        ),
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
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                _buildHero(),
                const SizedBox(height: 16),
                if (_status == 'completed') _buildCompletedCard(),
                _buildProviderCard(),
                const SizedBox(height: 14),
                _buildDetailsCard(),
                const SizedBox(height: 14),
                _buildPaymentCard(),
                const SizedBox(height: 14),
                _buildTimeline(),
                const SizedBox(height: 14),
                if (_error.isNotEmpty) _buildError(),
                _buildActions(),
                const SizedBox(height: 10),
                _buildPollIndicator(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: _T.card,
      foregroundColor: _T.navy,
      elevation: 0,
      shadowColor: _T.shadow,
      surfaceTintColor: Colors.transparent,
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Booking Status',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: _T.navy)),
        Text('Booking #${widget.bookingId}',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: _T.muted)),
      ]),
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 16),
          child: Icon(Icons.directions_car_rounded, color: _T.primary, size: 24),
        ),
      ],
      bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _T.line)),
    );
  }

  // ── Hero strip ────────────────────────────────────────────────────────────
  Widget _buildHero() {
    final cfg = _kStatusCfg[_status] ?? _kStatusCfg['pending']!;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF353B69), Color(0xFF6470D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
              color: Color(0x4D353B69), blurRadius: 28, offset: Offset(0, 12))
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.22)),
            ),
            child: const Center(
              child: Icon(Icons.directions_car_rounded,
                  color: Colors.white, size: 30)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('BOOKING #',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800,
                      color: Colors.white60, letterSpacing: 0.6)),
              Text('${widget.bookingId}',
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
              const Text('Driver Request Submitted',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: Colors.white70)),
            ]),
          ),
        ]),
        const SizedBox(height: 18),

        // Status banner
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cfg.bannerBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cfg.bannerBorder),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: cfg.iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _status == 'pending'
                  ? ScaleTransition(
                      scale: _pulseAnim,
                      child: Icon(cfg.icon, color: cfg.iconColor, size: 20),
                    )
                  : Icon(cfg.icon, color: cfg.iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cfg.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900,
                        color: _T.navy)),
                const SizedBox(height: 3),
                Text(cfg.sub,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: _T.muted)),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Completed card ────────────────────────────────────────────────────────
  Widget _buildCompletedCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEEFBF4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.celebration_rounded,
                color: Color(0xFF15803D), size: 32),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Trip Completed!',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900,
                color: Color(0xFF12643E))),
        const SizedBox(height: 4),
        const Text('We hope everything went smoothly.',
            style: TextStyle(color: Color(0xFF4D8064), fontWeight: FontWeight.w700)),
      ]),
    );
  }

  // ── Provider card ─────────────────────────────────────────────────────────
  Widget _buildProviderCard() {
    final name = _providerName.isNotEmpty ? _providerName : 'Awaiting assignment…';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return _card(
      icon: Icons.man,
      title: 'Driver',
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF292B4A), Color(0xFF353B69)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(initial,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: _T.navy)),
          Container(
            margin: const EdgeInsets.only(top: 5),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _T.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: _T.primary.withOpacity(0.2)),
            ),
            child: const Text('Driver',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w900, color: _T.primary)),
          ),
        ]),
      ]),
    );
  }

  // ── Details card ──────────────────────────────────────────────────────────
  Widget _buildDetailsCard() {
    return _card(
      icon: Icons.list_alt_rounded,
      title: 'Booking Details',
      child: Wrap(
        spacing: 10, runSpacing: 10,
        children: [
          _detailCell('Booking ID', '#${widget.bookingId}'),
          _detailCell('Service', 'Driver'),
          _detailCell('Distance',
              _distanceKm > 0 ? '${_distanceKm.toStringAsFixed(1)} km' : '—'),
          _detailCell('Status',
              _status[0].toUpperCase() + _status.substring(1)),
          if (_pickupAddr.isNotEmpty) _detailCell('Pickup', _pickupAddr, wide: true),
          if (_destAddr.isNotEmpty)   _detailCell('Destination', _destAddr, wide: true),
        ],
      ),
    );
  }

  Widget _detailCell(String label, String value, {bool wide = false}) {
    return SizedBox(
      width: wide ? double.infinity : null,
      child: Container(
        constraints: const BoxConstraints(minWidth: 130),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _T.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _T.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w900,
                  color: _T.muted, letterSpacing: 0.6)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900, color: _T.navy),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  // ── Payment card ──────────────────────────────────────────────────────────
  Widget _buildPaymentCard() {
    return _card(
      icon: Icons.credit_card_rounded,
      title: 'Payment',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('TOTAL AMOUNT',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w900,
                    color: _T.muted, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(
              _fare > 0 ? '${_fare.toStringAsFixed(2)} EGP' : '— EGP',
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w900, color: _T.navy),
            ),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _T.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: _T.primary.withOpacity(0.2)),
            ),
            child: const Row(children: [
              Icon(Icons.payments_rounded, color: _T.primary, size: 18),
              SizedBox(width: 6),
              Text('Pending',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w900, color: _T.primary)),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Timeline (mirrors PHP steps) ──────────────────────────────────────────
  Widget _buildTimeline() {
    final steps = [
      {'icon': Icons.check_circle_outline_rounded, 'color': const Color(0xFF5B59A6), 'title': 'Booking confirmed',  'sub': 'Your request has been sent',         'key': 'pending'},
      {'icon': Icons.directions_car_rounded,        'color': const Color(0xFF1D4ED8), 'title': 'Driver on the way',  'sub': 'Your driver is heading to you',      'key': 'accepted'},
      {'icon': Icons.location_on_rounded,           'color': const Color(0xFFB45309), 'title': 'Driver arrived',     'sub': 'Your driver is at the pickup point', 'key': 'arrived'},
      {'icon': Icons.moving_rounded,                'color': const Color(0xFF15803D), 'title': 'Trip in progress',   'sub': 'You\'re on your way!',               'key': 'in_progress'},
      {'icon': Icons.star_rounded,                  'color': const Color(0xFF7C3AED), 'title': 'Trip completed',     'sub': 'Enjoy rating your experience',       'key': 'completed'},
    ];

    const order = ['pending', 'accepted', 'arrived', 'in_progress', 'completed'];

    final activeKey = _status == 'completed'
        ? 'completed'
        : (_status == 'in_trip' || _status == 'in_progress')
            ? 'in_progress'
            : _status == 'arrived'
                ? 'arrived'
                : (_status == 'accepted' || _status == 'arriving')
                    ? 'accepted'
                    : 'pending';

    final activeIdx = order.indexOf(activeKey);

    return _card(
      icon: Icons.map_rounded,
      title: 'Trip progress',
      child: Column(
        children: List.generate(steps.length, (i) {
          final idx    = order.indexOf(steps[i]['key'] as String);
          final done   = idx < activeIdx;
          final active = idx == activeIdx;

          return Padding(
            padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 18 : 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: done
                        ? const Color(0xFFEEFBF4)
                        : active
                            ? _T.primary.withOpacity(0.12)
                            : _T.bg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: done
                          ? const Color(0xFF22C55E)
                          : active
                              ? _T.primary
                              : _T.line,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      steps[i]['icon'] as IconData,
                      color: done
                          ? const Color(0xFF22C55E)
                          : active
                              ? (steps[i]['color'] as Color)
                              : _T.muted,
                      size: 18,
                    ),
                  ),
                ),
                if (i < steps.length - 1)
                  Container(
                    width: 2, height: 22,
                    color: done ? const Color(0xFF22C55E) : _T.line,
                  ),
              ]),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(steps[i]['title'] as String,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900, color: _T.navy)),
                    const SizedBox(height: 2),
                    Text(steps[i]['sub'] as String,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: _T.muted)),
                  ]),
                ),
              ),
            ]),
          );
        }),
      ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3BCBC)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: _T.bad, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(_error,
            style: const TextStyle(
                color: _T.bad, fontSize: 13, fontWeight: FontWeight.w700))),
      ]),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  Widget _buildActions() {
    return Column(children: [
      // Track Ride button — visible when driver is accepted/en route
      if (_status == 'accepted' || _status == 'arriving' ||
          _status == 'arrived' || _status == 'in_trip' || _status == 'in_progress')
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _T.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: _openTracking,
              icon: const Icon(Icons.map_rounded, size: 20),
              label: const Text('Track Ride',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            ),
          ),
        ),

      Row(children: [
        // Back to bookings
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: _T.navy,
              side: const BorderSide(color: _T.line, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('← My Bookings',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          ),
        ),

        // Cancel — only when pending
        if (_status == 'pending') ...[
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _T.bad,
                side: const BorderSide(color: Color(0xFFF3BCBC), width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _cancelling ? null : _cancel,
              child: _cancelling
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: _T.bad, strokeWidth: 2))
                  : const Text('Cancel Request',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            ),
          ),
        ],
      ]),
    ]);
  }

  // ── Poll indicator ────────────────────────────────────────────────────────
  Widget _buildPollIndicator() {
    final done = _status == 'completed' || _status == 'declined' || _status == 'cancelled';
    if (done) return const SizedBox.shrink();
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 6, height: 6,
        decoration: BoxDecoration(
          color: _T.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: _T.primary.withOpacity(0.4), blurRadius: 6)
          ],
        ),
      ),
      const SizedBox(width: 8),
      const Text('Checking for updates every 5 seconds…',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: _T.muted)),
    ]);
  }

  // ── Card shell ────────────────────────────────────────────────────────────
  Widget _card({
    required IconData icon,
    required String title,
    required Widget child,
    Color iconBg = const Color(0xFFEEEDFE),
    Color iconColor = _T.primary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _T.line),
        boxShadow: const [
          BoxShadow(color: _T.shadow, blurRadius: 24, offset: Offset(0, 8))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Icon(icon, color: iconColor, size: 18)),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: _T.navy)),
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }
}