import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final String _baseUrl = "https://ticketapi.dcstechnosis.com";

  // Theme Colors
  final Color primaryYellow = const Color(0xFFF3C300);
  final Color navyBlue = const Color(0xFF1E293B);
  final Color backgroundGray = const Color(0xFFF1F5F9);

  String _selectedRole = 'user';
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");

      // Build payload dynamically
      Map<String, dynamic> payload = {
        "name": _nameController.text.trim(),
        "email": _emailController.text.trim(),
        "password": _passwordController.text,
        "role": _selectedRole,
      };

      // Only send phone if they typed one in
      if (_phoneController.text.trim().isNotEmpty) {
        payload["phone"] = _phoneController.text.trim();
      }

      var response = await Dio().post(
        "$_baseUrl/api/users",
        data: payload,
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("User Created Successfully! ✅"),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      String errorMsg = "Failed to create user";
      if (e is DioException) {
        errorMsg = e.response?.data['message'] ?? errorMsg;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGray,
      appBar: AppBar(
        backgroundColor: navyBlue,
        title: const Text("Create New User",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryYellow))
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Floating White Card
                    Container(
                      padding: const EdgeInsets.all(32.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: primaryYellow.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.person_add_alt_1,
                                    color: navyBlue, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Account Details",
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: navyBlue)),
                                    const Text(
                                        "Register a new workspace member",
                                        style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          const Divider(
                              color: Color(0xFFF1F5F9),
                              thickness: 2,
                              height: 0),
                          const SizedBox(height: 32),
                          _buildInputLabel("FULL NAME"),
                          _buildTextField(_nameController, Icons.person_outline,
                              hint: "e.g. John Doe"),
                          const SizedBox(height: 24),
                          _buildInputLabel("EMAIL ADDRESS"),
                          _buildTextField(
                              _emailController, Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              hint: "name@company.com"),
                          const SizedBox(height: 24),
                          _buildInputLabel("PHONE NUMBER (Optional)"),
                          _buildTextField(
                              _phoneController, Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              isRequired: false,
                              hint: "+1 (555) 000-0000"),
                          const SizedBox(height: 24),
                          _buildInputLabel("ASSIGN ROLE"),
                          _buildRoleDropdown(),
                          const SizedBox(height: 24),
                          _buildInputLabel("PASSWORD"),
                          _buildPasswordField(),
                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryYellow,
                                foregroundColor: navyBlue,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 5,
                                shadowColor: primaryYellow.withOpacity(0.4),
                              ),
                              onPressed: _createUser,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline, size: 20),
                                  SizedBox(width: 8),
                                  Text("Create Account",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          letterSpacing: 0.5)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // --- REUSABLE WIDGETS ---

  Widget _buildInputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, IconData icon,
      {TextInputType? keyboardType, bool isRequired = true, String? hint}) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(
            color: navyBlue, fontWeight: FontWeight.w600, fontSize: 14),
        validator: (value) {
          if (isRequired && (value == null || value.trim().isEmpty)) {
            return "This field is required";
          }
          return null;
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
              fontWeight: FontWeight.normal),
          prefixIcon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryYellow, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: backgroundGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: TextStyle(
            color: navyBlue, fontWeight: FontWeight.w600, fontSize: 14),
        validator: (value) => value == null || value.length < 6
            ? "Minimum 6 characters required"
            : null,
        decoration: InputDecoration(
          hintText: "••••••••",
          hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
              fontWeight: FontWeight.normal),
          prefixIcon: const Icon(Icons.lock_outline,
              size: 20, color: Color(0xFF94A3B8)),
          suffixIcon: IconButton(
            icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                size: 18,
                color: const Color(0xFF94A3B8)),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryYellow, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      height: 58, // Matches text field height
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: backgroundGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRole,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF94A3B8)),
          style: TextStyle(
              color: navyBlue, fontWeight: FontWeight.w600, fontSize: 14),
          // 🔥 ALL 3 ROLES ADDED HERE
          items: const [
            DropdownMenuItem(value: 'user', child: Text("User")),
            DropdownMenuItem(value: 'agent', child: Text("Agent")),
            DropdownMenuItem(value: 'admin', child: Text("Admin")),
          ],
          onChanged: (val) => setState(() => _selectedRole = val!),
        ),
      ),
    );
  }
}
