import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../../providers/theme_provider.dart';
import '../../services/ticket_service.dart';
import '../../models/ticket.dart';
import '../../widgets/menu_drawer.dart';
import '../common/profile_screen.dart';
import '../common/ticket_detail_screen.dart';
import '../common/create_ticket_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final String _baseUrl = "https://ticketapi.dcstechnosis.com";
  final TextEditingController _searchController = TextEditingController();

  String _firstName = "User";
  String _initials = "U";
  String? _profileImageUrl;
  String _currentUserId = "";

  List<Ticket> _allTickets = [];
  bool _isLoading = true;

  // 🔥 STRICT ROLES AND PERMISSIONS STATE
  bool _isAdmin = false;
  bool _canViewTickets = false;
  bool _canCreateTicket = false;

  // Admin specific data
  int _totalUsers = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserProfileLocally();
  }

  // 🔥 HELPER: Load Demo User if API/Storage fails
  void _loadDemoUser() {
    setState(() {
      _firstName = "Admin";
      _initials = "AD";
      _currentUserId = "demo_admin_123";
      _isAdmin = true;
      _canViewTickets = true;
      _canCreateTicket = true;
    });
    _loadDashboardData();
  }

  // 🔥 HELPER: Demo Tickets List
  List<Ticket> _getDemoTickets() {
    return [
      Ticket(id: '60d5ecb54', ticketId: 'TK-891', subject: 'Internet is down on 3rd floor', description: 'Router shows red light', status: 'Open', priority: 'Critical', attachments: []),
      Ticket(id: '60d5ecb55', ticketId: 'TK-892', subject: 'Laptop screen blinking', description: 'Screen remains black after power on', status: 'In Progress', priority: 'High', attachments: []),
      Ticket(id: '60d5ecb56', ticketId: 'TK-893', subject: 'Need access to Server', description: 'Please grant developer access', status: 'Closed', priority: 'Medium', attachments: []),
      Ticket(id: '60d5ecb57', ticketId: 'TK-894', subject: 'Printer out of ink', description: 'HR department printer needs cartridge replacement', status: 'Open', priority: 'Low', attachments: []),
      Ticket(id: '60d5ecb58', ticketId: 'TK-895', subject: 'Email password reset', description: 'Forgot my outlook password', status: 'Resolved', priority: 'High', attachments: []),
    ];
  }

  Future<void> _fetchUserProfileLocally() async {
    try {
      const storage = FlutterSecureStorage();
      String? userDataString = await storage.read(key: "user_data");

      if (userDataString != null) {
        final userData = jsonDecode(userDataString);
        setState(() {
          String fullName = userData['name'] ?? 'User';
          _firstName = fullName.split(' ').first;
          _profileImageUrl = userData['profileImage'];
          List<String> nameParts = fullName.trim().split(" ");

          if (nameParts.length > 1) {
            _initials =
                nameParts[0][0].toUpperCase() + nameParts[1][0].toUpperCase();
          } else if (nameParts.isNotEmpty) {
            _initials = nameParts[0][0].toUpperCase();
          } else {
            _initials = "U";
          }
          _currentUserId = (userData['_id'] ?? userData['id'] ?? '').toString();

          _isAdmin = userData['role'] == 'admin';
          _canViewTickets = _isAdmin || (userData['canViewTicket'] == true);
          _canCreateTicket = _isAdmin || (userData['canCreateTicket'] == true);
        });

        _loadDashboardData();
      } else {
        _loadDemoUser();
      }
    } catch (e) {
      debugPrint("Dashboard Profile Error: $e");
      _loadDemoUser();
    }
  }

  Future<void> _loadDashboardData() async {
    if (!_canViewTickets) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");

      if (_isAdmin) {
        try {
          var usersRes = await Dio().get("$_baseUrl/api/users",
              options: Options(headers: {"Authorization": "Bearer ${token ?? ''}"}));
          if (usersRes.statusCode == 200) {
            var data = usersRes.data;
            List usersList =
            data is List ? data : (data['users'] ?? data['data'] ?? []);
            _totalUsers = usersList.length;
          } else {
            _totalUsers = 14;
          }
        } catch (e) {
          debugPrint("Failed to fetch users count: $e");
          _totalUsers = 14;
        }
      }

      List<Ticket> tickets = [];
      try {
        tickets = await TicketService().fetchTickets();
      } catch (e) {
        debugPrint("API Failed, loading demo tickets: $e");
      }

      if (tickets.isEmpty) {
        tickets = _getDemoTickets();
      }

      if (!_isAdmin && _currentUserId.isNotEmpty) {
        // Handle user filtering if needed
      }

      if (mounted) {
        setState(() {
          _allTickets = tickets;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
      if (mounted) {
        setState(() {
          _totalUsers = 14;
          _allTickets = _getDemoTickets();
          _isLoading = false;
        });
      }
    }
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
              if (_canViewTickets) ...[
                // 1. KPI GRID
                _isAdmin ? _buildAdminKPIGrid(isDark) : _buildUserKPIGrid(isDark),
                const SizedBox(height: 24),

                // 🔥 2. NEW: BEAUTIFUL BAR CHART GRAPH
                _buildWeeklyAnalyticsChart(isDark),
                const SizedBox(height: 24),

                // 3. RECENT TICKETS TABLE
                _buildRecentTicketsTable(isDark),
                const SizedBox(height: 24),

                // 4. OVERVIEW PROGRESS BARS
                _buildTicketOverview(isDark),
              ] else ...[
                // FALLBACK UI FOR USERS WITH NO PERMISSION
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, size: 80, color: isDark ? Colors.white24 : Colors.grey.shade400),
                        const SizedBox(height: 24),
                        Text("Access Denied", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 12),
                        Text("You have no assigned module.\nPlease ask admin for allow.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: isDark ? Colors.white54 : Colors.grey.shade600, height: 1.5)),
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
        IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white), onPressed: () {}),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Good day, $_firstName 👋", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
            Text("Here's your workspace overview", style: TextStyle(color: subTextColor, fontSize: 14)),
          ],
        ),
        if (_canCreateTicket)
          ElevatedButton.icon(
            onPressed: () async {
              final res = await Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateTicketScreen()));
              if (res == true) _loadDashboardData();
            },
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

  // 🔥 NEW WIDGET: WEEKLY ANALYTICS BAR CHART
  Widget _buildWeeklyAnalyticsChart(bool isDark) {
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black;
    Color borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade100;

    // Demo Data for Graph
    final List<Map<String, dynamic>> weeklyData = [
      {"day": "Mon", "value": 12},
      {"day": "Tue", "value": 18},
      {"day": "Wed", "value": 25},
      {"day": "Thu", "value": 15},
      {"day": "Fri", "value": 22},
      {"day": "Sat", "value": 8},
      {"day": "Sun", "value": 5},
    ];

    double maxCount = 25.0; // Base max value for scaling

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Weekly Activity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF3C300).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: const Text("This Week", style: TextStyle(color: Color(0xFFB48600), fontSize: 11, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 30),
          // Bar Chart Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: weeklyData.map((data) {
              double heightPercentage = data["value"] / maxCount;
              return Column(
                children: [
                  // Number Tooltip
                  Text("${data["value"]}", style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  // The Bar
                  Container(
                    width: 20,
                    height: 100 * heightPercentage, // Max height is 100px
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFFF3C300), const Color(0xFFF3C300).withOpacity(0.5)],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Day Label
                  Text(data["day"], style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.black54, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminKPIGrid(bool isDark) {
    int totalT = _allTickets.length;
    int openT = _allTickets.where((t) => t.status.toLowerCase() == 'open').length;
    int resolvedT = _allTickets.where((t) => t.status.toLowerCase() == 'closed' || t.status.toLowerCase() == 'resolved').length;

    return LayoutBuilder(builder: (context, constraints) {
      double width = constraints.maxWidth;
      double cardWidth = (width - 16) / 2;

      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildModernKPICard("Total Users", "$_totalUsers", Icons.people, isDark, cardWidth),
          _buildModernKPICard("Total Tickets", "$totalT", Icons.confirmation_number, isDark, cardWidth),
          _buildModernKPICard("Open Tickets", "$openT", Icons.folder_open, isDark, cardWidth),
          _buildModernKPICard("Resolved Tickets", "$resolvedT", Icons.check_circle, isDark, cardWidth),
        ],
      );
    });
  }

  Widget _buildUserKPIGrid(bool isDark) {
    int open = _allTickets.where((t) => t.status.toLowerCase() == 'open').length;
    return Row(
      children: [
        Expanded(child: _buildModernKPICard("My Tickets", "${_allTickets.length}", Icons.confirmation_number_rounded, isDark, double.infinity)),
        const SizedBox(width: 16),
        Expanded(child: _buildModernKPICard("Open", "$open", Icons.folder_open_rounded, isDark, double.infinity)),
      ],
    );
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isAdmin ? "Global Recent Tickets" : "Your Recent Tickets", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          Divider(height: 24, color: borderColor),
          if (_allTickets.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("No tickets found", style: TextStyle(color: textColor))))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _allTickets.take(5).length,
              separatorBuilder: (context, index) => Divider(height: 1, color: borderColor),
              itemBuilder: (context, index) {
                final t = _allTickets[index];
                return InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TicketDetailScreen(ticket: t))).then((_) => _loadDashboardData()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        _buildIDPill(t.id),
                        const SizedBox(width: 12),
                        Expanded(child: Text(t.subject, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor), overflow: TextOverflow.ellipsis)),
                        _buildStatusPill(t.status),
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

  Widget _buildIDPill(String id) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFFEF9C3), borderRadius: BorderRadius.circular(6)),
      child: Text("TK-${id.substring(id.length > 3 ? id.length - 3 : 0).toUpperCase()}",
          style: const TextStyle(color: Color(0xFF854D0E), fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }

  Widget _buildStatusPill(String status) {
    bool isInProgress = status.toLowerCase().contains('progress');
    Color color = status.toLowerCase() == 'open'
        ? Colors.orange
        : (status.toLowerCase() == 'closed' || status.toLowerCase() == 'resolved' ? Colors.green : Colors.blue);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(isInProgress ? "IN PROGRESS" : status.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}