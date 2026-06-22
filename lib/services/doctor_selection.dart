import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:rafiq/auth/api_service.dart';
import 'package:rafiq/auth/session_manager.dart';
import 'package:rafiq/services/payment.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const _primary     = Color(0xFF2B2C41);
const _primaryDark = Color(0xFF212233);
const _primarySoft = Color(0xFFEFEFF6);
const _accent      = Color(0xFF404066);
const _accentLight = Color(0xFF6B6FA8);
const _green       = Color(0xFF16A34A);
const _greenSoft   = Color(0xFFEEFBF3);
const _greenLine   = Color(0xFFB8EBCA);
const _red         = Color(0xFFDC2626);
const _redSoft     = Color(0xFFFFF1F1);
const _redLine     = Color(0xFFFFCACA);
const _bg          = Color(0xFFF7F8FC);
const _line        = Color(0xFFE6E9F2);
const _muted       = Color(0xFF727692);

// Doctor slots: fixed 60-min sessions, no variable duration
const _kWorkStart        = '10:00';
const _kWorkEnd          = '18:00';
const _kSlotDurationMins = 60;

const Map<String, double> _kSpecialityPrices = {
  'Cardiology (heart)': 650,
  'Neurology (brain & nerves)': 800,
  'Psychiatry (mental health)': 700,
  'Gastroenterology (digestive system)': 720,
  'Pediatrics': 550,
  'Orthopedics': 680,
};

const Map<String, IconData> _kSpecialityIcons = {
  'Cardiology (heart)': Icons.favorite_rounded,
  'Neurology (brain & nerves)': Icons.psychology_rounded,
  'Psychiatry (mental health)': Icons.self_improvement_rounded,
  'Gastroenterology (digestive system)': Icons.medical_services_rounded,
  'Pediatrics': Icons.child_care_rounded,
  'Orthopedics': Icons.accessibility_new_rounded,
};

double   _priceFor(String? s) => _kSpecialityPrices[s ?? ''] ?? 600;
IconData _iconFor(String? s)  => _kSpecialityIcons[s ?? ''] ?? Icons.local_hospital_rounded;

