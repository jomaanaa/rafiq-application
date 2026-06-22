import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'pending_page.dart';
import 'package:rafiq/auth/api_service.dart';

class ProviderRegistrationPage extends StatefulWidget {
  final String providerType;
  const ProviderRegistrationPage({super.key, required this.providerType});

  @override
  State<ProviderRegistrationPage> createState() =>
      _ProviderRegistrationPageState();
}

class _ProviderRegistrationPageState extends State<ProviderRegistrationPage> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final Color primaryColor = const Color(0xFF2B2C41);
  int currentStep = 1;

  static final _egyptPhone = RegExp(r'^(010|011|012|015)\d{8}$');
  static final _emailRegex = RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$');

  // Step 1
  final firstNameC   = TextEditingController();
  final lastNameC    = TextEditingController();
  final emailC       = TextEditingController();
  final passwordC    = TextEditingController();
  final confirmPassC = TextEditingController();

  // Step 2
  final addressC    = TextEditingController();
  final phoneC      = TextEditingController();
  final nationalIdC = TextEditingController();

  String? gender, birthMonth, birthDay, birthYear;

  ButtonStyle get _btnStyle => ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF2B2C41),
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
  );

  // Files — all providers
  XFile?        profilePhoto;
  PlatformFile? cvFile;

  // Files — doctor only
  PlatformFile? medicalLicenseFile;

  // Step 3 — doctor
  String? selectedSpecialty;
  final doctorSpecialties = [
    'Cardiology (Heart)', 'Neurology (Brain & Nerves)',
    'Psychiatry (Mental Health)', 'Gastroenterology (Digestive System)',
  ];

  // Step 3 — caregiver
  final shiftOptions = ["Morning", "Afternoon", "Evening", "Night"];
  List<String> selectedShifts = [];

  // Step 3 — interpreter
  final langOptions = ["English", "Arabic", "French", "Spanish", "Italian", "German"];
  List<String> selectedLanguages = [];

  // Step 3 — driver
  PlatformFile? drivingLicenseFile;
  PlatformFile? carLicenseFile;
  final carModelC     = TextEditingController();
  final carMakeC      = TextEditingController();
  final carColorC     = TextEditingController();
  final licensePlateC = TextEditingController();
  bool wheelchairAccessible = false;

  bool isLoading = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: primaryColor),
      title: Text("${widget.providerType} Registration"),
    ),
    body: SafeArea(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Form(
        key: formKey,
        child: SingleChildScrollView(child: _buildStep()),
      ),
    )),
  );

  Widget _buildStep() {
    switch (currentStep) {
      case 1: return _step1();
      case 2: return _step2();
      case 3: return _step3();
      default: return Container();
    }
  }

  Widget _stepIndicator() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(3, (i) {
      final n = i + 1;
      final active = currentStep == n;
      return Row(children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: active ? primaryColor : Colors.grey[300],
          child: Text('$n', style: TextStyle(
            color: active ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          )),
        ),
        if (i < 2) Container(
          width: 40, height: 2,
          color: currentStep > n ? primaryColor : Colors.grey[300],
        ),
      ]);
    }),
  );

  // ── STEP 1 ──────────────────────────────────────────────
  Widget _step1() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const RafiqLogo(), _stepIndicator(), const SizedBox(height: 24),
    const Text("Tell us about yourself", style: TextStyle(fontSize: 16)),
    const SizedBox(height: 16),
    Row(children: [
      Flexible(child: _field(firstNameC, "First name", prefix: const Icon(Icons.person_outline))),
      const SizedBox(width: 10),
      Flexible(child: _field(lastNameC, "Last name", prefix: const Icon(Icons.person_outline))),
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
      },
    ),
    const SizedBox(height: 16),
    _field(passwordC, "Password",
      obscure: true,
      prefix: const Icon(Icons.lock_outline),
      validator: (v) {
        if (v == null || v.isEmpty) return "Required";
        if (v.length < 8) return "Password must be at least 8 characters";
        return null;
      },
    ),
    const SizedBox(height: 16),
    _field(confirmPassC, "Confirm Password",
      obscure: true,
      prefix: const Icon(Icons.lock_outline),
      validator: (v) {
        if (v == null || v.isEmpty) return "Required";
        if (v != passwordC.text) return "Passwords do not match";
        return null;
      },
    ),
    const SizedBox(height: 24),
    ElevatedButton(
      style: _btnStyle,
      onPressed: () async {
        if (await _validateStep1()) setState(() => currentStep = 2);
      },
      child: const Text("Next"),
    ),
  ]);

  // ── STEP 2 ──────────────────────────────────────────────
  Widget _step2() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const RafiqLogo(),
    _stepIndicator(),
    const SizedBox(height: 20),
    const Text("Additional Info", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
    const SizedBox(height: 16),

    _photoPicker('Profile Photo', profilePhoto, () async {
      final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (p != null) setState(() => profilePhoto = p);
    }),
    const SizedBox(height: 16),

    _field(addressC, "Address", prefix: const Icon(Icons.location_on_outlined)),
    const SizedBox(height: 16),

    // Gender
    Row(children: [
      const Icon(Icons.person_outline, size: 18, color: Colors.grey),
      const SizedBox(width: 8),
      const Text("Gender: ", style: TextStyle(fontSize: 13)),
      Radio<String>(
        value: "female", groupValue: gender,
        activeColor: primaryColor,
        onChanged: (v) => setState(() => gender = v),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      const Text("Female", style: TextStyle(fontSize: 13)),
      Radio<String>(
        value: "male", groupValue: gender,
        activeColor: primaryColor,
        onChanged: (v) => setState(() => gender = v),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      const Text("Male", style: TextStyle(fontSize: 13)),
    ]),
    const SizedBox(height: 16),

    _field(phoneC, "Phone",
      keyboard: TextInputType.phone,
      maxLen: 11,
      hint: '01XXXXXXXXX',
      prefix: const Icon(Icons.phone_outlined),
      validator: (v) {
        if (v == null || v.isEmpty) return "Required";
        if (v.length != 11) return "Must be exactly 11 digits";
        if (!_egyptPhone.hasMatch(v)) return "Must start with 010, 011, 012 or 015";
        return null;
      },
    ),
    const SizedBox(height: 16),

    _field(nationalIdC, "National ID",
      keyboard: TextInputType.number,
      maxLen: 14,
      hint: 'Enter 14 numbers',
      prefix: const Icon(Icons.badge_outlined),
      validator: (v) {
        if (v == null || v.isEmpty) return "Required";
        if (v.length != 14) return "Must be exactly 14 digits";
        return null;
      },
    ),
    const SizedBox(height: 16),

    // Date of Birth
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
                primary: primaryColor,
                onPrimary: Colors.white,
                onSurface: primaryColor,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          setState(() {
            birthDay   = picked.day.toString().padLeft(2, '0');
            birthMonth = picked.month.toString().padLeft(2, '0');
            birthYear  = picked.year.toString();
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: birthDay != null ? primaryColor : primaryColor.withOpacity(0.4),
            width: birthDay != null ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined, size: 18, color: primaryColor),
          const SizedBox(width: 10),
          Text(
            birthDay != null ? '$birthDay/$birthMonth/$birthYear' : 'Date of Birth',
            style: TextStyle(
              fontSize: 14,
              fontWeight: birthDay != null ? FontWeight.w600 : FontWeight.normal,
              color: birthDay != null ? primaryColor : Colors.grey.shade500,
            ),
          ),
        ]),
      ),
    ),
    const SizedBox(height: 16),

    _filePicker('Upload your CV', cvFile, () async {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );
      if (r != null) setState(() => cvFile = r.files.first);
    }),

    const SizedBox(height: 16),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      ElevatedButton(
        style: _btnStyle,
        onPressed: () => setState(() => currentStep = 1),
        child: const Text("Previous"),
      ),
      ElevatedButton(
        style: _btnStyle,
        onPressed: () { if (_validateStep2()) setState(() => currentStep = 3); },
        child: const Text("Next"),
      ),
    ]),
  ]);

  // ── STEP 3 ──────────────────────────────────────────────
  Widget _step3() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const RafiqLogo(), _stepIndicator(), const SizedBox(height: 24),

    if (widget.providerType == "Doctor") ...[
      const Text("Select Your Specialty:", style: TextStyle(fontSize: 16)),
      const SizedBox(height: 16),
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
                  const Text("Select Specialty",
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Divider(),
                  ...doctorSpecialties.map((s) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF2B2C41).withOpacity(0.08),
                      child: const Icon(Icons.medical_services_outlined, size: 18, color: Color(0xFF2B2C41)),
                    ),
                    title: Text(s, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    trailing: selectedSpecialty == s
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2B2C41))
                        : const Icon(Icons.circle_outlined, color: Colors.grey),
                    onTap: () => Navigator.pop(context, s),
                  )),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
          if (result != null) setState(() => selectedSpecialty = result);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: selectedSpecialty != null ? primaryColor : primaryColor.withOpacity(0.4),
              width: selectedSpecialty != null ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(Icons.medical_services_outlined, size: 18, color: primaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedSpecialty ?? "Choose specialty",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selectedSpecialty != null ? FontWeight.w600 : FontWeight.normal,
                  color: selectedSpecialty != null ? primaryColor : Colors.grey.shade500,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: primaryColor),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      _filePicker('Medical License', medicalLicenseFile, () async {
        final r = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        );
        if (r != null) setState(() => medicalLicenseFile = r.files.first);
      }),
    ],

    if (widget.providerType == "Caregiver") ...[
      const Text("Select Your Shift Preferences:", style: TextStyle(fontSize: 16)),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () async {
          await showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => StatefulBuilder(
              builder: (context, setModalState) => Container(
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
                    const Text("Select Shift Preferences",
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    const Divider(),
                    ...shiftOptions.map((s) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF2B2C41).withOpacity(0.08),
                        child: const Icon(Icons.schedule_outlined, size: 18, color: Color(0xFF2B2C41)),
                      ),
                      title: Text(s, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      trailing: selectedShifts.contains(s)
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2B2C41))
                          : const Icon(Icons.circle_outlined, color: Colors.grey),
                      onTap: () {
                        setModalState(() {
                          selectedShifts.contains(s)
                              ? selectedShifts.remove(s)
                              : selectedShifts.add(s);
                        });
                        setState(() {});
                      },
                    )),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ElevatedButton(
                        style: _btnStyle,
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Done"),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: selectedShifts.isNotEmpty ? primaryColor : primaryColor.withOpacity(0.4),
              width: selectedShifts.isNotEmpty ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(Icons.schedule_outlined, size: 18, color: primaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedShifts.isEmpty ? "Choose shift preferences" : selectedShifts.join(', '),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selectedShifts.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                  color: selectedShifts.isNotEmpty ? primaryColor : Colors.grey.shade500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: primaryColor),
          ]),
        ),
      ),
    ],

    if (widget.providerType == "Interpreter") ...[
      const Text("Select Languages You Speak:", style: TextStyle(fontSize: 16)),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () async {
          await showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => StatefulBuilder(
              builder: (context, setModalState) => Container(
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
                    const Text("Select Languages",
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    const Divider(),
                    ...langOptions.map((l) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF2B2C41).withOpacity(0.08),
                        child: const Icon(Icons.language_outlined, size: 18, color: Color(0xFF2B2C41)),
                      ),
                      title: Text(l, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      trailing: selectedLanguages.contains(l)
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2B2C41))
                          : const Icon(Icons.circle_outlined, color: Colors.grey),
                      onTap: () {
                        setModalState(() {
                          selectedLanguages.contains(l)
                              ? selectedLanguages.remove(l)
                              : selectedLanguages.add(l);
                        });
                        setState(() {});
                      },
                    )),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ElevatedButton(
                        style: _btnStyle,
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Done"),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: selectedLanguages.isNotEmpty ? primaryColor : primaryColor.withOpacity(0.4),
              width: selectedLanguages.isNotEmpty ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(Icons.language_outlined, size: 18, color: primaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedLanguages.isEmpty ? "Choose languages" : selectedLanguages.join(', '),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selectedLanguages.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                  color: selectedLanguages.isNotEmpty ? primaryColor : Colors.grey.shade500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: primaryColor),
          ]),
        ),
      ),
    ],

    if (widget.providerType == "Driver") ...[
      _filePicker('Driving License', drivingLicenseFile, () async {
        final r = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        );
        if (r != null) setState(() => drivingLicenseFile = r.files.first);
      }),
      const SizedBox(height: 16),
      _filePicker('Car License', carLicenseFile, () async {
        final r = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        );
        if (r != null) setState(() => carLicenseFile = r.files.first);
      }),
      const SizedBox(height: 16),
      _field(carModelC, "Car Model", prefix: const Icon(Icons.directions_car_outlined)),
      const SizedBox(height: 16),
      _field(carMakeC, "Car Make", prefix: const Icon(Icons.directions_car_outlined)),
      const SizedBox(height: 16),
      _field(carColorC, "Car Color", prefix: const Icon(Icons.color_lens_outlined)),
      const SizedBox(height: 16),
      _field(licensePlateC, "License Plate", prefix: const Icon(Icons.confirmation_number_outlined)),
      const SizedBox(height: 16),
      Row(children: [
        const Icon(Icons.accessible_outlined, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        const Text("Wheelchair Accessible: ", style: TextStyle(fontSize: 13)),
        Radio<bool>(
          value: true, groupValue: wheelchairAccessible,
          activeColor: primaryColor,
          onChanged: (_) => setState(() => wheelchairAccessible = true),
        ),
        const Text("Yes", style: TextStyle(fontSize: 13)),
        Radio<bool>(
          value: false, groupValue: wheelchairAccessible,
          activeColor: primaryColor,
          onChanged: (_) => setState(() => wheelchairAccessible = false),
        ),
        const Text("No", style: TextStyle(fontSize: 13)),
      ]),
    ],

    const SizedBox(height: 24),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      ElevatedButton(
        style: _btnStyle,
        onPressed: () => setState(() => currentStep = 2),
        child: const Text("Previous"),
      ),
      ElevatedButton(
        style: _btnStyle,
        onPressed: _isStep3Valid() ? _register : null,
        child: isLoading
            ? const SizedBox(
                height: 22, width: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text("Continue"),
      ),
    ]),
  ]);

  // ── Validate Step 1 ──────────────────────────────────────
  Future<bool> _validateStep1() async {
    if (!formKey.currentState!.validate()) return false;

    final taken = await ApiService.isEmailTaken(emailC.text.trim());
    if (taken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This email is already registered")),
        );
      }
      return false;
    }

    return true;
  }

  // ── Validate Step 2 ──────────────────────────────────────
  bool _validateStep2() {
    if ([addressC, phoneC, nationalIdC].any((c) => c.text.isEmpty) ||
        gender == null || birthDay == null || birthMonth == null || birthYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return false;
    }
    if (!_egyptPhone.hasMatch(phoneC.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Enter a valid Egyptian phone number (010, 011, 012, 015)"),
      ));
      return false;
    }
    if (nationalIdC.text.length != 14) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("National ID must be exactly 14 digits"),
      ));
      return false;
    }
    return true;
  }

  // ── Register ─────────────────────────────────────────────
  Future<void> _register() async {
    setState(() => isLoading = true);
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.13.114.211/Api/register_provider.php'),
      );

      request.fields.addAll({
        'firstName':            firstNameC.text.trim(),
        'lastName':             lastNameC.text.trim(),
        'email':                emailC.text.trim(),
        'password':             passwordC.text.trim(),
        'role':                 'provider',
        'providerType':         widget.providerType.toLowerCase(),
        'address':              addressC.text.trim(),
        'phone':                phoneC.text.trim(),
        'nationalId':           nationalIdC.text.trim(),
        'gender':               gender ?? '',
        'birthDate':            '$birthYear-$birthMonth-$birthDay',
        'specialty':            selectedSpecialty ?? '',
        'shifts':               jsonEncode(selectedShifts),
        'languages':            jsonEncode(selectedLanguages),
        'carModel':             carModelC.text.trim(),
        'carMake':              carMakeC.text.trim(),
        'carColor':             carColorC.text.trim(),
        'licensePlate':         licensePlateC.text.trim(),
        'wheelchairAccessible': wheelchairAccessible ? '1' : '0',
      });

      if (profilePhoto != null)
        request.files.add(await http.MultipartFile.fromPath('photo', profilePhoto!.path));
      if (cvFile?.path != null)
        request.files.add(await http.MultipartFile.fromPath('cv', cvFile!.path!));
      if (medicalLicenseFile?.path != null)
        request.files.add(await http.MultipartFile.fromPath('medical_license', medicalLicenseFile!.path!));
      if (drivingLicenseFile?.path != null)
        request.files.add(await http.MultipartFile.fromPath('driving_license', drivingLicenseFile!.path!));
      if (carLicenseFile?.path != null)
        request.files.add(await http.MultipartFile.fromPath('car_license', carLicenseFile!.path!));

      final streamed = await request.send();
      final body     = await streamed.stream.bytesToString();
      final data     = jsonDecode(body);

      if (streamed.statusCode == 200 && data['success'] == true) {
        final userId = int.tryParse(data['user_id'].toString()) ?? 0;
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => PendingPage(
              userId: userId,
              providerType: widget.providerType.toLowerCase(),
            )),
            (_) => false,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? "Registration failed")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  bool _isStep3Valid() {
    switch (widget.providerType) {
      case "Doctor":      return selectedSpecialty != null;
      case "Caregiver":   return selectedShifts.isNotEmpty;
      case "Interpreter": return selectedLanguages.isNotEmpty;
      case "Driver":
        return drivingLicenseFile != null && carLicenseFile != null &&
            carModelC.text.isNotEmpty && carMakeC.text.isNotEmpty &&
            carColorC.text.isNotEmpty && licensePlateC.text.isNotEmpty;
      default: return false;
    }
  }

  // ── Widgets ──────────────────────────────────────────────

  Widget _filePicker(String label, PlatformFile? file, VoidCallback onTap) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: primaryColor.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(Icons.upload_file_outlined, size: 18, color: primaryColor),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Choose File', style: TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(
              file == null ? 'No file chosen' : file.name,
              style: TextStyle(
                color: file == null ? Colors.grey.shade500 : Colors.black87,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            )),
          ]),
        ),
      ),
    ]);

  Widget _photoPicker(String label, XFile? photo, VoidCallback onTap) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: primaryColor.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(Icons.photo_camera_outlined, size: 18, color: primaryColor),
            const SizedBox(width: 10),
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
    int? maxLen,
    String? hint,
    Widget? prefix,
    bool dense = false,
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
      isDense: dense,
      contentPadding: dense
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          : null,
      counterText: maxLen != null ? '' : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      floatingLabelStyle: TextStyle(color: primaryColor),
    ),
    validator: validator ?? (v) => v == null || v.isEmpty ? "Required" : null,
  );
}

class RafiqLogo extends StatelessWidget {
  const RafiqLogo({super.key});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Image.asset('assets/images/logo.png', height: 60),
  ));
}