// ============================================================
// lib/admin/admin_patients_page.dart
// ============================================================
import 'package:flutter/material.dart';
import 'admin_api_service.dart';
import 'admin_helpers.dart';

class AdminPatientsPage extends StatefulWidget {
  const AdminPatientsPage({super.key});
  @override
  State<AdminPatientsPage> createState() => _AdminPatientsPageState();
}

class _AdminPatientsPageState extends State<AdminPatientsPage> {
  List<dynamic> _list = [];
  bool _loading = false;
  final _search = TextEditingController();

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
      final list = await AdminApiService.getPatients(search: _search.text);
      if (!mounted) return;
      setState(() { _list = list; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Search bar
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: SearchField(controller: _search, hint: 'Search by name or email…'),
      ),

      // Count strip
      if (_list.isNotEmpty)
        Container(
          color: kBg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Text('${_list.length} patient${_list.length != 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 12, color: kTextSecondary, fontWeight: FontWeight.w500)),
          ]),
        ),

      // List
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2))
            : _list.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.accessible_outlined, size: 44, color: kTextMuted),
                    const SizedBox(height: 8),
                    Text(_search.text.isNotEmpty ? 'No results found' : 'No patients yet',
                        style: const TextStyle(color: kTextSecondary, fontSize: 14)),
                  ]))
                : RefreshIndicator(
                    onRefresh: _load, color: kPrimary,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _PatientCard(p: _list[i]),
                    ),
                  ),
      ),
    ]);
  }
}

class _PatientCard extends StatelessWidget {
  final Map p;
  const _PatientCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final name      = '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
    final email     = '${p['email'] ?? ''}';
    final disability= '${p['disability'] ?? ''}';
    final gender    = '${p['gender'] ?? ''}';
    final books     = p['total_bookings'] ?? 0;

    return Container(
      decoration: kCardBox,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        UserAvatar(name, 44),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(height: 2),
          Text(email, style: const TextStyle(fontSize: 12, color: kTextSecondary),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: [
            if (disability.isNotEmpty) _chip(disability, kPrimary),
            if (gender.isNotEmpty)     _chip(gender,     kTextSecondary),
          ]),
        ])),
        const SizedBox(width: 10),
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: kBg, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder)),
            child: Center(child: Text('$books',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kPrimary))),
          ),
          const SizedBox(height: 2),
          const Text('Bookings', style: TextStyle(fontSize: 8, color: kTextMuted)),
        ]),
      ]),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
        color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(99)),
    child: Text(label.isNotEmpty ? label[0].toUpperCase() + label.substring(1) : label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
  );
}