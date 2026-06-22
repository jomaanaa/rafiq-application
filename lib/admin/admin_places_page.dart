// ============================================================
// lib/admin/admin_places_page.dart
// ============================================================
import 'package:flutter/material.dart';
import 'admin_api_service.dart';
import 'admin_helpers.dart';

class AdminPlacesPage extends StatefulWidget {
  const AdminPlacesPage({super.key});
  @override
  State<AdminPlacesPage> createState() => _AdminPlacesPageState();
}

class _AdminPlacesPageState extends State<AdminPlacesPage> {
  List<dynamic> _list = [];
  bool _loading = false;
  final _search = TextEditingController();
  String _type   = 'all';
  String _status = 'all';

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
      final list = await AdminApiService.getPlaces(
          search: _search.text, type: _type, status: _status);
      if (!mounted) return;
      setState(() { _list = list; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _delete(int id, String name) async {
    final ok = await confirmDialog(context,
        title: 'Delete Place?',
        message: '"$name" will be permanently removed.',
        confirmLabel: 'Delete', isDanger: true);
    if (ok != true) return;
    try {
      await AdminApiService.deletePlace(id);
      showToast(context, 'Place deleted');
      _load();
    } catch (e) { showToast(context, 'Error: $e', isError: true); }
  }

  Future<void> _changeStatus(int id, String status) async {
    try {
      await AdminApiService.updatePlaceStatus(id, status);
      showToast(context, 'Status updated to $status');
      _load();
    } catch (e) { showToast(context, 'Error: $e', isError: true); }
  }

  void _viewPlace(Map pl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PlaceViewSheet(pl: pl),
    );
  }

  static const _typeItems = {
    'all': 'All Types', 'Hospital': 'Hospital', 'Clinic': 'Clinic',
    'Mall': 'Mall', 'Park': 'Park', 'Museum': 'Museum',
    'Restaurant': 'Restaurant', 'Hotel': 'Hotel', 'Mosque': 'Mosque',
    'Church': 'Church', 'Pharmacy': 'Pharmacy', 'School': 'School',
    'University': 'University', 'Government Office': 'Gov. Office', 'Other': 'Other',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(children: [
        // Filters
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(children: [
            SearchField(controller: _search, hint: 'Search places…'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: FilterDropdown(
                value: _type, items: _typeItems,
                onChanged: (v) { setState(() => _type = v!); _load(); },
              )),
            ]),
          ]),
        ),

        // Count
        if (_list.isNotEmpty)
          Container(
            color: kBg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Text('${_list.length} place${_list.length != 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, color: kTextSecondary, fontWeight: FontWeight.w500)),
            ]),
          ),

        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2))
              : _list.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.place_outlined, size: 44, color: kTextMuted),
                      const SizedBox(height: 8),
                      const Text('No places found', style: TextStyle(color: kTextSecondary, fontSize: 14)),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _load, color: kPrimary,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: _list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _PlaceCard(
                          pl: _list[i],
                          onView:   () => _viewPlace(_list[i]),
                          onDelete: () => _delete(_list[i]['place_id'] as int, '${_list[i]['name']}'),
                          onStatusChange: (s) => _changeStatus(_list[i]['place_id'] as int, s),
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────

/// Strips the leading [osm:node_XXXXXXX] tag from a description string.
String _cleanDescription(String raw) {
  return raw.replaceFirst(RegExp(r'^\[osm:[^\]]+\]\s*'), '').trim();
}

/// Renders a star rating row (filled + empty stars) for a 1–5 scale.
Widget _buildStarRating(dynamic rawRating) {
  final rating = (rawRating is num)
      ? rawRating.toDouble()
      : double.tryParse('$rawRating') ?? 0.0;
  const total = 5;
  final filled = rating.round().clamp(0, total);

  return Row(
    children: List.generate(total, (i) => Icon(
      i < filled ? Icons.star_rounded : Icons.star_outline_rounded,
      size: 18,
      color: i < filled ? const Color(0xFFFACC15) : const Color(0xFFD1D5DB),
    )),
  );
}

// ── Place card (list view — no rating shown here) ──────────
class _PlaceCard extends StatelessWidget {
  final Map pl;
  final VoidCallback onView, onDelete;
  final ValueChanged<String> onStatusChange;
  const _PlaceCard({required this.pl, required this.onView,
      required this.onDelete, required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    final name    = '${pl['name']    ?? ''}';
    final type    = '${pl['type']    ?? ''}';
    final address = '${pl['address'] ?? ''}';
    final chips   = placeFeatures(pl);

    return Container(
      decoration: kCardBox,
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Header row
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Emoji icon
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: kBg, borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(placeEmoji(type),
                    style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(address, style: const TextStyle(
                    fontSize: 12, color: kTextSecondary),
                    overflow: TextOverflow.ellipsis, maxLines: 1),
                const SizedBox(height: 5),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: kBorder)),
                    child: Text(type, style: const TextStyle(fontSize: 9,
                        color: kTextSecondary, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ])),
              // 3-dot menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 18, color: kTextMuted),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onSelected: (val) {
                  switch (val) {
                    case 'view':    onView(); break;
                    case 'active':  onStatusChange('active'); break;
                    case 'hidden':  onStatusChange('hidden'); break;
                    case 'pending': onStatusChange('pending'); break;
                    case 'delete':  onDelete(); break;
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'view',
                      child: _MenuItem(icon: Icons.visibility_outlined, label: 'View Details')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'delete',
                      child: _MenuItem(icon: Icons.delete_outline_rounded, label: 'Delete', color: Color(0xFFEF4444))),
                ],
              ),
            ]),

            // Accessibility feature chips
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 4, children: chips.map((c) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(99)),
                child: Text('✓ $c', style: const TextStyle(
                    fontSize: 10, color: kPrimary, fontWeight: FontWeight.w600)),
              )).toList()),
            ],

            // ── Rating intentionally NOT shown in the list card ──

          ]),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MenuItem({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 16, color: color ?? kTextPrimary),
    const SizedBox(width: 10),
    Text(label, style: TextStyle(fontSize: 13, color: color ?? kTextPrimary)),
  ]);
}

