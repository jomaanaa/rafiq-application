// ============================================================
// lib/admin/admin_overview_page.dart
// ============================================================
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'admin_api_service.dart';
import 'admin_helpers.dart';


const _c1 = Color(0xFF2B2C41);
const _c2 = Color(0xFF404066);
const _c3 = Color(0xFF88CAFC);
const _c4 = Color(0xFFD2EBFF);
const _c5 = Color(0xFFEDCC6F);
const _chartColors = [_c2, _c3, _c5, _c1, _c4];

class AdminOverviewPage extends StatefulWidget {
  const AdminOverviewPage({super.key});
  @override
  State<AdminOverviewPage> createState() => _AdminOverviewPageState();
}

class _AdminOverviewPageState extends State<AdminOverviewPage> {
  Map<String, dynamic>? _s;
  bool _loading = true, _error = false;

  bool _chartsOpen    = false;
  bool _providersOpen = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final s = await AdminApiService.getStats();
      if (!mounted) return;
      setState(() { _s = s; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = true; _loading = false; });
    }
  }

  void _showChartsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChartsBottomSheet(s: _s!),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(
        child: CircularProgressIndicator(color: _c2, strokeWidth: 2));
    if (_error) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.wifi_off_rounded, size: 44, color: _c3),
        const SizedBox(height: 10),
        const Text('Could not load dashboard',
            style: TextStyle(color: _c2, fontSize: 14)),
        const SizedBox(height: 14),
        ElevatedButton(onPressed: _load,
            style: ElevatedButton.styleFrom(backgroundColor: _c2,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Retry')),
      ],
    ));

    final s = _s!;
    return RefreshIndicator(
      onRefresh: _load, color: _c2,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Header(s: s),
          const SizedBox(height: 18),
          _StatCards(s: s),
          const SizedBox(height: 14),
          _TotalRevenueCard(s: s),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _showChartsSheet,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_c2, _c3],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: _c2.withOpacity(0.25),
                    blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.bar_chart_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('View Charts & Analytics',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 14)),
                SizedBox(width: 8),
                Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 16),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          _AccordionCard(
            title: 'Top Providers',
            subtitle: 'Hours worked & revenue earned',
            icon: Icons.emoji_events_rounded,
            iconColor: _c5,
            isOpen: _providersOpen,
            onToggle: () => setState(() => _providersOpen = !_providersOpen),
            child: _TopProvidersBody(s: s),
          ),
        ]),
      ),
    );
  }
}

// ── Accordion Card ─────────────────────────────────────────
class _AccordionCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isOpen;
  final VoidCallback onToggle;
  final Widget child;

  const _AccordionCard({
    required this.title, required this.subtitle,
    required this.icon, required this.iconColor,
    required this.isOpen, required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: kCardBox,
      child: Column(children: [
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: isOpen
                  ? const BorderRadius.vertical(top: Radius.circular(16))
                  : BorderRadius.circular(16),
            ),
            child: Row(children: [
              Container(width: 30, height: 30,
                decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 15)),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700, color: _c1)),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: _c2)),
              ])),
              AnimatedRotation(
                turns: isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 300),
                child: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: _c2, size: 22),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(children: [
            const Divider(height: 1, color: _c4),
            child,
          ]),
          crossFadeState: isOpen
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
      ]),
    );
  }
}

