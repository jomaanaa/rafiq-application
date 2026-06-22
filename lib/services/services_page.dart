import 'package:flutter/material.dart';
import 'doctor_selection.dart';
import 'caregiver_selection.dart';
import 'interpreter_selection.dart';
import 'package:rafiq/driver/request_driver_screen.dart';
import 'package:rafiq/auth/session_manager.dart';
import 'package:rafiq/driver/driver_api.dart';
import 'package:rafiq/driver/booking_status_screen.dart';

const Color _kBg      = Color(0xFFF6F8FD);
const Color _kDark    = Color(0xFF242742);
const Color _kPrimary = Color(0xFF4B4F83);
const Color _kAccent  = Color(0xFF6470D2);
const Color _kMuted   = Color(0xFF6B7188);
const Color _kLine    = Color(0xFFE8EBF5);
const Color _kSoft    = Color(0xFFF1F4FB);

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  static const _services = [
    _ServiceItem(title: 'Doctor',      desc: 'Physical therapy sessions.',        icon: Icons.medical_services_outlined),
    _ServiceItem(title: 'Caregiver',   desc: 'Daily assistance at home.',         icon: Icons.favorite_border_rounded),
    _ServiceItem(title: 'Driver',      desc: 'Wheelchair-friendly transport.',    icon: Icons.directions_car_outlined),
    _ServiceItem(title: 'Interpreter', desc: 'Real-time sign language support.',  icon: Icons.record_voice_over_outlined),
  ];

  Widget _targetFor(int i) {
    switch (i) {
      case 0: return const DoctorSelectionScreen();
      case 1: return const CaregiverSelectionScreen();
      case 3: return const InterpreterSelectionScreen();
      default: return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
          children: [
            _buildHero(),
            const SizedBox(height: 24),
            _buildSectionHead('Available Services'),
            const SizedBox(height: 12),
            ...List.generate(_services.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ServiceCard(
                item: _services[i],
                onTap: () async {
                  if (i == 2) {
                    int? patientId = await SessionManager.getUserId();
                    final user = await SessionManager.getUser();
                    debugPrint('Full session: $user');
                    debugPrint('patientId: $patientId');

                    if (patientId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Session error — please log in again')),
                      );
                      return;
                    }

                    final active = await DriverApi.getActiveBooking(patientId);
                    if (!context.mounted) return;

                    if (active != null && active['request_type'] == 'instant') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingStatusScreen(
                            bookingId: active['booking_id'] as int,
                            patientId: patientId,
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RequestDriverScreen(patientId: patientId),
                        ),
                      );
                    }
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => _targetFor(i)),
                    );
                  }
                },
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF20233C), Color(0xFF353B69), _kAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(color: _kDark.withOpacity(0.18), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.grid_view_rounded, size: 11, color: Colors.white),
                SizedBox(width: 6),
                Text('ALL SERVICES',
                    style: TextStyle(color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.w800, letterSpacing: 1.1)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('Our Services',
              style: TextStyle(color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -.4)),
          const SizedBox(height: 6),
          Text('How can we help you today?',
              style: TextStyle(color: Colors.white.withOpacity(0.75),
                  fontSize: 13, height: 1.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            children: [
              _heroStat('4', 'Services'),
              const SizedBox(width: 8),
              _heroStat('24/7', 'Available'),
              const SizedBox(width: 8),
              _heroStat('100%', 'Accessible'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 1),
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.65), letterSpacing: 0.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHead(String title) {
    return Text(title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
            color: _kDark, letterSpacing: -.3));
  }
}

class _ServiceCard extends StatelessWidget {
  final _ServiceItem item;
  final Future<void> Function() onTap;

  const _ServiceCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async => await onTap(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kLine),
          boxShadow: [
            BoxShadow(color: _kDark.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEDFE),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(item.icon, size: 24, color: _kPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(item.title,
                        style: const TextStyle(color: Color(0xFF353B69),
                            fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 5),
                  Text(item.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _kDark)),
                  const SizedBox(height: 3),
                  Text(item.desc,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: _kMuted, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF353B69), _kAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceItem {
  final String title, desc;
  final IconData icon;
  const _ServiceItem({required this.title, required this.desc, required this.icon});
}