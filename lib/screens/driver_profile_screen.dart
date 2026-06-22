import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:rafiq/auth/api_service.dart';
import 'package:rafiq/auth/session_manager.dart';
import 'package:rafiq/auth/login.dart';

const _dp      = Color(0xFF404066);
const _dpDark  = Color(0xFF2B2C41);
const _dpLight = Color(0xFF6D73C8);
const _dbg     = Color(0xFFF6F8FD);
const _dmuted  = Color(0xFF6E7388);
const _dline   = Color(0xFFE7E9F2);
const _ddanger = Color(0xFFB53535);

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});
  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen>
    with SingleTickerProviderStateMixin {

  bool isEditing = false;
  bool isLoading = true;
  bool _isSaving = false;
  String? _errorMsg;

  late AnimationController _expandCtrl;
  late Animation<double>   _expandAnim;

  final firstName    = TextEditingController();
  final lastName     = TextEditingController();
  final email        = TextEditingController();
  final phone        = TextEditingController();
  final address      = TextEditingController();
  final nationalId   = TextEditingController();
  final carColor     = TextEditingController();
  final carModel     = TextEditingController();
  final carMake      = TextEditingController();
  final licensePlate = TextEditingController();

  String  gender               = '';
  String  dob                  = '';
  String  wheelchairAccessible = 'No';
  File?   profileImage;
  File?   cvFile;
  String? cvFileName;
  File?   driverLicenseFile;
  String? driverLicenseName;
  File?   carLicenseFile;
  String? carLicenseName;
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
    firstName.dispose(); lastName.dispose(); email.dispose(); phone.dispose();
    address.dispose(); nationalId.dispose(); carColor.dispose(); carModel.dispose();
    carMake.dispose(); licensePlate.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final session = await SessionManager.getUser();
      final id = int.tryParse(session?['user_id']?.toString() ?? '0') ?? 0;
      final data = await ApiService.getDriverProfile(id);
      if (mounted && data != null) {
        setState(() {
          firstName.text    = data['first_name']  ?? '';
          lastName.text     = data['last_name']   ?? '';
          email.text        = data['email']       ?? '';
          phone.text        = data['phone']       ?? '';
          address.text      = data['address']     ?? '';
          nationalId.text   = data['national_id'] ?? '';
          carColor.text     = data['car_color']   ?? '';
          carModel.text     = data['car_model']   ?? '';
          carMake.text      = data['car_make']    ?? '';
          licensePlate.text = data['license_plate'] ?? '';
          gender            = data['gender']      ?? '';
          dob               = data['dob']         ?? '';
          wheelchairAccessible = data['wheelchair_accessible'] ?? 'No';
          cvFileName        = data['cv'];
          driverLicenseName = data['driver_license'];
          carLicenseName    = data['car_license'];
          photoUrl          = data['photo'];
          isLoading         = false;
        });
      } else { if (mounted) setState(() => isLoading = false); }
    } catch (_) { if (mounted) setState(() => isLoading = false); }
  }

  Future<void> _saveProfile() async {
    setState(() { _isSaving = true; _errorMsg = null; });
    try {
      final session = await SessionManager.getUser();
      final id = int.tryParse(session?['user_id']?.toString() ?? '0') ?? 0;
      final res = await ApiService.updateDriverProfile({
        'user_id':               id.toString(),
        'first_name':            firstName.text.trim(),
        'last_name':             lastName.text.trim(),
        'phone':                 phone.text.trim(),
        'address':               address.text.trim(),
        'car_color':             carColor.text.trim(),
        'car_model':             carModel.text.trim(),
        'car_make':              carMake.text.trim(),
        'license_plate':         licensePlate.text.trim(),
        'wheelchair_accessible': wheelchairAccessible,
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
    final f = firstName.text.isNotEmpty ? firstName.text[0].toUpperCase() : 'D';
    final l = lastName.text.isNotEmpty  ? lastName.text[0].toUpperCase()  : '';
    return '$f$l';
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: success ? _dpDark : _ddanger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  Future<void> _pickImage() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (p != null && mounted) setState(() => profileImage = File(p.path));
  }

  Future<void> _pickCV()            async => _pickDoc((f, n) { cvFile = f; cvFileName = n; });
  Future<void> _pickDriverLicense() async => _pickDoc((f, n) { driverLicenseFile = f; driverLicenseName = n; });
  Future<void> _pickCarLicense()    async => _pickDoc((f, n) { carLicenseFile = f; carLicenseName = n; });

  Future<void> _pickDoc(Function(File, String) onPicked) async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf','jpg','png']);
    if (r != null) setState(() => onPicked(File(r.files.single.path!), r.files.single.name));
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(backgroundColor: _dbg, body: Center(child: CircularProgressIndicator(color: _dp)));
    return Scaffold(
      backgroundColor: _dbg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _buildProfileCard(),
            const SizedBox(height: 24),
            _buildDocumentsCard(),
            const SizedBox(height: 110),
          ]),
        ),
      ),
    );
  }

  // ── Profile Card ─────────────────────────────────────────
  Widget _buildProfileCard() => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32),
      border: Border.all(color: _dp.withOpacity(0.08)),
      boxShadow: [BoxShadow(color: _dpDark.withOpacity(0.10), blurRadius: 48, offset: const Offset(0, 20))]),
    clipBehavior: Clip.hardEdge,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildHero(),
      if (!isEditing) _buildCompactSummary(),
      SizeTransition(sizeFactor: _expandAnim, child: _buildFormBody()),
    ]),
  );

  Widget _buildHero() => Container(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [_dpDark, _dp, _dpLight], begin: Alignment.topLeft, end: Alignment.bottomRight)),
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
        ])),
        Column(children: [
          _hBtn(Icons.logout, () async { await SessionManager.logout(); if (!mounted) return; Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const Login()), (_) => false); }),
          const SizedBox(height: 8),
          _hBtn(isEditing ? Icons.check_circle_outline : Icons.edit_outlined, _isSaving ? null : () => isEditing ? _saveProfile() : _setEditing(true)),
        ]),
      ]),
    ]),
  );

  Widget _hBtn(IconData icon, VoidCallback? onTap) => GestureDetector(onTap: onTap,
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
          decoration: BoxDecoration(color: _dpLight, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
          child: const Icon(Icons.camera_alt, size: 12, color: Colors.white))),
    ]);
  }

  // ── Compact Summary ──────────────────────────────────────
  Widget _buildCompactSummary() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.6,
        children: [
          _dTile('Phone',       phone.text.isNotEmpty ? phone.text : '—',    Icons.phone_outlined),
          _dTile('Gender',      gender.isNotEmpty ? '${gender[0].toUpperCase()}${gender.substring(1)}' : '—', Icons.person_outline_rounded),
          _dTile('Car',         carMake.text.isNotEmpty ? '${carMake.text} ${carModel.text}'.trim() : '—', Icons.directions_car_outlined),
          _dTile('Plate',       licensePlate.text.isNotEmpty ? licensePlate.text : '—', Icons.pin_outlined),
        ]),
      const SizedBox(height: 14),
      // Wheelchair
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFF8F9FD), borderRadius: BorderRadius.circular(14), border: Border.all(color: _dline)),
        child: Row(children: [
          const Icon(Icons.accessible_rounded, size: 14, color: _dmuted), const SizedBox(width: 8),
          const Text('Wheelchair Accessible', style: TextStyle(color: _dmuted, fontSize: 9, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text(wheelchairAccessible, style: const TextStyle(color: _dpDark, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
      const SizedBox(height: 14),
      GestureDetector(onTap: () => _setEditing(true),
        child: Container(height: 42,
          decoration: BoxDecoration(color: _dp.withOpacity(0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: _dp.withOpacity(0.14))),
          alignment: Alignment.center,
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.edit_outlined, size: 15, color: _dp), SizedBox(width: 6),
            Text('Edit Profile', style: TextStyle(color: _dp, fontWeight: FontWeight.w800, fontSize: 13)),
          ]))),
    ]),
  );

  Widget _dTile(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: const Color(0xFFF8F9FD), borderRadius: BorderRadius.circular(14), border: Border.all(color: _dline)),
    child: Row(children: [
      Icon(icon, size: 14, color: _dmuted), const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: const TextStyle(color: _dmuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        const SizedBox(height: 1),
        Text(value, style: const TextStyle(color: _dpDark, fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );

  // ── Edit Form ────────────────────────────────────────────
  Widget _buildFormBody() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_errorMsg != null) ...[_DErrorBanner(message: _errorMsg!), const SizedBox(height: 16)],
      Row(children: [Expanded(child: _dfw('First Name', firstName)), const SizedBox(width: 14), Expanded(child: _dfw('Last Name', lastName))]),
      const SizedBox(height: 16),
      _dfw('Email', email, readOnly: true),
      const SizedBox(height: 16),
      _dfw('Phone', phone, keyboard: TextInputType.phone),
      const SizedBox(height: 16),
      _dfw('Address', address),
      const SizedBox(height: 16),
      _dfw('National ID', nationalId, keyboard: TextInputType.number),
      const SizedBox(height: 20),
      // Car info in form
      const Text('Car Info', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _dpDark, letterSpacing: 0.3)),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: _dfw('Car Color', carColor)), const SizedBox(width: 14), Expanded(child: _dfw('Car Model', carModel))]),
      const SizedBox(height: 16),
      Row(children: [Expanded(child: _dfw('Car Make', carMake)), const SizedBox(width: 14), Expanded(child: _dfw('License Plate', licensePlate))]),
      const SizedBox(height: 16),
      _DFieldWrapper(label: 'Wheelchair Accessible', child: Container(
        height: 54, padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: const Color(0xFFF8F9FD), borderRadius: BorderRadius.circular(18), border: Border.all(color: _dline)),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: ['Yes','No'].contains(wheelchairAccessible) ? wheelchairAccessible : 'No',
          isExpanded: true,
          style: const TextStyle(color: _dpDark, fontSize: 14, fontWeight: FontWeight.w700),
          items: const [DropdownMenuItem(value: 'Yes', child: Text('Yes')), DropdownMenuItem(value: 'No', child: Text('No'))],
          onChanged: (v) => setState(() => wheelchairAccessible = v!),
        )),
      )),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: _DActionBtn(label: _isSaving ? 'Saving…' : 'Save Changes',
          gradient: const LinearGradient(colors: [_dp, _dpLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
          textColor: Colors.white, onTap: _isSaving ? null : _saveProfile)),
        const SizedBox(width: 12),
        Expanded(child: _DActionBtn(label: 'Cancel', color: const Color(0xFFF1F4FB), textColor: _dpDark,
          border: Border.all(color: _dline), onTap: () => setState(() { _setEditing(false); _errorMsg = null; }))),
      ]),
    ]),
  );

  Widget _dfw(String label, TextEditingController c, {TextInputType keyboard = TextInputType.text, bool readOnly = false}) =>
    _DFieldWrapper(label: label, child: _DFieldInput(controller: c, enabled: !readOnly, keyboardType: keyboard));

  // ── Documents Card ───────────────────────────────────────
  Widget _buildDocumentsCard() => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32),
      border: Border.all(color: _dp.withOpacity(0.08)),
      boxShadow: [BoxShadow(color: _dpDark.withOpacity(0.08), blurRadius: 36, offset: const Offset(0, 14))]),
    clipBehavior: Clip.hardEdge,
    child: Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _dline))),
        child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: _dp.withOpacity(0.08), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.folder_outlined, color: _dp, size: 18)),
          const SizedBox(width: 12),
          const Text('Documents', style: TextStyle(color: _dpDark, fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
      ),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(children: [
          _docRow('CV / Resume',    Icons.description_outlined,  cvFileName,        _pickCV),
          const Divider(height: 1, color: _dline),
          _docRow('Driver License', Icons.badge_outlined,         driverLicenseName, _pickDriverLicense),
          const Divider(height: 1, color: _dline),
          _docRow('Car License',    Icons.car_repair_outlined,    carLicenseName,    _pickCarLicense),
        ])),
    ]),
  );

  Widget _docRow(String label, IconData icon, String? name, VoidCallback onPick) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: _dp.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: _dp, size: 18)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: _dmuted, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(name ?? 'Not uploaded', style: TextStyle(color: name != null ? _dpDark : _dmuted, fontSize: 13, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
      ])),
      if (isEditing) GestureDetector(onTap: onPick,
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: _dp, borderRadius: BorderRadius.circular(12)),
          child: const Text('Upload', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)))),
    ]),
  );
}

