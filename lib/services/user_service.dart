import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserService {
  // 🔥 Using your Live Server URL
  final String _baseUrl = "https://ticketapi.dcstechnosis.com";
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Helper method to get the token
  Future<String?> _getToken() async {
    return await _storage.read(key: "jwt_token");
  }

  // 1. GET ALL USERS
  Future<List<dynamic>> getAllUsers() async {
    try {
      String? token = await _getToken();
      var response = await _dio.get(
        "$_baseUrl/api/users", // Assuming it has the /api prefix like auth
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      if (response.statusCode == 200) {
        // Adjust this depending on whether your API returns a direct array or wraps it in an object (e.g., response.data['data'])
        return response.data['users'] ?? response.data;
      }
      return [];
    } catch (e) {
      throw Exception("Failed to fetch users: $e");
    }
  }

  // 2. CREATE A NEW USER
  Future<bool> createUser(Map<String, dynamic> userData) async {
    try {
      String? token = await _getToken();
      var response = await _dio.post(
        "$_baseUrl/api/users",
        data: userData,
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 3. UPDATE USER STATUS (Active/Inactive)
  Future<bool> updateUserStatus(String userId, String status) async {
    try {
      String? token = await _getToken();
      var response = await _dio.patch(
        "$_baseUrl/api/users/$userId/status",
        data: {"status": status},
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 4. UPDATE USER ROLE
  Future<bool> updateUserRole(String userId, String roleId) async {
    try {
      String? token = await _getToken();
      var response = await _dio.patch(
        "$_baseUrl/api/users/$userId/role",
        data: {
          "role": roleId
        }, // Check your swagger docs for the exact JSON key needed here
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 5. DELETE A USER
  Future<bool> deleteUser(String userId) async {
    try {
      String? token = await _getToken();
      var response = await _dio.delete(
        "$_baseUrl/api/users/$userId",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
