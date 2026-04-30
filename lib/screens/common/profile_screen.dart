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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final String _baseUrl = "https://ticketapi.dcstechnosis.com";

  File? _pickedImage;
  String? _serverImageUrl;
  String? _passwordError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchMyProfileLocally(); // 🔥 Call the new local fetcher!
  }

  // 🔥 NEW: Instantly reads the data saved during login
  Future<void> _fetchMyProfileLocally() async {
    try {
      const storage = FlutterSecureStorage();
      String? userDataString = await storage.read(key: "user_data");

      if (userDataString != null) {
        final userData = jsonDecode(userDataString);
        String fullName = userData['name'] ?? '';
        List<String> nameParts = fullName.trim().split(' ');

        setState(() {
          _firstNameController.text =
              nameParts.isNotEmpty ? nameParts.first : '';
          _lastNameController.text =
              nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
          _phoneController.text = userData['phone'] ?? '';
          _serverImageUrl = userData['profileImage'];
        });
      }
    } catch (e) {
      debugPrint("Failed to load local profile: $e");
    }
  }

  Future<void> _updateProfile() async {
    if (_passwordError != null) return;
    setState(() => _isLoading = true);

    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");
      String? userDataString = await storage.read(key: "user_data");
      String userId =
          userDataString != null ? jsonDecode(userDataString)['_id'] : '';

      FormData formData = FormData.fromMap({
        "name":
            "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}",
        "phone": _phoneController.text.trim(),
        if (_passwordController.text.isNotEmpty)
          "password": _passwordController.text,
        if (_pickedImage != null)
          "profileImage": await MultipartFile.fromFile(_pickedImage!.path,
              filename: "profile.jpg"),
      });

      // Update hitting the user endpoint since /auth/profile might also be missing!
      var response = await Dio().patch(
        "$_baseUrl/api/users/$userId",
        data: formData,
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Profile Updated! ✅"),
              backgroundColor: Colors.green),
        );
        _passwordController.clear();
        _confirmPasswordController.clear();

        // Also update the local storage with the new name!
        if (userDataString != null) {
          Map<String, dynamic> userJson = jsonDecode(userDataString);
          userJson['name'] =
              "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}";
          await storage.write(key: "user_data", value: jsonEncode(userJson));
        }
      }
    } catch (e) {
      debugPrint("Update error: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Update failed"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _pickedImage = File(pickedFile.path));
    }
  }

  void _checkPasswordsMatch(String value) {
    setState(() {
      if (_confirmPasswordController.text.isNotEmpty &&
          _passwordController.text != _confirmPasswordController.text) {
        _passwordError = "Passwords do not match!";
      } else {
        _passwordError = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC);
    final appBarColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final sectionColor = isDark ? Colors.white : const Color(0xFF334155);

    ImageProvider? avatarImage;
    if (_pickedImage != null) {
      avatarImage = FileImage(_pickedImage!);
    } else if (_serverImageUrl != null && _serverImageUrl!.isNotEmpty) {
      avatarImage = NetworkImage("$_baseUrl$_serverImageUrl");
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("My Profile",
            style: TextStyle(
                color: textColor, fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: appBarColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: const Color(0xFFF3C300), width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: const Color(0xFFF3C300).withOpacity(0.1),
                      backgroundImage: avatarImage,
                      child: avatarImage == null
                          ? const Icon(Icons.person,
                              size: 40, color: Color(0xFFB48600))
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2)),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text("PERSONAL DETAILS",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: sectionColor,
                    letterSpacing: 1.2)),
            const SizedBox(height: 12),
            _buildTextField("First Name", _firstNameController, isDark),
            const SizedBox(height: 12),
            _buildTextField("Last Name", _lastNameController, isDark),
            const SizedBox(height: 12),
            _buildTextField("Phone Number", _phoneController, isDark,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 24),
            Text("SECURITY",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: sectionColor,
                    letterSpacing: 1.2)),
            const SizedBox(height: 12),
            _buildTextField("New Password", _passwordController, isDark,
                obscureText: true, onChanged: _checkPasswordsMatch),
            const SizedBox(height: 12),
            _buildTextField(
                "Confirm Password", _confirmPasswordController, isDark,
                obscureText: true,
                errorText: _passwordError,
                onChanged: _checkPasswordsMatch),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF3C300),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isLoading ? null : _updateProfile,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2))
                    : const Text("Save Changes",
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Provider.of<AuthProvider>(context, listen: false).logout();
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                      (route) => false);
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text("Log Out",
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      String hint, TextEditingController controller, bool isDark,
      {bool obscureText = false,
      String? errorText,
      Function(String)? onChanged,
      TextInputType? keyboardType}) {
    final fillColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      keyboardType: keyboardType,
      style: TextStyle(
          color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        filled: true,
        fillColor: fillColor,
        errorText: errorText,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFF3C300), width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      ),
    );
  }
}
