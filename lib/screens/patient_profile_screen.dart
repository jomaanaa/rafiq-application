import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:rafiq/auth/api_service.dart';
import 'package:rafiq/auth/session_manager.dart';
import 'package:rafiq/auth/login.dart';
import 'package:rafiq/services/jitsi_service.dart';

const _primary      = Color(0xFF404066);
const _primaryDark  = Color(0xFF2B2C41);
const _primaryLight = Color(0xFF6D73C8);
const _bgColor      = Color(0xFFF6F8FD);
const _textColor    = Color(0xFF222335);
const _mutedColor   = Color(0xFF6E7388);
const _lineColor    = Color(0xFFE7E9F2);
const _dangerColor  = Color(0xFFB53535);
const _goldColor    = Color(0xFFF59E0B);

class PatientProfileScreen extends StatefulWidget {
  final int userId;
  const PatientProfileScreen({super.key, required this.userId});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _isEditing = false;
  bool _isLoading = true;
  bool _isSaving  = false;
  String? _errorMsg;

  late AnimationController _expandCtrl;
  late Animation<double> _expandAnim;

  final _firstName = TextEditingController();
  final _lastName  = TextEditingController();
  final _email     = TextEditingController();
  final _phone     = TextEditingController();
  final _address   = TextEditingController();

  String    _gender = '';
  DateTime? _dob;
  File?     _profileImage;
  String?   _photoUrl;

  final List<String> _allDisabilities = [
    'Visual Impairment',
    'Hearing Impairment',
    'Physical Disability',
    'Intellectual Disability',
  ];
  List<String> _selectedDisabilities = [];

  late Future<List<Map<String, dynamic>>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _expandAnim = CurvedAnimation(parent: _expandCtrl, curve: Curves.easeInOutCubic);
    _loadProfile();
    _bookingsFuture = _loadBookings();
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  // ─── DATA ────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final session = await SessionManager.getUser();
      final id = int.tryParse(
          session?['user_id']?.toString() ?? widget.userId.toString()) ?? 0;
      final data = await ApiService.getPatientProfile(id);
      if (!mounted) return;
      if (data != null) {
        _firstName.text = data['first_name'] ?? '';
        _lastName.text  = data['last_name']  ?? '';
        _email.text     = data['email']      ?? '';
        _phone.text     = data['phone']      ?? '';
        _address.text   = data['address']    ?? '';
        _gender         = data['gender']     ?? '';
        _photoUrl       = data['photo']?.toString();
        final dobStr    = data['dob']?.toString() ?? '';
        if (dobStr.isNotEmpty) _dob = DateTime.tryParse(dobStr);
        final raw = data['disability']?.toString() ?? '';
        _selectedDisabilities = raw.isNotEmpty
            ? raw.split(', ').map((e) => e.trim()).toList()
            : [];
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<List<Map<String, dynamic>>> _loadBookings() async {
    final session = await SessionManager.getUser();
    final id = int.tryParse(
        session?['user_id']?.toString() ?? widget.userId.toString()) ?? 0;
    return ApiService.getProfileBookings(id);
  }

  // ─── SAVE ────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    setState(() { _isSaving = true; _errorMsg = null; });

    final session = await SessionManager.getUser();
    final id = int.tryParse(
        session?['user_id']?.toString() ?? widget.userId.toString()) ?? 0;

    try {
      final uri = Uri.parse('${ApiService.baseUrl}/update_patient.php');
      final req = http.MultipartRequest('POST', uri);

      req.fields['user_id']    = id.toString();
      req.fields['first_name'] = _firstName.text.trim();
      req.fields['last_name']  = _lastName.text.trim();
      req.fields['phone']      = _phone.text.trim();
      req.fields['address']    = _address.text.trim();
      req.fields['disability'] = _selectedDisabilities.join(', ');

      if (_profileImage != null) {
        req.files.add(await http.MultipartFile.fromPath(
            'photo', _profileImage!.path));
      }

      final streamed = await req.send();
      final res      = await http.Response.fromStream(streamed);
      if (!mounted) return;

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;

      if (decoded['success'] == true) {
        if (decoded['photo_url'] != null) {
          _photoUrl     = decoded['photo_url'].toString();
          _profileImage = null;
        }
        final savedPhotoUrl = _photoUrl;
        await SessionManager.saveUser({
          ...session!,
          'user_id'    : id,
          'first_name' : _firstName.text.trim(),
          'last_name'  : _lastName.text.trim(),
          if (savedPhotoUrl != null) 'photo': savedPhotoUrl,
        });
        await _loadProfile();
        if (savedPhotoUrl != null && (_photoUrl == null || _photoUrl!.isEmpty)) {
          setState(() => _photoUrl = savedPhotoUrl);
        }
        _setEditing(false);
        setState(() => _isSaving = false);
        _showSnack('Profile updated successfully', success: true);
      } else {
        setState(() {
          _errorMsg = decoded['message']?.toString() ??
              'Update failed. Please try again.';
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMsg = 'Error: $e'; _isSaving = false; });
    }
  }

  void _setEditing(bool val) {
    setState(() => _isEditing = val);
    if (val) {
      _expandCtrl.forward();
    } else {
      _expandCtrl.reverse();
    }
  }

  // ─── HELPERS ─────────────────────────────────────────────
  String get _initials {
    final f = _firstName.text.isNotEmpty ? _firstName.text[0].toUpperCase() : 'P';
    final l = _lastName.text.isNotEmpty  ? _lastName.text[0].toUpperCase()  : '';
    return '$f$l';
  }

  String get _fullName => '${_firstName.text} ${_lastName.text}'.trim();

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: success ? _primaryDark : _dangerColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  Future<void> _pickImage() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (p != null && mounted) setState(() => _profileImage = File(p.path));
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  String _formatDob(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return Colors.green.shade600;
      case 'cancelled': return _dangerColor;
      case 'pending':   return const Color(0xFFD97706);
      case 'accepted':  return _primaryLight;
      default:          return _mutedColor;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return Icons.check_circle_outline_rounded;
      case 'cancelled': return Icons.cancel_outlined;
      case 'pending':   return Icons.schedule_rounded;
      case 'accepted':  return Icons.thumb_up_alt_outlined;
      default:          return Icons.info_outline_rounded;
    }
  }

