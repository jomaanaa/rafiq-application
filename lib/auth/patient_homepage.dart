import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'notifications.dart';
import 'api_service.dart';
import 'session_manager.dart';
import 'package:rafiq/services/caregiver_selection.dart';
import 'package:rafiq/services/doctor_selection.dart';
import 'package:rafiq/services/interpreter_selection.dart';
import 'package:rafiq/features/ocr_reader.dart';
import 'package:rafiq/services/cart_screen.dart';
import 'package:rafiq/driver/request_driver_screen.dart';
import 'package:rafiq/driver/driver_api.dart';
import 'package:rafiq/driver/booking_status_screen.dart';
import 'package:rafiq/features/chatbot_screen.dart'; 


// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const _bg      = Color(0xFFF6F8FD);
const _dark    = Color(0xFF242742);
const _primary = Color(0xFF4B4F83);
const _accent  = Color(0xFF6470D2);
const _muted   = Color(0xFF6B7188);
const _line    = Color(0xFFE8EBF5);
const _soft    = Color(0xFFF1F4FB);
const _iconBg  = Color(0xFFEEEDFE);

// ─────────────────────────────────────────────────────────────────────────────
// DATA
// ─────────────────────────────────────────────────────────────────────────────
const _services = [
  {
    "title": "Caregiver",
    "badge": "Daily Support",
    "icon": Icons.favorite_border_rounded,
    "desc": "Personal daily support at home.",
    "btn": "Book Now",
  },
  {
    "title": "Driver",
    "badge": "Accessible Ride",
    "icon": Icons.directions_car_outlined,
    "desc": "Accessible rides for easier movement.",
    "btn": "Request Ride",
  },
  {
    "title": "Doctor",
    "badge": "Medical Help",
    "icon": Icons.medical_services_outlined,
    "desc": "Book trusted doctors by specialty.",
    "btn": "Find Doctor",
  },
  {
    "title": "Interpreter",
    "badge": "Communication",
    "icon": Icons.record_voice_over_outlined,
    "desc": "Language support when you need it.",
    "btn": "Book Now",
  },
];

const _features = [
  {
    "title": "OCR Reader",
    "icon": Icons.document_scanner_outlined,
    "sub": "Scan & read text",
    "key": "ocr",
  },
];

const _products = [
  {
    "title": "Smart Beeping Glasses",
    "img": "assets/images/glasses.jpeg",
    "desc": "Detect nearby obstacles with gentle sound alerts.",
    "price": "1,499 EGP",
    "priceValue": 1499,
  },
  {
    "title": "Emergency Alert Bracelet",
    "img": "assets/images/watch.jpeg",
    "desc": "Send emergency alerts quickly when needed.",
    "price": "2,999 EGP",
    "priceValue": 2999,
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class PatientHomepage extends StatefulWidget {
  final String firstName;
  const PatientHomepage({super.key, required this.firstName});

  @override
  State<PatientHomepage> createState() => _PatientHomepageState();
}

class _PatientHomepageState extends State<PatientHomepage> {
  int    _notifCount    = 0;
  String _locationLabel = 'Detecting your location…';
  bool   _placesExpanded = false;

  List<Map<String, dynamic>> _places = [];
  bool _placesLoading = true;

  final Map<String, int> _cart = {};
  int get _cartItemCount => _cart.values.fold(0, (sum, qty) => sum + qty);

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _detectLocation();
    _loadPlaces();
  }

  Future<void> _loadNotifications() async {
    final id = await SessionManager.getUserId();
    if (id == null) return;
    final data = await ApiService.getPatientNotifications(id);
    final seen = await SessionManager.getSeenNotifications();
    if (mounted) setState(() => _notifCount = (data.length - seen).clamp(0, 999));
  }

  void _openNotifications() async {
    final id = await SessionManager.getUserId();
    if (id == null) return;
    final data = await ApiService.getPatientNotifications(id);
    await SessionManager.saveSeenNotifications(data.length);
    if (mounted) setState(() => _notifCount = 0);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()))
        .then((_) => _loadNotifications());
  }

  Future<void> _detectLocation() async {
    try {
      bool on = await Geolocator.isLocationServiceEnabled();
      if (!on) { _setLoc('Location unavailable'); return; }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _setLoc('Location access blocked'); return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _setLoc('Getting your area…');
      final res = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse'
          '?format=jsonv2'
          '&lat=${pos.latitude}'
          '&lon=${pos.longitude}'
          '&accept-language=en'
          '&zoom=16',
        ),
        headers: {'User-Agent': 'RafiqApp/1.0'},
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final a    = (body['address'] as Map<String, dynamic>?) ?? {};
        final place = a['quarter']       ??
                      a['suburb']        ??
                      a['neighbourhood'] ??
                      a['village']       ??
                      a['town']          ??
                      a['city_district'] ??
                      a['county']        ??
                      a['city']          ??
                      a['state']         ??
                      'Your location';
        _setLoc(place as String);
      }
    } catch (_) { _setLoc('Your current location'); }
  }

  void _setLoc(String v) { if (mounted) setState(() => _locationLabel = v); }

  Future<void> _loadPlaces() async {
    try {
      List<Map<String, dynamic>> list;
      Position? pos;
      try {
        final perm = await Geolocator.checkPermission();
        if (perm != LocationPermission.denied &&
            perm != LocationPermission.deniedForever) {
          pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
          ).timeout(const Duration(seconds: 6));
        }
      } catch (_) {}

      if (pos != null) {
        list = await ApiService.getPlacesNearby(
          lat: pos.latitude,
          lng: pos.longitude,
          radiusKm: 5,
        );
      } else {
        list = await ApiService.getAllPlaces();
      }

      if (mounted) setState(() { _places = list; _placesLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _placesLoading = false);
    }
  }

