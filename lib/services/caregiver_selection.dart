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

const _kWorkStart     = '10:00';
const _kWorkEnd       = '18:00';
const _kSlotDuration  = 30;
const _kHalfHourRate  = 150.0;
const _kMaxDuration   = 480;

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
  final String mm = min.toString().padLeft(2, '0');
  return '$h:$mm $period';
}

bool _rangesOverlap(int aS, int aE, int bS, int bE) => aS < bE && aE > bS;

List<Map<String, String>> _generateSlots() {
  final slots = <Map<String, String>>[];
  final start = _toMin(_kWorkStart);
  final end   = _toMin(_kWorkEnd);
  for (var t = start; t + _kSlotDuration <= end; t += _kSlotDuration) {
    slots.add({'from': _fromMin(t), 'to': _fromMin(t + _kSlotDuration)});
  }
  return slots;
}

IconData _shiftIcon(String shift) {
  final s = shift.toLowerCase();
  if (s.contains('morning')) return Icons.wb_sunny_rounded;
  if (s.contains('evening')) return Icons.nights_stay_rounded;
  if (s.contains('night'))   return Icons.bedtime_rounded;
  return Icons.handshake_rounded;
}

String _formatDuration(int minutes) {
  if (minutes < 60) return '$minutes minutes';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return '$h hour${h > 1 ? 's' : ''}';
  return '$h hour${h > 1 ? 's' : ''} $m minutes';
}

double _calcTotal(int durationMinutes) =>
    (durationMinutes / 30).ceil() * _kHalfHourRate;

// ─── Main Screen ──────────────────────────────────────────────────────────────
class CaregiverSelectionScreen extends StatefulWidget {
  const CaregiverSelectionScreen({super.key});

  @override
  State<CaregiverSelectionScreen> createState() =>
      _CaregiverSelectionScreenState();
}

