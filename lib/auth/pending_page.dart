// ============================================================
// lib/auth/pending_page.dart
// ============================================================
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'session_manager.dart';
import 'login.dart';
import 'provider_navigation.dart';

class PendingPage extends StatefulWidget {
  final int userId;
  final String? providerType; // may be null if they have no type yet

  const PendingPage({
    super.key,
    required this.userId,
    this.providerType,
  });

  @override
  State<PendingPage> createState() => _PendingPageState();
}

class _PendingPageState extends State<PendingPage>
    with SingleTickerProviderStateMixin {
  // ── State ───────────────────────────────────────────────
  String _status = 'pending'; // pending | accepted | rejected
  String _pollMessage = 'Checking for updates…';
  bool _redirecting = false;
  int _attempts = 0;
  Timer? _timer;

  // ── Animation ───────────────────────────────────────────
  late AnimationController _pulse;
  late Animation<double> _scale;

  // ── Palette (Rafiq) ─────────────────────────────────────
  static const _dark   = Color(0xFF2B2C41);
  static const _purple = Color(0xFF404066);
  static const _sky    = Color(0xFF88CAFC);
  static const _blue   = Color(0xFFD2EBFF);
  static const _gold   = Color(0xFFEDCC6F);

  @override
  void initState() {
    super.initState();

    // pulse animation for the icon
    _pulse = AnimationController(
      vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    // start polling after 3s
    Future.delayed(const Duration(seconds: 3), _poll);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  // ── Poll server ─────────────────────────────────────────
  Future<void> _poll() async {
    if (!mounted) return;
    try {
      final res = await http
          .get(Uri.parse(
            'http://10.13.114.211/Api/check_status.php?user_id=${widget.userId}',
          ))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      final data = jsonDecode(res.body);

      if (data['success'] == true) {
        final status = (data['status'] ?? 'pending').toLowerCase().trim();
        final type   = data['provider_type'] as String?;

        setState(() => _status = status);

        // ── Accepted → redirect ──────────────────────────
        if (status == 'accepted') {
          final providerType = type ?? widget.providerType;
          if (providerType != null && !_redirecting) {
            setState(() {
              _redirecting   = true;
              _pollMessage   = 'Approved! Redirecting to your dashboard…';
            });
            await Future.delayed(const Duration(milliseconds: 1200));
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ProviderNavigation(providerType: providerType),
              ),
            );
          }
          return; // stop polling
        }

        // ── Rejected → stop polling ──────────────────────
        if (status == 'rejected') return;

        // ── Still pending ────────────────────────────────
        setState(() => _pollMessage = 'Still waiting for admin review…');
      }
    } catch (_) {}

    // schedule next poll (slow down after 20 attempts)
    _attempts++;
    final delay = _attempts > 20 ? 15 : 5;
    if (mounted) {
      _timer = Timer(Duration(seconds: delay), _poll);
    }
  }

  // ── Logout ──────────────────────────────────────────────
  Future<void> _logout() async {
    _timer?.cancel();
    await SessionManager.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const Login()),
      (_) => false,
    );
  }

  // ── UI ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_dark, _purple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 40, offset: const Offset(0, 16),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Image.asset('assets/images/logo.png', height: 64,
                        errorBuilder: (_, __, ___) => const Text('RafiQ',
                            style: TextStyle(fontSize: 28,
                                fontWeight: FontWeight.w900, color: _dark))),
                    const SizedBox(height: 28),

                    // Animated icon
                    ScaleTransition(
                      scale: _status == 'pending' ? _scale
                          : const AlwaysStoppedAnimation(1.0),
                      child: Text(_statusIcon(),
                          style: const TextStyle(fontSize: 60)),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Text(_statusTitle(),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800,
                            color: _dark),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),

                    // Status badge
                    _StatusBadge(status: _status),
                    const SizedBox(height: 20),

                    // Description
                    if (_status != 'rejected') ...[
                      const Text(
                        'Thank you for signing up as a provider on Rafiq.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.6),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Our admin team is reviewing your application and documents. You will be able to access your dashboard once your account is approved.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.6),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'If you have any questions, please contact support.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    // Rejection box
                    if (_status == 'rejected') ...[
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3F3),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Text(
                          '❌  Unfortunately, your application was not approved. Please contact our support team for more information.',
                          style: TextStyle(
                              color: Color(0xFF8D2727),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.6),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Poll status message
                    if (_status == 'pending')
                      Text(_pollMessage,
                          style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                              fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center),

                    if (_status == 'accepted' && _redirecting)
                      Text(_pollMessage,
                          style: const TextStyle(
                              color: Color(0xFF059669),
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center),

                    const SizedBox(height: 24),

                   SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    onPressed: () => Navigator.pushAndRemoveUntil(
  context,
  MaterialPageRoute(builder: (_) => const Login()),
  (_) => false,
),
    icon: const Icon(Icons.arrow_back_rounded, size: 18),
    label: const Text('Back',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    style: ElevatedButton.styleFrom(
      backgroundColor: _dark,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30)),
    ),
  ),
),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────
  String _statusIcon() {
    switch (_status) {
      case 'accepted': return '✅';
      case 'rejected': return '❌';
      default:         return '⏳';
    }
  }

  String _statusTitle() {
    switch (_status) {
      case 'accepted': return 'Approved! Redirecting you…';
      case 'rejected': return 'Application not approved';
      default:         return 'Your application is under review';
    }
  }
}

// ── Status badge widget ────────────────────────────────────
class _StatusBadge extends StatefulWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  State<_StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<_StatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _blink;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1.0, end: 0.2)
        .animate(CurvedAnimation(parent: _blink, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _blink.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cfg = _badgeConfig();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: cfg['bg'] as Color,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: cfg['border'] as Color),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // Blinking dot (only for pending)
        if (widget.status == 'pending')
          AnimatedBuilder(
            animation: _opacity,
            builder: (_, __) => Opacity(
              opacity: _opacity.value,
              child: Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: cfg['dot'] as Color,
                      shape: BoxShape.circle)),
            ),
          )
        else
          Container(width: 8, height: 8,
              decoration: BoxDecoration(color: cfg['dot'] as Color,
                  shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(cfg['label'] as String,
            style: TextStyle(color: cfg['text'] as Color,
                fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }

  Map<String, dynamic> _badgeConfig() {
    switch (widget.status) {
      case 'accepted':
        return {'bg': const Color(0xFFF0FBF5), 'border': const Color(0xFFA7F3D0),
                'dot': const Color(0xFF059669), 'text': const Color(0xFF12643E),
                'label': 'Accepted'};
      case 'rejected':
        return {'bg': const Color(0xFFFFF3F3), 'border': const Color(0xFFFCA5A5),
                'dot': const Color(0xFFEF4444), 'text': const Color(0xFF8D2727),
                'label': 'Rejected'};
      default:
        return {'bg': const Color(0xFFF0F0FF), 'border': const Color(0xFFC0C0F0),
                'dot': const Color(0xFF6470D2), 'text': const Color(0xFF4A4AAA),
                'label': 'Pending Approval'};
    }
  }
}