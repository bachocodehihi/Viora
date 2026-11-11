import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../l10n/language.dart';
import '../screens/call/call_screen.dart';
import '../screens/call/incoming_call_screen.dart';
import '../widgets/toast/app_toast.dart';
import 'notification_service.dart';
import 'session_service.dart';
import 'socket_service.dart';

class CallSoundHelper {
  static const MethodChannel _channel = MethodChannel('viora/call_sound');

  static Future<void> startRingtone() async {
    try {
      await _channel.invokeMethod('startRingtone');
    } catch (_) {}
  }

  static Future<void> stopRingtone() async {
    try {
      await _channel.invokeMethod('stopRingtone');
    } catch (_) {}
  }

  static Future<void> playRingbackPulse() async {
    try {
      await _channel.invokeMethod('playRingbackPulse');
    } catch (_) {}
  }

  static Future<void> stopRingback() async {
    try {
      await _channel.invokeMethod('stopRingback');
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
Future<void> callkitBackgroundHandler(CallEvent event) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[CallKit Background Event] ${event.eventName}');
  if (event is CallEventActionCallDecline) {
    final callId = event.callKitParams.id;
    final callDocId = event.callKitParams.extra?['callDocId']?.toString();
    await CallService.declineCall(callId: callId, callDocId: callDocId);
  } else if (event is CallEventActionCallEnded) {
    final callId = event.callKitParams.id;
    final callDocId = event.callKitParams.extra?['callDocId']?.toString();
    await CallService.endCall(callId: callId, callDocId: callDocId);
  } else if (event is CallEventActionCallTimeout) {
    await CallService.missedCall(callId: event.id);
  }
}

class _CallLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    CallService.currentLifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      CallService.consumePendingAcceptedCall();
    }
  }
}

class CallService {
  static bool _isInitialized = false;
  static bool _bgHandlerRegistered = false;
  static bool isAppReadyForNavigation = false;
  static AppLifecycleState currentLifecycleState =
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;

  static final _CallLifecycleObserver _lifecycleObserver = _CallLifecycleObserver();
  static final StreamController<String> _cancelledController =
      StreamController<String>.broadcast();
  static Stream<String> get cancelledCallStream => _cancelledController.stream;

  static final StreamController<Map<String, String>> _terminalController =
      StreamController<Map<String, String>>.broadcast();
  static Stream<Map<String, String>> get terminalCallStream => _terminalController.stream;

  static final StreamController<String?> _callLogSyncController =
      StreamController<String?>.broadcast();
  static Stream<String?> get callLogSyncStream => _callLogSyncController.stream;

  static void notifyCallLogSync([String? conversationId]) {
    if (!_callLogSyncController.isClosed) {
      _callLogSyncController.add(conversationId);
    }
  }

  static final Set<String> _handledIncomingCallIds = {};
  static final Set<String> _cancelledCallIds = {};
  static final Set<String> _openingCallIds = {};
  static String? _activeIncomingCallId;
  static String? _activeCallScreenCallId;

  static bool get hasActiveCallUi =>
      _activeIncomingCallId != null || _activeCallScreenCallId != null;