  // ─── BUILD ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bgColor,
        body: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProfileCard(),
              const SizedBox(height: 24),
              _buildBookingsCard(),
              const SizedBox(height: 110),
            ],
          ),
        ),
      ),
    );
  }

  // ─── PROFILE CARD ────────────────────────────────────────
  Widget _buildProfileCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _primary.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: _primaryDark.withOpacity(0.10), blurRadius: 48, offset: const Offset(0, 20))],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildHero(),
        if (!_isEditing) _buildCompactSummary(),
        SizeTransition(
          sizeFactor: _expandAnim,
          child: _buildFormBody(),
        ),
      ]),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF20233C), Color(0xFF353B69), Color(0xFF6470D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('My Profile', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.1)),
                const SizedBox(height: 4),
                Text(_fullName.isNotEmpty ? _fullName : 'Update your information',
                    style: TextStyle(color: Colors.white.withOpacity(0.80), fontSize: 13, fontWeight: FontWeight.w600)),
                if (_email.text.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(_email.text, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11)),
                ],
              ])),
              Column(children: [
                _heroIconBtn(icon: Icons.logout, onTap: () async {
                  await SessionManager.logout();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const Login()), (_) => false);
                }),
                const SizedBox(height: 8),
                _heroIconBtn(
                  icon: _isEditing ? Icons.check_circle_outline : Icons.edit_outlined,
                  onTap: _isSaving ? null : () => _isEditing ? _saveProfile() : _setEditing(true),
                ),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroIconBtn({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white.withOpacity(0.22)),
        ),
        child: Icon(icon, color: Colors.white, size: 17),
      ),
    );
  }

  Widget _buildAvatar() {
    ImageProvider? imageProvider;
    if (_profileImage != null) {
      imageProvider = FileImage(_profileImage!);
    } else if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      imageProvider = NetworkImage(_photoUrl!);
    }
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withOpacity(0.14),
            border: Border.all(color: Colors.white.withOpacity(0.30), width: 2),
            image: imageProvider != null ? DecorationImage(image: imageProvider, fit: BoxFit.cover) : null,
          ),
          child: imageProvider == null
              ? Center(child: Text(_initials, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)))
              : null,
        ),
        if (_isEditing)
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: _primaryLight, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
              child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
            ),
          ),
      ],
    );
  }

  // ─── COMPACT SUMMARY (read-only) ─────────────────────────
  Widget _buildCompactSummary() {
    final items = [
      ('Phone', _phone.text.isNotEmpty ? _phone.text : '—', Icons.phone_outlined),
      ('Gender', _gender.isNotEmpty ? _gender[0].toUpperCase() + _gender.substring(1) : '—', Icons.person_outline_rounded),
      ('Date of Birth', _formatDob(_dob), Icons.cake_outlined),
      ('Address', _address.text.isNotEmpty ? _address.text : '—', Icons.location_on_outlined),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: items.map((item) => _compactInfoTile(item.$1, item.$2, item.$3)).toList(),
          ),
          if (_selectedDisabilities.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _primary.withOpacity(0.07), borderRadius: BorderRadius.circular(8)),
                child: const Text('Disabilities:', style: TextStyle(color: _mutedColor, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              ..._selectedDisabilities.map((d) => _DisabilityChip(label: d)),
            ]),
          ],
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _setEditing(true),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _primary.withOpacity(0.14)),
              ),
              alignment: Alignment.center,
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.edit_outlined, size: 15, color: _primary),
                SizedBox(width: 6),
                Text('Edit Profile', style: TextStyle(color: _primary, fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactInfoTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _lineColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: _mutedColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(color: _mutedColor, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                const SizedBox(height: 1),
                Text(value, style: const TextStyle(color: _primaryDark, fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── EDIT FORM BODY ──────────────────────────────────────
  Widget _buildFormBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMsg != null) ...[_ErrorBanner(message: _errorMsg!), const SizedBox(height: 16)],
          Row(children: [
            Expanded(child: _buildField('First Name', _firstName)),
            const SizedBox(width: 14),
            Expanded(child: _buildField('Last Name', _lastName)),
          ]),
          const SizedBox(height: 16),
          _buildField('Email', _email, keyboardType: TextInputType.emailAddress, readOnly: true),
          const SizedBox(height: 16),
          _buildField('Phone', _phone, keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _buildGenderField()),
            const SizedBox(width: 14),
            Expanded(child: _buildDobField()),
          ]),
          const SizedBox(height: 16),
          _buildField('Address', _address),
          const SizedBox(height: 16),
          _buildDisabilityField(),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _ActionButton(
              label: _isSaving ? 'Saving…' : 'Save Changes',
              gradient: const LinearGradient(colors: [_primary, _primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
              textColor: Colors.white,
              onTap: _isSaving ? null : _saveProfile,
            )),
            const SizedBox(width: 12),
            Expanded(child: _ActionButton(
              label: 'Cancel',
              color: const Color(0xFFF1F4FB),
              textColor: _primaryDark,
              border: Border.all(color: _lineColor),
              onTap: () => setState(() { _setEditing(false); _errorMsg = null; }),
            )),
          ]),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {TextInputType keyboardType = TextInputType.text, bool readOnly = false}) {
    return _FieldWrapper(label: label, child: _FieldInput(controller: ctrl, enabled: !readOnly, keyboardType: keyboardType));
  }

  Widget _buildGenderField() {
    return _FieldWrapper(
      label: 'Gender',
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: const Color(0xFFF8F9FD), borderRadius: BorderRadius.circular(18), border: Border.all(color: _lineColor)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _gender.isEmpty ? null : _gender,
            hint: const Text('Select…', style: TextStyle(color: _mutedColor, fontSize: 13)),
            isExpanded: true,
            style: const TextStyle(color: _primaryDark, fontSize: 14, fontWeight: FontWeight.w700),
            items: const [
              DropdownMenuItem(value: 'male',   child: Text('Male')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
            ],
            onChanged: (v) => setState(() => _gender = v ?? ''),
          ),
        ),
      ),
    );
  }

  Widget _buildDobField() {
    return _FieldWrapper(
      label: 'Date of Birth',
      child: GestureDetector(
        onTap: _pickDob,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: const Color(0xFFF8F9FD), borderRadius: BorderRadius.circular(18), border: Border.all(color: _lineColor)),
          alignment: Alignment.centerLeft,
          child: Row(children: [
            Expanded(child: Text(_formatDob(_dob), style: TextStyle(color: _dob != null ? _primaryDark : _mutedColor, fontSize: 14, fontWeight: FontWeight.w700))),
            const Icon(Icons.calendar_today_outlined, size: 15, color: _mutedColor),
          ]),
        ),
      ),
    );
  }

  Widget _buildDisabilityField() {
    return _FieldWrapper(
      label: 'Disability',
      child: GestureDetector(
        onTap: _openDisabilitySheet,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFF8F9FD), borderRadius: BorderRadius.circular(18), border: Border.all(color: _lineColor)),
          child: _selectedDisabilities.isEmpty
              ? const Align(alignment: Alignment.centerLeft, child: Text('Tap to select…', style: TextStyle(color: _mutedColor, fontSize: 13)))
              : Wrap(spacing: 6, runSpacing: 6, children: _selectedDisabilities.map((d) => _DisabilityChip(label: d)).toList()),
        ),
      ),
    );
  }

  // ── FIX 2: Redesigned disability picker as a bottom sheet ──
  void _openDisabilitySheet() {
    // Work on a local copy; only apply on "Done"
    final localSelected = List<String>.from(_selectedDisabilities);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: _lineColor, borderRadius: BorderRadius.circular(4)),
                ),
                // Header
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryDark, _primary, _primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.25)),
                        ),
                        child: const Icon(Icons.accessibility_new_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Select Disabilities', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                            Text('Choose all that apply', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Options list
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    children: _allDisabilities.map((d) {
                      final isSelected = localSelected.contains(d);
                      return GestureDetector(
                        onTap: () {
                          setSheet(() {
                            if (isSelected) {
                              localSelected.remove(d);
                            } else {
                              localSelected.add(d);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? _primary.withOpacity(0.08) : const Color(0xFFF8F9FD),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? _primary.withOpacity(0.35) : _lineColor,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  color: isSelected ? _primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: isSelected ? _primary : _mutedColor.withOpacity(0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  d,
                                  style: TextStyle(
                                    color: isSelected ? _primaryDark : _textColor,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Selected', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // Done button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedDisabilities = List<String>.from(localSelected));
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_primary, _primaryLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: _primary.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      alignment: Alignment.center,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 17),
                        const SizedBox(width: 8),
                        Text(
                          localSelected.isEmpty ? 'Confirm (none selected)' : 'Confirm ${localSelected.length} selected',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── BOOKINGS CARD ───────────────────────────────────────
  Widget _buildBookingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _primary.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: _primaryDark.withOpacity(0.08), blurRadius: 36, offset: const Offset(0, 14))],
      ),
      clipBehavior: Clip.hardEdge,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _bookingsFuture,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: _primary)),
            );
          }

          final bookings = snap.data ?? [];
          final preview  = bookings.take(3).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _lineColor))),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: _primary.withOpacity(0.08), borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.history_rounded, color: _primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Text('Previous Requests', style: TextStyle(color: _primaryDark, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    if (bookings.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: _primary.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                        child: Text('${bookings.length}', style: const TextStyle(color: _primary, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    const Spacer(),
                    if (bookings.length > 3)
                      GestureDetector(
                        onTap: () => _openBookingsSheet(bookings),
                        child: const Text('View all', style: TextStyle(color: _primaryLight, fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
              ),

              // ── Empty state ──
              if (bookings.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(36),
                  child: Column(children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(color: _primary.withOpacity(0.07), borderRadius: BorderRadius.circular(18)),
                      child: const Icon(Icons.calendar_today_outlined, color: _mutedColor, size: 24),
                    ),
                    const SizedBox(height: 12),
                    const Text('No previous requests found.', style: TextStyle(color: _mutedColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  ]),
                )
              else
                // ── Preview list (first 3) ──
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: preview.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: _lineColor, indent: 20, endIndent: 20),
                  itemBuilder: (_, i) => _buildBookingTile(preview[i], bookings),
                ),

              // ── "View all X requests" footer ──
              if (bookings.length > 3)
                GestureDetector(
                  onTap: () => _openBookingsSheet(bookings),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: _lineColor))),
                    alignment: Alignment.center,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('View all ${bookings.length} requests', style: const TextStyle(color: _primary, fontWeight: FontWeight.w800, fontSize: 13)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, color: _primary, size: 18),
                    ]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ─── BOOKING TILE ────────────────────────────────────────
  Widget _buildBookingTile(Map<String, dynamic> b, List<Map<String, dynamic>> allBookings) {
    final provider       = '${b['provider_first'] ?? ''} ${b['provider_last'] ?? ''}'.trim();
    final status         = (b['status'] ?? 'Pending').toString();
    final date           = b['booking_date']?.toString() ?? '';
    final time           = b['service_time']?.toString() ?? '';
    final bookingId      = int.tryParse(b['booking_id']?.toString() ?? '0') ?? 0;
    final isCompleted    = status.toLowerCase() == 'completed';
    final hasReview      = b['rating'] != null;
    final existingRating = int.tryParse(b['rating']?.toString() ?? '') ?? 0;
    final existingReview = b['review']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: _primary.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.medical_services_outlined, color: _primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(provider.isNotEmpty ? provider : 'Provider',
                  style: const TextStyle(color: _textColor, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 3),
              Text([date, time].where((s) => s.isNotEmpty).join('  ·  '),
                  style: const TextStyle(color: _mutedColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  if ((b['service_type'] ?? '').toString().isNotEmpty)
                  Text(
                    b['service_type'].toString(),
                    style: const TextStyle(color: _primaryLight, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
            ])),
            _StatusPill(status: status, color: _statusColor(status), icon: _statusIcon(status)),
          ]),
          if ((b['service_type']?.toString() ?? '').toLowerCase() == 'interpreter' &&
    (status.toLowerCase() == 'accepted' || status.toLowerCase() == 'in_session')) ...[
  const SizedBox(height: 10),
  GestureDetector(
    onTap: () async {
      final session = await SessionManager.getUser();
      final name  = '${session?['first_name'] ?? ''} ${session?['last_name'] ?? ''}'.trim();
      final email = session?['email']?.toString() ?? '';
      await JitsiService.joinCall(
        bookingId: bookingId,
        displayName: name.isNotEmpty ? name : 'Patient',
        userEmail: email,
      );
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _primaryLight.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryLight.withOpacity(0.3)),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.video_call_rounded, color: _primaryLight, size: 16),
        SizedBox(width: 6),
        Text('Join Call', style: TextStyle(
            color: _primaryLight, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    ),
  ),
],
          if (status.toLowerCase() == 'pending' || status.toLowerCase() == 'accepted') ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Cancel Booking?', style: TextStyle(fontWeight: FontWeight.w900, color: _primaryDark)),
                    content: const Text('Are you sure you want to cancel this booking?', style: TextStyle(color: _mutedColor)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Yes, cancel', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                );
                if (confirm != true || !mounted) return;
                final session = await SessionManager.getUser();
                final patientId = int.tryParse(session?['user_id']?.toString() ?? '0') ?? 0;
                final ok = await ApiService.cancelBooking(bookingId: bookingId, patientId: patientId);
                if (!mounted) return;
                if (ok) {
                  _bookingsFuture = _loadBookings();
                  setState(() {});
                  _showSnack('Booking cancelled', success: true);
                } else {
                  _showSnack('Cannot cancel — booking may already be in progress');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.cancel_outlined, color: Colors.red, size: 14),
                  SizedBox(width: 6),
                  Text('Cancel Booking', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 12)),
                ]),
              ),
            ),
          ],
          if (isCompleted) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _openReviewDialog(
                bookingId,
                initialRating: existingRating,
                initialReview: existingReview,
                onSubmitted: () { _bookingsFuture = _loadBookings(); setState(() {}); },
              ),
              child: hasReview
                  ? _ReviewDisplay(rating: existingRating, review: existingReview)
                  : _LeaveReviewButton(),
            ),
          ],
        ],
      ),
    );
  }

  // ─── OPEN BOOKINGS SHEET ─────────────────────────────────
  void _openBookingsSheet(List<Map<String, dynamic>> bookings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingsSheet(
        bookings: bookings,
        onRefresh: () { _bookingsFuture = _loadBookings(); setState(() {}); },
        statusColor: _statusColor,
        statusIcon: _statusIcon,
        onReview: _openReviewDialog,
        showSnack: _showSnack,
      ),
    );
  }

  // ─── REVIEW DIALOG ───────────────────────────────────────
  void _openReviewDialog(
    int bookingId, {
    int initialRating = 0,
    String initialReview = '',
    required VoidCallback onSubmitted,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReviewSheet(
        bookingId: bookingId,
        initialRating: initialRating,
        initialReview: initialReview,
        onSubmitted: (rating, review) async {
          final res = await ApiService.submitReview(
            bookingId: bookingId,
            rating: rating,
            review: review,
          );
          if (!mounted) return;
          if (res['success'] == true) {
            _showSnack(initialRating > 0 ? 'Review updated!' : 'Review submitted!', success: true);
            onSubmitted();
          } else {
            _showSnack(res['message'] ?? 'Failed to submit review');
          }
        },
      ),
    );
  }
}

