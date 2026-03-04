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
        data: {'name': name},
      );

      final User? user = res.user;
      if (user == null) {
        throw Exception('Sign up failed: User creation returned null');
      }

      // New User - Create Record
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

    } on AuthException catch (e) {
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
                   
                   // If new roles are already present, just log them in
                   if (currentRoles.containsAll(newRoles)) {
                      // Just return existing
                      return existingUser;
                   }

                   // Add new roles
                   currentRoles.addAll(newRoles);
                   
                   // Update DB
                   final String newActiveRole = roles.first; // Switch to the role they just signed up for
                   
                   await _client.from('users').update({
                     'roles': currentRoles.toList(),
                     'active_role': newActiveRole,
                     'updated_at': DateTime.now().toIso8601String(),
                     // Note: We are NOT automatically adding allergies here for existing users to avoid overwriting/complexity logic without user input
                     // If needed, we could merge allergies, but simpler to let them edit profile later.
                   }).eq('id', user.id);

                   // If new role includes donor, ensure rewards exist
                    if (newRoles.contains('donor')) {
                       await _ensureRewardRecord(user.id);
                    }
                   
                   return await _fetchUserProfile(user.id);
                }
             } catch (_) {
                // Profile missing (Zombie). Recover by creating it.
             }

             // Create record if missing
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
      throw Exception('Sign up error: ${e.message}');
    } catch (e) {
      throw Exception('Sign up error: $e');
    }
    return null;
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

      // Insert into 'users' table
      await _client.from('users').upsert(newUser.toJson()); // Upsert to be safe? Or insert.

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

  // Sign In
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
      throw Exception('Sign in error: $e');
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw Exception('Sign out error: $e');
    }
  }

  // Get Current User
  Future<UserModel?> getCurrentUser() async {
    try {
      final User? user = _client.auth.currentUser;
      if (user == null) return null;
      return await _fetchUserProfile(user.id);
    } catch (e) {
      return null; // Return null if session expired or fetch failed
    }
  }

  // Switch Role
  Future<UserModel?> switchRole({
    required String userId,
    required String newRole,
  }) async {
    try {
      await _client.from('users').update({
        'active_role': newRole, // Updated column name
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      return await _fetchUserProfile(userId);
    } catch (e) {
      throw Exception('Switch role error: $e');
    }
  }

  // Reset Password
  Future<void> resetPassword({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception('Reset password error: $e');
    }
  }

  // Helper to fetch user profile
  Future<UserModel?> _fetchUserProfile(String userId) async {
    try {
      final response = await _client.from('users').select().eq('id', userId).single();
      return UserModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch user profile: $e');
    }
  }
  // Delete Account
  Future<void> deleteAccount(String userId) async {
    try {
      // Delete from public 'users' table. 
      // Note: This requires RLS policies to allow users to delete their own rows.
      // If RLS is set up correctly, cascading deletes might handle related data.
      await _client.from('users').delete().eq('id', userId);
      
      // Sign out after deletion
      await signOut();
    } catch (e) {
      throw Exception('Delete account error: $e');
    }
  }
}