class _CaregiverSelectionScreenState extends State<CaregiverSelectionScreen>
    with TickerProviderStateMixin {

  List<dynamic> _allCaregivers = [];
  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;

  dynamic _selectedCaregiver;
  String _genderFilter = '';
  String _sortBy = 'default';
  final _searchCtrl = TextEditingController();

  DateTime _selectedDate  = DateTime.now();
  DateTime _calendarMonth = DateTime.now();
  String? _selectedStartTime;
  String? _selectedEndTime;
  int _selectedDuration = 30;
  List<Map<String, String>> _availableSlots = [];
  List<Map<String, String>> _bookedSlots    = [];
  bool _slotsLoading = false;
  bool _slotsLoaded  = false;
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
  final _stepKeys   = [GlobalKey(), GlobalKey(), GlobalKey()];

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  // Duration options matching PHP exactly
  static const _durationOptions = [
    30, 60, 90, 120, 150, 180, 210, 240,
    270, 300, 330, 360, 390, 420, 450, 480,
  ];

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _stepsAnim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _headerFade  = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut));
    _headerAnim.forward();
    _stepsAnim.forward();

    _accordionCtrls = List.generate(3, (i) => AnimationController(
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

  void _openStep(int step) {
    setState(() => _expandedStep = step);
    for (int i = 0; i < 3; i++) {
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
      final results = await Future.wait([ApiService.getCaregivers(), SessionManager.getUser()]);
      if (mounted) {
        setState(() {
          _allCaregivers = results[0] as List<dynamic>;
          _currentUser   = results[1] as Map<String, dynamic>?;
          _isLoading     = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _snack('Connection error: $e');
    }
  }

  List<dynamic> get _filteredCaregivers {
    var list = List<dynamic>.from(_allCaregivers);
    if (_genderFilter.isNotEmpty) {
      list = list.where((c) {
        final g = (c['gender'] ?? c['sex'] ?? '').toString().toLowerCase().trim();
        return g == _genderFilter;
      }).toList();
    }
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) =>
          (c['full_name'] ?? '').toString().toLowerCase().contains(q)).toList();
    }
    if (_sortBy == 'rating_desc') {
      list.sort((a, b) {
        final ar = double.tryParse(a['avg_rating']?.toString() ?? '0') ?? 0;
        final br = double.tryParse(b['avg_rating']?.toString() ?? '0') ?? 0;
        return br.compareTo(ar);
      });
    } else if (_sortBy == 'name_asc') {
      list.sort((a, b) => (a['full_name'] ?? '').toString().toLowerCase()
          .compareTo((b['full_name'] ?? '').toString().toLowerCase()));
    }
    return list;
  }

  // Check if a start slot is usable for the selected duration
  bool _canUseSlot(Map<String, String> slot) {
    final start   = _toMin(slot['from']!);
    final end     = start + _selectedDuration;
    final workEnd = _toMin(_kWorkEnd);
    if (end > workEnd) return false;
    for (final b in _bookedSlots) {
      if (_rangesOverlap(start, end, _toMin(b['from']!), _toMin(b['to']!))) return false;
    }
    return true;
  }

  Future<void> _loadSlots() async {
    if (_selectedCaregiver == null) return;
    setState(() {
      _slotsLoading      = true;
      _slotsLoaded       = false;
      _availableSlots    = [];
      _bookedSlots       = [];
      _selectedStartTime = null;
      _selectedEndTime   = null;
    });

    final providerId = int.parse(_selectedCaregiver!['user_id'].toString());
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
    final book   = <Map<String, String>>[];

    // Collect all booked ranges
    for (final slot in all) {
      final sS       = _toMin(slot['from']!);
      final sE       = _toMin(slot['to']!);
      final isBooked = booked.any((b) => _rangesOverlap(sS, sE, _toMin(b['from']!), _toMin(b['to']!)));
      if (isBooked) book.add(slot);
    }

    if (mounted) {
      setState(() {
        _bookedSlots  = book;
        _slotsLoading = false;
        _slotsLoaded  = true;
      });
      _rebuildAvailableSlots();
    }
  }

  // Rebuild available slots based on current duration — mirrors PHP canUseSlotForDuration
  void _rebuildAvailableSlots() {
    final all   = _generateSlots();
    final avail = <Map<String, String>>[];
    for (final slot in all) {
      if (_canUseSlot(slot)) avail.add(slot);
    }
    setState(() {
      _availableSlots = avail;
      // If previously selected start no longer fits, clear it
      if (_selectedStartTime != null) {
        final stillValid = avail.any((s) => s['from'] == _selectedStartTime);
        if (!stillValid) {
          _selectedStartTime = null;
          _selectedEndTime   = null;
        } else {
          // Recalculate end time based on new duration
          _selectedEndTime = _fromMin(_toMin(_selectedStartTime!) + _selectedDuration);
        }
      }
    });
  }

  int get _currentStep {
    if (_selectedCaregiver == null) return 1;
    if (_selectedStartTime == null) return 2;
    return 3;
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

                      _buildAccordionStep(
                        key: _stepKeys[0],
                        stepIndex: 0,
                        stepNumber: 1,
                        title: 'Choose Caregiver',
                        subtitle: 'Pick the caregiver that suits your need.',
                        helperText: 'You can compare by rating, shift, and gender.',
                        completedSummary: _selectedCaregiver != null
                            ? _buildCompletedSummary(
                                icon: Icons.person_rounded,
                                lines: [
                                  _selectedCaregiver!['full_name']?.toString() ?? '',
                                  (_selectedCaregiver!['shift_preference'] ?? _selectedCaregiver!['shift'] ?? 'Flexible').toString(),
                                ])
                            : null,
                        child: Column(children: [
                          _buildCaregiverFilters(),
                          const SizedBox(height: 16),
                          _filteredCaregivers.isEmpty
                              ? const _EmptyState(
                                  icon: Icons.person_search_rounded,
                                  message: 'No caregivers found.')
                              : Column(children: _filteredCaregivers.map(_buildCaregiverCard).toList()),
                        ]),
                      ),

                      const SizedBox(height: 16),

                      _buildAccordionStep(
                        key: _stepKeys[1],
                        stepIndex: 1,
                        stepNumber: 2,
                        title: 'Choose Date & Time',
                        subtitle: 'Select duration, then pick a day and available slot.',
                        helperText: 'Green means available. Duration affects which slots are shown.',
                        completedSummary: _selectedStartTime != null
                            ? _buildCompletedSummary(
                                icon: Icons.calendar_month_rounded,
                                lines: [
                                  DateFormat('MMM dd, yyyy').format(_selectedDate),
                                  '${_toAmPm(_selectedStartTime!)} – ${_toAmPm(_selectedEndTime!)}',
                                  _formatDuration(_selectedDuration),
                                  'EGP ${_calcTotal(_selectedDuration).toInt()}',
                                ])
                            : null,
                        child: Column(children: [
                          _buildDurationPicker(),
                          const SizedBox(height: 16),
                          _buildCalendar(),
                          if (_selectedCaregiver != null && _slotsLoading) ...[
                            const SizedBox(height: 16),
                            const Center(child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(color: _primary))),
                          ],
                          if (_selectedCaregiver != null && _slotsLoaded) ...[
                            const SizedBox(height: 16),
                            _buildSlotsPanel(),
                          ],
                          if (_selectedCaregiver == null) ...[
                            const SizedBox(height: 16),
                            const _EmptyState(
                                icon: Icons.calendar_month_rounded,
                                message: 'Choose a caregiver first to see available slots.'),
                          ],
                        ]),
                      ),

                      const SizedBox(height: 16),

                      _buildAccordionStep(
                        key: _stepKeys[2],
                        stepIndex: 2,
                        stepNumber: 3,
                        title: 'Review & Confirm',
                        subtitle: 'Send the booking request and wait for confirmation.',
                        helperText: 'The request status starts as pending.',
                        child: Column(children: [
                          _buildPatientInfo(),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _commentCtrl,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Enter specific care requirements (required)...',
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

  // ── Duration Picker ───────────────────────────────────────────────────────────
  Widget _buildDurationPicker() {
    final total = _calcTotal(_selectedDuration);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Session Duration',
            style: TextStyle(color: _primary, fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 4),
        const Text('150 EGP per 30 minutes · max 8 hours',
            style: TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _line)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedDuration,
              isExpanded: true,
              style: const TextStyle(color: _primary, fontSize: 14, fontWeight: FontWeight.w700),
              items: _durationOptions.map((mins) => DropdownMenuItem(
                value: mins,
                child: Text(_formatDuration(mins)),
              )).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _selectedDuration  = v;
                  _selectedStartTime = null;
                  _selectedEndTime   = null;
                });
                if (_slotsLoaded) _rebuildAvailableSlots();
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line)),
          child: Row(children: [
            const Icon(Icons.payments_outlined, size: 16, color: _accent),
            const SizedBox(width: 8),
            Text(
              '${_formatDuration(_selectedDuration)}  ·  EGP ${total.toInt()}',
              style: const TextStyle(color: _accent, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Accordion Step Card ───────────────────────────────────────────────────────
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
                  'Please select a caregiver first.',
                  'Please select a date and time slot first.',
                ];
                _snack(msgs[(stepNumber - 2).clamp(0, 1)]);
                return;
              }
              _openStep(stepNumber);
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              child: Row(
                children: [
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
                ],
              ),
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

  // ── Sliver App Bar ────────────────────────────────────────────────────────────
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
                          child: const Text('Caregiver booking',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        ),
                        const SizedBox(height: 8),
                        const Text('Book a Caregiver',
                            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                        const SizedBox(height: 2),
                        Text('150 EGP per 30 min · up to 8 hours',
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

  // ── Steps flow ────────────────────────────────────────────────────────────────
  Widget _buildStepsFlow() {
    final steps = [
      {'icon': Icons.handshake_rounded,            'title': 'Caregiver', 'sub': 'Pick one'},
      {'icon': Icons.calendar_month_rounded,       'title': 'Schedule',  'sub': 'Pick a slot'},
      {'icon': Icons.check_circle_outline_rounded, 'title': 'Confirm',   'sub': 'Review & submit'},
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
                final delay = i * 0.18;
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

  // ── Caregiver filters ─────────────────────────────────────────────────────────
  Widget _buildCaregiverFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by caregiver name...',
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
              _FilterChip(
                  label: t.$1,
                  selected: _genderFilter == t.$2,
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
                DropdownMenuItem(value: 'name_asc',    child: Text('A–Z')),
              ],
              onChanged: (v) => setState(() => _sortBy = v ?? 'default'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaregiverCard(dynamic cg) {
    final isSelected = _selectedCaregiver != null &&
        _selectedCaregiver['user_id'] == cg['user_id'];
    final shift  = (cg['shift_preference'] ?? cg['shift'] ?? 'Flexible').toString();
    final rating = cg['avg_rating']?.toString() ?? cg['rating']?.toString() ?? 'New';
    final gender = (cg['gender'] ?? cg['sex'] ?? '').toString().toLowerCase().trim();

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedCaregiver = cg;
          _selectedStartTime = null;
          _selectedEndTime   = null;
          _slotsLoaded       = false;
          _slotsCache.clear();
        });
        _loadSlots().then((_) => _openStep(2));
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
              Text(cg['full_name'] ?? 'Caregiver',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _primary, fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(_shiftIcon(shift), size: 13, color: _accentLight),
                const SizedBox(width: 4),
                Flexible(child: Text(shift,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 12))),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _Pill(Icons.star_rounded, rating),
                _Pill(Icons.payments_outlined, '150 EGP / 30 min'),
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

  // ── Calendar ──────────────────────────────────────────────────────────────────
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
                if (_selectedCaregiver == null) { _snack('Choose a caregiver first.'); return; }
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

  // ── Slots panel ───────────────────────────────────────────────────────────────
  Widget _buildSlotsPanel() {
    final shift = (_selectedCaregiver?['shift_preference'] ?? _selectedCaregiver?['shift'] ?? 'Flexible').toString();
    final total = _calcTotal(_selectedDuration);

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
              Icon(_shiftIcon(shift), size: 18, color: _accent),
              const SizedBox(width: 8),
              Expanded(child: Text(
                '${_selectedCaregiver!['full_name']}  ·  ${DateFormat('MMM d').format(_selectedDate)}  ·  ${_toAmPm(_kWorkStart)} – ${_toAmPm(_kWorkEnd)}',
                style: const TextStyle(color: _primary, fontSize: 12, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis)),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Available Start Times',
                    style: TextStyle(color: _primary, fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  'Session: ${_formatDuration(_selectedDuration)}  ·  Total: EGP ${total.toInt()}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
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
            const Text('Tap a green slot to select your start time',
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
                    Flexible(child: Text('No available slots for this duration on this day.',
                        style: TextStyle(color: _muted, fontSize: 13))),
                  ]))
              : Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _availableSlots.map((slot) {
                    final endTime = _fromMin(_toMin(slot['from']!) + _selectedDuration);
                    final isSel   = _selectedStartTime == slot['from'];
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedStartTime = slot['from'];
                          _selectedEndTime   = endTime;
                        });
                        _openStep(3);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                            color: isSel ? _primary : _greenSoft,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: isSel ? _primary : _greenLine, width: isSel ? 2 : 1),
                            boxShadow: isSel ? [BoxShadow(color: _primary.withOpacity(0.22), blurRadius: 10, offset: const Offset(0, 4))] : null),
                        child: Text(
                          '${_toAmPm(slot['from']!)} – ${_toAmPm(endTime)}',
                          style: TextStyle(
                              color: isSel ? Colors.white : _green,
                              fontWeight: FontWeight.w800, fontSize: 13),
                        ),
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
                _SummaryRow('Caregiver', _selectedCaregiver?['full_name'] ?? '–'),
                _SummaryRow('Date',      DateFormat('MMM dd, yyyy').format(_selectedDate)),
                _SummaryRow('Duration',  _formatDuration(_selectedDuration)),
                _SummaryRow('Time',      '${_toAmPm(_selectedStartTime!)} – ${_toAmPm(_selectedEndTime!)}'),
                _SummaryRow('Total Fee', 'EGP ${total.toInt()}'),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  // ── Patient info ──────────────────────────────────────────────────────────────
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

  // ── Submit ────────────────────────────────────────────────────────────────────
  void _submitBooking() {
    if (_selectedCaregiver == null) return _snack('Please select a caregiver first.');
    if (_selectedStartTime == null) return _snack('Please select an available appointment slot.');
    if (_commentCtrl.text.trim().isEmpty) return _snack('Please enter your care requirements.');
    if (_selectedDate.isBefore(_today))   return _snack('Past dates cannot be booked.');

    final cg       = _selectedCaregiver!;
    final fullName = cg['full_name']?.toString() ?? '';
    final parts    = fullName.split(' ');
    final dateStr  = _dateStr(_selectedDate);
    final total    = _calcTotal(_selectedDuration);

    Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(bookingData: {
      'service_type':     'Caregiver',
      'patient_id':       _currentUser?['user_id'],
      'provider_id':      cg['user_id'],
      'fullname':         '${_currentUser?['firstName'] ?? ''} ${_currentUser?['lastName'] ?? ''}'.trim(),
      'phone':            _currentUser?['phone'],
      'email':            _currentUser?['email'],
      'address':          _currentUser?['address'] ?? 'Home Visit',
      'date':             dateStr,
      'booking_time':     '$_selectedStartTime:00',
      'service_time':     '$_selectedEndTime:00',
      'start_at':         '$dateStr $_selectedStartTime:00',
      'end_at':           '$dateStr $_selectedEndTime:00',
      'duration_minutes': _selectedDuration,
      'payment_total':    total,
      'payment_status':   'Pending',
      'status':           'pending',
      'comment':          _commentCtrl.text,
      'first_name':       cg['first_name'] ?? (parts.isNotEmpty ? parts.first : ''),
      'last_name':        cg['last_name']  ?? (parts.length > 1  ? parts.last  : ''),
      'shift_preference': cg['shift_preference'] ?? cg['shift'],
    })));
  }

  // ── Edit profile dialog ───────────────────────────────────────────────────────
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