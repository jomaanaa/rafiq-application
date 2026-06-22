import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:rafiq/auth/api_service.dart';
import 'package:rafiq/auth/session_manager.dart';
import 'package:rafiq/auth/login.dart';

const _ip      = Color(0xFF404066);
const _ipDark  = Color(0xFF2B2C41);
const _ipLight = Color(0xFF6D73C8);
const _ibg     = Color(0xFFF6F8FD);
const _imuted  = Color(0xFF6E7388);
const _iline   = Color(0xFFE7E9F2);
const _idanger = Color(0xFFB53535);

class InterpreterProfileScreen extends StatefulWidget {
  const InterpreterProfileScreen({super.key});
  @override
  State<InterpreterProfileScreen> createState() => _InterpreterProfileScreenState();
}

class _InterpreterProfileScreenState extends State<InterpreterProfileScreen>
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

  String  gender = '';
  String  dob    = '';
  File?   profileImage;
  File?   cvFile;
  String? cvFileName;
  String? photoUrl;

  final List<String> allLanguages = ['Arabic','English','French','German','Spanish','Italian','Chinese','Turkish'];
  List<String> selectedLanguages  = [];

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
    phone.dispose(); address.dispose(); nationalId.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final session = await SessionManager.getUser();
      final id = int.tryParse(session?['user_id']?.toString() ?? '0') ?? 0;
      final data = await ApiService.getInterpreterProfile(id);
      if (mounted && data != null) {
        setState(() {
          firstName.text  = data['first_name']  ?? '';
          lastName.text   = data['last_name']   ?? '';
          email.text      = data['email']       ?? '';
          phone.text      = data['phone']       ?? '';
          address.text    = data['address']     ?? '';
          nationalId.text = data['national_id'] ?? '';
          gender          = data['gender']      ?? '';
          dob             = data['dob']         ?? '';
          cvFileName      = data['cv'];
          photoUrl        = data['photo'];
          final raw = data['languages']?.toString() ?? '';
          selectedLanguages = raw.isNotEmpty ? raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() : [];
          isLoading = false;
        });
      } else { if (mounted) setState(() => isLoading = false); }
    } catch (_) { if (mounted) setState(() => isLoading = false); }
  }

  Future<void> _saveProfile() async {
    setState(() { _isSaving = true; _errorMsg = null; });
    try {
      final session = await SessionManager.getUser();
      final id = int.tryParse(session?['user_id']?.toString() ?? '0') ?? 0;
      final res = await ApiService.updateInterpreterProfile({
        'user_id':    id.toString(),
        'first_name': firstName.text.trim(),
        'last_name':  lastName.text.trim(),
        'phone':      phone.text.trim(),
        'address':    address.text.trim(),
        'languages':  selectedLanguages.join(', '),
      });
      if (res == true) {
        await _loadProfile();
        _setEditing(false);
        _showSnack('Profile updated successfully', success: true);
      } else { setState(() => _errorMsg = 'Update failed. Please try again.'); }
    } catch (e) { setState(() => _errorMsg = 'Error: $e'); }
    finally { if (mounted) setState(() => _isSaving = false); }
  }

  void _setEditing(bool val) {
    setState(() => isEditing = val);
    val ? _expandCtrl.forward() : _expandCtrl.reverse();
  }

  String get _initials {
    final f = firstName.text.isNotEmpty ? firstName.text[0].toUpperCase() : 'I';
    final l = lastName.text.isNotEmpty  ? lastName.text[0].toUpperCase()  : '';
    return '$f$l';
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: success ? _ipDark : _idanger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  Future<void> _pickImage() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (p != null && mounted) setState(() => profileImage = File(p.path));
  }

  Future<void> _pickCV() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf','doc','docx']);
    if (r != null) setState(() { cvFile = File(r.files.single.path!); cvFileName = r.files.single.name; });
  }

  void _openLanguagesDialog() {
    showDialog(context: context, builder: (_) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Select Languages', style: TextStyle(fontWeight: FontWeight.w800, color: _ipDark)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
          children: allLanguages.map((l) => CheckboxListTile(
            title: Text(l), value: selectedLanguages.contains(l), activeColor: _ip,
            onChanged: (v) { setD(() => v! ? selectedLanguages.add(l) : selectedLanguages.remove(l)); setState(() {}); },
          )).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Done', style: TextStyle(color: _ip, fontWeight: FontWeight.w700)))],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(backgroundColor: _ibg, body: Center(child: CircularProgressIndicator(color: _ip)));
    return Scaffold(
      backgroundColor: _ibg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _buildProfileCard(),
            const SizedBox(height: 24),
            _buildCvCard(),
            const SizedBox(height: 110),
          ]),
        ),
      ),
    );
  }

  Widget _buildProfileCard() => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32),
      border: Border.all(color: _ip.withOpacity(0.08)),
      boxShadow: [BoxShadow(color: _ipDark.withOpacity(0.10), blurRadius: 48, offset: const Offset(0, 20))]),
    clipBehavior: Clip.hardEdge,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildHero(),
      if (!isEditing) _buildCompactSummary(),
      SizeTransition(sizeFactor: _expandAnim, child: _buildFormBody()),
    ]),
  );

  Widget _buildHero() => Container(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [_ipDark, _ip, _ipLight], begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: Stack(clipBehavior: Clip.none, children: [
      Positioned(right: -60, top: -80, child: Container(width: 180, height: 180,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.10)))),
      Row(children: [
        _buildAvatar(), const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('My Profile', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.1)),
          const SizedBox(height: 4),
          Text('${firstName.text} ${lastName.text}'.trim().isNotEmpty ? '${firstName.text} ${lastName.text}'.trim() : 'Update your information',
              style: TextStyle(color: Colors.white.withOpacity(0.80), fontSize: 13, fontWeight: FontWeight.w600)),
          if (gender.isNotEmpty) ...[const SizedBox(height: 2),
            Text(gender, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11))],
        ])),
        Column(children: [
          _heroBtn(Icons.logout, () async { await SessionManager.logout(); if (!mounted) return; Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const Login()), (_) => false); }),
          const SizedBox(height: 8),
          _heroBtn(isEditing ? Icons.check_circle_outline : Icons.edit_outlined, _isSaving ? null : () => isEditing ? _saveProfile() : _setEditing(true)),
        ]),
      ]),
    ]),
  );

  Widget _heroBtn(IconData icon, VoidCallback? onTap) => GestureDetector(onTap: onTap,
    child: Container(width: 36, height: 36,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(11), border: Border.all(color: Colors.white.withOpacity(0.22))),
      child: Icon(icon, color: Colors.white, size: 17)));

  Widget _buildAvatar() {
    ImageProvider? img;
    if (profileImage != null) img = FileImage(profileImage!);
    else if (photoUrl != null && photoUrl!.isNotEmpty) img = NetworkImage(photoUrl!);
    return Stack(alignment: Alignment.bottomRight, children: [
      Container(width: 72, height: 72,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.white.withOpacity(0.14),
          border: Border.all(color: Colors.white.withOpacity(0.30), width: 2),
          image: img != null ? DecorationImage(image: img, fit: BoxFit.cover) : null),
        child: img == null ? Center(child: Text(_initials, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800))) : null),
      if (isEditing) GestureDetector(onTap: _pickImage,
        child: Container(padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: _ipLight, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
          child: const Icon(Icons.camera_alt, size: 12, color: Colors.white))),
    ]);
  }

  Widget _buildCompactSummary() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.6,
        children: [
          _tile('Phone',      phone.text.isNotEmpty ? phone.text : '—',                    Icons.phone_outlined),
          _tile('Gender',     gender.isNotEmpty ? '${gender[0].toUpperCase()}${gender.substring(1)}' : '—', Icons.person_outline_rounded),
          _tile('Date of Birth', dob.isNotEmpty ? dob : '—',                               Icons.cake_outlined),
          _tile('Languages',  selectedLanguages.isNotEmpty ? selectedLanguages.join(', ') : '—', Icons.translate_outlined),
        ]),
      const SizedBox(height: 14),
      GestureDetector(onTap: () => _setEditing(true),
        child: Container(height: 42,
          decoration: BoxDecoration(color: _ip.withOpacity(0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: _ip.withOpacity(0.14))),
          alignment: Alignment.center,
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.edit_outlined, size: 15, color: _ip), SizedBox(width: 6),
            Text('Edit Profile', style: TextStyle(color: _ip, fontWeight: FontWeight.w800, fontSize: 13)),
          ]))),
    ]),
  );

  Widget _tile(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: const Color(0xFFF8F9FD), borderRadius: BorderRadius.circular(14), border: Border.all(color: _iline)),
    child: Row(children: [
      Icon(icon, size: 14, color: _imuted), const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: const TextStyle(color: _imuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        const SizedBox(height: 1),
        Text(value, style: const TextStyle(color: _ipDark, fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );

  Widget _buildFormBody() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_errorMsg != null) ...[_IBanner(message: _errorMsg!), const SizedBox(height: 16)],
      Row(children: [Expanded(child: _fw('First Name', firstName)), const SizedBox(width: 14), Expanded(child: _fw('Last Name', lastName))]),
      const SizedBox(height: 16),
      _fw('Email', email, readOnly: true),
      const SizedBox(height: 16),
      _fw('Phone', phone, keyboard: TextInputType.phone),
      const SizedBox(height: 16),
      _fw('Address', address),
      const SizedBox(height: 16),
      _fw('National ID', nationalId, keyboard: TextInputType.number),
      const SizedBox(height: 16),
      // Languages field
      _IFieldWrapper(label: 'Languages', child: GestureDetector(
        onTap: _openLanguagesDialog,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFF8F9FD), borderRadius: BorderRadius.circular(18), border: Border.all(color: _iline)),
          child: selectedLanguages.isEmpty
              ? const Align(alignment: Alignment.centerLeft, child: Text('Tap to select…', style: TextStyle(color: _imuted, fontSize: 13)))
              : Wrap(spacing: 6, runSpacing: 6, children: selectedLanguages.map((l) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _ip, borderRadius: BorderRadius.circular(8)),
                  child: Text(l, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                )).toList()),
        ),
      )),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: _IActionBtn(label: _isSaving ? 'Saving…' : 'Save Changes',
          gradient: const LinearGradient(colors: [_ip, _ipLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
          textColor: Colors.white, onTap: _isSaving ? null : _saveProfile)),
        const SizedBox(width: 12),
        Expanded(child: _IActionBtn(label: 'Cancel', color: const Color(0xFFF1F4FB), textColor: _ipDark,
          border: Border.all(color: _iline), onTap: () => setState(() { _setEditing(false); _errorMsg = null; }))),
      ]),
    ]),
  );

  Widget _fw(String label, TextEditingController c, {TextInputType keyboard = TextInputType.text, bool readOnly = false}) =>
    _IFieldWrapper(label: label, child: _IFieldInput(controller: c, enabled: !readOnly, keyboardType: keyboard));

  // ── CV Card ──────────────────────────────────────────────
  Widget _buildCvCard() => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32),
      border: Border.all(color: _ip.withOpacity(0.08)),
      boxShadow: [BoxShadow(color: _ipDark.withOpacity(0.08), blurRadius: 36, offset: const Offset(0, 14))]),
    clipBehavior: Clip.hardEdge,
    child: Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _iline))),
        child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: _ip.withOpacity(0.08), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.description_outlined, color: _ip, size: 18)),
          const SizedBox(width: 12),
          const Text('CV / Resume', style: TextStyle(color: _ipDark, fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
      ),
      Padding(padding: const EdgeInsets.all(20),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: _ip.withOpacity(0.08), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.insert_drive_file_outlined, color: _ip, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('CV File', style: TextStyle(color: _imuted, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(cvFileName ?? 'No CV uploaded', style: const TextStyle(color: _ipDark, fontSize: 14, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
          ])),
          if (isEditing) GestureDetector(onTap: _pickCV,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: _ip, borderRadius: BorderRadius.circular(12)),
              child: const Text('Upload', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)))),
        ])),
    ]),
  );
}

