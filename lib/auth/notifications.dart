import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'session_manager.dart';

// ── Design tokens (matched from doctor_homepage + request_driver_screen) ──────
const _kPrimary  = Color(0xFF2D2D5A);
const _kAccent   = Color(0xFF6470D2);
const _kDark     = Color(0xFF242742);
const _kMuted    = Color(0xFF6B7188);
const _kBg       = Color(0xFFF6F8FD);
const _kBg2      = Color(0xFFF1F4FB);
const _kLine     = Color(0xFFE8EBF5);
const _kCard     = Color(0xFFFFFFFF);
const _kSoft     = Color(0xFFEEEDFE);
const _kGreen    = Color(0xFF16A34A);
const _kGreenBg  = Color(0xFFEEFBF3);
const _kAmber    = Color(0xFFB45309);
const _kAmberBg  = Color(0xFFFFFBEB);
const _kRed      = Color(0xFFB53535);
const _kRedBg    = Color(0xFFFDECEC);
const _kTeal     = Color(0xFF0F766E);
const _kTealBg   = Color(0xFFEFFEFD);
const _kBlue     = Color(0xFF1D4ED8);
const _kBlueBg   = Color(0xFFEFF6FF);

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with TickerProviderStateMixin {
  List   _requests = [];
  bool   _loading  = true;

  // Staggered entry animations — one controller per card, created after load
  final List<AnimationController> _cardAnims = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void dispose() {
    for (final c in _cardAnims) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      final patientId = await SessionManager.getUserId();
      if (patientId == null) { setState(() => _loading = false); return; }
      final data = await ApiService.getPatientNotifications(patientId);
      if (!mounted) return;

      // Build one AnimationController per item
      for (final c in _cardAnims) { c.dispose(); }
      _cardAnims.clear();
      for (int i = 0; i < (data as List).length; i++) {
        final ctrl = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 420),
        );
        _cardAnims.add(ctrl);
        // Stagger: each card starts 60 ms after the previous
        Future.delayed(Duration(milliseconds: 80 + i * 60), () {
          if (mounted) ctrl.forward();
        });
      }

      setState(() { _requests = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Status helpers ──────────────────────────────────────────────────────────
  String _normalize(String raw) {
    final s = raw.toLowerCase();
    if (s == 'accepted')                    return 'Accepted';
    if (s == 'arrived')                     return 'Arrived';
    if (s == 'in_progress' || s == 'in_trip') return 'In Progress';
    if (s == 'completed')                   return 'Completed';
    if (s == 'declined' || s == 'rejected') return 'Declined';
    if (s == 'cancelled')                   return 'Cancelled';
    return 'Pending';
  }

  _StatusStyle _style(String status) {
    switch (status) {
      case 'Accepted':    return _StatusStyle(icon: Icons.check_circle_rounded,      color: _kGreen,  bg: _kGreenBg);
      case 'Arrived':     return _StatusStyle(icon: Icons.location_on_rounded,        color: _kBlue,   bg: _kBlueBg);
      case 'In Progress': return _StatusStyle(icon: Icons.moving_rounded,             color: _kPrimary, bg: _kSoft);
      case 'Completed':   return _StatusStyle(icon: Icons.check_circle_rounded,       color: _kTeal,   bg: _kTealBg);
      case 'Declined':    return _StatusStyle(icon: Icons.cancel_rounded,             color: _kRed,    bg: _kRedBg);
      case 'Cancelled':   return _StatusStyle(icon: Icons.cancel_outlined,            color: _kRed,    bg: _kRedBg);
      default:            return _StatusStyle(icon: Icons.access_time_rounded,        color: _kAmber,  bg: _kAmberBg);
    }
  }

  // ── Format helpers ──────────────────────────────────────────────────────────
  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final d = DateTime.parse(raw);
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${m[d.month - 1]} ${d.year}';
    } catch (_) { return raw; }
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final parts = raw.split(':');
      int h = int.parse(parts[0]);
      final period = h >= 12 ? 'PM' : 'AM';
      h = h % 12; if (h == 0) h = 12;
      return '$h:${parts[1]} $period';
    } catch (_) { return raw; }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kBg, _kBg2],
            stops: [0.0, 0.8],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kLine),
                boxShadow: [
                  BoxShadow(
                      color: _kPrimary.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: _kPrimary, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          // Title pill
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kLine),
                boxShadow: [
                  BoxShadow(
                      color: _kPrimary.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Row(children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_kPrimary, _kAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.notifications_rounded,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Notifications',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: _kPrimary)),
                  if (!_loading)
                    Text(
                      _requests.isEmpty
                          ? 'All caught up'
                          : '${_requests.length} update${_requests.length == 1 ? "" : "s"}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _kMuted),
                    ),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Body ─────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2.5),
      );
    }

    if (_requests.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: _kSoft,
              shape: BoxShape.circle,
              border: Border.all(color: _kAccent.withOpacity(0.2), width: 2),
            ),
            child: const Icon(Icons.notifications_off_rounded,
                color: _kAccent, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('No notifications yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _kPrimary)),
          const SizedBox(height: 6),
          const Text('Your booking updates will appear here.',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _kMuted)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: _kPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        itemCount: _requests.length,
        itemBuilder: (_, i) {
          final ctrl = i < _cardAnims.length ? _cardAnims[i] : null;
          final slide = ctrl == null
              ? null
              : Tween<Offset>(
                      begin: const Offset(0, 0.12), end: Offset.zero)
                  .animate(CurvedAnimation(
                      parent: ctrl, curve: Curves.easeOutCubic));
          final fade = ctrl == null
              ? null
              : CurvedAnimation(parent: ctrl, curve: Curves.easeOut);

          Widget card = _buildCard(_requests[i]);

          if (slide != null && fade != null) {
            card = FadeTransition(
              opacity: fade,
              child: SlideTransition(position: slide, child: card),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: card,
          );
        },
      ),
    );
  }

  // ── Notification card ─────────────────────────────────────────────────────
  Widget _buildCard(Map r) {
    final status = _normalize(r['status']?.toString() ?? 'Pending');
    final st     = _style(status);
    final name   = '${r["first_name"] ?? ""} ${r["last_name"] ?? ""}'.trim();
    final service = r['service_type']?.toString() ?? 'Service';
    final date    = _formatDate(r['date']?.toString());
    final time    = _formatTime(r['booking_time']?.toString());
    final total   = r['payment_total']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kLine),
        boxShadow: [
          BoxShadow(
              color: _kPrimary.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Coloured top strip ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: st.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border(bottom: BorderSide(color: _kLine)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Status pill
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: st.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(st.icon, color: st.color, size: 16),
                ),
                const SizedBox(width: 8),
                Text(status,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: st.color)),
              ]),
              // Service type pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _kAccent.withOpacity(0.2)),
                ),
                child: Text(service,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: _kAccent)),
              ),
            ],
          ),
        ),

        // ── Body ──
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar initial
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_kPrimary, _kAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      name.isNotEmpty ? name : 'Unknown',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: _kDark),
                    ),
                    const SizedBox(height: 10),

                    // Date / Time chips
                    Row(children: [
                      _chip(Icons.calendar_today_rounded, date),
                      const SizedBox(width: 8),
                      _chip(Icons.access_time_rounded, time),
                    ]),

                    if (total != null && total.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _chip(Icons.payments_rounded, '$total EGP',
                          color: _kGreen, bg: _kGreenBg),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _chip(IconData icon, String label,
      {Color color = _kMuted, Color bg = _kBg2}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kLine),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

// ── Status style data ──────────────────────────────────────────────────────────
class _StatusStyle {
  final IconData icon;
  final Color    color;
  final Color    bg;
  const _StatusStyle({required this.icon, required this.color, required this.bg});
}