// ─── Slot helpers ─────────────────────────────────────────────────────────────
int _toMin(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

String _fromMin(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

String _toAmPm(String hhmm) {
  final parts = hhmm.split(':');
  int h = int.parse(parts[0]);
  final int min = int.parse(parts[1]);
  final String period = h < 12 ? 'AM' : 'PM';
  if (h == 0) h = 12;
  else if (h > 12) h -= 12;
  return '$h:${min.toString().padLeft(2, '0')} $period';
}

bool _rangesOverlap(int aS, int aE, int bS, int bE) => aS < bE && aE > bS;

// Fixed 60-min slots from 10:00–18:00 → 8 slots
List<Map<String, String>> _generateSlots() {
  final slots = <Map<String, String>>[];
  final start = _toMin(_kWorkStart);
  final end   = _toMin(_kWorkEnd);
  for (var t = start; t + _kSlotDurationMins <= end; t += _kSlotDurationMins) {
    slots.add({'from': _fromMin(t), 'to': _fromMin(t + _kSlotDurationMins)});
  }
  return slots;
}

// ─── Main Screen ──────────────────────────────────────────────────────────────
class DoctorSelectionScreen extends StatefulWidget {
  const DoctorSelectionScreen({super.key});

  @override
  State<DoctorSelectionScreen> createState() => _DoctorSelectionScreenState();
}

class _DoctorSelectionScreenState extends State<DoctorSelectionScreen>
    with TickerProviderStateMixin {

  List<Map<String, dynamic>> _allDoctors = [];
  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;

  String? _selectedSpeciality;

  Map<String, dynamic>? _selectedDoctor;
  String _genderFilter = '';
  String _sortBy = 'default';
  final _searchCtrl = TextEditingController();

  DateTime _selectedDate     = DateTime.now();
  DateTime _calendarMonth    = DateTime.now();
  String? _selectedStartTime;
  String? _selectedEndTime;
  List<Map<String, String>> _availableSlots = [];
  List<Map<String, String>> _bookedSlots    = [];
  bool _slotsLoading = false;
  bool _slotsLoaded  = false;
  // Cache keyed by "$date-$providerId" — cleared when doctor changes
  final Map<String, List<Map<String, dynamic>>> _slotsCache = {};

  final _commentCtrl = TextEditingController();

  int _expandedStep = 1;

  late final List<AnimationController> _accordionCtrls;
  late final List<Animation<double>>   _accordionAnims;
  late final AnimationController _headerAnim;
  late final AnimationController _stepsAnim;
  late final Animation<double>   _headerFade;
  late final Animation<Offset>   _headerSlide;

  final _scrollCtrl = ScrollController();
  final _stepKeys   = [GlobalKey(), GlobalKey(), GlobalKey(), GlobalKey()];

  // Consistent with caregiver/interpreter — only date part, no time
  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _stepsAnim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _headerFade = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut));
    _headerAnim.forward();
    _stepsAnim.forward();

    _accordionCtrls = List.generate(4, (i) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: i == 0 ? 1.0 : 0.0,
    ));
    _accordionAnims = _accordionCtrls
        .map<Animation<double>>((c) => CurvedAnimation(parent: c, curve: Curves.easeInOutCubic))
        .toList();

    _loadData();
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    _stepsAnim.dispose();
    for (final c in _accordionCtrls) c.dispose();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  String _normalizeSpeciality(String raw) => _kSpecialityPrices.keys.firstWhere(
    (k) => k.toLowerCase() == raw.toLowerCase(),
    orElse: () => raw,
  );

  void _openStep(int step) {
    setState(() => _expandedStep = step);
    for (int i = 0; i < 4; i++) {
      if (i == step - 1) _accordionCtrls[i].forward();
      else _accordionCtrls[i].reverse();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _stepKeys[step - 1].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.05);
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final docs = await ApiService.getDoctors();
      final user = await SessionManager.getUser();
      if (mounted) {
        setState(() {
          _allDoctors  = docs;
          _currentUser = user;
          _isLoading   = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _snack('Connection error: $e');
    }
  }

  List<String> get _specialities {
    final seen = <String>{};
    final list = <String>[];
    for (final d in _allDoctors) {
      final normalized = _normalizeSpeciality(d['speciality']?.toString() ?? '');
      if (seen.add(normalized)) list.add(normalized);
    }
    list.sort();
    return list;
  }

  List<Map<String, dynamic>> get _filteredDoctors {
    var list = _allDoctors.where((d) {
      return _normalizeSpeciality(d['speciality']?.toString() ?? '') == _selectedSpeciality;
    }).toList();

    if (_genderFilter.isNotEmpty) {
      list = list.where((d) =>
          (d['gender'] ?? '').toString().toLowerCase().trim() == _genderFilter).toList();
    }

    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((d) =>
          (d['full_name'] ?? '').toString().toLowerCase().contains(q)).toList();
    }

    if (_sortBy == 'rating_desc') {
      list.sort((a, b) {
        final ar = double.tryParse(a['avg_rating']?.toString() ?? '0') ?? 0;
        final br = double.tryParse(b['avg_rating']?.toString() ?? '0') ?? 0;
        return br.compareTo(ar);
      });
    } else if (_sortBy == 'price_asc') {
      list.sort((a, b) => _priceFor(a['speciality']).compareTo(_priceFor(b['speciality'])));
    } else if (_sortBy == 'price_desc') {
      list.sort((a, b) => _priceFor(b['speciality']).compareTo(_priceFor(a['speciality'])));
    } else if (_sortBy == 'name_asc') {
      list.sort((a, b) => (a['full_name'] ?? '').toString().toLowerCase()
          .compareTo((b['full_name'] ?? '').toString().toLowerCase()));
    }
    return list;
  }

  Future<void> _loadSlots() async {
    if (_selectedDoctor == null) return;
    setState(() {
      _slotsLoading      = true;
      _slotsLoaded       = false;
      _availableSlots    = [];
      _bookedSlots       = [];
      _selectedStartTime = null;
      _selectedEndTime   = null;
    });

    final providerId = int.parse(_selectedDoctor!['user_id'].toString());
    final dateStr    = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final cacheKey   = '$dateStr-$providerId';

    List<Map<String, dynamic>> raw;
    if (_slotsCache.containsKey(cacheKey)) {
      raw = _slotsCache[cacheKey]!;
    } else {
      raw = await ApiService.getBookedSlots(providerId: providerId, date: dateStr);
      _slotsCache[cacheKey] = raw;
    }

    final booked = raw.map((s) => {'from': s['from'].toString(), 'to': s['to'].toString()}).toList();
    final all    = _generateSlots();
    final avail  = <Map<String, String>>[];
    final book   = <Map<String, String>>[];

    for (final slot in all) {
      final sS       = _toMin(slot['from']!);
      final sE       = _toMin(slot['to']!);
      final isBooked = booked.any((b) => _rangesOverlap(sS, sE, _toMin(b['from']!), _toMin(b['to']!)));
      if (isBooked) book.add(slot); else avail.add(slot);
    }

    if (mounted) {
      setState(() {
        _availableSlots = avail;
        _bookedSlots    = book;
        _slotsLoading   = false;
        _slotsLoaded    = true;
      });
    }
  }

  int get _currentStep {
    if (_selectedSpeciality == null) return 1;
    if (_selectedDoctor == null)     return 2;
    if (_selectedStartTime == null)  return 3;
    return 4;
  }

  String _dateStr(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                _buildSliverAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 20),
                      _buildStepsFlow(),
                      const SizedBox(height: 24),

                      // Step 1: Specialty
                      _buildAccordionStep(
                        key: _stepKeys[0],
                        stepIndex: 0,
                        stepNumber: 1,
                        title: 'Choose Specialty',
                        subtitle: 'Select the medical specialty you need first.',
                        helperText: 'Example: Cardiology, Pediatrics, Neurology.',
                        completedSummary: _selectedSpeciality != null
                            ? _buildCompletedSummary(
                                icon: _iconFor(_selectedSpeciality),
                                lines: [
                                  _selectedSpeciality!,
                                  'EGP ${_priceFor(_selectedSpeciality).toInt()} per session',
                                ])
                            : null,
                        child: _specialities.isEmpty
                            ? const _EmptyState(icon: Icons.local_hospital_rounded, message: 'No specialties found.')
                            : GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                childAspectRatio: 2.4,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                children: _specialities.map((s) {
                                  final isSel = _selectedSpeciality == s;
                                  return GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _selectedSpeciality = s;
                                        _selectedDoctor     = null;
                                        _selectedStartTime  = null;
                                        _selectedEndTime    = null;
                                        _slotsLoaded        = false;
                                        _slotsCache.clear();
                                        _genderFilter       = '';
                                        _sortBy             = 'default';
                                      });
                                      _openStep(2);
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 220),
                                      decoration: BoxDecoration(
                                        color: isSel ? _primary : Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(color: isSel ? _primary : _line, width: isSel ? 2 : 1.5),
                                        boxShadow: isSel
                                            ? [BoxShadow(color: _primary.withOpacity(0.22), blurRadius: 14, offset: const Offset(0, 6))]
                                            : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                          Container(
                                            width: 32, height: 32,
                                            decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(10),
                                                color: isSel ? Colors.white.withOpacity(0.18) : _primarySoft),
                                            alignment: Alignment.center,
                                            child: Icon(_iconFor(s), size: 17, color: isSel ? Colors.white : _accent),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(s,
                                                style: TextStyle(
                                                    color: isSel ? Colors.white : _primary,
                                                    fontWeight: FontWeight.w700, fontSize: 12),
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                          if (isSel) ...[
                                            const SizedBox(width: 4),
                                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 15),
                                          ],
                                        ]),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),

                      const SizedBox(height: 16),

                      // Step 2: Doctor
                      _buildAccordionStep(
                        key: _stepKeys[1],
                        stepIndex: 1,
                        stepNumber: 2,
                        title: 'Pick a Doctor',
                        subtitle: 'Compare doctors and choose the one that suits you best.',
                        helperText: 'You can filter by rating, price, gender, or name.',
                        completedSummary: _selectedDoctor != null
                            ? _buildCompletedSummary(
                                icon: Icons.person_rounded,
                                lines: [
                                  _selectedDoctor!['full_name']?.toString() ?? '',
                                  _selectedDoctor!['speciality']?.toString() ?? '',
                                ])
                            : null,
                        child: Column(children: [
                          _buildDoctorFilters(),
                          const SizedBox(height: 16),
                          if (_selectedSpeciality == null)
                            const _EmptyState(icon: Icons.person_search_rounded,
                                message: 'Select a specialty first to see available doctors.')
                          else if (_filteredDoctors.isEmpty)
                            const _EmptyState(icon: Icons.person_off_rounded,
                                message: 'No doctors found with the selected filters.')
                          else
                            Column(children: _filteredDoctors.map(_buildDoctorCard).toList()),
                        ]),
                      ),

                      const SizedBox(height: 16),

                      // Step 3: Date & Time
                      _buildAccordionStep(
                        key: _stepKeys[2],
                        stepIndex: 2,
                        stepNumber: 3,
                        title: 'Choose Date & Time',
                        subtitle: 'Select the day you want, then pick an available time slot.',
                        helperText: 'Green slots are available for booking.',
                        completedSummary: _selectedStartTime != null
                            ? _buildCompletedSummary(
                                icon: Icons.calendar_month_rounded,
                                lines: [
                                  DateFormat('MMM dd, yyyy').format(_selectedDate),
                                  '${_toAmPm(_selectedStartTime!)} – ${_toAmPm(_selectedEndTime!)}',
                                ])
                            : null,
                        child: Column(children: [
                          _buildCalendar(),
                          if (_selectedDoctor != null && _slotsLoading) ...[
                            const SizedBox(height: 16),
                            const Center(child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(color: _primary))),
                          ],
                          if (_selectedDoctor != null && _slotsLoaded) ...[
                            const SizedBox(height: 16),
                            _buildSlotsPanel(),
                          ],
                          if (_selectedDoctor == null) ...[
                            const SizedBox(height: 16),
                            const _EmptyState(icon: Icons.calendar_month_rounded,
                                message: 'Choose a doctor first to see available slots.'),
                          ],
                        ]),
                      ),

                      const SizedBox(height: 16),

                      // Step 4: Review & Confirm
                      _buildAccordionStep(
                        key: _stepKeys[3],
                        stepIndex: 3,
                        stepNumber: 4,
                        title: 'Review & Confirm',
                        subtitle: 'Check your details and send the booking request.',
                        helperText: 'Your saved information appears automatically.',
                        child: Column(children: [
                          _buildPatientInfo(),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _commentCtrl,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Enter specific requirements or symptoms...',
                              hintStyle: const TextStyle(color: _muted, fontSize: 13),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: const BorderSide(color: _line)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: const BorderSide(color: _line)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: const BorderSide(color: _primary, width: 1.5)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity, height: 58,
                            child: ElevatedButton(
                              onPressed: _submitBooking,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: _primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  elevation: 6,
                                  shadowColor: _primary.withOpacity(0.35)),
                              child: const Text('Continue to Payment',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAccordionStep({
    required Key key,
    required int stepIndex,
    required int stepNumber,
    required String title,
    required String subtitle,
    String? helperText,
    required Widget child,
    Widget? completedSummary,
  }) {
    final isExpanded  = _expandedStep == stepNumber;
    final isCompleted = _currentStep > stepNumber;
    final isLocked    = stepNumber > _currentStep && !isExpanded;

    return Container(
      key: key,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isExpanded ? _accent : isCompleted ? _accentLight.withOpacity(0.5) : _line,
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(
          color: isExpanded ? _accent.withOpacity(0.10) : Colors.black.withOpacity(0.04),
          blurRadius: isExpanded ? 22 : 12,
          offset: const Offset(0, 6),
        )],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isExpanded
                    ? [_accent, _accentLight]
                    : isCompleted
                        ? [_accentLight.withOpacity(0.5), _accentLight.withOpacity(0.3)]
                        : [_line, _line],
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              if (isExpanded) return;
              if (isLocked) {
                final msgs = [
                  'Please select a specialty first.',
                  'Please select a specialty and doctor first.',
                  'Please select a date and time slot first.',
                ];
                _snack(msgs[(stepNumber - 2).clamp(0, 2)]);
                return;
              }
              _openStep(stepNumber);
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: isExpanded || isCompleted
                        ? const LinearGradient(colors: [_accent, _accentLight])
                        : null,
                    color: isExpanded || isCompleted ? null : const Color(0xFFEEEEF5),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: isExpanded || isCompleted
                        ? [BoxShadow(color: _accent.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))]
                        : null,
                  ),
                  child: Center(
                    child: isCompleted && !isExpanded
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                        : Text('$stepNumber',
                            style: TextStyle(
                              color: isExpanded ? Colors.white : _muted,
                              fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title,
                        style: TextStyle(
                          color: isExpanded ? _primary : isCompleted ? _accent : _muted,
                          fontWeight: FontWeight.w800, fontSize: 16,
                        )),
                    if (isExpanded) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
                      if (helperText != null) ...[
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.info_outline_rounded, size: 11, color: _accentLight),
                          const SizedBox(width: 4),
                          Flexible(child: Text(helperText,
                              style: const TextStyle(color: _accentLight, fontSize: 11, fontWeight: FontWeight.w600))),
                        ]),
                      ],
                    ] else if (isCompleted && completedSummary != null)
                      completedSummary
                    else
                      Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
                  ]),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  child: Icon(
                    isLocked ? Icons.lock_outline_rounded : Icons.keyboard_arrow_down_rounded,
                    color: isExpanded ? _accent : _muted,
                    size: 22,
                  ),
                ),
              ]),
            ),
          ),
          SizeTransition(
            sizeFactor: _accordionAnims[stepIndex],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1, color: _line),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedSummary({required IconData icon, required List<String> lines}) {
    return Row(children: [
      Icon(icon, size: 13, color: _accentLight),
      const SizedBox(width: 5),
      Expanded(
        child: Text(
          lines.where((l) => l.isNotEmpty).join('  ·  '),
          style: const TextStyle(color: _accentLight, fontSize: 12, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ]);
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 170,
      pinned: true,
      backgroundColor: _primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryDark, _accent]),
          ),
          child: Stack(children: [
            Positioned(top: -40, right: -40,
                child: Container(width: 160, height: 160,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.06)))),
            Positioned(bottom: -30, left: -20,
                child: Container(width: 120, height: 120,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.04)))),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                child: FadeTransition(
                  opacity: _headerFade,
                  child: SlideTransition(
                    position: _headerSlide,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white.withOpacity(0.2))),
                          child: const Text('Doctor booking',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        ),
                        const SizedBox(height: 8),
                        const Text('Book a Doctor',
                            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        Text('Choose specialty → doctor → appointment',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildStepsFlow() {
    final steps = [
      {'icon': Icons.local_hospital_rounded,       'title': 'Specialty', 'sub': 'Select what you need'},
      {'icon': Icons.person_search_rounded,         'title': 'Doctor',    'sub': 'Compare & choose'},
      {'icon': Icons.calendar_month_rounded,        'title': 'Schedule',  'sub': 'Pick a slot'},
      {'icon': Icons.check_circle_outline_rounded,  'title': 'Confirm',   'sub': 'Review & submit'},
    ];
    return SizedBox(
      height: 108,
      child: Row(
        children: List.generate(steps.length, (i) {
          final stepNum  = i + 1;
          final isDone   = _currentStep > stepNum;
          final isActive = _currentStep == stepNum;
          return Expanded(
            child: AnimatedBuilder(
              animation: _stepsAnim,
              builder: (_, child) {
                final delay = i * 0.15;
                final t = Curves.easeOut.transform(
                    ((_stepsAnim.value - delay) / (1 - delay)).clamp(0.0, 1.0));
                return Opacity(opacity: t,
                    child: Transform.translate(offset: Offset(0, 20 * (1 - t)), child: child));
              },
              child: GestureDetector(
                onTap: () { if (isDone || isActive) _openStep(stepNum); },
                child: _StepChip(
                    number: stepNum,
                    icon: steps[i]['icon'] as IconData,
                    title: steps[i]['title'] as String,
                    sub: steps[i]['sub'] as String,
                    isDone: isDone,
                    isActive: isActive,
                    isLast: i == steps.length - 1),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDoctorFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by doctor name...',
            hintStyle: const TextStyle(color: _muted, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 20),
            filled: true,
            fillColor: _primarySoft,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [('All', ''), ('Male', 'male'), ('Female', 'female')].map((t) =>
              _FilterChip(label: t.$1, selected: _genderFilter == t.$2,
                  onTap: () => setState(() => _genderFilter = t.$2))).toList(),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _line)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sortBy,
              isExpanded: true,
              style: const TextStyle(color: _primary, fontSize: 13, fontWeight: FontWeight.w700),
              items: const [
                DropdownMenuItem(value: 'default',     child: Text('Default')),
                DropdownMenuItem(value: 'rating_desc', child: Text('Top Rated')),
                DropdownMenuItem(value: 'price_asc',   child: Text('Low Price')),
                DropdownMenuItem(value: 'price_desc',  child: Text('High Price')),
                DropdownMenuItem(value: 'name_asc',    child: Text('A–Z')),
              ],
              onChanged: (v) => setState(() => _sortBy = v ?? 'default'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> doc) {
    final isSelected = _selectedDoctor?['user_id'] == doc['user_id'];
    final speciality = _normalizeSpeciality(doc['speciality']?.toString() ?? 'General');
    final gender     = (doc['gender'] ?? '').toString().toLowerCase().trim();
    final rating     = doc['rating']?.toString() ?? 'New';
    final price      = _priceFor(speciality);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedDoctor    = doc;
          _selectedStartTime = null;
          _selectedEndTime   = null;
          _slotsLoaded       = false;
          // Clear cache for this doctor so we always get fresh data
          _slotsCache.clear();
        });
        _loadSlots().then((_) => _openStep(3));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: isSelected ? _primary : _line, width: isSelected ? 2.5 : 1.5),
          boxShadow: [BoxShadow(
              color: isSelected ? _primary.withOpacity(0.12) : Colors.black.withOpacity(0.04),
              blurRadius: isSelected ? 20 : 10,
              offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: _primarySoft,
                border: Border.all(color: _line)),
            child: Center(child: Icon(
              gender == 'female' ? Icons.face_3_rounded
                  : gender == 'male' ? Icons.face_rounded
                  : Icons.person_rounded,
              size: 36, color: _accent,
            )),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doc['full_name'] ?? 'Doctor',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _primary, fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(_iconFor(speciality), size: 13, color: _accentLight),
                const SizedBox(width: 4),
                Flexible(child: Text(speciality,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 12))),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _Pill(Icons.star_rounded, rating),
                _Pill(Icons.payments_outlined, 'EGP ${price.toInt()}'),
                if (gender.isNotEmpty)
                  _Pill(
                    gender == 'female' ? Icons.female_rounded : Icons.male_rounded,
                    gender == 'female' ? 'Female' : 'Male',
                  ),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isSelected
                ? const Icon(Icons.check_circle_rounded, key: ValueKey('c'), color: _primary, size: 28)
                : Icon(Icons.radio_button_off_rounded, key: const ValueKey('u'), color: Colors.grey.shade300, size: 28),
          ),
        ]),
      ),
    );
  }

  Widget _buildCalendar() {
    final y           = _calendarMonth.year;
    final m           = _calendarMonth.month;
    final firstDay    = DateTime(y, m, 1).weekday % 7;
    final daysInMonth = DateTime(y, m + 1, 0).day;
    final today       = _today;
    final monthName   = DateFormat('MMMM yyyy').format(_calendarMonth);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _line),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(children: [
        Row(children: [
          _CalNavBtn(icon: Icons.chevron_left_rounded,
              onTap: () => setState(() => _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1))),
          Expanded(child: Text(monthName, textAlign: TextAlign.center,
              style: const TextStyle(color: _primary, fontWeight: FontWeight.w800, fontSize: 16))),
          _CalNavBtn(icon: Icons.chevron_right_rounded,
              onTap: () => setState(() => _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1))),
        ]),
        const SizedBox(height: 14),
        Row(children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
            .map((d) => Expanded(child: Text(d, textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, fontWeight: FontWeight.w700, fontSize: 12))))
            .toList()),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6, childAspectRatio: 1),
          itemCount: firstDay + daysInMonth,
          itemBuilder: (_, idx) {
            if (idx < firstDay) return const SizedBox();
            final day     = idx - firstDay + 1;
            final date    = DateTime(y, m, day);
            final isPast  = date.isBefore(today);
            final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
            final isSel   = _dateStr(_selectedDate) == _dateStr(date);

            return GestureDetector(
              onTap: isPast ? null : () {
                if (_selectedDoctor == null) { _snack('Choose a doctor first.'); return; }
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedDate      = date;
                  _selectedStartTime = null;
                  _selectedEndTime   = null;
                });
                _loadSlots();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isPast ? const Color(0xFFF3F4F8) : isSel ? _primary : isToday ? _primarySoft : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSel ? _primary : isToday ? _accentLight : _line, width: isSel ? 2 : 1),
                  boxShadow: isSel ? [BoxShadow(color: _primary.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))] : null,
                ),
                child: Center(child: Text('$day', style: TextStyle(
                    color: isPast ? const Color(0xFFB0B4C4) : isSel ? Colors.white : _primary,
                    fontWeight: isSel || isToday ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13))),
              ),
            );
          },
        ),
      ]),
    );
  }

  Widget _buildSlotsPanel() {
    final speciality = _normalizeSpeciality(_selectedDoctor?['speciality']?.toString() ?? 'General');
    final price      = _priceFor(speciality);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _line),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: _primarySoft, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(_iconFor(speciality), size: 18, color: _accent),
              const SizedBox(width: 8),
              Expanded(child: Text(
                '${_selectedDoctor!['full_name']}  ·  ${DateFormat('MMM d').format(_selectedDate)}  ·  ${_toAmPm(_kWorkStart)} – ${_toAmPm(_kWorkEnd)}',
                style: const TextStyle(color: _primary, fontSize: 12, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis)),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Available Appointments',
                    style: TextStyle(color: _primary, fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                // Fixed 60-min sessions — no variable duration for doctors
                Text('1-hour session  ·  EGP ${price.toInt()} per appointment',
                    style: const TextStyle(color: _muted, fontSize: 12)),
              ]),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Container(width: 10, height: 10,
                decoration: BoxDecoration(
                    color: _greenSoft,
                    border: Border.all(color: _greenLine),
                    borderRadius: BorderRadius.circular(999))),
            const SizedBox(width: 6),
            const Text('Tap a green slot to select your appointment',
                style: TextStyle(color: _muted, fontSize: 12)),
          ]),
          const SizedBox(height: 14),
          _availableSlots.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _primarySoft, borderRadius: BorderRadius.circular(12)),
                  child: const Row(children: [
                    Icon(Icons.info_outline_rounded, color: _muted, size: 16),
                    SizedBox(width: 8),
                    Flexible(child: Text('No available appointments on this day.',
                        style: TextStyle(color: _muted, fontSize: 13))),
                  ]))
              : Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _availableSlots.map((slot) {
                    final isSel = _selectedStartTime == slot['from'];
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedStartTime = slot['from'];
                          _selectedEndTime   = slot['to'];
                        });
                        _openStep(4);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                            color: isSel ? _primary : _greenSoft,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: isSel ? _primary : _greenLine, width: isSel ? 2 : 1),
                            boxShadow: isSel ? [BoxShadow(color: _primary.withOpacity(0.22), blurRadius: 10, offset: const Offset(0, 4))] : null),
                        child: Text('${_toAmPm(slot['from']!)} – ${_toAmPm(slot['to']!)}',
                            style: TextStyle(
                                color: isSel ? Colors.white : _green,
                                fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                    );
                  }).toList(),
                ),

          if (_bookedSlots.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: _line),
            const SizedBox(height: 12),
            const Text('Already Booked',
                style: TextStyle(color: _primary, fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8,
                children: _bookedSlots.map((slot) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                      color: _redSoft,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _redLine)),
                  child: Text('${_toAmPm(slot['from']!)} – ${_toAmPm(slot['to']!)}',
                      style: const TextStyle(color: _red, fontWeight: FontWeight.w800, fontSize: 13)),
                )).toList()),
          ],

          if (_selectedStartTime != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: _primarySoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SummaryRow('Doctor',    _selectedDoctor?['full_name'] ?? '–'),
                _SummaryRow('Specialty', speciality),
                _SummaryRow('Date',      DateFormat('MMM dd, yyyy').format(_selectedDate)),
                _SummaryRow('Time',      '${_toAmPm(_selectedStartTime!)} – ${_toAmPm(_selectedEndTime!)}'),
                _SummaryRow('Fee',       'EGP ${price.toInt()}'),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPatientInfo() {
    final name = '${_currentUser?['firstName'] ?? ''} ${_currentUser?['lastName'] ?? ''}'.trim();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: _primarySoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line)),
      child: Column(children: [
        _InfoRow(label: 'Patient',    value: name.isEmpty ? 'Unknown' : name),
        const Divider(color: _line, height: 18),
        _InfoRow(label: 'Email',      value: _currentUser?['email'] ?? '—'),
        const Divider(color: _line, height: 18),
        _InfoRow(label: 'Phone',      value: _currentUser?['phone'] ?? '—'),
        const Divider(color: _line, height: 18),
        _InfoRow(label: 'Disability', value: _currentUser?['disability'] ?? 'None'),
        const Divider(color: _line, height: 18),
        Row(children: [
          Expanded(child: _InfoRow(label: 'Address', value: _currentUser?['address'] ?? '—')),
          GestureDetector(
            onTap: _showEditProfileDialog,
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('Edit',
                    style: TextStyle(color: _primary, fontWeight: FontWeight.w900, fontSize: 13))),
          ),
        ]),
      ]),
    );
  }

  void _submitBooking() {
    if (_selectedSpeciality == null) return _snack('Please select a specialty first.');
    if (_selectedDoctor == null)     return _snack('Please select a doctor.');
    if (_selectedStartTime == null)  return _snack('Please select an available appointment slot.');
    // Consistent past-date guard with caregiver/interpreter
    if (_selectedDate.isBefore(_today)) return _snack('Past dates cannot be booked.');

    final doc      = _selectedDoctor!;
    final price    = _priceFor(_normalizeSpeciality(doc['speciality']?.toString() ?? ''));
    final dateStr  = _dateStr(_selectedDate);

    final fullName  = doc['full_name']?.toString() ?? '';
    final nameParts = fullName.trim().split(' ');
    final firstName = doc['first_name']?.toString().isNotEmpty == true
        ? doc['first_name'].toString()
        : (nameParts.isNotEmpty ? nameParts.first : '');
    final lastName  = doc['last_name']?.toString().isNotEmpty == true
        ? doc['last_name'].toString()
        : (nameParts.length > 1 ? nameParts.skip(1).join(' ') : '');

    Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(bookingData: {
      'service_type':   'Doctor',
      'patient_id':     _currentUser?['user_id'],
      'provider_id':    int.parse(doc['user_id'].toString()),
      'fullname':       '${_currentUser?['firstName'] ?? ''} ${_currentUser?['lastName'] ?? ''}'.trim(),
      'phone':          _currentUser?['phone'],
      'email':          _currentUser?['email'],
      'address':        _currentUser?['address'] ?? 'Clinic',
      'date':           dateStr,
      'booking_time':   '$_selectedStartTime:00',
      'service_time':   '$_selectedEndTime:00',
      'start_at':       '$dateStr $_selectedStartTime:00',
      'end_at':         '$dateStr $_selectedEndTime:00',
      'payment_total':  price,
      'payment_status': 'Pending',
      'status':         'pending',
      'comment':        _commentCtrl.text,
      'first_name':     firstName,
      'last_name':      lastName,
      'doctor_name':    fullName,
    })));
  }

  void _showEditProfileDialog() {
    final fCtrl = TextEditingController(text: _currentUser?['firstName']);
    final lCtrl = TextEditingController(text: _currentUser?['lastName']);
    final eCtrl = TextEditingController(text: _currentUser?['email']);
    final pCtrl = TextEditingController(text: _currentUser?['phone']);
    final aCtrl = TextEditingController(text: _currentUser?['address']);
    String tempDisability = _currentUser?['disability'] ?? 'None';
    final options = ['Visual impairment', 'Hearing impairment', 'Physical disability', 'Other', 'None'];

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Edit Details', style: TextStyle(color: _primary, fontWeight: FontWeight.w900)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: fCtrl, decoration: const InputDecoration(labelText: 'First Name')),
        TextField(controller: lCtrl, decoration: const InputDecoration(labelText: 'Last Name')),
        TextField(controller: eCtrl, decoration: const InputDecoration(labelText: 'Email')),
        TextField(controller: pCtrl, decoration: const InputDecoration(labelText: 'Phone')),
        TextField(controller: aCtrl, decoration: const InputDecoration(labelText: 'Address')),
        const SizedBox(height: 16),
        DropdownButton<String>(
            value: options.contains(tempDisability) ? tempDisability : 'Other',
            isExpanded: true,
            items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setD(() => tempDisability = v!)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () async {
            final update = {
              'user_id':    _currentUser?['user_id'],
              'first_name': fCtrl.text,
              'last_name':  lCtrl.text,
              'email':      eCtrl.text,
              'phone':      pCtrl.text,
              'address':    aCtrl.text,
              'disability': tempDisability,
            };
            await ApiService.updatePatientProfile(update);
            final next = {
              ..._currentUser!,
              'firstName':  fCtrl.text,
              'lastName':   lCtrl.text,
              'email':      eCtrl.text,
              'phone':      pCtrl.text,
              'address':    aCtrl.text,
              'disability': tempDisability,
            };
            await SessionManager.saveUser(next);
            if (mounted) setState(() => _currentUser = next);
            if (mounted) Navigator.pop(ctx);
            _snack('Details updated!');
          },
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    )));
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.number, required this.icon, required this.title,
    required this.sub, required this.isDone, required this.isActive, required this.isLast,
  });
  final int number;
  final IconData icon;
  final String title, sub;
  final bool isDone, isActive, isLast;

  @override
  Widget build(BuildContext context) {
    final bgColor     = isDone ? _primarySoft : Colors.white;
    final borderColor = isDone ? _accentLight : isActive ? _primary : _line;
    final numBg       = isDone || isActive ? _primary : Colors.grey.shade200;
    final numFg       = isDone || isActive ? Colors.white : _muted;
    return Padding(
      padding: EdgeInsets.only(right: isLast ? 0 : 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: isActive
                ? [BoxShadow(color: _primary.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))]
                : null),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 26, height: 26,
                decoration: BoxDecoration(color: numBg, borderRadius: BorderRadius.circular(8)),
                child: Center(child: isDone
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                    : Text('$number', style: TextStyle(color: numFg, fontWeight: FontWeight.w900, fontSize: 12)))),
            Icon(icon, size: 18, color: isDone || isActive ? _accent : _muted),
          ]),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(title,
                style: TextStyle(
                    color: isActive || isDone ? _primary : _muted,
                    fontWeight: FontWeight.w800, fontSize: 11)),
          ),
        ]),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label; final bool selected; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
          color: selected ? _primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? _primary : _line, width: 1.5)),
      child: Text(label, style: TextStyle(
          color: selected ? Colors.white : _primary,
          fontWeight: FontWeight.w700, fontSize: 12)),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _line)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: _accentLight),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: _accent, fontWeight: FontWeight.w700, fontSize: 11)),
    ]),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon; final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24), alignment: Alignment.center,
    child: Column(children: [
      Icon(icon, color: Colors.grey.shade300, size: 40),
      const SizedBox(height: 10),
      Text(message, textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 13)),
    ]),
  );
}

class _CalNavBtn extends StatelessWidget {
  const _CalNavBtn({required this.icon, required this.onTap});
  final IconData icon; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 38, height: 38,
        decoration: BoxDecoration(color: _primarySoft, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: _primary, size: 22)),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(children: [
      Text('$label: ', style: const TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w500)),
      Expanded(child: Text(value,
          style: const TextStyle(color: _primary, fontSize: 13, fontWeight: FontWeight.w700))),
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Row(children: [
    Text('$label: ', style: const TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w500)),
    Expanded(child: Text(value,
        style: const TextStyle(color: _primary, fontSize: 13, fontWeight: FontWeight.w700),
        overflow: TextOverflow.ellipsis)),
  ]);
}