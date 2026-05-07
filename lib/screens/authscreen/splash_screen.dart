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
      backgroundColor: const Color(0xFFFFF8E1),
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,

        child: Image.asset(
          'assets/icons/app_icon.png',
            fit: BoxFit.contain
        ),
      ),
    );
  }
}