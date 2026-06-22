// lib/screens/earnings_screen.dart
import 'package:flutter/material.dart';
import '../auth/api_service.dart';
import '../auth/session_manager.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});
  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  Map? _summary;
  bool _loading = true;

  static const kPrimary = Color(0xFF4B4F83);
  static const kAccent  = Color(0xFF6470D2);
  static const kDark    = Color(0xFF242742);
  static const kMuted   = Color(0xFF6B7188);
  static const kBg      = Color(0xFFF6F8FD);
  static const kBg2     = Color(0xFFF1F4FB);
  static const kCard    = Colors.white;
  static const kGreen   = Color(0xff1F9D5A);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final id = await SessionManager.getUserId();
      if (id == null) { setState(() => _loading = false); return; }
      final data = await ApiService.getProviderEarnings(id);
      if (mounted) setState(() { _summary = data?['summary']; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kBg, kBg2],
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kPrimary))
            : RefreshIndicator(
                onRefresh: _load,
                color: kPrimary,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [SliverToBoxAdapter(child: _body())],
                ),
              ),
      ),
    );
  }

  Widget _body() {
    final netBalance  = double.tryParse(_summary?['net_earned']?.toString()  ?? '0') ?? 0;
    final totalJobs   = int.tryParse(_summary?['total_jobs']?.toString()     ?? '0') ?? 0;
    final pendingJobs = int.tryParse(_summary?['pending_jobs']?.toString()   ?? '0') ?? 0;
    final totalEarned = double.tryParse(_summary?['total_earned']?.toString() ?? '0') ?? 0;
    final avgRating   = _summary?['avg_rating']?.toString();
    final hasRating   = avgRating != null && avgRating.isNotEmpty && avgRating != 'null';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        const Text('Earnings',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                color: kDark, letterSpacing: -0.5)),
        const SizedBox(height: 5),
        const Text('Track your income & activity',
            style: TextStyle(fontSize: 13, color: kMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 24),

        // Wallet Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF20233C), Color(0xFF353B69), Color(0xFF6470D2)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: kAccent.withOpacity(0.28), blurRadius: 24, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Net Wallet Balance',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 22),
            Text('${netBalance.toStringAsFixed(2)} EGP',
                style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: -1)),
          ]),
        ),

        const SizedBox(height: 22),

        // KPI Grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 14, mainAxisSpacing: 14,
          childAspectRatio: 1.08,
          children: [
            _kpiCard(Icons.check_circle_rounded,   const Color.fromARGB(154, 31, 157, 90),   'Completed Sessions', '$totalJobs'),
            _kpiCard(Icons.pending_actions_rounded, const Color.fromARGB(255, 84, 99, 157),   'Pending',            '$pendingJobs'),
            _kpiCard(Icons.attach_money_rounded,    const Color.fromARGB(255, 108, 119, 195),  'Gross Total',        '${totalEarned.toStringAsFixed(0)} EGP'),
            _kpiCard(Icons.star_rounded,            const Color.fromARGB(255, 134, 140, 224), 'Rating',             hasRating ? '$avgRating / 5' : '--'),
          ],
        ),
      ]),
    );
  }

  Widget _kpiCard(IconData icon, Color iconColor, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(height: 14),
        Text(label, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: kMuted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        Text(value, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: kDark)),
      ]),
    );
  }
}