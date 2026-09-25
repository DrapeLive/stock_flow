import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/api_client.dart';

class PushService {
  PushService._();

  static final PushService instance = PushService._();

  void Function(Map<String, dynamic> data)? onOpen;

  bool _available = false;
  Future<void>? _initialization;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  Future<void> init() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;

      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onOpenMessage);

      await _requestPermissions();
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) _onOpenMessage(initialMessage);

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      await messaging.getToken();
      _available = true;
      debugPrint('[push] Firebase messaging ready.');
    } catch (error) {
      _available = false;
      debugPrint(
        '[push] Firebase unavailable; push notifications are disabled: $error',
      );
    }
  }

  Future<void> registerForUser() async {
    await init();
    if (!_available) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[push] Registration skipped because no FCM token exists.');
        return;
      }
      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';
      await ApiClient.dio.post(
        '/api/notification/register-token/',
        data: {'token': token, 'platform': platform},
      );
    } catch (error) {
      debugPrint('[push] Token registration failed: $error');
    }
  }

  Future<void> unregisterForUser() async {
    await init();
    if (!_available) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await ApiClient.dio.post(
          '/api/notification/unregister-token/',
          data: {'token': token},
        );
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (error) {
      debugPrint('[push] Token unregistration failed: $error');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    if (kIsWeb) return;
    try {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }
}

String routeForPush(Map<String, dynamic> data) {
  final route = data['route'];
  if (route is String && route.startsWith('/')) return route;

  final orderId = _positiveInt(data['order_id'] ?? data['orderId']);
  if (orderId != null) return '/admin/order/status/$orderId';

  final itemId = _positiveInt(data['item_id'] ?? data['itemId']);
  if (itemId != null) return '/admin/items/edit/$itemId';

  return '/admin';
}

int? _positiveInt(dynamic value) {
  final parsed = value is int ? value : int.tryParse('$value');
  return parsed != null && parsed > 0 ? parsed : null;
}

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await _showLocalNotification(message);
}

Future<void> _onForegroundMessage(RemoteMessage message) async {
  await _showLocalNotification(message);
}

void _onOpenMessage(RemoteMessage message) {
  PushService.instance.onOpen?.call(message.data);
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  final notification = message.notification;
  if (notification == null) return;

  try {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await plugin.show(
      0,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'stock_flow',
          'Stock Flow',
          channelDescription: 'Order and stock updates',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  } catch (_) {}
}