  static Future<void> ensureBackgroundHandlerRegistered() async {
    if (_bgHandlerRegistered) return;
    try {
      await FlutterCallkitIncoming.onBackgroundMessage(callkitBackgroundHandler);
      _bgHandlerRegistered = true;
    } catch (e) {
      debugPrint('[CallService] onBackgroundMessage register error: $e');
    }
  }

  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    unawaited(SocketService.init());
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    currentLifecycleState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;

    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
      if (event == null) return;
      debugPrint('[CallKit Event] ${event.eventName}');
      switch (event) {
        case CallEventActionCallAccept(:final callKitParams):
          await _acceptFromCallKitParams(callKitParams);
          break;
        case CallEventActionCallDecline(:final callKitParams):
          final callId = callKitParams.id;
          final callDocId = callKitParams.extra?['callDocId']?.toString();
          _cancelledCallIds.add(callId);
          _cancelledController.add(callId);
          _terminalController.add({'callId': callId, 'type': 'call_declined'});
          await declineCall(callId: callId, callDocId: callDocId);
          break;
        case CallEventActionCallEnded(:final callKitParams):
          final callId = callKitParams.id;
          final callDocId = callKitParams.extra?['callDocId']?.toString();
          _cancelledCallIds.add(callId);
          _cancelledController.add(callId);
          _terminalController.add({'callId': callId, 'type': 'call_ended'});
          await endCall(callId: callId, callDocId: callDocId);
          break;
        case CallEventActionCallTimeout(:final id):
          _cancelledCallIds.add(id);
          _cancelledController.add(id);
          _terminalController.add({'callId': id, 'type': 'call_missed'});
          await dismissCallFromFcm({'callId': id});
          unawaited(missedCall(callId: id));
          break;
        default:
          break;
      }
    });

    SocketService.onIncomingCall((data) async {
      await handleIncomingCallSignal(data);
    });

    SocketService.onCallCancelled((data) async {
      await handleCallTerminalSignal(data, eventType: 'call_cancelled');
    });

    SocketService.onCallMissed((data) async {
      await handleCallTerminalSignal(data, eventType: 'call_missed');
    });

    SocketService.onCallEnded((data) async {
      await handleCallTerminalSignal(data, eventType: 'call_ended');
    });

    SocketService.onCallDeclined((data) async {
      await handleCallTerminalSignal(data, eventType: 'call_declined');
    });

    await ensureBackgroundHandlerRegistered();
  }

  static void markIncomingScreenClosed(String callId) {
    if (_activeIncomingCallId == callId) {
      _activeIncomingCallId = null;
    }
  }

  static void markCallScreenOpened(String callId) {
    _activeCallScreenCallId = callId;
    _activeIncomingCallId = null;
  }

  static void markCallScreenClosed(String callId) {
    if (_activeCallScreenCallId == callId) {
      _activeCallScreenCallId = null;
    }
    _openingCallIds.remove(callId);
  }

  static Future<Map<String, String>> _buildHeaders() async {
    final token = await SessionService.getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static int agoraUidForUserId(String? userId) {
    if (userId == null) return 0;
    final hex = userId.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (hex.length < 8) return 0;
    final tail = hex.substring(hex.length - 8);
    final parsed = (int.tryParse(tail, radix: 16) ?? 0) & 0x7fffffff;
    return parsed > 0 ? parsed : 1;
  }

  static String computeGroupInitials(String? name) {
    final clean = (name ?? '').trim();
    if (clean.isEmpty) return 'GR';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return clean.length >= 2 ? clean.substring(0, 2).toUpperCase() : clean.toUpperCase();
  }

  static List<Map<String, dynamic>> parseParticipantsList(dynamic raw) {
    if (raw is! List) return const [];
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final item in raw) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final userId = (map['userId'] ?? map['id'] ?? map['_id'] ?? '').toString().trim();
        if (userId.isEmpty || seen.contains(userId)) continue;
        seen.add(userId);
        final rawUid = int.tryParse(map['agoraUid']?.toString() ?? '') ?? 0;
        final agoraUid = rawUid > 0 ? rawUid : agoraUidForUserId(userId);
        result.add({
          'userId': userId,
          'name': (map['name'] ?? map['username'] ?? 'Viora').toString(),
          'avatar': (map['avatar'] ?? '').toString(),
          'agoraUid': agoraUid,
        });
      }
    }
    return result;
  }

  static Future<bool> _isVietnameseLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('language_code');
      if (code != null && code.isNotEmpty) {
        return code == 'vi';
      }
    } catch (_) {}
    return LanguageManager.localeNotifier.value.languageCode == 'vi';
  }

  static bool _isAppForegroundAndActive() {
    final state = WidgetsBinding.instance.lifecycleState ?? currentLifecycleState;
    return state == AppLifecycleState.resumed &&
        NotificationService.navigatorKey.currentContext != null;
  }

  static Future<bool> requestCallPermissions({required bool requireVideo}) async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      return false;
    }
    if (requireVideo) {
      final camStatus = await Permission.camera.request();
      if (!camStatus.isGranted) {
        return false;
      }
    }
    return true;
  }

  static Future<void> startOutgoingCall({
    required BuildContext context,
    required bool initialVideo,
    String? receiverId,
    String? conversationId,
    bool isGroup = false,
    required String peerName,
    required String peerAvatar,
  }) async {
    final l10n = context.l10n;
    if (hasActiveCallUi) return;

    final micOk = await Permission.microphone.request();
    if (!micOk.isGranted) {
      if (context.mounted) {
        AppToast.error(context, l10n.callPermissionRequired);
      }
      return;
    }

    if (initialVideo) {
      final camOk = await Permission.camera.request();
      if (!camOk.isGranted) {
        if (context.mounted) {
          AppToast.error(context, l10n.cameraPermissionRequired);
        }
        return;
      }
    }

    try {
      final userId = await SessionService.getUserId();
      final headers = await _buildHeaders();

      final response = await http
          .post(
            Uri.parse(ApiConfig.startCall),
            headers: headers,
            body: jsonEncode({
              'userId': userId,
              if (receiverId != null && receiverId.isNotEmpty) 'receiverId': receiverId,
              if (conversationId != null && conversationId.isNotEmpty)
                'conversationId': conversationId,
              'isGroup': isGroup,
              'callType': initialVideo ? 'video' : 'audio',
            }),
          )
          .timeout(const Duration(seconds: 12));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || data['success'] != true) {
        if (context.mounted) {
          AppToast.error(
            context,
            data['message']?.toString() ?? l10n.cannotStartCall,
          );
        }
        return;
      }

      final callId = data['callId']?.toString() ?? '';
      final callDocId = data['callDocId']?.toString();
      final channelName = data['channelName']?.toString() ?? '';
      final appId = data['appId']?.toString() ?? '';
      final token = data['token']?.toString() ?? '';
      final joinedExisting = data['joinedExisting'] == true;
      final resolvedConversationId = data['conversationId']?.toString() ?? conversationId;
      final resolvedGroupName = isGroup
          ? ((data['groupName']?.toString().trim().isNotEmpty == true)
              ? data['groupName'].toString().trim()
              : peerName)
          : null;
      final resolvedGroupAvatar = isGroup
          ? ((data['groupAvatar']?.toString().trim().isNotEmpty == true)
              ? data['groupAvatar'].toString().trim()
              : (peerAvatar.trim().isNotEmpty
                  ? peerAvatar.trim()
                  : computeGroupInitials(resolvedGroupName)))
          : null;
      final participants = parseParticipantsList(data['participants']);
      final targetIds = (data['targetUserIds'] is List)
          ? (data['targetUserIds'] as List).map((e) => e.toString()).toList()
          : (receiverId != null && receiverId.isNotEmpty ? [receiverId] : <String>[]);

      if (joinedExisting && callId.isNotEmpty) {
        _cancelledCallIds.remove(callId);
        unawaited(_clearIncomingCallNotification(callId));
      }

      if (!context.mounted || callId.isEmpty || channelName.isEmpty || token.isEmpty) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            callId: callId,
            callDocId: callDocId,
            channelName: channelName,
            appId: appId,
            token: token,
            peerName: peerName,
            peerAvatar: isGroup ? (resolvedGroupAvatar ?? '') : peerAvatar,
            peerId: receiverId,
            conversationId: resolvedConversationId,
            isGroup: isGroup,
            groupName: resolvedGroupName,
            groupAvatar: resolvedGroupAvatar,
            initialParticipants: participants,
            targetUserIds: targetIds,
            isCaller: !joinedExisting,
            initialVideo: initialVideo,
            initialAnsweredAt: _parseDateTime(data['answeredAt']),
          ),
        ),
      );
    } catch (e) {
      debugPrint('[CallService] startOutgoingCall error: $e');
      if (context.mounted) {
        AppToast.error(context, l10n.cannotStartCall);
      }
    }
  }

  static Future<void> joinActiveCall({
    required BuildContext context,
    required String callId,
    String? callDocId,
    bool initialVideo = false,
    String? conversationId,
    required String peerName,
    required String peerAvatar,
  }) async {
    final l10n = context.l10n;
    if (hasActiveCallUi) return;

    final micOk = await Permission.microphone.request();
    if (!micOk.isGranted) {
      if (context.mounted) {
        AppToast.error(context, l10n.callPermissionRequired);
      }
      return;
    }

    if (initialVideo) {
      final camOk = await Permission.camera.request();
      if (!camOk.isGranted) {
        if (context.mounted) {
          AppToast.error(context, l10n.cameraPermissionRequired);
        }
        return;
      }
    }

    try {
      if (callId.isNotEmpty) {
        _cancelledCallIds.remove(callId);
      }
      final userId = await SessionService.getUserId();
      final headers = await _buildHeaders();

      final response = await http
          .post(
            Uri.parse(ApiConfig.joinCall),
            headers: headers,
            body: jsonEncode({
              if (userId != null && userId.isNotEmpty) 'userId': userId,
              if (callId.isNotEmpty) 'callId': callId,
              if (callDocId != null && callDocId.isNotEmpty) 'callDocId': callDocId,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || data['success'] != true) {
        final code = data['code']?.toString() ?? '';
        if (code == 'CALL_ALREADY_ENDED') {
          notifyCallLogSync(conversationId);
        }
        if (context.mounted) {
          AppToast.info(
            context,
            code == 'CALL_ALREADY_ENDED'
                ? l10n.callAlreadyEnded
                : (data['message']?.toString() ?? l10n.cannotJoinCall),
          );
        }
        return;
      }

      final resolvedCallId = data['callId']?.toString() ?? callId;
      final resolvedCallDocId = data['callDocId']?.toString() ?? callDocId;
      final channelName = data['channelName']?.toString() ?? '';
      final appId = data['appId']?.toString() ?? '';
      final token = data['token']?.toString() ?? '';
      final resolvedConversationId = data['conversationId']?.toString() ?? conversationId;
      final resolvedGroupName = (data['groupName']?.toString().trim().isNotEmpty == true)
          ? data['groupName'].toString().trim()
          : peerName;
      final resolvedGroupAvatar = (data['groupAvatar']?.toString().trim().isNotEmpty == true)
          ? data['groupAvatar'].toString().trim()
          : (peerAvatar.trim().isNotEmpty
              ? peerAvatar.trim()
              : computeGroupInitials(resolvedGroupName));
      final participants = parseParticipantsList(data['participants']);
      final targetIds = (data['targetUserIds'] is List)
          ? (data['targetUserIds'] as List).map((e) => e.toString()).toList()
          : <String>[];

      if (resolvedCallId.isNotEmpty) {
        _cancelledCallIds.remove(resolvedCallId);
        unawaited(_clearIncomingCallNotification(resolvedCallId));
      }

      if (!context.mounted || resolvedCallId.isEmpty || channelName.isEmpty || token.isEmpty) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            callId: resolvedCallId,
            callDocId: resolvedCallDocId,
            channelName: channelName,
            appId: appId,
            token: token,
            peerName: resolvedGroupName,
            peerAvatar: resolvedGroupAvatar,
            conversationId: resolvedConversationId,
            isGroup: true,
            groupName: resolvedGroupName,
            groupAvatar: resolvedGroupAvatar,
            initialParticipants: participants,
            targetUserIds: targetIds,
            isCaller: false,
            initialVideo: initialVideo,
            initialAnsweredAt: _parseDateTime(data['answeredAt']),
          ),
        ),
      );
    } catch (e) {
      debugPrint('[CallService] joinActiveCall error: $e');
      if (context.mounted) {
        AppToast.error(context, l10n.cannotJoinCall);
      }
    }
  }

  static Future<void> handleIncomingCallSignal(Map<String, dynamic> data) async {
    final callId = data['callId']?.toString() ?? '';
    if (callId.isEmpty) return;

    final currentUserId = await SessionService.getUserId();
    final callerId = data['callerId']?.toString() ?? '';
    if (currentUserId != null && callerId.isNotEmpty && currentUserId == callerId) {
      return;
    }

    if (_cancelledCallIds.contains(callId)) return;
    if (_handledIncomingCallIds.contains(callId)) return;
    if (hasActiveCallUi) {
      await declineCall(callId: callId, callDocId: data['callDocId']?.toString());
      return;
    }

    _handledIncomingCallIds.add(callId);
    if (_handledIncomingCallIds.length > 50) {
      _handledIncomingCallIds.clear();
      _handledIncomingCallIds.add(callId);
    }

    if (_isAppForegroundAndActive()) {
      final navState = NotificationService.navigatorKey.currentState;
      if (navState == null) {
        await showNativeIncomingCallFromFcm(data);
        return;
      }
      _activeIncomingCallId = callId;
      final isGroup = data['isGroup'] == true || data['isGroup']?.toString() == 'true';
      final rawGroupName = data['groupName']?.toString().trim() ?? '';
      final rawGroupAvatar = data['groupAvatar']?.toString().trim() ?? '';
      final resolvedGroupAvatar = isGroup
          ? (rawGroupAvatar.isNotEmpty
              ? rawGroupAvatar
              : computeGroupInitials(rawGroupName))
          : null;
      final participants = parseParticipantsList(data['participants']);
      navState.push(
        MaterialPageRoute(
          builder: (_) => IncomingCallScreen(
            callId: callId,
            callDocId: data['callDocId']?.toString(),
            channelName: data['channelName']?.toString() ?? '',
            callerId: callerId,
            callerName: data['callerName']?.toString() ?? 'Viora',
            callerAvatar: data['callerAvatar']?.toString() ?? '',
            callType: data['callType']?.toString() ?? 'audio',
            conversationId: data['conversationId']?.toString(),
            isGroup: isGroup,
            groupName: rawGroupName.isNotEmpty ? rawGroupName : null,
            groupAvatar: resolvedGroupAvatar,
            initialParticipants: participants,
          ),
        ),
      );
    } else {
      await showNativeIncomingCallFromFcm(data);
    }
  }

  static Future<void> handleCallCancelledSignal(Map<String, dynamic> data) async {
    await handleCallTerminalSignal(data, eventType: 'call_cancelled');
  }

  static Future<void> handleCallTerminalSignal(
    Map<String, dynamic> data, {
    String eventType = 'call_cancelled',
  }) async {
    final callId = data['callId']?.toString() ?? '';
    if (callId.isEmpty) return;
    _cancelledCallIds.add(callId);
    _cancelledController.add(callId);
    _terminalController.add({'callId': callId, 'type': eventType});
    await dismissCallFromFcm(data);
  }

  static Future<Map<String, dynamic>?> fetchCallStatus(
    String callId, {
    Duration timeout = const Duration(seconds: 4),
    bool ping = false,
  }) async {
    if (callId.isEmpty) return null;
    try {
      final headers = await _buildHeaders();
      final base = ApiConfig.getCallDetail(callId);
      final url = ping ? '$base?ping=1' : base;
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(timeout);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      if (data is Map && data['success'] == true && data['call'] is Map) {
        return Map<String, dynamic>.from(data['call'] as Map);
      }
    } catch (e) {
      debugPrint('[CallService] fetchCallStatus error: $e');
    }
    return null;
  }

  static Future<void> _clearIncomingCallNotification(String callId) async {
    if (callId.isEmpty) return;
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (_) {}
    try {
      await FlutterCallkitIncoming.hideCallkitIncoming(CallKitParams(id: callId));
    } catch (_) {}
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim();
    if (str.isEmpty) return null;
    return DateTime.tryParse(str);
  }

  static Future<void> showNativeIncomingCallFromFcm(Map<String, dynamic> data) async {
    final callId = data['callId']?.toString() ?? '';
    if (callId.isEmpty || _cancelledCallIds.contains(callId)) return;

    final createdAtStr = data['createdAt']?.toString();
    if (createdAtStr != null && createdAtStr.isNotEmpty) {
      final createdAtMs = int.tryParse(createdAtStr);
      if (createdAtMs != null) {
        final ageMs = DateTime.now().millisecondsSinceEpoch - createdAtMs;
        if (ageMs > 45000) {
          debugPrint('[CallService] Ignoring stale incoming_call FCM (${ageMs}ms old)');
          return;
        }
        if (ageMs > 2500) {
          final remoteCall = await fetchCallStatus(
            callId,
            timeout: const Duration(milliseconds: 1800),
          );
          final remoteStatus = remoteCall?['status']?.toString();
          if (remoteStatus != null && remoteStatus != 'ringing') {
            debugPrint('[CallService] Skipping incoming_call FCM (status=$remoteStatus)');
            _cancelledCallIds.add(callId);
            return;
          }
          if (_cancelledCallIds.contains(callId)) return;
        }
      }
    }

    final currentUserId = await SessionService.getUserId();
    final callerId = data['callerId']?.toString() ?? '';
    if (currentUserId != null && callerId.isNotEmpty && currentUserId == callerId) {
      return;
    }

    final isVi = await _isVietnameseLocale();
    final callType = data['callType']?.toString() ?? 'audio';
    final isVideo = callType == 'video';
    final isGroup = data['isGroup'] == true || data['isGroup']?.toString() == 'true';
    final callerName = data['callerName']?.toString() ?? 'Viora';
    final groupName = data['groupName']?.toString() ?? '';
    final callerAvatar = data['callerAvatar']?.toString() ?? '';
    final groupAvatar = data['groupAvatar']?.toString() ?? '';

    final displayName = isGroup && groupName.isNotEmpty
        ? '$callerName ($groupName)'
        : callerName;
    final rawNativeAvatar = isGroup ? groupAvatar : callerAvatar;
    final nativeAvatarUrl = (rawNativeAvatar.startsWith('http://') ||
            rawNativeAvatar.startsWith('https://'))
        ? rawNativeAvatar
        : null;

    try {
      await FlutterCallkitIncoming.showCallkitIncoming(
        CallKitParams(
          id: callId,
          nameCaller: displayName,
          appName: 'Viora',
          avatar: nativeAvatarUrl,
          handle: isVideo
              ? (isVi ? 'Cuộc gọi video đến' : 'Incoming video call')
              : (isVi ? 'Cuộc gọi thoại đến' : 'Incoming voice call'),
          type: isVideo ? 1 : 0,
          duration: 35000,
          missedCallNotification: NotificationParams(
            showNotification: true,
            isShowCallback: false,
            subtitle: isVi ? 'Cuộc gọi nhỡ' : 'Missed call',
          ),
          callingNotification: NotificationParams(
            showNotification: true,
            isShowCallback: false,
            subtitle: isVi ? 'Đang kết nối...' : 'Connecting...',
          ),
          extra: <String, dynamic>{
            'callId': callId,
            'callDocId': data['callDocId']?.toString() ?? '',
            'channelName': data['channelName']?.toString() ?? '',
            'callType': callType,
            'callerId': callerId,
            'callerName': callerName,
            'callerAvatar': callerAvatar,
            'receiverId': data['receiverId']?.toString() ?? '',
            'conversationId': data['conversationId']?.toString() ?? '',
            'isGroup': isGroup,
            'groupName': groupName,
            'groupAvatar': groupAvatar,
          },
          android: AndroidParams(
            isCustomNotification: false,
            isCustomSmallExNotification: false,
            isShowLogo: false,
            isShowCallID: true,
            ringtonePath: 'system_ringtone_default',
            backgroundColor: '#0A1120',
            actionColor: '#22C55E',
            textColor: '#FFFFFF',
            incomingCallNotificationChannelName: isVi ? 'Cuộc gọi đến' : 'Incoming calls',
            missedCallNotificationChannelName: isVi ? 'Cuộc gọi nhỡ' : 'Missed calls',
            isShowFullLockedScreen: true,
            isImportant: true,
            isFullScreen: false,
            textAccept: isVi ? 'Trả lời' : 'Accept',
            textDecline: isVi ? 'Từ chối' : 'Decline',
          ),
          ios: const IOSParams(
            iconName: 'CallKitLogo',
            handleType: 'generic',
            supportsVideo: true,
            maximumCallGroups: 1,
            maximumCallsPerCallGroup: 1,
            audioSessionMode: 'videoChat',
            audioSessionActive: true,
            supportsDTMF: false,
            supportsHolding: false,
            supportsGrouping: false,
            supportsUngrouping: false,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[CallService] showCallkitIncoming error: $e');
    }
  }

  static Future<void> dismissCallFromFcm(Map<String, dynamic> data) async {
    final callId = data['callId']?.toString() ?? '';
    if (callId.isEmpty) return;
    _cancelledCallIds.add(callId);
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (_) {}
    try {
      await FlutterCallkitIncoming.hideCallkitIncoming(CallKitParams(id: callId));
    } catch (_) {}
  }

  static Future<bool> hasPendingAcceptedCall() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      return calls.any((c) => c.isAccepted && c.id.isNotEmpty);
    } catch (_) {
      return false;
    }
  }

  static Future<void> consumePendingAcceptedCall() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      final accepted = calls.where((c) => c.isAccepted && c.id.isNotEmpty).toList();
      if (accepted.isEmpty) return;
      await _acceptFromCallKitParams(accepted.last);
    } catch (e) {
      debugPrint('[CallService] consumePendingAcceptedCall error: $e');
    }
  }

  static Future<void> _acceptFromCallKitParams(CallKitParams params) async {
    final callId = params.id;
    if (callId.isEmpty) return;
    if (!isAppReadyForNavigation) {
      return;
    }
    if (_activeCallScreenCallId == callId || _openingCallIds.contains(callId)) {
      return;
    }

    final ctx = NotificationService.navigatorKey.currentContext;
    final nav = NotificationService.navigatorKey.currentState;
    if (ctx == null || nav == null) {
      return;
    }

    _openingCallIds.add(callId);
    final extra = params.extra ?? {};
    final callDocId = extra['callDocId']?.toString();
    final callType = extra['callType']?.toString() ??
        (params.type == 1 ? 'video' : 'audio');
    final isVideo = callType == 'video';

    final okPerm = await requestCallPermissions(requireVideo: isVideo);
    if (!okPerm) {
      _openingCallIds.remove(callId);
      await declineCall(callId: callId, callDocId: callDocId);
      try {
        await FlutterCallkitIncoming.endCall(callId);
      } catch (_) {}
      final currentCtx = NotificationService.navigatorKey.currentContext;
      if (currentCtx != null && currentCtx.mounted) {
        final l10n = currentCtx.l10n;
        AppToast.error(
          currentCtx,
          isVideo ? l10n.cameraPermissionRequired : l10n.callPermissionRequired,
        );
      }
      return;
    }

    final acceptRes = await _postAcceptCall(callId: callId, callDocId: callDocId);
    if (acceptRes == null || acceptRes['success'] != true) {
      _openingCallIds.remove(callId);
      try {
        await FlutterCallkitIncoming.endCall(callId);
      } catch (_) {}
      final currentCtx = NotificationService.navigatorKey.currentContext;
      if (currentCtx != null && currentCtx.mounted) {
        AppToast.info(currentCtx, currentCtx.l10n.callEndedStatus);
      }
      return;
    }

    final callerId = extra['callerId']?.toString() ?? '';
    final callerName = extra['callerName']?.toString() ?? params.nameCaller ?? 'Viora';
    final callerAvatar = extra['callerAvatar']?.toString() ?? '';
    final isGroup = extra['isGroup'] == true ||
        extra['isGroup']?.toString() == 'true' ||
        acceptRes['isGroup'] == true;
    final rawGroupName = (acceptRes['groupName']?.toString().trim().isNotEmpty == true)
        ? acceptRes['groupName'].toString().trim()
        : (extra['groupName']?.toString().trim() ?? '');
    final rawGroupAvatar = (acceptRes['groupAvatar']?.toString().trim().isNotEmpty == true)
        ? acceptRes['groupAvatar'].toString().trim()
        : (extra['groupAvatar']?.toString().trim() ?? '');
    final resolvedGroupAvatar = isGroup
        ? (rawGroupAvatar.isNotEmpty ? rawGroupAvatar : computeGroupInitials(rawGroupName))
        : null;
    final participants = parseParticipantsList(acceptRes['participants']);
    final resolvedTargets = (acceptRes['targetUserIds'] is List &&
            (acceptRes['targetUserIds'] as List).isNotEmpty)
        ? (acceptRes['targetUserIds'] as List).map((e) => e.toString()).toList()
        : (callerId.isNotEmpty ? [callerId] : const <String>[]);
    final conversationId = extra['conversationId']?.toString() ??
        acceptRes['conversationId']?.toString();

    final finalNav = NotificationService.navigatorKey.currentState;
    if (finalNav == null) {
      _openingCallIds.remove(callId);
      return;
    }

    try {
      await FlutterCallkitIncoming.setCallConnected(callId);
    } catch (_) {}

    finalNav.push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: callId,
          callDocId: acceptRes['callDocId']?.toString() ?? callDocId,
          channelName: acceptRes['channelName']?.toString() ??
              extra['channelName']?.toString() ??
              '',
          appId: acceptRes['appId']?.toString() ?? '',
          token: acceptRes['token']?.toString() ?? '',
          peerName: callerName,
          peerAvatar: isGroup ? (resolvedGroupAvatar ?? '') : callerAvatar,
          peerId: callerId,
          conversationId: conversationId,
          isGroup: isGroup,
          groupName: rawGroupName.isNotEmpty ? rawGroupName : null,
          groupAvatar: resolvedGroupAvatar,
          initialParticipants: participants,
          targetUserIds: resolvedTargets,
          isCaller: false,
          initialVideo: isVideo,
          initialAnsweredAt: _parseDateTime(acceptRes['answeredAt']),
        ),
      ),
    );
  }

  static Future<void> acceptFromIncomingScreen({
    required BuildContext context,
    required String callId,
    String? callDocId,
    required String channelName,
    required String callerId,
    required String callerName,
    required String callerAvatar,
    required String callType,
    String? conversationId,
    bool isGroup = false,
    String? groupName,
    String? groupAvatar,
    List<Map<String, dynamic>> initialParticipants = const [],
  }) async {
    final l10n = context.l10n;
    final isVideo = callType == 'video';

    final okPerm = await requestCallPermissions(requireVideo: isVideo);
    if (!okPerm) {
      if (context.mounted) {
        AppToast.error(
          context,
          isVideo ? l10n.cameraPermissionRequired : l10n.callPermissionRequired,
        );
      }
      return;
    }

    final res = await _postAcceptCall(callId: callId, callDocId: callDocId);
    if (res == null || res['success'] != true) {
      if (context.mounted) {
        AppToast.info(context, l10n.callEndedStatus);
        markIncomingScreenClosed(callId);
        Navigator.of(context).pop();
      }
      return;
    }

    if (!context.mounted) return;
    final resolvedGroupName = (res['groupName']?.toString().trim().isNotEmpty == true)
        ? res['groupName'].toString().trim()
        : groupName;
    final rawGroupAvatar = (res['groupAvatar']?.toString().trim().isNotEmpty == true)
        ? res['groupAvatar'].toString().trim()
        : (groupAvatar?.trim() ?? '');
    final resolvedGroupAvatar = isGroup
        ? (rawGroupAvatar.isNotEmpty ? rawGroupAvatar : computeGroupInitials(resolvedGroupName))
        : null;
    final parsedParticipants = parseParticipantsList(res['participants']);
    final effectiveParticipants = parsedParticipants.isNotEmpty
        ? parsedParticipants
        : initialParticipants;
    final resolvedTargets = (res['targetUserIds'] is List &&
            (res['targetUserIds'] as List).isNotEmpty)
        ? (res['targetUserIds'] as List).map((e) => e.toString()).toList()
        : (callerId.isNotEmpty ? [callerId] : const <String>[]);

    markIncomingScreenClosed(callId);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: callId,
          callDocId: res['callDocId']?.toString() ?? callDocId,
          channelName: res['channelName']?.toString() ?? channelName,
          appId: res['appId']?.toString() ?? '',
          token: res['token']?.toString() ?? '',
          peerName: callerName,
          peerAvatar: isGroup ? (resolvedGroupAvatar ?? '') : callerAvatar,
          peerId: callerId,
          conversationId: conversationId,
          isGroup: isGroup,
          groupName: resolvedGroupName,
          groupAvatar: resolvedGroupAvatar,
          initialParticipants: effectiveParticipants,
          targetUserIds: resolvedTargets,
          isCaller: false,
          initialVideo: isVideo,
          initialAnsweredAt: _parseDateTime(res['answeredAt']),
        ),
      ),
    );
  }

  static Future<Map<String, dynamic>?> _postAcceptCall({
    required String callId,
    String? callDocId,
  }) async {
    SocketService.emitCallAccept(callId: callId, callDocId: callDocId);
    try {
      final userId = await SessionService.getUserId();
      final headers = await _buildHeaders();
      final response = await http
          .post(
            Uri.parse(ApiConfig.acceptCall),
            headers: headers,
            body: jsonEncode({
              'userId': userId,
              'callId': callId,
              if (callDocId != null && callDocId.isNotEmpty) 'callDocId': callDocId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint('[CallService] _postAcceptCall error: $e');
      return null;
    }
  }

  static Future<void> declineCall({required String callId, String? callDocId}) async {
    _cancelledCallIds.add(callId);
    SocketService.emitCallDecline(callId: callId, callDocId: callDocId);
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final userId = await SessionService.getUserId();
        final headers = await _buildHeaders();
        final res = await http
            .post(
              Uri.parse(ApiConfig.declineCall),
              headers: headers,
              body: jsonEncode({
                if (userId != null && userId.isNotEmpty) 'userId': userId,
                'callId': callId,
                if (callDocId != null && callDocId.isNotEmpty) 'callDocId': callDocId,
              }),
            )
            .timeout(const Duration(seconds: 8));
        if (res.statusCode < 500) break;
      } catch (e) {
        debugPrint('[CallService] declineCall attempt ${attempt + 1} error: $e');
      }
      if (attempt == 0) {
        await Future.delayed(const Duration(milliseconds: 350));
      }
    }
    notifyCallLogSync();
  }

  static Future<void> endCall({
    required String callId,
    String? callDocId,
    bool endForAll = false,
  }) async {
    _cancelledCallIds.add(callId);
    SocketService.emitCallEnd(
      callId: callId,
      callDocId: callDocId,
      endForAll: endForAll,
    );
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final userId = await SessionService.getUserId();
        final headers = await _buildHeaders();
        final res = await http
            .post(
              Uri.parse(ApiConfig.endCall),
              headers: headers,
              body: jsonEncode({
                if (userId != null && userId.isNotEmpty) 'userId': userId,
                'callId': callId,
                if (callDocId != null && callDocId.isNotEmpty) 'callDocId': callDocId,
                'endForAll': endForAll,
              }),
            )
            .timeout(const Duration(seconds: 8));
        if (res.statusCode < 500) break;
      } catch (e) {
        debugPrint('[CallService] endCall attempt ${attempt + 1} error: $e');
      }
      if (attempt == 0) {
        await Future.delayed(const Duration(milliseconds: 350));
      }
    }
    notifyCallLogSync();
  }

  static Future<void> missedCall({required String callId, String? callDocId}) async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _buildHeaders();
      await http
          .post(
            Uri.parse(ApiConfig.missedCall),
            headers: headers,
            body: jsonEncode({
              if (userId != null && userId.isNotEmpty) 'userId': userId,
              'callId': callId,
              if (callDocId != null && callDocId.isNotEmpty) 'callDocId': callDocId,
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[CallService] missedCall error: $e');
    }
    notifyCallLogSync();
  }
}
