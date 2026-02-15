import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../models/food_post_model.dart';
import '../models/message_model.dart';
import '../models/request_model.dart';
import '../models/reward_model.dart';
import '../models/user_model.dart';

class DatabaseService {
  final SupabaseClient _client = SupabaseConfig.client;

  // --- USER OPERATIONS ---

  Future<UserModel?> getUserById(String userId) async {
    try {
      final response = await _client.from('users').select().eq('id', userId).single();
      return UserModel.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching user: $e');
    }
  }

  Future<void> updateUser(UserModel user) async {
    try {
      await _client.from('users').update(user.toJson()).eq('id', user.id);
    } catch (e) {
      throw Exception('Error updating user: $e');
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _client.from('users').delete().eq('id', userId);
    } catch (e) {
      throw Exception('Error deleting user: $e');
    }
  }

  // --- FOOD POST OPERATIONS ---

  Future<List<FoodPostModel>> getAllFoodPosts() async {
    try {
      final response = await _client
          .from('food_posts')
          .select()
          .order('created_at', ascending: false);
      return (response as List).map((e) => FoodPostModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Error fetching all food posts: $e');
    }
  }

  Future<List<FoodPostModel>> getFoodPostsByDonor(String donorId) async {
    try {
      final response = await _client
          .from('food_posts')
          .select()
          .eq('donor_id', donorId)
          .order('created_at', ascending: false);
      return (response as List).map((e) => FoodPostModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Error fetching donor posts: $e');
    }
  }

  Future<FoodPostModel?> getFoodPostById(String postId) async {
    try {
      final response = await _client.from('food_posts').select().eq('post_id', postId).single();
      return FoodPostModel.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching post by ID: $e');
    }
  }

  Future<String> createFoodPost(FoodPostModel post) async {
    try {
      final response = await _client.from('food_posts').insert(post.toJson()).select().single();
      return response['post_id'];
    } catch (e) {
      throw Exception('Error creating food post: $e');
    }
  }

  Future<void> updateFoodPost(FoodPostModel post) async {
    try {
      await _client.from('food_posts').update(post.toJson()).eq('post_id', post.postId);
    } catch (e) {
      throw Exception('Error updating food post: $e');
    }
  }

  Future<void> deleteFoodPost(String postId) async {
    try {
      await _client.from('food_posts').delete().eq('post_id', postId);
    } catch (e) {
      throw Exception('Error deleting food post: $e');
    }
  }

  Future<List<FoodPostModel>> searchFoodPosts(String query) async {
    try {
      final response = await _client
          .from('food_posts')
          .select()
          .ilike('item_name', '%$query%') // Case-insensitive search
          .order('created_at', ascending: false);
      return (response as List).map((e) => FoodPostModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Error searching food posts: $e');
    }
  }

  // --- REQUEST OPERATIONS ---

  Future<List<RequestModel>> getRequestsByRecipient(String recipientId) async {
    try {
      final response = await _client
          .from('requests')
          .select()
          .eq('recipient_id', recipientId)
          .order('created_at', ascending: false);
      return (response as List).map((e) => RequestModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Error fetching recipient requests: $e');
    }
  }

  Future<List<RequestModel>> getRequestsByDonor(String donorId) async {
    try {
      final response = await _client
          .from('requests')
          .select()
          .eq('donor_id', donorId)
          .order('created_at', ascending: false);
      return (response as List).map((e) => RequestModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Error fetching donor requests: $e');
    }
  }

  Future<String> createRequest(RequestModel request) async {
    try {
      final data = request.toJson()..remove('request_id');
      final response = await _client.from('requests').insert(data).select().single();
      return response['request_id'];
    } catch (e) {
      throw Exception('Error creating request: $e');
    }
  }

  Future<void> updateRequestStatus(String requestId, String status) async {
    try {
      await _client.from('requests').update({
        'request_status': status, // Updated column name
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('request_id', requestId);
    } catch (e) {
      throw Exception('Error updating request status: $e');
    }
  }

  // --- MESSAGE OPERATIONS ---

  Future<List<MessageModel>> getMessages(String requestId) async {
    try {
      final response = await _client
          .from('messages')
          .select()
          .eq('request_id', requestId)
          .order('created_at', ascending: true);
      return (response as List).map((e) => MessageModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Error fetching messages: $e');
    }
  }

  Future<void> sendMessage(MessageModel message) async {
    try {
      await _client.from('messages').insert(message.toJson());
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }

  Future<void> markAsRead(String messageId) async {
    try {
      await _client.from('messages').update({'is_read': true}).eq('message_id', messageId);
    } catch (e) {
      throw Exception('Error marking message as read: $e');
    }
  }

  Stream<List<MessageModel>> watchMessages(String requestId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['message_id'])
        .eq('request_id', requestId)
        .order('created_at', ascending: true)
        .map((data) => data.map((json) => MessageModel.fromJson(json)).toList());
  }

  // --- REWARDS OPERATIONS ---

  Future<List<RewardModel>> getLeaderboard({int limit = 20}) async {
    try {
      final response = await _client
          .from('rewards')
          .select()
          .order('points', ascending: false)
          .limit(limit);
      return (response as List).map((e) => RewardModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Error fetching leaderboard: $e');
    }
  }

  Future<RewardModel?> getUserReward(String userId) async {
    try {
      final response = await _client.from('rewards').select().eq('user_id', userId).single();
      return RewardModel.fromJson(response);
    } catch (e) {
      // Return null if not found (or throw based on preference, here we return null to allow handling)
      return null;
    }
  }

  // --- SUPPORT OPERATIONS ---

  Future<void> createSupportTicket(String userId, String description) async {
    try {
      await _client.from('support_tickets').insert({
        'user_id': userId,
        'description': description,
        'status': 'open',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Error creating support ticket: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserTickets(String userId) async {
    try {
      final response = await _client
          .from('support_tickets')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error fetching user tickets: $e');
    }
  }
}
