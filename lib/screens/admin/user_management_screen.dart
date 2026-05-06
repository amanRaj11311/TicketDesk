import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:untitled13/widgets/menu_drawer.dart';

import '../../constants/api_constants.dart';
import '../../providers/theme_provider.dart';
import '../common/profile_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final String _baseUrl = ApiConstants.baseUrl;
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allUsers = [];
  List<dynamic> _filteredUsers = [];
  List<dynamic> _rolesList = [];
  bool _isLoading = true;

  // 🔥 PAGINATION VARIABLES
  int _currentPage = 1;
  bool _hasMoreData = true;
  bool _isFetchingMore = false;
  final ScrollController _scrollController = ScrollController();

  // 🔥 APP BAR USER PROFILE DATA
  String _firstName = "User";
  String _initials = "U";
  String? _profileImageUrl;

  // STRICT PERMISSION FLAGS
  bool _canCreateUser = false;
  bool _canUpdateUser = false;
  bool _canDeleteUser = false;

  @override
  void initState() {
    super.initState();
    // 🔥 Listen to Scroll to load more data
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100 &&
          !_isFetchingMore &&
          _hasMoreData) {
        _loadMoreUsers();
      }
    });
    _loadDataAndPermissions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDataAndPermissions() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMoreData = true;
      _allUsers.clear();
    });

    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");
      String? userDataString = await storage.read(key: "user_data");

      // 1. PARSE PERMISSIONS AND PROFILE DATA
      if (userDataString != null) {
        final userData = jsonDecode(userDataString);

        String fullName = userData['name'] ?? 'User';
        List<String> nameParts = fullName.trim().split(RegExp(r'\s+'));
        _firstName = nameParts.isNotEmpty ? nameParts.first : 'User';

        if (nameParts.length > 1 && nameParts[1].isNotEmpty) {
          _initials = nameParts[0][0].toUpperCase() + nameParts[1][0].toUpperCase();
        } else if (nameParts.isNotEmpty && nameParts[0].isNotEmpty) {
          _initials = nameParts[0][0].toUpperCase();
        } else {
          _initials = "U";
        }
        _profileImageUrl = userData['avatarUrl'] ?? userData['profileImage'] ?? userData['avatar'];

        _canCreateUser = false;
        _canUpdateUser = false;
        _canDeleteUser = false;

        if (userData['permissions'] != null && userData['permissions'] is List) {
          for (var perm in userData['permissions']) {
            String res = perm['resource']?.toString().toLowerCase().trim() ?? '';
            String act = perm['action']?.toString().toLowerCase().trim() ?? '';

            if (res == 'user') {
              if (act == 'create') _canCreateUser = true;
              if (act == 'update' || act == 'edit') _canUpdateUser = true;
              if (act == 'delete' || act == 'dlt') _canDeleteUser = true;
            }
          }
        }
      }

      // 2. FETCH DYNAMIC ROLES
      try {
        var roleResponse = await Dio().get(
          "$_baseUrl/api/roles",
          options: Options(headers: {"Authorization": "Bearer $token"}),
        );
        if (roleResponse.statusCode == 200) {
          var data = roleResponse.data;
          if (data is List) {
            _rolesList = data;
          } else if (data is Map) {
            _rolesList = data['data'] ?? data['roles'] ?? [];
          }
        }
      } catch (e) {
        debugPrint("Failed to fetch roles from API: $e");
      }

      // 3. FETCH USERS (PAGE 1)
      try {
        var userResponse = await Dio().get(
          "$_baseUrl/api/users?page=$_currentPage&limit=15", // 🔥 Pagination added here
          options: Options(headers: {"Authorization": "Bearer $token"}),
        );

        if (userResponse.data is List) {
          _allUsers = userResponse.data;
          _hasMoreData = false; // No meta, assume all fetched
        } else if (userResponse.data is Map) {
          _allUsers = userResponse.data['data'] ?? userResponse.data['users'] ?? [];
          // Check Meta for more pages
          if (userResponse.data['meta'] != null) {
            int totalPages = userResponse.data['meta']['pages'] ?? 1;
            _hasMoreData = _currentPage < totalPages;
          }
        }
      } catch (e) {
        debugPrint("Failed to fetch users from API: $e");
      }

      setState(() {
        _filteredUsers = _allUsers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Critical Error fetching data: $e");
    }
  }

  // 🔥 FETCH NEXT PAGE OF USERS
  Future<void> _loadMoreUsers() async {
    setState(() => _isFetchingMore = true);
    try {
      _currentPage++;
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");

      var userResponse = await Dio().get(
        "$_baseUrl/api/users?page=$_currentPage&limit=15",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      List<dynamic> newUsers = [];
      if (userResponse.data is List) {
        newUsers = userResponse.data;
        _hasMoreData = false;
      } else if (userResponse.data is Map) {
        newUsers = userResponse.data['data'] ?? userResponse.data['users'] ?? [];
        if (userResponse.data['meta'] != null) {
          int totalPages = userResponse.data['meta']['pages'] ?? 1;
          _hasMoreData = _currentPage < totalPages;
        } else {
          _hasMoreData = newUsers.isNotEmpty;
        }
      }

      setState(() {
        _allUsers.addAll(newUsers);
        _filterUsers(_searchController.text); // Re-apply search filter
        _isFetchingMore = false;
      });
    } catch (e) {
      setState(() => _isFetchingMore = false);
      debugPrint("Error loading more users: $e");
    }
  }

  void _filterUsers(String query) {
    setState(() {
      _filteredUsers = _allUsers.where((u) {
        final name = (u['name'] ?? '').toLowerCase();
        final email = (u['email'] ?? '').toLowerCase();
        return name.contains(query.toLowerCase()) || email.contains(query.toLowerCase());
      }).toList();
    });
  }

  String _extractRoleName(dynamic user) {
    if (user == null) return 'user';
    if (user['roleId'] != null && user['roleId'] is Map && user['roleId']['name'] != null) {
      return user['roleId']['name'].toString();
    }
    if (user['role'] != null && user['role'] is Map && user['role']['name'] != null) {
      return user['role']['name'].toString();
    }
    if (user['role'] != null && user['role'] is String) {
      return user['role'].toString();
    }
    if (user['roles'] != null && user['roles'] is List && user['roles'].isNotEmpty) {
      var firstRole = user['roles'][0];
      if (firstRole is String) return firstRole;
      if (firstRole is Map && firstRole['name'] != null) return firstRole['name'].toString();
    }
    return 'User';
  }

  String? _extractRoleId(dynamic user) {
    if (user == null) return null;
    if (user['roleId'] != null) {
      if (user['roleId'] is Map) return user['roleId']['_id']?.toString() ?? user['roleId']['id']?.toString();
      return user['roleId'].toString();
    }
    if (user['role'] != null) {
      if (user['role'] is Map) return user['role']['_id']?.toString() ?? user['role']['id']?.toString();
      return user['role'].toString();
    }
    if (user['roles'] != null && user['roles'] is List && user['roles'].isNotEmpty) {
      var firstRole = user['roles'][0];
      if (firstRole is Map) return firstRole['_id']?.toString() ?? firstRole['id']?.toString();
      if (firstRole is String) return firstRole;
    }
    return null;
  }

  int _allUsersWhereRole(String targetRoleStr) {
    return _allUsers.where((u) => _extractRoleName(u).toLowerCase().contains(targetRoleStr.toLowerCase())).length;
  }

  void _openCreateOrEditSheet({dynamic user}) {
    bool isNewUser = (user == null);
    String userId = isNewUser ? '' : (user['_id'] ?? user['id'] ?? '').toString();

    final nameCtrl = TextEditingController(text: isNewUser ? '' : user['name'] ?? '');
    final emailCtrl = TextEditingController(text: isNewUser ? '' : user['email'] ?? '');
    final phoneCtrl = TextEditingController(text: isNewUser ? '' : user['phone'] ?? '');
    final passwordCtrl = TextEditingController();

    String? currentRoleId = _extractRoleId(user);
    String? selectedRoleId;

    List<String> availableRoleIds = _rolesList.map((r) => (r['_id'] ?? r['id']).toString()).toList();

    if (currentRoleId != null && availableRoleIds.contains(currentRoleId)) {
      selectedRoleId = currentRoleId;
    } else if (availableRoleIds.isNotEmpty) {
      selectedRoleId = availableRoleIds.first;
    }

    String rawStatus = isNewUser ? 'active' : (user['status'] ?? 'active').toString().toLowerCase();
    String selectedStatus = rawStatus == 'inactive' ? 'inactive' : 'active';

    bool isSubmitting = false;
    bool obscurePassword = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
        final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final inputColor = isDark ? const Color(0xFF121212) : Colors.grey.shade50;
        final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
        final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {

            Future<void> submitForm() async {
              if (nameCtrl.text.trim().isEmpty || selectedRoleId == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name & Role are required!"), backgroundColor: Colors.orange));
                return;
              }
              if (isNewUser && (emailCtrl.text.trim().isEmpty || passwordCtrl.text.isEmpty)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email & Password required for new user!"), backgroundColor: Colors.orange));
                return;
              }

              setModalState(() => isSubmitting = true);

              try {
                const storage = FlutterSecureStorage();
                String? token = await storage.read(key: "jwt_token");

                String roleNameToSend = 'user';
                try {
                  var matchedRole = _rolesList.firstWhere((r) => (r['_id'] ?? r['id']).toString() == selectedRoleId);
                  roleNameToSend = (matchedRole['name'] ?? 'user').toString().toLowerCase();
                } catch (_) {}

                Options requestOptions = Options(
                    headers: {
                      "Authorization": "Bearer $token",
                      "Content-Type": "application/json"
                    }
                );

                if (isNewUser) {
                  Map<String, dynamic> payload = {
                    "name": nameCtrl.text.trim(),
                    "email": emailCtrl.text.trim(),
                    "password": passwordCtrl.text,
                    "role": roleNameToSend,
                  };
                  if (phoneCtrl.text.trim().isNotEmpty) {
                    payload["phone"] = phoneCtrl.text.trim();
                  }

                  await Dio().post(
                      "$_baseUrl/api/users",
                      data: jsonEncode(payload),
                      options: requestOptions
                  );

                } else {
                  Map<String, dynamic> infoPayload = {
                    "name": nameCtrl.text.trim(),
                    "status": selectedStatus,
                    "roleIds": [selectedRoleId],
                    "role": selectedRoleId,
                  };

                  await Dio().patch(
                      "$_baseUrl/api/users/$userId",
                      data: jsonEncode(infoPayload),
                      options: requestOptions
                  );

                  if (passwordCtrl.text.isNotEmpty) {
                    Map<String, dynamic> passPayload = {
                      "newPassword": passwordCtrl.text,
                      "password": passwordCtrl.text
                    };

                    await Dio().patch(
                        "$_baseUrl/api/users/$userId/password",
                        data: jsonEncode(passPayload),
                        options: requestOptions
                    );
                  }
                }

                if (!context.mounted) return;

                Navigator.pop(context);
                _loadDataAndPermissions();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isNewUser ? "User Created Successfully!" : "User Updated Successfully!"), backgroundColor: Colors.green));

              } catch (e) {
                setModalState(() => isSubmitting = false);
                String errorMsg = "Failed to process request.";
                if (e is DioException && e.response != null) {
                  errorMsg = e.response?.data['message'] ?? e.response?.data.toString() ?? errorMsg;
                }
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $errorMsg"), backgroundColor: Colors.red));
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 50, height: 6, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                      Text(isNewUser ? "Create New User" : "Edit User", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 24),

                      _buildFormLabel("FULL NAME", isDark),
                      TextField(controller: nameCtrl, style: TextStyle(color: textColor), decoration: _buildInputDecoration("e.g. John Doe", Icons.person_outline, inputColor, borderColor, isDark)),
                      const SizedBox(height: 20),

                      if (isNewUser) ...[
                        _buildFormLabel("EMAIL ADDRESS", isDark),
                        TextField(controller: emailCtrl, style: TextStyle(color: textColor), keyboardType: TextInputType.emailAddress, decoration: _buildInputDecoration("name@company.com", Icons.email_outlined, inputColor, borderColor, isDark)),
                        const SizedBox(height: 20),

                        _buildFormLabel("PHONE NUMBER (Optional)", isDark),
                        TextField(controller: phoneCtrl, style: TextStyle(color: textColor), keyboardType: TextInputType.phone, decoration: _buildInputDecoration("+1 (555) 000-0000", Icons.phone_outlined, inputColor, borderColor, isDark)),
                        const SizedBox(height: 20),
                      ],

                      _buildFormLabel("ROLE", isDark),
                      DropdownButtonFormField<String?>(
                        value: selectedRoleId,
                        dropdownColor: bgColor,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                        decoration: _buildInputDecoration("", Icons.badge_outlined, inputColor, borderColor, isDark),
                        hint: Text(_rolesList.isEmpty ? "No Roles Found" : "Select Role", style: TextStyle(color: _rolesList.isEmpty ? Colors.red : (isDark ? Colors.white54 : Colors.grey.shade400))),
                        items: _rolesList.isEmpty
                            ? [const DropdownMenuItem<String?>(value: null, child: Text("No Roles Loaded", style: TextStyle(color: Colors.red)))]
                            : _rolesList.map((role) {
                          String rId = (role['_id'] ?? role['id'] ?? '').toString();
                          String rName = role['name']?.toString() ?? 'Unknown Role';
                          return DropdownMenuItem<String>(value: rId, child: Text(rName.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)));
                        }).toList(),
                        onChanged: (val) => setModalState(() => selectedRoleId = val),
                      ),
                      const SizedBox(height: 20),

                      _buildFormLabel(isNewUser ? "PASSWORD" : "NEW PASSWORD (Leave blank to keep unchanged)", isDark),
                      TextField(
                        controller: passwordCtrl,
                        obscureText: obscurePassword,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: isNewUser ? "••••••••" : "Leave blank to keep current password",
                          hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade400, fontWeight: FontWeight.w400, fontSize: 13),
                          filled: true, fillColor: inputColor,
                          prefixIcon: Icon(Icons.lock_outline, size: 20, color: isDark ? Colors.white54 : Colors.grey),
                          suffixIcon: IconButton(
                            icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, color: isDark ? Colors.white54 : Colors.grey, size: 18),
                            onPressed: () => setModalState(() => obscurePassword = !obscurePassword),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF3C300), width: 2)),
                        ),
                      ),

                      if (!isNewUser) ...[
                        const SizedBox(height: 20),
                        _buildFormLabel("STATUS", isDark),
                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          dropdownColor: bgColor,
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                          decoration: _buildInputDecoration("", Icons.toggle_on_outlined, inputColor, borderColor, isDark),
                          items: const [
                            DropdownMenuItem(value: 'active', child: Text("Active")),
                            DropdownMenuItem(value: 'inactive', child: Text("Inactive")),
                          ],
                          onChanged: (val) => setModalState(() => selectedStatus = val!),
                        ),
                      ],
                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity, height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: isDark ? const Color(0xFFF3C300) : const Color(0xFF1E293B), foregroundColor: isDark ? Colors.black : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                          onPressed: isSubmitting ? null : submitForm,
                          child: isSubmitting ? CircularProgressIndicator(color: isDark ? Colors.black : Colors.white) : Text(isNewUser ? "Create Account" : "Save Changes", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFormLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.grey.shade400 : Colors.grey, letterSpacing: 0.5)),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon, Color fillColor, Color borderColor, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade400, fontWeight: FontWeight.w400),
      filled: true, fillColor: fillColor,
      prefixIcon: Icon(icon, size: 20, color: isDark ? Colors.white54 : Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF3C300), width: 2)),
    );
  }

  Future<void> _deleteUser(String userId) async {
    if (userId.isEmpty) return;

    bool confirm = await showDialog(
      context: context,
      builder: (context) {
        final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text("Delete User", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
          content: Text("Are you sure you want to delete this user? This action cannot be undone.", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey, fontWeight: FontWeight.bold))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    ) ?? false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");

      await Dio().delete(
        "$_baseUrl/api/users/$userId",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User deleted successfully."), backgroundColor: Colors.green));
      _loadDataAndPermissions();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error deleting user"), backgroundColor: Colors.red));
    }
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E293B),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: const Text("Users", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      actions: [
        _buildAvatarMenu(),
      ],
    );
  }

  Widget _buildAvatarMenu() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return PopupMenuButton<String>(
      onSelected: (val) {
        if (val == 'profile') {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())).then((_) => _loadDataAndPermissions());
        }
        if (val == 'theme') themeProvider.toggleTheme();
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'profile', child: Row(children: [Icon(Icons.person_outline, size: 20), SizedBox(width: 10), Text("Profile")])),
        PopupMenuItem(
          value: 'theme',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode, size: 20), const SizedBox(width: 10), Text(themeProvider.isDarkMode ? "Light Mode" : "Dark Mode")]),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(right: 12, left: 4),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFF3C300),
          backgroundImage: _profileImageUrl != null ? NetworkImage("$_baseUrl$_profileImageUrl") : null,
          child: _profileImageUrl == null ? Text(_initials, style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)) : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white70 : Colors.grey.shade500;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;

    int totalUsers = _allUsers.length;
    int admins = _allUsersWhereRole('admin');
    int agents = _allUsersWhereRole('agent');
    int activeUsers = _allUsers.where((u) => (u['status'] ?? 'active').toString().toLowerCase() == 'active').length;

    return Scaffold(
      backgroundColor: bgColor,
      drawer: const MenuDrawer(currentRoute: "users"),
      appBar: _buildModernAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF3C300)))
          : RefreshIndicator(
        onRefresh: _loadDataAndPermissions,
        color: const Color(0xFF1E293B),
        child: SingleChildScrollView(
          controller: _scrollController, // 🔥 PAGINATION SCROLL CONTROLLER ADDED HERE
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(textColor, subTextColor),
              const SizedBox(height: 24),
              _buildKPIGrid(totalUsers, admins, agents, activeUsers, isDark),
              const SizedBox(height: 32),

              Container(
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterUsers,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: "Search users by name or email...",
                    hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade400, fontSize: 14),
                    prefixIcon: Icon(Icons.search, size: 20, color: isDark ? Colors.white54 : Colors.grey.shade400),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: borderColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: borderColor)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("All Users", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  Text("${_filteredUsers.length} records", style: TextStyle(color: subTextColor, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),

              if (_filteredUsers.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      children: [
                        Icon(Icons.group_off_outlined, size: 60, color: isDark ? Colors.white24 : Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text("No users found.", style: TextStyle(color: subTextColor, fontSize: 16, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredUsers.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildUserCard(_filteredUsers[index], isDark, cardColor, textColor, borderColor),
                ),

              // 🔥 LOADING INDICATOR FOR PAGINATION AT THE BOTTOM
              if (_isFetchingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFF3C300)),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor, Color subTextColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("User Management", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 4),
              Text("Manage your team members and their roles", style: TextStyle(color: subTextColor, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (_canCreateUser)
          ElevatedButton.icon(
            onPressed: () => _openCreateOrEditSheet(),
            icon: const Icon(Icons.add, size: 16, color: Colors.black),
            label: const Text("New User", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF3C300),
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
      ],
    );
  }

  Widget _buildKPIGrid(int total, int admins, int agents, int active, bool isDark) {
    return LayoutBuilder(builder: (context, constraints) {
      double width = constraints.maxWidth;
      double cardWidth = width > 800 ? (width - 48) / 4 : (width - 16) / 2;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildKPICard("Total Users", "$total", Icons.people_outline, Colors.orange, cardWidth, isDark),
          _buildKPICard("Admins", "$admins", Icons.admin_panel_settings_outlined, Colors.red, cardWidth, isDark),
          _buildKPICard("Agents", "$agents", Icons.support_agent_outlined, Colors.blue, cardWidth, isDark),
          _buildKPICard("Active", "$active", Icons.check_circle_outline, Colors.green, cardWidth, isDark),
        ],
      );
    });
  }

  Widget _buildKPICard(String title, String val, IconData icon, Color color, double width, bool isDark) {
    return Container(
      width: width,
      height: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade100), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(val, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 22, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(dynamic user, bool isDark, Color cardColor, Color textColor, Color borderColor) {
    String userId = (user['_id'] ?? user['id'] ?? '').toString();
    String name = user['name'] ?? 'Unknown';
    String email = user['email'] ?? 'No email available';
    String roleName = _extractRoleName(user);
    bool isActive = (user['status'] ?? 'active').toString().toLowerCase() == 'active';

    String initials = "U";
    if (name.trim().isNotEmpty) {
      List<String> parts = name.trim().split(' ').where((e) => e.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        String first = parts[0].isNotEmpty ? parts[0][0] : '';
        String second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
        initials = (first + second).toUpperCase();
      }
    }

    String joinedDate = "N/A";
    if (user['createdAt'] != null) {
      try {
        DateTime parsedDate = DateTime.parse(user['createdAt']);
        joinedDate = DateFormat('dd MMM yyyy').format(parsedDate);
      } catch (e) { }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 8, offset: const Offset(0, 2))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFFEF9C3),
                      radius: 20,
                      child: Text(initials, style: const TextStyle(color: Color(0xFFB48600), fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(email, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade500, fontSize: 12), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusIndicator(isActive, isDark),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildRolePill(roleName),
                Text("Joined: $joinedDate", style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade500, fontWeight: FontWeight.w500)),
              ],
            ),
          ),

          if (_canUpdateUser || _canDeleteUser) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: borderColor),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_canUpdateUser)
                  OutlinedButton.icon(
                    onPressed: () => _openCreateOrEditSheet(user: user),
                    icon: Icon(Icons.edit_outlined, size: 12, color: Colors.orange.shade700),
                    label: Text("Edit", style: TextStyle(color: Colors.orange.shade700, fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: BorderSide(color: Colors.orange.shade200),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap
                    ),
                  ),
                if (_canUpdateUser && _canDeleteUser) const SizedBox(width: 8),
                if (_canDeleteUser)
                  OutlinedButton.icon(
                    onPressed: () => _deleteUser(userId),
                    icon: Icon(Icons.delete_outline, size: 12, color: Colors.red.shade600),
                    label: Text("Delete", style: TextStyle(color: Colors.red.shade600, fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: BorderSide(color: Colors.red.shade200),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap
                    ),
                  ),
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildRolePill(String role) {
    Color color; Color bgColor;
    String r = role.toLowerCase();

    if (r.contains('admin') || r.contains('super')) {
      color = Colors.red.shade700; bgColor = Colors.red.shade50;
    } else if (r.contains('agent') || r.contains('manager')) {
      color = Colors.blue.shade700; bgColor = Colors.blue.shade50;
    } else {
      color = Colors.grey.shade700; bgColor = Colors.grey.shade100;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.2))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.security, size: 10, color: color),
          const SizedBox(width: 4),
          Text(role.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(bool isActive, bool isDark) {
    Color color = isActive ? Colors.green.shade600 : Colors.grey.shade500;
    Color bgColor = isActive ? Colors.green.shade50 : (isDark ? Colors.white10 : Colors.grey.shade100);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(isActive ? "Active" : "Inactive", style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}