// ─── BOOKINGS SHEET ───────────────────────────────────────────
class _BookingsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> bookings;
  final VoidCallback onRefresh;
  final Color Function(String) statusColor;
  final IconData Function(String) statusIcon;
  final void Function(int, {int initialRating, String initialReview, required VoidCallback onSubmitted}) onReview;
  final void Function(String, {bool success}) showSnack;

  const _BookingsSheet({
    required this.bookings,
    required this.onRefresh,
    required this.statusColor,
    required this.statusIcon,
    required this.onReview,
    required this.showSnack,
  });

  @override
  State<_BookingsSheet> createState() => _BookingsSheetState();
}

class _BookingsSheetState extends State<_BookingsSheet> {
  int _page = 0;
  static const int _perPage = 5;

  // ── Filters ──
  String _statusFilter = 'All';
  String _sortOrder    = 'Newest';
  // We'll derive service types from bookings dynamically
  String _serviceFilter = 'All';

  static const _statusOptions  = ['All', 'Pending', 'Accepted', 'Completed', 'Cancelled'];
  static const _sortOptions    = ['Newest', 'Oldest'];

  List<Map<String, dynamic>> get _filtered {
    var list = List<Map<String, dynamic>>.from(widget.bookings);

    // Status filter
    if (_statusFilter != 'All') {
      list = list.where((b) =>
        (b['status'] ?? '').toString().toLowerCase() == _statusFilter.toLowerCase()
      ).toList();
    }

    // Service type filter
    if (_serviceFilter != 'All') {
      list = list.where((b) =>
        (b['service_type'] ?? '').toString() == _serviceFilter
      ).toList();
    }

    // Sort by date
    list.sort((a, b) {
      final aDate = DateTime.tryParse(a['booking_date']?.toString() ?? '') ?? DateTime(0);
      final bDate = DateTime.tryParse(b['booking_date']?.toString() ?? '') ?? DateTime(0);
      return _sortOrder == 'Newest' ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
    });

    return list;
  }

