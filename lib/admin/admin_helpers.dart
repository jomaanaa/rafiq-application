// ============================================================
// lib/admin/admin_helpers.dart  —  Design System & Shared Widgets
// ============================================================
import 'package:flutter/material.dart';

// ── Tokens ─────────────────────────────────────────────────
const kPrimaryDark   = Color(0xFF1E1B4B);
const kPrimary       = Color(0xFF4F46E5);
const kBg            = Color(0xFFF8FAFC);
const kBorder        = Color(0xFFE2E8F0);
const kTextPrimary   = Color(0xFF0F172A);
const kTextSecondary = Color(0xFF64748B);
const kTextMuted     = Color(0xFF94A3B8);
const kDivider       = Color(0xFFF1F5F9);

BoxDecoration get kCardBox => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: kBorder, width: 0.8),
  boxShadow: [BoxShadow(
      color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
);

// ── Status badge ───────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});

  static const _cfg = <String, List<Color>>{
    'pending':   [Color(0xFFFFFBEB), Color(0xFFF59E0B), Color(0xFF78350F)],
    'accepted':  [Color(0xFFECFDF5), Color(0xFF10B981), Color(0xFF064E3B)],
    'rejected':  [Color(0xFFFEF2F2), Color(0xFFEF4444), Color(0xFF7F1D1D)],
    'active':    [Color(0xFFECFDF5), Color(0xFF10B981), Color(0xFF064E3B)],
    'hidden':    [Color(0xFFF8FAFC), Color(0xFF94A3B8), Color(0xFF334155)],
    'completed': [Color(0xFFEEF2FF), Color(0xFF818CF8), Color(0xFF312E81)],
    'arrived':   [Color(0xFFEFF6FF), Color(0xFF3B82F6), Color(0xFF1E3A8A)],
    'cancelled': [Color(0xFFFEF2F2), Color(0xFFEF4444), Color(0xFF7F1D1D)],
    'declined':  [Color(0xFFFEF2F2), Color(0xFFEF4444), Color(0xFF7F1D1D)],
    'paid':      [Color(0xFFECFDF5), Color(0xFF10B981), Color(0xFF064E3B)],
    'unpaid':    [Color(0xFFFFFBEB), Color(0xFFF59E0B), Color(0xFF78350F)],
  };

  @override
  Widget build(BuildContext context) {
    final c = _cfg[status.toLowerCase()] ??
        [const Color(0xFFF8FAFC), kTextMuted, kTextSecondary];
    final label = status.isNotEmpty
        ? status[0].toUpperCase() + status.substring(1) : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c[0], borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5,
            decoration: BoxDecoration(color: c[1], shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c[2])),
      ]),
    );
  }
}

// ── User avatar ────────────────────────────────────────────
class UserAvatar extends StatelessWidget {
  final String name;
  final double size;
  const UserAvatar(this.name, this.size, {super.key});

  static const _colors = [
    Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFF0891B2),
    Color(0xFF059669), Color(0xFFD97706), Color(0xFFDC2626),
  ];

  @override
  Widget build(BuildContext context) {
    final words = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    final letters = words.take(2).map((w) => w[0].toUpperCase()).join();
    final bg = name.isNotEmpty ? _colors[name.codeUnitAt(0) % _colors.length] : _colors[0];
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Center(child: Text(letters.isEmpty ? '?' : letters,
          style: TextStyle(color: Colors.white, fontSize: size * 0.36,
              fontWeight: FontWeight.w700))),
    );
  }
}

// ── Section header ─────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionHeader(this.title, {this.subtitle, this.trailing, super.key});

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
      if (subtitle != null)
        Padding(padding: const EdgeInsets.only(top: 1),
          child: Text(subtitle!, style: const TextStyle(fontSize: 12, color: kTextSecondary))),
    ])),
    if (trailing != null) trailing!,
  ]);
}

// ── Filter dropdown ────────────────────────────────────────
class FilterDropdown extends StatelessWidget {
  final String value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;
  const FilterDropdown(
      {required this.value, required this.items, required this.onChanged, super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value, isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: kTextSecondary),
        style: const TextStyle(fontSize: 12, color: kTextPrimary),
        items: items.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

// ── Search field ───────────────────────────────────────────
class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const SearchField({required this.controller, required this.hint, super.key});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    style: const TextStyle(fontSize: 13),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: kTextMuted),
      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: kTextMuted),
      filled: true, fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kPrimary, width: 1.5)),
    ),
  );
}