class _DFieldWrapper extends StatelessWidget {
  final String label; final Widget child;
  const _DFieldWrapper({required this.label, required this.child});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: _dpDark, letterSpacing: 0.3)),
    const SizedBox(height: 8), child]);
}

class _DFieldInput extends StatelessWidget {
  final TextEditingController controller; final bool enabled; final TextInputType keyboardType;
  const _DFieldInput({required this.controller, this.enabled = true, this.keyboardType = TextInputType.text});
  @override
  Widget build(BuildContext context) => TextField(controller: controller, enabled: enabled, keyboardType: keyboardType,
    style: const TextStyle(color: _dpDark, fontSize: 14, fontWeight: FontWeight.w700),
    decoration: InputDecoration(filled: true, fillColor: enabled ? const Color(0xFFF8F9FD) : const Color(0xFFF0F2F8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _dline)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _dline)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _dpLight, width: 1.5)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: _dline.withOpacity(0.6)))));
}

class _DErrorBanner extends StatelessWidget {
  final String message; const _DErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: const Color(0xFFFFF1F1), borderRadius: BorderRadius.circular(14), border: Border.all(color: _ddanger.withOpacity(0.18))),
    child: Text(message, style: const TextStyle(color: _ddanger, fontWeight: FontWeight.w800, fontSize: 13)));
}

class _DActionBtn extends StatelessWidget {
  final String label; final Color? color; final Gradient? gradient;
  final Color textColor; final BoxBorder? border; final VoidCallback? onTap;
  const _DActionBtn({required this.label, required this.textColor, this.color, this.gradient, this.border, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(height: 50,
      decoration: BoxDecoration(color: color, gradient: gradient, borderRadius: BorderRadius.circular(14), border: border,
        boxShadow: gradient != null ? [BoxShadow(color: _dp.withOpacity(0.20), blurRadius: 20, offset: const Offset(0, 8))] : null),
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(color: onTap == null ? textColor.withOpacity(0.4) : textColor, fontWeight: FontWeight.w800, fontSize: 13))));
}