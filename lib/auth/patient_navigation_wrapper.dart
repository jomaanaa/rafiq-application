import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:rafiq/auth/patient_homepage.dart';
import 'package:rafiq/auth/session_manager.dart';
import 'package:rafiq/services/services_page.dart';
import 'package:rafiq/services/accessibility_map.dart';
import 'package:rafiq/screens/patient_profile_screen.dart';

class PatientNavigationWrapper extends StatefulWidget {
  final String firstName;

  PatientNavigationWrapper({super.key, required this.firstName});

  @override
  State<PatientNavigationWrapper> createState() =>
      _PatientNavigationWrapperState();
}

class _PatientNavigationWrapperState
    extends State<PatientNavigationWrapper> {
  int _selectedIndex = 0;
  List<Widget> _pages = [];
  int _userId = 0;

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  Future<void> _loadPages() async {
    final session = await SessionManager.getUser();
    final id =
        int.tryParse(session?['user_id']?.toString() ?? '0') ?? 0;
    if (!mounted) return;
    setState(() {
      _userId = id;
      _pages = [
        PatientHomepage(firstName: widget.firstName),
        ServicesScreen(),
        AccessibilityMapScreen(),
        PatientProfileScreen(userId: _userId),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _pages.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF404066),
              ),
            )
          : IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
      bottomNavigationBar: _buildTexturedNavBar(),
    );
  }

  Widget _buildTexturedNavBar() {
    final Color primaryColor = const Color(0xFF2D2D5A);

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
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.home_rounded, 0, primaryColor),
                _navItem(Icons.grid_view_rounded, 1, primaryColor),
                _navItem(Icons.map_rounded, 2, primaryColor),
                _navItem(Icons.person_rounded, 3, primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, int index, Color activeColor) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          color: isSelected ? activeColor : Colors.grey.shade400,
          size: 26,
        ),
      ),
    );
  }
}