import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/api_client.dart';

/// Best-effort Firebase Cloud Messaging wiring.
///
/// Everything degrades gracefully: until `google-services.json` is dropped
/// into `android/app` (and the firebase options are available) no-ops are used
/// so local dev builds keep running. See `android/app/build.gradle.kts`.
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  /// Invoked with the notification payload when the user taps a push (cold
  /// start, background, or foreground). `main.dart` wires this to the router.
  void Function(Map<String, dynamic> data)? onOpen;

  bool _initialized = false;
  bool _available = false;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;

      await _requestPermissions();
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );

      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      // Taps in background/quiescent states; cold-start taps are handled via
      // getInitialMessage below.
      FirebaseMessaging.onMessageOpenedApp.listen(_onOpenMessage);
      final initial = await messaging.getInitialMessage();
      if (initial != null) _onOpenMessage(initial);

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Pull tokens eagerly so a queued push can reach this install once the
      // backend FCM endpoint is enabled.
      await messaging.getToken();
      _available = true;
      debugPrint('[push] Firebase messaging ready.');
    } catch (e) {
      _available = false;
      debugPrint('[push] Firebase not configured ($e); push disabled.');
    }
  }

  /// Called when a user logs in / a session is restored. No-op until Firebase
  /// is available; a firebase unavailability here must never break auth.
  Future<void> registerForUser() async {
    if (!_available) return;
    String? token;
    try {
      token = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('[push] registerForUser getToken failed: $e');
      return;
    }
    if (token == null || token.isEmpty) {
      debugPrint('[push] registerForUser: no token yet');
      return;
    }
    debugPrint('[push] registered FCM token: $token');
    try {
      await ApiClient.dio.post(
        '/api/notification/register-token/',
        data: {'token': token, 'platform': 'android'},
      );
    } catch (e) {
      debugPrint('[push] register-token failed: $e');
    }
  }

  /// Called on logout. Best-effort; failures are swallowed.
  Future<void> unregisterForUser() async {
    if (!_available) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        try {
          await ApiClient.dio.post(
            '/api/notification/unregister-token/',
            data: {'token': token},
          );
        } catch (e) {
          debugPrint('[push] unregister-token failed: $e');
        }
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('[push] unregisterForUser failed: $e');
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
    if (!kIsWeb) {
      try {
        await _local
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } catch (_) {}
    }
  }
}

/// Maps a push payload to a deep-link route. Accepts either an explicit
/// `route` field or structured `screen`/`order_id`/`item_id` fields. Falls
/// back to the dashboard, which `main.dart` treats as a root reset.
String routeForPush(Map<String, dynamic> data) {
  final route = data['route'];
  if (route is String && route.startsWith('/')) return route;

  final screen = data['screen'] ?? data['type'] ?? data['target'];
  final orderId = int.tryParse('${data['order_id'] ?? data['orderId'] ?? ''}');
  final itemId = int.tryParse('${data['item_id'] ?? data['itemId'] ?? ''}');

  if (screen == 'order' && orderId != null) {
    return '/admin/order/status/$orderId';
  }
  if (screen == 'item' && itemId != null) {
    return '/admin/items/edit/$itemId';
  }
  return '/admin';
}

/// Runs in a background isolate; cannot capture [PushService] instance state.
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
  } catch (_) {
    // Local presentation is best-effort; never crash on notification issues.
  }
}