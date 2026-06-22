import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rafiq/auth/api_service.dart';
import 'package:rafiq/auth/session_manager.dart';
import 'package:rafiq/auth/login.dart';

const _cprimary      = Color(0xFF404066);
const _cprimaryDark  = Color(0xFF2B2C41);
const _cprimaryLight = Color(0xFF6D73C8);
const _cbgColor      = Color(0xFFF6F8FD);
const _cmutedColor   = Color(0xFF6E7388);
const _clineColor    = Color(0xFFE7E9F2);
const _cdangerColor  = Color(0xFFB53535);

class CaregiverProfileScreen extends StatefulWidget {
  const CaregiverProfileScreen({super.key});
  @override
  State<CaregiverProfileScreen> createState() => _CaregiverProfileScreenState();
}

class _CaregiverProfileScreenState extends State<CaregiverProfileScreen>
    with SingleTickerProviderStateMixin {

  bool isLoading = true;
  bool isEditing = false;
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

  String  gender          = '';
  String  shiftPreference = 'Morning';
  String? photoUrl;
  File?   profileImage;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _expandAnim = CurvedAnimation(parent: _expandCtrl, curve: Curves.easeInOutCubic);
    loadProfile();
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    firstName.dispose(); lastName.dispose(); email.dispose();
    phone.dispose(); address.dispose(); nationalId.dispose();
    super.dispose();
  }

  Future<void> loadProfile() async {
    final userId = await SessionManager.getUserId();
    if (userId == null) return;
    final res = await ApiService.getCaregiverProfile(userId);
    if (res['status'] == 'success') {
      final data = res['data'];
      setState(() {
        firstName.text  = data['first_name']       ?? '';
        lastName.text   = data['last_name']        ?? '';
        email.text      = data['email']            ?? '';
        phone.text      = data['phone']            ?? '';
        address.text    = data['address']          ?? '';
        nationalId.text = data['national_id']      ?? '';
        shiftPreference = data['shift_preference'] ?? 'Morning';
        gender          = data['gender']           ?? '';
        photoUrl        = data['photo'];
        isLoading       = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() { _isSaving = true; _errorMsg = null; });
    try {
      final userId = await SessionManager.getUserId();
      final res = await ApiService.updateCaregiverProfile(
        userId: userId!,
        firstName: firstName.text,
        lastName:  lastName.text,
        phone:     phone.text,
        address:   address.text,
        nationalId: nationalId.text,
        shiftPreference: shiftPreference,
      );
      if (res['success'] == true) {
        await loadProfile();
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
    final f = firstName.text.isNotEmpty ? firstName.text[0].toUpperCase() : 'C';
    final l = lastName.text.isNotEmpty  ? lastName.text[0].toUpperCase()  : '';
    return '$f$l';
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: success ? _cprimaryDark : _cdangerColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  Future<void> _pickImage() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (p != null && mounted) setState(() => profileImage = File(p.path));
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(backgroundColor: _cbgColor, body: Center(child: CircularProgressIndicator(color: _cprimary)));
    return Scaffold(
      backgroundColor: _cbgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _buildProfileCard(),
            const SizedBox(height: 110),
          ]),
        ),
      ),
    );
  }

  Widget _buildProfileCard() => Container(
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(32),
      border: Border.all(color: _cprimary.withOpacity(0.08)),
      boxShadow: [BoxShadow(color: _cprimaryDark.withOpacity(0.10), blurRadius: 48, offset: const Offset(0, 20))],
    ),
    clipBehavior: Clip.hardEdge,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildHero(),
      if (!isEditing) _buildCompactSummary(),
      SizeTransition(sizeFactor: _expandAnim, child: _buildFormBody()),
    ]),
  );

  Widget _buildHero() => Container(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [_cprimaryDark, _cprimary, _cprimaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
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
          if (gender.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(gender, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11)),
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
    child: Container(width: 36, height: 36,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(11), border: Border.all(color: Colors.white.withOpacity(0.22))),
      child: Icon(icon, color: Colors.white, size: 17)),
  );

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
      if (isEditing)
        GestureDetector(onTap: _pickImage,
          child: Container(padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: _cprimaryLight, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
            child: const Icon(Icons.camera_alt, size: 12, color: Colors.white))),
    ]);
  }

  Widget _buildCompactSummary() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.6,
        children: [
          _infoTile('Phone',      phone.text.isNotEmpty ? phone.text : '—',       Icons.phone_outlined),
          _infoTile('Gender',     gender.isNotEmpty ? '${gender[0].toUpperCase()}${gender.substring(1)}' : '—', Icons.person_outline_rounded),
          _infoTile('Shift',      shiftPreference,                                  Icons.work_outline_rounded),
          _infoTile('National ID', nationalId.text.isNotEmpty ? nationalId.text : '—', Icons.badge_outlined),
        ],
      ),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: () => _setEditing(true),
        child: Container(height: 42,
          decoration: BoxDecoration(color: _cprimary.withOpacity(0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: _cprimary.withOpacity(0.14))),
          alignment: Alignment.center,
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.edit_outlined, size: 15, color: _cprimary),
            SizedBox(width: 6),
            Text('Edit Profile', style: TextStyle(color: _cprimary, fontWeight: FontWeight.w800, fontSize: 13)),
          ])),
      ),
    ]),
  );

  Widget _infoTile(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: const Color(0xFFF8F9FD), borderRadius: BorderRadius.circular(14), border: Border.all(color: _clineColor)),
    child: Row(children: [
      Icon(icon, size: 14, color: _cmutedColor), const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: const TextStyle(color: _cmutedColor, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        const SizedBox(height: 1),
        Text(value, style: const TextStyle(color: _cprimaryDark, fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );

  Widget _buildFormBody() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_errorMsg != null) ...[_CErrorBanner(message: _errorMsg!), const SizedBox(height: 16)],
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
      _CFieldWrapper(label: 'Shift Preference', child: Container(
        height: 54, padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: const Color(0xFFF8F9FD), borderRadius: BorderRadius.circular(18), border: Border.all(color: _clineColor)),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: ['Morning','Afternoon','Evening','Night'].contains(shiftPreference) ? shiftPreference : 'Morning',
          isExpanded: true,
          style: const TextStyle(color: _cprimaryDark, fontSize: 14, fontWeight: FontWeight.w700),
          items: ['Morning','Afternoon','Evening','Night'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => shiftPreference = v!),
        )),
      )),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: _CActionButton(
          label: _isSaving ? 'Saving…' : 'Save Changes',
          gradient: const LinearGradient(colors: [_cprimary, _cprimaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
          textColor: Colors.white, onTap: _isSaving ? null : _saveProfile,
        )),
        const SizedBox(width: 12),
        Expanded(child: _CActionButton(
          label: 'Cancel', color: const Color(0xFFF1F4FB), textColor: _cprimaryDark,
          border: Border.all(color: _clineColor),
          onTap: () => setState(() { _setEditing(false); _errorMsg = null; }),
        )),
      ]),
    ]),
  );

  Widget _field(String label, TextEditingController c, {TextInputType keyboard = TextInputType.text, bool readOnly = false}) =>
    _CFieldWrapper(label: label, child: _CFieldInput(controller: c, enabled: !readOnly, keyboardType: keyboard));
}

