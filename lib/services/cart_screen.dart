import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rafiq/services/success.dart';
import 'package:rafiq/auth/api_service.dart';
import 'package:rafiq/auth/session_manager.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens — unified with PaymentScreen
// ─────────────────────────────────────────────────────────────────────────────
const _kBg        = Color(0xFFF8F8FF);
const _kInk       = Color(0xFF23243A);
const _kNavy      = Color(0xFF2D2D5A);
const _kNavy2     = Color(0xFF30335F);
const _kNavy3     = Color(0xFF555991);
const _kCardDark  = Color(0xFF17182D);
const _kCardMid   = Color(0xFF2C315F);
const _kCardLight = Color(0xFF3F426F);
const _kAccent    = Color(0xFFEDCC6F);   // gold — card brand label
const _kPurple    = Color(0xFF353B69);
const _kBlue      = Color(0xFF4A56B0);
const _kBlueBg    = Color(0xFFEEF0FF);
const _kMuted     = Color(0xFF8B91A6);
const _kSoft      = Color(0xFF6F748B);
const _kLine      = Color(0xFFE4E6F5);
const _kSoftBg    = Color(0xFFF8F8FF);
const _kGreen     = Color(0xFF168653);
const _kGreenBg   = Color(0xFFEEFBF4);

// ─────────────────────────────────────────────────────────────────────────────
// Input formatters
// ─────────────────────────────────────────────────────────────────────────────
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue nv) {
    final digits = nv.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 19 ? digits.substring(0, 19) : digits;
    final buf = StringBuffer();
    for (int i = 0; i < capped.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(capped[i]);
    }
    final s = buf.toString();
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue nv) {
    final digits = nv.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 4 ? digits.substring(0, 4) : digits;
    final s = capped.length > 2
        ? '${capped.substring(0, 2)}/${capped.substring(2)}'
        : capped;
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CartScreen
// ─────────────────────────────────────────────────────────────────────────────
class CartScreen extends StatefulWidget {
  final Map<String, int> cart;
  final List<Map<String, dynamic>> products;
  final void Function(Map<String, int> updatedCart) onCartUpdated;

  const CartScreen({
    super.key,
    required this.cart,
    required this.products,
    required this.onCartUpdated,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Map<String, int> _cart;
  bool _isProcessing = false;

  // Payment method: 'cash' | 'visa'
  String _payMethod = 'cash';

  // Delivery fields
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();

  // Card fields
  final _holderCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl    = TextEditingController();

  // Live card preview state
  String _liveHolder = 'YOUR NAME';
  String _liveNumber = '•••• •••• •••• ••••';
  String _liveExpiry = 'MM/YY';
  String _liveBrand  = 'CARD';

  // Validation errors
  String? _nameErr;
  String? _phoneErr;
  String? _addressErr;
  String? _holderErr;
  String? _numberErr;
  String? _expiryErr;
  String? _cvvErr;

  @override
  void initState() {
    super.initState();
    _cart = Map<String, int>.from(widget.cart);
    _prefillUser();
  }

  // ── Name prefill — session cache first, then live profile fetch as fallback ──
  Future<void> _prefillUser() async {
    final user = await SessionManager.getUser();
    if (user == null) return;

    // Try to build name from session cache first
    String name  = _buildName(user);
    String phone = user['phone']?.toString() ?? '';
    String addr  = user['address']?.toString() ?? '';

    // If name is still missing, do a fresh profile fetch
    if (name.isEmpty) {
      final userId = int.tryParse(user['user_id']?.toString() ?? '');
      if (userId != null) {
        final profile = await ApiService.getPatientProfile(userId);
        if (profile != null) {
          name  = _buildName(profile);
          phone = profile['phone']?.toString() ?? phone;
          addr  = profile['address']?.toString() ?? addr;
        }
      }
    }

    if (mounted) {
      setState(() {
        if (name.isNotEmpty)  _nameCtrl.text    = name;
        if (phone.isNotEmpty) _phoneCtrl.text   = phone;
        if (addr.isNotEmpty)  _addressCtrl.text = addr;
      });
    }
  }

  /// Resolves a display name from any user/profile map.
  /// Tries: full_name → name → first_name + last_name → first_name alone.
  String _buildName(Map<String, dynamic> data) {
    // 1. explicit full-name field
    for (final key in ['full_name', 'name', 'doctor_name', 'provider_name']) {
      final v = data[key]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    // 2. first + last
    final first = data['first_name']?.toString().trim() ?? '';
    final last  = data['last_name']?.toString().trim()  ?? '';
    return '$first $last'.trim();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _addressCtrl.dispose();
    _holderCtrl.dispose(); _numberCtrl.dispose(); _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Map<String, dynamic>? _productByTitle(String t) {
    try { return widget.products.firstWhere((p) => p['title'] == t); }
    catch (_) { return null; }
  }

  List<MapEntry<String, int>> get _cartItems =>
      _cart.entries.where((e) => e.value > 0).toList();

  int get _total => _cartItems.fold(0, (sum, e) {
    final p = _productByTitle(e.key);
    return sum + ((p?['priceValue'] as num?)?.toInt() ?? 0) * e.value;
  });

  bool get _isEmpty => _cartItems.isEmpty;

  void _setQty(String title, int qty) {
    setState(() { qty <= 0 ? _cart.remove(title) : _cart[title] = qty; });
    widget.onCartUpdated(Map<String, int>.from(_cart));
  }

  String _detectBrand(String raw) {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (RegExp(r'^4').hasMatch(d))                return 'VISA';
    if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(d)) return 'MASTERCARD';
    if (RegExp(r'^3[47]').hasMatch(d))            return 'AMEX';
    return 'CARD';
  }

  String _last4(String raw) {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    return d.length >= 4 ? d.substring(d.length - 4) : d;
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  // ── Validation ────────────────────────────────────────────────────────────

  bool _validate() {
    String? nameE, phoneE, addrE, holderE, numberE, expiryE, cvvE;

    if (_nameCtrl.text.trim().isEmpty)    nameE  = 'Please enter your full name.';
    if (_phoneCtrl.text.trim().isEmpty)   phoneE = 'Please enter your phone number.';
    if (_addressCtrl.text.trim().isEmpty) addrE  = 'Please enter your delivery address.';

    if (_payMethod == 'visa') {
      final digits = _numberCtrl.text.replaceAll(RegExp(r'\D'), '');
      if (_holderCtrl.text.trim().isEmpty)
        holderE = 'Please enter the card holder name.';
      if (digits.length < 12)
        numberE = 'Please enter a valid card number.';
      if (!RegExp(r'^(0[1-9]|1[0-2])\/[0-9]{2}$').hasMatch(_expiryCtrl.text.trim()))
        expiryE = 'Enter a valid expiry (MM/YY).';
      if (!RegExp(r'^[0-9]{3,4}$').hasMatch(_cvvCtrl.text.trim()))
        cvvE    = 'Enter a valid CVV.';
    }

    setState(() {
      _nameErr = nameE; _phoneErr = phoneE; _addressErr = addrE;
      _holderErr = holderE; _numberErr = numberE; _expiryErr = expiryE; _cvvErr = cvvE;
    });

    return nameE == null && phoneE == null && addrE == null &&
        holderE == null && numberE == null && expiryE == null && cvvE == null;
  }

  // ── Checkout ──────────────────────────────────────────────────────────────

  Future<void> _checkout() async {
    if (_isEmpty || !_validate()) return;
    setState(() => _isProcessing = true);

    try {
      final user = await SessionManager.getUser();
      final bookingData = <String, dynamic>{
        'service_type':   'Product Order',
        'payment_total':  _total.toString(),
        'payment_method': _payMethod,
        'status':         'Pending',
        'first_name':     'Rafiq',
        'last_name':      'Store',
        'date':           _today(),
        'booking_time':   '00:00:00',
        'service_time':   '00:00:00',
        'full_name':      _nameCtrl.text.trim(),
        'phone':          _phoneCtrl.text.trim(),
        'address':        _addressCtrl.text.trim(),
        'items':          _cartItems.map((e) => {'title': e.key, 'qty': e.value}).toList(),
        if (user != null) 'patient_id': user['user_id'],
        if (_payMethod == 'visa') ...{
          'card_holder': _holderCtrl.text.trim(),
          'card_last4':  _last4(_numberCtrl.text),
          'card_brand':  _detectBrand(_numberCtrl.text),
        },
      };

      if (mounted) {
        widget.onCartUpdated({});
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SuccessScreen(bookingData: bookingData)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Checkout failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: _isEmpty ? _buildEmpty() : _buildContent(),
                ),
              ],
            ),
          ),
          if (!_isEmpty)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _buildStickyBar(),
            ),
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 20, 10),
        color: _kBg,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: _kInk),
              onPressed: () => Navigator.pop(context),
            ),
            const Expanded(
              child: Text('Your Cart',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _kInk)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _kBlue.withOpacity(0.28)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12)],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 13, color: _kBlue),
                  SizedBox(width: 5),
                  Text('Secure checkout',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _kBlue)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _kLine),
            ),
            child: const Icon(Icons.shopping_cart_outlined, size: 38, color: _kMuted),
          ),
          const SizedBox(height: 16),
          const Text('Your cart is empty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _kInk)),
          const SizedBox(height: 6),
          const Text('Add products from the homepage to get started.',
              style: TextStyle(fontSize: 13, color: _kMuted)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kCardDark, _kNavy2, _kNavy3]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('Browse Products',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Main content ──────────────────────────────────────────────────────────

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // Product heroes
          ..._cartItems.map((e) => _buildProductHero(e.key, e.value)),

          const SizedBox(height: 20),

          // Order summary
          _buildPanel(
            icon: Icons.receipt_long_rounded,
            title: 'Order Summary',
            child: Column(
              children: [
                ..._cartItems.map((e) {
                  final p     = _productByTitle(e.key);
                  final price = (p?['priceValue'] as num?)?.toInt() ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('${e.key} × ${e.value}',
                              style: const TextStyle(
                                  fontSize: 13, color: _kMuted, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text('${price * e.value} EGP',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800, color: _kInk)),
                      ],
                    ),
                  );
                }),
                const Divider(color: _kLine, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _kInk)),
                    Text('$_total EGP',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900, color: _kNavy2)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Delivery info
          _buildPanel(
            icon: Icons.local_shipping_outlined,
            title: 'Delivery Information',
            child: Column(
              children: [
                _buildField(
                  label: 'Full Name',
                  ctrl: _nameCtrl,
                  hint: 'Your full name',
                  error: _nameErr,
                  icon: Icons.person_outline_rounded,
                  onChanged: (_) => setState(() => _nameErr = null),
                ),
                _buildField(
                  label: 'Phone Number',
                  ctrl: _phoneCtrl,
                  hint: '01XXXXXXXXX',
                  error: _phoneErr,
                  icon: Icons.phone_outlined,
                  keyboard: TextInputType.phone,
                  onChanged: (_) => setState(() => _phoneErr = null),
                ),
                _buildField(
                  label: 'Delivery Address',
                  ctrl: _addressCtrl,
                  hint: 'Your full delivery address',
                  error: _addressErr,
                  icon: Icons.location_on_outlined,
                  onChanged: (_) => setState(() => _addressErr = null),
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Payment method
          _buildPanel(
            icon: Icons.credit_card_rounded,
            title: 'Payment Method',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildMethodTile(
                      value: 'cash',
                      icon: Icons.payments_rounded,
                      title: 'Cash',
                      subtitle: 'Pay when order arrives.',
                      chipLabel: 'Pay later',
                      isGreen: true,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMethodTile(
                      value: 'visa',
                      icon: Icons.credit_card_rounded,
                      title: 'Card',
                      subtitle: 'Pay now with your card.',
                      chipLabel: 'Secure checkout',
                      isGreen: false,
                    )),
                  ],
                ),

                // Cash note
                if (_payMethod == 'cash') ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kGreenBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kGreen.withOpacity(0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: _kGreen, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "You'll pay when your order is delivered.",
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: _kGreen, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Card form
                if (_payMethod == 'visa') ...[
                  const SizedBox(height: 20),
                  _buildCardPreview(),
                  const SizedBox(height: 18),

                  _buildField(
                    label: 'Card Holder Name',
                    ctrl: _holderCtrl,
                    hint: 'Name on card',
                    error: _holderErr,
                    icon: Icons.person_outline_rounded,
                    onChanged: (v) => setState(() {
                      _holderErr  = null;
                      _liveHolder = v.trim().isEmpty ? 'YOUR NAME' : v.trim().toUpperCase();
                    }),
                  ),
                  _buildField(
                    label: 'Card Number',
                    ctrl: _numberCtrl,
                    hint: '1234 5678 9012 3456',
                    error: _numberErr,
                    icon: Icons.credit_card_rounded,
                    keyboard: TextInputType.number,
                    formatters: [_CardNumberFormatter()],
                    onChanged: (v) => setState(() {
                      _numberErr  = null;
                      _liveNumber = v.isEmpty ? '•••• •••• •••• ••••' : v;
                      _liveBrand  = _detectBrand(v);
                    }),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          label: 'Expiry',
                          ctrl: _expiryCtrl,
                          hint: 'MM/YY',
                          error: _expiryErr,
                          icon: Icons.date_range_rounded,
                          keyboard: TextInputType.number,
                          formatters: [_ExpiryFormatter()],
                          onChanged: (v) => setState(() {
                            _expiryErr  = null;
                            _liveExpiry = v.isEmpty ? 'MM/YY' : v;
                          }),
                          isLast: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildField(
                          label: 'CVV',
                          ctrl: _cvvCtrl,
                          hint: '•••',
                          error: _cvvErr,
                          icon: Icons.lock_outline_rounded,
                          keyboard: TextInputType.number,
                          obscure: true,
                          maxLength: 4,
                          formatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (_) => setState(() => _cvvErr = null),
                          isLast: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Product hero ──────────────────────────────────────────────────────────

  Widget _buildProductHero(String title, int qty) {
    final p     = _productByTitle(title);
    final img   = p?['img']         as String? ?? '';
    final desc  = p?['desc']        as String? ?? '';
    final price = (p?['priceValue'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kCardDark, _kCardMid, Color(0xFF5B58EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: _kNavy.withOpacity(0.22), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(img, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image_outlined, color: Colors.white54, size: 32)),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: -.3)),
                  const SizedBox(height: 5),
                  Text(desc,
                      style: TextStyle(
                          fontSize: 12, color: Colors.white.withOpacity(0.82), height: 1.5),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            border: Border.all(color: Colors.white.withOpacity(0.24)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${price * qty} EGP',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _heroQtyStepper(title, qty),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroQtyStepper(String title, int qty) => Row(
        children: [
          _stepBtn(Icons.remove, () => _setQty(title, qty - 1)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$qty',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          _stepBtn(Icons.add, () => _setQty(title, qty + 1)),
        ],
      );

  Widget _stepBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Icon(icon, size: 15, color: Colors.white),
        ),
      );

  // ── Live card preview — matches PaymentScreen ─────────────────────────────

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
        boxShadow: [
          BoxShadow(color: _kNavy.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 52, height: 38,
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
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w900,
                      color: _kAccent, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _liveNumber.isEmpty ? '•••• •••• •••• ••••' : _liveNumber,
            style: const TextStyle(
                color: Colors.white, fontSize: 22,
                letterSpacing: 2.5, fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('CARD HOLDER',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 9, letterSpacing: 0.9, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(_liveHolder,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('EXPIRY',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 9, letterSpacing: 0.9, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(_liveExpiry,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  // ── Panel wrapper — matches PaymentScreen's card style ────────────────────

  Widget _buildPanel({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF6470D2).withOpacity(0.14)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _kBlueBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 18, color: _kBlue),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900, color: _kInk)),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  // ── Payment method tile — matches PaymentScreen._buildMethodTile ──────────

  Widget _buildMethodTile({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    required String chipLabel,
    required bool isGreen,
  }) {
    final active     = _payMethod == value;
    final iconColor  = isGreen ? _kGreen  : _kBlue;
    final iconBg     = isGreen ? _kGreenBg : _kBlueBg;

    return GestureDetector(
      onTap: () => setState(() => _payMethod = value),
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
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900, color: _kInk)),
            const SizedBox(height: 3),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: _kMuted, height: 1.4)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kBlueBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF6470D2).withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isGreen
                        ? Icons.access_time_rounded
                        : Icons.lock_outline_rounded,
                    size: 10,
                    color: _kBlue,
                  ),
                  const SizedBox(width: 4),
                  Text(chipLabel,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w900, color: _kBlue)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Field — with leading icon label matching PaymentScreen ────────────────

  Widget _buildField({
    required String label,
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    String? error,
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? formatters,
    bool obscure = false,
    int? maxLength,
    required ValueChanged<String> onChanged,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row with icon — mirrors PaymentScreen._fieldLabel
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                Icon(icon, size: 13, color: _kSoft),
                const SizedBox(width: 5),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w900, color: _kSoft)),
              ],
            ),
          ),
          TextField(
            controller: ctrl,
            keyboardType: keyboard,
            inputFormatters: formatters,
            obscureText: obscure,
            maxLength: maxLength,
            onChanged: onChanged,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w900, color: _kInk),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                  fontSize: 13, color: _kMuted, fontWeight: FontWeight.w800),
              counterText: '',
              filled: true,
              fillColor: _kSoftBg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
                  color: error != null
                      ? Colors.red
                      : const Color(0xFF6470D2).withOpacity(0.56),
                  width: 1.5,
                ),
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 5, left: 4),
              child: Text(error,
                  style: TextStyle(
                      color: Colors.red.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  // ── Sticky confirm bar ────────────────────────────────────────────────────

  Widget _buildStickyBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 34),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kLine, width: 0.5)),
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TOTAL',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w900,
                      color: _kMuted, letterSpacing: 0.8)),
              const SizedBox(height: 2),
              Text('$_total EGP',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900, color: _kInk)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: _isProcessing ? null : _checkout,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kCardDark, _kNavy2, _kNavy3],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: _kNavy.withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: Center(
                  child: _isProcessing
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text('Confirm Order — $_total EGP',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}