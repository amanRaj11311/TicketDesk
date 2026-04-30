import 'dart:convert';

class TicketAttachment {
  final String url;
  final String filename;

  TicketAttachment({required this.url, required this.filename});

  factory TicketAttachment.fromJson(dynamic json) {
    if (json == null) return TicketAttachment(url: '', filename: '');
    return TicketAttachment(
      url: json['url']?.toString() ?? '',
      filename: json['filename']?.toString() ?? '',
    );
  }
}

class Ticket {
  final String id;
  final String ticketId;
  final String subject;
  final String description;
  final String status;
  final String priority;
  final List<TicketAttachment> attachments;

  // 🔥 ADDED THESE TWO FIELDS FOR ROLE FILTERING
  final String? createdBy;
  final String? assignedTo;

  Ticket({
    required this.id,
    required this.ticketId,
    required this.subject,
    required this.description,
    required this.status,
    required this.priority,
    required this.attachments,
    this.createdBy,
    this.assignedTo,
  });

  factory Ticket.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return Ticket(
          id: '',
          ticketId: 'TK-000',
          subject: 'Unknown',
          description: '',
          status: 'Open',
          priority: 'Low',
          attachments: []);
    }

    // Safely parse attachments list
    var attachmentList = json['attachments'] as List? ?? [];
    List<TicketAttachment> parsedAttachments =
        attachmentList.map((i) => TicketAttachment.fromJson(i)).toList();

    // 🔥 SMART EXTRACTOR: Handles both Strings and MongoDB nested Objects
    String? extractIdSafely(dynamic field) {
      if (field == null) return null;
      if (field is String) return field;
      if (field is Map) {
        return field['_id']?.toString() ?? field['id']?.toString();
      }
      return field.toString();
    }

    return Ticket(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',

      ticketId: json['ticketId']?.toString() ?? 'TK-000',

      subject: json['subject']?.toString() ?? 'No Subject',
      description: json['description']?.toString() ?? 'No Description',
      status: json['status']?.toString() ?? 'Open',
      priority: json['priority']?.toString() ?? 'Low',
      attachments: parsedAttachments,

      // 🔥 POPULATE THE NEW FIELDS
      createdBy: extractIdSafely(json['createdBy']),
      assignedTo: extractIdSafely(json['assignedTo']),
    );
  }
}