// ── Place view bottom sheet ─────────────────────────────────
class _PlaceViewSheet extends StatelessWidget {
  final Map pl;
  const _PlaceViewSheet({required this.pl});

  @override
  Widget build(BuildContext context) {
    final chips = placeFeatures(pl);

    // Clean the description: strip leading [osm:node_...] prefix
    final rawComment = (pl['comment'] ?? '').toString();
    final cleanComment = _cleanDescription(rawComment);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          SheetHandle(title: '${pl['name']}'),
          Expanded(child: SingleChildScrollView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Header banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [kPrimaryDark, kPrimary]),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Text(placeEmoji('${pl['type']}'), style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${pl['name']}', style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text('${pl['address']}', style: const TextStyle(
                        fontSize: 12, color: Colors.white60)),
                  ])),
                ]),
              ),
              const SizedBox(height: 16),

              // Info rows
              InfoRow(icon: Icons.category_outlined, label: 'Type',      value: '${pl['type'] ?? '—'}'),
              InfoRow(icon: Icons.my_location,       label: 'Latitude',  value: '${pl['latitude']  ?? '—'}'),
              InfoRow(icon: Icons.my_location,       label: 'Longitude', value: '${pl['longitude'] ?? '—'}'),


              // ── Star rating row (matches InfoRow style) ────────
              if (pl['rating'] != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: kBg, borderRadius: BorderRadius.circular(9)),
                      child: const Icon(Icons.star_rounded, size: 18, color: kTextMuted),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Rating',
                          style: TextStyle(fontSize: 11, color: kTextSecondary)),
                      const SizedBox(height: 3),
                      _buildStarRating(pl['rating']),
                    ])),
                  ]),
                ),
                const Divider(height: 1, color: kBorder),
              ],

              // Accessibility chips
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('ACCESSIBILITY', style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: kTextMuted, letterSpacing: 0.7)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: chips.map((c) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(99)),
                  child: Text('✓ $c', style: const TextStyle(
                      fontSize: 12, color: kPrimary, fontWeight: FontWeight.w600)),
                )).toList()),
              ],

              // Reviews (OSM prefix stripped)
              if (cleanComment.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('REVIEWS', style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: kTextMuted, letterSpacing: 0.7)),
                const SizedBox(height: 6),
                Text(cleanComment, style: const TextStyle(
                    fontSize: 13, color: kTextSecondary, height: 1.5)),
              ],
            ]),
          )),
        ]),
      ),
    );
  }
}

// ── Place form (add/edit) ──────────────────────────────────
class _PlaceFormSheet extends StatefulWidget {
  final Map? place;
  final VoidCallback onSaved;
  const _PlaceFormSheet({this.place, required this.onSaved});
  @override
  State<_PlaceFormSheet> createState() => _PlaceFormSheetState();
}

class _PlaceFormSheetState extends State<_PlaceFormSheet> {
  final _name    = TextEditingController();
  final _addr    = TextEditingController();
  final _lat     = TextEditingController();
  final _lng     = TextEditingController();
  final _comment = TextEditingController();
  final _photo   = TextEditingController();
  String _type   = 'Hospital';
  String _status = 'active';
  bool _elevator = false, _ramp = false, _toilet = false, _parking = false;
  bool _saving = false;

