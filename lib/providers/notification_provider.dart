import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';

class NotificationProvider with ChangeNotifier {
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  RealtimeChannel? _messageChannel;
  RealtimeChannel? _requestChannel;

  NotificationProvider() {
    _initLocalNotifications();
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    
    await _localNotifications.initialize(initSettings);
  }

  void initializeRealtime(String userId) {
    _stopListening();

    // Subscribe to messages
    _messageChannel = SupabaseConfig.client
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) {
            _showNotification('New Message', 'You have a new message');
            _incrementUnread();
          },
        )
        .subscribe();

    // Subscribe to food requests
    _requestChannel = SupabaseConfig.client
        .channel('public:food_requests')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'food_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'donor_id',
            value: userId,
          ),
          callback: (payload) {
            _showNotification('New Request', 'Someone requested your food post.');
            _incrementUnread();
          },
        )
        .subscribe();
  }

  void _incrementUnread() {
    _unreadCount++;
    notifyListeners();
  }

  void clearUnread() {
    _unreadCount = 0;
    notifyListeners();
  }

  Future<void> _showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'wajbat_notifications',
      'Wajbat Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const platformDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);
    
    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      platformDetails,
    );
  }

  void _stopListening() {
    _messageChannel?.unsubscribe();
    _requestChannel?.unsubscribe();
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }
}
