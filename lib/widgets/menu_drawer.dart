import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:untitled13/screens/admin/permissions_screen.dart';
import 'package:untitled13/screens/admin/roles_screen.dart';
import 'package:untitled13/screens/admin/teams_screen.dart';
import 'dart:io';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/authscreen/login_screen.dart';
import '../screens/common/dashboard_screen.dart';
import '../screens/common/profile_screen.dart';
import '../screens/common/ticket_screen.dart';
import '../screens/admin/user_management_screen.dart';

class MenuDrawer extends StatefulWidget {
  final String currentRoute;

  const MenuDrawer({super.key, required this.currentRoute});

  @override
  State<MenuDrawer> createState() => _MenuDrawerState();
}

class _MenuDrawerState extends State<MenuDrawer> {
  String _roleName = "User";
  final String _baseUrl = "https://ticketapi.dcstechnosis.com";

  String _fullName = "Divyanshi Gandoriya";
  String _initials = "U";
  String? _profileImageUrl;

  // 🔥 STRICT PERMISSIONS FLAGS BASED ON MODULE ARRAY
  bool _canViewTickets = false;
  bool _canViewUsers = false;
  bool _canViewTeams = false;
  bool _canViewRoles = false;
  bool _canViewPermissions = false;

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
        String name = (userData['name'] ?? 'Divyanshi Gandoriya').trim();

        // 🔥 ROLE EXTRACTION
        String roleName = "User";

        if (userData['roleId'] != null && userData['roleId'] is Map) {
          roleName = userData['roleId']['name'] ?? roleName;
        } else if (userData['role'] != null && userData['role'] is Map) {
          roleName = userData['role']['name'] ?? roleName;
        } else if (userData['role'] is String) {
          roleName = userData['role'];
        } else if (userData['roles'] != null && userData['roles'] is List && userData['roles'].isNotEmpty) {
          var firstRole = userData['roles'][0];
          if (firstRole is String) {
            roleName = firstRole;
          } else if (firstRole is Map) {
            roleName = firstRole['name'] ?? roleName;
          }
        }

        if (mounted) {
          setState(() {
            _fullName = name;
            _roleName = roleName.toUpperCase();
            _profileImageUrl = userData['profileImage'] ?? userData['avatarUrl'] ?? userData['avatar'];

            // initials logic
            List<String> nameParts = name.split(RegExp(r'\s+'));
            if (nameParts.length == 1 && nameParts[0].isNotEmpty) {
              _initials = nameParts[0][0].toUpperCase();
            } else if (nameParts.length >= 2) {
              _initials = "${nameParts.first[0]}${nameParts.last[0]}".toUpperCase();
            }

            // permissions logic
            _canViewTickets = false;
            _canViewUsers = false;
            _canViewTeams = false;
            _canViewRoles = false;
            _canViewPermissions = false;

            if (userData['permissions'] != null && userData['permissions'] is List) {
              for (var perm in userData['permissions']) {
                String res = perm['resource']?.toString().toLowerCase().trim() ?? '';
                String act = perm['action']?.toString().toLowerCase().trim() ?? '';

                bool isViewAccess = (act == 'view' || act == 'view_all' || act == 'view_own');

                if (isViewAccess) {
                  if (res == 'ticket') _canViewTickets = true;
                  if (res == 'user') _canViewUsers = true;
                  if (res == 'team') _canViewTeams = true;
                  if (res == 'role') _canViewRoles = true;
                  if (res == 'permission') _canViewPermissions = true;
                }
              }
            }
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
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.logout, color: Colors.red),
          SizedBox(width: 8),
          Text("Logout", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))
        ]),
        content: Text("Are you sure you want to log out?", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
            },
            child: const Text("Yes, Logout", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 🔥 RESTORED TICKETDESK COLORS
  Widget _buildMenuItem(String title, IconData iconOutlined, IconData iconSolid, String route, VoidCallback onTap, bool isDark) {
    bool isActive = widget.currentRoute == route;
    final activeTextColor = const Color(0xFFB48600); // TicketDesk Yellow/Brown
    final inactiveTextColor = isDark ? Colors.white : Colors.black87;
    final activeBg = isDark ? const Color(0xFFF3C300).withOpacity(0.15) : const Color(0xFFF3C300).withOpacity(0.1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          if (!isActive) onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(isActive ? iconSolid : iconOutlined, size: 22, color: isActive ? activeTextColor : (isDark ? Colors.white54 : Colors.grey.shade500)),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? activeTextColor : inactiveTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔥 RESTORED TICKETDESK STYLING
  Widget _buildSectionLabel(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8, top: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white54 : Colors.grey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasManagementAccess = _canViewUsers || _canViewTeams;
    bool hasAccessControlAccess = _canViewRoles || _canViewPermissions;

    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;

    // 🔥 TICKETDESK HEADER NAVY BLUE COLOR RESTORED
    final headerBgColor = isDark ? const Color(0xFF121212) : const Color(0xFF1E293B);

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: 300,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            margin: EdgeInsets.only(
                top: Platform.isAndroid ? 10 : 50,
                bottom: 20,
                right: 10,
                left: 10
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔥 HEADER SECTION (TicketDesk Colors Restored)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  decoration: BoxDecoration(
                    color: headerBgColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF3C300), // TicketDesk Yellow
                        ),
                        child: CircleAvatar(
                          backgroundColor: Colors.transparent,
                          backgroundImage: (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                              ? NetworkImage(_getSafeImageUrl(_profileImageUrl!))
                              : null,
                          child: (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                              ? Text(_initials, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18))
                              : null,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_fullName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(_roleName, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),

                // SCROLLABLE MENU BODY
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),

                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSectionLabel("MAIN", isDark),
                        _buildMenuItem("Dashboard", Icons.dashboard_outlined, Icons.dashboard_rounded, "dashboard", () {
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
                        }, isDark),
                        if (_canViewTickets)
                          _buildMenuItem("Tickets", Icons.confirmation_number_outlined, Icons.confirmation_number, "tickets", () {
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TicketsScreen()));
                          }, isDark),

                        if (hasManagementAccess) ...[
                          const SizedBox(height: 10),
                          _buildSectionLabel("MANAGEMENT", isDark),
                          if (_canViewUsers)
                            _buildMenuItem("Users", Icons.people_outline, Icons.people, "users", () {
                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserManagementScreen()));
                            }, isDark),
                          if (_canViewTeams)
                            _buildMenuItem("Teams", Icons.group_work_outlined, Icons.group_work, "teams", () {
                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TeamsScreen()));
                            }, isDark),
                        ],

                        if (hasAccessControlAccess) ...[
                          const SizedBox(height: 10),
                          _buildSectionLabel("ACCESS CONTROL", isDark),
                          if (_canViewRoles)
                            _buildMenuItem("Roles", Icons.shield_outlined, Icons.shield, "roles", () {
                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const RolesScreen()));
                            }, isDark),
                          if (_canViewPermissions)
                            _buildMenuItem("Permissions", Icons.vpn_key_outlined, Icons.vpn_key, "permissions", () {
                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PermissionsScreen()));
                            }, isDark),
                        ],

                        const SizedBox(height: 10),
                        _buildSectionLabel("SETTINGS", isDark),
                        _buildMenuItem("My Profile", Icons.person_outline, Icons.person, "profile", () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                        }, isDark),
                      ],
                    ),
                  ),
                ),

                // FOOTER SECTION
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: borderColor)),
                  ),
                  child: InkWell(
                    onTap: () => _showLogoutDialog(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                          SizedBox(width: 8),
                          Text("Log Out", style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w800, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}