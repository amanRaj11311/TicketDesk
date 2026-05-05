class TicketAttachment {
  final String url;
  final String filename;

  TicketAttachment({required this.url, required this.filename});

  factory TicketAttachment.fromJson(Map<String, dynamic> json) {
    return TicketAttachment(
      url: json['url'] ?? '',
      filename: json['filename'] ?? '',
    );
  }
}

class Ticket {
  final String id;
  final String ticketId;
  final String ticketNumber; // ✅ NEW FIELD
  final String title;
  final String description;
  final String status;
  final String priority;
  final String createdAt;
  final String createdBy;
  final dynamic assignedTo;
  final List<TicketAttachment> attachments;

  Ticket({
    required this.id,
    required this.ticketId,
    required this.ticketNumber, // ✅ ADD HERE
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.createdBy,
    this.assignedTo,
    required this.attachments,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['_id'] ?? '',
      ticketId: json['ticketId'] ?? '',
      ticketNumber: json['ticketNumber'] ?? '', // ✅ PARSE HERE
      title: json['title'] ?? 'No Title',
      description: json['description'] ?? '',
      status: json['status'] ?? 'Open',
      priority: json['priority'] ?? 'Low',
      createdAt: json['createdAt'] ?? '',
      createdBy: json['createdBy']?.toString() ?? '',
      assignedTo: json['assignedTo'],
      attachments: (json['attachments'] as List?)
          ?.map((x) => TicketAttachment.fromJson(x))
          .toList() ??
          [],
    );
  }
}