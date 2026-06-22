// ============================================================
// lib/admin/admin_providers_page.dart
// ============================================================
import 'package:flutter/material.dart';
import 'admin_api_service.dart';
import 'admin_helpers.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_cached_pdfview/flutter_cached_pdfview.dart';



class AdminProvidersPage extends StatefulWidget {
  const AdminProvidersPage({super.key});
  @override
  State<AdminProvidersPage> createState() => _AdminProvidersPageState();
}

class _AdminProvidersPageState extends State<AdminProvidersPage> {
  List<dynamic> _list = [];
  bool _loading = false;
  final _search = TextEditingController();
  String _status   = 'all';
  String _category = 'all';

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
      final list = await AdminApiService.getProviders(
          search: _search.text, status: _status, category: _category);
      if (!mounted) return;
      setState(() { _list = list; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _openDetail(Map p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProviderDetailSheet(
        provider: p,
        onChanged: () { Navigator.pop(context); _load(); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _list.where((p) => p['status'] == 'pending').length;

    return Column(children: [
      // ── Filter bar ──────────────────────────────────
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(children: [
          SearchField(controller: _search, hint: 'Search by name or email…'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: FilterDropdown(
              value: _status,
              items: const {'all': 'All Status', 'pending': 'Pending',
                'accepted': 'Accepted', 'rejected': 'Rejected'},
              onChanged: (v) { setState(() => _status = v!); _load(); },
            )),
            const SizedBox(width: 8),
            Expanded(child: FilterDropdown(
              value: _category,
              items: const {'all': 'All Types', 'driver': 'Driver',
                'doctor': 'Doctor', 'caregiver': 'Caregiver', 'interpreter': 'Interpreter'},
              onChanged: (v) { setState(() => _category = v!); _load(); },
            )),
          ]),
        ]),
      ),

      // ── Pending alert banner ─────────────────────────
      if (pending > 0 && _status == 'all')
        Container(
          width: double.infinity,
          color: const Color(0xFFFFFBEB),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            const Icon(Icons.hourglass_top_rounded,
                size: 16, color: Color(0xFF78350F)),
            const SizedBox(width: 8),
            Expanded(child: Text('$pending provider${pending > 1 ? 's' : ''} awaiting your review',
                style: const TextStyle(fontSize: 12, color: Color(0xFF78350F), fontWeight: FontWeight.w500))),
            GestureDetector(
              onTap: () { setState(() => _status = 'pending'); _load(); },
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Text('View',
                    style: TextStyle(fontSize: 12, color: Color(0xFFF59E0B), fontWeight: FontWeight.w700)),
                SizedBox(width: 2),
                Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFFF59E0B)),
              ]),
            ),
          ]),
        ),

      // ── List ─────────────────────────────────────────
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2))
            : _list.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.people_outline, size: 44, color: kTextMuted),
                    const SizedBox(height: 8),
                    Text(_search.text.isNotEmpty ? 'No results for "${_search.text}"' : 'No providers found',
                        style: const TextStyle(color: kTextSecondary, fontSize: 14)),
                  ]))
                : RefreshIndicator(
                    onRefresh: _load, color: kPrimary,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _ProviderCard(
                        provider: _list[i],
                        onTap: () => _openDetail(_list[i]),
                      ),
                    ),
                  ),
      ),
    ]);
  }
}

// ── Provider summary card ───────────────────────────────────
class _ProviderCard extends StatelessWidget {
  final Map provider;
  final VoidCallback onTap;
  const _ProviderCard({required this.provider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p      = provider;
    final name   = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
    final cat    = '${p['category'] ?? 'Provider'}';
    final status = '${p['status'] ?? 'pending'}';
    final books  = p['total_bookings'] ?? 0;
    final color  = catColor(cat);

    return Container(
      decoration: kCardBox,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            UserAvatar(name, 46),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
              const SizedBox(height: 3),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(99)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(catMaterialIcon(cat), size: 11, color: color),
                    const SizedBox(width: 4),
                    Text(cat,
                        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(width: 6),
                StatusBadge(status),
              ]),
            ])),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$books', style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: kTextPrimary)),
              const Text('bookings', style: TextStyle(fontSize: 9, color: kTextMuted)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(7)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Details', style: TextStyle(
                      fontSize: 10, color: kPrimary, fontWeight: FontWeight.w700)),
                  SizedBox(width: 3),
                  Icon(Icons.chevron_right_rounded, size: 13, color: kPrimary),
                ]),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Provider detail bottom sheet ────────────────────────────
