import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/food_post_model.dart';
import '../services/ai_service.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';

class FoodPostProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final StorageService _storageService = StorageService();
  // ignore: unused_field
  final AIService _aiService = AIService();
  final Uuid _uuid = const Uuid();

  List<FoodPostModel> _foodPosts = [];
  List<FoodPostModel> _myPosts = [];
  FoodPostModel? _selectedPost;
  bool _isLoading = false;
  String? _errorMessage;

  List<FoodPostModel> get foodPosts => _foodPosts;
  List<FoodPostModel> get myPosts => _myPosts;
  FoodPostModel? get selectedPost => _selectedPost;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Fetch all posts
  Future<void> fetchAllFoodPosts() async {
    _setLoading(true);
    try {
      _foodPosts = await _dbService.getAllFoodPosts();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Fetch posts by donor
  Future<void> fetchMyPosts(String donorId) async {
    _setLoading(true);
    try {
      _myPosts = await _dbService.getFoodPostsByDonor(donorId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Create Post
  Future<bool> createPost({
    required String itemName,
    required String quantity,
    required DateTime expirationDate,
    required String location,
    required double? latitude,
    required double? longitude,
    required File image,
    required List<String> ingredients,
    required String donorId,
  }) async {
    _setLoading(true);
    try {
      final String? imageUrl = await _storageService.uploadFoodImage(image, donorId);

      final newPost = FoodPostModel(
        postId: _uuid.v4(), // We might need to let DB assign this or use UUID here. 
                          // DatabaseService createPost returns ID, so let's check that.
                          // Actually DatabaseService createPost takes a model. 
                          // So we generate a temp ID or let DB handle it. 
                          // The user's prompt says "Create FoodPostModel... Call _dbService.createFoodPost".
                          // I'll leave ID empty or generate one if model requires it.
                          // Model requires it. Let's use empty string and update after specific implementation if needed,
                          // or generate a UUID if we are doing client-side ID gen.
                          // To be safe and consistent with typical client-gen patterns I'll use UUID locally 
                          // OR I can trust the DB service to return the real ID. 
                          // However, the model needs an ID in constructor.
                          // I'll generate one here.
        donorId: donorId,
        itemName: itemName,
        quantity: quantity,
        expirationDate: expirationDate,
        location: location,
        latitude: latitude,
        longitude: longitude,
        imageUrl: imageUrl,
        ingredients: ingredients,
        postStatus: 'available',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(), 
      );
      
      // Note: DatabaseService.createPost returns String (postId). 
      // If we pass a generated ID, we can use that.
      // If the DB generates it, we should update the model. 
      // Assuming for now we pass the model as is.
      await _dbService.createFoodPost(newPost);
      
      // Refresh lists
      await fetchAllFoodPosts();
      await fetchMyPosts(donorId);
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

  // Update Post
  Future<bool> updatePost(FoodPostModel post, File? newImage) async {
    _setLoading(true);
    try {
      String? imageUrl = post.imageUrl;
      if (newImage != null) {
        imageUrl = await _storageService.uploadFoodImage(newImage, post.donorId);
      }

      final updatedPost = post.copyWith(imageUrl: imageUrl, updatedAt: DateTime.now());
      await _dbService.updateFoodPost(updatedPost);
      
      // Refresh lists
      await fetchAllFoodPosts();
      await fetchMyPosts(post.donorId);
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

  // Delete Post
  Future<bool> deletePost(String postId) async {
    _setLoading(true);
    try {
      await _dbService.deleteFoodPost(postId);
      _foodPosts.removeWhere((p) => p.postId == postId);
      _myPosts.removeWhere((p) => p.postId == postId);
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

  Future<FoodPostModel?> getPostById(String postId) async {
    return await _dbService.getFoodPostById(postId);
  }

  // Update Post Status
  Future<bool> updatePostStatus(String postId, String status) async {
    _setLoading(true);
    try {
      final post = await _dbService.getFoodPostById(postId);
      if (post != null) {
        final updatedPost = post.copyWith(postStatus: status, updatedAt: DateTime.now());
        await _dbService.updateFoodPost(updatedPost);
        
        // Update local lists
        final index = _foodPosts.indexWhere((p) => p.postId == postId);
        if (index != -1) _foodPosts[index] = updatedPost;
        
        final myIndex = _myPosts.indexWhere((p) => p.postId == postId);
        if (myIndex != -1) _myPosts[myIndex] = updatedPost;
        
        _errorMessage = null;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Search Posts
  Future<void> searchPosts(String query) async {
    _setLoading(true);
    try {
      _foodPosts = await _dbService.searchFoodPosts(query);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void selectPost(FoodPostModel post) {
    _selectedPost = post;
    notifyListeners();
  }
  
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
