import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/message_model.dart';
import '../../models/request_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/localization/app_localizations.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _isLoading = true;

  late RequestModel _request;
  late UserModel _otherUser;
  late UserModel _currentUser;

  List<MessageModel> _messages = [];
  RealtimeChannel? _channel;
  bool _isInit = true;
  Timer? _refreshTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _request = args['request'] as RequestModel;
      _otherUser = args['otherUser'] as UserModel;
      _currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser!;

      _fetchInitialMessages();
      _setupRealtimeSubscription();
      
      _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _fetchInitialMessages(isAutoRefresh: true);
      });

      _isInit = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _channel?.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialMessages({bool isAutoRefresh = false}) async {
    if (!isAutoRefresh) {
      setState(() => _isLoading = true);
    }
    try {
      final response = await SupabaseConfig.client
          .from('messages')
          .select()
          .eq('request_id', _request.requestId)
          .order('created_at', ascending: true);

      if (mounted) {
        int oldLength = _messages.length;
        setState(() {
          final fetchedMessages = (response as List).map((m) => MessageModel.fromJson(m)).toList();
          final tempMessages = _messages.where((m) => m.messageId.startsWith('temp_')).toList();
          
          for (var tempMsg in tempMessages) {
             if (!fetchedMessages.any((m) => m.content == tempMsg.content && m.senderId == tempMsg.senderId)) {
                fetchedMessages.add(tempMsg);
             }
          }
          
          fetchedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          _messages = fetchedMessages;
          
          if (!isAutoRefresh) {
            _isLoading = false;
          }
        });

        if (!isAutoRefresh || (oldLength < _messages.length && _isNearBottom())) {
          Future.delayed(const Duration(milliseconds: 200), _scrollToBottom);
        }

        _markRequestMessagesAsRead();
      }
    } catch (e) {
      if (mounted) {
        if (!isAutoRefresh) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppLocalizations.of(context)?.translate('failed_load_messages') ?? 'Failed to load messages: '}$e')),
          );
        }
      }
    }
  }

  void _setupRealtimeSubscription() {
    final channelName = 'messages:${_request.requestId}';
    _channel = SupabaseConfig.client.channel(channelName);

    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'request_id',
        value: _request.requestId,
      ),
      callback: (payload) {
        final newMessage = MessageModel.fromJson(payload.newRecord);
        if (mounted) {
          setState(() {
            _messages.removeWhere((m) =>
            m.messageId.startsWith('temp_') &&
                m.content == newMessage.content &&
                m.senderId == newMessage.senderId);

            if (!_messages.any((m) => m.messageId == newMessage.messageId)) {
              _messages.add(newMessage);
              _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            }
          });

          if (_isNearBottom()) {
            Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
          }
        }
      },
    ).subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.channelError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.translate('connection_lost') ?? 'Real-time connection lost. Use refresh if needed.')),
        );
      }
    });
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    return pos.maxScrollExtent - pos.pixels < 100;
  }

  void _markRequestMessagesAsRead() {
    final messageProvider = Provider.of<MessageProvider>(context, listen: false);
    for (var msg in _messages) {
      if (!msg.isRead && msg.senderId == _otherUser.id) {
        messageProvider.markAsRead(msg.messageId);
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final messageProvider = Provider.of<MessageProvider>(context, listen: false);

      await messageProvider.sendMessage(
        requestId: _request.requestId,
        senderId: _currentUser.id,
        receiverId: _otherUser.id,
        content: text,
      );

      final tempMsg = MessageModel(
        messageId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        requestId: _request.requestId,
        senderId: _currentUser.id,
        receiverId: _otherUser.id,
        content: text,
        isRead: false,
        createdAt: DateTime.now(),
      );

      setState(() {
        _messages.add(tempMsg);
      });
      _scrollToBottom();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)?.translate('failed_send_message') ?? 'Failed to send: '}$e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: _otherUser.profileImageUrl != null
                  ? CachedNetworkImageProvider(_otherUser.profileImageUrl!)
                  : null,
              child: _otherUser.profileImageUrl == null
                  ? Text(_otherUser.name[0].toUpperCase(), style: const TextStyle(fontSize: 14))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_otherUser.name, style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
              : IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchInitialMessages(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.grey[200],
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${AppLocalizations.of(context)?.translate('request_status') ?? 'Request Status: '}${AppLocalizations.of(context)?.translateDynamic(_request.requestStatus).toUpperCase() ?? _request.requestStatus.toUpperCase()}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)?.translate('start_conversation') ?? 'Start the conversation!', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg.senderId == _currentUser.id;
                final showDateHeader = index == 0 ||
                    _messages[index].createdAt.day != _messages[index - 1].createdAt.day;

                return Column(
                  children: [
                    if (showDateHeader)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(msg.createdAt),
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    _buildMessageBubble(msg, isMe),
                  ],
                );
              },
            ),
          ),

          // Input Area
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.1), offset: const Offset(0, -1), blurRadius: 4),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_photo_alternate_outlined, color: Colors.grey),
                    onPressed: () {
                      // TODO: Attach image
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)?.translate('type_a_message') ?? 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSending ? null : _sendMessage,
                    child: CircleAvatar(
                      backgroundColor: _isSending ? Colors.grey : AppColors.primary,
                      child: _isSending
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
          ),
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg.content,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('hh:mm a').format(msg.createdAt),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.black54,
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.isRead ? Icons.done_all : Icons.done,
                    size: 12,
                    color: msg.isRead ? Colors.blue[100] : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
