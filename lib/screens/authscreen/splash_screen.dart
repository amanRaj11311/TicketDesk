import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';
import '../common/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  void _checkUserStatus() async {
    // 1. Native splash (Yellow color) turant hata do kyunki Flutter ki screen aa gayi hai
    FlutterNativeSplash.remove();

    // 2. Token verify karo
    String? role = await _authService.verifyToken();

    // 3. User ko ye poster padhne ke liye 2.5 seconds ka time do
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;


    if (role != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3C300),
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        // 🔥 BoxFit.cover ensures ki aapki image screen ke hisaab se perfect fit ho bina stretch hue
        child: Image.asset(
          'assets/icons/Splash.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}