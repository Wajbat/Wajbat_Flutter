import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../services/database_service.dart';

class MessageProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final Map<String, List<MessageModel>> _messagesByRequest = {};
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, List<MessageModel>> get messagesByRequest => _messagesByRequest;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Stream messages (preferred for chat)
  Stream<List<MessageModel>> watchMessages(String requestId) {
    return _dbService.watchMessages(requestId);
  }

  Future<void> fetchMessages(String requestId) async {
    _setLoading(true);
    try {
      final messages = await _dbService.getMessages(requestId);
      _messagesByRequest[requestId] = messages;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendMessage({
    required String requestId,
    required String senderId,
    required String receiverId,
    required String content,
  }) async {
    try {
      final newMessage = MessageModel(
        messageId: '', // DB/Service generated
        requestId: requestId,
        senderId: senderId,
        receiverId: receiverId,
        content: content,
        isRead: false,
        createdAt: DateTime.now(),
      );

      await _dbService.sendMessage(newMessage);
      
      // Optimistically add
      // If we are using stream, this might be redundant or momentarily duplicated until stream updates.
      // But user requested "Update local messages".
      if (_messagesByRequest.containsKey(requestId)) {
        _messagesByRequest[requestId]!.add(newMessage);
        notifyListeners();
      }
      
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markAsRead(String messageId) async {
    try {
       await _dbService.markAsRead(messageId);
       
       // Update local state if needed
       _messagesByRequest.forEach((requestId, messages) {
         final index = messages.indexWhere((m) => m.messageId == messageId);
         if (index != -1) {
           messages[index] = messages[index].copyWith(isRead: true);
         }
       });
       notifyListeners();
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