  static const _types = [
    'Hospital','Clinic','Mall','Park','Museum','Restaurant',
    'Hotel','Mosque','Church','Pharmacy','School','University',
    'Government Office','Other',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.place;
    if (p != null) {
      _name.text    = '${p['name']    ?? ''}';
      _addr.text    = '${p['address'] ?? ''}';
      _lat.text     = '${p['latitude']  ?? ''}';
      _lng.text     = '${p['longitude'] ?? ''}';
      _comment.text = '${p['comment']  ?? ''}';
      _photo.text   = '${p['photo']    ?? ''}';
      _type   = _types.contains(p['type'])   ? '${p['type']}'   : 'Hospital';
      _status = ['active','pending','hidden'].contains(p['status']) ? '${p['status']}' : 'active';
      bool t(v) => v == true || v == 't';
      _elevator = t(p['elevator']); _ramp    = t(p['ramp']);
      _toilet   = t(p['toilet']);   _parking = t(p['parking']);
    }
  }

  @override
  void dispose() {
    _name.dispose(); _addr.dispose(); _lat.dispose();
    _lng.dispose(); _comment.dispose(); _photo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _addr.text.trim().isEmpty) {
      showToast(context, 'Name and Address are required', isError: true); return;
    }
    setState(() => _saving = true);
    final data = {
      'name': _name.text.trim(), 'type': _type, 'address': _addr.text.trim(),
      'latitude': _lat.text.isNotEmpty ? _lat.text : null,
      'longitude': _lng.text.isNotEmpty ? _lng.text : null,
      'comment': _comment.text, 'photo': _photo.text, 'status': _status,
      'elevator': _elevator, 'ramp': _ramp, 'toilet': _toilet, 'parking': _parking,
    };
    try {
      final p = widget.place;
      if (p != null) {
        await AdminApiService.editPlace(p['place_id'] as int, data);
        showToast(context, 'Place updated!');
      } else {
        await AdminApiService.addPlace(data);
        showToast(context, 'Place added!');
      }
      widget.onSaved();
    } catch (e) {
      setState(() => _saving = false);
      showToast(context, 'Error: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.place != null;
    return DraggableScrollableSheet(
      initialChildSize: 0.93,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          SheetHandle(title: isEdit ? 'Edit Place' : 'Add New Place'),
          Expanded(child: SingleChildScrollView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _lbl('Place Name *'), _fld(_name, 'e.g. Cairo Festival City'), const SizedBox(height: 12),
              _lbl('Type *'), _drop(), const SizedBox(height: 12),
              _lbl('Address *'), _fld(_addr, 'Full address'), const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _lbl('Latitude'), _fld(_lat, '30.0444'),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _lbl('Longitude'), _fld(_lng, '31.2357'),
                ])),
              ]),
              const SizedBox(height: 12),
              _lbl('Accessibility Features'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _tog('Elevator',  _elevator, () => setState(() => _elevator = !_elevator)),
                _tog('Ramp',      _ramp,     () => setState(() => _ramp     = !_ramp)),
                _tog('Restroom',  _toilet,   () => setState(() => _toilet   = !_toilet)),
                _tog('Parking',   _parking,  () => setState(() => _parking  = !_parking)),
              ]),
              const SizedBox(height: 12),
              _lbl('Description'),
              TextField(controller: _comment, maxLines: 3,
                style: const TextStyle(fontSize: 13),
                decoration: _dec('Describe the accessibility setup…')),
              const SizedBox(height: 12),
              _lbl('Photo URL'), _fld(_photo, 'https://…'), const SizedBox(height: 12),
              _lbl('Status'),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kBorder)),
                child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                  value: _status, isExpanded: true,
                  style: const TextStyle(fontSize: 13, color: kTextPrimary),
                  items: ['active','pending','hidden'].map((s) =>
                      DropdownMenuItem(value: s, child: Text(s[0].toUpperCase() + s.substring(1)))).toList(),
                  onChanged: (v) => setState(() => _status = v!),
                )),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: kTextSecondary, side: const BorderSide(color: kBorder),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
                  child: const Text('Cancel'),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
                  child: _saving
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(isEdit ? 'Update Place' : 'Add Place',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                )),
              ]),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _lbl(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextSecondary)),
  );

  Widget _fld(TextEditingController c, String h) => TextField(
    controller: c, style: const TextStyle(fontSize: 13),
    decoration: _dec(h),
  );

  InputDecoration _dec(String h) => InputDecoration(
    hintText: h, hintStyle: const TextStyle(fontSize: 13, color: kTextMuted),
    filled: true, fillColor: kBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
  );

  Widget _drop() => Container(
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder)),
    child: DropdownButtonHideUnderline(child: DropdownButton<String>(
      value: _type, isExpanded: true,
      style: const TextStyle(fontSize: 13, color: kTextPrimary),
      items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
      onChanged: (v) => setState(() => _type = v!),
    )),
  );

  Widget _tog(String label, bool on, VoidCallback tap) => GestureDetector(
    onTap: tap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: on ? kPrimary : kBg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: on ? kPrimary : kBorder),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: on ? Colors.white : kTextSecondary)),
    ),
  );
}