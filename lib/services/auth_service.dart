import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../models/reward_model.dart';
import '../models/user_model.dart';

class AuthService {
  final SupabaseClient _client = SupabaseConfig.client;

  // Stream of auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // Sign Up
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String name,
    required List<String> roles,
    String? phoneNumber,
    String? organizationName,
    String? recipientType,
    List<String>? allergies,
  }) async {
    debugPrint('Attempting Sign Up with email: $email');
    try {
      final AuthResponse res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'roles': roles,
          'phone_number': phoneNumber,
          'organization_name': organizationName,
          'recipient_type': recipientType,
          'allergies': allergies ?? [],
        },
      );

      final User? user = res.user;
      if (user == null) {
        throw Exception('Sign up failed: User creation returned null');
      }

      // If session is null, it means email confirmation is required.
      // The user record will be created by the DB trigger we added.
      // We return a temporary UserModel or handle the "Check Email" state in the UI.
      return UserModel(
        id: user.id,
        name: name,
        email: email,
        phoneNumber: phoneNumber,
        roles: roles,
        active_role: roles.first,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        organizationName: organizationName,
        recipientType: recipientType,
        allergies: allergies ?? [],
      );

    } on AuthException catch (e) {
      String displayMessage = e.message;
      try {
        final Map<String, dynamic> errorData = jsonDecode(e.message);
        if (errorData.containsKey('message')) {
          displayMessage = errorData['message'];
        }
      } catch (_) {
        // Not a JSON string
      }

      if (e.message.contains('User already registered') || e.code == 'user_already_exists') {
        // User exists. Try to sign in to verify ownership.
        try {
          final loginRes = await _client.auth.signInWithPassword(email: email, password: password);
          final user = loginRes.user;
          
          if (user != null) {
             try {
                // Check if public profile exists
                var existingUser = await _fetchUserProfile(user.id);
                
                // User exists. Merge roles.
                if (existingUser != null) {
                   final Set<String> currentRoles = Set.from(existingUser.roles);
                   final Set<String> newRoles = Set.from(roles);
                   
                   if (currentRoles.containsAll(newRoles)) {
                      return existingUser;
                   }

                   currentRoles.addAll(newRoles);
                   final String newActiveRole = roles.first; 
                   
                   await _client.from('users').update({
                     'roles': currentRoles.toList(),
                     'active_role': newActiveRole,
                     'updated_at': DateTime.now().toIso8601String(),
                   }).eq('id', user.id);

                    if (newRoles.contains('donor')) {
                       await _ensureRewardRecord(user.id);
                    }
                   
                   return await _fetchUserProfile(user.id);
                }
             } catch (_) {}

             return await _createPublicUserRecord(
                user.id, 
                email, 
                name, 
                roles, 
                phoneNumber, 
                organizationName, 
                recipientType,
                allergies,
             );
          }
        } catch (loginError) {
          throw Exception('Account exists. Please login with correct password to resolve issues.');
        }
      } 
      throw Exception(displayMessage);
    } catch (e) {
      throw Exception('$e');
    }
  }

  Future<UserModel> _createPublicUserRecord(
    String userId,
    String email,
    String name,
    List<String> roles,
    String? phoneNumber,
    String? organizationName,
    String? recipientType,
    List<String>? allergies,
  ) async {
      final String currentRole = roles.first; 

      final newUser = UserModel(
        id: userId,
        name: name,
        email: email,
        phoneNumber: phoneNumber,
        roles: roles,
        active_role: currentRole, 
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        organizationName: organizationName,
        recipientType: recipientType,
        allergies: allergies ?? [],
      );

      await _client.from('users').upsert(newUser.toJson());

      if (roles.contains('donor')) {
        await _ensureRewardRecord(userId);
      }

      return newUser;
  }

  Future<void> _ensureRewardRecord(String userId) async {
      try {
        final existing = await _client.from('rewards').select().eq('user_id', userId).maybeSingle();
        if (existing == null) {
           final reward = RewardModel(
            rewardId: userId, 
            userId: userId,
            points: 0,
            badges: [],
            totalDonations: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await _client.from('rewards').insert(reward.toJson());
        }
      } catch (e) {
        debugPrint("Error ensuring rewards: $e");
      }
  }

  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final AuthResponse res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final User? user = res.user;
      if (user == null) {
        throw Exception('Sign in failed: User is null');
      }

      return await _fetchUserProfile(user.id);
    } catch (e) {
      throw Exception('$e');
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw Exception('Sign out error: $e');
    }
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final User? user = _client.auth.currentUser;
      if (user == null) return null;
      return await _fetchUserProfile(user.id);
    } catch (e) {
      return null;
    }
  }

  Future<UserModel?> switchRole({
    required String userId,
    required String newRole,
  }) async {
    try {
      await _client.from('users').update({
        'active_role': newRole,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      return await _fetchUserProfile(userId);
    } catch (e) {
      throw Exception('Switch role error: $e');
    }
  }

  Future<void> resetPassword({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'wajbat://reset-password',
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Reset password error: $e');
    }
  }

  Future<UserModel?> _fetchUserProfile(String userId) async {
    try {
      final response = await _client.from('users').select().eq('id', userId).single();
      return UserModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch user profile: $e');
    }
  }

  Future<void> deleteAccount(String userId) async {
    try {
      await _client.from('users').delete().eq('id', userId);
      await signOut();
    } catch (e) {
      throw Exception('Delete account error: $e');
    }
  }
}
