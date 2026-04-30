import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../widgets/menu_drawer.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final String _baseUrl = "https://ticketapi.dcstechnosis.com";

  List<dynamic> _teams = [];
  List<dynamic> _users = [];
  bool _isLoading = true;

  // Theme Colors
  final Color primaryYellow = const Color(0xFFF3C300);
  final Color navyBlue = const Color(0xFF1E293B);
  final Color backgroundGray = const Color(0xFFF8FAFC);

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
      Options options = Options(headers: {"Authorization": "Bearer $token"});

      final responses = await Future.wait([
        Dio().get("$_baseUrl/api/teams", options: options),
        Dio().get("$_baseUrl/api/users", options: options),
      ]);

      var teamsData = responses[0].data;
      var usersData = responses[1].data;

      setState(() {
        if (teamsData is Map && teamsData.containsKey('data'))
          _teams = teamsData['data'];
        else if (teamsData is List) _teams = teamsData;

        if (usersData is Map && usersData.containsKey('data'))
          _users = usersData['data'];
        else if (usersData is List)
          _users = usersData;
        else if (usersData is Map && usersData.containsKey('users'))
          _users = usersData['users'];

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("Failed to load data", e);
    }
  }

  void _showError(String fallbackMsg, dynamic e) {
    String msg = fallbackMsg;
    if (e is DioException) {
      if (e.response?.statusCode == 401) {
        msg = "Session expired or unauthorized. Please log in again.";
      } else {
        msg = e.response?.data?['message'] ?? e.message ?? fallbackMsg;
      }
    }
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // 🔥 BULLETPROOF EXTRACTOR: Safely matches User IDs to get Names
  String _extractLeadName(dynamic leadData) {
    if (leadData == null) return "Unassigned";

    if (leadData is Map) {
      return leadData['name']?.toString() ?? "Unknown";
    }

    String leadId = leadData.toString();
    for (var u in _users) {
      String uId = (u['_id'] ?? u['id']).toString();
      if (uId == leadId) {
        return u['name']?.toString() ?? "Unknown";
      }
    }

    return "Unknown";
  }

  String _extractUserName(dynamic userData) {
    if (userData == null) return "Unknown";
    if (userData is Map) return userData['name']?.toString() ?? "Unknown";

    String userId = userData.toString();
    for (var u in _users) {
      String uId = (u['_id'] ?? u['id']).toString();
      if (uId == userId) {
        return u['name']?.toString() ?? "Unknown";
      }
    }

    return "Unknown";
  }

  // --- CREATE / EDIT TEAM DIALOG ---
  Future<void> _showCreateOrEditTeamDialog({dynamic team}) async {
    bool isEdit = team != null;
    String teamId = isEdit ? (team['_id'] ?? team['id']).toString() : "";

    final TextEditingController nameCtrl =
        TextEditingController(text: isEdit ? team['name'] : "");
    final TextEditingController descCtrl =
        TextEditingController(text: isEdit ? team['description'] : "");

    String? selectedLeadId;
    if (isEdit && team['teamLead'] != null) {
      selectedLeadId = team['teamLead'] is Map
          ? team['teamLead']['_id']?.toString()
          : team['teamLead'].toString();
    }

    List<String> selectedMemberIds = [];
    if (isEdit && team['members'] != null) {
      selectedMemberIds = List<String>.from((team['members'] as List)
          .map((m) => m is Map ? m['_id']?.toString() : m.toString()));
    }

    bool confirm = await showDialog(
            context: context,
            builder: (context) {
              return StatefulBuilder(builder: (context, setDialogState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  contentPadding: const EdgeInsets.all(14),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isEdit ? "Edit Team" : "Create New Team",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context, false),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints())
                    ],
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("TEAM NAME",
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey)),
                          const SizedBox(height: 8),
                          _buildDialogTextField(
                              nameCtrl, "e.g. Support Team Alpha"),
                          const SizedBox(height: 20),
                          const Text("TEAM LEAD",
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey)),
                          const SizedBox(height: 8),
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.grey.shade300)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedLeadId,
                                isExpanded: true,
                                hint: const Text("Select lead",
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.grey)),
                                icon: const Icon(Icons.keyboard_arrow_down,
                                    color: Colors.grey),
                                items: _users.map((u) {
                                  return DropdownMenuItem<String>(
                                    value: (u['_id'] ?? u['id']).toString(),
                                    child: Text(u['name'] ?? 'Unknown',
                                        style: const TextStyle(fontSize: 14)),
                                  );
                                }).toList(),
                                onChanged: (val) =>
                                    setDialogState(() => selectedLeadId = val),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text("DESCRIPTION",
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey)),
                          const SizedBox(height: 8),
                          _buildDialogTextField(descCtrl,
                              "Brief description of the team's purpose",
                              maxLines: 2),
                          const SizedBox(height: 24),
                          const Text("MEMBERS",
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.grey.shade200)),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _users.map((u) {
                                String uId = (u['_id'] ?? u['id']).toString();
                                bool isSelected =
                                    selectedMemberIds.contains(uId);
                                return FilterChip(
                                  label: Text(u['name'] ?? 'Unknown',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: isSelected
                                              ? Colors.black
                                              : Colors.black87)),
                                  selected: isSelected,
                                  selectedColor: primaryYellow.withOpacity(0.3),
                                  checkmarkColor: Colors.black87,
                                  backgroundColor: Colors.white,
                                  side: BorderSide(
                                      color: isSelected
                                          ? primaryYellow
                                          : Colors.grey.shade300),
                                  onSelected: (selected) {
                                    setDialogState(() {
                                      if (selected)
                                        selectedMemberIds.add(uId);
                                      else
                                        selectedMemberIds.remove(uId);
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryYellow,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8))),
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(
                                  isEdit ? "Save Changes" : "Create Team",
                                  style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
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

      Map<String, dynamic> payload = {
        "name": nameCtrl.text.trim(),
        "description": descCtrl.text.trim(),
        if (selectedLeadId != null) "teamLead": selectedLeadId,
        "members": selectedMemberIds,
      };

      if (isEdit) {
        await Dio().patch("$_baseUrl/api/teams/$teamId",
            data: payload,
            options: Options(headers: {"Authorization": "Bearer $token"}));
      } else {
        await Dio().post("$_baseUrl/api/teams",
            data: payload,
            options: Options(headers: {"Authorization": "Bearer $token"}));
      }

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEdit ? "Team updated!" : "Team created!"),
            backgroundColor: Colors.green));
      _fetchData();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(isEdit ? "Error updating team" : "Error creating team", e);
    }
  }

  // --- DELETE TEAM ---
  Future<void> _deleteTeam(String teamId) async {
    bool confirm = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
                  title: const Text("Delete Team",
                      style: TextStyle(color: Colors.red)),
                  content: const Text(
                      "Are you sure you want to permanently delete this team?"),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel")),
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Delete",
                            style: TextStyle(color: Colors.white))),
                  ],
                )) ??
        false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");
      await Dio().delete("$_baseUrl/api/teams/$teamId",
          options: Options(headers: {"Authorization": "Bearer $token"}));
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Team deleted"), backgroundColor: Colors.green));
      _fetchData();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("Error deleting team", e);
    }
  }

  // --- VIEW TEAM DIALOG ---
  void _showViewTeamDialog(dynamic team) {
    List<dynamic> members = team['members'] ?? [];
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: Text(team['name'] ?? 'Team',
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Description",
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(team['description'] ?? 'No description provided.',
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 16),
                  Text("Team Members (${members.length})",
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  members.isEmpty
                      ? const Text("No members assigned.")
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: members.map((m) {
                            return Chip(
                              label: Text(_extractUserName(m),
                                  style: const TextStyle(fontSize: 12)),
                              backgroundColor: Colors.blue.shade50,
                              side: BorderSide.none,
                            );
                          }).toList(),
                        )
                ],
              ),
            ));
  }

  Widget _buildDialogTextField(TextEditingController controller, String hint,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalTeams = _teams.length;
    int totalMembers = _teams.fold(
        0, (sum, team) => sum + ((team['members'] as List?)?.length ?? 0));
    int openTickets = 0;
    int resolvedTickets = 0;

    return Scaffold(
      backgroundColor: backgroundGray,
      drawer: const MenuDrawer(currentRoute: "teams"),
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
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildKPIGrid(
                        totalTeams, totalMembers, openTickets, resolvedTickets),
                    const SizedBox(height: 24),
                    _buildTeamsList(),
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
              Text("Teams",
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: navyBlue)),
              const SizedBox(height: 4),
              Text("Organize your support staff into focused teams",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _showCreateOrEditTeamDialog(),
          icon: const Icon(Icons.add, size: 18, color: Colors.black),
          label: const Text("New Team",
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

  Widget _buildKPIGrid(int teams, int members, int open, int resolved) {
    return LayoutBuilder(builder: (context, constraints) {
      double width = constraints.maxWidth;
      double cardWidth = width > 800 ? (width - 48) / 4 : (width - 16) / 2;

      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildKPICard("Total Teams", "$teams",
              Icons.dashboard_customize_outlined, cardWidth),
          _buildKPICard("Total Members", "$members", Icons.people_alt_outlined,
              cardWidth),
          _buildKPICard(
              "Open Tickets", "$open", Icons.folder_open_outlined, cardWidth),
          _buildKPICard(
              "Resolved", "$resolved", Icons.check_circle_outline, cardWidth),
        ],
      );
    });
  }

  Widget _buildKPICard(String title, String val, IconData icon, double width) {
    return Container(
      width: width,
      height: 110,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 15,
                offset: const Offset(0, 4))
          ]),
      child: Stack(
        children: [
          Positioned(
            left: 20,
            top: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(val,
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: navyBlue)),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 70,
              decoration: BoxDecoration(
                  color: primaryYellow.withOpacity(0.15),
                  borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                      topLeft: Radius.circular(60),
                      bottomLeft: Radius.circular(60))),
            ),
          ),
          Positioned(
            right: 20,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: primaryYellow,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: primaryYellow.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ]),
                child: Icon(icon, size: 22, color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 COMPLETELY FLUID LAYOUT (No more RenderFlex errors)
  Widget _buildTeamsList() {
    if (_teams.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200)),
        child: const Column(
          children: [
            Icon(Icons.group_off_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text("No teams created yet.",
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
          children: _teams
              .map((t) => SizedBox(
                    width: (constraints.maxWidth - 16) / 2,
                    child: _buildTeamCard(t),
                  ))
              .toList(),
        );
      }

      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _teams.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) => _buildTeamCard(_teams[index]),
      );
    });
  }

  Widget _buildTeamCard(dynamic team) {
    String teamId = (team['_id'] ?? team['id']).toString();
    String name = team['name'] ?? 'Unnamed Team';
    String desc = team['description'] ?? 'No description';
    int memberCount = (team['members'] as List?)?.length ?? 0;

    String leadName = _extractLeadName(team['teamLead']);
    String leadInitials =
        leadName != "Unassigned" && leadName != "Unknown" && leadName.isNotEmpty
            ? leadName[0].toUpperCase()
            : "-";

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
        mainAxisSize: MainAxisSize.min, // 🔥 CRITICAL for preventing Overflow
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 8, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(name,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: navyBlue))),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text("$memberCount members",
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold)),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onSelected: (val) {
                        if (val == 'edit')
                          _showCreateOrEditTeamDialog(team: team);
                        if (val == 'delete') _deleteTeam(teamId);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [
                              Icon(Icons.edit_outlined,
                                  size: 18, color: Colors.blue),
                              SizedBox(width: 8),
                              Text("Edit Team")
                            ])),
                        const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text("Delete Team",
                                  style: TextStyle(color: Colors.red))
                            ])),
                      ],
                    )
                  ],
                ),
                Text(desc,
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade100),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey.shade100,
                        child: Text(leadInitials,
                            style: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 12))),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Team Lead",
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold)),
                        Text(leadName,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Resolution Rate",
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600)),
                    Text("0%",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryYellow)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                        value: 0.0,
                        backgroundColor: Colors.grey.shade100,
                        minHeight: 6)),
              ],
            ),
          ),

          const SizedBox(
              height: 16), // 🔥 Replacing Spacer with a safe SizedBox
          Divider(height: 1, color: Colors.grey.shade100),

          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showViewTeamDialog(team),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility_outlined,
                            size: 16, color: Colors.grey),
                        SizedBox(width: 6),
                        Text("View Details",
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 24, color: Colors.grey.shade200),
              Expanded(
                child: InkWell(
                  onTap: () => _showCreateOrEditTeamDialog(team: team),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add_alt_1_outlined,
                            size: 16, color: Colors.grey),
                        SizedBox(width: 6),
                        Text("Manage Members",
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