// ── Charts Bottom Sheet ────────────────────────────────────
class _ChartsBottomSheet extends StatelessWidget {
  final Map<String, dynamic> s;
  const _ChartsBottomSheet({required this.s});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF6F8FD),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: _c4, borderRadius: BorderRadius.circular(4)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(children: [
              const Icon(Icons.bar_chart_rounded, color: _c2, size: 20),
              const SizedBox(width: 8),
              const Text('Charts & Analytics',
                  style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w800, color: _c1)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: _c4, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.close_rounded, color: _c2, size: 18),
                ),
              ),
            ]),
          ),
          const Divider(height: 1, color: _c4),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _ChartCard(title: 'Monthly Bookings',
                    subtitle: 'Booking activity per month',
                    icon: Icons.bar_chart_rounded, iconColor: _c3,
                    child: _MonthlyBarChart(s: s)),
                const SizedBox(height: 14),
                _ChartCard(title: 'Revenue Trend',
                    subtitle: 'Monthly earnings (EGP)',
                    icon: Icons.trending_up_rounded, iconColor: _c5,
                    child: _RevenueLineChart(s: s)),
                const SizedBox(height: 14),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _ChartCard(title: 'By Category',
                      subtitle: 'Provider types',
                      icon: Icons.donut_large_rounded, iconColor: _c2,
                      child: _CategoryPieChart(s: s))),
                  const SizedBox(width: 12),
                  Expanded(child: _ChartCard(title: 'Services',
                      subtitle: 'Most requested',
                      icon: Icons.local_activity_rounded, iconColor: _c5,
                      child: _ServicesPieChart(s: s))),
                ]),
                const SizedBox(height: 14),
                _ChartCard(title: 'Provider Ratings',
                    subtitle: 'Top rated providers by patients',
                    icon: Icons.star_rounded, iconColor: _c5,
                    child: _ProviderRatingsChart(s: s)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final Map<String, dynamic> s;
  const _Header({required this.s});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const mo = ['Jan','Feb','Mar','Apr','May','Jun',
                 'Jul','Aug','Sep','Oct','Nov','Dec'];
    const dy = ['Monday','Tuesday','Wednesday','Thursday',
                 'Friday','Saturday','Sunday'];
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Dashboard', style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800, color: _c1)),
        Text('${dy[now.weekday-1]}, ${now.day} ${mo[now.month-1]} ${now.year}',
            style: const TextStyle(fontSize: 12, color: _c2)),
      ])),
      if ((s['pendingProviders'] ?? 0) > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _c5.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _c5.withOpacity(0.5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.hourglass_top_rounded,
                size: 13, color: Color(0xFF7A5F00)),
            const SizedBox(width: 5),
            Text('${s['pendingProviders']} pending',
                style: const TextStyle(fontSize: 11,
                    color: Color(0xFF7A5F00), fontWeight: FontWeight.w700)),
          ]),
        ),
    ]);
  }
}

// ── 4 Stat cards ───────────────────────────────────────────
class _StatCards extends StatelessWidget {
  final Map<String, dynamic> s;
  const _StatCards({required this.s});
  @override
  Widget build(BuildContext context) => GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
    childAspectRatio: 1.65,
    children: [
      _StatCard(value: s['totalProviders'] ?? 0,
          label: 'Total Providers', sub: '${s['acceptedProviders'] ?? 0} active',
          icon: Icons.people_rounded,
          gradient: const LinearGradient(
              colors: [_c1, _c2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          valueColor: Colors.white, subColor: Colors.white54,
          iconBg: Colors.white12, iconColor: Colors.white),
      _StatCard(value: s['totalPatients'] ?? 0,
          label: 'Total Patients', sub: 'Registered',
          icon: Icons.accessible_rounded,
          gradient: const LinearGradient(
              colors: [_c2, _c3], begin: Alignment.topLeft, end: Alignment.bottomRight),
          valueColor: Colors.white, subColor: Colors.white54,
          iconBg: Colors.white12, iconColor: Colors.white),
      _StatCard(value: s['totalBookings'] ?? 0,
          label: 'Total Bookings', sub: '${s['doneBookings'] ?? 0} done',
          icon: Icons.receipt_long_rounded,
          gradient: const LinearGradient(
              colors: [_c3, _c2], begin: Alignment.topRight, end: Alignment.bottomLeft),
          valueColor: Colors.white, subColor: Colors.white54,
          iconBg: Colors.white12, iconColor: Colors.white),
      _StatCard(value: s['pendingProviders'] ?? 0,
          label: 'Pending', sub: 'Need review',
          icon: Icons.hourglass_top_rounded,
          gradient: const LinearGradient(
              colors: [_c5, Color(0xFFD4A832)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          valueColor: _c1, subColor: const Color(0x99000000),
          iconBg: const Color(0x222B2C41), iconColor: _c1),
    ],
  );
}

class _StatCard extends StatelessWidget {
  final int value;
  final String label, sub;
  final IconData icon;
  final LinearGradient gradient;
  final Color valueColor, subColor, iconBg, iconColor;
  const _StatCard({required this.value, required this.label, required this.sub,
      required this.icon, required this.gradient, required this.valueColor,
      required this.subColor, required this.iconBg, required this.iconColor});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12),
            blurRadius: 10, offset: const Offset(0, 4))]),
    child: Column(mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(width: 30, height: 30,
          decoration: BoxDecoration(color: iconBg,
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 15)),
      const SizedBox(height: 7),
      Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
          color: valueColor, height: 1), textAlign: TextAlign.center),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
          color: valueColor), textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis),
      Text(sub, style: TextStyle(fontSize: 9, color: subColor),
          textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
    ]),
  );
}
class _TotalRevenueCard extends StatelessWidget {
  final Map<String, dynamic> s;
  const _TotalRevenueCard({required this.s});

