import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:untitled13/screens/admin/permissions_screen.dart';
import 'package:untitled13/screens/admin/roles_screen.dart';
import 'package:untitled13/screens/admin/teams_screen.dart';

import '../providers/auth_provider.dart';
import '../screens/authscreen/login_screen.dart';
import '../screens/common/dashboard_screen.dart';
import '../screens/common/profile_screen.dart';
import '../screens/common/ticket_screen.dart'; // Make sure this path is correct!
import '../screens/admin/user_management_screen.dart'; // Make sure this path is correct!

class MenuDrawer extends StatefulWidget {
  final String currentRoute;

  const MenuDrawer({super.key, required this.currentRoute});

  @override
  State<MenuDrawer> createState() => _MenuDrawerState();
}

class _MenuDrawerState extends State<MenuDrawer> {
  final String _baseUrl = "https://ticketapi.dcstechnosis.com";

  String _fullName = "User";
  String _initials = "U";
  String? _profileImageUrl;

  // 🔥 GLOBAL PERMISSIONS STATE
  bool _isAdmin = false;
  bool _canViewTickets = false;
  bool _canManageUsers = false;
  bool _canManageTeams = false;
  bool _canManageRoles = false;
  bool _canManagePermissions = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      const storage = FlutterSecureStorage();
      String? userDataString = await storage.read(key: "user_data");

      if (userDataString != null) {
        final userData = jsonDecode(userDataString);
        String name = (userData['name'] ?? 'User').trim();

        if (mounted) {
          setState(() {
            _fullName = name;
            _profileImageUrl = userData['profileImage'];

            List<String> nameParts = name.split(RegExp(r'\s+'));
            if (nameParts.length == 1) {
              _initials = nameParts[0][0].toUpperCase();
            } else if (nameParts.length >= 2) {
              _initials =
                  "${nameParts.first[0]}${nameParts.last[0]}".toUpperCase();
            }

            // 🔥 PARSE PERMISSIONS TO BUILD MENU
            _isAdmin = userData['role'] == 'admin';

            // If admin, everything is true. If user, strictly check their specific permissions
            _canViewTickets = _isAdmin || (userData['canViewTicket'] == true);
            _canManageUsers = _isAdmin || (userData['canManageUsers'] == true);
            _canManageTeams = _isAdmin || (userData['canManageTeams'] == true);
            _canManageRoles = _isAdmin || (userData['canManageRoles'] == true);
            _canManagePermissions =
                _isAdmin || (userData['canManagePermissions'] == true);
          });
        }
      }
    } catch (e) {
      debugPrint("Drawer Profile Load Error: $e");
    }
  }

  String _getSafeImageUrl(String path) {
    if (path.startsWith('http')) return path;
    String cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return "$_baseUrl/$cleanPath";
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.logout, color: Colors.red),
          SizedBox(width: 8),
          Text("Logout")
        ]),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false);
            },
            child: const Text("Yes, Logout"),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
      String title, IconData icon, String route, VoidCallback onTap) {
    bool isActive = widget.currentRoute == route;

    return Container(
      color: isActive
          ? const Color(0xFFF3C300).withOpacity(0.1)
          : Colors.transparent,
      child: ListTile(
        leading: Icon(icon,
            color: isActive ? const Color(0xFFB48600) : Colors.grey.shade500),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? const Color(0xFFB48600) : Colors.black87,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        onTap: () {
          Navigator.pop(context); // Close drawer
          if (!isActive) onTap();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasManagementAccess = _canManageUsers || _canManageTeams;
    bool hasAccessControlAccess = _canManageRoles || _canManagePermissions;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1E293B)),
            accountName: Text(_fullName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: const Text("My Workspace"),
            currentAccountPicture: CircleAvatar(
              backgroundColor: const Color(0xFFF3C300),
              backgroundImage:
                  (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                      ? NetworkImage(_getSafeImageUrl(_profileImageUrl!))
                      : null,
              child: (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                  ? Text(_initials,
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 24))
                  : null,
            ),
          ),

          // 🔥 1. ALWAYS VISIBLE
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text("MAIN",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
          ),
          _buildMenuItem("Dashboard", Icons.dashboard_rounded, "dashboard", () {
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const DashboardScreen()));
          }),

          // 🔥 2. TICKETS (Permission Gated)
          if (_canViewTickets)
            _buildMenuItem(
                "Tickets", Icons.confirmation_number_outlined, "tickets", () {
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const TicketsScreen()));
            }),

          // 🔥 3. MANAGEMENT SECTION (Permission Gated)
          if (hasManagementAccess)
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
              child: Text("MANAGEMENT",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
            ),
          if (_canManageUsers)
            _buildMenuItem("Users", Icons.people_outline, "users", () {
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const UserManagementScreen()));
            }),
          if (_canManageTeams)
            _buildMenuItem("Teams", Icons.group_work_outlined, "teams", () {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => TeamsScreen()));
            }),

          // 🔥 4. ACCESS CONTROL SECTION (Permission Gated)
          if (hasAccessControlAccess)
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
              child: Text("ACCESS CONTROL",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
            ),
          if (_canManageRoles)
            _buildMenuItem("Roles", Icons.badge_outlined, "roles", () {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => RolesScreen()));
            }),
          if (_canManagePermissions)
            _buildMenuItem("Permissions", Icons.vpn_key_outlined, "permissions",
                () {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => PermissionsScreen()));
            }),

          const Divider(height: 32),

          // 🔥 5. PROFILE & LOGOUT (Always Visible)
          _buildMenuItem("My Profile", Icons.person_outline, "profile", () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()));
          }),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout",
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () => _showLogoutDialog(context),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
