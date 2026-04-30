import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:untitled13/widgets/menu_drawer.dart';
import 'create_user_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final String _baseUrl = "https://ticketapi.dcstechnosis.com";
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allUsers = [];
  List<dynamic> _filteredUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");

      var response = await Dio().get(
        "$_baseUrl/api/users",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      setState(() {
        if (response.data is List) {
          _allUsers = response.data;
        } else if (response.data is Map && response.data.containsKey('users')) {
          _allUsers = response.data['users'];
        } else if (response.data is Map && response.data.containsKey('data')) {
          _allUsers = response.data['data'];
        } else {
          _allUsers = [];
        }

        _filteredUsers = _allUsers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (e is DioException) {
        debugPrint(
            "Dio Error fetching users: ${e.response?.statusCode} - ${e.response?.data}");
      } else {
        debugPrint("Error fetching users: $e");
      }
    }
  }

  void _filterUsers(String query) {
    setState(() {
      _filteredUsers = _allUsers.where((u) {
        final name = (u['name'] ?? '').toLowerCase();
        final email = (u['email'] ?? '').toLowerCase();
        return name.contains(query.toLowerCase()) ||
            email.contains(query.toLowerCase());
      }).toList();
    });
  }

  // 🔥 AGGRESSIVE ROLE EXTRACTOR FIX
  String _extractRole(dynamic user) {
    if (user == null) return 'user';

    // Check if it's deeply nested like { roleId: { name: "admin" } }
    if (user['roleId'] != null &&
        user['roleId'] is Map &&
        user['roleId']['name'] != null) {
      return user['roleId']['name'].toString().toLowerCase();
    }
    // Check if it's nested in a 'role' object like { role: { name: "admin" } }
    if (user['role'] != null &&
        user['role'] is Map &&
        user['role']['name'] != null) {
      return user['role']['name'].toString().toLowerCase();
    }
    // Check if it's just a string { role: "admin" }
    if (user['role'] != null && user['role'] is String) {
      return user['role'].toString().toLowerCase();
    }

    // Check if there is an array of roles { roles: ["admin"] }
    if (user['roles'] != null &&
        user['roles'] is List &&
        user['roles'].isNotEmpty) {
      var firstRole = user['roles'][0];
      if (firstRole is String) return firstRole.toLowerCase();
      if (firstRole is Map && firstRole['name'] != null)
        return firstRole['name'].toString().toLowerCase();
    }

    return 'user';
  }

  int _allTicketsWhereRole(String targetRole) {
    return _allUsers
        .where((u) => _extractRole(u).contains(targetRole.toLowerCase()))
        .length;
  }

  // 🔥 EDIT DIALOG WITH NAME, ROLE, AND STATUS
  Future<void> _showEditUserDialog(dynamic user) async {
    String userId = (user['_id'] ?? user['id'] ?? '').toString();
    if (userId.isEmpty) return;

    // 🔥 Added the Name Controller back
    TextEditingController nameCtrl =
        TextEditingController(text: user['name'] ?? '');

    // Load existing role
    String rawRole = _extractRole(user);
    String selectedRole = 'user';
    if (rawRole.contains('admin'))
      selectedRole = 'admin';
    else if (rawRole.contains('agent')) selectedRole = 'agent';

    // Load existing status
    String rawStatus = (user['status'] ?? 'active').toString().toLowerCase();
    String selectedStatus = rawStatus == 'inactive' ? 'inactive' : 'active';

    bool confirm = await showDialog(
            context: context,
            builder: (context) {
              return StatefulBuilder(builder: (context, setDialogState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  contentPadding: const EdgeInsets.all(24),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Edit User",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context, false),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User Info Header
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blue.shade50,
                              child: Text(
                                user['name'] != null &&
                                        user['name'].toString().isNotEmpty
                                    ? user['name'][0].toUpperCase()
                                    : "U",
                                style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user['name'] ?? 'Unknown',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                      overflow: TextOverflow.ellipsis),
                                  Text(user['email'] ?? 'No email',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12),
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 🔥 ADDED FULL NAME FIELD
                        const Text("FULL NAME",
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.person_outline,
                                size: 18, color: Colors.grey),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: Color(0xFFF3C300), width: 2)),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Role Dropdown
                        const Text("ROLE",
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedRole,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down,
                                  color: Colors.grey),
                              items: const [
                                DropdownMenuItem(
                                    value: 'user', child: Text("User")),
                                DropdownMenuItem(
                                    value: 'agent', child: Text("Agent")),
                                DropdownMenuItem(
                                    value: 'admin', child: Text("Admin")),
                              ],
                              onChanged: (val) =>
                                  setDialogState(() => selectedRole = val!),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Status Dropdown
                        const Text("STATUS",
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedStatus,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down,
                                  color: Colors.grey),
                              items: const [
                                DropdownMenuItem(
                                    value: 'active', child: Text("Active")),
                                DropdownMenuItem(
                                    value: 'inactive', child: Text("Inactive")),
                              ],
                              onChanged: (val) =>
                                  setDialogState(() => selectedStatus = val!),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF3C300),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8))),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save,
                                    color: Colors.black87, size: 18),
                                SizedBox(width: 8),
                                Text("Save Changes",
                                    style: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              });
            }) ??
        false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");

      await Dio().patch(
        "$_baseUrl/api/users/$userId",
        // 🔥 Send Name alongside Role and Status
        data: {
          "name": nameCtrl.text.trim(),
          "role": selectedRole,
          "status": selectedStatus,
        },
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("User updated successfully!"),
          backgroundColor: Colors.green));
      _fetchUsers();
    } catch (e) {
      setState(() => _isLoading = false);
      if (e is DioException) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Backend Error: ${e.response?.data}"),
            backgroundColor: Colors.red));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error updating user: $e"),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteUser(String userId) async {
    if (userId.isEmpty) return;

    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text("Delete User")
            ]),
            content: const Text(
                "Are you sure you want to delete this user? This action cannot be undone."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel",
                      style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child:
                    const Text("Delete", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");

      await Dio().delete(
        "$_baseUrl/api/users/$userId",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("User deleted successfully."),
          backgroundColor: Colors.green));
      _fetchUsers();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error deleting user: $e"),
          backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalUsers = _allUsers.length;
    int admins = _allTicketsWhereRole('admin');
    int agents = _allTicketsWhereRole('agent');
    int activeUsers = _allUsers
        .where((u) =>
            (u['status'] ?? 'active').toString().toLowerCase() == 'active')
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const MenuDrawer(currentRoute: "users"),
      appBar: _buildModernAppBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF3C300)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildKPIGrid(totalUsers, admins, agents, activeUsers),
                  const SizedBox(height: 24),
                  _buildUsersTable(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Users",
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B))),
              const SizedBox(height: 4),
              Text("Manage team members and their access levels",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CreateUserScreen()))
              .then((_) => _fetchUsers()),
          icon: const Icon(Icons.person_add, size: 18, color: Colors.black),
          label: const Text("Add User",
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF3C300),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
        ),
      ],
    );
  }

  Widget _buildKPIGrid(int total, int admins, int agents, int active) {
    return LayoutBuilder(builder: (context, constraints) {
      double width = constraints.maxWidth;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildKPICard(
              "Total Users", "$total", Icons.people, Colors.orange, width),
          _buildKPICard("Admins", "$admins", Icons.admin_panel_settings,
              Colors.red, width),
          _buildKPICard(
              "Agents", "$agents", Icons.support_agent, Colors.blue, width),
          _buildKPICard("Active Users", "$active", Icons.check_circle,
              Colors.green, width),
        ],
      );
    });
  }

  Widget _buildKPICard(
      String title, String val, IconData icon, Color color, double width) {
    double cardWidth = (width - 16) / 2;
    if (width > 900) cardWidth = (width - 48) / 4;

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(val,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 24, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTable() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                      width: 4,
                      height: 16,
                      color: const Color(0xFFF3C300),
                      margin: const EdgeInsets.only(right: 8)),
                  const Text("All Users",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              Text("${_filteredUsers.length} members",
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 40,
            decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200)),
            child: TextField(
              controller: _searchController,
              onChanged: _filterUsers,
              decoration: const InputDecoration(
                hintText: "Search records...",
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(bottom: 10),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _headerCell("USER", 250),
                    _headerCell("ROLE", 120),
                    _headerCell("STATUS", 100),
                    _headerCell("JOINED", 120),
                    _headerCell("ACTIONS", 100),
                  ],
                ),
                const SizedBox(height: 12),
                if (_filteredUsers.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text("No users found."))
                else
                  ..._filteredUsers.map((u) => _buildUserRow(u)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _headerCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(text,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  Widget _buildUserRow(dynamic user) {
    String userId = (user['_id'] ?? user['id'] ?? '').toString();

    String name = user['name'] ?? 'Unknown';
    String email = user['email'] ?? '';

    String role = _extractRole(user);
    bool isActive =
        (user['status'] ?? 'active').toString().toLowerCase() == 'active';

    String initials = name.isNotEmpty
        ? "${name.split(' ')[0][0]}${name.split(' ').length > 1 ? name.split(' ')[1][0] : ''}"
            .toUpperCase()
        : "U";

    String joinedDate = "Unknown";
    if (user['createdAt'] != null) {
      try {
        DateTime parsedDate = DateTime.parse(user['createdAt']);
        joinedDate = DateFormat('dd MMM yyyy').format(parsedDate);
      } catch (e) {
        joinedDate = "Invalid Date";
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: Row(
        children: [
          SizedBox(
              width: 250,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    radius: 18,
                    child: Text(initials,
                        style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                        Text(email,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              )),
          SizedBox(
              width: 120,
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildRolePill(role))),
          SizedBox(
              width: 100,
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildStatusIndicator(isActive))),
          SizedBox(
              width: 120,
              child: Text(joinedDate,
                  style: const TextStyle(fontSize: 12, color: Colors.grey))),
          SizedBox(
              width: 100,
              child: Row(
                children: [
                  InkWell(
                    onTap: () => _showEditUserDialog(user),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.edit_outlined,
                            size: 18, color: Colors.blue)),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _deleteUser(userId),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.delete_outline,
                            size: 18, color: Colors.red)),
                  ),
                ],
              )),
        ],
      ),
    );
  }

  Widget _buildRolePill(String role) {
    Color color;
    IconData icon;
    if (role.contains('admin')) {
      color = Colors.red;
      icon = Icons.security;
    } else if (role.contains('agent')) {
      color = Colors.blue;
      icon = Icons.support_agent;
    } else {
      color = Colors.grey.shade700;
      icon = Icons.person;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(role.toUpperCase(),
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(bool isActive) {
    Color color = isActive ? Colors.green : Colors.grey;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 6),
        Text(isActive ? "Active" : "Inactive",
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E293B),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: const Text("TMS Admin",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}