  @override
  Widget build(BuildContext context) {
    final total     = double.tryParse('${s['totalRevenue']    ?? 0}') ?? 0.0;
    final platform  = double.tryParse('${s['platformRevenue'] ?? 0}') ?? 0.0;
    final payouts   = double.tryParse('${s['providerPayouts'] ?? 0}') ?? 0.0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [_c1, _c2],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: _c1.withOpacity(0.3),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Row 1: icon + title only ──
        Row(children: [
          Container(width: 28, height: 28,
            decoration: BoxDecoration(color: _c5.withOpacity(0.2),
                borderRadius: BorderRadius.circular(7)),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: _c5, size: 15)),
          const SizedBox(width: 8),
          const Text('Revenue Breakdown',
              style: TextStyle(color: Colors.white, fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ]),

        const SizedBox(height: 16),

        // ── Gross total ──
        const Text('Gross Revenue',
            style: TextStyle(color: Colors.white60, fontSize: 10)),
        const SizedBox(height: 4),
        Text('EGP ${total.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white,
                fontSize: 26, fontWeight: FontWeight.w900)),

        const SizedBox(height: 14),
        const Divider(color: Colors.white24, height: 1),
        const SizedBox(height: 14),

        // ── Platform / Provider split ──
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.business_rounded, size: 12, color: _c5),
              const SizedBox(width: 4),
              const Text('RafiQ (15%)',
                  style: TextStyle(color: _c5, fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 5),
            Text('EGP ${platform.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white,
                    fontSize: 17, fontWeight: FontWeight.w900)),
            const Text('Platform commission',
                style: TextStyle(color: Colors.white38, fontSize: 9)),
          ])),
          Container(width: 1, height: 44, color: Colors.white24),
          Expanded(child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.people_rounded, size: 12, color: _c3),
                const SizedBox(width: 4),
                const Text('Providers (85%)',
                    style: TextStyle(color: _c3, fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 5),
              Text('EGP ${payouts.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 17, fontWeight: FontWeight.w900)),
              const Text('Provider earnings',
                  style: TextStyle(color: Colors.white38, fontSize: 9)),
            ]),
          )),
        ]),
      ]),
    );
  }
}

// ── Chart card wrapper ─────────────────────────────────────
class _ChartCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  const _ChartCard({required this.title, required this.subtitle,
      required this.icon, required this.iconColor, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: kCardBox,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 30, height: 30,
          decoration: BoxDecoration(color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 15)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: _c1)),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: _c2)),
        ])),
      ]),
      const SizedBox(height: 16),
      child,
    ]),
  );
}

// ── Monthly Bookings Bar Chart ─────────────────────────────
class _MonthlyBarChart extends StatelessWidget {
  final Map<String, dynamic> s;
  const _MonthlyBarChart({required this.s});
  @override
  Widget build(BuildContext context) {
    final data   = List<Map>.from(s['monthly'] ?? []);
    if (data.isEmpty) return const _NoData();
    final counts = data.map((d) => int.tryParse('${d['count']}') ?? 0).toList();
    final maxY   = counts.reduce((a, b) => a > b ? a : b).toDouble();
    return SizedBox(height: 160, child: BarChart(BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY * 1.25,
      gridData: FlGridData(show: true, drawVerticalLine: false,
        horizontalInterval: maxY > 0 ? maxY / 3 : 1,
        getDrawingHorizontalLine: (_) =>
            const FlLine(color: _c4, strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
          getTitlesWidget: (val, _) {
            final i = val.toInt();
            if (i < 0 || i >= data.length) return const SizedBox();
            return Padding(padding: const EdgeInsets.only(top: 5),
              child: Text('${data[i]['month']}',
                  style: const TextStyle(fontSize: 9, color: _c2)));
          })),
        leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),
      ),
      barGroups: counts.asMap().entries.map((e) {
        final isMax = e.value == maxY.toInt() && e.value > 0;
        return BarChartGroupData(x: e.key, barRods: [
          BarChartRodData(toY: e.value.toDouble(), width: 20,
            borderRadius: BorderRadius.circular(6),
            gradient: LinearGradient(
              colors: isMax ? [_c3, _c2] : [_c4, _c3],
              begin: Alignment.bottomCenter, end: Alignment.topCenter)),
        ]);
      }).toList(),
      barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (group) => _c1,
        getTooltipItem: (g, _, rod, __) => BarTooltipItem(
          '${rod.toY.toInt()} bookings',
          const TextStyle(color: _c5, fontSize: 11,
              fontWeight: FontWeight.bold)),
      )),
    )));
  }
}

