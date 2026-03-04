import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    checkAuthState();
  }

  Future<void> checkAuthState() async {
    _setLoading(true);
    try {
      _currentUser = await _authService.getCurrentUser();
    } catch (e) {
      _errorMessage = e.toString();
      _currentUser = null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshUser() async {
    if (_currentUser == null) return;
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        _currentUser = user;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error refreshing user: $e');
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required List<String> roles,
    String? phoneNumber,
    String? organizationName,
    String? recipientType,
    List<String>? allergies,
  }) async {
    _setLoading(true);
    try {
      final user = await _authService.signUp(
        email: email,
        password: password,
        name: name,
        roles: roles,
        phoneNumber: phoneNumber,
        organizationName: organizationName,
        recipientType: recipientType,
        allergies: allergies,
      );
      _currentUser = user;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    try {
      final user = await _authService.signIn(email: email, password: password);
      _currentUser = user;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _currentUser = null;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resetPassword(String email) async {
    _setLoading(true);
    try {
      await _authService.resetPassword(email: email);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> switchRole(String newRole) async {
    if (_currentUser == null) return false;
    
    if (!_currentUser!.hasRole(newRole)) {
      _errorMessage = "User does not have role: $newRole";
      notifyListeners();
      return false;
    }

    _setLoading(true);
    try {
      final updatedUser = await _authService.switchRole(
        userId: _currentUser!.id,
        newRole: newRole,
      );
      _currentUser = updatedUser;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
