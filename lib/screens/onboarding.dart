import 'package:flutter/material.dart';
import 'package:rafiq/auth/login.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model for each onboarding page
// ─────────────────────────────────────────────────────────────────────────────
class _OnboardingPage {
  final String imagePath;
  final String title;
  final String subtitle;

  const _OnboardingPage({
    required this.imagePath,
    required this.title,
    required this.subtitle,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding Screen
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const Color primaryColor = Color(0xFF2D2D5A);
  static const Color bgColor      = Color(0xFFF8F9FE);

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      imagePath: 'assets/images/onboarding 1.png',
      title: 'Your indispensable\ndigital companion.',
      subtitle:
          'Rafiq helps users navigate their day with ease, offering support and '
          'tools to make life more independent and accessible.',
    ),
    _OnboardingPage(
      imagePath: 'assets/images/onboarding 2.png',
      title: 'Your indispensable\ndigital companion.',
      subtitle:
          'Rafiq helps users navigate their day with ease, offering support and '
          'tools to make life more independent and accessible.',
    ),
    _OnboardingPage(
      imagePath: 'assets/images/onboarding 3.png',
      title: 'Your indispensable\ndigital companion.',
      subtitle:
          'Rafiq helps users navigate their day with ease, offering support and '
          'tools to make life more independent and accessible.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _goToAuth();
    }
  }

  void _skip() => _goToAuth();

  void _goToAuth() async {
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.setBool('seen_onboarding', true); // commented out for presentation

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Login()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) => _buildPage(_pages[i]),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),

          // Logo image asset
          _buildLogo(),

          const SizedBox(height: 8),

          // Tagline
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: primaryColor,
              height: 1.25,
            ),
          ),

          const SizedBox(height: 12),

          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: primaryColor.withOpacity(0.55),
              height: 1.55,
            ),
          ),

          const SizedBox(height: 32),

          // Illustration
          Expanded(
            child: Image.asset(
              page.imagePath,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _placeholderIllustration(),
            ),
          ),

          const SizedBox(height: 24),

          // Dot indicators
          _buildDots(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/logo.png',
      height: 60,
      fit: BoxFit.contain,
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (i) {
        final active = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width:  active ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? primaryColor : primaryColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Skip / Next row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _skip,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: primaryColor.withOpacity(0.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: _nextPage,
                child: const Text(
                  'Next',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Continue with email
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: _goToAuth,
              child: const Text(
                'Continue with email',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderIllustration() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, size: 72, color: primaryColor.withOpacity(0.15)),
          const SizedBox(height: 8),
          Text(
            'Add onboarding1/2/3.png\nto assets/images/',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: primaryColor.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}