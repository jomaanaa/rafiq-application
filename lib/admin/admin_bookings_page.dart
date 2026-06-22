// ============================================================
// lib/admin/admin_bookings_page.dart
// ============================================================
import 'package:flutter/material.dart';
import 'admin_api_service.dart';
import 'admin_helpers.dart';

class AdminBookingsPage extends StatefulWidget {
  const AdminBookingsPage({super.key});
  @override
  State<AdminBookingsPage> createState() => _AdminBookingsPageState();
}

class _AdminBookingsPageState extends State<AdminBookingsPage> {
  List<dynamic> _list = [];
  bool _loading = false;
  final _search  = TextEditingController();
  String _status  = 'all';
  String _service = 'all';

  @override
  void initState() { super.initState(); _load(); _search.addListener(_debounce); }
  @override
  void dispose() { _search.removeListener(_debounce); _search.dispose(); super.dispose(); }

  void _debounce() => Future.delayed(
      const Duration(milliseconds: 350), () { if (mounted) _load(); });

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final list = await AdminApiService.getBookings(
          search: _search.text, status: _status, serviceType: _service);
      if (!mounted) return;
      setState(() { _list = list; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _openDetail(Map b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingDetailSheet(booking: b),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Filter bar
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(children: [
          SearchField(controller: _search, hint: 'Search patient or provider…'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: FilterDropdown(
              value: _status,
              items: const {'all': 'All Status', 'pending': 'Pending',
                'completed': 'Completed', 'cancelled': 'Cancelled'},
              onChanged: (v) { setState(() => _status = v!); _load(); },
            )),
            const SizedBox(width: 8),
            Expanded(child: FilterDropdown(
              value: _service,
              items: const {'all': 'All Services', 'caregiver': 'Caregiver',
                'driver': 'Driver', 'doctor': 'Doctor', 'interpreter': 'Interpreter'},
              onChanged: (v) { setState(() => _service = v!); _load(); },
            )),
          ]),
        ]),
      ),

      // Count strip
      if (_list.isNotEmpty)
        Container(
          color: kBg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Text('${_list.length} booking${_list.length != 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 12, color: kTextSecondary, fontWeight: FontWeight.w500)),
            const Spacer(),
            const Text('Tap any row to see details',
                style: TextStyle(fontSize: 11, color: kTextMuted)),
          ]),
        ),

      // List
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2))
            : _list.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.receipt_long_outlined, size: 44, color: kTextMuted),
                    const SizedBox(height: 8),
                    const Text('No bookings found', style: TextStyle(color: kTextSecondary, fontSize: 14)),
                  ]))
                : RefreshIndicator(
                    onRefresh: _load, color: kPrimary,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) => _BookingRow(
                          booking: _list[i], onTap: () => _openDetail(_list[i])),
                    ),
                  ),
      ),
    ]);
  }
}

// ── Compact booking row ────────────────────────────────────
class _BookingRow extends StatelessWidget {
  final Map booking;
  final VoidCallback onTap;
  const _BookingRow({required this.booking, required this.onTap});

  static const _svcColors = {
    'caregiver':             Color(0xFF7C3AED),
    'driver':                Color(0xFF0891B2),
    'doctor':                Color(0xFF059669),
    'interpreter':           Color(0xFFD97706),
    'interpreter - arabic':  Color(0xFFD97706),
  };

  @override
  Widget build(BuildContext context) {
    final b       = booking;
    final patient = '${b['patient_name']  ?? '—'}';
    final service = '${b['service_type']  ?? ''}';
    final status  = '${b['status']        ?? 'pending'}';
    final date    = '${b['date']          ?? ''}';
    final sColor  = _svcColors[service.toLowerCase()] ?? kPrimary;
    final isUrgent= b['is_urgent'] == true || b['is_urgent'] == 't';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: kCardBox,
        child: Row(children: [
          // ID
          SizedBox(width: 36, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('#${b['booking_id']}', style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: kTextPrimary)),
              if (isUrgent) Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(3)),
                child: const Text('URG', style: TextStyle(
                    fontSize: 7, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
              ),
            ],
          )),
          const SizedBox(width: 8),

