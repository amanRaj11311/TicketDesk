import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/api_constants.dart';
import '../models/ticket.dart';

class TicketService {
  // 🔥 Ek hi Dio instance use karna best practice hai
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ==========================================
  // 1. FETCH TICKETS (🔥 PAGINATION ADDED)
  // ==========================================
  Future<List<Ticket>> fetchTickets({int page = 1, int limit = 15}) async {
    try {
      String? token = await _storage.read(key: "jwt_token");
      if (token == null) return [];

      var response = await _dio.get(
        "${ApiConstants.baseUrl}/api/tickets?page=$page&limit=$limit",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (response.statusCode == 200) {
        List data = response.data['data'] ?? response.data['tickets'] ?? [];
        return data.map((json) => Ticket.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("Fetch Tickets Error: $e");
      return [];
    }
  }

  // ==========================================
  // 2. CREATE TICKET
  // ==========================================
  Future<int> createTicket(String title, String description, String priority, File? image) async {
    try {
      String? token = await _storage.read(key: "jwt_token");
      if (token == null) return 401; // Unauthorized (Session Expired)

      // FormData banayenge kyunki text ke saath image (file) bhi ja sakti hai
      FormData formData = FormData.fromMap({
        "title": title, // Agar backend 'subject' maange, to isko "subject" kar dena
        "description": description,
        "priority": priority.toLowerCase(),
      });

      if (image != null) {
        String fileName = image.path.split('/').last;
        formData.files.add(MapEntry(
          "images", // Backend me file receiver field ka naam "images" hona chahiye
          await MultipartFile.fromFile(image.path, filename: fileName),
        ));
      }

      var response = await _dio.post(
        "${ApiConstants.baseUrl}/api/tickets",
        data: formData,
        options: Options(
          headers: {"Authorization": "Bearer $token"},
          validateStatus: (status) => true, // App crash hone se rokega
        ),
      );

      // 🔥 Terminal me backend ka exact response dikhayega
      debugPrint("Create Ticket Response Code: ${response.statusCode}");
      debugPrint("Create Ticket Response Data: ${response.data}");

      return response.statusCode ?? 500;
    } catch (e) {
      debugPrint("Create Ticket Error: $e");
      return 500; // Internal Server Error
    }
  }
}