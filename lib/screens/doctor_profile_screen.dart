import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:rafiq/auth/api_service.dart';
import 'package:rafiq/auth/session_manager.dart';
import 'package:rafiq/auth/login.dart';

const _primary      = Color(0xFF404066);
const _primaryDark  = Color(0xFF2B2C41);
const _primaryLight = Color(0xFF6D73C8);
const _bgColor      = Color(0xFFF6F8FD);
const _mutedColor   = Color(0xFF6E7388);
const _lineColor    = Color(0xFFE7E9F2);
const _dangerColor  = Color(0xFFB53535);

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});
  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen>
    with SingleTickerProviderStateMixin {

  bool isEditing = false;
  bool isLoading = true;
  bool _isSaving = false;
  String? _errorMsg;

  late AnimationController _expandCtrl;
  late Animation<double>   _expandAnim;

  final firstName  = TextEditingController();
  final lastName   = TextEditingController();
  final email      = TextEditingController();
  final phone      = TextEditingController();
  final address    = TextEditingController();
  final nationalId = TextEditingController();
  final speciality = TextEditingController();

  String  gender = '';
  String  dob    = '';
  File?   profileImage;
  File?   licenseFile;
  String? licenseFileName;
  String? photoUrl;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _expandAnim = CurvedAnimation(parent: _expandCtrl, curve: Curves.easeInOutCubic);
    _loadProfile();
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    firstName.dispose(); lastName.dispose(); email.dispose();
    phone.dispose(); address.dispose(); nationalId.dispose(); speciality.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final session = await SessionManager.getUser();
      final id = int.tryParse(session?['user_id']?.toString() ?? '0') ?? 0;
      final data = await ApiService.getDoctorProfile(id);
      if (mounted && data != null) {
        setState(() {
          firstName.text  = data['first_name']     ?? '';
          lastName.text   = data['last_name']      ?? '';
          email.text      = data['email']          ?? '';
          phone.text      = data['phone']          ?? '';
          address.text    = data['address']        ?? '';
          nationalId.text = data['national_id']    ?? '';
          speciality.text = data['speciality']     ?? '';
          gender          = data['gender']         ?? '';
          dob             = data['dob']            ?? '';
          licenseFileName = data['medical_license'];
          photoUrl        = data['photo'];
          isLoading       = false;
        });
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (_) { if (mounted) setState(() => isLoading = false); }
  }

  Future<void> _saveProfile() async {
    setState(() { _isSaving = true; _errorMsg = null; });
    try {
      final session = await SessionManager.getUser();
      final id = int.tryParse(session?['user_id']?.toString() ?? '0') ?? 0;
      final res = await ApiService.updateDoctorProfile({
        'user_id':     id.toString(),
        'first_name':  firstName.text.trim(),
        'last_name':   lastName.text.trim(),
        'phone':       phone.text.trim(),
        'address':     address.text.trim(),
        'speciality':  speciality.text.trim(),
        'national_id': nationalId.text.trim(),
      });
      if (res == true) {
        await _loadProfile();
        _setEditing(false);
        _showSnack('Profile updated successfully', success: true);
      } else {
        setState(() => _errorMsg = 'Update failed. Please try again.');
      }
    } catch (e) {
      setState(() => _errorMsg = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _setEditing(bool val) {
    setState(() => isEditing = val);
    val ? _expandCtrl.forward() : _expandCtrl.reverse();
  }

  String get _initials {
    final f = firstName.text.isNotEmpty ? firstName.text[0].toUpperCase() : 'D';
    final l = lastName.text.isNotEmpty  ? lastName.text[0].toUpperCase()  : '';
    return '$f$l';
  }

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
    if (p != null && mounted) setState(() => profileImage = File(p.path));
  }

  Future<void> _pickLicense() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf','jpg','png']);
    if (r != null) setState(() { licenseFile = File(r.files.single.path!); licenseFileName = r.files.single.name; });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(backgroundColor: _bgColor, body: Center(child: CircularProgressIndicator(color: _primary)));
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _buildProfileCard(),
            const SizedBox(height: 24),
            _buildLicenseCard(),
            const SizedBox(height: 110),
          ]),
        ),
      ),
    );
  }

  // ── Profile Card ─────────────────────────────────────────
  Widget _buildProfileCard() => Container(
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(32),
      border: Border.all(color: _primary.withOpacity(0.08)),
      boxShadow: [BoxShadow(color: _primaryDark.withOpacity(0.10), blurRadius: 48, offset: const Offset(0, 20))],
    ),
    clipBehavior: Clip.hardEdge,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildHero(),
      if (!isEditing) _buildCompactSummary(),
      SizeTransition(sizeFactor: _expandAnim, child: _buildFormBody()),
    ]),
  );

  // ── Hero ─────────────────────────────────────────────────
  Widget _buildHero() => Container(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [_primaryDark, _primary, _primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
    ),
    child: Stack(clipBehavior: Clip.none, children: [
      Positioned(right: -60, top: -80, child: Container(width: 180, height: 180,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.10)))),
      Row(children: [
        _buildAvatar(),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('My Profile', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.1)),
          const SizedBox(height: 4),
          Text('${firstName.text} ${lastName.text}'.trim().isNotEmpty ? '${firstName.text} ${lastName.text}'.trim() : 'Update your information',
              style: TextStyle(color: Colors.white.withOpacity(0.80), fontSize: 13, fontWeight: FontWeight.w600)),
          if (speciality.text.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Dr. · ${speciality.text}', style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11)),
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
            icon: isEditing ? Icons.check_circle_outline : Icons.edit_outlined,
            onTap: _isSaving ? null : () => isEditing ? _saveProfile() : _setEditing(true),
          ),
        ]),
      ]),
    ]),
  );

  Widget _heroIconBtn({required IconData icon, VoidCallback? onTap}) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Icon(icon, color: Colors.white, size: 17),
    ),
  );

  Widget _buildAvatar() {
    ImageProvider? img;
    if (profileImage != null) img = FileImage(profileImage!);
    else if (photoUrl != null && photoUrl!.isNotEmpty) img = NetworkImage(photoUrl!);
    return Stack(alignment: Alignment.bottomRight, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withOpacity(0.14),
          border: Border.all(color: Colors.white.withOpacity(0.30), width: 2),
          image: img != null ? DecorationImage(image: img, fit: BoxFit.cover) : null,
        ),
        child: img == null ? Center(child: Text(_initials, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800))) : null,
      ),
      if (isEditing)
        GestureDetector(onTap: _pickImage,
          child: Container(padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: _primaryLight, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
            child: const Icon(Icons.camera_alt, size: 12, color: Colors.white))),
    ]);
  }

  // ── Compact Summary ──────────────────────────────────────
  Widget _buildCompactSummary() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.6,
        children: [
          _infoTile('Phone',       phone.text.isNotEmpty ? phone.text : '—',          Icons.phone_outlined),
          _infoTile('Gender',      gender.isNotEmpty ? '${gender[0].toUpperCase()}${gender.substring(1)}' : '—', Icons.person_outline_rounded),
          _infoTile('Date of Birth', dob.isNotEmpty ? dob : '—',                      Icons.cake_outlined),
          _infoTile('Speciality',  speciality.text.isNotEmpty ? speciality.text : '—', Icons.local_hospital_outlined),
        ],
      ),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: () => _setEditing(true),
        child: Container(
          height: 42,
          decoration: BoxDecoration(color: _primary.withOpacity(0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: _primary.withOpacity(0.14))),
          alignment: Alignment.center,
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.edit_outlined, size: 15, color: _primary),
            SizedBox(width: 6),
            Text('Edit Profile', style: TextStyle(color: _primary, fontWeight: FontWeight.w800, fontSize: 13)),
          ]),
        ),
      ),
    ]),
  );

  Widget _infoTile(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: const Color(0xFFF8F9FD), borderRadius: BorderRadius.circular(14), border: Border.all(color: _lineColor)),
    child: Row(children: [
      Icon(icon, size: 14, color: _mutedColor),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: const TextStyle(color: _mutedColor, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        const SizedBox(height: 1),
        Text(value, style: const TextStyle(color: _primaryDark, fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );

  // ── Edit Form ────────────────────────────────────────────
  Widget _buildFormBody() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_errorMsg != null) ...[_ErrorBanner(message: _errorMsg!), const SizedBox(height: 16)],
      Row(children: [
        Expanded(child: _field('First Name', firstName)),
        const SizedBox(width: 14),
        Expanded(child: _field('Last Name', lastName)),
      ]),
      const SizedBox(height: 16),
      _field('Email', email, readOnly: true),
      const SizedBox(height: 16),
      _field('Phone', phone, keyboard: TextInputType.phone),
      const SizedBox(height: 16),
      _field('Address', address),
      const SizedBox(height: 16),
      _field('National ID', nationalId, keyboard: TextInputType.number),
      const SizedBox(height: 16),
      _field('Speciality', speciality),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: _ActionButton(
          label: _isSaving ? 'Saving…' : 'Save Changes',
          gradient: const LinearGradient(colors: [_primary, _primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
          textColor: Colors.white, onTap: _isSaving ? null : _saveProfile,
        )),
        const SizedBox(width: 12),
        Expanded(child: _ActionButton(
          label: 'Cancel', color: const Color(0xFFF1F4FB), textColor: _primaryDark,
          border: Border.all(color: _lineColor),
          onTap: () => setState(() { _setEditing(false); _errorMsg = null; }),
        )),
      ]),
    ]),
  );

  Widget _field(String label, TextEditingController c, {TextInputType keyboard = TextInputType.text, bool readOnly = false}) =>
    _FieldWrapper(label: label, child: _FieldInput(controller: c, enabled: !readOnly, keyboardType: keyboard));

  // ── License Card ─────────────────────────────────────────
  Widget _buildLicenseCard() => Container(
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(32),
      border: Border.all(color: _primary.withOpacity(0.08)),
      boxShadow: [BoxShadow(color: _primaryDark.withOpacity(0.08), blurRadius: 36, offset: const Offset(0, 14))],
    ),
    clipBehavior: Clip.hardEdge,
    child: Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _lineColor))),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: _primary.withOpacity(0.08), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.verified_user_outlined, color: _primary, size: 18)),
          const SizedBox(width: 12),
          const Text('Medical License', style: TextStyle(color: _primaryDark, fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: _primary.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.description_outlined, color: _primary, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('License File', style: TextStyle(color: _mutedColor, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(licenseFileName ?? 'No license uploaded',
              style: const TextStyle(color: _primaryDark, fontSize: 14, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
          ])),
          if (isEditing)
            GestureDetector(onTap: _pickLicense,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(12)),
                child: const Text('Upload', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)))),
        ]),
      ),
    ]),
  );
}

