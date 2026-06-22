// lib/screens/doctor_sessions_screen.dart
import 'package:flutter/material.dart';
import '../auth/api_service.dart';
import '../auth/session_manager.dart';
import 'dart:async';

class DoctorSessionsScreen extends StatefulWidget {
  const DoctorSessionsScreen({super.key});
  @override
  State<DoctorSessionsScreen> createState() => _DoctorSessionsScreenState();
}

class _DoctorSessionsScreenState extends State<DoctorSessionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List _active = []; List _completed = [];
  bool _loadingA = true; bool _loadingC = true;
  Timer? _countdownTimer;
  final _scrollController = ScrollController();

  static const kPrimary = Color(0xFF4B4F83);
  static const kAccent  = Color(0xFF6470D2);
  static const kDark    = Color(0xFF242742);
  static const kMuted   = Color(0xFF6B7188);
  static const kGreen   = Color(0xff1F9D5A);
  static const kBg      = Color(0xFFF6F8FD);
  static const kBg2     = Color(0xFFF1F4FB);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _init();
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _countdownTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final id = await SessionManager.getUserId();
    if (id == null) { setState(() { _loadingA = false; _loadingC = false; }); return; }
    await Future.wait([_loadActive(id), _loadCompleted(id)]);
  }

  Future<void> _loadActive(int id) async {
    setState(() => _loadingA = true);
    try {
      final d = await ApiService.getDoctorSessions(id);
      if (mounted) {
        setState(() { _active = d ?? []; _loadingA = false; });
        _checkForCancelledBookings();
      }
    } catch (_) { if (mounted) setState(() => _loadingA = false); }
  }

  void _checkForCancelledBookings() {
    setState(() {
      _active = _active.where((b) =>
        (b['status'] ?? '').toString().toLowerCase() != 'cancelled'
      ).toList();
    });
  }

  Future<void> _loadCompleted(int id) async {
    setState(() => _loadingC = true);
    try { final d = await ApiService.getCompletedDoctorSessions(id); if (mounted) setState(() { _completed = d ?? []; _loadingC = false; }); }
    catch (_) { if (mounted) setState(() => _loadingC = false); }
  }

  Future<void> _refreshAll() async {
    final id = await SessionManager.getUserId();
    if (id == null) return;
    await Future.wait([_loadActive(id), _loadCompleted(id)]);
  }

  Future<void> _updateStatus(int bookingId, String status) async {
    final offset = _scrollController.offset;
    try {
      await ApiService.updateBookingStatus(bookingId, status);
      _snack(_statusMsg(status), _statusColor(status));
      final id = await SessionManager.getUserId();
      if (id != null) { await _loadActive(id); if (status == 'completed') await _loadCompleted(id); }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) _scrollController.jumpTo(offset);
      });
    } catch (_) { _snack('Something went wrong', Colors.red); }
  }

  void _snack(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: c, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _statusMsg(String s) {
    switch (s) {
      case 'arrived':   return 'Marked as Arrived!';
      case 'in_visit':  return 'Visit started!';
      case 'completed': return 'Visit completed!';
      default:          return 'Status updated.';
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'arrived':   return kPrimary;
      case 'in_visit':  return kAccent;
      case 'completed': return kGreen;
      default:          return kPrimary;
    }
  }

  String _fmtDate(String? d) {
    if (d == null || d.isEmpty) return '—';
    try { final dt = DateTime.parse(d); const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']; return '${dt.day} ${m[dt.month - 1]} ${dt.year}'; }
    catch (_) { return d; }
  }

  String _fmtTime(String? t) {
    if (t == null || t.isEmpty) return '—';
    final p = t.split(':'); if (p.length < 2) return t;
    int h = int.tryParse(p[0]) ?? 0;
    final mn = p[1].padLeft(2, '0');
    final pm = h >= 12 ? 'PM' : 'AM';
    h = h % 12; if (h == 0) h = 12;
    return '$h:$mn $pm';
  }

  String _name(Map r) {
    final n = '${r["first_name"] ?? ""} ${r["last_name"] ?? ""}'.trim();
    return n.isNotEmpty ? n : 'Patient';
  }

  Map<String, dynamic> _statusStyle(String s) {
    switch (s) {
      case 'accepted': return {'bg': const Color(0xffEEFAF3), 'text': const Color(0xff137043), 'label': 'Accepted'};
      case 'arrived':  return {'bg': const Color(0xFFEEF2FF), 'text': kPrimary,                'label': 'Arrived'};
      case 'in_visit': return {'bg': const Color(0xFFEEF2FF), 'text': kAccent,                 'label': 'In Visit'};
      default:         return {'bg': const Color(0xFFF1F4FB), 'text': kMuted,                   'label': s};
    }
  }

  DateTime? _parseScheduled(Map r) {
    final dateStr = r['date']?.toString() ?? '';
    final timeStr = (r['service_time'] ?? r['booking_time'])?.toString() ?? '';
    if (dateStr.isEmpty || timeStr.isEmpty) return null;
    try { return DateTime.parse('${dateStr.substring(0, 10)} $timeStr'); }
    catch (_) { return null; }
  }

  bool _isActionable(Map r) {
    final scheduled = _parseScheduled(r);
    if (scheduled == null) return true;
    return DateTime.now().isAfter(scheduled.subtract(const Duration(hours: 1)));
  }

  String _countdownText(Map r) {
    final scheduled = _parseScheduled(r);
    if (scheduled == null) return '';
    final diff = scheduled.difference(DateTime.now());
    if (diff.inDays > 0) return 'Session starts in ${diff.inDays} day${diff.inDays > 1 ? "s" : ""}';
    if (diff.inHours > 0) return 'Session starts in ${diff.inHours}h ${diff.inMinutes % 60}m';
    return 'Session starts in ${diff.inMinutes} minute${diff.inMinutes != 1 ? "s" : ""}';
  }

  Widget _scheduleBadge(Map r) {
    final scheduled = _parseScheduled(r);
    if (scheduled == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final schedDay = DateTime(scheduled.year, scheduled.month, scheduled.day);
    if (_isActionable(r)) return _badge('Now', Icons.circle, const Color(0xff137043), const Color(0xffEEFAF3));
    if (schedDay.isAtSameMomentAs(today)) return _badge('Scheduled Today', Icons.schedule_rounded, const Color(0xffB45309), const Color(0xffFFFBEB));
    return _badge('Scheduled', Icons.calendar_today_rounded, kPrimary, const Color(0xFFEEF2FF));
  }

  Widget _badge(String label, IconData icon, Color textColor, Color bgColor) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(999), border: Border.all(color: textColor.withOpacity(0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 9, color: textColor),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: textColor)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kBg, kBg2]),
      ),
      child: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            const Text('Visits', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kDark)),
            const SizedBox(height: 4),
            const Text('Manage your patient visits', style: TextStyle(fontSize: 13, color: kMuted, fontWeight: FontWeight.w600)),
          ]),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
          ),
          child: TabBar(
            controller: _tab,
            labelColor: Colors.white, unselectedLabelColor: kMuted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            indicator: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF353B69), Color(0xFF6470D2)]),
              borderRadius: BorderRadius.circular(12),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Active'),
                if (_active.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(999)),
                    child: Text('${_active.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                ],
              ])),
              const Tab(text: 'Completed'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(child: TabBarView(controller: _tab, children: [
          _loadingA
              ? const Center(child: CircularProgressIndicator(color: kPrimary))
              : _active.isEmpty ? _emptyState('No active visits', 'Accepted visits appear here', Icons.calendar_today_rounded)
              : RefreshIndicator(onRefresh: _refreshAll, color: kPrimary,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                    itemCount: _active.length, itemBuilder: (_, i) => _activeCard(_active[i]))),
          _loadingC
              ? const Center(child: CircularProgressIndicator(color: kPrimary))
              : _completed.isEmpty ? _emptyState('No completed visits', 'Finished visits appear here', Icons.check_circle_outline_rounded)
              : RefreshIndicator(onRefresh: _refreshAll, color: kPrimary,
                  child: ListView.builder(padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                    itemCount: _completed.length, itemBuilder: (_, i) => _completedCard(_completed[i]))),
        ])),
      ])),
    );
  }

  Widget _activeCard(Map r) {
    final status = (r['status'] ?? 'accepted').toString().toLowerCase();
    final gross  = double.tryParse(r['payment_total']?.toString() ?? '0') ?? 0;
    final net    = gross * 0.85;
    final phone  = r['phone']?.toString() ?? '—';
    final bid    = int.tryParse(r['booking_id']?.toString() ?? '0') ?? 0;
    final sd     = _statusStyle(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: kPrimary.withOpacity(0.07), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: sd['bg'] as Color, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Booking #${r["booking_id"]}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: sd['text'] as Color)),
            Row(children: [
              _scheduleBadge(r),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: (sd['text'] as Color).withOpacity(0.12), borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: (sd['text'] as Color).withOpacity(0.25))),
                child: Text(sd['label'] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: sd['text'] as Color)),
              ),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF4B4F83), Color(0xFF6470D2)]), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_name(r), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kDark)),
                Text(phone, style: const TextStyle(fontSize: 13, color: kMuted, fontWeight: FontWeight.w600)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: kGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text('${net.toStringAsFixed(2)} EGP', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kGreen))),
            ]),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE8EBF5)),
            const SizedBox(height: 12),
            _row(Icons.location_on_rounded,    r['address']?.toString() ?? '—'),
            _row(Icons.calendar_today_rounded, _fmtDate(r['date']?.toString())),
            _row(Icons.access_time_rounded,    _fmtTime(r['booking_time']?.toString())),
            _row(Icons.payment_rounded,        'Payment: ${r["payment_method"] ?? "—"}'),
            _row(Icons.attach_money_rounded,   'Total: ${r["payment_total"] ?? "—"} EGP'),
            const SizedBox(height: 14),
            if (!_isActionable(r)) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xffFCD34D).withOpacity(0.5)),
                ),
                child: Row(children: [
                  const Icon(Icons.access_time_rounded, color: Color(0xffB45309), size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_countdownText(r),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xffB45309)))),
                ]),
              ),
              const SizedBox(height: 8),
            ],
            if (_isActionable(r)) ...[
              if (status == 'accepted')
                _btn('Mark Arrived', kPrimary, () => _updateStatus(bid, 'arrived'), icon: Icons.location_on_rounded),
              if (status == 'accepted' || status == 'arrived') ...[
                if (status == 'accepted') const SizedBox(height: 8),
                _btn('Start Visit', kAccent, () => _updateStatus(bid, 'in_visit'), icon: Icons.play_arrow_rounded),
              ],
              if (status == 'in_visit')
                _btn('Complete Visit', kGreen, () => _confirmComplete(bid), icon: Icons.check_circle_rounded),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _completedCard(Map r) {
    final gross  = double.tryParse(r['payment_total']?.toString() ?? '0') ?? 0;
    final net    = gross * 0.85;

    return Container(
      margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: kPrimary.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))]),
      child: Column(children: [
        Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: kGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.check_circle_rounded, color: kGreen, size: 24)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_name(r), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kDark)),
            Text(_fmtDate(r['date']?.toString()), style: const TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w600)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('+${net.toStringAsFixed(2)} EGP', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kGreen)),
            Text('of ${gross.toStringAsFixed(2)} EGP', style: const TextStyle(fontSize: 11, color: kMuted, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ]),
    );
  }

  Widget _row(IconData icon, String val) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(icon, size: 15, color: kMuted),
      const SizedBox(width: 8),
      Expanded(child: Text(val, style: const TextStyle(fontSize: 13, color: kPrimary, fontWeight: FontWeight.w700))),
    ]),
  );

  Widget _btn(String label, Color color, VoidCallback onTap, {IconData? icon}) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 13),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 8)],
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
      ])),
    ),
  );

  void _confirmComplete(int bookingId) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Complete Visit?', style: TextStyle(fontWeight: FontWeight.w900, color: kDark)),
      content: const Text('This will mark the visit as completed and add earnings to your wallet.', style: TextStyle(color: kMuted, fontWeight: FontWeight.w600)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () { Navigator.pop(context); _updateStatus(bookingId, 'completed'); },
          child: const Text('Complete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      ],
    ));
  }

  Widget _emptyState(String title, String sub, IconData icon) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(color: kPrimary.withOpacity(0.06), shape: BoxShape.circle),
        child: Icon(icon, size: 48, color: kMuted)),
      const SizedBox(height: 18),
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kDark)),
      const SizedBox(height: 6),
      Text(sub, style: const TextStyle(fontSize: 13, color: kMuted, fontWeight: FontWeight.w600)),
    ]),
  );
}