          // Service dot
          Container(width: 8, height: 8,
              decoration: BoxDecoration(color: sColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),

          // Patient
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(patient, style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary),
                overflow: TextOverflow.ellipsis),
            Text(service.isNotEmpty
                ? service[0].toUpperCase() + service.substring(1)
                : '—',
                style: TextStyle(fontSize: 11, color: sColor, fontWeight: FontWeight.w500)),
          ])),

          // Date
          Text(date.length >= 10 ? date.substring(5) : date,
              style: const TextStyle(fontSize: 11, color: kTextSecondary)),
          const SizedBox(width: 8),

          // Status
          StatusBadge(status),

          // Chevron
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 16, color: kTextMuted),
        ]),
      ),
    );
  }
}

// ── Booking detail bottom sheet ────────────────────────────
class _BookingDetailSheet extends StatelessWidget {
  final Map booking;
  const _BookingDetailSheet({required this.booking});

  static const _svcColors = {
    'caregiver':             Color(0xFF7C3AED),
    'driver':                Color(0xFF0891B2),
    'doctor':                Color(0xFF059669),
    'interpreter':           Color(0xFFD97706),
    'interpreter - arabic':  Color(0xFFD97706),
  };

  @override
  Widget build(BuildContext context) {
    final b        = booking;
    final patient  = '${b['patient_name']  ?? '—'}';
    final provider = '${b['provider_name'] ?? '—'}';
    final service  = '${b['service_type']  ?? ''}';
    final status   = '${b['status']        ?? 'pending'}';
    final date     = '${b['date']          ?? '—'}';
    final amount   = b['payment_total'];
    final payStatus= '${b['payment_status'] ?? ''}';
    final rating   = int.tryParse('${b['rating'] ?? ''}') ?? 0;
    final isUrgent = b['is_urgent']   == true || b['is_urgent']   == 't';
    final isFullDay= b['is_full_day'] == true || b['is_full_day'] == 't';
    final sColor   = _svcColors[service.toLowerCase()] ?? kPrimary;
    final sLabel   = service.isNotEmpty
        ? service[0].toUpperCase() + service.substring(1) : '—';

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          const SheetHandle(),

          // Service header bar
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: sColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sColor.withOpacity(0.15)),
            ),
            child: Row(children: [
              Container(width: 38, height: 38,
                decoration: BoxDecoration(color: sColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(_svcIcon(service), color: sColor, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Booking #${b['booking_id']}', style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: kTextPrimary)),
                Text(sLabel, style: TextStyle(fontSize: 12, color: sColor, fontWeight: FontWeight.w500)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                StatusBadge(status),
                if (isUrgent) Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('URGENT', style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 4),

          Expanded(child: SingleChildScrollView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // People
              _sectionTitle('People Involved'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _personCard('Patient', patient, Icons.accessible_rounded, const Color(0xFF0891B2))),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_rounded, size: 16, color: kTextMuted),
                const SizedBox(width: 10),
                Expanded(child: _personCard('Provider', provider, Icons.medical_services_outlined, sColor)),
              ]),
              const SizedBox(height: 16),

              // Details
              _sectionTitle('Booking Details'),
              const SizedBox(height: 10),
              InfoRow(icon: Icons.calendar_today_outlined, label: 'Date', value: date),
              if (isFullDay)
                InfoRow(icon: Icons.wb_sunny_outlined, label: 'Duration', value: 'Full Day'),
              if (amount != null)
                InfoRow(icon: Icons.payments_outlined, label: 'Total Amount', value: 'EGP $amount'),
              if (payStatus.isNotEmpty && payStatus != 'null')
               InfoRow(icon: Icons.receipt_outlined, label: 'Payment Status',
value: payStatus.toLowerCase() == 'completed' ? 'Paid' : payStatus.toLowerCase() == 'pending' ? 'Unpaid' : payStatus[0].toUpperCase() + payStatus.substring(1)),
              // Rating
              if (rating > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A))),
                  child: Row(children: [
                    ...List.generate(5, (i) => Icon(
                      i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: const Color(0xFFF59E0B), size: 18)),
                    const SizedBox(width: 8),
                    Text('$rating / 5',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                            color: Color(0xFF78350F))),
                  ]),
                ),
              ],
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t.toUpperCase(),
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
          color: kTextMuted, letterSpacing: 0.7));

  Widget _personCard(String role, String name, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(role, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 4),
      Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary),
          overflow: TextOverflow.ellipsis),
    ]),
  );

  IconData _svcIcon(String s) {
    switch (s.toLowerCase()) {
      case 'driver':      return Icons.directions_car_outlined;
      case 'doctor':      return Icons.medical_services_outlined;
      case 'caregiver':   return Icons.people_alt_outlined;
      default:            return Icons.translate_outlined;
    }
  }
}