// ── Revenue Line Chart ─────────────────────────────────────
class _RevenueLineChart extends StatelessWidget {
  final Map<String, dynamic> s;
  const _RevenueLineChart({required this.s});
  @override
  Widget build(BuildContext context) {
    final data = List<Map>.from(s['monthlyRevenue'] ?? []);
    if (data.isEmpty) return const _NoData();
    final spots = data.asMap().entries.map((e) {
      final v = double.tryParse('${e.value['total'] ?? 0}') ?? 0.0;
      return FlSpot(e.key.toDouble(), v);
    }).toList();
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    return SizedBox(height: 160, child: LineChart(LineChartData(
      minY: 0, maxY: maxY > 0 ? maxY * 1.25 : 10,
      gridData: FlGridData(show: true, drawVerticalLine: false,
        horizontalInterval: maxY > 0 ? maxY / 3 : 1,
        getDrawingHorizontalLine: (_) =>
            const FlLine(color: _c4, strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
            interval: 1,
          getTitlesWidget: (val, _) {
            final i = val.toInt();
            if (i < 0 || i >= data.length) return const SizedBox();
            return Padding(padding: const EdgeInsets.only(top: 5),
              child: Text('${data[i]['month']}',
                  style: const TextStyle(fontSize: 9, color: _c2)));
          })),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
            reservedSize: 38,
          interval: maxY > 0 ? maxY / 3 : 1,
          getTitlesWidget: (val, _) => Text(
            val >= 1000
                ? '${(val/1000).toStringAsFixed(0)}k'
                : val.toStringAsFixed(0),
            style: const TextStyle(fontSize: 8, color: _c2)))),
        topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: [LineChartBarData(
        spots: spots, isCurved: true, curveSmoothness: 0.35,
        color: _c5, barWidth: 2.5, isStrokeCapRound: true,
        dotData: FlDotData(show: true,
          getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
              radius: 3.5, color: _c5,
              strokeWidth: 2, strokeColor: Colors.white)),
        belowBarData: BarAreaData(show: true,
          gradient: LinearGradient(
            colors: [_c5.withOpacity(0.18), _c5.withOpacity(0.01)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      )],
    )));
  }
}

// ── Category Pie Chart ─────────────────────────────────────
class _CategoryPieChart extends StatelessWidget {
  final Map<String, dynamic> s;
  const _CategoryPieChart({required this.s});
  @override
  Widget build(BuildContext context) {
    final raw  = List<Map>.from(s['byCategory'] ?? []);
    final data = raw.where((d) {
      final cat = '${d['category'] ?? ''}'.trim().toLowerCase();
      return cat != 'provider 2';
    }).toList();

    if (data.isEmpty) return const _NoData();
    final total = data.fold(0,
        (sum, d) => sum + (int.tryParse('${d['count']}') ?? 0));
    return Column(children: [
      SizedBox(height: 120, child: PieChart(PieChartData(
        sections: data.asMap().entries.map((e) {
          final count = int.tryParse('${e.value['count']}') ?? 0;
          final pct   = total > 0 ? count / total * 100 : 0.0;
          return PieChartSectionData(value: count.toDouble(),
            color: _chartColors[e.key % _chartColors.length], radius: 44,
            title: '${pct.toStringAsFixed(0)}%',
            titleStyle: const TextStyle(color: Colors.white,
                fontSize: 10, fontWeight: FontWeight.bold));
        }).toList(),
        centerSpaceRadius: 22, sectionsSpace: 2,
      ))),
      const SizedBox(height: 12),
      ...data.asMap().entries.map((e) {
        final count = int.tryParse('${e.value['count']}') ?? 0;
        final cat   = '${e.value['category']}';
        final color = _chartColors[e.key % _chartColors.length];
        return Padding(padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Container(width: 8, height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Icon(catIcon(cat), size: 11, color: _c2),
            const SizedBox(width: 4),
            Expanded(child: Text(cat,
                style: const TextStyle(fontSize: 10, color: _c2))),
            Text('$count', style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w700, color: color)),
          ]));
      }),
    ]);
  }
}

