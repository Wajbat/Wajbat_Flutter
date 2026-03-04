import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';
import '../services/database_service.dart';
import '../core/config/supabase_config.dart';

class MessageProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final Map<String, List<MessageModel>> _messagesByRequest = {};
  bool _isLoading = false;
  String? _errorMessage;
  RealtimeSubscribeStatus? _connectionStatus;

  Map<String, List<MessageModel>> get messagesByRequest => _messagesByRequest;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  RealtimeSubscribeStatus? get connectionStatus => _connectionStatus;

  StreamSubscription<List<MessageModel>>? _messageSubscription;

  // Stream of messages for a specific request
  Stream<List<MessageModel>> getMessagesStream(String requestId) {
    return _dbService.watchMessages(requestId).map((messages) {
      _handleRealtimeMessages(requestId, messages);
      return _messagesByRequest[requestId] ?? [];
    });
  }

  // Internal handler for incoming real-time messages
  void _handleRealtimeMessages(String requestId, List<MessageModel> newMessages) {
    // Check for duplicates and update cache
    final existingMessages = _messagesByRequest[requestId] ?? [];
    
    // Simple replacement for now as watchMessages emits the full list
    // but we add deduplication if manually needed or for merging
    final Map<String, MessageModel> messageMap = {
      for (var m in existingMessages) m.messageId: m
    };
    
    for (var m in newMessages) {
      // If message is new or updated, replace/add
      messageMap[m.messageId] = m;
    }
    
    final merged = messageMap.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
    // Capping at last 100 messages for performance
    if (merged.length > 100) {
      _messagesByRequest[requestId] = merged.sublist(merged.length - 100);
    } else {
      _messagesByRequest[requestId] = merged;
    }
    
    _isLoading = false;
    notifyListeners();
  }

  // Stream messages and update local state
  void initChat(String requestId) {
    // If we already have messages and it's not a fresh init, avoid full reload
    if (_messagesByRequest.containsKey(requestId) && _messagesByRequest[requestId]!.isNotEmpty) {
      // Optionally just refresh unread status or similar
    } else {
      _setLoading(true);
    }
    
    _messageSubscription?.cancel();
    
    _messageSubscription = _dbService.watchMessages(requestId).listen(
      (messages) {
        _handleRealtimeMessages(requestId, messages);
        _connectionStatus = RealtimeSubscribeStatus.subscribed;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = error.toString();
        _isLoading = false;
        _connectionStatus = RealtimeSubscribeStatus.channelError;
        notifyListeners();
      },
    );
  }

  void disposeChat() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _connectionStatus = null;
  }

  Future<void> sendMessage({
    required String requestId,
    required String senderId,
    required String receiverId,
    required String content,
  }) async {
    try {
      final newMessage = MessageModel(
        messageId: 'temp_${DateTime.now().millisecondsSinceEpoch}', // Unique temp ID
        requestId: requestId,
        senderId: senderId,
        receiverId: receiverId,
        content: content,
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Optimistically add to local state
      if (!_messagesByRequest.containsKey(requestId)) {
        _messagesByRequest[requestId] = [];
      }
      
      _messagesByRequest[requestId]!.add(newMessage);
      notifyListeners();

      // Send to DB
      await _dbService.sendMessage(newMessage.copyWith(messageId: '')); 
      
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markConversationAsRead(String requestId) async {
    try {
      final messages = _messagesByRequest[requestId] ?? [];
      final unreadIds = messages
          .where((m) => !m.isRead)
          .map((m) => m.messageId)
          .where((id) => !id.startsWith('temp_'))
          .toList();
          
      if (unreadIds.isEmpty) return;

      // Optimistic update
      for (var i = 0; i < messages.length; i++) {
        if (!messages[i].isRead) {
          messages[i] = messages[i].copyWith(isRead: true);
        }
      }
      notifyListeners();

      // Background sync
      for (var id in unreadIds) {
        _dbService.markAsRead(id);
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAsRead(String messageId) async {
    if (messageId.startsWith('temp_')) return;
    try {
       // Optimistic update
       _messagesByRequest.forEach((requestId, messages) {
         final index = messages.indexWhere((m) => m.messageId == messageId);
         if (index != -1) {
           messages[index] = messages[index].copyWith(isRead: true);
         }
       });
       notifyListeners();

       await _dbService.markAsRead(messageId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