// ── Shared widgets ────────────────────────────────────────────
class _FieldWrapper extends StatelessWidget {
  final String label; final Widget child;
  const _FieldWrapper({required this.label, required this.child});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: _primaryDark, letterSpacing: 0.3)),
    const SizedBox(height: 8), child,
  ]);
}

class _FieldInput extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final TextInputType keyboardType;
  const _FieldInput({required this.controller, this.enabled = true, this.keyboardType = TextInputType.text});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller, enabled: enabled, keyboardType: keyboardType,
    style: const TextStyle(color: _primaryDark, fontSize: 14, fontWeight: FontWeight.w700),
    decoration: InputDecoration(
      filled: true, fillColor: enabled ? const Color(0xFFF8F9FD) : const Color(0xFFF0F2F8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _lineColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _lineColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _primaryLight, width: 1.5)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: _lineColor.withOpacity(0.6))),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: const Color(0xFFFFF1F1), borderRadius: BorderRadius.circular(14), border: Border.all(color: _dangerColor.withOpacity(0.18))),
    child: Text(message, style: const TextStyle(color: _dangerColor, fontWeight: FontWeight.w800, fontSize: 13)),
  );
}

class _ActionButton extends StatelessWidget {
  final String label; final Color? color; final Gradient? gradient;
  final Color textColor; final BoxBorder? border; final VoidCallback? onTap;
  const _ActionButton({required this.label, required this.textColor, this.color, this.gradient, this.border, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 50,
      decoration: BoxDecoration(color: color, gradient: gradient, borderRadius: BorderRadius.circular(14), border: border,
        boxShadow: gradient != null ? [BoxShadow(color: _primary.withOpacity(0.20), blurRadius: 20, offset: const Offset(0, 8))] : null),
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(color: onTap == null ? textColor.withOpacity(0.4) : textColor, fontWeight: FontWeight.w800, fontSize: 13)),
    ),
  );
}