// ── Sheet handle ───────────────────────────────────────────
class SheetHandle extends StatelessWidget {
  final String? title;
  const SheetHandle({this.title, super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Center(child: Container(
        width: 36, height: 4, margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
            color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
      )),
      if (title != null) Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Row(children: [
          Expanded(child: Text(title!, style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: kTextPrimary))),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(width: 28, height: 28,
              decoration: const BoxDecoration(color: kBg, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 16, color: kTextSecondary)),
          ),
        ]),
      ),
      const Divider(height: 20, color: kDivider),
    ],
  );
}

// ── Detail info row ────────────────────────────────────────
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const InfoRow({required this.icon, required this.label, required this.value, super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Container(width: 34, height: 34,
        decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 15, color: kTextSecondary)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: kTextMuted)),
        Text(value.isNotEmpty ? value : '—',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kTextPrimary)),
      ])),
    ]),
  );
}

IconData catIcon(String? cat) {
  switch (cat?.toLowerCase().trim()) {
    case 'driver':      return Icons.directions_car_rounded;
    case 'doctor':      return Icons.local_hospital_rounded;
    case 'caregiver':   return Icons.favorite_rounded;
    case 'interpreter': return Icons.translate_rounded;
    default:            return Icons.person_rounded;
  }
}
IconData serviceIcon(String? type) {
  final t = type?.toLowerCase().trim() ?? '';
  if (t.startsWith('interpreter')) return Icons.record_voice_over_rounded;
  switch (t) {
    case 'home visit':           return Icons.home_rounded;
    case 'online consultation':  return Icons.video_call_rounded;
    case 'physical therapy':     return Icons.fitness_center_rounded;
    case 'nursing care':         return Icons.medical_services_rounded;
    case 'elderly care':         return Icons.elderly_rounded;
    default:                     return Icons.miscellaneous_services_rounded;
  }
}

Color catColor(String? cat) {
  switch (cat) {
    case 'Driver':      return const Color(0xFF0891B2);
    case 'Doctor':      return const Color(0xFF059669);
    case 'Caregiver':   return const Color(0xFF7C3AED);
    case 'Interpreter': return const Color(0xFFD97706);
    default:            return kPrimary;
  }
}

String placeEmoji(String? type) {
  const m = {
    'Hospital': '🏥', 'Clinic': '🩺', 'Mall': '🛍️', 'Park': '🌳',
    'Museum': '🏛️', 'Restaurant': '🍽️', 'Hotel': '🏨', 'Mosque': '🕌',
    'Church': '⛪', 'Pharmacy': '💊', 'School': '🏫', 'University': '🎓',
    'Government Office': '🏢', 'Other': '📍',
  };
  return m[type] ?? '📍';
}

List<String> placeFeatures(Map p) {
  bool t(v) => v == true || v == 't' || v == 1;
  return [
    if (t(p['elevator'])) 'Elevator',
    if (t(p['ramp']))     'Ramp',
    if (t(p['toilet']))   'Restroom',
    if (t(p['parking']))  'Parking',
  ];
}

// ── Dialogs / toasts ───────────────────────────────────────
Future<bool?> confirmDialog(BuildContext context,
    {required String title, required String message,
     String confirmLabel = 'Confirm', bool isDanger = false}) =>
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title, style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
        content: Text(message,
            style: const TextStyle(fontSize: 13, color: kTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: kTextSecondary))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel, style: TextStyle(fontWeight: FontWeight.w700,
                color: isDanger ? const Color(0xFFEF4444) : kPrimary)),
          ),
        ],
      ),
    );

void showToast(BuildContext context, String msg, {bool isError = false}) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
          color: Colors.white, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(msg,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
    backgroundColor: isError ? const Color(0xFFDC2626) : kPrimaryDark,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    margin: const EdgeInsets.all(12),
    duration: const Duration(seconds: 2),
  ));
}