// ── Services Pie Chart ─────────────────────────────────────
class _ServicesPieChart extends StatelessWidget {
  final Map<String, dynamic> s;
  const _ServicesPieChart({required this.s});

  static bool _isInterpreter(String t) =>
      t.toLowerCase().startsWith('interpreter');

  static IconData _serviceOrCatIcon(String type) {
    final t = type.toLowerCase().trim();
    if (t == 'interpreter' || t == 'interpreter') return Icons.translate_rounded;
    if (t == 'caregiver')   return Icons.favorite_rounded;
    if (t == 'driver')      return Icons.directions_car_rounded;
    if (t == 'doctor')      return Icons.local_hospital_rounded;
    return serviceIcon(type);
  }

  static List<Map<String, dynamic>> _mergeInterpreters(List<Map> raw) {
    int interpreterTotal = 0;
    final others = <Map<String, dynamic>>[];
    for (final item in raw) {
      final type  = '${item['service_type'] ?? ''}';
      final count = int.tryParse('${item['count']}') ?? 0;
      if (_isInterpreter(type)) {
        interpreterTotal += count;
      } else {
        others.add({'service_type': type, 'count': count});
      }
    }
    if (interpreterTotal > 0) {
      others.insert(0, {'service_type': 'Interpreter', 'count': interpreterTotal});
    }
    others.sort((a, b) =>
        (b['count'] as int).compareTo(a['count'] as int));
    return others.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final raw  = List<Map>.from(s['services'] ?? []);
    if (raw.isEmpty) return const _NoData();
    final data  = _mergeInterpreters(raw);
    final total = data.fold(0, (sum, d) => sum + (d['count'] as int));
    String short(String t) => t.length > 14 ? '${t.substring(0, 13)}…' : t;
    return Column(children: [
      SizedBox(height: 120, child: PieChart(PieChartData(
        sections: data.asMap().entries.map((e) {
          final count = e.value['count'] as int;
          final pct   = total > 0 ? count / total * 100 : 0.0;
          return PieChartSectionData(value: count.toDouble(),
            color: _chartColors[e.key % _chartColors.length], radius: 44,
            title: '${pct.toStringAsFixed(0)}%',
            titleStyle: const TextStyle(color: Colors.white,
                fontSize: 10, fontWeight: FontWeight.bold));
        }).toList(),
        centerSpaceRadius: 22, sectionsSpace: 2,
      ))),
      const SizedBox(height: 12),
      ...data.asMap().entries.map((e) {
        final count = e.value['count'] as int;
        final type  = e.value['service_type'] as String;
        final color = _chartColors[e.key % _chartColors.length];
        return Padding(padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Container(width: 8, height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Icon(_serviceOrCatIcon(type), size: 11, color: _c2),
            const SizedBox(width: 4),
            Expanded(child: Text(short(type),
                style: const TextStyle(fontSize: 10, color: _c2),
                overflow: TextOverflow.ellipsis)),
            Text('$count', style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w700, color: color)),
          ]));
      }),
    ]);
  }
}

// ── Provider Ratings Chart ─────────────────────────────────
class _ProviderRatingsChart extends StatelessWidget {
  final Map<String, dynamic> s;
  const _ProviderRatingsChart({required this.s});

