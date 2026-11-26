import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'anime_friends_updates',
    'Anime Friends updates',
    description: 'Friend requests, messages and social updates.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();

      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );

      await _localNotifications.initialize(
        settings: initializationSettings,
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.createNotificationChannel(_channel);

      FirebaseMessaging.onMessage.listen(_showForegroundNotification);

      _initialized = true;
    } catch (error) {
      debugPrint('FCM initialization failed: $error');
    }
  }

  Future<NotificationSettings?> requestPermission() async {
    if (!_initialized) return null;

    try {
      return await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      return null;
    }
  }

  Future<String?> getToken() async {
    if (!_initialized) return null;

    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (error) {
      debugPrint('FCM token retrieval failed: $error');
      return null;
    }
  }

  Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title;
    final body = notification?.body;

    if (title == null && body == null) return;

    try {
      await _localNotifications.show(
        id: message.messageId?.hashCode ?? message.hashCode,
        title: title ?? 'Anime Friends',
        body: body ?? 'You have a new update.',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    } catch (error) {
      debugPrint('Could not display foreground notification: $error');
    }
  }
}