  List<String> get _serviceOptions {
    final types = widget.bookings
        .map((b) => b['service_type']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    types.sort();
    return ['All', ...types];
  }

  void _resetPage() => _page = 0;

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final total    = (filtered.length / _perPage).ceil().clamp(1, 999);
    final start    = _page * _perPage;
    final end      = (start + _perPage).clamp(0, filtered.length);
    final visible  = filtered.isEmpty ? <Map<String, dynamic>>[] : filtered.sublist(start, end);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(color: _lineColor, borderRadius: BorderRadius.circular(4)),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: _primary.withOpacity(0.08), borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.history_rounded, color: _primary, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('All Requests', style: TextStyle(color: _primaryDark, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _primary.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                child: Text('${filtered.length}', style: const TextStyle(color: _primary, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: _bgColor, borderRadius: BorderRadius.circular(9), border: Border.all(color: _lineColor)),
                  child: const Icon(Icons.close_rounded, size: 15, color: _mutedColor),
                ),
              ),
            ]),
          ),

          // ── Filter Row ──
          Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _lineColor))),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Status filter
                  _FilterChipGroup(
                    icon: Icons.tune_rounded,
                    label: _statusFilter,
                    options: _statusOptions,
                    onSelected: (v) => setState(() { _statusFilter = v; _resetPage(); }),
                  ),
                  const SizedBox(width: 8),
                  // Service type filter — only show if there's more than one type
                  if (_serviceOptions.length > 2) ...[
                    _FilterChipGroup(
                      icon: Icons.medical_services_outlined,
                      label: _serviceFilter,
                      options: _serviceOptions,
                      onSelected: (v) => setState(() { _serviceFilter = v; _resetPage(); }),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Sort order
                  _FilterChipGroup(
                    icon: Icons.sort_rounded,
                    label: _sortOrder,
                    options: _sortOptions,
                    onSelected: (v) => setState(() { _sortOrder = v; _resetPage(); }),
                  ),
                ],
              ),
            ),
          ),

          // Scrollable list
          Flexible(
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(color: _primary.withOpacity(0.07), borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.search_off_rounded, color: _mutedColor, size: 24),
                      ),
                      const SizedBox(height: 12),
                      const Text('No requests match your filters.', style: TextStyle(color: _mutedColor, fontSize: 14, fontWeight: FontWeight.w600)),
                    ]),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: _lineColor, indent: 20, endIndent: 20),
                    itemBuilder: (ctx, i) {
                      final b              = visible[i];
                      final provider       = '${b['provider_first'] ?? ''} ${b['provider_last'] ?? ''}'.trim();
                      final status         = (b['status'] ?? 'Pending').toString();
                      final date           = b['booking_date']?.toString() ?? '';
                      final time           = b['service_time']?.toString() ?? '';
                      final bookingId      = int.tryParse(b['booking_id']?.toString() ?? '0') ?? 0;
                      final isCompleted    = status.toLowerCase() == 'completed';
                      final hasReview      = b['rating'] != null;
                      final existingRating = int.tryParse(b['rating']?.toString() ?? '') ?? 0;
                      final existingReview = b['review']?.toString() ?? '';

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                width: 42, height: 42,
                                decoration: BoxDecoration(color: _primary.withOpacity(0.08), borderRadius: BorderRadius.circular(13)),
                                child: const Icon(Icons.medical_services_outlined, color: _primary, size: 19),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(provider.isNotEmpty ? provider : 'Provider',
                                    style: const TextStyle(color: _textColor, fontWeight: FontWeight.w700, fontSize: 14)),
                                    if ((b['service_type'] ?? '').toString().isNotEmpty)
                                Text(
                                  b['service_type'].toString(),
                                  style: const TextStyle(color: _primaryLight, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text([date, time].where((s) => s.isNotEmpty).join('  ·  '),
                                    style: const TextStyle(color: _mutedColor, fontSize: 11, fontWeight: FontWeight.w600)),
                              ])),
                           _StatusPill(status: status, color: widget.statusColor(status), icon: widget.statusIcon(status)),
                            ]),
                            if ((b['service_type']?.toString() ?? '').toLowerCase() == 'interpreter' &&
    (status.toLowerCase() == 'accepted' || status.toLowerCase() == 'in_session')) ...[
  const SizedBox(height: 10),
  GestureDetector(
    onTap: () async {
      final session = await SessionManager.getUser();
      final name  = '${session?['first_name'] ?? ''} ${session?['last_name'] ?? ''}'.trim();
      final email = session?['email']?.toString() ?? '';
      await JitsiService.joinCall(
        bookingId: bookingId,
        displayName: name.isNotEmpty ? name : 'Patient',
        userEmail: email,
      );
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _primaryLight.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryLight.withOpacity(0.3)),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.video_call_rounded, color: _primaryLight, size: 16),
        SizedBox(width: 6),
        Text('Join Call', style: TextStyle(
            color: _primaryLight, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    ),
  ),
],
                            if (status.toLowerCase() == 'pending' || status.toLowerCase() == 'accepted') ...[
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      title: const Text('Cancel Booking?', style: TextStyle(fontWeight: FontWeight.w900, color: _primaryDark)),
                                      content: const Text('Are you sure you want to cancel this booking?', style: TextStyle(color: _mutedColor)),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Yes, cancel', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm != true || !mounted) return;
                                  final session   = await SessionManager.getUser();
                                  final patientId = int.tryParse(session?['user_id']?.toString() ?? '0') ?? 0;
                                  final ok        = await ApiService.cancelBooking(bookingId: bookingId, patientId: patientId);
                                  if (!mounted) return;
                                  if (ok) {
                                    // ── Instant UI update: flip status locally ──
                                    b['status'] = 'cancelled';
                                    setState(() {});
                                    widget.onRefresh();
                                    widget.showSnack('Booking cancelled', success: true);
                                  } else {
                                    widget.showSnack('Cannot cancel — booking may already be in progress');
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                                  ),
                                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.cancel_outlined, color: Colors.red, size: 14),
                                    SizedBox(width: 6),
                                    Text('Cancel Booking', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 12)),
                                  ]),
                                ),
                              ),
                            ],
                            if (isCompleted) ...[
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () => widget.onReview(
                                  bookingId,
                                  initialRating: existingRating,
                                  initialReview: existingReview,
                                  onSubmitted: () { widget.onRefresh(); setState(() {}); },
                                ),
                                child: hasReview
                                    ? _ReviewDisplay(rating: existingRating, review: existingReview)
                                    : _LeaveReviewButton(),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Pagination
          if (total > 1) ...[
            const Divider(height: 1, color: _lineColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _page > 0 ? () => setState(() => _page--) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _page > 0 ? _primary.withOpacity(0.06) : _lineColor.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _page > 0 ? _primary.withOpacity(0.16) : _lineColor),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.chevron_left_rounded, size: 16, color: _page > 0 ? _primary : _mutedColor),
                        Text('Prev', style: TextStyle(color: _page > 0 ? _primary : _mutedColor, fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...() {
                    final windowStart = (_page - 1).clamp(0, (total - 3).clamp(0, total));
                    final windowEnd   = (windowStart + 3).clamp(0, total);
                    return List.generate(windowEnd - windowStart, (i) {
                      final pageIndex = windowStart + i;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: GestureDetector(
                          onTap: () => setState(() => _page = pageIndex),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: pageIndex == _page ? _primary : _primary.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: pageIndex == _page ? _primary : _primary.withOpacity(0.14)),
                            ),
                            alignment: Alignment.center,
                            child: Text('${pageIndex + 1}', style: TextStyle(
                              color: pageIndex == _page ? Colors.white : _primary,
                              fontWeight: FontWeight.w800, fontSize: 12,
                            )),
                          ),
                        ),
                      );
                    });
                  }(),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _page < total - 1 ? () => setState(() => _page++) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _page < total - 1 ? _primary.withOpacity(0.06) : _lineColor.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _page < total - 1 ? _primary.withOpacity(0.16) : _lineColor),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Next', style: TextStyle(color: _page < total - 1 ? _primary : _mutedColor, fontSize: 12, fontWeight: FontWeight.w700)),
                        Icon(Icons.chevron_right_rounded, size: 16, color: _page < total - 1 ? _primary : _mutedColor),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Filter chip group widget ──────────────────────────────────
