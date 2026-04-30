import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '/models/ticket.dart';
import '/services/ticket_service.dart';
import '/widgets/menu_drawer.dart';
import 'ticket_detail_screen.dart';
import 'create_ticket_screen.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final TicketService _ticketService = TicketService();
  final TextEditingController _searchController = TextEditingController();

  List<Ticket> _allTickets = [];
  List<Ticket> _displayedTickets = [];
  bool _isLoading = true;

  bool _isAdmin = false;
  String _currentUserId = "";

  // 🔥 FILTER STATE VARIABLES
  String _selectedStatus = 'All Status';
  String _selectedPriority = 'All Priority';

  final List<String> _statusOptions = [
    'All Status',
    'Open',
    'In Progress',
    'Closed'
  ];
  final List<String> _priorityOptions = [
    'All Priority',
    'Low',
    'Medium',
    'High',
    'Critical'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 🔥 REALISTIC STATIC DATA FOR SCREENSHOTS
  List<Ticket> _getStaticDemoTickets() {
    return [
      Ticket(id: '60d5ecb54', ticketId: 'TK-891', subject: 'Wi-Fi keeps disconnecting on 3rd floor', description: 'Router shows red light constantly.', status: 'Open', priority: 'High', attachments: []),
      Ticket(id: '60d5ecb55', ticketId: 'TK-892', subject: 'Need access to AWS Production Server', description: 'Please grant developer access to the main EC2 instance.', status: 'In Progress', priority: 'Critical', attachments: []),
      Ticket(id: '60d5ecb56', ticketId: 'TK-893', subject: 'New employee laptop setup', description: 'Need Macbook Pro M2 configured for the new designer joining on Monday.', status: 'Closed', priority: 'Medium', attachments: []),
      Ticket(id: '60d5ecb57', ticketId: 'TK-894', subject: 'Printer out of black ink', description: 'HR department printer needs cartridge replacement immediately.', status: 'Open', priority: 'Low', attachments: []),
      Ticket(id: '60d5ecb58', ticketId: 'TK-895', subject: 'Email password reset for CEO', description: 'Forgot outlook password, need urgent reset.', status: 'Closed', priority: 'Critical', attachments: []),
      Ticket(id: '60d5ecb59', ticketId: 'TK-896', subject: 'Update company website banner', description: 'Marketing team requested a banner change for the upcoming sale.', status: 'In Progress', priority: 'Medium', attachments: []),
      Ticket(id: '60d5ecb60', ticketId: 'TK-897', subject: 'Mouse cursor jumping randomly', description: 'Wireless mouse seems defective, need a replacement.', status: 'Open', priority: 'Low', attachments: []),
      Ticket(id: '60d5ecb61', ticketId: 'TK-898', subject: 'Database backup failure', description: 'Nightly CRON job for MongoDB backup failed yesterday.', status: 'In Progress', priority: 'High', attachments: []),
    ];
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      const storage = FlutterSecureStorage();

      String? userDataString = await storage.read(key: "user_data");
      if (userDataString != null) {
        final userData = jsonDecode(userDataString);
        _isAdmin = userData['role'] == 'admin';
        _currentUserId = (userData['_id'] ?? userData['id'] ?? '').toString();
      }

      List<Ticket> fetchedTickets = [];

      try {
        fetchedTickets = await _ticketService.fetchTickets();
      } catch (e) {
        debugPrint("API Failed, using static data");
      }

      // Use static data if API is empty or fails
      if (fetchedTickets.isEmpty) {
        fetchedTickets = _getStaticDemoTickets();
      }

      setState(() {
        _allTickets = fetchedTickets;
        _applyFilters();
      });
    } catch (e) {
      debugPrint("Error loading tickets: $e");
      if (mounted) {
        setState(() {
          _allTickets = _getStaticDemoTickets();
          _applyFilters();
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _displayedTickets = _allTickets.where((t) {
        final query = _searchController.text.toLowerCase();
        final matchesSearch = t.subject.toLowerCase().contains(query) ||
            t.ticketId.toLowerCase().contains(query);

        final matchesStatus = _selectedStatus == 'All Status' ||
            t.status.toLowerCase() == _selectedStatus.toLowerCase();

        final matchesPriority = _selectedPriority == 'All Priority' ||
            t.priority.toLowerCase() == _selectedPriority.toLowerCase();

        return matchesSearch && matchesStatus && matchesPriority;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    int total = _allTickets.length;
    int open = _allTickets.where((t) => t.status.toLowerCase() == 'open').length;
    int inProgress = _allTickets.where((t) => t.status.toLowerCase().contains('progress')).length;
    int closed = _allTickets.where((t) => t.status.toLowerCase() == 'closed' || t.status.toLowerCase() == 'resolved').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const MenuDrawer(currentRoute: 'tickets'),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Tickets", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF3C300)))
          : RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildKPIGrid(total, open, inProgress, closed),
              const SizedBox(height: 24),
              // 🔥 Filter row yahan se hata kar table ke andar daal diya!
              _buildTicketTable(),
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
              const Text("Tickets", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 4),
              Text("Manage and track all support requests", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateTicketScreen())).then((_) => _loadData()),
          icon: const Icon(Icons.add, size: 18, color: Colors.black),
          label: const Text("New Ticket", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF3C300),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        ),
      ],
    );
  }

  Widget _buildKPIGrid(int total, int open, int progress, int closed) {
    return LayoutBuilder(builder: (context, constraints) {
      double width = constraints.maxWidth;
      double cardWidth = width > 800 ? (width - 48) / 4 : (width - 16) / 2;

      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildKPICard("Total", "$total", Icons.confirmation_number_outlined, cardWidth),
          _buildKPICard("Open", "$open", Icons.folder_open, cardWidth),
          _buildKPICard("In Progress", "$progress", Icons.rotate_right, cardWidth),
          _buildKPICard("Closed", "$closed", Icons.check_circle_outline, cardWidth),
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
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(val, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
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
                  color: const Color(0xFFF3C300).withOpacity(0.15),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                    topLeft: Radius.circular(60),
                    bottomLeft: Radius.circular(60),
                  )),
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
                    color: const Color(0xFFF3C300),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFF3C300).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))
                    ]),
                child: Icon(icon, size: 22, color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 FILTER ROW KO TABLE KE ANDAR FIT KARNE KE LIYE CLEAN KIYA
  Widget _buildFilterRow() {
    return Row(
      children: [
        const Text("FILTERS:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDropdown(_selectedStatus, _statusOptions, (val) {
            setState(() => _selectedStatus = val!);
            _applyFilters();
          }),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDropdown(_selectedPriority, _priorityOptions, (val) {
            setState(() => _selectedPriority = val!);
            _applyFilters();
          }),
        ),
      ],
    );
  }

  Widget _buildDropdown(String currentValue, List<String> options, Function(String?) onChanged) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
          onChanged: onChanged,
          items: options.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value, overflow: TextOverflow.ellipsis));
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTicketTable() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 4, height: 26, color: const Color(0xFFF3C300), margin: const EdgeInsets.only(right: 8)),
                  const Text("All Tickets", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, size: 16, color: Colors.grey),
                label: const Text("Refresh", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), side: BorderSide(color: Colors.grey.shade300)),
              )
            ],
          ),
          const SizedBox(height: 20),

          // 🔥 SEARCH BAR
          Container(
            height: 44,
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => _applyFilters(),
              decoration: const InputDecoration(
                hintText: "Search records by ID or Subject...",
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(bottom: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 🔥 FILTERS NOW PLACED DIRECTLY UNDER THE SEARCH BAR
          _buildFilterRow(),

          const SizedBox(height: 12),
          Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: Text("${_displayedTickets.length} records found", style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
              )),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _headerCell("ID", 80),
                    _headerCell("SUBJECT", 250),
                    _headerCell("STATUS", 120),
                    _headerCell("PRIORITY", 120),
                    _headerCell("ASSIGNED TO", 150),
                    _headerCell("CREATED", 120),
                    _headerCell("ACTIONS", 100),
                  ],
                ),
                const SizedBox(height: 12),
                if (_displayedTickets.isEmpty)
                  const Padding(padding: EdgeInsets.all(32.0), child: Text("No tickets found matching your criteria.", style: TextStyle(color: Colors.grey)))
                else
                  ..._displayedTickets.map((t) => _buildTableRow(t)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _headerCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
    );
  }

  Widget _buildTableRow(Ticket t) {
    String date = "20 Apr 2026";

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: Row(
        children: [
          SizedBox(width: 80, child: _buildIDPill(t.id)),
          SizedBox(width: 250, child: Text(t.subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis)),
          SizedBox(width: 120, child: Align(alignment: Alignment.centerLeft, child: _buildDotPill(t.status))),
          SizedBox(width: 120, child: Align(alignment: Alignment.centerLeft, child: _buildDotPill(t.priority))),
          SizedBox(width: 150, child: _buildAssignee(t)),
          SizedBox(width: 120, child: Text(date, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500))),
          SizedBox(
              width: 100,
              child: Row(
                children: [
                  _buildActionButton(Icons.visibility_outlined, Colors.grey.shade600, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => TicketDetailScreen(ticket: t))).then((_) => _loadData());
                  }),
                  const SizedBox(width: 8),
                  if (_isAdmin && t.status.toLowerCase() != 'closed') _buildActionButton(Icons.check, Colors.green, () {}),
                ],
              )),
        ],
      ),
    );
  }

  Widget _buildIDPill(String id) {
    String displayId = id.length > 3 ? id.substring(id.length - 3) : id;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFFEF9C3), borderRadius: BorderRadius.circular(6)),
      child: Text("TK-${displayId.toUpperCase()}", style: const TextStyle(color: Color(0xFF854D0E), fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _buildDotPill(String text) {
    Color color;
    String val = text.toLowerCase();

    if (val == 'open' || val == 'high')
      color = Colors.orange;
    else if (val.contains('progress') || val == 'medium')
      color = Colors.blue;
    else if (val == 'critical')
      color = Colors.red;
    else
      color = Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAssignee(Ticket t) {
    String assigneeName = "Rajesh Tech";

    if (t.status.toLowerCase() == 'open') {
      assigneeName = "Unassigned";
    }

    if (assigneeName == "Unassigned") {
      return const Text("Unassigned", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500));
    }

    String initials = assigneeName.isNotEmpty ? assigneeName[0].toUpperCase() : "?";

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: const Color(0xFFF3C300), borderRadius: BorderRadius.circular(4)),
          child: Center(child: Text(initials, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black))),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(assigneeName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}