Future<void> _navigate(String key) async {
    Widget screen;
    switch (key) {
      case 'Caregiver':   screen = CaregiverSelectionScreen();      break;
      case 'Driver':
        final patientId = await SessionManager.getUserId();
        if (patientId == null) return;

        // Show loading so the user knows something is happening
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );
        }

        final active = await DriverApi.getActiveBooking(patientId);
        if (!context.mounted) return;
        Navigator.pop(context); // dismiss loading

        if (active != null) {
          screen = BookingStatusScreen(
            bookingId: active['booking_id'] as int,
            patientId: patientId,
          );
        } else {
          screen = RequestDriverScreen(patientId: patientId);
        }
  break;
      case 'Doctor':      screen = DoctorSelectionScreen();         break;
      case 'Interpreter': screen = InterpreterSelectionScreen();    break;
      case 'ocr':         screen = const SmartOcrReader();          break;
      default: return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _addToCart(Map<String, dynamic> product) {
    setState(() {
      final key = product['title'] as String;
      _cart[key] = (_cart[key] ?? 0) + 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product['title']} added to cart'),
        duration: const Duration(seconds: 1),
        backgroundColor: _primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartScreen(
          cart: Map<String, int>.from(_cart),
          products: _products.map((p) => Map<String, dynamic>.from(p)).toList(),
          onCartUpdated: (updated) {
            if (mounted) setState(() { _cart.clear(); _cart.addAll(updated); });
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // The key fix: everything uses a LayoutBuilder so all cards share the
  // exact same computed width, derived from the real available width minus
  // the horizontal padding. No GridView internal padding surprises.
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    const double hPad    = 18;
    const double gutter  = 12;

// AFTER
          return Scaffold(
            backgroundColor: const Color(0xFFF6F8FD),
            body: Stack(
              children: [
                SafeArea(
                  child: LayoutBuilder(
          builder: (context, constraints) {
            // The one source of truth for all card/section widths
            final double fullW  = constraints.maxWidth - (hPad * 2);
            final double halfW  = (fullW - gutter) / 2;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(hPad, 16, hPad, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 10),
                  _buildLocationRow(fullW),
                  const SizedBox(height: 20),
                  _buildHero(fullW),
                  const SizedBox(height: 24),
                  _buildSectionHead('Our Services'),
                  const SizedBox(height: 12),
                  _buildServiceGrid(halfW, gutter),
                  const SizedBox(height: 24),
                  _buildSectionHead('Accessibility Features'),
                  const SizedBox(height: 12),
                  _buildFeaturesRow(fullW),
                  const SizedBox(height: 24),
                  _buildSectionHead(
                    'Accessible Places Nearby',
                    trailing: _placesExpanded ? 'Show Less' : 'View All',
                    onTrailing: () => setState(() => _placesExpanded = !_placesExpanded),
                  ),
                  const SizedBox(height: 12),
                  _buildPlaces(halfW, gutter),
                  const SizedBox(height: 24),
                  _buildSectionHead('Our Products'),
                  const SizedBox(height: 12),
                  _buildProducts(halfW, gutter),
                ],
              ),
            );
          },
        ),
      ),
      const _FloatingChatbot(),   // ← add this line
      ],                            // ← closes Stack's children
    ),                              // ← closes Stack
  );
    }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, ${widget.firstName}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Find accessible places and services.',
                style: TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        _HeaderIconButton(
          icon: Icons.notifications_none_rounded,
          badge: _notifCount > 0 ? _notifCount.toString() : null,
          badgeColor: Colors.red,
          onTap: _openNotifications,
        ),
        const SizedBox(width: 6),
        _HeaderIconButton(
          icon: Icons.shopping_bag_outlined,
          badge: _cartItemCount > 0 ? _cartItemCount.toString() : null,
          badgeColor: _accent,
          onTap: _openCart,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOCATION ROW
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLocationRow(double width) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 16, color: _accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _locationLabel,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _primary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () { _setLoc('Detecting…'); _detectLocation(); },
              child: const Icon(Icons.refresh_rounded, size: 18, color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HERO  — explicit width so it always matches the grid below
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHero(double width) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF20233C), Color(0xFF353B69), Color(0xFF6470D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'RAFIQ SERVICES',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Everything you need,\norganized in one place.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1.3,
                letterSpacing: -.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a service or explore our accessibility tools.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 12,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SERVICE GRID  — manual 2-col layout using Row + fixed halfW
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildServiceGrid(double halfW, double gutter) {
    final rows = <Widget>[];
    for (int i = 0; i < _services.length; i += 2) {
      final left  = _services[i]     as Map<String, dynamic>;
      final right = (i + 1 < _services.length) ? _services[i + 1] as Map<String, dynamic> : null;
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ServiceCard(data: left,  width: halfW, onTap: () async { await _navigate(left['title'] as String); }),
            SizedBox(width: gutter),
            if (right != null)
              _ServiceCard(data: right, width: halfW, onTap: () async { await _navigate(right['title'] as String); })
            else
              SizedBox(width: halfW),
          ],
        ),
      );
      if (i + 2 < _services.length) rows.add(SizedBox(height: gutter));
    }
    return Column(children: rows);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACCESSIBILITY FEATURES
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFeaturesRow(double fullW) {
    return Column(
      children: _features.map((t) {
        final iconData = t['icon'] as IconData;
        return GestureDetector(
          onTap: () async { await _navigate(t['key'] as String); },
          child: Container(
            width: fullW,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: _iconBg, borderRadius: BorderRadius.circular(13)),
                  child: Icon(iconData, size: 20, color: _primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['title'] as String,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _dark)),
                      const SizedBox(height: 2),
                      Text(t['sub'] as String,
                          style: const TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _primary),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION HEAD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSectionHead(String title, {String? trailing, VoidCallback? onTrailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: _dark, letterSpacing: -.2)),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailing,
            child: Text(trailing,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _primary)),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PLACES  — same manual 2-col as service grid
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPlaces(double halfW, double gutter) {
    if (_placesLoading) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
      );
    }
    if (_places.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
        child: const Text('No accessible places found nearby.',
            style: TextStyle(color: _muted, fontWeight: FontWeight.w600)),
      );
    }
    final visible = _placesExpanded ? _places : _places.take(4).toList();
    final rows = <Widget>[];
    for (int i = 0; i < visible.length; i += 2) {
      final left  = visible[i];
      final right = (i + 1 < visible.length) ? visible[i + 1] : null;
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PlaceCard(place: left,  width: halfW),
            SizedBox(width: gutter),
            right != null ? _PlaceCard(place: right, width: halfW) : SizedBox(width: halfW),
          ],
        ),
      );
      if (i + 2 < visible.length) rows.add(SizedBox(height: gutter));
    }
    return Column(children: rows);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRODUCTS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildProducts(double halfW, double gutter) {
    final rows = <Widget>[];
    for (int i = 0; i < _products.length; i += 2) {
      final left  = _products[i]     as Map<String, dynamic>;
      final right = (i + 1 < _products.length) ? _products[i + 1] as Map<String, dynamic> : null;
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProductCard(product: left,  width: halfW, cartQty: _cart[left['title']] ?? 0,  onAddToCart: () => _addToCart(left)),
            SizedBox(width: gutter),
            right != null
                ? _ProductCard(product: right, width: halfW, cartQty: _cart[right['title']] ?? 0, onAddToCart: () => _addToCart(right))
                : SizedBox(width: halfW),
          ],
        ),
      );
      if (i + 2 < _products.length) rows.add(SizedBox(height: gutter));
    }
    return Column(children: rows);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER ICON BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String? badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.badgeColor,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line),
            ),
            child: Icon(icon, size: 20, color: _dark),
          ),
          if (badge != null)
            Positioned(
              right: 5, top: 5,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                child: Text(badge!,
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final double width;
  final Future<void> Function() onTap;

  const _ServiceCard({required this.data, required this.width, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final iconData = data['icon'] as IconData;
    return GestureDetector(
      onTap: () async => await onTap(),
      child: SizedBox(
        width: width,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _line),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: _iconBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(iconData, size: 20, color: _primary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(999)),
                child: Text(data['badge'] as String,
                    style: const TextStyle(color: _primary, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 6),
              Text(data['title'] as String,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _dark)),
              const SizedBox(height: 3),
              Text(data['desc'] as String,
                  style: const TextStyle(
                      fontSize: 11, color: _muted, fontWeight: FontWeight.w500, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Container(
                height: 30,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF353B69), Color(0xFF6470D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text(data['btn'] as String,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLACE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _PlaceCard extends StatelessWidget {
  final Map<String, dynamic> place;
  final double width;
  const _PlaceCard({required this.place, required this.width});

  IconData _typeIcon(String? type) {
    final t = (type ?? '').toLowerCase();
    if (t.contains('hospital') || t.contains('clinic'))  return Icons.local_hospital_outlined;
    if (t.contains('museum')   || t.contains('gallery')) return Icons.account_balance_outlined;
    if (t.contains('mall')     || t.contains('shop'))    return Icons.shopping_bag_outlined;
    if (t.contains('park')     || t.contains('garden'))  return Icons.park_outlined;
    if (t.contains('restaurant')|| t.contains('cafe'))   return Icons.restaurant_outlined;
    if (t.contains('hotel'))                             return Icons.hotel_outlined;
    if (t.contains('transit')  || t.contains('station')) return Icons.train_outlined;
    return Icons.place_outlined;
  }

  List<String> _accessFeatures() {
    final f = <String>[];
    bool flag(dynamic v) => v == true || v == 1 || v == '1';
    if (flag(place['wheelchair'])) f.add('Wheelchair');
    if (flag(place['elevator']))   f.add('Elevator');
    if (flag(place['ramp']))       f.add('Ramp');
    if (flag(place['toilet']))     f.add('Toilet');
    if (flag(place['parking']))    f.add('Parking');
    return f;
  }

  @override
  Widget build(BuildContext context) {
    final name     = place['name']    ?? 'Place';
    final type     = place['type']    ?? 'General';
    final rating   = place['rating']?.toString() ?? '0';
    final dist     = place['distance_km'] ?? place['distanceKm'];
    final features = _accessFeatures();

    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: _iconBg, borderRadius: BorderRadius.circular(9)),
                  child: Icon(_typeIcon(type), size: 16, color: _primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _dark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(999)),
              child: Text(type,
                  style: const TextStyle(color: _primary, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 12, color: Color(0xFFEDCC6F)),
                const SizedBox(width: 3),
                Text(rating,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _muted)),
                if (dist != null) ...[
                  const Spacer(),
                  Text('${dist}km',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700, color: _primary)),
                ],
              ],
            ),
            if (features.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4, runSpacing: 4,
                children: features.take(2).map((f) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration:
                      BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(999)),
                  child: Text(f,
                      style: const TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w600, color: _muted)),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT CARD
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final double width;
  final int cartQty;
  final VoidCallback onAddToCart;

  const _ProductCard({
    required this.product,
    required this.width,
    required this.cartQty,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cartQty > 0 ? _accent.withOpacity(0.35) : _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Container(
                height: 110,
                width: double.infinity,
                color: Colors.white,
                child: Image.asset(
                  product['img'] as String,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Center(child: Icon(Icons.image_outlined, color: _muted, size: 28)),
                ),
              ),
            ),
            Container(height: 1, color: _line),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 36,
                    child: Text(product['title'] as String,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: _dark, height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(height: 4),
                  Text(product['price'] as String,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800, color: _dark)),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: onAddToCart,
                    child: Container(
                      height: 32,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF353B69), Color(0xFF6470D2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_shopping_cart_rounded,
                              color: Colors.white, size: 13),
                          const SizedBox(width: 5),
                          Text(
                            cartQty > 0 ? 'Add More ($cartQty)' : 'Add to Cart',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}  // ← _ProductCard ends HERE

// ─────────────────────────────────────────────────────────────────────────────
// FLOATING CHATBOT
// ─────────────────────────────────────────────────────────────────────────────
class _FloatingChatbot extends StatefulWidget {
  const _FloatingChatbot();

  @override
  State<_FloatingChatbot> createState() => _FloatingChatbotState();
}

class _FloatingChatbotState extends State<_FloatingChatbot>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  static const _suggestions = [
    'How do I book a driver?',
    'Find accessible places',
    'Book a doctor visit',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fadeAnim  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  void _openFullChat({String? initialMessage}) {
    setState(() => _expanded = false);
    _ctrl.reverse();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RafiqChatbotScreen(initialMessage: initialMessage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 18,
      bottom: MediaQuery.of(context).padding.bottom + 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_expanded)
            FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                alignment: Alignment.bottomRight,
                child: _ChatPreviewPanel(
                  onClose: _toggle,
                  onOpenFull: () => _openFullChat(),
                  onSuggestion: (q) => _openFullChat(initialMessage: q),
                  suggestions: _suggestions,
                ),
              ),
            ),
          if (_expanded) const SizedBox(height: 12),
          GestureDetector(
            onTap: _toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _expanded ? 52 : 56,
              height: _expanded ? 52 : 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF353B69), Color(0xFF6470D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6470D2).withOpacity(0.40),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _expanded
                    ? const Icon(Icons.keyboard_arrow_down_rounded,
                        key: ValueKey('close'), color: Colors.white, size: 24)
                    : Image.asset('assets/images/helpy.png',
                        key: ValueKey('helpy'), width: 40, height: 40, scale: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}  // ← _FloatingChatbot ends HERE

// ─────────────────────────────────────────────────────────────────────────────
// CHAT PREVIEW PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _ChatPreviewPanel extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onOpenFull;
  final ValueChanged<String> onSuggestion;
  final List<String> suggestions;

  const _ChatPreviewPanel({
    required this.onClose,
    required this.onOpenFull,
    required this.onSuggestion,
    required this.suggestions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 288,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x246470D2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E2040).withOpacity(0.13),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E2040), Color(0xFF353B69), Color(0xFF6470D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF353B69), Color(0xFF6470D2)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset('assets/images/helpy.png', fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Helpy',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.2,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Online',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.72),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 15),
                  ),
                ),
              ],
            ),
          ),
          // Bot greeting bubble
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF353B69), Color(0xFF6470D2)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset('assets/images/helpy.png', fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5FB),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                      border: Border.all(color: const Color(0x246470D2)),
                    ),
                    child: const Text(
                      "Hi! 👋 I'm Helpy. How can I help you today?",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E2040),
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Suggestion chips
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'QUICK QUESTIONS',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6B7080),
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 8),
                ...suggestions.map((q) => GestureDetector(
                  onTap: () => onSuggestion(q),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 7),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5FB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x306470D2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 10, color: Color(0xFF6470D2)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            q,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF353B69),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
              ],
            ),
          ),
          // Open full chat button
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: GestureDetector(
              onTap: onOpenFull,
              child: Container(
                height: 40,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF353B69), Color(0xFF6470D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Open full chat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.open_in_full_rounded, color: Colors.white, size: 14),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}  