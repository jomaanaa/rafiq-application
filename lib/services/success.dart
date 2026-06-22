import 'package:flutter/material.dart';
import 'package:rafiq/auth/api_service.dart';
import 'package:rafiq/auth/session_manager.dart';

// ---------------------------------------------------------------------------
// Design tokens — shared with payment_screen.dart
// ---------------------------------------------------------------------------
const Color _kNavy      = Color(0xFF292B4A);
const Color _kPurple    = Color(0xFF353B69);
const Color _kAccent    = Color(0xFF6470D2);
const Color _kAccentBg  = Color(0xFFEEF0FF);
const Color _kInk       = Color(0xFF23243A);
const Color _kMuted     = Color(0xFF8B91A6);
const Color _kBg        = Color(0xFFF5F6FF);
const Color _kGreen     = Color(0xFF168653);
const Color _kGreenBg   = Color(0xFFEEFBF4);
const Color _kGreenText = Color(0xFF12643E);
const Color _kAmber     = Color(0xFFF4B400);
const Color _kCardBg    = Color(0xFFF8F8FF);
const Color _kLine      = Color(0xFFE4E6F5);

// ---------------------------------------------------------------------------
// SuccessScreen — handles both service bookings and product orders
// ---------------------------------------------------------------------------
class SuccessScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  const SuccessScreen({super.key, required this.bookingData});

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  bool _cancelling = false;

  bool get _isProductOrder =>
      widget.bookingData['service_type'] == 'Product Order';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.2, 1.0, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Same fallback chain as payment_screen.dart — handles doctors, caregivers,
  /// interpreters, and any other service type.
  String _resolveProviderName() {
    final d = widget.bookingData;
    final fullName = d['doctor_name'] ?? d['provider_name'] ?? d['name'];
    if (fullName != null && fullName.toString().trim().isNotEmpty) {
      return fullName.toString().trim();
    }
    final first = (d['first_name'] ?? '').toString().trim();
    final last  = (d['last_name']  ?? '').toString().trim();
    if (first.isNotEmpty || last.isNotEmpty) {
      return '$first $last'.trim();
    }
    final legacy = d['caregiver_name']?.toString().trim() ?? '';
    if (legacy.isNotEmpty) return legacy;
    return 'Service Provider';
  }

  String _serviceType() =>
      widget.bookingData['service_type']?.toString() ?? 'Service';

  /// Returns the Material icon matching the service type —
  /// mirrors _iconForService in payment_screen.dart and ServicesScreen.
  IconData _iconForService([String? override]) {
    final s = (override ?? _serviceType()).toLowerCase();
    if (s.contains('doctor') || s.contains('medical') || s.contains('physio')) {
      return Icons.medical_services_outlined;
    }
    if (s.contains('caregiver') || s.contains('care') || s.contains('nurse')) {
      return Icons.favorite_border_rounded;
    }
    if (s.contains('driver') || s.contains('transport') || s.contains('car')) {
      return Icons.directions_car_outlined;
    }
    if (s.contains('interpreter') || s.contains('sign') || s.contains('language')) {
      return Icons.record_voice_over_outlined;
    }
    if (s.contains('product') || s.contains('order')) {
      return Icons.inventory_2_outlined;
    }
    return Icons.medical_services_outlined;
  }

  String _formatTime(String? t) {
    if (t == null || !t.contains(':')) return t ?? '';
    try {
      final p = t.split(':');
      int h = int.parse(p[0]), m = int.parse(p[1]);
      final period = h >= 12 ? 'PM' : 'AM';
      h = h % 12 == 0 ? 12 : h % 12;
      return '$h:${m.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return t;
    }
  }

  /// `service_time` is the slot END time (e.g. "17:00:00"), not a duration.
  /// We compute the actual duration by subtracting booking_time from service_time.
  String _computeDuration() {
    final startRaw = widget.bookingData['booking_time']?.toString();
    final endRaw   = widget.bookingData['service_time']?.toString();
    if (startRaw == null || endRaw == null) return '1 Hour';
    try {
      final sParts = startRaw.split(':');
      final eParts = endRaw.split(':');
      final startMins = int.parse(sParts[0]) * 60 + int.parse(sParts[1]);
      final endMins   = int.parse(eParts[0]) * 60 + int.parse(eParts[1]);
      final diff      = endMins - startMins;
      if (diff <= 0) return '1 Hour';
      final h = diff ~/ 60;
      final m = diff % 60;
      if (h == 0) return '$m ${m == 1 ? 'Minute' : 'Minutes'}';
      if (m == 0) return '$h ${h == 1 ? 'Hour' : 'Hours'}';
      return '${h}h ${m}m';
    } catch (_) {
      return '1 Hour';
    }
  }

  Future<void> _cancelBooking() async {
      // ── 1. Validate booking ID ───────────────────────────────────────────────
      final bookingId = int.tryParse(
          widget.bookingData['booking_id']?.toString() ?? '0') ?? 0;
      if (bookingId == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No booking ID found — cannot cancel.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }

      // ── 2. Confirm ───────────────────────────────────────────────────────────
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Cancel Request?',
              style: TextStyle(fontWeight: FontWeight.w900, color: _kNavy)),
          content: const Text(
              'Are you sure you want to cancel this booking? This cannot be undone.',
              style: TextStyle(color: _kMuted)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep it')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes, cancel',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800))),
          ],
        ),
      );
      if (confirm != true || !mounted) return;

      setState(() => _cancelling = true);

      // ── 3. Resolve patient ID — bookingData first, session as fallback ───────
      int patientId = int.tryParse(
          widget.bookingData['patient_id']?.toString() ?? '0') ?? 0;
      if (patientId == 0) {
        final session = await SessionManager.getUser();
        patientId = int.tryParse(
            (session?['user_id'] ?? session?['id'])?.toString() ?? '0') ?? 0;
      }

      // ── 4. Call API ──────────────────────────────────────────────────────────
      final ok = await ApiService.cancelBooking(
          bookingId: bookingId, patientId: patientId);

      if (!mounted) return;
      setState(() => _cancelling = false);

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Booking cancelled successfully',
              style: TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not cancel — booking may already be in progress.',
              style: TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: FadeTransition(
            opacity: _fade,
            child: _isProductOrder
                ? _buildProductContent()
                : _buildBookingContent(),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRODUCT ORDER CONTENT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildProductContent() {
    final items  = widget.bookingData['items'] as List? ?? [];
    final total  = widget.bookingData['payment_total']?.toString() ?? '0';
    final method = widget.bookingData['payment_method']?.toString().toLowerCase() ?? '';
    final addr   = widget.bookingData['address']?.toString() ?? '';
    final phone  = widget.bookingData['phone']?.toString() ?? '';
    final name   = widget.bookingData['full_name']?.toString() ?? '';
    final date   = widget.bookingData['date']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProductHero(),
        const SizedBox(height: 18),
        _buildProductCelebration(),
        const SizedBox(height: 14),

        // Order items card
        if (items.isNotEmpty)
          _card(
            icon: Icons.shopping_bag_outlined,
            title: 'Items Ordered',
            child: Column(
              children: items.map<Widget>((item) {
                final title = item['title']?.toString() ?? '';
                final qty   = item['qty']?.toString() ?? '1';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: _kAccentBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.inventory_2_outlined,
                            size: 18, color: _kAccent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800, color: _kInk)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _kAccentBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('× $qty',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w900, color: _kAccent)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

        const SizedBox(height: 14),

        // Delivery info card
        _card(
          icon: Icons.local_shipping_outlined,
          title: 'Delivery Details',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _detailCell('Name',  name.isNotEmpty  ? name  : '—', icon: Icons.person_outline_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _detailCell('Phone', phone.isNotEmpty ? phone : '—', icon: Icons.phone_outlined)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _detailCell('Date',   date.isNotEmpty ? date : '—', icon: Icons.calendar_today_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _detailCell('Status', 'Processing',                  icon: Icons.pending_outlined)),
                ],
              ),
              if (addr.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: _kCardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kAccent.withOpacity(0.1)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(Icons.location_on_outlined,
                            size: 13, color: _kAccent.withOpacity(0.7)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ADDRESS',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                                    color: _kMuted, letterSpacing: 0.7)),
                            const SizedBox(height: 3),
                            Text(addr,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w900,
                                    color: Color(0xFF30324C))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Payment card
        _buildPaymentCard(),

        const SizedBox(height: 14),

        // Delivery timeline
        _card(
          icon: Icons.map_outlined,
          title: 'What happens next',
          child: Column(
            children: [
              _timelineStep(Icons.check_circle_outline_rounded, 'Order confirmed',
                  'Your order has been received',      true,  false, false),
              _timelineStep(Icons.inventory_2_outlined, 'Preparing order',
                  'We are getting your items ready',   false, true,  false),
              _timelineStep(Icons.local_shipping_outlined, 'Out for delivery',
                  'Your order is on its way',          false, false, false),
              _timelineStep(Icons.celebration_outlined, 'Delivered',
                  'Enjoy your product!',               false, false, true),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _buildDoneButton(),
      ],
    );
  }

  Widget _buildProductHero() {
    final bookingId = widget.bookingData['booking_id']?.toString() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kPurple, _kAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: _kPurple.withOpacity(0.32), blurRadius: 30, offset: const Offset(0, 12)),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -40, bottom: -60,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.white.withOpacity(0.1), Colors.transparent,
                ]),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 66, height: 66,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.22)),
                    ),
                    child: const Icon(Icons.inventory_2_outlined,
                        size: 30, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bookingId.isNotEmpty ? 'Order #$bookingId' : 'New Order',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                              color: Colors.white.withOpacity(0.78), letterSpacing: 0.6),
                        ),
                        const SizedBox(height: 4),
                        const Text('Order Placed Successfully',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                                color: Colors.white, height: 1.15)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.22)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        size: 20, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Order placed successfully!',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                          SizedBox(height: 2),
                          Text("We'll contact you to confirm delivery.",
                              style: TextStyle(fontSize: 12, color: Colors.white70,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductCelebration() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kGreenBg, Color(0xFFF0FBF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _kGreen.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: _kGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.celebration_outlined, size: 32, color: _kGreen),
          ),
          const SizedBox(height: 12),
          const Text('Thank you for your order!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _kGreenText)),
          const SizedBox(height: 5),
          const Text(
            'Your items will be delivered soon.\nOur team will contact you to confirm.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: Color(0xFF4D8064), height: 1.5),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SERVICE BOOKING CONTENT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBookingContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHero(),
        const SizedBox(height: 18),
        _buildCelebrationCard(),
        const SizedBox(height: 18),
        _buildProviderCard(),
        const SizedBox(height: 14),
        _buildDetailsCard(),
        const SizedBox(height: 14),
        _buildPaymentCard(),
        const SizedBox(height: 14),
        _buildTimelineCard(),
        const SizedBox(height: 24),
        _buildDoneButton(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHero() {
    final bookingId   = widget.bookingData['booking_id']?.toString() ?? '';
    final serviceType = _serviceType();
    final icon        = _iconForService();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kPurple, _kAccent],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: _kPurple.withOpacity(0.32), blurRadius: 30,
              offset: const Offset(0, 12)),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -40, bottom: -60,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.white.withOpacity(0.1), Colors.transparent,
                ]),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 66, height: 66,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.22)),
                    ),
                    child: Icon(icon, size: 30, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bookingId.isNotEmpty
                              ? 'Booking #$bookingId'
                              : 'New Booking',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                              color: Colors.white.withOpacity(0.78),
                              letterSpacing: 0.6),
                        ),
                        const SizedBox(height: 4),
                        Text('$serviceType Request Submitted',
                            style: const TextStyle(fontSize: 24,
                                fontWeight: FontWeight.w900, color: Colors.white,
                                height: 1.1)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.22)),
                ),
                child: Row(
                  children: [
                    _PulseDot(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Waiting for your provider to accept',
                              style: TextStyle(fontSize: 14,
                                  fontWeight: FontWeight.w900, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text('Your request is live and visible.',
                              style: TextStyle(fontSize: 12,
                                  color: Colors.white.withOpacity(0.82),
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCelebrationCard() {
    final providerName = _resolveProviderName();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kGreenBg, Color(0xFFF0FBF5)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _kGreen.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: _kGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                size: 32, color: _kGreen),
          ),
          const SizedBox(height: 12),
          const Text('Request Confirmed!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                  color: _kGreenText)),
          const SizedBox(height: 5),
          Text(
            'Your session with $providerName has been successfully scheduled.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: Color(0xFF4D8064), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard() {
    final name         = _resolveProviderName();
    final photo        = widget.bookingData['provider_photo']?.toString() ?? '';
    final avatarLetter = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    return _card(
      icon: Icons.person_outline_rounded,
      title: 'Provider',
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                  colors: [_kNavy, _kPurple],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: photo.isNotEmpty
                  ? Image.network(photo, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(avatarLetter,
                            style: const TextStyle(color: Colors.white,
                                fontSize: 20, fontWeight: FontWeight.w900))))
                  : Center(
                      child: Text(avatarLetter,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 20, fontWeight: FontWeight.w900))),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                      color: Color(0xFF25263E))),
              const SizedBox(height: 5),
              // Service type pill with icon — matches payment_screen.dart
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _kAccentBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _kAccent.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_iconForService(), size: 12, color: _kAccent),
                    const SizedBox(width: 5),
                    Text(_serviceType(),
                        style: const TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w900, color: _kAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    final bookingId   = widget.bookingData['booking_id']?.toString() ?? '';
    final date        = widget.bookingData['date']?.toString() ?? 'Today';
    final startTime   = widget.bookingData['booking_time']?.toString();
    final address     = widget.bookingData['address']?.toString() ?? '';
    final destination = widget.bookingData['destination']?.toString() ?? '';
    final cells = <_MetaEntry>[
      _MetaEntry('Booking ID', bookingId.isNotEmpty ? '#$bookingId' : 'Pending',
          Icons.tag_rounded),
      _MetaEntry('Service',    _serviceType(),
          _iconForService()),
      _MetaEntry('Date',       date,
          Icons.calendar_today_rounded),
      _MetaEntry('Time',       _formatTime(startTime),
          Icons.schedule_rounded),
      _MetaEntry('Duration',   _computeDuration(),
          Icons.timer_outlined),
      _MetaEntry('Status',     'Pending',
          Icons.info_outline_rounded),
      if (address.isNotEmpty)
        _MetaEntry('Address',     address,     Icons.location_on_outlined),
      if (destination.isNotEmpty)
        _MetaEntry('Destination', destination, Icons.flag_outlined),
    ];
    return _card(
      icon: Icons.receipt_long_outlined,
      title: 'Booking Details',
      child: Column(
        children: [
          for (int i = 0; i < cells.length; i += 2)
            Padding(
              padding: EdgeInsets.only(bottom: i + 2 < cells.length ? 10 : 0),
              child: Row(
                children: [
                  Expanded(child: _detailCell(cells[i].label,   cells[i].value,   icon: cells[i].icon)),
                  if (i + 1 < cells.length) ...[
                    const SizedBox(width: 10),
                    Expanded(child: _detailCell(cells[i + 1].label, cells[i + 1].value, icon: cells[i + 1].icon)),
                  ] else
                    const Expanded(child: SizedBox()),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    final total       = widget.bookingData['payment_total']?.toString() ?? '0';
    final method      = widget.bookingData['payment_method']?.toString().toLowerCase() ?? '';
    final methodLabel = method == 'cash' ? 'Cash' : method == 'visa' ? 'Card' : 'Pending';
    final methodIcon  = method == 'cash'
        ? Icons.payments_rounded
        : Icons.credit_card_rounded;
    final Color methodColor = method == 'cash' ? _kGreen : _kAccent;
    final Color methodBg    = method == 'cash' ? _kGreenBg : _kAccentBg;

    return _card(
      icon: Icons.credit_card_rounded,
      title: 'Payment',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TOTAL AMOUNT',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                      color: _kMuted, letterSpacing: 0.6)),
              const SizedBox(height: 5),
              Text('$total EGP',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
                      color: Color(0xFF20213B), letterSpacing: -0.5)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: methodBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: methodColor.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(methodIcon, size: 16, color: methodColor),
                const SizedBox(width: 6),
                Text(methodLabel,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                        color: methodColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard() {
    return _card(
      icon: Icons.map_outlined,
      title: 'What happens next',
      child: Column(
        children: [
          _timelineStep(Icons.check_circle_outline_rounded, 'Booking confirmed',
              'Your request has been sent',            true,  false, false),
          _timelineStep(Icons.search_rounded,              'Provider reviewing',
              'A provider is looking at your request', false, true,  false),
          _timelineStep(Icons.handshake_outlined,          'Provider accepted',
              'Your provider is on the way',           false, false, false),
          _timelineStep(Icons.star_outline_rounded,        'Service completed',
              'Enjoy rating your experience',          false, false, true),
        ],
      ),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  Widget _timelineStep(IconData icon, String title, String sub,
      bool done, bool active, bool isLast) {
    final Color ringColor = done
        ? _kGreen
        : active
            ? _kAccent
            : const Color(0xFFE2E8F0);
    final Color bgColor = done
        ? _kGreenBg
        : active
            ? _kAccentBg
            : const Color(0xFFF1F5F9);
    final Color iconColor = done
        ? _kGreen
        : active
            ? _kAccent
            : const Color(0xFFBFC5D6);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          child: Column(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bgColor,
                  border: Border.all(color: ringColor.withOpacity(0.35), width: 2),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              if (!isLast)
                Container(width: 2, height: 28, color: _kAccent.withOpacity(0.2)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 6, bottom: isLast ? 0 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                        color: Color(0xFF30324C))),
                const SizedBox(height: 2),
                Text(sub,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: _kMuted)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailCell(String label, String value, {required IconData icon}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kAccent.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 12, color: _kAccent.withOpacity(0.65)),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label.toUpperCase(),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                        color: _kMuted, letterSpacing: 0.7)),
                const SizedBox(height: 3),
                Text(value,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                        color: Color(0xFF30324C))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneButton() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_kPurple, _kAccent],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: _kPurple.withOpacity(0.28), blurRadius: 18,
                    offset: const Offset(0, 6)),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check_rounded, size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text('Done',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
        if (!_isProductOrder) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _cancelling ? null : _cancelBooking,
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withOpacity(0.35)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
                ],
              ),
              alignment: Alignment.center,
              child: _cancelling
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.cancel_outlined, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Text('Cancel Request',
                            style: TextStyle(color: Colors.red,
                                fontWeight: FontWeight.w800, fontSize: 14)),
                      ],
                    ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _kAccent.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: _kAccentBg, borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, size: 17, color: _kAccent),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                      color: Color(0xFF20213B))),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pulse dot (unchanged)
// ---------------------------------------------------------------------------
class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _scale   = Tween(begin: 1.0, end: 1.7).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _opacity = Tween(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Opacity(
          opacity: _opacity.value,
          child: Container(
            width: 10, height: 10,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------
class _MetaEntry {
  final String label, value;
  final IconData icon;
  const _MetaEntry(this.label, this.value, this.icon);
}

// ---------------------------------------------------------------------------
// ReceiptDivider / DashPainter kept for backward compat
// ---------------------------------------------------------------------------
class ReceiptDivider extends StatelessWidget {
  final double height;
  final List<int>? dashArray;
  const ReceiptDivider({super.key, this.height = 1, this.dashArray});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      color: dashArray == null ? Colors.grey.shade100 : Colors.transparent,
      child: dashArray != null ? CustomPaint(painter: DashPainter()) : null,
    );
  }
}

class DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + 5, 0), paint);
      x += 8;
    }
  }

  @override
  bool shouldRepaint(CustomPainter _) => false;
}