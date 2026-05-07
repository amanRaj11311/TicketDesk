import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../authscreen/login_screen.dart';
import '../../constants/api_constants.dart';
import '../../widgets/menu_drawer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String _baseUrl = ApiConstants.baseUrl;

  // Profile Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Password Controllers
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  File? _pickedImage;
  String? _serverImageUrl; // 🔥 Ye variable define kiya hai
  String _initials = "U";

  String? _passwordError;
  bool _isProfileLoading = false;
  bool _isPasswordLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchMyProfileLocally();
  }

  // 🔥 Read local user data to pre-fill the form and App Bar
  Future<void> _fetchMyProfileLocally() async {
    try {
      const storage = FlutterSecureStorage();
      String? userDataString = await storage.read(key: "user_data");

      if (userDataString != null) {
        final userData = jsonDecode(userDataString);
        String fullName = userData['name'] ?? '';

        setState(() {
          _nameController.text = fullName;
          _emailController.text = userData['email'] ?? '';
          _serverImageUrl = userData['avatarUrl'] ?? userData['profileImage'] ?? userData['avatar'];

          // Generate Initials for App Bar
          List<String> nameParts = fullName.trim().split(RegExp(r'\s+'));
          if (nameParts.length > 1 && nameParts[1].isNotEmpty) {
            _initials = nameParts[0][0].toUpperCase() + nameParts[1][0].toUpperCase();
          } else if (nameParts.isNotEmpty && nameParts[0].isNotEmpty) {
            _initials = nameParts[0][0].toUpperCase();
          } else {
            _initials = "U";
          }
        });
      }
    } catch (e) {
      debugPrint("Failed to load local profile: $e");
    }
  }

  // 🔥 Error Handler
  void _showError(String fallbackMsg, dynamic e) {
    String msg = fallbackMsg;
    if (e is DioException) {
      if (e.response?.data is String && e.response!.data.toString().contains("<!DOCTYPE html>")) {
        msg = "API Route Not Found (404). Check backend routes.";
      } else {
        try {
          msg = e.response?.data['message']?.toString() ?? e.response?.data?.toString() ?? fallbackMsg;
        } catch (_) {}
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, maxLines: 3), backgroundColor: Colors.red));
    }
  }

  // ====================================================================
  // 🔥 UPDATE PROFILE INFO (Exact Swagger Route: PATCH /users/profile)
  // ====================================================================
  Future<void> _updateProfileInfo() async {
    String email = _emailController.text.trim();

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]+$',
    );

    if (_nameController.text.trim().isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Name and Email cannot be empty"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

// 🔥 Email validation
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid email address"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isProfileLoading = true);

    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");

      dynamic payload;
      Options options;

      // 🔥 IMAGE IS OPTIONAL: If image is picked, send FormData. Otherwise, send strict JSON like Web.
      if (_pickedImage != null) {
        payload = FormData.fromMap({
          "name": _nameController.text.trim(),
          "email": _emailController.text.trim(),
          "avatar": await MultipartFile.fromFile(_pickedImage!.path, filename: "profile.jpg"),
        });
        options = Options(headers: {"Authorization": "Bearer $token"});
      } else {
        payload = jsonEncode({
          "name": _nameController.text.trim(),
          "email": _emailController.text.trim(),
        });
        options = Options(headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json"
        });
      }

      var response = await Dio().patch(
        "$_baseUrl/api/users/profile",
        data: payload,
        options: options,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated Successfully!"), backgroundColor: Colors.green));

      // Update Local Storage so the App Bar reflects the new name instantly
      String? userDataString = await storage.read(key: "user_data");
      if (userDataString != null) {
        Map<String, dynamic> userJson = jsonDecode(userDataString);
        userJson['name'] = _nameController.text.trim();
        userJson['email'] = _emailController.text.trim();

        if (response.data != null && response.data['data'] != null) {
          if (response.data['data']['avatarUrl'] != null) {
            userJson['avatarUrl'] = response.data['data']['avatarUrl'];
            _serverImageUrl = response.data['data']['avatarUrl'];
          }
        }
        await storage.write(key: "user_data", value: jsonEncode(userJson));
        _fetchMyProfileLocally(); // Refresh UI initials
      }
    } catch (e) {
      _showError("Profile update failed", e);
    } finally {
      setState(() => _isProfileLoading = false);
    }
  }

  // ====================================================================
  // 🔥 UPDATE PASSWORD (Exact Swagger Route: PATCH /users/password)
  // ====================================================================
  Future<void> _updatePassword() async {
    if (_currentPasswordController.text.isEmpty || _newPasswordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all password fields"), backgroundColor: Colors.orange));
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _passwordError = "Passwords do not match!");
      return;
    }

    setState(() => _isPasswordLoading = true);

    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");

      Options jsonOptions = Options(
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json"
          }
      );

      // Exact payload from your screenshot
      Map<String, dynamic> payload = {
        "currentPassword": _currentPasswordController.text,
        "newPassword": _newPasswordController.text
      };

      await Dio().patch(
        "$_baseUrl/api/users/password",
        data: jsonEncode(payload),
        options: jsonOptions,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password updated successfully!"), backgroundColor: Colors.green));

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() => _passwordError = null);

    } catch (e) {
      _showError("Password update failed", e);
    } finally {
      setState(() => _isPasswordLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _pickedImage = File(pickedFile.path));
    }
  }

  void _checkPasswordsMatch(String value) {
    setState(() {
      if (_confirmPasswordController.text.isNotEmpty && _newPasswordController.text != _confirmPasswordController.text) {
        _passwordError = "Passwords do not match!";
      } else {
        _passwordError = null;
      }
    });
  }

  // =========================================================================
  // 🔥 BUILD GLOBAL APP BAR WITH AVATAR & DARK MODE TOGGLE
  // =========================================================================
  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E293B),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: const Text("My Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      actions: [
        // IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white), onPressed: () {}),
        _buildAvatarMenu(),
      ],
    );
  }

  Widget _buildAvatarMenu() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // 🔥 FIX: Resolved the undefined _profileImageUrl by using the correct _serverImageUrl variable
    return PopupMenuButton<String>(
      onSelected: (val) {
        if (val == 'theme') themeProvider.toggleTheme();
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'theme',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [Icon(themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode, size: 20), const SizedBox(width: 10), const Text("Dark Mode")]),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(right: 12, left: 4),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFF3C300),
          backgroundImage: _serverImageUrl != null ? NetworkImage("$_baseUrl$_serverImageUrl") : null,
          child: _serverImageUrl == null ? Text(_initials, style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)) : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;

    ImageProvider? avatarImage;
    if (_pickedImage != null) {
      avatarImage = FileImage(_pickedImage!);
    } else if (_serverImageUrl != null && _serverImageUrl!.isNotEmpty) {
      String fullUrl = _serverImageUrl!.startsWith('http') ? _serverImageUrl! : "$_baseUrl$_serverImageUrl";
      avatarImage = NetworkImage(fullUrl);
    }

    return Scaffold(
      backgroundColor: bgColor,
      drawer: const MenuDrawer(currentRoute: "profile"),
      appBar: _buildModernAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AVATAR SECTION
            Center(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFF3C300), width: 3)),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFFF3C300).withOpacity(0.1),
                      backgroundImage: avatarImage,
                      child: avatarImage == null ? Text(_initials, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFB48600))) : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFF1E293B), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 🔥 CARD 1: PERSONAL INFORMATION
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 4, height: 20, decoration: BoxDecoration(color: const Color(0xFFF3C300), borderRadius: BorderRadius.circular(8)), margin: const EdgeInsets.only(right: 10)),
                      Text("Personal Information", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  LayoutBuilder(builder: (context, constraints) {
                    bool isMobile = constraints.maxWidth < 500;
                    return Flex(
                      direction: isMobile ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: isMobile ? 0 : 1, child: _buildTextField("FULL NAME", "Enter your full name", _nameController, isDark)),
                        if (!isMobile) const SizedBox(width: 16),
                        if (isMobile) const SizedBox(height: 16),
                        Expanded(flex: isMobile ? 0 : 1, child: _buildTextField("EMAIL ADDRESS", "Enter your email", _emailController, isDark, keyboardType: TextInputType.emailAddress)),
                      ],
                    );
                  }),

                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF3C300), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                      onPressed: _isProfileLoading ? null : _updateProfileInfo,
                      child: _isProfileLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : const Text("Save Changes", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 🔥 CARD 2: CHANGE PASSWORD
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 4, height: 20, decoration: BoxDecoration(color: const Color(0xFFF3C300), borderRadius: BorderRadius.circular(8)), margin: const EdgeInsets.only(right: 10)),
                      Text("Change Password", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildTextField("CURRENT PASSWORD", "Enter current password", _currentPasswordController, isDark, obscureText: true),
                  const SizedBox(height: 16),

                  LayoutBuilder(builder: (context, constraints) {
                    bool isMobile = constraints.maxWidth < 500;
                    return Flex(
                      direction: isMobile ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: isMobile ? 0 : 1, child: _buildTextField("NEW PASSWORD", "Enter new password", _newPasswordController, isDark, obscureText: true, onChanged: _checkPasswordsMatch)),
                        if (!isMobile) const SizedBox(width: 16),
                        if (isMobile) const SizedBox(height: 16),
                        Expanded(flex: isMobile ? 0 : 1, child: _buildTextField("CONFIRM NEW PASSWORD", "Confirm new password", _confirmPasswordController, isDark, obscureText: true, errorText: _passwordError, onChanged: _checkPasswordsMatch)),
                      ],
                    );
                  }),

                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF3C300), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                      onPressed: _isPasswordLoading ? null : _updatePassword,
                      child: _isPasswordLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : const Text("Update Password", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),

            // LOGOUT BUTTON
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  backgroundColor: Colors.red.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.red.withOpacity(0.3))),
                ),
                onPressed: () {
                  Provider.of<AuthProvider>(context, listen: false).logout();
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String hint, TextEditingController controller, bool isDark, {bool obscureText = false, String? errorText, Function(String)? onChanged, TextInputType? keyboardType}) {
    final fillColor = isDark ? const Color(0xFF121212) : Colors.grey.shade50;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          onChanged: onChanged,
          keyboardType: keyboardType,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) {

            // 🔥 Email validation only for email field
            if (label.toLowerCase().contains("email")) {

              if (value == null || value.trim().isEmpty) {
                return "Email is required";
              }

              final emailRegex = RegExp(
                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]+$',
              );

              if (!emailRegex.hasMatch(value.trim())) {
                return "Enter valid email";
              }
            }

            // 🔥 Password confirm validation
            if (label.toLowerCase().contains("confirm")) {
              if (value != _newPasswordController.text) {
                return "Passwords do not match";
              }
            }

            return null;
          },
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.white30 : Colors.grey.shade400,
              fontSize: 14,
            ),
            filled: true,
            fillColor: fillColor,
            errorText: errorText,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFFF3C300),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}