class _IFieldWrapper extends StatelessWidget {
  final String label; final Widget child;
  const _IFieldWrapper({required this.label, required this.child});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: _ipDark, letterSpacing: 0.3)),
    const SizedBox(height: 8), child]);
}

class _IFieldInput extends StatelessWidget {
  final TextEditingController controller; final bool enabled; final TextInputType keyboardType;
  const _IFieldInput({required this.controller, this.enabled = true, this.keyboardType = TextInputType.text});
  @override
  Widget build(BuildContext context) => TextField(controller: controller, enabled: enabled, keyboardType: keyboardType,
    style: const TextStyle(color: _ipDark, fontSize: 14, fontWeight: FontWeight.w700),
    decoration: InputDecoration(filled: true, fillColor: enabled ? const Color(0xFFF8F9FD) : const Color(0xFFF0F2F8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _iline)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _iline)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _ipLight, width: 1.5)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: _iline.withOpacity(0.6)))));
}

class _IBanner extends StatelessWidget {
  final String message; const _IBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: const Color(0xFFFFF1F1), borderRadius: BorderRadius.circular(14), border: Border.all(color: _idanger.withOpacity(0.18))),
    child: Text(message, style: const TextStyle(color: _idanger, fontWeight: FontWeight.w800, fontSize: 13)));
}

class _IActionBtn extends StatelessWidget {
  final String label; final Color? color; final Gradient? gradient;
  final Color textColor; final BoxBorder? border; final VoidCallback? onTap;
  const _IActionBtn({required this.label, required this.textColor, this.color, this.gradient, this.border, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(height: 50,
      decoration: BoxDecoration(color: color, gradient: gradient, borderRadius: BorderRadius.circular(14), border: border,
        boxShadow: gradient != null ? [BoxShadow(color: _ip.withOpacity(0.20), blurRadius: 20, offset: const Offset(0, 8))] : null),
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(color: onTap == null ? textColor.withOpacity(0.4) : textColor, fontWeight: FontWeight.w800, fontSize: 13))));
}