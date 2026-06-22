// provider_navigation.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'caregiver_homepage.dart';
import 'package:rafiq/screens/sessions_screen.dart';
import 'package:rafiq/screens/earnings_screen.dart';
import 'interpreter_homepage.dart';
import 'driver_homepage.dart';
import 'doctor_homepage.dart';
import 'package:rafiq/screens/interpreter_profile_screen.dart';
import 'package:rafiq/screens/caregiver_profile_screen.dart';
import 'package:rafiq/screens/driver_profile_screen.dart';
import 'package:rafiq/screens/doctor_profile_screen.dart';
import 'package:rafiq/screens/interpreter_sessions_screen.dart';
import 'package:rafiq/screens/doctor_sessions_screen.dart';
import '../screens/driver_session_screen.dart';

class ProviderNavigation extends StatefulWidget {
  final String providerType;

  const ProviderNavigation({
    super.key,
    required this.providerType,
  });

  @override
  State<ProviderNavigation> createState() => _ProviderNavigationState();
}

class _ProviderNavigationState extends State<ProviderNavigation> {

  int _currentIndex = 0;
  late List<Widget> _pages;
  late List<IconData> _icons;
  late List<String> _labels;

  static const kPrimary = Color(0xFF2D2D5A);

  @override
  void initState() {
    super.initState();
    _buildPages();
  }

  void _buildPages() {
    // Icons and labels are the same for all provider types
    _icons = [
      Icons.home_rounded,
      Icons.calendar_month_rounded,
      Icons.attach_money_rounded,
      Icons.person_rounded,
    ];
    _labels = ['Home', 'Sessions', 'Earnings', 'Profile'];

    if (widget.providerType == 'caregiver') {
      _pages = [
        CaregiverHomepage(),
        SessionsScreen(),
        EarningsScreen(),
        CaregiverProfileScreen(),
      ];
    } else if (widget.providerType == 'interpreter') {
      _pages = [
        InterpreterHomepage(),
        InterpreterSessionsScreen(),
        EarningsScreen(),
        InterpreterProfileScreen(),
      ];
    } else if (widget.providerType == 'driver') {
      _pages = [
        DriverHomepage(),
        DriverSessionsScreen(),
        EarningsScreen(),
        DriverProfileScreen(),
      ];
    } else if (widget.providerType == 'doctor') {
      _pages = [
        DoctorHomepage(),
        DoctorSessionsScreen(),
        EarningsScreen(),
        DoctorProfileScreen(),
      ];
    } else {
      _pages  = [const Center(child: Text('Unknown provider'))];
      _icons  = [Icons.home_rounded];
      _labels = ['Home'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _pages[_currentIndex], 
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.6),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 25,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                _icons.length,
                (i) => _navItem(_icons[i], _labels[i], i),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? kPrimary.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          color: isSelected ? kPrimary : Colors.grey.shade400,
          size: 26,
        ),
      ),
    );
  }
}