  @override
  Widget build(BuildContext context) {
    final providers = List<Map>.from(s['topRatedProviders'] ?? []);
    if (providers.isEmpty) return const _NoData(msg: 'No ratings yet');

    final rated = providers
        .where((p) => (double.tryParse('${p['avg_rating'] ?? 0}') ?? 0) > 0)
        .toList();

    if (rated.isEmpty) return const _NoData(msg: 'No ratings yet');

    final avg = double.tryParse('${s['avgRating'] ?? 0}') ?? 0.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _c5.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _c5.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.star_rounded, color: _c5, size: 28),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(avg.toStringAsFixed(1), style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, color: _c1)),
            const Text('Overall average rating',
                style: TextStyle(fontSize: 10, color: _c2)),
          ]),
        ]),
      ),
      const SizedBox(height: 14),

      ...rated.take(5).map((p) {
        final name   = '${p['name'] ?? '—'}';
        final cat    = '${p['category'] ?? ''}';
        final rating = double.tryParse('${p['avg_rating'] ?? 0}') ?? 0.0;
        final total  = int.tryParse('${p['rating_count'] ?? 0}') ?? 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _c4.withOpacity(0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            UserAvatar(name, 34),
            const SizedBox(width: 10),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _c1),
                  overflow: TextOverflow.ellipsis),
              Row(children: [
                Icon(catIcon(cat), size: 10, color: _c2),
                const SizedBox(width: 3),
                Text(cat, style: const TextStyle(fontSize: 9, color: _c2)),
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(children: [
                Text(rating.toStringAsFixed(1), style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900, color: _c1)),
                const SizedBox(width: 3),
                const Icon(Icons.star_rounded, color: _c5, size: 14),
              ]),
              Text('$total reviews',
                  style: const TextStyle(fontSize: 9, color: _c2)),
            ]),
          ]),
        );
      }),
    ]);
  }
}

// ── Top Providers Body ─────────────────────────────────────
class _TopProvidersBody extends StatelessWidget {
  final Map<String, dynamic> s;
  const _TopProvidersBody({required this.s});
  @override
  Widget build(BuildContext context) {
    final providers = List<Map>.from(s['topProviders'] ?? []);
    final maxBooks  = providers.isEmpty ? 1
        : providers.map((p) => int.tryParse('${p['total_bookings']}') ?? 0)
            .reduce((a, b) => a > b ? a : b);
    if (providers.isEmpty)
      return const Padding(padding: EdgeInsets.all(24), child: _NoData());
    return Column(children: [
      ...providers.asMap().entries.map((e) {
        final p      = e.value;
        final rank   = e.key;
        final name   = '${p['name'] ?? '—'}';
        final cat    = '${p['category'] ?? ''}';
        final books  = int.tryParse('${p['total_bookings']}') ?? 0;
        final hours  = double.tryParse('${p['total_hours']  ?? 0}') ?? 0.0;
        final earned = double.tryParse('${p['total_earned'] ?? 0}') ?? 0.0;
        final pct    = maxBooks > 0 ? books / maxBooks : 0.0;
        final rankBg = rank == 0 ? _c5.withOpacity(0.2)
            : rank == 1 ? _c3.withOpacity(0.2)
            : rank == 2 ? _c4 : const Color(0xFFF0F2F8);
        final rankColor = rank == 0 ? const Color(0xFF7A5F00)
            : rank == 1 ? _c2 : rank == 2 ? _c2 : kTextMuted;
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(
              color: rank < providers.length - 1
                  ? _c4 : Colors.transparent))),
          child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(width: 24, height: 24,
                decoration: BoxDecoration(color: rankBg, shape: BoxShape.circle),
                child: Center(child: Text('${rank + 1}', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w900, color: rankColor)))),
              const SizedBox(width: 8),
              UserAvatar(name, 36),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700, color: _c1),
                    overflow: TextOverflow.ellipsis),
                Row(children: [
                  Icon(catIcon(cat), size: 11, color: _c2),
                  const SizedBox(width: 4),
                  Text(cat, style: const TextStyle(fontSize: 10, color: _c2)),
                ]),
              ])),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: _c4,
                    borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  Text('${hours.toStringAsFixed(1)}h',
                      style: const TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w900, color: _c1)),
                  const Text('hrs', style: TextStyle(fontSize: 7, color: _c2)),
                ])),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: _c5.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _c5.withOpacity(0.4))),
                child: Column(children: [
                  Text(earned.toStringAsFixed(0), style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w900,
                      color: Color(0xFF7A5F00)),
                      overflow: TextOverflow.ellipsis),
                  const Text('EGP', style: TextStyle(
                      fontSize: 7, color: Color(0xFFB08A00))),
                ])),
            ]),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: pct, minHeight: 3,
                  backgroundColor: _c4,
                  valueColor: const AlwaysStoppedAnimation(_c3))),
          ]),
        );
      }),
      const SizedBox(height: 6),
    ]);
  }
}

// ── No data ────────────────────────────────────────────────
class _NoData extends StatelessWidget {
  final String msg;
  const _NoData({this.msg = 'No data yet'});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(msg, style: const TextStyle(color: _c2, fontSize: 12))));
}