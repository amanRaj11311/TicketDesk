import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/ticket.dart';

class TicketDetailScreen extends StatefulWidget {
  final Ticket ticket;
  const TicketDetailScreen({super.key, required this.ticket});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final String _baseUrl = "https://ticketapi.dcstechnosis.com";
  bool _canEdit = false;
  bool _canDelete = false;
  bool _isAdmin = false;
  late Ticket _currentTicket;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentTicket = widget.ticket;

    // 🔥 DEMO DATA FOR SCREENSHOTS: Agar image nahi hai, to 2 mast demo images daal do
    if (_currentTicket.attachments.isEmpty) {
      _currentTicket = Ticket(
        id: _currentTicket.id,
        ticketId: _currentTicket.ticketId,
        subject: _currentTicket.subject,
        description: _currentTicket.description,
        status: _currentTicket.status,
        priority: _currentTicket.priority,
        attachments: [
          TicketAttachment(
              url: 'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?auto=format&fit=crop&w=500&q=80',
              filename: 'network_error.jpg'),
          TicketAttachment(
              url: 'https://images.unsplash.com/photo-1593640408182-31c70c8268f5?auto=format&fit=crop&w=500&q=80',
              filename: 'hardware_issue.jpg'),
        ],
      );
    }

    _fetchUserPermissions();
  }

  Future<void> _fetchUserPermissions() async {
    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");

      if (token == null) {
        // 🔥 MOCK PERMISSIONS FOR DEMO (If no token)
        setState(() { _isAdmin = true; _canEdit = true; _canDelete = true; });
        return;
      }

      var response = await Dio().get("$_baseUrl/api/auth/me",
          options: Options(headers: {"Authorization": "Bearer $token"}));

      if (response.statusCode == 200) {
        final userData = response.data['user'];
        setState(() {
          _isAdmin = userData['role'] == 'admin';
          _canEdit = _isAdmin || (userData['canEditTicket'] == true);
          _canDelete = _isAdmin || (userData['canDeleteTicket'] == true);
        });
      }
    } catch (e) {
      debugPrint("Permission error: $e");
      // 🔥 MOCK PERMISSIONS FOR DEMO (If API is down)
      if (mounted) {
        setState(() { _isAdmin = true; _canEdit = true; _canDelete = true; });
      }
    }
  }

  // 🔥 1. FULL EDIT DIALOG
  Future<void> _showEditDialog() async {
    String mongoId = _currentTicket.id;
    if (mongoId.isEmpty || mongoId == "null") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Critical Error: MongoDB ID missing."),
          backgroundColor: Colors.red));
      return;
    }

    TextEditingController subjectCtrl =
    TextEditingController(text: _currentTicket.subject);
    TextEditingController descCtrl =
    TextEditingController(text: _currentTicket.description);

    List<XFile> newlySelectedImages = [];
    List<TicketAttachment> displayedCurrentImages =
    List.from(_currentTicket.attachments);
    List<String> filenamesToRemove = [];

    final ImagePicker picker = ImagePicker();

    bool confirm = await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text("Edit Ticket",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Subject",
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextField(
                        controller: subjectCtrl,
                        decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12))),
                    const SizedBox(height: 16),
                    const Text("Description",
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextField(
                        controller: descCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12))),
                    const SizedBox(height: 16),
                    if (displayedCurrentImages.isNotEmpty) ...[
                      const Text("Current Images (tap 'X' to remove)",
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: displayedCurrentImages.map((img) {
                          int index = displayedCurrentImages.indexOf(img);
                          // 🔥 Handle Dummy URLs vs Real URLs safely
                          String finalUrl = img.url.startsWith('http') ? img.url : "$_baseUrl${img.url}";

                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(finalUrl,
                                    fit: BoxFit.cover,
                                    width: 80,
                                    height: 80,
                                    errorBuilder: (c, e, s) => Container(
                                        width: 80,
                                        height: 80,
                                        color: Colors.grey.shade300,
                                        child: const Icon(
                                            Icons.broken_image))),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      filenamesToRemove.add(img.filename);
                                      displayedCurrentImages
                                          .removeAt(index);
                                    });
                                  },
                                  child: CircleAvatar(
                                      radius: 12,
                                      backgroundColor:
                                      Colors.red.withOpacity(0.8),
                                      child: const Icon(Icons.close,
                                          size: 16, color: Colors.white)),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    OutlinedButton.icon(
                      onPressed: () async {
                        final List<XFile> images =
                        await picker.pickMultiImage();
                        if (images.isNotEmpty) {
                          setDialogState(
                                  () => newlySelectedImages.addAll(images));
                        }
                      },
                      icon: const Icon(Icons.add_photo_alternate,
                          color: Colors.blue),
                      label: const Text("Add More New Images",
                          style: TextStyle(color: Colors.blue)),
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.blue),
                          minimumSize: const Size(double.infinity, 45)),
                    ),
                    if (newlySelectedImages.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                          "${newlySelectedImages.length} new images selected",
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.bold)),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Cancel")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF3C300)),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Save Changes",
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            );
          });
        }) ??
        false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");

      final Map<String, dynamic> finalMap = {
        "subject": subjectCtrl.text.trim(),
        "description": descCtrl.text.trim(),
        "removedImages[]": filenamesToRemove,
      };

      FormData formData =
      FormData.fromMap(finalMap, ListFormat.multiCompatible);

      for (var file in newlySelectedImages) {
        formData.files.add(MapEntry(
          "images",
          await MultipartFile.fromFile(file.path, filename: file.name),
        ));
      }

      if (filenamesToRemove.isNotEmpty) {
        formData = FormData.fromMap({
          "subject": subjectCtrl.text.trim(),
          "description": descCtrl.text.trim(),
        });
        for (var filename in filenamesToRemove) {
          formData.fields.add(MapEntry("removedImages", filename));
        }
      }

      var response = await Dio().patch(
        "$_baseUrl/api/tickets/$mongoId",
        data: formData,
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      setState(() {
        _currentTicket = Ticket.fromJson(response.data['data']);
        _isLoading = false;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Ticket Details and Images updated!"),
            backgroundColor: Colors.green));
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Update Error: $e"), backgroundColor: Colors.red));
    }
  }

  // 🔥 2. DELETE TICKET
  Future<void> _deleteTicket() async {
    String mongoId = _currentTicket.id;
    if (mongoId.isEmpty || mongoId == "null") return;

    bool confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Delete Ticket",
              style: TextStyle(color: Colors.red)),
          content: const Text(
              "Are you sure you want to permanently delete this ticket? All associated image files will also be removed from the server."),
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

      await Dio().delete("$_baseUrl/api/tickets/$mongoId",
          options: Options(headers: {"Authorization": "Bearer $token"}));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Ticket and associated image files deleted"),
            backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Delete Error: $e"), backgroundColor: Colors.red));
    }
  }

  // 🔥 3. QUICK STATUS CHANGE (Admin)
  Future<void> _quickChangeStatus(String newStatus) async {
    setState(() => _isLoading = true);
    try {
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: "jwt_token");

      var response = await Dio().patch(
        "$_baseUrl/api/tickets/${_currentTicket.id}",
        data: {"status": newStatus},
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      setState(() {
        _currentTicket = Ticket.fromJson(response.data['data']);
        _isLoading = false;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Status changed to $newStatus"),
            backgroundColor: Colors.green));
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(_currentTicket.ticketId,
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_canEdit)
            IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: _showEditDialog),
          if (_canDelete)
            IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _deleteTicket),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: Color(0xFFF3C300)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderPills(),
            const SizedBox(height: 24),
            Text(_currentTicket.subject,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 16),
            const Text("Description",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200)),
              child: Text(_currentTicket.description,
                  style: const TextStyle(fontSize: 16)),
            ),
            if (_currentTicket.attachments.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text("Attached Images (tap to view full screen)",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _currentTicket.attachments.map((img) {

                  // 🔥 Handle Dummy URLs vs Real URLs safely for UI
                  String finalUrl = img.url.startsWith('http') ? img.url : "$_baseUrl${img.url}";

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => FullScreenImageViewer(
                                imageUrl: finalUrl,
                                ticketId: _currentTicket.ticketId,
                              )));
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        finalUrl,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.broken_image,
                                  color: Colors.grey),
                            ),
                      ),
                    ),
                  );
                }).toList(),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderPills() {
    return Row(
      children: [
        if (_isAdmin)
          PopupMenuButton<String>(
            onSelected: _quickChangeStatus,
            child: _buildPill(
                _currentTicket.status, _getStatusColor(_currentTicket.status)),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Open', child: Text("Open")),
              const PopupMenuItem(
                  value: 'In Progress', child: Text("In Progress")),
              const PopupMenuItem(value: 'Closed', child: Text("Closed")),
            ],
          )
        else
          _buildPill(
              _currentTicket.status, _getStatusColor(_currentTicket.status)),
        const SizedBox(width: 12),
        _buildPill(_currentTicket.priority,
            _getPriorityColor(_currentTicket.priority)),
      ],
    );
  }

  Color _getStatusColor(String s) => s.toLowerCase() == 'open'
      ? Colors.orange
      : (s.toLowerCase() == 'closed' ? Colors.green : Colors.blue);
  Color _getPriorityColor(String p) => p.toLowerCase() == 'high'
      ? Colors.orange
      : (p.toLowerCase() == 'critical' ? Colors.red : Colors.purple);

  Widget _buildPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text.toUpperCase(),
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          if (_isAdmin) const Icon(Icons.arrow_drop_down, size: 16)
        ],
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String ticketId;

  const FullScreenImageViewer(
      {super.key, required this.imageUrl, required this.ticketId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text("Image for $ticketId",
            style: const TextStyle(color: Colors.white, fontSize: 14)),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const CircularProgressIndicator(color: Color(0xFFF3C300));
            },
            errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, color: Colors.grey, size: 50),
          ),
        ),
      ),
    );
  }
}