class _ProviderDetailSheet extends StatefulWidget {
  final Map provider;
  final VoidCallback onChanged;
  const _ProviderDetailSheet({required this.provider, required this.onChanged});
  @override
  State<_ProviderDetailSheet> createState() => _ProviderDetailSheetState();
}

class _ProviderDetailSheetState extends State<_ProviderDetailSheet> {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  bool _saving  = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final id = widget.provider['user_id'] as int;
      final d  = await AdminApiService.getProviderDetail(id);
      if (!mounted) return;
      setState(() { _detail = d; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _changeStatus(String status) async {
    final p    = _detail ?? widget.provider;
    final name = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
    final ok   = await confirmDialog(context,
        title: status == 'accepted' ? 'Accept Provider?' : 'Reject Provider?',
        message: 'Are you sure you want to $status "$name"?',
        confirmLabel: status == 'accepted' ? 'Accept' : 'Reject',
        isDanger: status == 'rejected');
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await AdminApiService.updateProviderStatus(
          widget.provider['user_id'] as int, status: status);
      showToast(context, 'Provider $status successfully',
          isError: status == 'rejected');
      widget.onChanged();
    } catch (e) {
      setState(() => _saving = false);
      showToast(context, 'Error: $e', isError: true);
    }
  }

  void _openNote() {
    final p    = _detail ?? widget.provider;
    final ctrl = TextEditingController(text: '${p['admin_note'] ?? ''}');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Admin Note', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
        content: TextField(
          controller: ctrl, maxLines: 4,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Write a note about this provider…',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kPrimary)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: kTextSecondary))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final currentStatus = '${(_detail ?? widget.provider)['status'] ?? 'pending'}';
              await AdminApiService.updateProviderStatus(
                  widget.provider['user_id'] as int,
                  status: currentStatus, note: ctrl.text.trim());
              showToast(context, 'Note saved!');
              _load();
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  void _openDoc(String url) {
    final fixedUrl = url
        .replaceAll('10.13.114.211', '10.13.114.211')
        .replaceAll('localhost', '10.13.114.211')
        .replaceAll('10.13.114.211', '10.13.114.211');

    print('📄 Opening doc URL: $fixedUrl');

    final isImage = fixedUrl.toLowerCase().endsWith('.png') ||
        fixedUrl.toLowerCase().endsWith('.jpg') ||
        fixedUrl.toLowerCase().endsWith('.jpeg');

    final isPdf = fixedUrl.toLowerCase().endsWith('.pdf');
    final isDoc = fixedUrl.toLowerCase().endsWith('.doc') ||
        fixedUrl.toLowerCase().endsWith('.docx');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            child: Row(children: [
              const Icon(Icons.description_outlined, color: kPrimary, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Document Viewer',
                    style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w700, color: kTextPrimary)),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close_rounded, color: kTextMuted, size: 20),
              ),
            ]),
          ),
          // Content
          Expanded(
            child: isImage
                ? InteractiveViewer(
                    child: Center(
                      child: Image.network(
                        fixedUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, progress) =>
                            progress == null
                                ? child
                                : const Center(child: CircularProgressIndicator(color: kPrimary)),
                        errorBuilder: (_, __, ___) => const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image_outlined, size: 48, color: kTextMuted),
                              SizedBox(height: 8),
                              Text('Could not load image',
                                  style: TextStyle(color: kTextSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : isPdf
                    ? PDF(
                        nightMode: false,
                        autoSpacing: true,
                        pageFling: true,
                        fitPolicy: FitPolicy.BOTH,
                      ).cachedFromUrl(
                        fixedUrl,
                        placeholder: (progress) => const Center(
                          child: CircularProgressIndicator(color: kPrimary),
                        ),
                        errorWidget: (error) => const Center(
                          child: Text('Could not load PDF',
                              style: TextStyle(color: kTextSecondary)),
                        ),
                      )
                    : isDoc
                        ? Builder(builder: (ctx) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              launchUrl(Uri.parse(fixedUrl),
                                  mode: LaunchMode.externalApplication);
                            });
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.description_rounded,
                                      size: 56, color: Color(0xFF2B579A)),
                                  SizedBox(height: 16),
                                  Text('Opening Document…',
                                      style: TextStyle(fontSize: 16,
                                          fontWeight: FontWeight.w800)),
                                  SizedBox(height: 8),
                                  Text('Document will open in your Word app.',
                                      style: TextStyle(color: kTextSecondary, fontSize: 13)),
                                ],
                              ),
                            );
                          })
                        : const Center(
                            child: Text('Unsupported file type',
                                style: TextStyle(color: kTextSecondary)),
                          ),
          ),
        ]),
      ),
    );
  }

  // ── Document button ────────────────────────────────────────
  Widget _docButton(String label, IconData icon, String? url) {
    final hasDoc = url != null && url.isNotEmpty;
    return GestureDetector(
      onTap: hasDoc ? () => _openDoc(url) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasDoc ? kBg : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: hasDoc ? kBorder : const Color(0xFFFDE68A)),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: hasDoc
                    ? kPrimary.withOpacity(0.1)
                    : const Color(0xFFFDE68A).withOpacity(0.5),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(icon,
                color: hasDoc ? kPrimary : const Color(0xFF78350F),
                size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
            Text(
              hasDoc ? 'Tap to view document' : 'No document uploaded',
              style: TextStyle(
                  fontSize: 11,
                  color: hasDoc ? kTextSecondary : const Color(0xFF78350F)),
            ),
          ])),
          if (hasDoc)
            const Icon(Icons.visibility_outlined, size: 16, color: kPrimary),
          if (!hasDoc)
            const Icon(Icons.warning_amber_rounded,
                size: 16, color: Color(0xFF78350F)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SheetHandle(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2))
                : _detail == null
                    ? const Center(child: Text('Failed to load provider details',
                          style: TextStyle(color: kTextSecondary)))
                    : _buildContent(ctrl),
          ),
          if (!_loading && _detail != null) _buildActions(),
        ]),
      ),
    );
  }

  Widget _buildContent(ScrollController ctrl) {
    final p      = _detail!;
    final name   = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
    final cat    = '${p['category'] ?? 'Provider'}';
    final status = '${p['status'] ?? 'pending'}';
    final color  = catColor(cat);
    final books  = List<Map>.from(p['bookings'] ?? []);

    return SingleChildScrollView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Profile header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [kPrimaryDark, color],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            UserAvatar(name, 52),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 5),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(99)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(catMaterialIcon(cat), size: 12, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(cat,
                        style: const TextStyle(color: Colors.white,
                            fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(width: 8),
                StatusBadge(status),
              ]),
            ])),
          ]),
        ),
        const SizedBox(height: 20),

        // Personal info
        _sectionTitle('Personal Information'),
        const SizedBox(height: 10),
        InfoRow(icon: Icons.email_outlined,       label: 'Email',        value: '${p['email']       ?? '—'}'),
        InfoRow(icon: Icons.phone_outlined,       label: 'Phone',        value: '${p['phone']       ?? '—'}'),
        InfoRow(icon: Icons.person_outlined,      label: 'Gender',       value: '${p['gender']      ?? '—'}'),
        InfoRow(icon: Icons.cake_outlined,        label: 'Date of Birth',value: '${p['dob']         ?? '—'}'),
        InfoRow(icon: Icons.badge_outlined,       label: 'National ID',  value: '${p['national_id'] ?? '—'}'),
        InfoRow(icon: Icons.location_on_outlined, label: 'Address',      value: '${p['address']     ?? '—'}'),

        // Professional info
        if (cat == 'Doctor') ...[
          const SizedBox(height: 16),
          _sectionTitle('Doctor Details'),
          const SizedBox(height: 10),
          InfoRow(icon: Icons.local_hospital_outlined, label: 'Speciality', value: '${p['speciality'] ?? '—'}'),
        ],
        if (cat == 'Driver') ...[
          const SizedBox(height: 16),
          _sectionTitle('Driver Details'),
          const SizedBox(height: 10),
          InfoRow(icon: Icons.directions_car_outlined,      label: 'Vehicle',       value: '${p['car_make'] ?? ''} ${p['car_model'] ?? ''}'.trim()),
          InfoRow(icon: Icons.confirmation_number_outlined, label: 'Plate',         value: '${p['license_plate'] ?? '—'}'),
          // Wheelchair accessible — icon replaces the old ✅ emoji in the value string
          _wheelchairRow(p['wheelchair_accessible']),
          InfoRow(icon: Icons.route_outlined,               label: 'Total Trips',   value: '${p['total_trips'] ?? 0}'),
          InfoRow(icon: Icons.account_balance_wallet_outlined, label: 'Balance',    value: 'EGP ${p['available_balance'] ?? 0}'),
        ],
        if (cat == 'Caregiver') ...[
          const SizedBox(height: 16),
          _sectionTitle('Caregiver Details'),
          const SizedBox(height: 10),
          InfoRow(icon: Icons.schedule_outlined, label: 'Shift Preference', value: '${p['shift_preference'] ?? '—'}'),
        ],
        if (cat == 'Interpreter') ...[
          const SizedBox(height: 16),
          _sectionTitle('Interpreter Details'),
          const SizedBox(height: 10),
          InfoRow(icon: Icons.translate_outlined, label: 'Languages', value: '${p['languages'] ?? '—'}'),
        ],

        // ── Documents section (ALL providers) ──────────────
        const SizedBox(height: 16),
        _sectionTitle('Documents'),
        const SizedBox(height: 10),

        if (cat == 'Doctor')
          _docButton('Medical License', Icons.medical_information_outlined,
              p['medical_license']?.toString()),
        if (cat == 'Driver')
          _docButton('Driving License', Icons.card_membership_outlined,
              p['driving_license']?.toString()),

        _docButton('CV / Description', Icons.description_outlined,
            p['cv']?.toString()),

        // Admin note
        if ((p['admin_note'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionTitle('Admin Note'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              border: Border.all(color: const Color(0xFFFDE68A)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.sticky_note_2_outlined,
                  size: 15, color: Color(0xFF78350F)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${p['admin_note']}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF78350F))),
              ),
            ]),
          ),
        ],

        // Booking history
        if (books.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionTitle('Recent Bookings (${books.length})'),
          const SizedBox(height: 10),
          ...books.take(6).map((b) => Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('#${b['booking_id']} · ${b['service_type'] ?? ''}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextPrimary)),
                Text('${b['patient_name'] ?? '—'} · ${b['date'] ?? ''}',
                    style: const TextStyle(fontSize: 11, color: kTextSecondary)),
              ])),
              StatusBadge('${b['status'] ?? 'pending'}'),
              if (b['payment_total'] != null) ...[
                const SizedBox(width: 6),
                Text('EGP ${b['payment_total']}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextPrimary)),
              ],
            ]),
          )),
        ],

        const SizedBox(height: 20),
      ]),
    );
  }

  /// Wheelchair accessible row with a proper icon instead of ✅ / text
  Widget _wheelchairRow(dynamic value) {
    final isYes = value == 't' || value == true;
    return InfoRow(
      icon: Icons.accessible_rounded,
      label: 'Wheelchair Accessible',
      value: isYes ? 'Yes' : 'No',
    );
  }

  Widget _buildActions() {
    final status = '${(_detail ?? widget.provider)['status'] ?? 'pending'}';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kBorder, width: 0.8)),
      ),
      child: Row(children: [
        // Note button
        OutlinedButton.icon(
          onPressed: _saving ? null : _openNote,
          icon: const Icon(Icons.edit_note_rounded, size: 16),
          label: const Text('Note'),
          style: OutlinedButton.styleFrom(
            foregroundColor: kTextSecondary,
            side: const BorderSide(color: kBorder),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          ),
        ),
        const SizedBox(width: 8),

        // Accept — only for PENDING providers
        if (status == 'pending') ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _saving ? null : () => _changeStatus('accepted'),
              icon: _saving
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_rounded, size: 16),
              label: const Text('Accept'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _saving ? null : () => _changeStatus('rejected'),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Reject'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9)),
              ),
            ),
          ),
        ],

        // Accepted — only show Reject button
        if (status == 'accepted')
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _saving ? null : () => _changeStatus('rejected'),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Reject Provider'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9)),
              ),
            ),
          ),

        // Rejected — label with icon
        if (status == 'rejected')
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel_rounded,
                      size: 16, color: Color(0xFFEF4444)),
                  SizedBox(width: 6),
                  Text('Provider Rejected',
                      style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
      ]),
    );
  }

  Widget _sectionTitle(String t) => Text(t.toUpperCase(),
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
          color: kTextMuted, letterSpacing: 0.7));
}

// ── Helper: Material icon per category (replaces emoji catIcon()) ──
IconData catMaterialIcon(String cat) {
  switch (cat.toLowerCase()) {
    case 'driver':      return Icons.directions_car_rounded;
    case 'doctor':      return Icons.local_hospital_rounded;
    case 'caregiver':   return Icons.favorite_rounded;
    case 'interpreter': return Icons.translate_rounded;
    default:            return Icons.person_rounded;
  }
}