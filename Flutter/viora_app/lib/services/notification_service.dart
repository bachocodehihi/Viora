import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../config/app_routes.dart';
import '../l10n/language.dart';
import '../widgets/in_app_notification_banner.dart';
import 'call_service.dart';
import 'session_service.dart';
import 'social_notification_service.dart';
import 'socket_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM Background message: ${message.messageId}');
  final data = Map<String, dynamic>.from(message.data);
  final type = data['type']?.toString();
  if (type == 'incoming_call') {
    await CallService.ensureBackgroundHandlerRegistered();
    await CallService.showNativeIncomingCallFromFcm(data);
  } else if (type == 'call_cancelled' ||
      type == 'call_declined' ||
      type == 'call_ended' ||
      type == 'call_missed') {
    await CallService.dismissCallFromFcm(data);
  }
}

class NotificationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'viora_notification_channel',
    'Viora Notifications',
    description: 'Viora notifications and messages channel',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static OverlayEntry? _currentBannerEntry;
  static final Map<String, int> _recentNotificationKeys = {};

  static bool _isKeyRecent(String key) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _recentNotificationKeys.removeWhere((_, time) => now - time > 8000);
    return _recentNotificationKeys.containsKey(key);
  }

  static void _markKeyRecent(String key) {
    _recentNotificationKeys[key] = DateTime.now().millisecondsSinceEpoch;
  }

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification clicked: ${response.payload}');
          if (response.payload != null) {
            try {
              final data = jsonDecode(response.payload!);
              if (data is Map<String, dynamic>) {
                _handleNotificationTap(data);
              }
            } catch (e) {
              debugPrint('Error parsing notification response payload: $e');
            }
          }
        },
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('FCM Permission status: ${settings.authorizationStatus}');

      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        final data = message.data;
        final type = data['type']?.toString();

        if (type == 'incoming_call') {
          await CallService.handleIncomingCallSignal(Map<String, dynamic>.from(data));
          return;
        }
        if (type == 'call_cancelled' ||
            type == 'call_declined' ||
            type == 'call_ended' ||
            type == 'call_missed') {
          await CallService.handleCallTerminalSignal(
            Map<String, dynamic>.from(data),
            eventType: type!,
          );
          return;
        }
        if (type == 'message') return;

        final currentUserId = await SessionService.getUserId();
        final senderId = data['senderId']?.toString();
        if (currentUserId != null && senderId != null && currentUserId.isNotEmpty && currentUserId == senderId) {
          debugPrint('Ignoring self-notification from sender $senderId');
          return;
        }

        debugPrint('FCM Foreground message: ${message.notification?.title}');
        final notification = message.notification;

        final title = notification?.title ??
            data['senderName']?.toString() ??
            data['title']?.toString() ??
            'Viora';
        final context = navigatorKey.currentContext;
        final l10n = context != null ? Language.of(context) : null;
        final notifType = data['type']?.toString();
        final body = (notifType != null && notifType.isNotEmpty && notifType != 'general')
            ? SocialNotificationService.getNotificationActionText(data, l10n)
            : (notification?.body ??
                data['content']?.toString() ??
                data['body']?.toString() ??
                '');
        final avatar = data['avatar']?.toString() ??
            data['imageUrl']?.toString() ??
            notification?.android?.imageUrl;

        if (title.isNotEmpty || body.isNotEmpty) {
          showInAppNotification(
            title: title,
            body: body,
            avatar: avatar,
            data: data,
            onTap: () {
              _handleNotificationTap(data);
            },
          );
        }
      });

      SocketService.onNewNotification((data) async {
        final type = data['type']?.toString();
        if (type == 'message') return;

        final currentUserId = await SessionService.getUserId();
        final sender = data['sender'] as Map?;
        final senderId = sender?['_id']?.toString() ?? data['senderId']?.toString();
        if (currentUserId != null && senderId != null && currentUserId.isNotEmpty && currentUserId == senderId) {
          debugPrint('Ignoring self-notification from sender $senderId via socket');
          return;
        }

        final senderName = sender?['username']?.toString() ?? 'Viora';
        final senderAvatar = sender?['avatar']?.toString();
        final context = navigatorKey.currentContext;
        final l10n = context != null ? Language.of(context) : null;
        final bodyText = SocialNotificationService.getNotificationActionText(
          Map<String, dynamic>.from(data),
          l10n,
        );

        showInAppNotification(
          title: senderName,
          body: bodyText,
          avatar: senderAvatar,
          data: Map<String, dynamic>.from(data),
          onTap: () {
            _handleNotificationTap(Map<String, dynamic>.from(data));
          },
        );
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM opened from background: ${message.data}');
        _handleNotificationTap(message.data);
      });

      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          debugPrint('FCM opened from terminated: ${message.data}');
          _handleNotificationTap(message.data);
        }
      });

      messaging.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token refreshed: $newToken');
        syncTokenWithBackend(fcmToken: newToken);
      });

      await syncTokenWithBackend();
    } catch (e) {
      debugPrint('NotificationService.initialize error: $e');
    }
  }

  static void showInAppNotification({
    required String title,
    required String body,
    String? avatar,
    Map<String, dynamic>? data,
    VoidCallback? onTap,
  }) {

    String cleanBody = body.trim();
    if (title.isNotEmpty && cleanBody.toLowerCase().startsWith(title.toLowerCase())) {
      cleanBody = cleanBody.substring(title.length).trim();
      if (cleanBody.startsWith(':') || cleanBody.startsWith('-')) {
        cleanBody = cleanBody.substring(1).trim();
      }
    }
    if (cleanBody.isEmpty) {
      cleanBody = body.trim();
    }

    final notifId = data?['notificationId']?.toString() ??
        data?['_id']?.toString() ??
        data?['id']?.toString();
    final reqId = data?['requestId']?.toString() ??
        (data?['request'] is Map
            ? data?['request']?['_id']?.toString()
            : data?['request']?.toString());
    final normTitle = title.trim().toLowerCase();
    final normBody = cleanBody.trim().toLowerCase();
    final contentKey = '$normTitle::$normBody';

    bool isDuplicate = false;
    if (notifId != null && notifId.isNotEmpty && _isKeyRecent('notif::$notifId')) {
      isDuplicate = true;
    } else if (reqId != null && reqId.isNotEmpty && _isKeyRecent('req::$reqId')) {
      isDuplicate = true;
    } else if (_isKeyRecent('content::$contentKey')) {
      isDuplicate = true;
    }

    if (isDuplicate) {
      debugPrint('Suppressed duplicate in-app notification: $contentKey');
      return;
    }

    if (notifId != null && notifId.isNotEmpty) _markKeyRecent('notif::$notifId');
    if (reqId != null && reqId.isNotEmpty) _markKeyRecent('req::$reqId');
    _markKeyRecent('content::$contentKey');

    final overlayState = navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    try {
      _currentBannerEntry?.remove();
    } catch (_) {}
    _currentBannerEntry = null;

    late OverlayEntry entry;
    bool isRemoved = false;

    void safeRemove() {
      if (!isRemoved) {
        isRemoved = true;
        try {
          entry.remove();
        } catch (_) {}
        if (_currentBannerEntry == entry) {
          _currentBannerEntry = null;
        }
      }
    }

    entry = OverlayEntry(
      builder: (context) {
        return InAppNotificationBanner(
          title: title,
          body: cleanBody,
          avatar: avatar,
          onTap: onTap,
          onDismiss: safeRemove,
        );
      },
    );

    _currentBannerEntry = entry;
    overlayState.insert(entry);
  }

  static void _handleNotificationTap(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final type = data['type']?.toString();
    final senderId = data['senderId']?.toString();
    final senderName = data['senderName']?.toString();
    final conversationId = data['conversationId']?.toString();

    if (type == 'friend_request' || type == 'follow') {
      if (senderId != null && senderId.isNotEmpty) {
        Navigator.of(context).pushNamed(
          AppRoutes.profileAccount,
          arguments: {
            'userId': senderId,
            'name': senderName,
          },
        );
      }
    } else if (type == 'message' && conversationId != null && conversationId.isNotEmpty) {
      Navigator.of(context).pushNamed(
        AppRoutes.chatDetail,
        arguments: {
          'conversationId': conversationId,
          'name': senderName ?? 'Chat',
          'receiverId': senderId,
        },
      );
    }
  }

  static Future<void> syncTokenWithBackend({String? fcmToken}) async {
    try {
      final userId = await SessionService.getUserId();
      if (userId == null || userId.isEmpty) return;

      final token = fcmToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      debugPrint('Syncing FCM Token with backend: $token');

      final authToken = await SessionService.getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      await http
          .post(
            Uri.parse(ApiConfig.updateFcmToken),
            headers: headers,
            body: jsonEncode({
              'userId': userId,
              'fcmToken': token,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('NotificationService.syncTokenWithBackend error: $e');
    }
  }
}
