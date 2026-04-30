import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../widgets/menu_drawer.dart';

class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  final String _baseUrl = "https://ticketapi.dcstechnosis.com";

  List<dynamic> _roles = [];
  List<dynamic> _masterPermissions = [];
  bool _isLoading = true;

  // Theme Colors
  final Color primaryYellow = const Color(0xFFF3C300);
  final Color navyBlue = const Color(0xFF1E293B);
  final Color backgroundGray = const Color(0xFFF8FAFC);

  // Exact Permissions
  final Map<String, List<Map<String, String>>> _permissionModules = {
    "TICKETS": [
      {"id": "ticket:view:any", "label": "View Tickets"},
      {"id": "ticket:create:any", "label": "Create Tickets"},
      {"id": "ticket:update:any", "label": "Edit Tickets"},
      {"id": "ticket:delete:any", "label": "Delete Tickets"},
      {"id": "ticket:assign:any", "label": "Assign Tickets"},
    ],
    "USERS": [
      {"id": "user:view:any", "label": "View Users"},
      {"id": "user:create:any", "label": "Create Users"},
      {"id": "user:update:any", "label": "Edit Users"},
      {"id": "user:delete:any", "label": "Delete Users"},
    ],
    "TEAMS": [
      {"id": "team:view:any", "label": "View Teams"},
      {"id": "team:create:any", "label": "Create Teams"},
      {"id": "team:update:any", "label": "Edit Teams"},
    ],
    "ROLES": [
      {"id": "role:view:any", "label": "View Roles"},
      {"id": "role:update:any", "label": "Manage Roles"},
    ]
  };

  @override
  void initState() {
    super.initState();
    _fetchRoles(); // 🔥 Fixed Function Name
  }

  // 🔥 Fixed Function Name to resolve compilation errors
  Future<void> _fetchRoles() async {
    setState(() => _isLoading = true);
    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");
      Options options = Options(headers: {"Authorization": "Bearer $token"});

      // Try fetching master permissions
      try {
        var permRes =
            await Dio().get("$_baseUrl/api/permissions", options: options);
        if (permRes.data is Map && permRes.data['data'] != null) {
          _masterPermissions = permRes.data['data'];
        } else if (permRes.data is List) {
          _masterPermissions = permRes.data;
        }
      } catch (e) {
        debugPrint(
            "Permissions endpoint missing. Harvesting IDs from roles instead.");
      }

      // Fetch Roles
      var roleRes = await Dio().get("$_baseUrl/api/roles", options: options);
      setState(() {
        if (roleRes.data is Map && roleRes.data.containsKey('data')) {
          _roles = roleRes.data['data'];
        } else if (roleRes.data is List) {
          _roles = roleRes.data;
        } else {
          _roles = [];
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("Failed to load roles", e);
    }
  }

  Future<String> _getOrganizationId() async {
    const storage = FlutterSecureStorage();
    String? userDataString = await storage.read(key: "user_data");
    if (userDataString != null) {
      return (jsonDecode(userDataString)['organizationId'] ??
              jsonDecode(userDataString)['organization'] ??
              '')
          .toString();
    }
    return '';
  }

  void _showError(String fallbackMsg, dynamic e) {
    String msg = fallbackMsg;
    if (e is DioException)
      msg = e.response?.data?['message'] ??
          e.response?.data?['error'] ??
          fallbackMsg;
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Set<String> _extractPermissions(dynamic role) {
    Set<String> perms = {};
    if (role == null || role['permissions'] == null) return perms;
    for (var p in role['permissions']) {
      if (p is Map) {
        String? name = p['name'] ?? p['label'];
        if (name != null) perms.add(name);
      } else if (p is String) {
        perms.add(p);
      }
    }
    return perms;
  }

  String _getPermissionObjectId(String permString) {
    for (var p in _masterPermissions) {
      if (p['name'] == permString || p['label'] == permString)
        return p['_id'].toString();
    }
    for (var r in _roles) {
      for (var p in r['permissions'] ?? []) {
        if (p is Map && (p['name'] == permString || p['label'] == permString)) {
          return p['_id'].toString();
        }
      }
    }
    return permString;
  }

  // --- GRID VIEW ROLE DIALOG ---
  Future<void> _showCreateOrEditRoleDialog({dynamic role}) async {
    bool isEdit = role != null;
    String roleId = isEdit ? (role['_id'] ?? role['id']).toString() : "";

    final TextEditingController nameCtrl =
        TextEditingController(text: isEdit ? role['name'] : "");
    final TextEditingController descCtrl =
        TextEditingController(text: isEdit ? role['description'] : "");

    Set<String> selectedPerms = _extractPermissions(role);

    bool confirm = await showDialog(
            context: context,
            builder: (context) {
              return StatefulBuilder(builder: (context, setDialogState) {
                void toggleModule(String moduleKey, bool selectAll) {
                  setDialogState(() {
                    for (var perm in _permissionModules[moduleKey]!) {
                      if (selectAll)
                        selectedPerms.add(perm['id']!);
                      else
                        selectedPerms.remove(perm['id']!);
                    }
                  });
                }

                return Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.all(16),
                  child: Container(
                    width: 600,
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.9),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        // HEADER
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                              border: Border(
                                  bottom:
                                      BorderSide(color: Colors.grey.shade200))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  isEdit
                                      ? "Edit Role Configuration"
                                      : "Create New Role",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: navyBlue)),
                              IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.grey),
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints())
                            ],
                          ),
                        ),

                        // BODY
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildProTextField(
                                    nameCtrl, "ROLE NAME", "e.g. Supervisor"),
                                const SizedBox(height: 16),
                                _buildProTextField(descCtrl, "DESCRIPTION",
                                    "Brief description..."),
                                const SizedBox(height: 32),

                                // 🔥 GRID VIEW PERMISSIONS (Matches your exact screenshot!)
                                ..._permissionModules.entries.map((entry) {
                                  String moduleName = entry.key;
                                  List<Map<String, String>> perms = entry.value;
                                  bool allSelected = perms.every(
                                      (p) => selectedPerms.contains(p['id']));

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 32),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(moduleName,
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey,
                                                    letterSpacing: 1.0)),
                                            OutlinedButton(
                                              onPressed: () => toggleModule(
                                                  moduleName, !allSelected),
                                              style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                                  side: BorderSide(
                                                      color:
                                                          Colors.grey.shade300),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8))),
                                              child: Text(
                                                  allSelected
                                                      ? "Deselect All"
                                                      : "Select All",
                                                  style: TextStyle(
                                                      color:
                                                          Colors.grey.shade700,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            )
                                          ],
                                        ),
                                        const SizedBox(height: 16),

                                        // 🔥 PERFECT 2-COLUMN GRID (Works on Mobile & Desktop)
                                        LayoutBuilder(
                                            builder: (context, constraints) {
                                          // Calculate width for 2 columns with a 12px gap
                                          double boxWidth =
                                              (constraints.maxWidth - 12) / 2;
                                          return Wrap(
                                            spacing: 12,
                                            runSpacing: 12,
                                            children: perms.map((perm) {
                                              bool isChecked = selectedPerms
                                                  .contains(perm['id']);
                                              return GestureDetector(
                                                onTap: () {
                                                  setDialogState(() {
                                                    if (isChecked)
                                                      selectedPerms
                                                          .remove(perm['id']!);
                                                    else
                                                      selectedPerms
                                                          .add(perm['id']!);
                                                  });
                                                },
                                                child: Container(
                                                  width: boxWidth,
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    border: Border.all(
                                                        color: Colors
                                                            .grey.shade300),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Checkbox(
                                                        value: isChecked,
                                                        activeColor: navyBlue,
                                                        onChanged: (val) {
                                                          setDialogState(() {
                                                            if (val == true)
                                                              selectedPerms.add(
                                                                  perm['id']!);
                                                            else
                                                              selectedPerms
                                                                  .remove(perm[
                                                                      'id']!);
                                                          });
                                                        },
                                                      ),
                                                      Expanded(
                                                        child: Text(
                                                            perm['label']!,
                                                            style: TextStyle(
                                                                fontSize: 13,
                                                                fontWeight: isChecked
                                                                    ? FontWeight
                                                                        .bold
                                                                    : FontWeight
                                                                        .w500,
                                                                color:
                                                                    navyBlue),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis),
                                                      )
                                                    ],
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

                        // FOOTER
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                              border: Border(
                                  top:
                                      BorderSide(color: Colors.grey.shade200))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text("Cancel",
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold))),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryYellow,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8))),
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(
                                    isEdit ? "Update Role" : "Create Role",
                                    style: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                );
              });
            }) ??
        false;

    if (!confirm || nameCtrl.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");
      String orgId = await _getOrganizationId();

      List<String> payloadPermissions =
          selectedPerms.map((p) => _getPermissionObjectId(p)).toList();

      Map<String, dynamic> payload = {
        "name": nameCtrl.text.trim(),
        "description": descCtrl.text.trim(),
        "permissions": payloadPermissions,
        "organizationId": orgId, // Injecting Organization ID
        "roleId": roleId, // Injecting Role ID
      };

      if (isEdit) {
        await Dio().put("$_baseUrl/api/roles/$roleId",
            data: payload,
            options: Options(headers: {"Authorization": "Bearer $token"}));
      } else {
        await Dio().post("$_baseUrl/api/roles",
            data: payload,
            options: Options(headers: {"Authorization": "Bearer $token"}));
      }

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEdit
                ? "Role updated successfully!"
                : "Role created successfully!"),
            backgroundColor: Colors.green));
      _fetchRoles(); // 🔥 Uses the correctly named function
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(isEdit ? "Error updating role" : "Error creating role", e);
    }
  }

  // --- DELETE ROLE WITH FIX ---
  Future<void> _deleteRole(String roleId, String roleName) async {
    bool confirm = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: Row(children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text("Delete Role")
                  ]),
                  content: Text(
                      "Are you sure you want to delete the '$roleName' role? This action cannot be undone."),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel",
                            style: TextStyle(color: Colors.grey))),
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Delete Role",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold))),
                  ],
                )) ??
        false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");
      String orgId = await _getOrganizationId();

      // 🔥 Sending Organization ID and Role ID in DELETE Body for backend security rules
      await Dio().delete("$_baseUrl/api/roles/$roleId",
          data: {"organizationId": orgId, "roleId": roleId},
          options: Options(headers: {"Authorization": "Bearer $token"}));

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Role deleted successfully."),
            backgroundColor: Colors.green));
      _fetchRoles(); // 🔥 Uses the correctly named function
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("Error deleting role", e);
    }
  }

  Widget _buildProTextField(
      TextEditingController controller, String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: TextStyle(
              fontSize: 14, color: navyBlue, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 13,
                fontWeight: FontWeight.normal),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: primaryYellow, width: 2)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGray,
      drawer: const MenuDrawer(currentRoute: "roles"),
      appBar: AppBar(
        backgroundColor: navyBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("TMS Admin",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryYellow))
          : RefreshIndicator(
              onRefresh: _fetchRoles, // 🔥 Uses the correctly named function
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildRolesList(),
                  ],
                ),
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
              Text("Roles",
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: navyBlue)),
              const SizedBox(height: 2),
              Text("Manage roles and their capabilities",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _showCreateOrEditRoleDialog(),
          icon: const Icon(Icons.add, size: 18, color: Colors.black),
          label: const Text("New Role",
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
              backgroundColor: primaryYellow,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
        ),
      ],
    );
  }

  Widget _buildRolesList() {
    if (_roles.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200)),
        child: const Column(
          children: [
            Icon(Icons.shield_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text("No roles configured yet.",
                style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      bool isDesktop = constraints.maxWidth > 800;

      if (isDesktop) {
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _roles
              .map((r) => SizedBox(
                    width: (constraints.maxWidth - 16) / 2,
                    child: _buildRoleCard(r),
                  ))
              .toList(),
        );
      }

      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _roles.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) => _buildRoleCard(_roles[index]),
      );
    });
  }

  int _countPermsInModule(List<String> perms, String moduleKey) {
    int count = 0;
    for (var mPerm in _permissionModules[moduleKey]!) {
      if (perms.contains(mPerm['id'])) count++;
    }
    return count;
  }

  Widget _buildRoleCard(dynamic role) {
    String roleId = (role['_id'] ?? role['id']).toString();
    String name = role['name'] ?? 'Unnamed Role';
    int assignedUsers = role['userCount'] ?? 0;

    List<String> perms = _extractPermissions(role).toList();
    int totalPerms = perms.length;

    int ticketPerms = _countPermsInModule(perms, "TICKETS");
    int userPerms = _countPermsInModule(perms, "USERS");
    int teamPerms = _countPermsInModule(perms, "TEAMS");
    int rolePerms = _countPermsInModule(perms, "ROLES");

    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100, shape: BoxShape.circle),
                  child: const Icon(Icons.shield_outlined,
                      color: Colors.black87, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(name,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: navyBlue),
                        overflow: TextOverflow.ellipsis)),
                Text("$assignedUsers users",
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPermRow("Tickets", ticketPerms, 5),
                const SizedBox(height: 12),
                _buildPermRow("Users", userPerms, 4),
                const SizedBox(height: 12),
                _buildPermRow("Teams", teamPerms, 3),
                const SizedBox(height: 12),
                _buildPermRow("Roles", rolePerms, 2),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.vpn_key_outlined,
                    size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 6),
                Text("$totalPerms/14 permissions",
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showCreateOrEditRoleDialog(role: role),
                  icon: const Icon(Icons.edit, size: 14, color: Colors.black87),
                  label: const Text("Edit",
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: primaryYellow,
                      elevation: 0,
                      minimumSize: const Size(60, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6))),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _deleteRole(roleId, name),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6)),
                    child: Icon(Icons.delete_outline,
                        size: 16, color: Colors.red.shade700),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPermRow(String label, int current, int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w500)),
        Text("$current/$total",
            style: const TextStyle(
                fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
