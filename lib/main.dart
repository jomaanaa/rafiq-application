import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth/login.dart';
import 'screens/onboarding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // final prefs = await SharedPreferences.getInstance();
  // final bool seenOnboarding = prefs.getBool('seen_onboarding') ?? false;
  final bool seenOnboarding = false; // always show onboarding for presentation

  runApp(RafiqApp(showOnboarding: !seenOnboarding));
}

class RafiqApp extends StatelessWidget {
  final bool showOnboarding;
  const RafiqApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: showOnboarding ? const OnboardingScreen() : const Login(),
    );
  }
}