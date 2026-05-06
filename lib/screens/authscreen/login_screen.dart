import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart'; // 🔥 Imported to verify token
import '../../providers/auth_provider.dart';
import '../constants/api_constants.dart'; // 🔥 Imported for Base URL
import '../common/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isButtonTapped = false;

  bool _keepMeLoggedIn = true;
  bool _isCheckingSession = true;

  final Color primaryYellow = const Color(0xFFF3C300);
  final Color navyBlue = const Color(0xFF1E293B);
  final Color backgroundGray = const Color(0xFFF1F5F9);

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkSavedSession();
  }

  // 🔥 Auto-Login Logic with Token Validation
  // 🔥 Auto-Login Logic with Token Validation & Expiry Message
  Future<void> _checkSavedSession() async {
    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");
      String? isPersistent = await storage.read(key: "is_persistent");

      if (token != null && token.isNotEmpty) {
        if (isPersistent == "true" || isPersistent == null) {

          try {
            final String baseUrl = ApiConstants.baseUrl;
            // Hit a lightweight endpoint to check token validity
            await Dio().get(
                "$baseUrl/api/users/profile",
                options: Options(headers: {"Authorization": "Bearer $token"})
            );

            // If it succeeds, token is valid! Go to Dashboard.
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DashboardScreen()),
              );
              return;
            }
          } catch (e) {
            // 🔥 Token EXPIRED! Clear storage and SHOW ERROR MESSAGE
            debugPrint("Token Expired. Clearing old session.");
            await storage.delete(key: "jwt_token");
            await storage.delete(key: "user_data");

            // Show error message on Login Screen
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Session expired. Please log in again."),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 4),
                  )
              );
            }
          }

        } else {
          // Token exists but user unticked "Keep me logged in" previously -> Clear it
          await storage.delete(key: "jwt_token");
          await storage.delete(key: "user_data");
        }
      }
    } catch (e) {
      debugPrint("Session check error: $e");
    }

    // If no valid session or token expired, show Login UI
    if (mounted) {
      setState(() {
        _isCheckingSession = false;
      });
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)),
    );

    _buttonScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.5, 1.0, curve: Curves.elasticOut)),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter both email and password"), backgroundColor: Colors.orange),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);

    String? role = await auth.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (role != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login Successful!"), backgroundColor: Colors.green),
      );

      const storage = FlutterSecureStorage();
      await storage.write(key: "is_persistent", value: _keepMeLoggedIn ? "true" : "false");

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login Failed. Check your credentials or network."), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return Scaffold(
        backgroundColor: backgroundGray,
        body: Center(
          child: CircularProgressIndicator(color: primaryYellow),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundGray,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogoHeader(),
                    const SizedBox(height: 40),
                    _buildLoginCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: navyBlue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: navyBlue.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))
              ]),
          child: Icon(Icons.confirmation_number_outlined, size: 48, color: primaryYellow),
        ),
        const SizedBox(height: 16),
        Text(
          "TicketDesk",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: navyBlue, letterSpacing: 1.0),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Welcome back", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: navyBlue)),
          const SizedBox(height: 8),
          const Text("Sign in to your workspace.", style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
          const SizedBox(height: 32),

          const Text("EMAIL ADDRESS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _emailController,
            hintText: "name@company.com",
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),

          const SizedBox(height: 24),

          const Text("PASSWORD", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _passwordController,
            hintText: "••••••••",
            icon: Icons.lock_outline,
            isPassword: true,
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _keepMeLoggedIn,
                  activeColor: primaryYellow,
                  checkColor: navyBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                  onChanged: (val) {
                    setState(() {
                      _keepMeLoggedIn = val!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Text(
                  "Keep me logged in",
                  style: TextStyle(fontSize: 13, color: navyBlue, fontWeight: FontWeight.w600)
              ),
            ],
          ),

          const SizedBox(height: 32),

          _buildAnimatedLoginButton(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        keyboardType: keyboardType,
        style: TextStyle(color: navyBlue, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF94A3B8), size: 18),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          )
              : null,
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryYellow, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildAnimatedLoginButton() {
    return ScaleTransition(
      scale: _buttonScaleAnimation,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isButtonTapped = true),
        onTapUp: (_) {
          setState(() => _isButtonTapped = false);
          _handleLogin();
        },
        onTapCancel: () => setState(() => _isButtonTapped = false),
        child: AnimatedScale(
          scale: _isButtonTapped ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: primaryYellow,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: primaryYellow.withOpacity(_isButtonTapped ? 0.2 : 0.4),
                  blurRadius: _isButtonTapped ? 5 : 12,
                  offset: _isButtonTapped ? const Offset(0, 2) : const Offset(0, 5),
                ),
              ],
            ),
            child: Consumer<AuthProvider>(
              builder: (context, auth, child) {
                return auth.isLoading
                    ? const Center(
                    child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Color(0xFF1E293B), strokeWidth: 2.5)))
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Sign In", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20, color: Color(0xFF1E293B)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}