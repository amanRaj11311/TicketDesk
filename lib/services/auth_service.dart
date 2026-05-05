import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

class AuthService {
  final String loginUrl = 'https://uat.ticketapi.dcstechnosis.com/api/auth/login';
  final _storage = const FlutterSecureStorage();

  // 1. Login Method
  Future<UserModel?> loginUser(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 🔥 SAVE BOTH TOKEN AND USER DATA!
        await _storage.write(key: 'jwt_token', value: data['accessToken']);
        await _storage.write(key: 'user_data', value: jsonEncode(data['user']));

        return UserModel.fromJson(data['user']);
      } else {
        return null;
      }
    } catch (e) {
      throw Exception("Network Error: $e");
    }
  }

  // 2. Verify Token Method (For Splash Screen)
  Future<String?> verifyToken() async {
    try {
      String? token = await _storage.read(key: "jwt_token");
      String? userData = await _storage.read(key: "user_data");

      if (token == null || userData == null) return null;

      // Instead of hitting a missing API, we read the locally saved role!
      final userJson = jsonDecode(userData);
      return userJson['role'];
    } catch (e) {
      return null;
    }
  }

  // 3. Logout Method
  Future<void> logout() async {
    await _storage.deleteAll();
  }
}
