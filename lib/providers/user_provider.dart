import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class UserProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  UserModel? _targetUser;
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  UserModel? get targetUser => _targetUser;

  Future<void> updateUserProfile(UserModel updatedUser) async {
    _setLoading(true);
    try {
      await _dbService.updateUser(updatedUser);
      // Update local state immediately
      _targetUser = updatedUser;
      notifyListeners();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Method to refresh user data if needed independently of AuthProvider
  // Though AuthProvider usually holds the source of truth for the current logged-in user
  Future<void> fetchUserById(String userId) async {
    _setLoading(true);
    try {
      _targetUser = await _dbService.getUserById(userId);
      notifyListeners();
    } catch (e) {
      _targetUser = null;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<UserModel?> getUser(String userId) async {
    return await _dbService.getUserById(userId);
  }

  Future<void> deleteAccount(String userId) async {
    _setLoading(true);
    try {
      final authService = AuthService();
      await authService.deleteAccount(userId);
      _targetUser = null;
      notifyListeners();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