class _FilterChipGroup extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<String> options;
  final void Function(String) onSelected;

  const _FilterChipGroup({
    required this.icon,
    required this.label,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = label != options.first;
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: _lineColor, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 16),
                ...options.map((o) => GestureDetector(
                  onTap: () { Navigator.pop(context); onSelected(o); },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: o == label ? _primary.withOpacity(0.08) : const Color(0xFFF8F9FD),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: o == label ? _primary.withOpacity(0.30) : _lineColor),
                    ),
                    child: Row(children: [
                      Expanded(child: Text(o, style: TextStyle(
                        color: o == label ? _primaryDark : _textColor,
                        fontWeight: o == label ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 14,
                      ))),
                      if (o == label) const Icon(Icons.check_rounded, color: _primary, size: 16),
                    ]),
                  ),
                )),
              ],
            ),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _primary : const Color(0xFFF8F9FD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? _primary : _lineColor),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: isActive ? Colors.white : _mutedColor),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            color: isActive ? Colors.white : _mutedColor,
            fontSize: 12, fontWeight: FontWeight.w700,
          )),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: isActive ? Colors.white : _mutedColor),
        ]),
      ),
    );
  }
}

// ─── REVIEW SHEET ─────────────────────────────────────────────
class _ReviewSheet extends StatefulWidget {
  final int bookingId;
  final int initialRating;
  final String initialReview;
  final Future<void> Function(int rating, String review) onSubmitted;

