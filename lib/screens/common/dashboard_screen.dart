import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/ticket_service.dart';
import '../../models/ticket.dart';
import '../../widgets/menu_drawer.dart';
import '../authscreen/login_screen.dart';
import '../common/profile_screen.dart';
import '../common/ticket_detail_screen.dart';
import '../common/ticket_screen.dart';
import '../constants/api_constants.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final String _baseUrl = ApiConstants.baseUrl;
  final TicketService _ticketService = TicketService();

  String _firstName = "User";
  String _initials = "U";
  String? _profileImageUrl;
  String _currentUserId = "";

  List<Ticket> _allTickets = [];
  bool _isLoading = true;

  bool _isAdmin = false;
  bool _canViewDashboard = true;
  bool _canViewUsers = false;
  bool _canViewAllTickets = false;
  bool _canViewOwnTickets = false;
  bool _canCreateTicket = false;
  bool _canUpdateTicket = false;
  bool _canDeleteTicket = false;
  bool _canChangePriority = false;
  bool _canUploadAttachment = false;

  bool get _hasAnyTicketViewAccess => _canViewAllTickets || _canViewOwnTickets;

  int _totalUsers = 0;
  String _rawUserDataString = "No Data Found";

  @override
  void initState() {
    super.initState();
    _fetchUserProfileLocally();
  }

  // 🔥 NEW: Helper method to catch expired tokens and force logout
  void _handleApiError(dynamic e) {
    if (!mounted) return;
    String errStr = e.toString().toLowerCase();

    // If it's a 401 Unauthorized error (Token Expired)
    if ((e is DioException && e.response?.statusCode == 401) || errStr.contains('401') || errStr.contains('unauthorized')) {
      Provider.of<AuthProvider>(context, listen: false).logout();
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false
      );
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Session expired. Please log in again."), backgroundColor: Colors.orange)
      );
    }
  }

  Future<void> _fetchUserProfileLocally() async {
    try {
      const storage = FlutterSecureStorage();
      String? userDataString = await storage.read(key: "user_data");

      if (userDataString != null) {
        _rawUserDataString = userDataString;

        final userData = jsonDecode(userDataString);
        setState(() {
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

          _currentUserId = (userData['_id'] ?? userData['id'] ?? '').toString();

          String userRole = userData['role']?.toString().toLowerCase().trim() ?? '';
          _isAdmin = (userRole == 'admin' || userRole == 'super admin');

          _canViewUsers = false;
          _canViewAllTickets = false;
          _canViewOwnTickets = false;
          _canCreateTicket = false;
          _canUpdateTicket = false;
          _canDeleteTicket = false;
          _canChangePriority = false;
          _canUploadAttachment = false;

          if (userData['permissions'] != null && userData['permissions'] is List) {
            for (var perm in userData['permissions']) {
              String res = perm['resource']?.toString().toLowerCase().trim() ?? '';
              String act = perm['action']?.toString().toLowerCase().trim() ?? '';

              if (res == 'user' && act == 'view') _canViewUsers = true;

              if (res == 'ticket') {
                if (act == 'view' || act == 'view_all') _canViewAllTickets = true;
                if (act == 'view_own') _canViewOwnTickets = true;
                if (act == 'create') _canCreateTicket = true;
                if (act == 'update' || act == 'edit') _canUpdateTicket = true;
                if (act == 'delete') _canDeleteTicket = true;
                if (act == 'change_priority') _canChangePriority = true;
              }
              if (res == 'attachment' && act == 'upload') _canUploadAttachment = true;
            }
          }
        });

        _loadDashboardData();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Dashboard Profile Error: $e");
      _rawUserDataString = "Error parsing data: $e";
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");

      if (_canViewUsers) {
        try {
          var usersRes = await Dio().get("$_baseUrl/api/users",
              options: Options(headers: {"Authorization": "Bearer ${token ?? ''}"}));
          if (usersRes.statusCode == 200) {
            var data = usersRes.data;
            List usersList = data is List ? data : (data['users'] ?? data['data'] ?? []);
            _totalUsers = usersList.length;
          } else {
            _totalUsers = 0;
          }
        } catch (e) {
          _totalUsers = 0;
          _handleApiError(e); // 🔥 Added error handler
        }
      }

      if (_hasAnyTicketViewAccess) {
        List<Ticket> tickets = [];
        try {
          tickets = await _ticketService.fetchTickets();

          if (!_canViewAllTickets && _canViewOwnTickets) {
            tickets = tickets.where((t) => t.createdBy == _currentUserId).toList();
          }
        } catch (e) {
          debugPrint("API Failed: $e");
          _handleApiError(e); // 🔥 Added error handler
        }

        if (mounted) {
          setState(() {
            _allTickets = tickets;
          });
        }
      }

      if (mounted) setState(() => _isLoading = false);

    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getDisplayTicketNumber(Ticket t) {
    try {
      var num = (t as dynamic).ticketNumber;
      if (num != null && num.toString().isNotEmpty) return num.toString();
    } catch (_) {}
    if (t.ticketId.isNotEmpty) return t.ticketId;
    return "TKT-${t.id.substring(t.id.length - 4)}";
  }

  // =========================================================================
  // 🔥 CREATE TICKET BOTTOM SHEET
  // =========================================================================
  void _openCreateTicketBottomSheet() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String localPriority = 'low';
    File? localImage;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
        final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final inputColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC);
        final textColor = isDark ? Colors.white : Colors.black;
        final labelColor = isDark ? Colors.grey.shade400 : const Color(0xFF64748B);

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {

            Future<void> pickImage() async {
              final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
              if (pickedFile != null) {
                setModalState(() => localImage = File(pickedFile.path));
              }
            }

            Future<void> submitForm() async {
              if (titleController.text.trim().isEmpty || descriptionController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields"), backgroundColor: Colors.orange));
                return;
              }

              setModalState(() => isSubmitting = true);

              int statusCode = await _ticketService.createTicket(
                titleController.text.trim(),
                descriptionController.text.trim(),
                localPriority,
                localImage,
              );

              if (!context.mounted) return;

              if (statusCode == 201 || statusCode == 200) {
                Navigator.pop(context);
                _loadDashboardData();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ticket Created Successfully!"), backgroundColor: Colors.green));
              } else if (statusCode == 401) {
                Navigator.pop(context);
                Provider.of<AuthProvider>(context, listen: false).logout();
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
              } else {
                setModalState(() => isSubmitting = false);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to create ticket. Server Error."), backgroundColor: Colors.red));
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 40, height: 5, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                      Text("Create New Ticket", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 20),

                      Text("SUBJECT / TITLE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: labelColor)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: titleController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(hintText: "E.g., Internet is down", hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: inputColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                      ),
                      const SizedBox(height: 20),

                      Text("DESCRIPTION", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: labelColor)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(hintText: "Describe the issue in detail...", hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: inputColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                      ),
                      const SizedBox(height: 20),

                      if (_canChangePriority) ...[
                        Text("PRIORITY", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: labelColor)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: localPriority,
                          dropdownColor: inputColor,
                          style: TextStyle(color: textColor, fontSize: 14),
                          decoration: InputDecoration(filled: true, fillColor: inputColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                          items: ['low', 'medium', 'high', 'critical'].map((String value) => DropdownMenuItem(value: value, child: Text(value.toUpperCase()))).toList(),
                          onChanged: (val) => setModalState(() => localPriority = val!),
                        ),
                        const SizedBox(height: 24),
                      ],

                      if (_canUploadAttachment) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: inputColor, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.blue.withOpacity(0.2) : const Color(0xFFEFF6FF), foregroundColor: isDark ? Colors.blue : const Color(0xFF1E293B), elevation: 0),
                                onPressed: pickImage,
                                icon: const Icon(Icons.add_photo_alternate_outlined),
                                label: const Text("Attach Photo"),
                              ),
                              const SizedBox(width: 16),
                              Expanded(child: Text(localImage != null ? "✅ Image attached" : "No image selected", style: TextStyle(color: localImage != null ? Colors.green : Colors.grey, fontSize: 13), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                      ] else ...[
                        const SizedBox(height: 10),
                      ],

                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: isSubmitting ? null : submitForm,
                          child: isSubmitting
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Submit Ticket", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
      drawer: const MenuDrawer(currentRoute: 'dashboard'),
      appBar: _buildModernAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF3C300)))
          : RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 24),

              // KPI Grid and Data Tables
              _buildDynamicKPIGrid(isDark),
              const SizedBox(height: 24),

              if (_hasAnyTicketViewAccess) ...[
                _buildRecentTicketsTable(isDark),
                const SizedBox(height: 24),
                _buildTicketOverview(isDark),
              ] else ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 60, color: isDark ? Colors.white24 : Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text("No tickets to display.", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.grey.shade500)),
                      ],
                    ),
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E293B),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: const Text("Dashboard", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      actions: [
        _buildAvatarMenu(),
      ],
    );
  }

  Widget _buildAvatarMenu() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return PopupMenuButton<String>(
      onSelected: (val) {
        if (val == 'profile') Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())).then((_) => _fetchUserProfileLocally());
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

  Widget _buildHeader(bool isDark) {
    Color textColor = isDark ? Colors.white : const Color(0xFF111827);
    Color subTextColor = isDark ? Colors.grey.shade400 : const Color(0xFF6B7280);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Good day, $_firstName 👋", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor), overflow: TextOverflow.ellipsis),
              Text("Here's your workspace overview", style: TextStyle(color: subTextColor, fontSize: 14)),
            ],
          ),
        ),
        if (_canCreateTicket)
          ElevatedButton.icon(
            onPressed: _openCreateTicketBottomSheet,
            icon: const Icon(Icons.add, size: 18, color: Colors.black),
            label: const Text("New Ticket", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF3C300),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
      ],
    );
  }

  Widget _buildDynamicKPIGrid(bool isDark) {
    return LayoutBuilder(builder: (context, constraints) {
      double width = constraints.maxWidth;
      double cardWidth = (width - 16) / 2;

      List<Widget> activeCards = [];

      if (_canViewUsers) {
        activeCards.add(_buildModernKPICard("Total Users", "$_totalUsers", Icons.people, isDark, cardWidth));
      }

      if (_hasAnyTicketViewAccess) {
        int totalT = _allTickets.length;
        int openT = _allTickets.where((t) => t.status.toLowerCase() == 'open').length;
        int resolvedT = _allTickets.where((t) => t.status.toLowerCase() == 'closed' || t.status.toLowerCase() == 'resolved').length;

        String prefix = _canViewAllTickets ? "Total" : "My";
        String openPrefix = _canViewAllTickets ? "Open" : "My Open";

        activeCards.add(_buildModernKPICard("$prefix Tickets", "$totalT", Icons.confirmation_number, isDark, cardWidth));
        activeCards.add(_buildModernKPICard(openPrefix, "$openT", Icons.folder_open, isDark, cardWidth));
        activeCards.add(_buildModernKPICard("Resolved", "$resolvedT", Icons.check_circle, isDark, cardWidth));
      }

      if (activeCards.isEmpty) return const SizedBox.shrink();

      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: activeCards,
      );
    });
  }

  Widget _buildModernKPICard(String title, String count, IconData icon, bool isDark, double width) {
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black;
    Color borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade100;

    return Container(
      width: width,
      height: 130,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: borderColor),
      ),
      child: Stack(
        children: [
          Positioned(right: -10, top: -10, child: CircleAvatar(radius: 30, backgroundColor: const Color(0xFFF3C300).withOpacity(0.1))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF3C300), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: Colors.black, size: 18),
              ),
              const Spacer(),
              Text(count, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTicketsTable(bool isDark) {
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black;
    Color borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade100;

    String tableTitle = _canViewAllTickets ? "Global Recent Tickets" : "Your Recent Tickets";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tableTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TicketsScreen()));
                },
                child: const Text("View All", style: TextStyle(color: Color(0xFFF3C300), fontWeight: FontWeight.bold)),
              )
            ],
          ),
          Divider(height: 16, color: borderColor),
          const SizedBox(height: 8),

          if (_allTickets.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("No tickets found", style: TextStyle(color: textColor))))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _allTickets.take(5).length,
              itemBuilder: (context, index) {
                final t = _allTickets[index];
                return InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TicketDetailScreen(ticket: t))).then((_) => _loadDashboardData()),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade100)
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor), overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(_getDisplayTicketNumber(t), style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                      child: Text("•", style: TextStyle(color: Colors.grey)),
                                    ),
                                    _buildDotPill(t.status, isDark),
                                  ],
                                )
                              ],
                            )
                        ),
                        const SizedBox(width: 12),
                        _buildDotPill(t.priority, isDark),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDotPill(String text, bool isDark) {
    Color color; Color bgColor; String val = text.toLowerCase();

    if (val == 'open' || val == 'high') { color = Colors.orange.shade700; bgColor = isDark ? Colors.orange.withOpacity(0.1) : Colors.orange.shade50; }
    else if (val.contains('progress') || val == 'medium') { color = Colors.blue.shade700; bgColor = isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50; }
    else if (val == 'critical') { color = Colors.red.shade700; bgColor = isDark ? Colors.red.withOpacity(0.1) : Colors.red.shade50; }
    else if (val == 'resolved' || val == 'low') { color = Colors.grey.shade700; bgColor = isDark ? Colors.white10 : Colors.grey.shade200; }
    else { color = Colors.green.shade700; bgColor = isDark ? Colors.green.withOpacity(0.1) : Colors.green.shade50; }

    if (val == 'medium') {
      color = const Color(0xFF6366F1);
      bgColor = isDark ? const Color(0xFF6366F1).withOpacity(0.1) : const Color(0xFFEEF2FF);
    }

    String displayText = text.split('_').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ');

    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
        child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(displayText, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold))
            ]
        )
    );
  }

  Widget _buildTicketOverview(bool isDark) {
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black;
    Color borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade100;

    int total = _allTickets.isEmpty ? 1 : _allTickets.length;
    int open = _allTickets.where((t) => t.status.toLowerCase() == 'open').length;
    int progress = _allTickets.where((t) => t.status.toLowerCase().contains('progress')).length;
    int closed = _allTickets.where((t) => t.status.toLowerCase() == 'closed' || t.status.toLowerCase() == 'resolved').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Ticket Overview", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 20),
          _buildProgressItem("Open", open, total, Colors.orange, isDark),
          _buildProgressItem("In Progress", progress, total, Colors.blue, isDark),
          _buildProgressItem("Closed", closed, total, Colors.green, isDark),
        ],
      ),
    );
  }

  Widget _buildProgressItem(String label, int count, int total, Color color, bool isDark) {
    double perc = count / total;
    Color textColor = isDark ? Colors.white : Colors.black;
    Color bgColor = isDark ? Colors.grey.shade800 : Colors.grey.shade100;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
            Text("$count (${(perc * 100).toInt()}%)", style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: perc, color: color, backgroundColor: bgColor, minHeight: 8)),
        ],
      ),
    );
  }
}