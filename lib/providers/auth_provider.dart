import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  UserModel? get user => _user;
  bool get isLoading => _isLoading;

  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Call the service layer
      _user = await _authService.loginUser(email, password);

      _isLoading = false;
      notifyListeners();

      return _user?.role; // This returns 'admin', 'user', or null
    } catch (e) {
      debugPrint("API Error in Provider: $e");
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> logout() async {
    _user = null;
    await _authService.logout();
    notifyListeners();
  }
}
