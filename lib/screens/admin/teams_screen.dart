import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../widgets/menu_drawer.dart';
import '../../constants/api_constants.dart';
import '../../providers/theme_provider.dart';
import '../common/profile_screen.dart'; // Imported for App Bar Avatar Action

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final String _baseUrl = ApiConstants.baseUrl;
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allTeams = [];
  List<dynamic> _filteredTeams = [];
  List<dynamic> _users = [];

  int _openTicketsCount = 0;
  int _resolvedTicketsCount = 0;
  bool _isLoading = true;

  // APP BAR USER PROFILE DATA
  String _firstName = "User";
  String _initials = "U";
  String? _profileImageUrl;

  // STRICT PERMISSION FLAGS
  bool _canViewTeam = false;
  bool _canCreateTeam = false;
  bool _canUpdateTeam = false;
  bool _canDeleteTeam = false;

  String _selectedSort = 'A-Z';
  final List<String> _sortOptions = ['A-Z', 'Z-A', 'Most Members', 'Fewest Members'];

  @override
  void initState() {
    super.initState();
    _loadDataAndPermissions();
  }

  Future<void> _loadDataAndPermissions() async {
    setState(() => _isLoading = true);
    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");
      String? userDataString = await storage.read(key: "user_data");

      // 1. SET USER PROFILE FOR APP BAR & PERMISSIONS
      if (userDataString != null) {
        final userData = jsonDecode(userDataString);

        // Setup Avatar/Initials
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

        _canViewTeam = false;
        _canCreateTeam = false;
        _canUpdateTeam = false;
        _canDeleteTeam = false;

        if (userData['permissions'] != null && userData['permissions'] is List) {
          for (var perm in userData['permissions']) {
            String res = perm['resource']?.toString().toLowerCase().trim() ?? '';
            String act = perm['action']?.toString().toLowerCase().trim() ?? '';

            if (res == 'team') {
              if (act == 'view' || act == 'view_all') _canViewTeam = true;
              if (act == 'create') _canCreateTeam = true;
              if (act == 'update' || act == 'edit') _canUpdateTeam = true;
              if (act == 'delete' || act == 'dlt') _canDeleteTeam = true;
            }
          }
        }
      }

      Options options = Options(headers: {"Authorization": "Bearer $token"});

      // 2. FETCH TEAMS, USERS AND TICKETS
      final responses = await Future.wait([
        Dio().get("$_baseUrl/api/teams", options: options).catchError((e) => Response(requestOptions: RequestOptions(path: ''))),
        Dio().get("$_baseUrl/api/users", options: options).catchError((e) => Response(requestOptions: RequestOptions(path: ''))),
        // 🔥 FIX 1: ADDED ?limit=10000 so it fetches ALL tickets for an accurate count, not just Page 1
        Dio().get("$_baseUrl/api/tickets?limit=10000", options: options).catchError((e) => Response(requestOptions: RequestOptions(path: ''))),
      ]);

      var teamsData = responses[0].data;
      var usersData = responses[1].data;
      var ticketsData = responses[2].data;

      // Extract Base Teams
      List<dynamic> parsedTeams = [];
      if (teamsData is Map) parsedTeams = teamsData['data'] ?? teamsData['teams'] ?? teamsData['docs'] ?? [];
      else if (teamsData is List) parsedTeams = teamsData;

      // FETCH MEMBERS FOR ALL TEAMS TO UPDATE CARDS CORRECTLY (N+1 Fetch)
      List<Future<Response>> memberRequests = [];
      for (var t in parsedTeams) {
        String tId = (t['_id'] ?? t['id']).toString();
        memberRequests.add(Dio().get("$_baseUrl/api/teams/$tId/members", options: options));
      }

      var memberResponses = await Future.wait(memberRequests.map((req) => req.catchError((e) => Response(requestOptions: RequestOptions(path: ''), data: []))));

      for (int i = 0; i < parsedTeams.length; i++) {
        var mData = memberResponses[i].data;
        List<dynamic> mList = [];
        if (mData is Map) mList = mData['data'] ?? mData['members'] ?? mData['users'] ?? [];
        else if (mData is List) mList = mData;

        parsedTeams[i]['fetched_members'] = mList;

        // Auto-extract exact Lead Name directly from members API
        var leadObj = mList.cast<Map<String, dynamic>?>().firstWhere((m) => (m?['role'] ?? '').toString().toLowerCase() == 'lead', orElse: () => null);
        if (leadObj != null) {
          String leadName = 'Unknown';
          if (leadObj['userId'] is Map) leadName = leadObj['userId']['name'] ?? 'Unknown';
          else if (leadObj['user'] is Map) leadName = leadObj['user']['name'] ?? 'Unknown';
          else if (leadObj['name'] != null) leadName = leadObj['name'];
          parsedTeams[i]['fetched_lead_name'] = leadName;
        }
      }

      if (!mounted) return;

      setState(() {
        _allTeams = parsedTeams;

        if (usersData is Map) _users = usersData['data'] ?? usersData['users'] ?? usersData['docs'] ?? [];
        else if (usersData is List) _users = usersData;

        List<dynamic> parsedTickets = [];
        if (ticketsData is Map) parsedTickets = ticketsData['data'] ?? ticketsData['tickets'] ?? ticketsData['docs'] ?? [];
        else if (ticketsData is List) parsedTickets = ticketsData;

        // 🔥 FIX 2: EXACTLY MATCHING THE TICKETS SCREEN LOGIC
        _openTicketsCount = parsedTickets.where((t) {
          String s = (t['status'] ?? '').toString().trim().toLowerCase();
          return s == 'open'; // Changed from contains to strict equality
        }).length;

        _resolvedTicketsCount = parsedTickets.where((t) {
          String s = (t['status'] ?? '').toString().trim().toLowerCase();
          return s == 'resolved' || s == 'closed'; // Added closed to match exact logic
        }).length;

        _filteredTeams = _allTeams;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error fetching data: $e");
    }
  }

  void _applyFilters() {
    setState(() {
      String query = _searchController.text.toLowerCase();

      _filteredTeams = _allTeams.where((t) {
        final name = (t['name'] ?? '').toLowerCase();
        final desc = (t['description'] ?? '').toLowerCase();
        return name.contains(query) || desc.contains(query);
      }).toList();

      if (_selectedSort == 'A-Z') {
        _filteredTeams.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
      } else if (_selectedSort == 'Z-A') {
        _filteredTeams.sort((a, b) => (b['name'] ?? '').compareTo(a['name'] ?? ''));
      } else if (_selectedSort == 'Most Members') {
        _filteredTeams.sort((a, b) => ((b['fetched_members'] as List?)?.length ?? 0).compareTo((a['fetched_members'] as List?)?.length ?? 0));
      } else if (_selectedSort == 'Fewest Members') {
        _filteredTeams.sort((a, b) => ((a['fetched_members'] as List?)?.length ?? 0).compareTo((b['fetched_members'] as List?)?.length ?? 0));
      }
    });
  }

  String _extractRoleName(dynamic user) {
    if (user == null) return 'user';
    if (user['roleId'] != null && user['roleId'] is Map && user['roleId']['name'] != null) return user['roleId']['name'].toString();
    if (user['role'] != null && user['role'] is Map && user['role']['name'] != null) return user['role']['name'].toString();
    if (user['role'] != null && user['role'] is String) return user['role'].toString();
    if (user['roles'] != null && user['roles'] is List && user['roles'].isNotEmpty) {
      var firstRole = user['roles'][0];
      if (firstRole is String) return firstRole;
      if (firstRole is Map && firstRole['name'] != null) return firstRole['name'].toString();
    }
    return 'User';
  }

  // =========================================================================
  // 🔥 CREATE / EDIT TEAM BOTTOM SHEET
  // =========================================================================
  void _showCreateOrEditTeamDialog({dynamic team}) {
    bool isEdit = team != null;
    String teamId = isEdit ? (team['_id'] ?? team['id']).toString() : "";

    final TextEditingController nameCtrl = TextEditingController(text: isEdit ? team['name'] : "");
    final TextEditingController descCtrl = TextEditingController(text: isEdit ? team['description'] : "");

    String? selectedLeadId;
    if (isEdit && team['teamLead'] != null) {
      selectedLeadId = team['teamLead'] is Map ? team['teamLead']['_id']?.toString() : team['teamLead'].toString();
    }

    List<String> selectedMemberIds = [];
    bool isSubmitting = false;

    bool isFetchingEditData = isEdit;
    bool hasInitiatedFetch = false;

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

        return StatefulBuilder(builder: (context, setModalState) {

          if (isFetchingEditData) {
            if (!hasInitiatedFetch) {
              hasInitiatedFetch = true;
              Future.microtask(() async {
                try {
                  const storage = FlutterSecureStorage();
                  String? token = await storage.read(key: "jwt_token");
                  var res = await Dio().get("$_baseUrl/api/teams/$teamId/members", options: Options(headers: {"Authorization": "Bearer $token"}));

                  var resData = res.data;
                  List<dynamic> dataList = [];
                  if (resData is Map) dataList = resData['data'] ?? resData['members'] ?? resData['users'] ?? [];
                  else if (resData is List) dataList = resData;

                  List<String> fetchedIds = [];
                  String? fetchedLeadId;

                  for (var m in dataList) {
                    String? uid;
                    if (m is Map) {
                      uid = (m['userId']?['_id'] ?? m['userId'] ?? m['user']?['_id'] ?? m['user'])?.toString();
                      if (m['role']?.toString().toLowerCase() == 'lead') fetchedLeadId = uid;
                    }
                    if (uid != null && uid.isNotEmpty) fetchedIds.add(uid);
                  }

                  if (context.mounted) {
                    setModalState(() {
                      selectedMemberIds.clear();
                      selectedMemberIds.addAll(fetchedIds.toSet().toList());
                      selectedLeadId = fetchedLeadId;
                      isFetchingEditData = false;
                    });
                  }
                } catch (e) {
                  debugPrint("Edit member fetch error: $e");
                  if (context.mounted) setModalState(() => isFetchingEditData = false);
                }
              });
            }

            return Container(
              height: 300,
              decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFFF3C300)),
                    const SizedBox(height: 16),
                    Text("Fetching Team Details...", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          }

          List<dynamic> availableLeads = _users.where((u) {
            String uId = (u['_id'] ?? u['id']).toString();
            return selectedMemberIds.contains(uId);
          }).toList();

          if (selectedLeadId != null && !selectedMemberIds.contains(selectedLeadId)) {
            selectedLeadId = null;
          }

          Future<void> submitForm() async {
            if (nameCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Team Name is required!"), backgroundColor: Colors.orange));
              return;
            }

            setModalState(() => isSubmitting = true);

            try {
              const storage = FlutterSecureStorage();
              String? token = await storage.read(key: "jwt_token");
              Options jsonOptions = Options(
                  headers: {
                    "Authorization": "Bearer $token",
                    "Content-Type": "application/json"
                  }
              );

              Map<String, dynamic> basePayload = {
                "name": nameCtrl.text.trim(),
                "description": descCtrl.text.trim(),
              };

              String finalTeamId = teamId;

              if (isEdit) {
                await Dio().patch("$_baseUrl/api/teams/$teamId", data: jsonEncode(basePayload), options: jsonOptions);
              } else {
                Response res = await Dio().post("$_baseUrl/api/teams", data: jsonEncode(basePayload), options: jsonOptions);
                finalTeamId = (res.data['data']?['_id'] ?? res.data['_id'] ?? '').toString();
              }

              if (finalTeamId.isNotEmpty) {
                try {
                  List<String> pureMemberIds = selectedMemberIds.toSet().toList();
                  List<Map<String, String>> syncPayload = pureMemberIds.map((id) {
                    return {
                      "userId": id,
                      "role": id == selectedLeadId ? "lead" : "agent"
                    };
                  }).toList();

                  await Dio().put(
                    "$_baseUrl/api/teams/$finalTeamId/members",
                    data: jsonEncode({ "members": syncPayload }),
                    options: jsonOptions,
                  );
                } on DioException catch (e) {
                  throw Exception("Members Sync Failed: ${e.response?.data ?? e.message}");
                }
              }

              if (!isEdit && finalTeamId.isNotEmpty && selectedLeadId != null) {
                try {
                  await Dio().patch(
                    "$_baseUrl/api/teams/$finalTeamId",
                    data: jsonEncode({ "teamLead": selectedLeadId }),
                    options: jsonOptions,
                  );
                } catch (e) {
                  debugPrint("Lead sync error: $e");
                }
              }

              if (!context.mounted) return;

              Navigator.pop(context);
              _loadDataAndPermissions();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? "Team Updated Successfully!" : "Team Created Successfully!"), backgroundColor: Colors.green));

            } catch (e) {
              setModalState(() => isSubmitting = false);
              String errorMsg = e.toString();
              if (e is DioException && e.response != null) {
                try {
                  errorMsg = e.response!.data['message']?.toString() ?? jsonEncode(e.response?.data);
                } catch (_) {
                  errorMsg = e.response?.data?.toString() ?? "Validation Failed";
                }
              }
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $errorMsg", maxLines: 2), backgroundColor: Colors.red));
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.9,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 50, height: 6, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                  Text(isEdit ? "Edit Team" : "Create New Team", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 24),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFormLabel("TEAM NAME", isDark),
                          TextField(controller: nameCtrl, style: TextStyle(color: textColor), decoration: _buildInputDecoration("e.g. Marketing Team", Icons.group_outlined, inputColor, borderColor, isDark)),
                          const SizedBox(height: 20),

                          _buildFormLabel("DESCRIPTION", isDark),
                          TextField(controller: descCtrl, maxLines: 2, style: TextStyle(color: textColor), decoration: _buildInputDecoration("Brief description...", Icons.description_outlined, inputColor, borderColor, isDark)),
                          const SizedBox(height: 24),

                          _buildFormLabel("ASSIGN MEMBERS (${selectedMemberIds.length} selected)", isDark),
                          const SizedBox(height: 8),

                          if (_users.isEmpty)
                            Text("No users available", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey))
                          else
                            LayoutBuilder(
                                builder: (context, constraints) {
                                  double boxWidth = (constraints.maxWidth - 12) / 2;
                                  return Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: _users.map((u) {
                                      String uId = (u['_id'] ?? u['id']).toString();
                                      bool isSelected = selectedMemberIds.contains(uId);
                                      String uName = u['name']?.toString() ?? 'Unknown';
                                      String uInitials = uName.isNotEmpty ? uName[0].toUpperCase() : 'U';
                                      String uRole = _extractRoleName(u);

                                      return InkWell(
                                        onTap: () {
                                          setModalState(() {
                                            if (isSelected) {
                                              selectedMemberIds.remove(uId);
                                              if (selectedLeadId == uId) selectedLeadId = null;
                                            } else {
                                              selectedMemberIds.add(uId);
                                            }
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          width: constraints.maxWidth > 600 ? 250 : boxWidth,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isSelected ? (isDark ? const Color(0xFFF3C300).withOpacity(0.1) : Colors.orange.shade50) : (isDark ? Colors.white10 : Colors.white),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: isSelected ? const Color(0xFFF3C300) : borderColor),
                                          ),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: Checkbox(
                                                  value: isSelected,
                                                  activeColor: const Color(0xFFF3C300),
                                                  checkColor: Colors.black,
                                                  side: BorderSide(color: isDark ? Colors.white54 : Colors.grey.shade400),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                                  onChanged: (val) {
                                                    setModalState(() {
                                                      if (val == true) {
                                                        selectedMemberIds.add(uId);
                                                      } else {
                                                        selectedMemberIds.remove(uId);
                                                        if (selectedLeadId == uId) selectedLeadId = null;
                                                      }
                                                    });
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              CircleAvatar(
                                                radius: 14,
                                                backgroundColor: const Color(0xFFFEF9C3),
                                                child: Text(uInitials, style: const TextStyle(color: Color(0xFFB48600), fontWeight: FontWeight.bold, fontSize: 10)),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(uName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor), overflow: TextOverflow.ellipsis),
                                                    Text(uRole, style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey.shade500), overflow: TextOverflow.ellipsis),
                                                  ],
                                                ),
                                              )
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                }
                            ),
                          const SizedBox(height: 24),

                          _buildFormLabel("TEAM LEAD (Select Members First)", isDark),
                          DropdownButtonFormField<String?>(
                            value: selectedLeadId,
                            dropdownColor: bgColor,
                            style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                            decoration: _buildInputDecoration("", Icons.star_border, inputColor, borderColor, isDark),
                            hint: Text(availableLeads.isEmpty ? "Add members to select lead" : "Select Lead", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade400)),
                            items: availableLeads.map((u) {
                              return DropdownMenuItem<String>(
                                value: (u['_id'] ?? u['id']).toString(),
                                child: Text(u['name']?.toString() ?? 'Unknown', style: const TextStyle(fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: availableLeads.isEmpty ? null : (val) => setModalState(() => selectedLeadId = val),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),

                  Container(
                    width: double.infinity, height: 55,
                    margin: const EdgeInsets.only(top: 16),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: isDark ? const Color(0xFFF3C300) : const Color(0xFF1E293B), foregroundColor: isDark ? Colors.black : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                      onPressed: isSubmitting ? null : submitForm,
                      child: isSubmitting ? CircularProgressIndicator(color: isDark ? Colors.black : Colors.white) : Text(isEdit ? "Save Changes" : "Create Team", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  // =========================================================================
  // 🔥 DYNAMIC VIEW TEAM DIALOG
  // =========================================================================
  void _showViewTeamDialog(dynamic team, bool isDark, Color bgColor, Color textColor, Color subTextColor, Color borderColor) {
    String teamId = (team['_id'] ?? team['id']).toString();
    bool isFetchingMembers = true;
    List<dynamic> fetchedMembers = [];

    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setDialogState) {

                if (isFetchingMembers && fetchedMembers.isEmpty) {
                  const FlutterSecureStorage().read(key: "jwt_token").then((token) {
                    Dio().get("$_baseUrl/api/teams/$teamId/members", options: Options(headers: {"Authorization": "Bearer $token"}))
                        .then((res) {
                      if (context.mounted) {
                        setDialogState(() {
                          var resData = res.data;
                          if (resData is Map) fetchedMembers = resData['data'] ?? resData['members'] ?? resData['users'] ?? [];
                          else if (resData is List) fetchedMembers = resData;
                          isFetchingMembers = false;
                        });
                      }
                    }).catchError((e) {
                      if (context.mounted) setDialogState(() => isFetchingMembers = false);
                    });
                  });
                }

                return AlertDialog(
                  backgroundColor: bgColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  titlePadding: const EdgeInsets.all(20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(team['name'] ?? 'Team Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor))),
                      IconButton(icon: Icon(Icons.close, color: textColor), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("MEMBERS", style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 12),

                        isFetchingMembers
                            ? const Padding(padding: EdgeInsets.all(20.0), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                            : fetchedMembers.isEmpty
                            ? Padding(padding: const EdgeInsets.all(20.0), child: Text("No members in this team.", style: TextStyle(color: subTextColor)))
                            : Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: fetchedMembers.length,
                            separatorBuilder: (c, i) => Divider(height: 1, color: borderColor),
                            itemBuilder: (c, i) {
                              var m = fetchedMembers[i];

                              String mName = 'Unknown';
                              if (m is Map) {
                                if (m['userId'] is Map) mName = m['userId']['name'] ?? 'Unknown';
                                else if (m['user'] is Map) mName = m['user']['name'] ?? 'Unknown';
                                else if (m['name'] != null) mName = m['name'];
                              }

                              String mRole = (m['role'] ?? 'Agent').toString().toUpperCase();
                              bool isLead = mRole == 'LEAD';

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFFEF9C3),
                                  child: Text(mName.isNotEmpty ? mName[0].toUpperCase() : 'U', style: const TextStyle(color: Color(0xFFB48600), fontWeight: FontWeight.bold)),
                                ),
                                title: Text(mName, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14)),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: isLead ? const Color(0xFFFEF9C3) : (isDark ? Colors.white10 : Colors.grey.shade100),
                                      borderRadius: BorderRadius.circular(6)
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isLead) const Icon(Icons.star, color: Color(0xFFB48600), size: 12),
                                      if (isLead) const SizedBox(width: 4),
                                      Text(mRole, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isLead ? const Color(0xFFB48600) : (isDark ? Colors.white70 : Colors.grey.shade700))),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      ],
                    ),
                  ),
                );
              }
          );
        }
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
      prefixIcon: Icon(icon, size: 18, color: isDark ? Colors.white54 : Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF3C300), width: 2)),
    );
  }

  Future<void> _deleteTeam(String teamId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) {
        final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text("Delete Team", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
          content: Text("Are you sure you want to permanently delete this team?", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
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
      await Dio().delete("$_baseUrl/api/teams/$teamId", options: Options(headers: {"Authorization": "Bearer $token"}));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Team deleted successfully."), backgroundColor: Colors.green));
      }
      _loadDataAndPermissions();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error deleting team"), backgroundColor: Colors.red));
      }
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
      title: const Text("Teams", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
        if (val == 'profile') Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())).then((_) => _loadDataAndPermissions());
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
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white70 : Colors.grey.shade500;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;

    int totalTeams = _allTeams.length;
    int totalUsers = _users.length;

    return Scaffold(
      backgroundColor: bgColor,
      drawer: const MenuDrawer(currentRoute: "teams"),
      appBar: _buildModernAppBar(), // 🔥 USING NEW GLOBAL APP BAR
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF3C300)))
          : RefreshIndicator(
        onRefresh: _loadDataAndPermissions,
        color: const Color(0xFF1E293B),
        child: LayoutBuilder(
            builder: (context, constraints) {
              bool isDesktop = constraints.maxWidth > 800;

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
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
                              Text("Teams Management", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
                              const SizedBox(height: 4),
                              Text("Organize your support staff into focused teams", style: TextStyle(color: subTextColor, fontSize: 13), overflow: TextOverflow.visible),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_canCreateTeam)
                          ElevatedButton.icon(
                            onPressed: () => _showCreateOrEditTeamDialog(),
                            icon: const Icon(Icons.add, size: 16, color: Colors.black),
                            label: const Text("New Team", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF3C300), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildKPIGrid(totalTeams, totalUsers, _openTicketsCount, _resolvedTicketsCount, isDark),
                    const SizedBox(height: 32),

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [Container(width: 5, height: 24, decoration: BoxDecoration(color: const Color(0xFFF3C300), borderRadius: BorderRadius.circular(10)), margin: const EdgeInsets.only(right: 12)), Text("All Teams (${_filteredTeams.length})", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor))]),
                              OutlinedButton.icon(
                                onPressed: _loadDataAndPermissions, icon: Icon(Icons.refresh, size: 16, color: textColor), label: Text("Refresh", style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600)),
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), side: BorderSide(color: borderColor)),
                              )
                            ],
                          ),
                          const SizedBox(height: 24),

                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: SizedBox(
                                  height: 42,
                                  child: TextField(
                                    controller: _searchController, onChanged: (val) => _applyFilters(),
                                    style: TextStyle(color: textColor, fontSize: 13),
                                    decoration: InputDecoration(hintText: "Search team name...", hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade400, fontSize: 13), filled: true, fillColor: isDark ? Colors.white10 : Colors.grey.shade50, prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.grey.shade400, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)), contentPadding: const EdgeInsets.symmetric(vertical: 0)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                  flex: 2,
                                  child: SizedBox(
                                      height: 42,
                                      child: _buildDropdown(_selectedSort, _sortOptions, (val) { setState(() => _selectedSort = val!); _applyFilters(); }, isDark)
                                  )
                              ),
                            ],
                          ),

                          Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Divider(color: isDark ? Colors.white12 : Colors.grey.shade100, height: 1)),

                          if (_filteredTeams.isEmpty)
                            Padding(
                                padding: const EdgeInsets.all(40.0),
                                child: Center(
                                    child: Column(
                                      children: [
                                        Icon(Icons.group_off_outlined, size: 60, color: isDark ? Colors.white24 : Colors.grey.shade300),
                                        const SizedBox(height: 16),
                                        Text("No teams found.", style: TextStyle(color: subTextColor, fontSize: 16, fontWeight: FontWeight.w500)),
                                      ],
                                    )
                                )
                            )
                          else
                            isDesktop ? _buildDesktopGrid(isDark, cardColor, textColor, subTextColor, borderColor, bgColor) : _buildMobileList(isDark, cardColor, textColor, subTextColor, borderColor, bgColor),
                        ],
                      ),
                    )
                  ],
                ),
              );
            }
        ),
      ),
    );
  }

  Widget _buildKPIGrid(int teams, int users, int open, int resolved, bool isDark) {
    return LayoutBuilder(builder: (context, constraints) {
      double width = constraints.maxWidth;
      double cardWidth = width > 800 ? (width - 48) / 4 : (width - 16) / 2;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildPremiumKPICard("Total Teams", "$teams", Icons.dashboard_customize_outlined, cardWidth, isDark),
          _buildPremiumKPICard("Total Users", "$users", Icons.people_alt_outlined, cardWidth, isDark),
          _buildPremiumKPICard("Open Tickets", "$open", Icons.folder_open_outlined, cardWidth, isDark),
          _buildPremiumKPICard("Closed", "$resolved", Icons.check_circle_outline, cardWidth, isDark),
        ],
      );
    });
  }

  Widget _buildPremiumKPICard(String title, String val, IconData icon, double width, bool isDark) {
    return Container(
      width: width,
      height: 100,
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade100), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Stack(
        children: [
          Positioned(right: -15, top: -15, child: Container(width: 70, height: 70, decoration: BoxDecoration(color: const Color(0xFFF3C300).withOpacity(0.05), shape: BoxShape.circle))),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(val, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                  ],
                ),
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF3C300), borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: const Color(0xFFF3C300).withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))]), child: Icon(icon, size: 20, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String currentValue, List<String> options, Function(String?) onChanged, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          isExpanded: true,
          icon: Icon(Icons.sort, color: isDark ? Colors.white54 : Colors.grey.shade500, size: 16),
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.w600),
          onChanged: onChanged,
          items: options.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))).toList(),
        ),
      ),
    );
  }

  Widget _buildDesktopGrid(bool isDark, Color cardColor, Color textColor, Color subTextColor, Color borderColor, Color bgColor) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: _filteredTeams.map((t) => SizedBox(
        width: 380,
        child: _buildTeamCard(t, isDark, cardColor, textColor, subTextColor, borderColor, bgColor),
      )).toList(),
    );
  }

  Widget _buildMobileList(bool isDark, Color cardColor, Color textColor, Color subTextColor, Color borderColor, Color bgColor) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredTeams.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _buildTeamCard(_filteredTeams[index], isDark, cardColor, textColor, subTextColor, borderColor, bgColor),
    );
  }

  Widget _buildTeamCard(dynamic team, bool isDark, Color cardColor, Color textColor, Color subTextColor, Color borderColor, Color bgColor) {
    String teamId = (team['_id'] ?? team['id']).toString();
    String name = team['name'] ?? 'Unnamed Team';
    String desc = team['description'] ?? 'No description';

    // Use dynamic data fetched locally
    List<dynamic> members = team['fetched_members'] ?? [];
    String leadName = team['fetched_lead_name'] ?? "No Lead Assigned";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(16), color: isDark ? const Color(0xFF1A1A1A) : Colors.white, boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),

          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: subTextColor),
              const SizedBox(width: 4),
              Text(leadName, style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 16),
              Icon(Icons.people_outline, size: 14, color: Colors.blue.shade600),
              const SizedBox(width: 4),
              Text("${members.length} Members", style: TextStyle(color: Colors.blue.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),

          if (desc.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(desc, style: TextStyle(color: subTextColor, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],

          Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: borderColor)),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_canViewTeam)
                _styledActionButton("View", Colors.grey.shade700, Icons.visibility_outlined, () => _showViewTeamDialog(team, isDark, bgColor, textColor, subTextColor, borderColor), isDark),
              if (_canViewTeam && (_canUpdateTeam || _canDeleteTeam)) const SizedBox(width: 8),
              if (_canUpdateTeam)
                _styledActionButton("Edit", Colors.orange.shade700, Icons.edit_outlined, () => _showCreateOrEditTeamDialog(team: team), isDark),
              if (_canUpdateTeam && _canDeleteTeam) const SizedBox(width: 8),
              if (_canDeleteTeam)
                _styledActionButton("Delete", Colors.red.shade600, Icons.delete_outline, () => _deleteTeam(teamId), isDark),
            ],
          )
        ],
      ),
    );
  }

  Widget _styledActionButton(String label, Color color, IconData icon, VoidCallback onTap, bool isDark) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 12),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withOpacity(0.05),
        side: BorderSide(color: color.withOpacity(0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}