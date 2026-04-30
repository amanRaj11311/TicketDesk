import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/ticket.dart';
import 'dart:io';

class TicketService {
  // 🔥 POINTING DIRECTLY TO THE NODE.JS BACKEND!
  final String _baseUrl = "https://ticketapi.dcstechnosis.com/api";
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<List<Ticket>> fetchTickets() async {
    try {
      String? token = await _storage.read(key: "jwt_token");
      if (token == null) return [];

      var response = await _dio.get(
        "$_baseUrl/tickets",
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
        ),
      );

      if (response.statusCode == 200) {
        var data = response.data;
        List dynamicList = [];

        if (data is List) {
          dynamicList = data;
        } else if (data is Map) {
          dynamicList =
              data['tickets'] ?? data['data'] ?? data['results'] ?? [];
        }

        return dynamicList.map((json) => Ticket.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      debugPrint(
          "Ticket Fetch Error [${e.response?.statusCode}]: ${e.response?.data}");
      return [];
    } catch (e) {
      debugPrint("General Ticket Error: $e");
      return [];
    }
  }

  Future<int> createTicket(
      String subject, String description, String priority, File? image) async {
    try {
      String? token = await _storage.read(key: "jwt_token");
      if (token == null) return 401;

      FormData formData = FormData.fromMap({
        "subject": subject,
        "description": description,
        "priority": priority,
        if (image != null)
          "image": await MultipartFile.fromFile(image.path,
              filename: image.path.split('/').last),
      });

      Response response = await _dio.post(
        "$_baseUrl/tickets",
        data: formData,
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      return response.statusCode ?? 500;
    } on DioException catch (e) {
      debugPrint("❌ Create Ticket Fail: ${e.response?.data}");
      return e.response?.statusCode ?? 500;
    } catch (e) {
      return 500;
    }
  }
}
