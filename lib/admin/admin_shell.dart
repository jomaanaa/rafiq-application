// ============================================================
// lib/admin/admin_shell.dart
// ============================================================
import 'package:flutter/material.dart';
import '../auth/session_manager.dart';
import '../auth/login.dart';
import 'admin_helpers.dart';
import 'admin_overview_page.dart';
import 'dart:ui';
import 'admin_providers_page.dart';
import 'admin_patients_page.dart';
import 'admin_places_page.dart';
import 'admin_bookings_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _idx = 0;

  static const _pages = [
    AdminOverviewPage(),
    AdminProvidersPage(),
    AdminPatientsPage(),
    AdminPlacesPage(),
    AdminBookingsPage(),
  ];

  static const _tabs = [
    _Tab(Icons.grid_view_rounded,      Icons.grid_view_rounded,  'Overview'),
    _Tab(Icons.people_outline,         Icons.people_rounded,     'Providers'),
    _Tab(Icons.accessible_outlined,    Icons.accessible_rounded, 'Patients'),
    _Tab(Icons.place_outlined,         Icons.place_rounded,      'Places'),
    _Tab(Icons.receipt_long_outlined,  Icons.receipt_long,       'Bookings'),
  ];

  Future<void> _logout() async {
    final ok = await confirmDialog(context,
        title: 'Logout', message: 'Are you sure you want to logout?',
        confirmLabel: 'Logout', isDanger: true);
    if (ok != true) return;
    await SessionManager.logout();
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const Login()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
     appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 8),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFB9CEE6), // The obvious slate blue at the top
                Color(0xFFFFFFFF),      // Pure white at the bottom to match the pages perfectly
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent, // Let the gradient show through
            elevation: 0,
            scrolledUnderElevation: 0, 
            automaticallyImplyLeading: false,
            title: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Image.asset(
                'assets/images/logo.png',
                height: 42,
                errorBuilder: (_, __, ___) => const Text('♿',
                    style: TextStyle(fontSize: 20)),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 4),
                child: GestureDetector(
                  onTap: _logout,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D2D5A).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF2D2D5A).withOpacity(0.08)),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFF2D2D5A),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(index: _idx, children: _pages),
      bottomNavigationBar: _NavBar(
          index: _idx,
          tabs: _tabs,
          onTap: (i) => setState(() => _idx = i)),
    );
  }
}

class _Tab {
  final IconData icon, activeIcon;
  final String label;
  const _Tab(this.icon, this.activeIcon, this.label);
}
class _NavBar extends StatelessWidget {
  final int index;
  final List<_Tab> tabs;
  final ValueChanged<int> onTap;
  const _NavBar({required this.index, required this.tabs, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(tabs.length, (i) {
                  final isSelected = i == index;
                  return GestureDetector(
                    onTap: () => onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryColor.withOpacity(0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        isSelected ? tabs[i].activeIcon : tabs[i].icon,
                        color: isSelected ? primaryColor : Colors.grey.shade400,
                        size: 26,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}