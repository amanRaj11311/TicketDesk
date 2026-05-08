import 'dart:io';
import 'dart:async'; // 🔥 IMPORTED FOR LIVE CHAT TIMER
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/ticket.dart';
import '../../services/ticket_service.dart';
import '../../widgets/menu_drawer.dart';
import '../../providers/theme_provider.dart';
import '../constants/api_constants.dart';
import '../common/profile_screen.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final String _baseUrl = ApiConstants.baseUrl;
  final TicketService _ticketService = TicketService();
  final TextEditingController _searchController = TextEditingController();

  List<Ticket> _allTickets = [];
  List<Ticket> _displayedTickets = [];
  bool _isLoading = true;

  // 🔥 PAGINATION VARIABLES
  int _currentPage = 1;
  bool _hasMoreData = true;
  bool _isFetchingMore = false;
  final ScrollController _scrollController = ScrollController();

  // 🔥 KPI VARIABLES (Independent of Scroll/Pagination)
  int _kpiTotal = 0;
  int _kpiOpen = 0;
  int _kpiInProgress = 0;
  int _kpiClosed = 0;

  String _currentUserId = "";

  // 🔥 APP BAR USER PROFILE DATA
  String _initials = "U";
  String? _profileImageUrl;

  // STRICT PERMISSIONS FLAGS
  bool _canViewAllTickets = false;
  bool _canViewOwnTickets = false;
  bool _canCreateTicket = false;
  bool _canEditTicket = false;
  bool _canDeleteTicket = false;
  bool _canChangePriority = false;
  bool _canChangeStatus = false;
  bool _canAssignTicket = false;
  bool _canUploadAttachment = false;
  bool _canAddComment = false;
  bool _canViewComment = false;
  bool _canCloseTicket = false;

  bool get _hasAnyTicketViewAccess => _canViewAllTickets || _canViewOwnTickets;

  String _selectedStatus = 'All Status';
  String _selectedPriority = 'All Priority';

  final List<String> _statusOptions = ['All Status', 'Open', 'In Progress', 'Resolved', 'Closed'];
  final List<String> _priorityOptions = ['All Priority', 'Low', 'Medium', 'High', 'Critical'];

  List<dynamic> _usersList = [];

  @override
  void initState() {
    super.initState();
    // 🔥 SCROLL LISTENER FOR PAGINATION
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100 &&
          !_isFetchingMore &&
          _hasMoreData) {
        _loadMoreTickets();
      }
    });
    _loadDataAndPermissions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDataAndPermissions() async {
    if (mounted) setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMoreData = true;
      _allTickets.clear();
    });

    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");
      String? userDataString = await storage.read(key: "user_data");

      if (userDataString != null) {
        final userData = jsonDecode(userDataString);
        _currentUserId = (userData['_id'] ?? userData['id'] ?? '').toString();

        String fullName = userData['name'] ?? 'User';
        List<String> nameParts = fullName.trim().split(RegExp(r'\s+'));

        if (nameParts.length > 1 && nameParts[1].isNotEmpty) {
          _initials = nameParts[0][0].toUpperCase() + nameParts[1][0].toUpperCase();
        } else if (nameParts.isNotEmpty && nameParts[0].isNotEmpty) {
          _initials = nameParts[0][0].toUpperCase();
        } else {
          _initials = "U";
        }
        _profileImageUrl = userData['avatarUrl'] ?? userData['profileImage'] ?? userData['avatar'];

        _canViewAllTickets = false;
        _canViewOwnTickets = false;
        _canCreateTicket = false;
        _canEditTicket = false;
        _canDeleteTicket = false;
        _canChangePriority = false;
        _canChangeStatus = false;
        _canAssignTicket = false;
        _canUploadAttachment = false;
        _canAddComment = false;
        _canViewComment = false;
        _canCloseTicket = false;

        if (userData['permissions'] != null && userData['permissions'] is List) {
          for (var perm in userData['permissions']) {
            String res = perm['resource']?.toString().toLowerCase().trim() ?? '';
            String act = perm['action']?.toString().toLowerCase().trim() ?? '';

            if (res == 'ticket') {
              if (act == 'view' || act == 'view_all') _canViewAllTickets = true;
              if (act == 'view_own') _canViewOwnTickets = true;
              if (act == 'create') _canCreateTicket = true;
              if (act == 'update' || act == 'edit') _canEditTicket = true;
              if (act == 'delete' || act == 'dlt') _canDeleteTicket = true;
              if (act == 'change_priority') _canChangePriority = true;
              if (act == 'change_status') _canChangeStatus = true;
              if (act == 'assign') _canAssignTicket = true;
              if (act == 'close') _canCloseTicket = true;
            } else if (res == 'comment') {
              if (act == 'view') _canViewComment = true;
              if (act == 'create' || act == 'add') _canAddComment = true;
            }
          }
        }

        if (_canCreateTicket || _canEditTicket || _canAddComment) {
          _canUploadAttachment = true;
        }
      }

      if (!_hasAnyTicketViewAccess) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 🔥 KPI EXACT COUNT FETCH (Limit=10000 sirf count ke liye)
      List<Ticket> kpiTickets = await _ticketService.fetchTickets(page: 1, limit: 10000);
      if (!_canViewAllTickets && _canViewOwnTickets) {
        kpiTickets = kpiTickets.where((t) => t.createdBy == _currentUserId).toList();
      }

      _kpiTotal = kpiTickets.length;
      _kpiOpen = kpiTickets.where((t) => t.status.toLowerCase() == 'open').length;
      _kpiInProgress = kpiTickets.where((t) => t.status.toLowerCase().contains('progress')).length;
      _kpiClosed = kpiTickets.where((t) => t.status.toLowerCase() == 'closed').length;


      // 🔥 FETCH PAGE 1 FOR LIST VIEW
      List<Ticket> fetchedTickets = await _ticketService.fetchTickets(page: _currentPage, limit: 15);
      if (fetchedTickets.length < 15) {
        _hasMoreData = false;
      }

      if (!_canViewAllTickets && _canViewOwnTickets) {
        fetchedTickets = fetchedTickets.where((t) => t.createdBy == _currentUserId).toList();
      }

      try {
        var userRes = await Dio().get("$_baseUrl/api/users", options: Options(headers: {"Authorization": "Bearer $token"}));
        if (userRes.statusCode == 200) {
          _usersList = userRes.data['data'] ?? userRes.data['users'] ?? [];
        }
      } catch (e) {
        debugPrint("Failed to fetch users: $e");
      }

      if (mounted) {
        setState(() {
          _allTickets = fetchedTickets;
          _applyFilters();
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔥 LOAD MORE TICKETS (PAGINATION)
  Future<void> _loadMoreTickets() async {
    setState(() => _isFetchingMore = true);
    try {
      _currentPage++;
      List<Ticket> fetchedTickets = await _ticketService.fetchTickets(page: _currentPage, limit: 15);

      if (fetchedTickets.length < 15) {
        _hasMoreData = false;
      }

      if (!_canViewAllTickets && _canViewOwnTickets) {
        fetchedTickets = fetchedTickets.where((t) => t.createdBy == _currentUserId).toList();
      }

      if (mounted) {
        setState(() {
          _allTickets.addAll(fetchedTickets);
          _applyFilters();
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isFetchingMore = false);
      debugPrint("Error loading more tickets: $e");
    }
  }

  void _applyFilters() {
    setState(() {
      _displayedTickets = _allTickets.where((t) {
        final query = _searchController.text.toLowerCase();
        String tNum = "";
        try { tNum = (t as dynamic).ticketNumber?.toString().toLowerCase() ?? ""; } catch (_) {}
        if (tNum.isEmpty) tNum = t.ticketId.toLowerCase();

        final matchesSearch = t.title.toLowerCase().contains(query) || tNum.contains(query);
        final matchesStatus = _selectedStatus == 'All Status' || t.status.toLowerCase() == _selectedStatus.toLowerCase().replaceAll(' ', '_');
        final matchesPriority = _selectedPriority == 'All Priority' || t.priority.toLowerCase() == _selectedPriority.toLowerCase();

        return matchesSearch && matchesStatus && matchesPriority;
      }).toList();
    });
  }

  String _getTicketId(Ticket t) {
    try { return (t as dynamic).sId ?? t.id; } catch (e) { return t.id; }
  }

  String _getDisplayTicketNumber(Ticket t) {
    try {
      var num = (t as dynamic).ticketNumber;
      if (num != null && num.toString().isNotEmpty) return num.toString();
    } catch (_) {}
    if (t.ticketId.isNotEmpty) return t.ticketId;
    return "TKT-${t.id.substring(t.id.length - 4)}";
  }

  // 🔥 BULLETPROOF SCANNER FOR CREATOR NAME
  String _getCreatorName(Ticket t) {
    try {
      var creator = (t as dynamic).createdBy;
      if (creator == null || creator.toString() == "null") return "--";

      if (creator is Map) return creator['name']?.toString() ?? "--";

      String creatorStr = creator.toString();

      if (creatorStr.contains('name:')) {
        var match = RegExp(r'name:\s*([^,}]+)').firstMatch(creatorStr);
        if (match != null && match.group(1) != null) {
          String name = match.group(1)!.replaceAll('"', '').replaceAll("'", '').trim();
          if (name.isNotEmpty) return name;
        }
      }

      var foundUser = _usersList.firstWhere((u) => u['_id'] == creatorStr || u['id'] == creatorStr, orElse: () => null);
      if (foundUser != null && foundUser['name'] != null) return foundUser['name'].toString();

    } catch (e) {
      debugPrint("Creator parse error: $e");
    }
    return "--";
  }

  // 🔥 BULLETPROOF SCANNER FOR ASSIGNEE NAME
  String _getAssigneeName(Ticket t) {
    try {
      var assignee = (t as dynamic).assignedTo;
      if (assignee == null || assignee.toString() == "null") return "--";

      if (assignee is Map) return assignee['name']?.toString() ?? "--";

      String assigneeStr = assignee.toString();

      if (assigneeStr.contains('name:')) {
        var match = RegExp(r'name:\s*([^,}]+)').firstMatch(assigneeStr);
        if (match != null && match.group(1) != null) {
          String name = match.group(1)!.replaceAll('"', '').replaceAll("'", '').trim();
          if (name.isNotEmpty) return name;
        }
      }

      var foundUser = _usersList.firstWhere((u) => u['_id'] == assigneeStr || u['id'] == assigneeStr, orElse: () => null);
      if (foundUser != null && foundUser['name'] != null) return foundUser['name'].toString();

    } catch (e) {
      debugPrint("Assignee parse error: $e");
    }
    return "--";
  }

  // =========================================================================
  // 🔥 CUSTOM OVERLAY MESSAGE
  // =========================================================================
  void _showOverlayMsg(BuildContext context, String msg, Color color) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Positioned(
          bottom: bottomInset + 40,
          left: 20,
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))]
              ),
              child: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) entry.remove();
    });
  }

  // =========================================================================
  // 🔥 CREATE / EDIT BOTTOM SHEET
  // =========================================================================
  void _openCreateOrEditSheet({Ticket? ticket}) {
    final titleController = TextEditingController(text: ticket?.title ?? "");
    final descriptionController = TextEditingController(text: ticket?.description ?? "");
    String localPriority = ticket?.priority.toLowerCase() ?? 'medium';
    String localStatus = ticket?.status.toLowerCase() ?? 'open';

    String? localAssignee;
    if (ticket?.assignedTo != null && ticket!.assignedTo.toString() != "null") {
      try {
        if (ticket.assignedTo is Map) {
          localAssignee = ticket.assignedTo['_id']?.toString();
        } else {
          localAssignee = (ticket.assignedTo as dynamic).sId ?? ticket.assignedTo.toString();
        }
      } catch (e) {
        localAssignee = ticket.assignedTo.toString();
      }
    }

    List<dynamic> existingServerImages = [];
    if (ticket != null) {
      try {
        if (ticket.attachments.isNotEmpty) {
          for (var att in ticket.attachments) {
            try {
              var url = (att as dynamic).url;
              if (url != null) existingServerImages.add({"url": url, "name": "attachment"});
            } catch (e) {}
          }
        }
      } catch(e) {}
    }

    List<File> localImages = [];
    bool isSubmitting = false;
    bool isNewTicket = (ticket == null);

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

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {

            Future<void> submitForm() async {
              if (titleController.text.trim().isEmpty || descriptionController.text.trim().isEmpty) {
                _showOverlayMsg(context, "Title & Description required!", Colors.orange);
                return;
              }
              setModalState(() => isSubmitting = true);

              try {
                const storage = FlutterSecureStorage();
                String? token = await storage.read(key: "jwt_token");

                Map<String, dynamic> payload = {
                  "title": titleController.text.trim(),
                  "description": descriptionController.text.trim(),
                  "priority": localPriority,
                  "status": localStatus,
                };

                if (localAssignee != null && localAssignee!.isNotEmpty) {
                  payload["assignedTo"] = localAssignee;
                }

                List<Map<String, dynamic>> attachmentsToKeep = [];
                for(var existing in existingServerImages) {
                  attachmentsToKeep.add({"url": existing['url'], "name": existing['name'] ?? "image"});
                }

                for(File file in localImages) {
                  List<int> imageBytes = await file.readAsBytes();
                  String base64Image = "data:image/jpeg;base64,${base64Encode(imageBytes)}";
                  attachmentsToKeep.add({
                    "name": file.path.split('/').last,
                    "type": "image/jpeg",
                    "size": file.lengthSync(),
                    "base64": base64Image
                  });
                }

                payload["attachments"] = attachmentsToKeep;

                Response response;
                if (ticket != null) {
                  response = await Dio().patch("$_baseUrl/api/tickets/${_getTicketId(ticket)}", data: payload, options: Options(headers: {"Authorization": "Bearer $token"}));
                } else {
                  response = await Dio().post("$_baseUrl/api/tickets", data: payload, options: Options(headers: {"Authorization": "Bearer $token"}));
                }

                if (!context.mounted) return;

                if (response.statusCode == 200 || response.statusCode == 201) {
                  _showOverlayMsg(context, isNewTicket ? "Ticket Created!" : "Ticket Updated!", Colors.green);
                  Navigator.pop(context);
                  _loadDataAndPermissions();
                }
              } catch (e) {
                setModalState(() => isSubmitting = false);
                _showOverlayMsg(context, "Failed to submit ticket. Server Error.", Colors.red);
              }
            }

            List<String> availableStatuses = ['open', 'in_progress', 'resolved'];
            if (_canCloseTicket) {
              availableStatuses.add('closed');
            }
            if (!availableStatuses.contains(localStatus)) {
              availableStatuses.add(localStatus);
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 50, height: 6, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                      Text(isNewTicket ? "Create New Ticket" : "Edit Ticket", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 24),

                      _buildFormLabel("SUBJECT / TITLE", isDark),
                      TextField(controller: titleController, style: TextStyle(color: textColor), decoration: _buildInputDecoration("Brief title...", inputColor, borderColor, isDark)),
                      const SizedBox(height: 20),

                      _buildFormLabel("DESCRIPTION", isDark),
                      TextField(controller: descriptionController, style: TextStyle(color: textColor), maxLines: 4, decoration: _buildInputDecoration("Detailed description...", inputColor, borderColor, isDark)),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          if (isNewTicket || _canChangePriority)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFormLabel("PRIORITY", isDark),
                                  DropdownButtonFormField<String>(
                                    value: localPriority,
                                    dropdownColor: bgColor,
                                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                                    decoration: _buildInputDecoration("", inputColor, borderColor, isDark),
                                    items: ['low', 'medium', 'high', 'critical'].map((v) => DropdownMenuItem(value: v, child: Text(v.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600)))).toList(),
                                    onChanged: (val) => setModalState(() => localPriority = val!),
                                  ),
                                ],
                              ),
                            ),

                          if ((isNewTicket || _canChangePriority) && (!isNewTicket && _canChangeStatus)) const SizedBox(width: 16),

                          if (!isNewTicket && _canChangeStatus)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFormLabel("STATUS", isDark),
                                  DropdownButtonFormField<String>(
                                    value: localStatus,
                                    dropdownColor: bgColor,
                                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                                    decoration: _buildInputDecoration("", inputColor, borderColor, isDark),
                                    items: availableStatuses.map((v) => DropdownMenuItem(value: v, child: Text(v.toUpperCase().replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.w600)))).toList(),
                                    onChanged: (val) => setModalState(() => localStatus = val!),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (_canAssignTicket) ...[
                        _buildFormLabel("ASSIGN TO", isDark),
                        DropdownButtonFormField<String?>(
                          value: _usersList.any((u) => u['_id'] == localAssignee) ? localAssignee : null,
                          dropdownColor: bgColor,
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                          decoration: _buildInputDecoration("", inputColor, borderColor, isDark),
                          hint: Text("-- Unassigned --", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600)),
                          items: [
                            DropdownMenuItem<String?>(value: null, child: Text("-- Unassigned --", style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.grey.shade700))),
                            ..._usersList.map((u) => DropdownMenuItem<String>(value: u['_id'].toString(), child: Text(u['name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.w500)))).toList()
                          ],
                          onChanged: (val) => setModalState(() => localAssignee = val),
                        ),
                        const SizedBox(height: 20),
                      ],

                      if (_canUploadAttachment) ...[
                        Container(
                          padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: inputColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white, foregroundColor: textColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: borderColor))),
                                      onPressed: () async {
                                        int totalImages = existingServerImages.length + localImages.length;
                                        if (totalImages >= 5) {
                                          _showOverlayMsg(context, "Max 5 images allowed", Colors.orange);
                                          return;
                                        }
                                        final List<XFile> pickedFiles = await ImagePicker().pickMultiImage(limit: 5 - totalImages);
                                        if (pickedFiles.isNotEmpty) {
                                          setModalState(() {
                                            for(var f in pickedFiles){
                                              if(existingServerImages.length + localImages.length < 5){
                                                localImages.add(File(f.path));
                                              }
                                            }
                                          });
                                        }
                                      },
                                      icon: const Icon(Icons.attach_file, size: 18), label: Text("Attach Image (${existingServerImages.length + localImages.length}/5)")
                                  ),
                                ],
                              ),
                              if(existingServerImages.isNotEmpty || localImages.isNotEmpty) const SizedBox(height: 12),
                              Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ...existingServerImages.map((serverImg) {
                                      String url = serverImg['url'].toString();
                                      String fullUrl = url.startsWith('http') ? url : "$_baseUrl$url";
                                      return Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.network(fullUrl, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 60, height: 60, color: Colors.grey, child: const Icon(Icons.broken_image, size: 20))),
                                            ),
                                            Positioned(
                                                right: 0, top: 0,
                                                child: InkWell(
                                                    onTap: () {
                                                      setModalState(() => existingServerImages.remove(serverImg));
                                                    },
                                                    child: Container(decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), padding: const EdgeInsets.all(2), child: const Icon(Icons.close, size: 14, color: Colors.white))
                                                )
                                            )
                                          ]
                                      );
                                    }).toList(),
                                    ...localImages.map((file) => Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.file(file, width: 60, height: 60, fit: BoxFit.cover),
                                          ),
                                          Positioned(
                                              right: 0, top: 0,
                                              child: InkWell(
                                                  onTap: () {
                                                    setModalState(() => localImages.remove(file));
                                                  },
                                                  child: Container(decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), padding: const EdgeInsets.all(2), child: const Icon(Icons.close, size: 14, color: Colors.white))
                                              )
                                          )
                                        ]
                                    )).toList()
                                  ]
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      SizedBox(
                        width: double.infinity, height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: isDark ? const Color(0xFFF3C300) : const Color(0xFF1E293B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                          onPressed: isSubmitting ? null : submitForm,
                          child: isSubmitting ? CircularProgressIndicator(color: isDark ? Colors.black : Colors.white) : Text(isNewTicket ? "Submit Ticket" : "Save Changes", style: TextStyle(color: isDark ? Colors.black87 : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildFormLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.grey.shade400 : Colors.grey, letterSpacing: 0.5)),
    );
  }

  InputDecoration _buildInputDecoration(String hint, Color fillColor, Color borderColor, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade400, fontWeight: FontWeight.w400),
      filled: true, fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF3C300), width: 2)),
    );
  }

  // =========================================================================
  // 🔥 FETCH & SHOW COMMENTS (LIVE CHAT ADDED)
  // =========================================================================
  void _openCommentsModal(Ticket ticket) {
    final commentController = TextEditingController();
    bool isLoadingComments = true;
    bool isSending = false;
    List<dynamic> comments = [];
    File? commentImage;
    Timer? chatTimer; // 🔥 ADDED TIMER VARIABLE FOR LIVE SYNC

    String displayTicketId = _getDisplayTicketNumber(ticket);

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
          final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
          final inputColor = isDark ? const Color(0xFF121212) : Colors.grey.shade100;
          final textColor = isDark ? Colors.white : Colors.black87;
          final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;

          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {

                // 🔥 Added isBackground flag so loading spinner doesn't flash every 2 secs
                void fetchComments({bool isBackground = false}) async {
                  try {
                    const storage = FlutterSecureStorage();
                    String? token = await storage.read(key: "jwt_token");
                    var res = await Dio().get("$_baseUrl/api/comments/${_getTicketId(ticket)}", options: Options(headers: {"Authorization": "Bearer $token"}));

                    if (res.statusCode == 200 && mounted) {
                      setModalState(() {
                        List rawList = res.data['data'] ?? res.data ?? [];
                        comments = List.from(rawList.reversed);
                        if (!isBackground) isLoadingComments = false; // Hide initial loader
                      });
                    }
                  } catch (e) {
                    if (!isBackground) setModalState(() => isLoadingComments = false);
                  }
                }

                // Initial fetch & Timer start
                if (isLoadingComments && comments.isEmpty) {
                  fetchComments();
                  // 🔥 START LIVE CHAT SYNC EVERY 2.5 SECONDS
                  chatTimer ??= Timer.periodic(const Duration(milliseconds: 1500), (timer) {
                    fetchComments(isBackground: true);
                  });
                }

                Future<void> sendComment() async {
                  if (commentController.text.trim().isEmpty && commentImage == null) return;
                  setModalState(() => isSending = true);
                  try {
                    const storage = FlutterSecureStorage();
                    String? token = await storage.read(key: "jwt_token");

                    Map<String, dynamic> payload = {
                      "message": commentController.text.trim().isNotEmpty ? commentController.text.trim() : "Attached file",
                      "senderType": "system"
                    };

                    if (commentImage != null) {
                      List<int> imageBytes = await commentImage!.readAsBytes();
                      String base64Image = "data:image/jpeg;base64,${base64Encode(imageBytes)}";
                      payload["attachments"] = [{"name": commentImage!.path.split('/').last, "type": "image/jpeg", "size": commentImage!.lengthSync(), "base64": base64Image}];
                    }

                    var res = await Dio().post("$_baseUrl/api/comments/${_getTicketId(ticket)}", data: payload, options: Options(headers: {"Authorization": "Bearer $token"}));

                    if (res.statusCode == 200 || res.statusCode == 201) {
                      commentController.clear();
                      commentImage = null;
                      fetchComments(isBackground: true); // 🔥 Instantly fetch silently after sending
                    }
                  } catch (e) {
                    _showOverlayMsg(context, "Failed to send comment", Colors.red);
                  } finally {
                    setModalState(() => isSending = false);
                  }
                }

                return Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.85,
                    decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Comments", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                                  Text(displayTicketId.toUpperCase(), style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              Container(
                                decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey.shade100, shape: BoxShape.circle),
                                child: IconButton(icon: Icon(Icons.close, color: textColor), onPressed: () => Navigator.pop(context)),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: borderColor),

                        Expanded(
                            child: isLoadingComments
                                ? const Center(child: CircularProgressIndicator())
                                : comments.isEmpty
                                ? Center(child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 60, color: isDark ? Colors.white24 : Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text("No comments yet.", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w500)),
                              ],
                            ))
                                : ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.all(20),
                              itemCount: comments.length,
                              itemBuilder: (context, index) {
                                var c = comments[index];

                                String senderId = "";
                                String senderName = "User";
                                if (c["senderId"] != null) {
                                  if (c["senderId"] is Map) {
                                    senderId = c["senderId"]["_id"]?.toString() ?? "";
                                    senderName = c["senderId"]["name"]?.toString() ?? "User";
                                  } else {
                                    senderId = c["senderId"].toString();
                                  }
                                }

                                bool isMe = senderId == _currentUserId;
                                String dateStr = c["createdAt"] != null ? DateFormat('dd MMM, hh:mm a').format(DateTime.parse(c["createdAt"]).toLocal()) : "";
                                String message = c["message"]?.toString() ?? "";

                                String? attachedImageUrl;
                                if (c["attachments"] != null && (c["attachments"] as List).isNotEmpty) {
                                  attachedImageUrl = c["attachments"][0]['url'];
                                }

                                return Align(
                                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                                    decoration: BoxDecoration(
                                        color: isMe ? (isDark ? const Color(0xFFF3C300).withOpacity(0.2) : const Color(0xFFFEF9C3)) : (isDark ? Colors.white10 : Colors.white),
                                        border: isMe ? null : Border.all(color: borderColor),
                                        borderRadius: BorderRadius.circular(16).copyWith(
                                          bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                                          bottomLeft: !isMe ? const Radius.circular(4) : const Radius.circular(16),
                                        ),
                                        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Text(isMe ? "You" : senderName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isMe ? const Color(0xFFB48600) : (isDark ? Colors.white70 : Colors.grey.shade800))),
                                            const SizedBox(width: 8),
                                            Text(dateStr, style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(message, style: TextStyle(fontSize: 15, color: textColor, height: 1.3)),

                                        if (attachedImageUrl != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 12.0),
                                            child: InkWell(
                                              onTap: () => _openImageDialog(attachedImageUrl!),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: Image.network(
                                                  attachedImageUrl.startsWith('http') ? attachedImageUrl : "$_baseUrl$attachedImageUrl",
                                                  height: 140, width: double.infinity, fit: BoxFit.cover,
                                                  errorBuilder: (c, e, s) => Container(height: 140, width: double.infinity, color: isDark ? Colors.white12 : Colors.grey.shade100, child: const Icon(Icons.broken_image, color: Colors.grey)),
                                                ),
                                              ),
                                            ),
                                          )
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                        ),

                        if (ticket.status.toLowerCase() == 'closed')
                          Container(padding: const EdgeInsets.all(16), color: isDark ? Colors.red.withOpacity(0.1) : Colors.red.shade50, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.lock_outline, size: 18, color: Colors.red), const SizedBox(width: 8), Text("Ticket is closed.", style: TextStyle(color: isDark ? Colors.red.shade400 : Colors.red, fontWeight: FontWeight.bold, fontSize: 15))]))
                        else if (_canAddComment)
                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                            decoration: BoxDecoration(color: bgColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]),
                            child: Column(
                              children: [
                                if (commentImage != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.shade100)),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.image, size: 16, color: isDark ? Colors.blue.shade400 : Colors.blue),
                                            const SizedBox(width: 8),
                                            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 150), child: Text(commentImage!.path.split('/').last, style: TextStyle(fontSize: 12, color: isDark ? Colors.blue.shade400 : Colors.blue, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                            const SizedBox(width: 12),
                                            InkWell(onTap: () => setModalState(()=> commentImage = null), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.white, shape: BoxShape.circle), child: const Icon(Icons.close, size: 14, color: Colors.red)))
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                Row(
                                  children: [
                                    if (_canUploadAttachment)
                                      Container(
                                        margin: const EdgeInsets.only(right: 12),
                                        decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey.shade100, shape: BoxShape.circle),
                                        child: IconButton(
                                            icon: Icon(commentImage != null ? Icons.image : Icons.attach_file, color: commentImage != null ? Colors.blue : (isDark ? Colors.white70 : Colors.grey.shade700), size: 22),
                                            onPressed: () async {
                                              final file = await ImagePicker().pickImage(source: ImageSource.gallery);
                                              if (file != null) setModalState(() => commentImage = File(file.path));
                                            }
                                        ),
                                      ),
                                    Expanded(
                                      child: TextField(
                                        controller: commentController,
                                        style: TextStyle(color: textColor),
                                        decoration: InputDecoration(
                                            hintText: "Type a message...",
                                            hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade400),
                                            filled: true, fillColor: inputColor,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    InkWell(
                                      onTap: isSending ? null : sendComment,
                                      child: Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: const BoxDecoration(color: Color(0xFFF3C300), shape: BoxShape.circle),
                                          child: isSending ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) : const Icon(Icons.send, color: Colors.black, size: 22)
                                      ),
                                    )
                                  ],
                                ),
                              ],
                            ),
                          )
                      ],
                    ),
                  ),
                );
              }
          );
        }
    ).whenComplete(() {
      // 🔥 KILL TIMER WHEN CHAT MODAL IS CLOSED
      chatTimer?.cancel();
    });
  }

  // =========================================================================
  // 🔥 IMAGE VIEWER DIALOG WITH DIRECT DOWNLOAD (NO CHROME)
  // =========================================================================
  Future<void> _downloadFile(String url) async {
    String fullUrl = url.startsWith('http') ? url : "$_baseUrl$url";

    try {
      if (mounted) {
        _showOverlayMsg(context, "Downloading image... Please wait.", Colors.blue);
      }

      var response = await Dio().get(fullUrl, options: Options(responseType: ResponseType.bytes));

      String fileName = fullUrl.split('/').last.split('?').first;
      if (!fileName.contains('.')) fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";

      String savePath;
      if (Platform.isAndroid) {
        savePath = "/storage/emulated/0/Download/$fileName";
      } else {
        savePath = "${Directory.systemTemp.path}/$fileName";
      }

      File file = File(savePath);
      await file.writeAsBytes(response.data);

      if (mounted) {
        _showOverlayMsg(context, "Image saved successfully to Downloads folder!", Colors.green);
      }
    } catch (e) {
      debugPrint("Download Error: $e");

      final Uri uri = Uri.parse(fullUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) _showOverlayMsg(context, "Failed to download image.", Colors.red);
      }
    }
  }

  void _openImageDialog(String imgUrl) {
    String fullUrl = imgUrl.startsWith('http') ? imgUrl : "$_baseUrl$imgUrl";

    showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    fullUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                        height: 200, width: double.infinity,
                        color: Colors.white, padding: const EdgeInsets.all(32),
                        child: const Center(child: Text("Could not load file. It might not be an image.", textAlign: TextAlign.center))
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: 20,
                child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                    onPressed: () => _downloadFile(fullUrl),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text("Download File", style: TextStyle(fontWeight: FontWeight.bold))
                ),
              ),

              Positioned(
                top: 10, right: 10,
                child: Container(
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 24), onPressed: () => Navigator.pop(context)),
                ),
              )
            ],
          ),
        )
    );
  }

  // =========================================================================
  // 🔥 BUILD GLOBAL APP BAR WITH AVATAR & DARK MODE TOGGLE
  // =========================================================================
  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E293B),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: const Text("Tickets", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      actions: [
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

  // =========================================================================
  // 🔥 MAIN UI
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white70 : Colors.grey.shade600;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;

    if (!_isLoading && !_hasAnyTicketViewAccess) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: _buildModernAppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 80, color: isDark ? Colors.white24 : Colors.grey.shade400),
              const SizedBox(height: 24),
              Text("Access Denied", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
              Text("Contact Administrator.", style: TextStyle(color: subTextColor)),
            ],
          ),
        ),
      );
    }

    int total = _displayedTickets.length;
    int open = _displayedTickets.where((t) => t.status.toLowerCase() == 'open').length;
    int inProgress = _displayedTickets.where((t) => t.status.toLowerCase().contains('progress')).length;
    int closed = _displayedTickets.where((t) => t.status.toLowerCase() == 'closed' || t.status.toLowerCase() == 'resolved').length;

    return Scaffold(
      backgroundColor: bgColor,
      drawer: const MenuDrawer(currentRoute: 'tickets'),
      appBar: _buildModernAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF3C300)))
          : RefreshIndicator(
        onRefresh: _loadDataAndPermissions,
        color: const Color(0xFF1E293B),
        child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                controller: _scrollController, // 🔥 PAGINATION SCROLLER
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
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
                              Text(
                                  "Tickets Management",
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Overview and tracking of all support requests",
                                style: TextStyle(color: subTextColor, fontSize: 12),
                                overflow: TextOverflow.visible,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_canCreateTicket)
                          ElevatedButton.icon(
                            onPressed: () => _openCreateOrEditSheet(),
                            icon: const Icon(Icons.add, size: 16, color: Colors.black),
                            label: const Text("New Ticket", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF3C300),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 2
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _buildKPIGrid(total, open, inProgress, closed, isDark),
                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                  children: [
                                    Container(width: 4, height: 20, decoration: BoxDecoration(color: const Color(0xFFF3C300), borderRadius: BorderRadius.circular(8)), margin: const EdgeInsets.only(right: 10)),
                                    Text(
                                        "${_canViewAllTickets ? 'All Tickets' : 'My Tickets'} (${_displayedTickets.length})",
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)
                                    )
                                  ]
                              ),
                              OutlinedButton.icon(
                                onPressed: _loadDataAndPermissions, icon: Icon(Icons.refresh, size: 14, color: textColor), label: Text("Refresh", style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), side: BorderSide(color: borderColor)),
                              )
                            ],
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: SizedBox(
                                  height: 42,
                                  child: TextField(
                                    controller: _searchController, onChanged: (val) => _applyFilters(),
                                    style: TextStyle(fontSize: 13, color: textColor),
                                    decoration: InputDecoration(hintText: "Search...", hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade400, fontSize: 12), filled: true, fillColor: isDark ? Colors.white10 : Colors.grey.shade50, prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.grey.shade400, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)), contentPadding: const EdgeInsets.symmetric(vertical: 0)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                  flex: 3,
                                  child: SizedBox(
                                      height: 42,
                                      child: _buildDropdown(_selectedStatus, _statusOptions, (val) { setState(() => _selectedStatus = val!); _applyFilters(); }, isDark)
                                  )
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                  flex: 3,
                                  child: SizedBox(
                                      height: 42,
                                      child: _buildDropdown(_selectedPriority, _priorityOptions, (val) { setState(() => _selectedPriority = val!); _applyFilters(); }, isDark)
                                  )
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          Divider(color: isDark ? Colors.white12 : Colors.grey.shade100, height: 1),
                          const SizedBox(height: 16),

                          if (_displayedTickets.isEmpty)
                            Padding(
                                padding: const EdgeInsets.all(40.0),
                                child: Center(
                                    child: Column(
                                      children: [
                                        Icon(Icons.inbox_outlined, size: 50, color: isDark ? Colors.white24 : Colors.grey.shade300),
                                        const SizedBox(height: 12),
                                        Text("No tickets found.", style: TextStyle(color: subTextColor, fontSize: 14, fontWeight: FontWeight.w500)),
                                      ],
                                    )
                                )
                            )
                          else if (constraints.maxWidth > 800)
                            _buildDesktopTable(isDark, textColor, subTextColor, borderColor)
                          else
                            _buildMobileList(isDark, textColor, subTextColor, borderColor),
                        ],
                      ),
                    ),

                    // 🔥 LOADING INDICATOR FOR NEXT PAGE
                    if (_isFetchingMore)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: Center(
                          child: CircularProgressIndicator(color: Color(0xFFF3C300)),
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

  Widget _buildKPIGrid(int total, int open, int progress, int closed, bool isDark) {
    return LayoutBuilder(builder: (context, constraints) {
      double width = constraints.maxWidth;
      double cardWidth = width > 800 ? (width - 48) / 4 : (width - 16) / 2;
      String prefix = _canViewAllTickets ? "Total" : "My";

      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildPremiumKPICard(prefix, "$_kpiTotal", Icons.confirmation_number_outlined, cardWidth, isDark),
          _buildPremiumKPICard("Open", "$_kpiOpen", Icons.folder_open, cardWidth, isDark),
          _buildPremiumKPICard("In Progress", "$_kpiInProgress", Icons.rotate_right, cardWidth, isDark),
          _buildPremiumKPICard("Closed", "$_kpiClosed", Icons.check_circle_outline, cardWidth, isDark),
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1A1A1A) : Colors.white, border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          icon: Icon(Icons.keyboard_arrow_down, color: isDark ? Colors.white54 : Colors.grey.shade500, size: 16),
          style: TextStyle(fontSize: 11, color: isDark ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.w600),
          onChanged: onChanged,
          items: options.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)))).toList(),
        ),
      ),
    );
  }

  Widget _buildDesktopTable(bool isDark, Color textColor, Color subTextColor, Color borderColor) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(
                children: [
                  _headerCell("ID", 80, subTextColor),
                  _headerCell("SUBJECT", 220, subTextColor),
                  _headerCell("STATUS", 120, subTextColor),
                  _headerCell("PRIORITY", 120, subTextColor),
                  if (_canViewAllTickets) _headerCell("CREATED BY", 150, subTextColor),
                  _headerCell("ASSIGNED TO", 160, subTextColor),
                  _headerCell("FILES", 150, subTextColor),
                  _headerCell("CREATED", 110, subTextColor),
                  _headerCell("ACTIONS", 250, subTextColor),
                ]
            ),
          ),
          const SizedBox(height: 8),
          ..._displayedTickets.map((t) => _buildTableRowDesktop(t, isDark, textColor, subTextColor, borderColor)),
        ],
      ),
    );
  }

  Widget _headerCell(String text, double width, Color subTextColor) => SizedBox(width: width, child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subTextColor, letterSpacing: 0.5)));

  Widget _buildTableRowDesktop(Ticket t, bool isDark, Color textColor, Color subTextColor, Color borderColor) {
    String dateStr = "N/A";
    try { if (t.createdAt.isNotEmpty) dateStr = DateFormat('dd MMM yyyy').format(DateTime.parse(t.createdAt).toLocal()); } catch (_) {}

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade100))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: _buildPremiumIDPill(t, isDark)),
          SizedBox(width: 220, child: Text(t.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textColor), overflow: TextOverflow.ellipsis)),
          SizedBox(width: 120, child: Align(alignment: Alignment.centerLeft, child: _buildPremiumDotPill(t.status, isDark))),
          SizedBox(width: 120, child: Align(alignment: Alignment.centerLeft, child: _buildPremiumDotPill(t.priority, isDark))),

          if (_canViewAllTickets)
            SizedBox(
                width: 150,
                child: Text(
                    _getCreatorName(t),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                    overflow: TextOverflow.ellipsis
                )
            ),

          SizedBox(width: 160, child: _buildAssigneeCell(t, textColor, isDark)),
          SizedBox(width: 150, child: _buildAttachmentRow(t, subTextColor, isDark)),
          SizedBox(width: 110, child: Text(dateStr, style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w500))),
          SizedBox(width: 250, child: _buildActionsRow(t, isDark, borderColor)),
        ],
      ),
    );
  }

  Widget _buildMobileList(bool isDark, Color textColor, Color subTextColor, Color borderColor) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _displayedTickets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final t = _displayedTickets[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12), color: isDark ? const Color(0xFF1A1A1A) : Colors.white, boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPremiumIDPill(t, isDark),
                    _buildPremiumDotPill(t.status, isDark)
                  ]
              ),
              const SizedBox(height: 10),

              Text(t.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),

              if (_canViewAllTickets) ...[
                const SizedBox(height: 6),
                Row(
                    children: [
                      Icon(Icons.person_outline, size: 14, color: subTextColor),
                      const SizedBox(width: 4),
                      Text("By: ${_getCreatorName(t)}", style: TextStyle(fontSize: 12, color: subTextColor)),
                    ]
                )
              ],
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: _buildAssigneeCell(t, textColor, isDark)),
                      _buildPremiumDotPill(t.priority, isDark),
                    ]
                ),
              ),

              _buildAttachmentRow(t, subTextColor, isDark),

              Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: borderColor)),

              SizedBox(
                width: double.infinity,
                child: _buildActionsRow(t, isDark, borderColor),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiumIDPill(Ticket t, bool isDark) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: isDark ? const Color(0xFFFEF9C3).withOpacity(0.1) : const Color(0xFFFEF9C3).withOpacity(0.5), borderRadius: BorderRadius.circular(6), border: Border.all(color: isDark ? const Color(0xFFFEF9C3).withOpacity(0.2) : const Color(0xFFFEF9C3))),
        child: Text(_getDisplayTicketNumber(t).toUpperCase(), style: const TextStyle(color: Color(0xFFB48600), fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5))
    );
  }

  Widget _buildPremiumDotPill(String text, bool isDark) {
    Color color; Color bgColor; String val = text.toLowerCase();
    if (val == 'open' || val == 'high') { color = Colors.orange.shade700; bgColor = isDark ? Colors.orange.withOpacity(0.1) : Colors.orange.shade50; }
    else if (val.contains('progress') || val == 'medium') { color = Colors.blue.shade700; bgColor = isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50; }
    else if (val == 'critical') { color = Colors.red.shade700; bgColor = isDark ? Colors.red.withOpacity(0.1) : Colors.red.shade50; }
    else { color = Colors.green.shade700; bgColor = isDark ? Colors.green.withOpacity(0.1) : Colors.green.shade50; }

    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
        child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))
            ]
        )
    );
  }

  Widget _buildAttachmentRow(Ticket t, Color subTextColor, bool isDark) {
    List<String> imageUrls = [];
    try {
      if (t.attachments.isNotEmpty) {
        for(var att in t.attachments) {
          try {
            var url = (att as dynamic).url;
            if(url != null) imageUrls.add(url.toString());
          } catch(_) { }
        }
      }
    } catch(e) { }

    if (imageUrls.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Attachments (${imageUrls.length})", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subTextColor)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: imageUrls.map((url) {
              String fullUrl = url.startsWith('http') ? url : "$_baseUrl$url";
              return InkWell(
                onTap: () => _openImageDialog(fullUrl),
                borderRadius: BorderRadius.circular(6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    fullUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                        width: 40, height: 40, color: isDark ? Colors.white10 : Colors.grey.shade100,
                        child: Icon(Icons.broken_image, size: 18, color: isDark ? Colors.white54 : Colors.grey)
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );

  }

  Widget _buildAssigneeCell(Ticket t, Color textColor, bool isDark) {
    String assigneeName = _getAssigneeName(t);

    if (assigneeName == "--") {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          "Unassigned",
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal:3, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFF3C300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            "Assigned: $assigneeName",
            style: const TextStyle(
              fontSize: 11
              ,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionsRow(Ticket t, bool isDark, Color borderColor) {
    bool isClosed = t.status.toLowerCase() == 'closed' ;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        if (_canViewComment || _canAddComment)
          _styledActionButton("Comment", isDark ? Colors.white70 : Colors.grey.shade700, Icons.chat_bubble_outline, () => _openCommentsModal(t), isDark, borderColor),

        if (_canEditTicket && !isClosed)
          _styledActionButton("Edit", Colors.orange.shade700, Icons.edit_outlined, () => _openCreateOrEditSheet(ticket: t), isDark, borderColor),

        if (_canDeleteTicket && !isClosed)
          _styledActionButton(
              "Delete",
              Colors.red.shade600,
              Icons.delete_outline,
                  () {
                final reasonCtrl = TextEditingController();
                showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text("Delete Ticket", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16))]),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Provide a reason to delete this ticket.", style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
                          const SizedBox(height: 12),
                          TextField(controller: reasonCtrl, style: TextStyle(color: isDark ? Colors.white : Colors.black87), maxLines: 2, decoration: InputDecoration(hintText: "Reason *", hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade400, fontSize: 13), filled: true, fillColor: isDark ? Colors.white10 : Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200)))),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text("Cancel", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600, fontWeight: FontWeight.bold))),
                        ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                            onPressed: () async {
                              if (reasonCtrl.text.trim().isEmpty) {
                                _showOverlayMsg(dialogContext, "Reason required", Colors.orange);
                                return;
                              }
                              Navigator.pop(dialogContext);
                              try {
                                const storage = FlutterSecureStorage();
                                String? token = await storage.read(key: "jwt_token");
                                await Dio().delete("$_baseUrl/api/tickets/${_getTicketId(t)}", data: {"reason": reasonCtrl.text.trim()}, options: Options(headers: {"Authorization": "Bearer $token"}));
                                _loadDataAndPermissions();
                                _showOverlayMsg(context, "Ticket Deleted", Colors.green);
                              } catch (e) {
                                _showOverlayMsg(context, "Failed to delete", Colors.red);
                              }
                            },
                            child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                        )
                      ],
                    )
                );
              },
              isDark,
              borderColor
          ),
      ],
    );
  }

  Widget _styledActionButton(String label, Color color, IconData icon, VoidCallback onTap, bool isDark, Color borderColor) {
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