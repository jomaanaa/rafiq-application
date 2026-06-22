import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rafiq/auth/api_service.dart';
import 'package:rafiq/auth/session_manager.dart';
import 'package:rafiq/services/success.dart';

// ---------------------------------------------------------------------------
// Card number input formatter
// ---------------------------------------------------------------------------
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 19 ? digits.substring(0, 19) : digits;
    final buffer = StringBuffer();
    for (int i = 0; i < capped.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(capped[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ---------------------------------------------------------------------------
// Expiry formatter
// ---------------------------------------------------------------------------
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 4 ? digits.substring(0, 4) : digits;
    String formatted = capped;
    if (capped.length > 2) {
      formatted = '${capped.substring(0, 2)}/${capped.substring(2)}';
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ---------------------------------------------------------------------------
// Design tokens — mirroring the PHP stylesheet
// ---------------------------------------------------------------------------
const Color _kNavy      = Color(0xFF2D2D5A);
const Color _kNavy2     = Color(0xFF30335F);
const Color _kNavy3     = Color(0xFF555991);
const Color _kCardDark  = Color(0xFF17182D);
const Color _kCardMid   = Color(0xFF2C315F);
const Color _kCardLight = Color(0xFF3F426F);
const Color _kAccent    = Color(0xFFEDCC6F);   // gold
const Color _kInk       = Color(0xFF23243A);
const Color _kSoft      = Color(0xFF6F748B);
const Color _kMuted     = Color(0xFF8B91A6);
const Color _kBg        = Color(0xFFF8F8FF);
const Color _kLine      = Color(0xFFE4E6F5);
const Color _kGreen     = Color(0xFF168653);
const Color _kGreenBg   = Color(0xFFEEFBF4);
const Color _kBluePill  = Color(0xFF4A56B0);
const Color _kBluePillBg = Color(0xFFEEF0FF);

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------
class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  const PaymentScreen({super.key, required this.bookingData});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  int _selectedMethod = 1; // 1 = Credit Card, 2 = Cash
  bool _isProcessing = false;
  Map<String, dynamic>? currentUser;

  final _cardHolderCtrl = TextEditingController();
  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl     = TextEditingController();
  final _cvvCtrl        = TextEditingController();

  String _liveHolder  = 'YOUR NAME';
  String _liveNumber  = '•••• •••• •••• ••••';
  String _liveExpiry  = 'MM/YY';
  String _liveBrand   = 'CARD';

  String? _holderError;
  String? _numberError;
  String? _expiryError;
  String? _cvvError;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _cardHolderCtrl.dispose();
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await SessionManager.getUser();
    if (mounted) setState(() => currentUser = user);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Resolves the provider's display name across all service types.
  /// Doctors may arrive as doctor_name / provider_name / name,
  /// caregivers/interpreters as first_name + last_name.
  String _resolveProviderName() {
    final d = widget.bookingData;

    // 1. Explicit full-name fields (some doctor APIs return this)
    final fullName = d['doctor_name'] ?? d['provider_name'] ?? d['name'];
    if (fullName != null && fullName.toString().trim().isNotEmpty) {
      return fullName.toString().trim();
    }

    // 2. first_name + last_name (caregivers, interpreters, some doctors)
    final first = (d['first_name'] ?? '').toString().trim();
    final last  = (d['last_name']  ?? '').toString().trim();
    if (first.isNotEmpty || last.isNotEmpty) {
      return '$first $last'.trim();
    }

    return 'Service Provider';
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return "00:00 AM";
    // Strip seconds if present: "HH:MM:SS" → "HH:MM"
    final parts = timeStr.split(':');
    if (parts.length < 2) return timeStr;
    try {
      int hour     = int.parse(parts[0]);
      int minute   = int.parse(parts[1]);
      final period = hour >= 12 ? "PM" : "AM";
      hour         = hour % 12 == 0 ? 12 : hour % 12;
      return "$hour:${minute.toString().padLeft(2, '0')} $period";
    } catch (_) {
      return timeStr;
    }
  }

  /// `service_time` from all selection screens is the slot END time (e.g. "17:00:00"),
  /// not a duration — so we just format it directly.
  String _formatEndTime(String? endTimeRaw) {
    if (endTimeRaw == null || endTimeRaw.trim().isEmpty) return "End Time";
    return _formatTime(endTimeRaw);
  }

  String _detectBrand(String rawNumber) {
    final digits = rawNumber.replaceAll(RegExp(r'\D'), '');
    if (RegExp(r'^4').hasMatch(digits))                return 'VISA';
    if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(digits)) return 'MASTERCARD';
    if (RegExp(r'^3[47]').hasMatch(digits))            return 'AMEX';
    return 'CARD';
  }

  // ── Validation ────────────────────────────────────────────────────────────

  bool _validateCard() {
    final holder = _cardHolderCtrl.text.trim();
    final digits = _cardNumberCtrl.text.replaceAll(RegExp(r'\D'), '');
    final expiry = _expiryCtrl.text.trim();
    final cvv    = _cvvCtrl.text.trim();

    String? holderErr, numberErr, expiryErr, cvvErr;

    if (holder.isEmpty)                                                holderErr = "Please enter the card holder name.";
    if (digits.length < 12 || digits.length > 19)                     numberErr = "Please enter a valid card number.";
    if (!RegExp(r'^(0[1-9]|1[0-2])\/([0-9]{2})$').hasMatch(expiry))  expiryErr = "Enter a valid expiry date (MM/YY).";
    if (!RegExp(r'^[0-9]{3,4}$').hasMatch(cvv))                       cvvErr    = "Enter a valid CVV (3–4 digits).";

    setState(() {
      _holderError = holderErr;
      _numberError = numberErr;
      _expiryError = expiryErr;
      _cvvError    = cvvErr;
    });

    return holderErr == null && numberErr == null &&
           expiryErr == null && cvvErr == null;
  }

  // ── Submission ────────────────────────────────────────────────────────────

  void _confirmBooking() async {
    if (_selectedMethod == 1 && !_validateCard()) return;
    setState(() => _isProcessing = true);

    Map<String, dynamic> finalData = Map<String, dynamic>.from(widget.bookingData);

    if (_selectedMethod == 1) {
      final digits = _cardNumberCtrl.text.replaceAll(RegExp(r'\D'), '');
      finalData['payment_method'] = "visa";
      finalData['card_holder']    = _cardHolderCtrl.text.trim();
      finalData['card_last4']     = digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
      finalData['card_brand']     = _detectBrand(_cardNumberCtrl.text);
    } else {
      finalData['payment_method'] = "cash";
    }

    if (currentUser != null) {
      finalData['patient_id'] = currentUser!['user_id'] ?? finalData['patient_id'];
    }

    try {
      final result = await ApiService.addBooking(finalData);
      print('RESULT: $result');        // ADD
      print('DATA SENT: $finalData'); 
      if (result['success'] == true && mounted) {
        if (result['booking_id'] != null) {
          finalData['booking_id'] = result['booking_id'].toString();
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SuccessScreen(bookingData: finalData)),
        );
      } else {
        throw "Server failed to record the booking.";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final startTime = widget.bookingData['booking_time']?.toString();
    final endTime   = widget.bookingData['service_time']?.toString();
    final timeRange = "${_formatTime(startTime)} – ${_formatEndTime(endTime)}";

    return Scaffold(
      backgroundColor: _kBg,
      bottomNavigationBar: _buildStickyConfirmButton(),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroSummaryCard(timeRange),
                        const SizedBox(height: 28),
                        _buildSectionTitle("Payment Method"),
                        const SizedBox(height: 14),
                        _buildMethodGrid(),
                        if (_selectedMethod == 2) ...[
                          const SizedBox(height: 12),
                          _buildCashNote(),
                        ],
                        if (_selectedMethod == 1) ...[
                          const SizedBox(height: 16),
                          _buildCreditCardForm(),
                        ],
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 20, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: _kInk),
          ),
          const Expanded(
            child: Text(
              "Checkout",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _kInk),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF4A56B0).withOpacity(0.28)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_outline_rounded, size: 13, color: _kBluePill),
                SizedBox(width: 5),
                Text("Secure checkout",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _kBluePill)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero summary card ─────────────────────────────────────────────────────

  Widget _buildHeroSummaryCard(String timeRange) {
    final providerName  = _resolveProviderName();
    final serviceType   = widget.bookingData['service_type'] ?? 'Service';
    final date          = widget.bookingData['date'] ?? "N/A";
    final bookingId     = widget.bookingData['booking_id']?.toString() ?? '';
    final status        = widget.bookingData['status'] ?? 'Pending';
    final totalAmount   = widget.bookingData['payment_total']?.toString() ?? '0';
    final avatarLetter  = providerName.isNotEmpty ? providerName[0].toUpperCase() : 'P';
    final providerPhoto = widget.bookingData['provider_photo']?.toString() ?? '';

    // Pick an icon that matches the service type — mirrors services_screen.dart
    final IconData serviceIcon = _iconForService(serviceType);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF6470D2).withOpacity(0.14)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 30, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar — falls back to service icon if no photo
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                          colors: [_kNavy, _kNavy2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [BoxShadow(color: _kNavy.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 6))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: providerPhoto.isNotEmpty
                            ? Image.network(
                                providerPhoto,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(avatarLetter,
                                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                                ),
                              )
                            : Center(
                                child: Text(avatarLetter,
                                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(providerName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _kInk)),
                          const SizedBox(height: 6),
                          // Service type pill — icon + label, matches _ServiceCard badge style
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _kBluePillBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: const Color(0xFF6470D2).withOpacity(0.22)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(serviceIcon, size: 12, color: _kBluePill),
                                const SizedBox(width: 5),
                                Text(serviceType,
                                    style: const TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w900, color: _kBluePill)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 2×2 meta grid
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildMetaCell("Booking ID", bookingId.isNotEmpty ? "#$bookingId" : "Pending",
                            icon: Icons.tag_rounded)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildMetaCell("Date", date,
                            icon: Icons.calendar_today_rounded)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildMetaCell("Time", timeRange,
                            icon: Icons.schedule_rounded)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildMetaCell("Status", status,
                            icon: Icons.info_outline_rounded)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Total amount band
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
              gradient: const LinearGradient(
                colors: [_kCardDark, _kCardMid, Color(0xFF5B58EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("TOTAL AMOUNT",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                            color: Colors.white.withOpacity(0.7), letterSpacing: 0.7)),
                    const SizedBox(height: 6),
                    Text("$totalAmount EGP",
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900,
                            color: Colors.white, letterSpacing: -0.5)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("SELECTED SERVICE",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                            color: Colors.white.withOpacity(0.7), letterSpacing: 0.7)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(serviceIcon, size: 14, color: Colors.white.withOpacity(0.85)),
                        const SizedBox(width: 5),
                        Text(serviceType,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Returns the same icon used for each service in ServicesScreen.
  IconData _iconForService(String serviceType) {
    final s = serviceType.toLowerCase();
    if (s.contains('doctor') || s.contains('medical') || s.contains('physio')) {
      return Icons.medical_services_outlined;
    }
    if (s.contains('caregiver') || s.contains('care') || s.contains('nurse')) {
      return Icons.favorite_border_rounded;
    }
    if (s.contains('driver') || s.contains('transport') || s.contains('car')) {
      return Icons.directions_car_outlined;
    }
    if (s.contains('interpreter') || s.contains('sign') || s.contains('language')) {
      return Icons.record_voice_over_outlined;
    }
    return Icons.medical_services_outlined;
  }

  // Meta info cell — now with a small leading icon
  Widget _buildMetaCell(String label, String value, {required IconData icon}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6470D2).withOpacity(0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 13, color: _kBluePill.withOpacity(0.7)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label.toUpperCase(),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                        color: _kMuted, letterSpacing: 0.7)),
                const SizedBox(height: 3),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _kInk)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Payment method grid ────────────────────────────────────────────────────

  Widget _buildMethodGrid() {
    return Row(
      children: [
        Expanded(child: _buildMethodTile(2, "Cash", "Pay when the service starts.",
            Icons.payments_rounded, chipLabel: "Pay later", isGreen: true)),
        const SizedBox(width: 12),
        Expanded(child: _buildMethodTile(1, "Card", "Pay now using your card details.",
            Icons.credit_card_rounded, chipLabel: "Secure checkout", isGreen: false)),
      ],
    );
  }

  Widget _buildMethodTile(int index, String title, String sub, IconData icon,
      {required String chipLabel, required bool isGreen}) {
    final active = _selectedMethod == index;
    final Color iconColor = isGreen ? _kGreen   : _kBluePill;
    final Color iconBg    = isGreen ? _kGreenBg : _kBluePillBg;

    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6470D2).withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active
                ? const Color(0xFF6470D2).withOpacity(0.5)
                : const Color(0xFF6470D2).withOpacity(0.14),
            width: active ? 1.5 : 1,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _kInk)),
            const SizedBox(height: 3),
            Text(sub,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                    color: _kMuted, height: 1.4)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kBluePillBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF6470D2).withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isGreen ? Icons.access_time_rounded : Icons.lock_outline_rounded,
                    size: 10,
                    color: _kBluePill,
                  ),
                  const SizedBox(width: 4),
                  Text(chipLabel,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w900, color: _kBluePill)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Cash note ─────────────────────────────────────────────────────────────

  Widget _buildCashNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kGreenBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kGreen.withOpacity(0.16)),
      ),
      child: Row(
        children: const [
          Icon(Icons.info_outline_rounded, color: _kGreen, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "You'll pay your provider directly when the service begins.",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _kGreen, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  // ── Credit card form ──────────────────────────────────────────────────────

  Widget _buildCreditCardForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF6470D2).withOpacity(0.14)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardPreview(),
          const SizedBox(height: 20),

          // Card Holder
          _fieldLabel("Card Holder Name", Icons.person_outline_rounded),
          _buildInput(
            controller: _cardHolderCtrl,
            hint: "Enter card holder name",
            error: _holderError,
            onChanged: (v) => setState(() {
              _liveHolder  = v.trim().isEmpty ? 'YOUR NAME' : v.trim().toUpperCase();
              _holderError = null;
            }),
          ),
          if (_holderError != null) _buildErrorText(_holderError!),
          const SizedBox(height: 14),

          // Card Number
          _fieldLabel("Card Number", Icons.credit_card_rounded),
          _buildInput(
            controller: _cardNumberCtrl,
            hint: "1234 5678 9012 3456",
            error: _numberError,
            keyboardType: TextInputType.number,
            formatters: [_CardNumberFormatter()],
            onChanged: (v) => setState(() {
              _liveNumber  = v.isEmpty ? '•••• •••• •••• ••••' : v;
              _liveBrand   = _detectBrand(v);
              _numberError = null;
            }),
          ),
          if (_numberError != null) _buildErrorText(_numberError!),
          const SizedBox(height: 14),

          // Expiry + CVV row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel("Expiry", Icons.date_range_rounded),
                    _buildInput(
                      controller: _expiryCtrl,
                      hint: "MM/YY",
                      error: _expiryError,
                      keyboardType: TextInputType.number,
                      formatters: [_ExpiryFormatter()],
                      onChanged: (v) => setState(() {
                        _liveExpiry  = v.isEmpty ? 'MM/YY' : v;
                        _expiryError = null;
                      }),
                    ),
                    if (_expiryError != null) _buildErrorText(_expiryError!),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel("CVV", Icons.lock_outline_rounded),
                    _buildInput(
                      controller: _cvvCtrl,
                      hint: "•••",
                      error: _cvvError,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      formatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) => setState(() => _cvvError = null),
                    ),
                    if (_cvvError != null) _buildErrorText(_cvvError!),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Card preview
  Widget _buildCardPreview() {
    return Container(
      height: 210,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kCardDark, _kCardMid, _kCardLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: _kNavy.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 52,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4C8FF), Colors.white, Color(0xFF9A8FD4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Text(_liveBrand,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                      color: _kAccent, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _liveNumber.isEmpty ? '•••• •••• •••• ••••' : _liveNumber,
            style: const TextStyle(color: Colors.white, fontSize: 22,
                letterSpacing: 2.5, fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("CARD HOLDER",
                      style: TextStyle(color: Colors.white.withOpacity(0.55),
                          fontSize: 9, letterSpacing: 0.9, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(_liveHolder,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("EXPIRY",
                      style: TextStyle(color: Colors.white.withOpacity(0.55),
                          fontSize: 9, letterSpacing: 0.9, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(_liveExpiry,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Field helpers ──────────────────────────────────────────────────────────

  Widget _fieldLabel(String label, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            Icon(icon, size: 13, color: _kSoft),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _kSoft)),
          ],
        ),
      );

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required String? error,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? formatters,
    bool obscureText = false,
    int? maxLength,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      obscureText: obscureText,
      maxLength: maxLength,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _kInk),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: _kMuted, fontWeight: FontWeight.w800),
        counterText: '',
        filled: true,
        fillColor: _kBg,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: error != null
                ? Colors.red.shade300
                : const Color(0xFF6470D2).withOpacity(0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: error != null ? Colors.red : const Color(0xFF6470D2).withOpacity(0.56),
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildErrorText(String msg) => Padding(
        padding: const EdgeInsets.only(top: 5, left: 4),
        child: Text(msg,
            style: TextStyle(color: Colors.red.shade600, fontSize: 11, fontWeight: FontWeight.w800)),
      );

  // ── Sticky confirm button ─────────────────────────────────────────────────

  Widget _buildStickyConfirmButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kLine, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 10,
            child: GestureDetector(
              onTap: _isProcessing ? null : _confirmBooking,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [_kCardDark, _kNavy2, _kNavy3],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(color: _kNavy.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Center(
                  child: _isProcessing
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text("Confirm Payment",
                                style: TextStyle(color: Colors.white, fontSize: 15,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEBE7DC), width: 1),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: _kNavy2),
                    SizedBox(width: 5),
                    Text("Back",
                        style: TextStyle(color: _kNavy2, fontSize: 15, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
            color: _kInk, letterSpacing: -0.2),
      );
}