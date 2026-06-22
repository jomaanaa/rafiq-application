import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'session_manager.dart';
import 'package:rafiq/auth/login.dart';

class PatientRegistrationPage extends StatefulWidget {
  const PatientRegistrationPage({super.key});
  @override
  State<PatientRegistrationPage> createState() => _PatientRegistrationPageState();
}

class _PatientRegistrationPageState extends State<PatientRegistrationPage> {
  int currentStep = 0;
  final formKey   = GlobalKey<FormState>();
  final navyColor = const Color(0xFF2B2C41);

  // Step 1
  final firstNameC   = TextEditingController();
  final lastNameC    = TextEditingController();
  final emailC       = TextEditingController();
  final passwordC    = TextEditingController();
  final confirmPassC = TextEditingController();

  // Step 2
  final addressC = TextEditingController();
  final phoneC   = TextEditingController();

  String? selectedGender, selectedDisability;
  DateTime? selectedBirthDate;
  XFile?  profilePhoto;

  static final _egyptPhone = RegExp(r'^(010|011|012|015)\d{8}$');
  static final _emailRegex = RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$');

  ButtonStyle get _btnStyle => ElevatedButton.styleFrom(
    backgroundColor: navyColor,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white, elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back), color: navyColor,
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(key: formKey, child: Column(children: [
        const SizedBox(height: 20),
        Image.asset('assets/images/logo.png', height: 70),
        const SizedBox(height: 16),
        const Text("Let us know how we can assist you on your journey.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 6),
        const Text("Tell us about yourself.", textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _stepCircle(1, currentStep == 0),
          Container(width: 30, height: 2, color: Colors.grey.shade400),
          _stepCircle(2, currentStep == 1),
        ]),
        const SizedBox(height: 30),
        currentStep == 0 ? _step1() : _step2(),
        const SizedBox(height: 30),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (currentStep == 1)
            Padding(
              padding: const EdgeInsets.only(right: 15),
              child: ElevatedButton(
                style: _btnStyle,
                onPressed: () => setState(() => currentStep = 0),
                child: const Text("Previous"),
              ),
            ),
          ElevatedButton(
            style: _btnStyle,
            onPressed: _onContinue,
            child: Text(currentStep == 0 ? "Continue" : "Finish"),
          ),
        ]),
        const SizedBox(height: 30),
      ])),
    )),
  );

  // ── STEP 1 ──────────────────────────────────────────────
  Widget _step1() => Column(children: [
    Row(children: [
      Expanded(child: _field(firstNameC, "First name")),
      const SizedBox(width: 12),
      Expanded(child: _field(lastNameC, "Last name")),
    ]),
    const SizedBox(height: 16),
    _field(emailC, "Email",
        keyboard: TextInputType.emailAddress,
        hint: 'name@example.com',
        prefix: const Icon(Icons.email_outlined),
        validator: (v) {
          if (v == null || v.isEmpty) return "Required";
          if (!_emailRegex.hasMatch(v)) return "Enter a valid email";
          return null;
        }),
    const SizedBox(height: 16),
    _field(passwordC, "Password", obscure: true,
        prefix: const Icon(Icons.lock_outline),
        validator: (v) {
          if (v == null || v.isEmpty) return "Required";
          if (v.length < 8) return "Password must be at least 8 characters";
          return null;
        }),
    const SizedBox(height: 16),
    _field(confirmPassC, "Confirm password", obscure: true,
        prefix: const Icon(Icons.lock_outline),
        validator: (v) {
          if (v == null || v.isEmpty) return "Required";
          if (v != passwordC.text) return "Passwords do not match";
          return null;
        }),
  ]);

  // ── STEP 2 ──────────────────────────────────────────────
  Widget _step2() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text("Almost done!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    const SizedBox(height: 20),

    // Profile photo
    _photoPicker('Profile Photo', profilePhoto, () async {
      final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (p != null) setState(() => profilePhoto = p);
    }),
    const SizedBox(height: 16),

    _field(addressC, "Address", prefix: const Icon(Icons.location_on_outlined)),
    const SizedBox(height: 16),

// Gender radio buttons
  Row(children: [
    Icon(Icons.person_outline, size: 18, color: navyColor),
    const SizedBox(width: 8),
    const Text("Gender: ", style: TextStyle(fontSize: 13)),
    Radio<String>(
      value: "female", groupValue: selectedGender,
      activeColor: navyColor,
      onChanged: (v) => setState(() => selectedGender = v),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    const Text("Female", style: TextStyle(fontSize: 13)),
    Radio<String>(
      value: "male", groupValue: selectedGender,
      activeColor: navyColor,
      onChanged: (v) => setState(() => selectedGender = v),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    const Text("Male", style: TextStyle(fontSize: 13)),
  ]),
    const SizedBox(height: 16),

    _field(phoneC, "Phone number",
        keyboard: TextInputType.phone, maxLen: 11,
        hint: '01XXXXXXXXX',
        prefix: const Icon(Icons.phone_outlined),
        validator: (v) {
          if (v == null || v.isEmpty) return "Required";
          if (v.length != 11) return "Must be exactly 11 digits";
          if (!_egyptPhone.hasMatch(v)) return "Must start with 010, 011, 012 or 015";
          return null;
        }),
    const SizedBox(height: 16),

    // Date of birth picker
    GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime(2000),
          firstDate: DateTime(1924),
          lastDate: DateTime.now(),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: navyColor,
                onPrimary: Colors.white,
                onSurface: navyColor,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => selectedBirthDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: selectedBirthDate != null ? navyColor : navyColor.withOpacity(0.4),
            width: selectedBirthDate != null ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined, size: 18, color: navyColor),
          const SizedBox(width: 10),
          Text(
            selectedBirthDate != null
                ? '${selectedBirthDate!.day.toString().padLeft(2,'0')}/${selectedBirthDate!.month.toString().padLeft(2,'0')}/${selectedBirthDate!.year}'
                : 'Date of Birth',
            style: TextStyle(
              fontSize: 14,
              fontWeight: selectedBirthDate != null ? FontWeight.w600 : FontWeight.normal,
              color: selectedBirthDate != null ? navyColor : Colors.grey.shade500,
            ),
          ),
        ]),
      ),
    ),
    const SizedBox(height: 16),

    // Disability bottom sheet picker
    GestureDetector(
      onTap: () async {
        final result = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Select Disability Type",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Divider(),
                ...["Physical disability", "Visual impairment",
                    "Hearing impairment", "Intellectual disability"].map((d) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: navyColor.withOpacity(0.08),
                    child: Icon(Icons.accessibility_new_outlined, size: 18, color: navyColor),
                  ),
                  title: Text(d, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  trailing: selectedDisability == d
                      ? Icon(Icons.check_circle_rounded, color: navyColor)
                      : const Icon(Icons.circle_outlined, color: Colors.grey),
                  onTap: () => Navigator.pop(context, d),
                )),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
        if (result != null) setState(() => selectedDisability = result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: selectedDisability != null ? navyColor : navyColor.withOpacity(0.4),
            width: selectedDisability != null ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(Icons.accessibility_new_outlined, size: 18, color: navyColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              selectedDisability ?? "Select disability type",
              style: TextStyle(
                fontSize: 14,
                fontWeight: selectedDisability != null ? FontWeight.w600 : FontWeight.normal,
                color: selectedDisability != null ? navyColor : Colors.grey.shade500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.keyboard_arrow_down_rounded, color: navyColor),
        ]),
      ),
    ),
  ]);

  // ── Continue / Finish ────────────────────────────────────
  void _onContinue() async {
    if (!formKey.currentState!.validate()) return;

    if (currentStep == 0) {
      setState(() => currentStep = 1);
      return;
    }

    if (selectedBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select your date of birth")));
      return;
    }

    if (selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select your gender")));
      return;
    }

    try {
      final request = http.MultipartRequest(
          'POST', Uri.parse('http://10.13.114.211/Api/add_user.php'));

      request.fields.addAll({
        'firstName':  firstNameC.text.trim(),
        'lastName':   lastNameC.text.trim(),
        'email':      emailC.text.trim(),
        'password':   passwordC.text,
        'role':       'patient',
        'address':    addressC.text.trim(),
        'phone':      phoneC.text.trim(),
        'gender':     selectedGender ?? '',
        'birthDate':  '${selectedBirthDate!.year}-${selectedBirthDate!.month.toString().padLeft(2,'0')}-${selectedBirthDate!.day.toString().padLeft(2,'0')}',
        'disability': selectedDisability ?? '',
      });

      if (profilePhoto != null)
        request.files.add(
            await http.MultipartFile.fromPath('photo', profilePhoto!.path));

      final streamed = await request.send();
      final body     = await streamed.stream.bytesToString();
      final result   = jsonDecode(body);

      if (result["success"] == true) {
        await SessionManager.saveUser({
          'user_id':   result['user_id'].toString(),
          'firstName': firstNameC.text.trim(),
          'role':      'patient',
        });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const Login()),
          (route) => false,
        );
      }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("${result["message"]}")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // ── Widgets ──────────────────────────────────────────────

  Widget _photoPicker(String label, XFile? photo, VoidCallback onTap) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: navyColor.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Choose Photo', style: TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 12),
            if (photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(File(photo.path), width: 40, height: 40, fit: BoxFit.cover),
              )
            else
              Text('No photo chosen',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ]),
        ),
      ),
    ]);

  Widget _field(TextEditingController c, String label, {
    bool obscure = false,
    TextInputType keyboard = TextInputType.text,
    int? maxLen, String? hint, Widget? prefix,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: c,
    obscureText: obscure,
    keyboardType: keyboard,
    maxLength: maxLen,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      counterText: maxLen != null ? '' : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: navyColor, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      floatingLabelStyle: TextStyle(color: navyColor),
    ),
    validator: validator ?? (v) => v == null || v.isEmpty ? "Required" : null,
  );

  Widget _stepCircle(int step, bool active) => CircleAvatar(
    radius: 14,
    backgroundColor: active ? navyColor : Colors.grey.shade300,
    child: Text(step.toString(),
        style: TextStyle(color: active ? Colors.white : Colors.black54)),
  );
}