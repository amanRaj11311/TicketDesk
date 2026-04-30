import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../widgets/menu_drawer.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final String _baseUrl = "https://ticketapi.dcstechnosis.com";
  bool _isLoading = true;

  // Theme Colors
  final Color primaryYellow = const Color(0xFFF3C300);
  final Color navyBlue = const Color(0xFF1E293B);
  final Color backgroundGray = const Color(0xFFF8FAFC);

  // Data
  List<dynamic> _roles = [];
  List<dynamic> _masterPermissions = [];

  // Selection State
  String? _selectedRoleId;
  Set<String> _originalRolePerms = {};
  Set<String> _currentRolePerms = {};

  // Matrix Structure
  final Map<String, Map<String, List<String>>> _gridMap = {};

  // Strict UI Layout Order
  final List<String> _moduleOrder = ['TICKETS', 'USERS', 'TEAMS', 'ROLES', 'REPORTS', 'SETTINGS'];
  final List<String> _columnOrder = ['VIEW', 'CREATE', 'EDIT', 'DELETE', 'ASSIGN', 'MANAGE', 'EXPORT'];

  @override
  void initState() {
    super.initState();
    _buildDynamicMatrix();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");
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

      _buildDynamicMatrix();

      if (_roles.isNotEmpty && _selectedRoleId == null) {
        _selectRole(_roles[0]);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      if (_masterPermissions.isEmpty) _masterPermissions = _getFallbackPermissions();
      _buildDynamicMatrix();

      setState(() => _isLoading = false);
      _showError("Failed to load permissions data", e);
    }
  }

  // 🔥 BULLETPROOF ERROR HANDLER
  // Prevents crashes if the backend sends an HTML error page instead of JSON
  void _showError(String fallbackMsg, dynamic e) {
    String msg = fallbackMsg;
    if (e is DioException) {
      final data = e.response?.data;

      if (data is Map) {
        msg = data['message'] ?? data['error'] ?? fallbackMsg;
      } else if (data is String) {
        // Handle HTML Error Pages
        if (data.contains("Cannot PUT")) {
          msg = "Backend Error: Route 'PUT /api/roles/:id' is missing on the server.";
        } else if (data.contains("Cannot PATCH")) {
          msg = "Backend Error: Route 'PATCH /api/roles/:id' is missing on the server.";
        } else if (data.contains("<!DOCTYPE html>")) {
          msg = "Backend Server Error: Returned an HTML error page.";
        } else {
          msg = data; // Show raw string if it's not HTML
        }
      } else {
        msg = e.message ?? fallbackMsg;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 5),
          )
      );
    }
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
    if (role == null || role['permissions'] == null) return [];
    if (role['permissions'] is List) {
      return (role['permissions'] as List).map((p) {
        if (p is Map) return (p['_id'] ?? p['id'] ?? '').toString();
        return p.toString();
      }).toList();
    }
    return [];
  }

  void _buildDynamicMatrix() {
    _gridMap.clear();
    for (String m in _moduleOrder) {
      _gridMap[m] = { for (String c in _columnOrder) c: [] };
    }

    for (var perm in _masterPermissions) {
      String id = perm['_id'].toString();
      String resource = perm['resource'].toString().toLowerCase();
      String action = perm['action'].toString().toLowerCase();

      String moduleName = _mapResourceToModule(resource);
      String columnName = _mapActionToColumn(action);

      if (_gridMap.containsKey(moduleName) && _gridMap[moduleName]!.containsKey(columnName)) {
        _gridMap[moduleName]![columnName]!.add(id);
      }
    }
  }

  String _mapResourceToModule(String resource) {
    if (['ticket', 'comment', 'attachment'].contains(resource)) return 'TICKETS';
    if (resource == 'user') return 'USERS';
    if (resource == 'team') return 'TEAMS';
    if (['role', 'permission'].contains(resource)) return 'ROLES';
    if (['report', 'dashboard'].contains(resource)) return 'REPORTS';
    if (resource == 'settings') return 'SETTINGS';
    return 'SETTINGS';
  }

  String _mapActionToColumn(String action) {
    if (action.contains('view')) return 'VIEW';
    if (action == 'create' || action == 'upload') return 'CREATE';
    if (['update', 'change_status', 'change_priority', 'close', 'reopen'].contains(action)) return 'EDIT';
    if (action == 'delete') return 'DELETE';
    if (action.contains('assign')) return 'ASSIGN';
    if (action == 'export') return 'EXPORT';
    return 'MANAGE';
  }

  void _selectRole(dynamic role) {
    setState(() {
      _selectedRoleId = (role['_id'] ?? role['id']).toString();
      _originalRolePerms = {};

      if (role['permissions'] != null) {
        for (var p in role['permissions']) {
          if (p is Map) _originalRolePerms.add((p['_id'] ?? p['id']).toString());
          else if (p is String) _originalRolePerms.add(p);
        }
      }
      _currentRolePerms = Set<String>.from(_originalRolePerms);
    });
  }

  bool _hasUnsavedChanges() {
    if (_originalRolePerms.length != _currentRolePerms.length) return true;
    return !_originalRolePerms.containsAll(_currentRolePerms);
  }

  void _togglePermission(List<String> permIdsToToggle) {
    if (permIdsToToggle.isEmpty) return;
    setState(() {
      bool allChecked = permIdsToToggle.every((id) => _currentRolePerms.contains(id));
      if (allChecked) {
        _currentRolePerms.removeAll(permIdsToToggle);
      } else {
        _currentRolePerms.addAll(permIdsToToggle);
      }
    });
  }

  void _toggleModuleRow(String moduleName) {
    setState(() {
      List<String> allIdsInModule = [];
      Map<String, List<String>>? cols = _gridMap[moduleName];

      if (cols != null) {
        for (List<String> colList in cols.values) {
          allIdsInModule.addAll(colList);
        }
      }
      if (allIdsInModule.isEmpty) return;

      bool allChecked = allIdsInModule.every((id) => _currentRolePerms.contains(id));
      if (allChecked) {
        _currentRolePerms.removeAll(allIdsInModule);
      } else {
        _currentRolePerms.addAll(allIdsInModule);
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

      Map<String, dynamic> payload = {
        "name": role['name'],
        "description": role['description'] ?? "",
        "permissions": _currentRolePerms.toList(),
        "organizationId": orgId,
        "roleId": _selectedRoleId,
      };

      await Dio().put(
          "$_baseUrl/api/roles/$_selectedRoleId",
          data: payload,
          options: Options(headers: {"Authorization": "Bearer $token"})
      );

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permissions saved successfully!"), backgroundColor: Colors.green));
      _fetchData();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("Error saving permissions", e);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasChanges = _hasUnsavedChanges();

    return Scaffold(
      backgroundColor: backgroundGray,
      drawer: const MenuDrawer(currentRoute: "permissions"),
      appBar: AppBar(
        backgroundColor: navyBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("TMS Admin", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      bottomNavigationBar: hasChanges ? _buildBottomSaveBar() : null,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryYellow))
          : RefreshIndicator(
        onRefresh: _fetchData,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildRoleSelector(),
            const SizedBox(height: 24),
            _buildSummaryCard(),
            const SizedBox(height: 24),
            _buildMobilePermissionsCards(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Permissions", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: navyBlue)),
          const SizedBox(height: 4),
          Text("Select a role to manage its access level", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text("SELECT ROLE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1.0)),
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
                  label: Text(role['name'] ?? 'Role', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? navyBlue : Colors.black87)),
                  selected: isSelected,
                  selectedColor: primaryYellow.withOpacity(0.8),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: isSelected ? primaryYellow : Colors.grey.shade300),
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

  Widget _buildSummaryCard() {
    if (_selectedRoleId == null) return const SizedBox.shrink();

    int percentage = _masterPermissions.isEmpty ? 0 : ((_currentRolePerms.length / _masterPermissions.length) * 100).toInt();

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
            Text("${_currentRolePerms.length}/${_masterPermissions.length}", style: TextStyle(color: primaryYellow, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildMobilePermissionsCards() {
    if (_selectedRoleId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: _moduleOrder.map((moduleName) {

          Map<String, List<String>>? cols = _gridMap[moduleName];
          bool hasAnyPerms = false;
          if (cols != null) {
            for (List<String> list in cols.values) {
              if (list.isNotEmpty) hasAnyPerms = true;
            }
          }
          if (!hasAnyPerms) return const SizedBox.shrink();

          List<String> allIdsInModule = [];
          if (cols != null) {
            for (List<String> list in cols.values) {
              allIdsInModule.addAll(list);
            }
          }
          bool allChecked = allIdsInModule.every((id) => _currentRolePerms.contains(id));

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(moduleName[0] + moduleName.substring(1).toLowerCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: navyBlue)),
                      InkWell(
                        onTap: () => _toggleModuleRow(moduleName),
                        child: Text(allChecked ? "Revoke All" : "Grant All", style: TextStyle(color: Colors.blue.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _columnOrder.map((colName) {
                      List<String> idsForCell = cols?[colName] ?? <String>[];
                      if (idsForCell.isEmpty) return const SizedBox.shrink();

                      bool isChecked = idsForCell.every((id) => _currentRolePerms.contains(id));

                      return InkWell(
                        onTap: () => _togglePermission(idsForCell),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isChecked ? primaryYellow.withOpacity(0.1) : Colors.transparent,
                            border: Border.all(color: isChecked ? primaryYellow : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(isChecked ? Icons.check_box : Icons.check_box_outline_blank, size: 18, color: isChecked ? navyBlue : Colors.grey),
                              const SizedBox(width: 8),
                              Text(colName, style: TextStyle(fontSize: 12, fontWeight: isChecked ? FontWeight.bold : FontWeight.w500, color: isChecked ? navyBlue : Colors.black87)),
                            ],
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

  Widget _buildBottomSaveBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))]
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
      {"_id": "69d0b67e176b2e74ad5c862e", "resource": "ticket", "action": "create"},
      {"_id": "69d0b67e176b2e74ad5c8637", "resource": "ticket", "action": "view"},
      {"_id": "69d0b67e176b2e74ad5c863e", "resource": "ticket", "action": "view_own"},
      {"_id": "69d0b67e176b2e74ad5c8646", "resource": "ticket", "action": "update"},
      {"_id": "69d0b67e176b2e74ad5c864a", "resource": "ticket", "action": "delete"},
      {"_id": "69d0b67e176b2e74ad5c864d", "resource": "ticket", "action": "assign"},
      {"_id": "69d0b67e176b2e74ad5c8650", "resource": "ticket", "action": "change_status"},
      {"_id": "69d0b67e176b2e74ad5c8653", "resource": "ticket", "action": "change_priority"},
      {"_id": "69d0b67e176b2e74ad5c8656", "resource": "ticket", "action": "close"},
      {"_id": "69d0b67e176b2e74ad5c8659", "resource": "ticket", "action": "reopen"},
      {"_id": "69d0b67e176b2e74ad5c865c", "resource": "comment", "action": "create"},
      {"_id": "69d0b67e176b2e74ad5c865f", "resource": "comment", "action": "view"},
      {"_id": "69d0b67e176b2e74ad5c8662", "resource": "comment", "action": "update"},
      {"_id": "69d0b67e176b2e74ad5c8665", "resource": "comment", "action": "delete"},
      {"_id": "69d0b67e176b2e74ad5c8668", "resource": "attachment", "action": "upload"},
      {"_id": "69d0b67e176b2e74ad5c866b", "resource": "attachment", "action": "view"},
      {"_id": "69d0b67e176b2e74ad5c866e", "resource": "attachment", "action": "delete"},
      {"_id": "69d0b67e176b2e74ad5c8671", "resource": "team", "action": "create"},
      {"_id": "69d0b67e176b2e74ad5c8674", "resource": "team", "action": "view"},
      {"_id": "69d0b67e176b2e74ad5c8677", "resource": "team", "action": "update"},
      {"_id": "69d0b67e176b2e74ad5c867a", "resource": "team", "action": "delete"},
      {"_id": "69d0b67e176b2e74ad5c867d", "resource": "user", "action": "create"},
      {"_id": "69d0b67e176b2e74ad5c8680", "resource": "user", "action": "view"},
      {"_id": "69d0b67e176b2e74ad5c8683", "resource": "user", "action": "update"},
      {"_id": "69d0b67e176b2e74ad5c8686", "resource": "user", "action": "delete"},
      {"_id": "69d0b67e176b2e74ad5c8689", "resource": "user", "action": "assign_role"},
      {"_id": "69d0b67e176b2e74ad5c868c", "resource": "role", "action": "create"},
      {"_id": "69d0b67e176b2e74ad5c868f", "resource": "role", "action": "view"},
      {"_id": "69d0b67e176b2e74ad5c8692", "resource": "role", "action": "update"},
      {"_id": "69d0b67e176b2e74ad5c8695", "resource": "role", "action": "delete"},
      {"_id": "69d0b67e176b2e74ad5c8698", "resource": "permission", "action": "view"},
      {"_id": "69d0b67e176b2e74ad5c869b", "resource": "permission", "action": "assign"},
      {"_id": "69d0b67e176b2e74ad5c869e", "resource": "dashboard", "action": "view"},
      {"_id": "69d0b67e176b2e74ad5c86a1", "resource": "report", "action": "view"},
      {"_id": "69d0b67e176b2e74ad5c86a4", "resource": "report", "action": "export"},
      {"_id": "69d0b67e176b2e74ad5c86a7", "resource": "settings", "action": "view"},
      {"_id": "69d0b67e176b2e74ad5c86aa", "resource": "settings", "action": "update"}
    ];
  }
}