class _CFieldWrapper extends StatelessWidget {
  final String label; final Widget child;
  const _CFieldWrapper({required this.label, required this.child});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: _cprimaryDark, letterSpacing: 0.3)),
    const SizedBox(height: 8), child,
  ]);
}

class _CFieldInput extends StatelessWidget {
  final TextEditingController controller; final bool enabled; final TextInputType keyboardType;
  const _CFieldInput({required this.controller, this.enabled = true, this.keyboardType = TextInputType.text});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller, enabled: enabled, keyboardType: keyboardType,
    style: const TextStyle(color: _cprimaryDark, fontSize: 14, fontWeight: FontWeight.w700),
    decoration: InputDecoration(
      filled: true, fillColor: enabled ? const Color(0xFFF8F9FD) : const Color(0xFFF0F2F8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _clineColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _clineColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _cprimaryLight, width: 1.5)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: _clineColor.withOpacity(0.6))),
    ),
  );
}

class _CErrorBanner extends StatelessWidget {
  final String message;
  const _CErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: const Color(0xFFFFF1F1), borderRadius: BorderRadius.circular(14), border: Border.all(color: _cdangerColor.withOpacity(0.18))),
    child: Text(message, style: const TextStyle(color: _cdangerColor, fontWeight: FontWeight.w800, fontSize: 13)),
  );
}

class _CActionButton extends StatelessWidget {
  final String label; final Color? color; final Gradient? gradient;
  final Color textColor; final BoxBorder? border; final VoidCallback? onTap;
  const _CActionButton({required this.label, required this.textColor, this.color, this.gradient, this.border, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(height: 50,
      decoration: BoxDecoration(color: color, gradient: gradient, borderRadius: BorderRadius.circular(14), border: border,
        boxShadow: gradient != null ? [BoxShadow(color: _cprimary.withOpacity(0.20), blurRadius: 20, offset: const Offset(0, 8))] : null),
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(color: onTap == null ? textColor.withOpacity(0.4) : textColor, fontWeight: FontWeight.w800, fontSize: 13)),
    ),
  );
}