  const _ReviewSheet({
    required this.bookingId,
    required this.initialRating,
    required this.initialReview,
    required this.onSubmitted,
  });

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late int _rating;
  late TextEditingController _reviewCtrl;
  bool _submitting = false;

  static const _labels = ['', 'Poor', 'Fair', 'Good', 'Great', 'Excellent'];

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
    _reviewCtrl = TextEditingController(text: widget.initialReview);
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialRating > 0;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_primaryDark, _primary, _primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.35), borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.25))),
                        child: const Icon(Icons.star_rounded, color: _goldColor, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(isEditing ? 'Edit Your Review' : 'Leave a Review',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(isEditing ? 'Update your rating and comment' : 'How was your experience?',
                            style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 12)),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = star),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutBack,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: star <= _rating ? _goldColor : _lineColor,
                            size: star <= _rating ? 44 : 38,
                          ),
                        ),
                      );
                    }),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _rating > 0
                        ? Padding(
                            key: ValueKey(_rating),
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_labels[_rating],
                                style: const TextStyle(color: _primary, fontWeight: FontWeight.w800, fontSize: 15)),
                          )
                        : const SizedBox(height: 28, key: ValueKey(0)),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _reviewCtrl,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 14, color: _primaryDark, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Share your experience (optional)…',
                      hintStyle: const TextStyle(color: _mutedColor, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FD),
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _lineColor)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _lineColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _primaryLight, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F4FB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _lineColor),
                          ),
                          alignment: Alignment.center,
                          child: const Text('Cancel', style: TextStyle(color: _primaryDark, fontWeight: FontWeight.w800, fontSize: 14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: _rating == 0 || _submitting ? null : () async {
                          setState(() => _submitting = true);
                          Navigator.pop(context);
                          await widget.onSubmitted(_rating, _reviewCtrl.text.trim());
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: _rating > 0
                                ? const LinearGradient(colors: [_primary, _primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight)
                                : null,
                            color: _rating == 0 ? _lineColor : null,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _rating > 0
                                ? [BoxShadow(color: _primary.withOpacity(0.28), blurRadius: 18, offset: const Offset(0, 8))]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(isEditing ? Icons.edit_rounded : Icons.check_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(isEditing ? 'Update Review' : 'Submit Review',
                                style: TextStyle(color: _rating > 0 ? Colors.white : _mutedColor, fontWeight: FontWeight.w800, fontSize: 14)),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── BOOKING REVIEW WIDGETS ──────────────────────────────────
class _ReviewDisplay extends StatelessWidget {
  final int rating;
  final String review;
  const _ReviewDisplay({required this.rating, required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _goldColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _goldColor.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Row(children: List.generate(5, (i) => Icon(
            i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
            color: _goldColor, size: 16,
          ))),
          const SizedBox(width: 10),
          if (review.isNotEmpty) ...[
            Expanded(child: Text(review, style: const TextStyle(color: _mutedColor, fontSize: 12, fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
          ],
          Icon(Icons.edit_outlined, size: 13, color: _mutedColor.withOpacity(0.6)),
        ],
      ),
    );
  }
}

class _LeaveReviewButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withOpacity(0.16)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: const [
        Icon(Icons.star_outline_rounded, color: _primary, size: 15),
        SizedBox(width: 6),
        Text('Leave a Review', style: TextStyle(color: _primary, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final Color color;
  final IconData icon;
  const _StatusPill({required this.status, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 4),
        Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 9, letterSpacing: 0.4)),
      ]),
    );
  }
}

// ─── REUSABLE WIDGETS ────────────────────────────────────────
class _FieldWrapper extends StatelessWidget {
  final String label;
  final Widget child;
  const _FieldWrapper({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: _primaryDark, letterSpacing: 0.3)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _FieldInput extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final TextInputType keyboardType;

  const _FieldInput({required this.controller, this.enabled = true, this.keyboardType = TextInputType.text});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: const TextStyle(color: _primaryDark, fontSize: 14, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        filled: true,
        fillColor: enabled ? const Color(0xFFF8F9FD) : const Color(0xFFF0F2F8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _lineColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _lineColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _primaryLight, width: 1.5)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: _lineColor.withOpacity(0.6))),
      ),
    );
  }
}

class _DisabilityChip extends StatelessWidget {
  final String label;
  const _DisabilityChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _dangerColor.withOpacity(0.18)),
      ),
      child: Text(message, style: const TextStyle(color: _dangerColor, fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color? color;
  final Gradient? gradient;
  final Color textColor;
  final BoxBorder? border;
  final VoidCallback? onTap;

  const _ActionButton({required this.label, required this.textColor, this.color, this.gradient, this.border, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: color,
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          border: border,
          boxShadow: gradient != null ? [BoxShadow(color: _primary.withOpacity(0.20), blurRadius: 20, offset: const Offset(0, 8))] : null,
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: onTap == null ? textColor.withOpacity(0.4) : textColor, fontWeight: FontWeight.w800, fontSize: 13)),
      ),
    );
  }
}