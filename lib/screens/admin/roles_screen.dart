import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../../widgets/menu_drawer.dart';
import '../../constants/api_constants.dart';
import '../../providers/theme_provider.dart';
import '../common/profile_screen.dart';

class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  final String _baseUrl = ApiConstants.baseUrl;

  List<dynamic> _roles = [];
  bool _isLoading = true;

  // APP BAR USER PROFILE DATA
  String _firstName = "User";
  String _initials = "U";
  String? _profileImageUrl;

  // 🔥 STRICT PERMISSION FLAGS FOR ROLES
  bool _canCreateRole = false;
  bool _canUpdateRole = false;
  bool _canDeleteRole = false;

  // Exact Permissions structured by Resource and Action
  final Map<String, List<Map<String, String>>> _permissionModules = {
    "TICKETS": [
      {"resource": "ticket", "action": "view", "label": "View All Tickets"},
      {"resource": "ticket", "action": "view_own", "label": "View Own Tickets"},
      {"resource": "ticket", "action": "create", "label": "Create Tickets"},
      {"resource": "ticket", "action": "update", "label": "Edit Tickets"},
      {"resource": "ticket", "action": "delete", "label": "Delete Tickets"},
      {"resource": "ticket", "action": "assign", "label": "Assign Tickets"},
      {"resource": "ticket", "action": "change_status", "label": "Change Status"},
      {"resource": "ticket", "action": "change_priority", "label": "Change Priority"},
      {"resource": "ticket", "action": "close", "label": "Close Tickets"},
      {"resource": "ticket", "action": "reopen", "label": "Reopen Tickets"},
    ],
    "COMMENTS": [
      {"resource": "comment", "action": "view", "label": "View Comments"},
      {"resource": "comment", "action": "create", "label": "Add Comments"},
      {"resource": "comment", "action": "update", "label": "Edit Comments"},
      {"resource": "comment", "action": "delete", "label": "Delete Comments"},
    ],
    "TEAMS": [
      {"resource": "team", "action": "view", "label": "View Teams"},
      {"resource": "team", "action": "create", "label": "Create Teams"},
      {"resource": "team", "action": "update", "label": "Edit Teams"},
      {"resource": "team", "action": "delete", "label": "Delete Teams"},
    ],
    "USERS": [
      {"resource": "user", "action": "view", "label": "View Users"},
      {"resource": "user", "action": "create", "label": "Create Users"},
      {"resource": "user", "action": "update", "label": "Edit Users"},
      {"resource": "user", "action": "delete", "label": "Delete Users"},
      {"resource": "user", "action": "assign_role", "label": "Assign Role to User"},
    ],
    "ROLES & PERMISSIONS": [
      {"resource": "role", "action": "view", "label": "View Roles"},
      {"resource": "role", "action": "create", "label": "Create Roles"},
      {"resource": "role", "action": "update", "label": "Update Roles"},
      {"resource": "role", "action": "delete", "label": "Delete Roles"},
      {"resource": "permission", "action": "view", "label": "View Permissions"},
      {"resource": "permission", "action": "assign", "label": "Assign Permissions"},
    ]
  };

  // Internal Master List
  List<dynamic> _masterPermissions = [];

  @override
  void initState() {
    super.initState();
    _fetchRolesAndPermissions();
  }

  Future<void> _fetchRolesAndPermissions() async {
    setState(() => _isLoading = true);
    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");
      String? userDataString = await storage.read(key: "user_data");

      // Set App Bar User Profile AND 🔥 Parse Permissions
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

        // 🔥 RESET PERMISSIONS
        _canCreateRole = false;
        _canUpdateRole = false;
        _canDeleteRole = false;

        if (userData['permissions'] != null && userData['permissions'] is List) {
          for (var perm in userData['permissions']) {
            String res = perm['resource']?.toString().toLowerCase().trim() ?? '';
            String act = perm['action']?.toString().toLowerCase().trim() ?? '';

            if (res == 'role') {
              if (act == 'create') _canCreateRole = true;
              if (act == 'update' || act == 'edit') _canUpdateRole = true;
              if (act == 'delete' || act == 'dlt') _canDeleteRole = true;
            }
          }
        }
      }

      Options options = Options(headers: {"Authorization": "Bearer $token"});

      // 1. Force Fetch Master Permissions
      try {
        var permRes = await Dio().get("$_baseUrl/api/permissions", options: options);
        if (permRes.statusCode == 200) {
          var pData = permRes.data;
          if (pData is Map && pData.containsKey('data')) {
            _masterPermissions = pData['data'];
          } else if (pData is List) {
            _masterPermissions = pData;
          }
        }
      } catch (e) {
        debugPrint("Permissions Fetch Error: $e");
      }

      // 2. Fetch Roles
      var roleRes = await Dio().get("$_baseUrl/api/roles", options: options);

      setState(() {
        if (roleRes.data is Map && roleRes.data.containsKey('data')) {
          _roles = roleRes.data['data'];
        } else if (roleRes.data is List) {
          _roles = roleRes.data;
        } else {
          _roles = [];
        }

        // Auto-Harvest Permissions if API call failed
        if (_masterPermissions.isEmpty) {
          for (var r in _roles) {
            if (r['permissionIds'] != null) {
              for (var p in r['permissionIds']) {
                if (p is Map && !_masterPermissions.any((existing) => existing['_id'] == p['_id'])) {
                  _masterPermissions.add(p);
                }
              }
            }
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showError("Failed to load roles", e);
    }
  }

  // Smart Error Handler
  void _showError(String fallbackMsg, dynamic e) {
    String msg = fallbackMsg;
    if (e is DioException) {
      if (e.response?.data is String && e.response!.data.toString().contains("<!DOCTYPE html>")) {
        msg = "API Route Not Found (404) or Method Not Supported.";
      } else {
        try {
          msg = e.response?.data['message']?.toString() ?? e.response?.data?.toString() ?? fallbackMsg;
        } catch (_) {}
      }
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, maxLines: 3), backgroundColor: Colors.red));
  }

  Set<String> _extractPermissionIds(dynamic role) {
    Set<String> ids = {};
    if (role == null) return ids;

    List<dynamic> permsList = role['permissionIds'] ?? role['permissions'] ?? [];

    for (var p in permsList) {
      if (p is Map) {
        String? id = (p['_id'] ?? p['id'])?.toString();
        if (id != null) ids.add(id);
      } else if (p is String) {
        ids.add(p);
      }
    }
    return ids;
  }

  String? _resolvePermissionId(String resource, String action) {
    for (var p in _masterPermissions) {
      if (p['resource'] == resource && p['action'] == action) {
        return (p['_id'] ?? p['id']).toString();
      }
    }
    return null;
  }

  // =========================================================================
  // 🔥 CREATE / EDIT ROLE DIALOG
  // =========================================================================
  void _showCreateOrEditRoleDialog({dynamic role}) {
    bool isEdit = role != null;
    String roleId = isEdit ? (role['_id'] ?? role['id']).toString() : "";

    final TextEditingController nameCtrl = TextEditingController(text: isEdit ? role['name'] : "");
    final TextEditingController descCtrl = TextEditingController(text: isEdit ? role['description'] : "");

    Set<String> selectedPermIds = _extractPermissionIds(role);
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
        final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final inputColor = isDark ? const Color(0xFF121212) : Colors.grey.shade50;
        final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
        final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;

        return StatefulBuilder(builder: (context, setDialogState) {

          void toggleModule(String moduleKey, bool selectAll) {
            setDialogState(() {
              for (var permConf in _permissionModules[moduleKey]!) {
                String? realId = _resolvePermissionId(permConf['resource']!, permConf['action']!);
                if (realId != null) {
                  if (selectAll) selectedPermIds.add(realId);
                  else selectedPermIds.remove(realId);
                }
              }
            });
          }

          Future<void> submitForm() async {
            if (nameCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Role Name is required!"), backgroundColor: Colors.orange));
              return;
            }

            setDialogState(() => isSubmitting = true);

            try {
              const storage = FlutterSecureStorage();
              String? token = await storage.read(key: "jwt_token");

              Options jsonOptions = Options(
                  headers: {
                    "Authorization": "Bearer $token",
                    "Content-Type": "application/json"
                  }
              );

              Map<String, dynamic> payload = {
                "name": nameCtrl.text.trim(),
                "description": descCtrl.text.trim(),
                "permissionIds": selectedPermIds.toList(),
              };

              if (isEdit) {
                payload["roleId"] = roleId;
                await Dio().put("$_baseUrl/api/roles/update", data: jsonEncode(payload), options: jsonOptions);
              } else {
                await Dio().post("$_baseUrl/api/roles", data: jsonEncode(payload), options: jsonOptions);
              }

              if (!context.mounted) return;
              Navigator.pop(context);
              _fetchRolesAndPermissions();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? "Role Updated Successfully!" : "Role Created Successfully!"), backgroundColor: Colors.green));

            } catch (e) {
              setDialogState(() => isSubmitting = false);
              String errorMsg = e.toString();
              if (e is DioException) {
                if (e.response?.data is String && e.response!.data.toString().contains("<!DOCTYPE html>")) {
                  errorMsg = "API Route Not Found (404). Backend configuration error.";
                } else {
                  try { errorMsg = e.response!.data['message']?.toString() ?? jsonEncode(e.response?.data); } catch (_) { errorMsg = "Validation Failed"; }
                }
              }
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $errorMsg", maxLines: 2), backgroundColor: Colors.red));
            }
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              width: 650,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isEdit ? "Edit Role Configuration" : "Create New Role", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        IconButton(icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.grey), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero, constraints: const BoxConstraints())
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFormLabel("ROLE NAME", isDark),
                          TextField(controller: nameCtrl, style: TextStyle(color: textColor), decoration: _buildInputDecoration("e.g. Supervisor", inputColor, borderColor, isDark)),
                          const SizedBox(height: 16),

                          _buildFormLabel("DESCRIPTION", isDark),
                          TextField(controller: descCtrl, style: TextStyle(color: textColor), decoration: _buildInputDecoration("Brief description...", inputColor, borderColor, isDark)),
                          const SizedBox(height: 32),

                          ..._permissionModules.entries.map((entry) {
                            String moduleName = entry.key;
                            List<Map<String, String>> permsConfig = entry.value;

                            bool allSelected = true;
                            int validPermsCount = 0;
                            for(var pc in permsConfig) {
                              String? id = _resolvePermissionId(pc['resource']!, pc['action']!);
                              if(id != null) {
                                validPermsCount++;
                                if(!selectedPermIds.contains(id)) allSelected = false;
                              }
                            }
                            if (validPermsCount == 0) allSelected = false;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(moduleName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade400 : Colors.grey, letterSpacing: 1.0)),
                                      OutlinedButton(
                                        onPressed: () => toggleModule(moduleName, !allSelected),
                                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), side: BorderSide(color: borderColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                        child: Text(allSelected ? "Deselect All" : "Select All", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  LayoutBuilder(builder: (context, constraints) {
                                    double boxWidth = (constraints.maxWidth - 12) / 2;
                                    return Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: permsConfig.map((permConf) {
                                        String? realId = _resolvePermissionId(permConf['resource']!, permConf['action']!);
                                        bool isAvailable = realId != null;
                                        bool isChecked = realId != null && selectedPermIds.contains(realId);

                                        return GestureDetector(
                                          onTap: isAvailable ? () {
                                            setDialogState(() {
                                              if (isChecked) selectedPermIds.remove(realId);
                                              else selectedPermIds.add(realId!);
                                            });
                                          } : null,
                                          child: Opacity(
                                            opacity: isAvailable ? 1.0 : 0.5,
                                            child: Container(
                                              width: boxWidth,
                                              padding: const EdgeInsets.symmetric(vertical: 4),
                                              decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.white, border: Border.all(color: isChecked ? const Color(0xFFF3C300) : borderColor), borderRadius: BorderRadius.circular(8)),
                                              child: Row(
                                                children: [
                                                  Checkbox(
                                                    value: isChecked,
                                                    activeColor: const Color(0xFFF3C300),
                                                    checkColor: Colors.black,
                                                    side: BorderSide(color: isDark ? Colors.white54 : Colors.grey.shade400),
                                                    onChanged: isAvailable ? (val) {
                                                      setDialogState(() {
                                                        if (val == true) selectedPermIds.add(realId!);
                                                        else selectedPermIds.remove(realId);
                                                      });
                                                    } : null,
                                                  ),
                                                  Expanded(
                                                    child: Text(permConf['label']!, style: TextStyle(fontSize: 13, fontWeight: isChecked ? FontWeight.bold : FontWeight.w500, color: textColor), overflow: TextOverflow.ellipsis),
                                                  )
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  })
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: borderColor))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontWeight: FontWeight.bold))),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: isDark ? const Color(0xFFF3C300) : const Color(0xFF1E293B), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          onPressed: isSubmitting ? null : submitForm,
                          child: isSubmitting ? CircularProgressIndicator(color: isDark ? Colors.black : Colors.white) : Text(isEdit ? "Update Role" : "Create Role", style: TextStyle(color: isDark ? Colors.black87 : Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildFormLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade400 : Colors.grey, letterSpacing: 0.5)),
    );
  }

  InputDecoration _buildInputDecoration(String hint, Color fillColor, Color borderColor, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.normal),
      filled: true, fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFF3C300), width: 2)),
    );
  }

  // =========================================================================
  // 🔥 DELETE ROLE
  // =========================================================================
  Future<void> _deleteRole(String roleId, String roleName) async {
    bool confirm = await showDialog(
        context: context,
        builder: (context) {
          final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text("Delete Role", style: TextStyle(color: Colors.red))]),
            content: Text("Are you sure you want to delete the '$roleName' role? This action cannot be undone.", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Delete Role", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
    ) ?? false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");

      Options jsonOptions = Options(
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json"
          }
      );

      await Dio().delete(
          "$_baseUrl/api/roles/delete",
          data: jsonEncode({"roleId": roleId}),
          options: jsonOptions
      );

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Role deleted successfully."), backgroundColor: Colors.green));
      _fetchRolesAndPermissions();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("Error deleting role", e);
    }
  }

  // =========================================================================
  // 🔥 BUILD GLOBAL APP BAR WITH AVATAR & DARK MODE TOGGLE
  // =========================================================================
  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E293B),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: const Text("Roles & Permissions", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
        if (val == 'profile') Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())).then((_) => _fetchRolesAndPermissions());
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
          backgroundImage: _profileImageUrl != null ? NetworkImage("$_baseUrl$_profileImageUrl") : null,
          child: _profileImageUrl == null ? Text(_initials, style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)) : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white70 : Colors.grey.shade600;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: bgColor,
      drawer: const MenuDrawer(currentRoute: "roles"),
      appBar: _buildModernAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF3C300)))
          : RefreshIndicator(
        onRefresh: _fetchRolesAndPermissions,
        color: const Color(0xFF1E293B),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Roles & Permissions", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 2),
                        Text("Manage roles and their capabilities", style: TextStyle(color: subTextColor, fontSize: 14)),
                      ],
                    ),
                  ),

                  // 🔥 STRICT UI: ONLY SHOW "NEW ROLE" IF PERMITTED
                  if (_canCreateRole)
                    ElevatedButton.icon(
                      onPressed: () => _showCreateOrEditRoleDialog(),
                      icon: const Icon(Icons.add, size: 16, color: Colors.black),
                      label: const Text("New Role", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF3C300), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              if (_roles.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
                  child: Column(
                    children: [
                      Icon(Icons.shield_outlined, size: 48, color: isDark ? Colors.white24 : Colors.grey),
                      const SizedBox(height: 16),
                      Text("No roles configured yet.", style: TextStyle(color: subTextColor, fontSize: 16)),
                    ],
                  ),
                )
              else
                LayoutBuilder(builder: (context, constraints) {
                  bool isDesktop = constraints.maxWidth > 800;

                  if (isDesktop) {
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: _roles.map((r) => SizedBox(width: (constraints.maxWidth - 16) / 2, child: _buildRoleCard(r, isDark, cardColor, textColor, subTextColor, borderColor))).toList(),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _roles.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) => _buildRoleCard(_roles[index], isDark, cardColor, textColor, subTextColor, borderColor),
                  );
                })
            ],
          ),
        ),
      ),
    );
  }

  int _countPermsInModule(Set<String> assignedIds, String moduleKey) {
    int count = 0;
    for (var mPerm in _permissionModules[moduleKey]!) {
      String? realId = _resolvePermissionId(mPerm['resource']!, mPerm['action']!);
      if (realId != null && assignedIds.contains(realId)) {
        count++;
      }
    }
    return count;
  }

  Widget _buildRoleCard(dynamic role, bool isDark, Color cardColor, Color textColor, Color subTextColor, Color borderColor) {
    String roleId = (role['_id'] ?? role['id']).toString();
    String name = role['name'] ?? 'Unnamed Role';
    int assignedUsers = role['userCount'] ?? 0;

    Set<String> assignedIds = _extractPermissionIds(role);
    int totalPerms = assignedIds.length;

    int ticketPerms = _countPermsInModule(assignedIds, "TICKETS");
    int userPerms = _countPermsInModule(assignedIds, "USERS");
    int teamPerms = _countPermsInModule(assignedIds, "TEAMS");
    int rolePerms = _countPermsInModule(assignedIds, "ROLES & PERMISSIONS");

    return Container(
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey.shade100, shape: BoxShape.circle), child: Icon(Icons.shield_outlined, color: textColor, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor), overflow: TextOverflow.ellipsis)),
                Text("$assignedUsers users", style: TextStyle(fontSize: 12, color: subTextColor, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPermRow("Tickets", ticketPerms, _permissionModules["TICKETS"]!.length, textColor, subTextColor),
                const SizedBox(height: 12),
                _buildPermRow("Users", userPerms, _permissionModules["USERS"]!.length, textColor, subTextColor),
                const SizedBox(height: 12),
                _buildPermRow("Teams", teamPerms, _permissionModules["TEAMS"]!.length, textColor, subTextColor),
                const SizedBox(height: 12),
                _buildPermRow("Roles & Config", rolePerms, _permissionModules["ROLES & PERMISSIONS"]!.length, textColor, subTextColor),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.vpn_key_outlined, size: 14, color: isDark ? Colors.white54 : Colors.grey.shade400),
                const SizedBox(width: 6),
                Text("$totalPerms permissions attached", style: TextStyle(fontSize: 12, color: subTextColor, fontWeight: FontWeight.bold)),
                const Spacer(),

                // 🔥 STRICT UI: ONLY SHOW "EDIT" IF PERMITTED
                if (_canUpdateRole)
                  ElevatedButton.icon(
                    onPressed: () => _showCreateOrEditRoleDialog(role: role),
                    icon: const Icon(Icons.edit, size: 14, color: Colors.black87),
                    label: const Text("Edit", style: TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF3C300), elevation: 0, minimumSize: const Size(60, 32), padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                  ),

                if (_canUpdateRole && _canDeleteRole) const SizedBox(width: 8),

                // 🔥 STRICT UI: ONLY SHOW "DELETE" IF PERMITTED
                if (_canDeleteRole)
                  InkWell(
                    onTap: () => _deleteRole(roleId, name),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)), child: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade700)),
                  )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPermRow(String label, int current, int total, Color textColor, Color subTextColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.w500)),
        Text("$current/$total", style: TextStyle(fontSize: 12, color: subTextColor, fontWeight: FontWeight.bold)),
      ],
    );
  }
}