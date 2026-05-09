import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../../widgets/menu_drawer.dart';
import '../../constants/api_constants.dart';
import '../../providers/theme_provider.dart';
import '../common/profile_screen.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final String _baseUrl = ApiConstants.baseUrl;
  bool _isLoading = true;

  // Theme Colors
  final Color primaryYellow = const Color(0xFFF3C300);
  final Color navyBlue = const Color(0xFF1E293B);

  // APP BAR USER PROFILE DATA
  String _firstName = "User";
  String _initials = "U";
  String? _profileImageUrl;

  // Data
  List<dynamic> _roles = [];
  List<dynamic> _masterPermissions = [];

  // Selection State
  String? _selectedRoleId;
  Set<String> _originalRolePerms = {};
  Set<String> _currentRolePerms = {};

  // 🔥 EXPLICIT PERMISSION MAPPING (Exactly 29 Permissions)
  final Map<String, List<Map<String, String>>> _permissionModules = {
    "Ticket": [
      {"resource": "ticket", "action": "view", "label": "VIEW"},
      {"resource": "ticket", "action": "view_own", "label": "VIEW OWN"},
      {"resource": "ticket", "action": "create", "label": "CREATE"},
      {"resource": "ticket", "action": "update", "label": "UPDATE"},
      {"resource": "ticket", "action": "delete", "label": "DELETE"},
      {"resource": "ticket", "action": "assign", "label": "ASSIGN"},
      {"resource": "ticket", "action": "change_status", "label": "CHANGE STATUS"},
      {"resource": "ticket", "action": "change_priority", "label": "CHANGE PRIORITY"},
      {"resource": "ticket", "action": "close", "label": "CLOSE"},
      {"resource": "ticket", "action": "reopen", "label": "REOPEN"},
    ],
    "Comment": [
      {"resource": "comment", "action": "view", "label": "VIEW"},
      {"resource": "comment", "action": "create", "label": "CREATE"},
      {"resource": "comment", "action": "update", "label": "UPDATE"},
      {"resource": "comment", "action": "delete", "label": "DELETE"},
    ],
    "Team": [
      {"resource": "team", "action": "view", "label": "VIEW"},
      {"resource": "team", "action": "create", "label": "CREATE"},
      {"resource": "team", "action": "update", "label": "UPDATE"},
      {"resource": "team", "action": "delete", "label": "DELETE"},
    ],
    "User": [
      {"resource": "user", "action": "view", "label": "VIEW"},
      {"resource": "user", "action": "create", "label": "CREATE"},
      {"resource": "user", "action": "update", "label": "UPDATE"},
      {"resource": "user", "action": "delete", "label": "DELETE"},
      {"resource": "user", "action": "assign_role", "label": "ASSIGN ROLE"},
    ],
    "Role": [
      {"resource": "role", "action": "view", "label": "VIEW"},
      {"resource": "role", "action": "create", "label": "CREATE"},
      {"resource": "role", "action": "update", "label": "UPDATE"},
      {"resource": "role", "action": "delete", "label": "DELETE"},
    ],
    "Permission": [
      {"resource": "permission", "action": "view", "label": "VIEW"},
      {"resource": "permission", "action": "assign", "label": "ASSIGN"},
    ],
  };

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");
      String? userDataString = await storage.read(key: "user_data");

      // Set App Bar User Profile
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
        _profileImageUrl = userData['profileImage'] ?? userData['avatar'];
      }

      Options options = Options(headers: {"Authorization": "Bearer $token"});

      final responses = await Future.wait([
        Dio().get("$_baseUrl/api/roles", options: options),
        Dio().get("$_baseUrl/api/permissions", options: options).catchError((_) => Response(requestOptions: RequestOptions(path: ''), data: [])),
      ]);

      var roleRes = responses[0].data;
      var permRes = responses[1].data;

      if (roleRes is Map && roleRes.containsKey('data')) _roles = roleRes['data'];
      else if (roleRes is List) _roles = roleRes;

      if (permRes is Map && permRes.containsKey('data')) _masterPermissions = permRes['data'];
      else if (permRes is List) _masterPermissions = permRes;

      if (_masterPermissions.isEmpty) {
        _masterPermissions = _getFallbackPermissions();
      }

      // Ensure proper selection mapping
      if (_roles.isNotEmpty) {
        if (_selectedRoleId != null && _roles.any((r) => (r['_id'] ?? r['id']).toString() == _selectedRoleId)) {
          var roleToSelect = _roles.firstWhere((r) => (r['_id'] ?? r['id']).toString() == _selectedRoleId);
          _selectRole(roleToSelect);
        } else {
          _selectRole(_roles[0]);
        }
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (_masterPermissions.isEmpty) _masterPermissions = _getFallbackPermissions();
      if (mounted) setState(() => _isLoading = false);
      _showError("Failed to load permissions data", e);
    }
  }

  void _showError(String fallbackMsg, dynamic e) {
    String msg = fallbackMsg;
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        msg = data['message'] ?? data['error'] ?? fallbackMsg;
      } else if (data is String) {
        if (data.contains("<!DOCTYPE html>")) {
          msg = "API Route Not Found (404). Backend configuration error.";
        } else {
          msg = data;
        }
      } else {
        msg = e.message ?? fallbackMsg;
      }
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red.shade800));
  }

  Future<String> _getOrganizationId() async {
    const storage = FlutterSecureStorage();
    String? userDataString = await storage.read(key: "user_data");
    if (userDataString != null) {
      return (jsonDecode(userDataString)['organizationId'] ?? jsonDecode(userDataString)['organization'] ?? '').toString();
    }
    return '';
  }

  List<String> _extractPermissions(dynamic role) {
    if (role == null) return [];
    List<dynamic> permsList = role['permissionIds'] ?? role['permissions'] ?? [];
    return permsList.map((p) {
      if (p is Map) return (p['_id'] ?? p['id'] ?? '').toString();
      return p.toString();
    }).toList();
  }

  String? _resolvePermissionId(String resource, String action) {
    for (var p in _masterPermissions) {
      if (p['resource'] == resource && p['action'] == action) {
        return (p['_id'] ?? p['id']).toString();
      }
    }
    return null;
  }

  void _selectRole(dynamic role) {
    setState(() {
      _selectedRoleId = (role['_id'] ?? role['id']).toString();
      _originalRolePerms = _extractPermissions(role).toSet();
      _currentRolePerms = Set<String>.from(_originalRolePerms);
    });
  }

  bool _hasUnsavedChanges() {
    if (_originalRolePerms.length != _currentRolePerms.length) return true;
    return !_originalRolePerms.containsAll(_currentRolePerms);
  }

  void _toggleModuleRow(String moduleName) {
    setState(() {
      List<String> validIds = [];
      for (var p in _permissionModules[moduleName]!) {
        String? id = _resolvePermissionId(p['resource']!, p['action']!);
        if (id != null) validIds.add(id);
      }
      if (validIds.isEmpty) return;

      bool allChecked = validIds.every((id) => _currentRolePerms.contains(id));
      if (allChecked) {
        _currentRolePerms.removeAll(validIds);
      } else {
        _currentRolePerms.addAll(validIds);
      }
    });
  }

  Future<void> _savePermissions() async {
    if (_selectedRoleId == null || !_hasUnsavedChanges()) return;

    setState(() => _isLoading = true);
    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");
      String orgId = await _getOrganizationId();

      var role = _roles.firstWhere((r) => (r['_id'] ?? r['id']).toString() == _selectedRoleId);

      Options jsonOptions = Options(
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json"
          }
      );

      Map<String, dynamic> payload = {
        "name": role['name'],
        "description": role['description'] ?? "",
        "permissionIds": _currentRolePerms.toList(),
        "organizationId": orgId,
        "roleId": _selectedRoleId,
      };

      await Dio().put(
          "$_baseUrl/api/roles/update",
          data: jsonEncode(payload),
          options: jsonOptions
      );

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permissions saved successfully!"), backgroundColor: Colors.green));
      _fetchData();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showError("Error saving permissions", e);
    }
  }

  // =========================================================================
  // 🔥 APP BAR WITH AVATAR & DARK MODE
  // =========================================================================
  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: navyBlue,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: const Text("Permissions Mapping", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      actions: [
        // IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white), onPressed: () {}),
        _buildAvatarMenu(),
      ],
    );
  }

  Widget _buildAvatarMenu() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return PopupMenuButton<String>(
      onSelected: (val) {
        if (val == 'profile') Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())).then((_) => _fetchData());
        if (val == 'theme') themeProvider.toggleTheme();
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'profile', child: Row(children: [Icon(Icons.person_outline, size: 20), SizedBox(width: 10), Text("Profile")])),
        PopupMenuItem(
          enabled: false,
          child: StatefulBuilder(
            builder: (context, menuSetState) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        themeProvider.isDarkMode
                            ? Icons.dark_mode
                            : Icons.light_mode,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        themeProvider.isDarkMode
                            ? "Dark Mode"
                            : "Light Mode",
                      ),
                    ],
                  ),

                  Switch(
                    value: themeProvider.isDarkMode,
                    activeColor: primaryYellow,
                    onChanged: (value) {
                      themeProvider.toggleTheme();

                      menuSetState(() {});
                      setState(() {});
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(right: 12, left: 4),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: primaryYellow,
          backgroundImage: _profileImageUrl != null ? NetworkImage("$_baseUrl$_profileImageUrl") : null,
          child: _profileImageUrl == null ? Text(_initials, style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)) : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasChanges = _hasUnsavedChanges();
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : navyBlue;

    return Scaffold(
      backgroundColor: bgColor,
      drawer: const MenuDrawer(currentRoute: "permissions"),
      appBar: _buildModernAppBar(),
      bottomNavigationBar: hasChanges ? _buildBottomSaveBar(isDark) : null,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryYellow))
          : RefreshIndicator(
        onRefresh: _fetchData,
        color: navyBlue,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          children: [
            _buildHeader(textColor, isDark),
            const SizedBox(height: 24),
            _buildRoleSelector(isDark),
            const SizedBox(height: 24),
            _buildSummaryCard(),
            const SizedBox(height: 24),
            _buildMobilePermissionsCards(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Permissions", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 4),
          Text("Select a role to manage its access level", style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildRoleSelector(bool isDark) {
    final chipBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final unselectedTextColor = isDark ? Colors.white70 : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text("SELECT ROLE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, letterSpacing: 1.0)),
        ),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _roles.length,
            itemBuilder: (context, index) {
              var role = _roles[index];
              String rId = (role['_id'] ?? role['id']).toString();
              bool isSelected = rId == _selectedRoleId;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(role['name'] ?? 'Role', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? (isDark ? Colors.black : navyBlue) : unselectedTextColor)),
                  selected: isSelected,
                  selectedColor: primaryYellow,
                  backgroundColor: chipBgColor,
                  side: BorderSide(color: isSelected ? primaryYellow : (isDark ? Colors.white12 : Colors.grey.shade300)),
                  onSelected: (selected) {
                    if (selected) _selectRole(role);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 🔥 UPDATED LOGIC TO ONLY COUNT THE 29 PERMISSIONS IN THE UI
  Widget _buildSummaryCard() {
    if (_selectedRoleId == null) return const SizedBox.shrink();

    int totalVisiblePerms = 0;
    int grantedVisiblePerms = 0;

    for (var module in _permissionModules.values) {
      for (var p in module) {
        String? id = _resolvePermissionId(p['resource']!, p['action']!);
        if (id != null) {
          totalVisiblePerms++;
          if (_currentRolePerms.contains(id)) {
            grantedVisiblePerms++;
          }
        }
      }
    }

    int percentage = totalVisiblePerms == 0 ? 0 : ((grantedVisiblePerms / totalVisiblePerms) * 100).toInt();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: navyBlue,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: navyBlue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.analytics_outlined, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Access Granted", style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Text("$percentage% of total permissions", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Text("$grantedVisiblePerms/$totalVisiblePerms", style: TextStyle(color: primaryYellow, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildMobilePermissionsCards(bool isDark) {
    if (_selectedRoleId == null) return const SizedBox.shrink();

    final cardBgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final cardHeaderColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: _permissionModules.keys.map((moduleName) {

          List<String> validIds = [];
          for (var p in _permissionModules[moduleName]!) {
            String? id = _resolvePermissionId(p['resource']!, p['action']!);
            if (id != null) validIds.add(id);
          }

          if (validIds.isEmpty) return const SizedBox.shrink();
          bool allChecked = validIds.every((id) => _currentRolePerms.contains(id));

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: cardHeaderColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), border: Border(bottom: BorderSide(color: borderColor))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(moduleName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : navyBlue)),
                      InkWell(
                        onTap: () => _toggleModuleRow(moduleName),
                        child: Text(allChecked ? "Revoke All" : "Grant All", style: TextStyle(color: primaryYellow, fontSize: 13, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _permissionModules[moduleName]!.map((permConf) {
                      String? realId = _resolvePermissionId(permConf['resource']!, permConf['action']!);
                      bool isAvailable = realId != null;
                      bool isChecked = isAvailable && _currentRolePerms.contains(realId);

                      return GestureDetector(
                        onTap: isAvailable ? () {
                          setState(() {
                            if (isChecked) _currentRolePerms.remove(realId);
                            else _currentRolePerms.add(realId);
                          });
                        } : null,
                        child: Opacity(
                          opacity: isAvailable ? 1.0 : 0.5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.white,
                              border: Border.all(color: isChecked ? primaryYellow : borderColor),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(isChecked ? Icons.check_box : Icons.check_box_outline_blank, size: 16, color: isChecked ? (isDark ? primaryYellow : navyBlue) : Colors.grey),
                                const SizedBox(width: 8),
                                Text(permConf['label']!, style: TextStyle(fontSize: 11, fontWeight: isChecked ? FontWeight.bold : FontWeight.w600, color: isChecked ? (isDark ? primaryYellow : navyBlue) : (isDark ? Colors.white70 : Colors.black87))),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                )
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomSaveBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200)),
          boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))]
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Unsaved Changes", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14)),
            ElevatedButton.icon(
              onPressed: _savePermissions,
              icon: const Icon(Icons.save, size: 18, color: Colors.black87),
              label: const Text("Save Permissions", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: primaryYellow,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getFallbackPermissions() {
    return [
      {"_id": "69f8312a3380862b35f38908", "resource": "ticket", "action": "create"},
      {"_id": "69f8312a3380862b35f38909", "resource": "ticket", "action": "view"},
      {"_id": "69f8312a3380862b35f3890a", "resource": "ticket", "action": "view_own"},
      {"_id": "69f8312a3380862b35f3890b", "resource": "ticket", "action": "update"},
      {"_id": "69f8312a3380862b35f3890c", "resource": "ticket", "action": "delete"},
      {"_id": "69f8312a3380862b35f3890d", "resource": "ticket", "action": "assign"},
      {"_id": "69f8312a3380862b35f3890e", "resource": "ticket", "action": "change_status"},
      {"_id": "69f8312a3380862b35f3890f", "resource": "ticket", "action": "change_priority"},
      {"_id": "69f8312a3380862b35f38910", "resource": "ticket", "action": "close"},
      {"_id": "69f8312a3380862b35f38911", "resource": "ticket", "action": "reopen"},
      {"_id": "69f8312a3380862b35f38912", "resource": "comment", "action": "create"},
      {"_id": "69f8312a3380862b35f38913", "resource": "comment", "action": "view"},
      {"_id": "69f8312a3380862b35f38914", "resource": "comment", "action": "update"},
      {"_id": "69f8312a3380862b35f38915", "resource": "comment", "action": "delete"},
      {"_id": "69f8312a3380862b35f38916", "resource": "attachment", "action": "upload"},
      {"_id": "69f8312a3380862b35f38917", "resource": "attachment", "action": "view"},
      {"_id": "69f8312a3380862b35f38918", "resource": "attachment", "action": "delete"},
      {"_id": "69f8312a3380862b35f38919", "resource": "team", "action": "create"},
      {"_id": "69f8312a3380862b35f3891a", "resource": "team", "action": "view"},
      {"_id": "69f8312a3380862b35f3891b", "resource": "team", "action": "update"},
      {"_id": "69f8312a3380862b35f3891c", "resource": "team", "action": "delete"},
      {"_id": "69f8312a3380862b35f3891d", "resource": "user", "action": "create"},
      {"_id": "69f8312a3380862b35f3891e", "resource": "user", "action": "view"},
      {"_id": "69f8312a3380862b35f3891f", "resource": "user", "action": "update"},
      {"_id": "69f8312a3380862b35f38920", "resource": "user", "action": "delete"},
      {"_id": "69f8312a3380862b35f38921", "resource": "user", "action": "assign_role"},
      {"_id": "69f8312a3380862b35f38922", "resource": "role", "action": "create"},
      {"_id": "69f8312a3380862b35f38923", "resource": "role", "action": "view"},
      {"_id": "69f8312a3380862b35f38924", "resource": "role", "action": "update"},
      {"_id": "69f8312a3380862b35f38925", "resource": "role", "action": "delete"},
      {"_id": "69f8312a3380862b35f38926", "resource": "permission", "action": "view"},
      {"_id": "69f8312a3380862b35f38927", "resource": "permission", "action": "assign"},
      {"_id": "69f8312a3380862b35f38928", "resource": "dashboard", "action": "view"},
      {"_id": "69f8312a3380862b35f38929", "resource": "report", "action": "view"},
      {"_id": "69f8312a3380862b35f3892a", "resource": "report", "action": "export"},
      {"_id": "69f8312a3380862b35f3892b", "resource": "settings", "action": "view"},
      {"_id": "69f8312a3380862b35f3892c", "resource": "settings", "action": "update"}
    ];
  }
}