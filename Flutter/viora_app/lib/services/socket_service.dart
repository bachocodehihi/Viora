import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../config/api_config.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../widgets/dialog/device_conflict_dialog.dart';
import 'device_service.dart';
import 'notification_service.dart';
import 'session_service.dart';
import '../l10n/language.dart';

class SocketService {
  static socket_io.Socket? _socket;
  static bool _isConnected = false;
  static String? _currentUserId;
  static Future<void>? _initFuture;

  static bool get isConnected => _isConnected && _socket != null;

  static Future<void> init() {
    final inFlight = _initFuture;
    if (inFlight != null) return inFlight;
    final future = _initImpl().whenComplete(() {
      _initFuture = null;
    });
    _initFuture = future;
    return future;
  }

  static Future<void> _initImpl() async {
    final userId = await SessionService.getUserId();

    if (_socket != null) {
      if (_currentUserId == userId && userId != null && userId.isNotEmpty) {
        if (_socket!.connected) {
          _isConnected = true;
        }
        return;
      }
      disconnect();
    }

    _currentUserId = userId;

    try {
      final socket = socket_io.io(
        ApiConfig.socketUrl,
        socket_io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(1000)
            .setReconnectionAttempts(999)
            .build(),
      );
      _socket = socket;

      _bindAllPersistentListeners();

      socket.onConnect((_) async {
        if (!identical(_socket, socket)) return;
        debugPrint('[Socket] Connected to server');
        _isConnected = true;
        _bindAllPersistentListeners();
        _rebindChatListeners();
        for (final convId in _activeConversationIds) {
          socket.emit('join_conversation', convId);
        }
        if (_currentConversationId != null &&
            _currentConversationId!.isNotEmpty &&
            !_activeConversationIds.contains(_currentConversationId)) {
          socket.emit('join_conversation', _currentConversationId);
        }
        final activeUserId = _currentUserId ?? await SessionService.getUserId();
        if (activeUserId != null && activeUserId.isNotEmpty && identical(_socket, socket)) {
          _currentUserId = activeUserId;
          final deviceId = await DeviceService.getDeviceId();
          final deviceName = await DeviceService.getDeviceName();
          if (identical(_socket, socket)) {
            socket.emit('join_user', {
              'userId': activeUserId,
              'deviceId': deviceId,
              'deviceName': deviceName,
            });
          }
        }
      });

      socket.off('account_conflict');
      socket.on('account_conflict', (data) async {
        if (!identical(_socket, socket)) return;
        debugPrint('[Socket] Received account_conflict event: $data');
        if (data is! Map) return;

        final incomingDeviceId = data['deviceId']?.toString();
        final myDeviceId = await DeviceService.getDeviceId();

        if (incomingDeviceId != null && incomingDeviceId.isNotEmpty && incomingDeviceId == myDeviceId) {
          return;
        }

        final deviceName = data['deviceName']?.toString() ?? 'Other device';
        _handleAccountConflict(deviceName);
      });

      socket.off('account_deleted');
      socket.on('account_deleted', (data) async {
        if (!identical(_socket, socket)) return;
        debugPrint('[Socket] Received account_deleted event: $data');
        _handleAccountDeletedRealtime();
      });

      socket.onDisconnect((_) {
        if (!identical(_socket, socket)) return;
        debugPrint('[Socket] Disconnected from server');
        _isConnected = false;
      });

      socket.onConnectError((err) {
        if (!identical(_socket, socket)) return;
        debugPrint('[Socket] Connect error: $err');
        _isConnected = false;
      });

      socket.onError((err) {
        if (!identical(_socket, socket)) return;
        debugPrint('[Socket] Error: $err');
      });
    } catch (e) {
      debugPrint('[Socket] Exception initializing: $e');
    }
  }

  static bool _isHandlingConflict = false;

  static void _handleAccountConflict(String deviceName) async {
    if (_isHandlingConflict) return;
    _isHandlingConflict = true;

    disconnect();

    final context = NotificationService.navigatorKey.currentContext;
    if (context != null && context.mounted) {
      await DeviceConflictDialog.show(
        context: context,
        deviceName: deviceName,
        onConfirm: () async {
          await SessionService.clearSession();
          _isHandlingConflict = false;
          NotificationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
            AppRoutes.welcome,
            (route) => false,
          );
        },
      );
    } else {
      await SessionService.clearSession();
      _isHandlingConflict = false;
      NotificationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.welcome,
        (route) => false,
      );
    }
  }

  static bool _isHandlingDeleted = false;

  static void _handleAccountDeletedRealtime() async {
    if (_isHandlingDeleted) return;
    _isHandlingDeleted = true;

    disconnect();

    final context = NotificationService.navigatorKey.currentContext;
    if (context != null && context.mounted) {
      final l10n = context.l10n;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(ctx).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 24),
              const SizedBox(width: 8),
              Text(
                l10n.accountDeletedTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            l10n.accountDeletedMessage,
            style: const TextStyle(fontSize: 13.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(l10n.agree, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    await SessionService.clearSession(removeFromSaved: true);
    _isHandlingDeleted = false;
    NotificationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.welcome,
      (route) => false,
    );
  }

  static String? _currentConversationId;
  static String? get currentConversationId => _currentConversationId;
  static final Set<String> _activeConversationIds = {};

  static void joinConversation(String conversationId) {
    if (conversationId.isEmpty) return;
    _currentConversationId = conversationId;
    _activeConversationIds.add(conversationId);
    if (_socket != null && _isConnected) {
      _socket?.emit('join_conversation', conversationId);
    }
  }

  static void joinConversations(Iterable<String> conversationIds) {
    for (final id in conversationIds) {
      if (id.isNotEmpty) {
        _activeConversationIds.add(id);
        if (_socket != null && _isConnected) {
          _socket?.emit('join_conversation', id);
        }
      }
    }
  }

  static void leaveConversation(String conversationId) {
    if (conversationId.isEmpty) return;
    if (_currentConversationId == conversationId) {
      _currentConversationId = null;
    }

  }

  static void _rebindChatListeners() {
    if (_socket == null) return;

    if (_newMessageListeners.isNotEmpty) {
      _socket?.off('new_message');
      _socket?.on('new_message', (data) {
        if (data is Map) {
          final payload = Map<String, dynamic>.from(data);
          for (final listener in List.from(_newMessageListeners)) {
            try {
              listener(payload);
            } catch (e) {
              debugPrint('[Socket] onNewMessage callback error: ');
            }
          }
        }
      });
    }

    if (_pollListeners.isNotEmpty) {
      _socket?.off('poll_updated');
      _socket?.on('poll_updated', (data) {
        if (data is Map) {
          final payload = Map<String, dynamic>.from(data);
          for (final listener in List.from(_pollListeners)) {
            try {
              listener(payload);
            } catch (e) {
              debugPrint('[Socket] onPollUpdated callback error: ');
            }
          }
        }
      });
    }

    if (_locationStoppedListeners.isNotEmpty) {
      _socket?.off('location_stopped');
      _socket?.on('location_stopped', (data) {
        if (data is Map) {
          final payload = Map<String, dynamic>.from(data);
          for (final listener in List.from(_locationStoppedListeners)) {
            try {
              listener(payload);
            } catch (e) {
              debugPrint('[Socket] onLocationStopped callback error: ');
            }
          }
        }
      });
    }

    if (_locationUpdatedListeners.isNotEmpty) {
      _socket?.off('location_updated');
      _socket?.on('location_updated', (data) {
        if (data is Map) {
          final payload = Map<String, dynamic>.from(data);
          for (final listener in List.from(_locationUpdatedListeners)) {
            try {
              listener(payload);
            } catch (e) {
              debugPrint('[Socket] onLocationUpdated callback error: ');
            }
          }
        }
      });
    }

    if (_pinnedListeners.isNotEmpty) {
      _socket?.off('message_pinned');
      _socket?.on('message_pinned', (data) {
        if (data is Map) {
          final payload = Map<String, dynamic>.from(data);
          for (final listener in List.from(_pinnedListeners)) {
            try {
              listener(payload);
            } catch (e) {
              debugPrint('[Socket] onMessagePinned callback error: ');
            }
          }
        }
      });
    }

    if (_conversationUpdatedListeners.isNotEmpty) {
      _socket?.off('conversation_updated');
      _socket?.on('conversation_updated', (data) {
        if (data is Map) {
          final payload = Map<String, dynamic>.from(data);
          for (final listener in List.from(_conversationUpdatedListeners)) {
            try {
              listener(payload);
            } catch (e) {
              debugPrint('[Socket] onConversationUpdated callback error: $e');
            }
          }
        }
      });
    }

    if (_unpinnedListeners.isNotEmpty) {
      _socket?.off('message_unpinned');
      _socket?.on('message_unpinned', (data) {
        if (data is Map) {
          final payload = Map<String, dynamic>.from(data);
          for (final listener in List.from(_unpinnedListeners)) {
            try {
              listener(payload);
            } catch (e) {
              debugPrint('[Socket] onMessageUnpinned callback error: ');
            }
          }
        }
      });
    }

    if (_callMessageUpdatedListeners.isNotEmpty) {
      _socket?.off('call_message_updated');
      _socket?.on('call_message_updated', (data) {
        if (data is Map) {
          final payload = Map<String, dynamic>.from(data);
          for (final listener in List.from(_callMessageUpdatedListeners)) {
            try {
              listener(payload);
            } catch (e) {
              debugPrint('[Socket] onCallMessageUpdated callback error: $e');
            }
          }
        }
      });
    }
  }

  static final Set<Function(Map<String, dynamic>)> _newMessageListeners = {};
  static final Set<Function(Map<String, dynamic>)> _callMessageUpdatedListeners = {};

  static void onCallMessageUpdated(Function(Map<String, dynamic> msg) callback) {
    _callMessageUpdatedListeners.add(callback);
    _socket?.off('call_message_updated');
    _socket?.on('call_message_updated', (data) {
      if (data is Map) {
        final payload = Map<String, dynamic>.from(data);
        for (final listener in List.from(_callMessageUpdatedListeners)) {
          try {
            listener(payload);
          } catch (e) {
            debugPrint('[Socket] onCallMessageUpdated callback error: $e');
          }
        }
      }
    });
  }

  static void offCallMessageUpdated([Function(Map<String, dynamic>)? callback]) {
    if (callback != null) {
      _callMessageUpdatedListeners.remove(callback);
      if (_callMessageUpdatedListeners.isEmpty) {
        _socket?.off('call_message_updated');
      }
    } else {
      _callMessageUpdatedListeners.clear();
      _socket?.off('call_message_updated');
    }
  }

  static void onNewMessage(Function(Map<String, dynamic> msg) callback) {
    _newMessageListeners.add(callback);
    _socket?.off('new_message');
    _socket?.on('new_message', (data) {
      if (data is Map) {
        final payload = Map<String, dynamic>.from(data);
        for (final listener in List.from(_newMessageListeners)) {
          try {
            listener(payload);
          } catch (e) {
            debugPrint('[Socket] onNewMessage callback error: ');
          }
        }
      }
    });
  }

  static void offNewMessage([Function(Map<String, dynamic>)? callback]) {
    if (callback != null) {
      _newMessageListeners.remove(callback);
      if (_newMessageListeners.isEmpty) {
        _socket?.off('new_message');
      }
    } else {
      _newMessageListeners.clear();
      _socket?.off('new_message');
    }
  }

  static final Set<Function(Map<String, dynamic>)> _conversationUpdatedListeners = {};

  static void onConversationUpdated(Function(Map<String, dynamic> data) callback) {
    _conversationUpdatedListeners.add(callback);
    _socket?.off('conversation_updated');
    _socket?.on('conversation_updated', (data) {
      if (data is Map) {
        final payload = Map<String, dynamic>.from(data);
        for (final listener in List.from(_conversationUpdatedListeners)) {
          try {
            listener(payload);
          } catch (e) {
            debugPrint('[Socket] onConversationUpdated callback error: $e');
          }
        }
      }
    });
  }

  static void offConversationUpdated([Function(Map<String, dynamic>)? callback]) {
    if (callback != null) {
      _conversationUpdatedListeners.remove(callback);
      if (_conversationUpdatedListeners.isEmpty) {
        _socket?.off('conversation_updated');
      }
    } else {
      _conversationUpdatedListeners.clear();
      _socket?.off('conversation_updated');
    }
  }

  static void onMessageRecalled(Function(Map<String, dynamic> data) callback) {
    _socket?.off('message_recalled');
    _socket?.on('message_recalled', (data) {
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    });
  }

  static final Set<Function(Map<String, dynamic>)> _pinnedListeners = {};
  static final Set<Function(Map<String, dynamic>)> _unpinnedListeners = {};

  static void onMessagePinned(Function(Map<String, dynamic> data) callback) {
    _pinnedListeners.add(callback);
    _socket?.off('message_pinned');
    _socket?.on('message_pinned', (data) {
      if (data is Map) {
        final payload = Map<String, dynamic>.from(data);
        for (final listener in List.from(_pinnedListeners)) {
          try {
            listener(payload);
          } catch (e) {
            debugPrint('[Socket] onMessagePinned callback error: $e');
          }
        }
      }
    });
  }

  static void offMessagePinned([Function(Map<String, dynamic>)? callback]) {
    if (callback != null) {
      _pinnedListeners.remove(callback);
    } else {
      _pinnedListeners.clear();
      _socket?.off('message_pinned');
    }
  }

  static void onMessageUnpinned(Function(Map<String, dynamic> data) callback) {
    _unpinnedListeners.add(callback);
    _socket?.off('message_unpinned');
    _socket?.on('message_unpinned', (data) {
      if (data is Map) {
        final payload = Map<String, dynamic>.from(data);
        for (final listener in List.from(_unpinnedListeners)) {
          try {
            listener(payload);
          } catch (e) {
            debugPrint('[Socket] onMessageUnpinned callback error: $e');
          }
        }
      }
    });
  }

  static void offMessageUnpinned([Function(Map<String, dynamic>)? callback]) {
    if (callback != null) {
      _unpinnedListeners.remove(callback);
    } else {
      _unpinnedListeners.clear();
      _socket?.off('message_unpinned');
    }
  }

  static void onMessageReaction(Function(Map<String, dynamic> data) callback) {
    _socket?.off('message_reaction_updated');
    _socket?.on('message_reaction_updated', (data) {
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    });
  }

  static void offMessageReaction() {
    _socket?.off('message_reaction_updated');
  }

  static final Set<Function(Map<String, dynamic>)> _locationStoppedListeners = {};
  static final Set<Function(Map<String, dynamic>)> _locationUpdatedListeners = {};

  static void onLocationStopped(Function(Map<String, dynamic> data) callback) {
    _locationStoppedListeners.add(callback);
    _socket?.off('location_stopped');
    _socket?.on('location_stopped', (data) {
      if (data is Map) {
        final payload = Map<String, dynamic>.from(data);
        for (final listener in List.from(_locationStoppedListeners)) {
          try {
            listener(payload);
          } catch (e) {
            debugPrint('[Socket] onLocationStopped listener error: ');
          }
        }
      }
    });
  }

  static void offLocationStopped([Function(Map<String, dynamic>)? callback]) {
    if (callback != null) {
      _locationStoppedListeners.remove(callback);
      if (_locationStoppedListeners.isEmpty) {
        _socket?.off('location_stopped');
      }
    } else {
      _locationStoppedListeners.clear();
      _socket?.off('location_stopped');
    }
  }

  static void onLocationUpdated(Function(Map<String, dynamic> data) callback) {
    _locationUpdatedListeners.add(callback);
    _socket?.off('location_updated');
    _socket?.on('location_updated', (data) {
      if (data is Map) {
        final payload = Map<String, dynamic>.from(data);
        for (final listener in List.from(_locationUpdatedListeners)) {
          try {
            listener(payload);
          } catch (e) {
            debugPrint('[Socket] onLocationUpdated listener error: ');
          }
        }
      }
    });
  }

  static void offLocationUpdated([Function(Map<String, dynamic>)? callback]) {
    if (callback != null) {
      _locationUpdatedListeners.remove(callback);
      if (_locationUpdatedListeners.isEmpty) {
        _socket?.off('location_updated');
      }
    } else {
      _locationUpdatedListeners.clear();
      _socket?.off('location_updated');
    }
  }

  static void offLocationEvents([Function(Map<String, dynamic>)? callback]) {
    if (callback != null) {
      offLocationStopped(callback);
      offLocationUpdated(callback);
    } else {
      offLocationStopped();
      offLocationUpdated();
    }
  }

  static void emitStopShareLocation({required String conversationId, String? messageId}) {
    if (conversationId.isEmpty) return;
    _socket?.emit('stop_share_location', {
      'conversationId': conversationId,
      'messageId': messageId,
      'userId': _currentUserId,
    });
  }

  static final Set<Function(Map<String, dynamic>)> _pollListeners = {};

  static void onPollUpdated(Function(Map<String, dynamic> data) callback) {
    _pollListeners.add(callback);
    _socket?.off('poll_updated');
    _socket?.on('poll_updated', (data) {
      if (data is Map) {
        final payload = Map<String, dynamic>.from(data);
        for (final listener in List.from(_pollListeners)) {
          try {
            listener(payload);
          } catch (e) {
            debugPrint('[Socket] onPollUpdated callback error: $e');
          }
        }
      }
    });
  }

  static void offPollUpdated([Function(Map<String, dynamic>)? callback]) {
    if (callback != null) {
      _pollListeners.remove(callback);
      if (_pollListeners.isEmpty) {
        _socket?.off('poll_updated');
      }
    } else {
      _pollListeners.clear();
      _socket?.off('poll_updated');
    }
  }

  static void emitReactMessage({
    required String messageId,
    required String reaction,
    String? conversationId,
  }) {
    _socket?.emit('react_message', {
      'messageId': messageId,
      'reaction': reaction,
      'conversationId': conversationId,
      'userId': _currentUserId,
    });
  }

  static void onUserTyping(Function(Map<String, dynamic> data) callback) {
    _socket?.off('user_typing');
    _socket?.on('user_typing', (data) {
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    });
  }

  static void sendTyping({required String conversationId, required bool isTyping, String? userName}) {
    if (conversationId.isEmpty) return;
    final event = isTyping ? 'typing_start' : 'typing_stop';
    _socket?.emit(event, {
      'conversationId': conversationId,
      'userId': _currentUserId,
      'userName': userName,
    });
  }

  static final Set<Function(String userId)> _userOnlineListeners = {};
  static final Set<Function(String userId)> _userOfflineListeners = {};
  static final Set<Function(Map<String, dynamic> data)> _userActiveStatusChangedListeners = {};

  static void _bindUserOnlineListener() {
    if (_userOnlineListeners.isEmpty) return;
    _socket?.off('user_online');
    _socket?.on('user_online', (data) {
      if (data is Map && data['userId'] != null) {
        final uid = data['userId'].toString();
        for (final listener in List.from(_userOnlineListeners)) {
          try {
            listener(uid);
          } catch (e) {
            debugPrint('[Socket] onUserOnline callback error: $e');
          }
        }
      }
    });
  }

  static void _bindUserOfflineListener() {
    if (_userOfflineListeners.isEmpty) return;
    _socket?.off('user_offline');
    _socket?.on('user_offline', (data) {
      if (data is Map && data['userId'] != null) {
        final uid = data['userId'].toString();
        for (final listener in List.from(_userOfflineListeners)) {
          try {
            listener(uid);
          } catch (e) {
            debugPrint('[Socket] onUserOffline callback error: $e');
          }
        }
      }
    });
  }

  static void _bindUserActiveStatusChangedListener() {
    if (_userActiveStatusChangedListeners.isEmpty) return;
    _socket?.off('user_active_status_changed');
    _socket?.on('user_active_status_changed', (data) {
      if (data is Map) {
        final payload = Map<String, dynamic>.from(data);
        for (final listener in List.from(_userActiveStatusChangedListeners)) {
          try {
            listener(payload);
          } catch (e) {
            debugPrint('[Socket] onUserActiveStatusChanged callback error: $e');
          }
        }
      }
    });
  }

  static void onUserOnline(Function(String userId) callback) {
    _userOnlineListeners.add(callback);
    _bindUserOnlineListener();
  }

  static void offUserOnline([Function(String userId)? callback]) {
    if (callback != null) {
      _userOnlineListeners.remove(callback);
      if (_userOnlineListeners.isEmpty) {
        _socket?.off('user_online');
      }
    } else {
      _userOnlineListeners.clear();
      _socket?.off('user_online');
    }
  }

  static void onUserOffline(Function(String userId) callback) {
    _userOfflineListeners.add(callback);
    _bindUserOfflineListener();
  }

  static void offUserOffline([Function(String userId)? callback]) {
    if (callback != null) {
      _userOfflineListeners.remove(callback);
      if (_userOfflineListeners.isEmpty) {
        _socket?.off('user_offline');
      }
    } else {
      _userOfflineListeners.clear();
      _socket?.off('user_offline');
    }
  }

  static void onUserActiveStatusChanged(Function(Map<String, dynamic> data) callback) {
    _userActiveStatusChangedListeners.add(callback);
    _bindUserActiveStatusChangedListener();
  }

  static void offUserActiveStatusChanged([Function(Map<String, dynamic> data)? callback]) {
    if (callback != null) {
      _userActiveStatusChangedListeners.remove(callback);
      if (_userActiveStatusChangedListeners.isEmpty) {
        _socket?.off('user_active_status_changed');
      }
    } else {
      _userActiveStatusChangedListeners.clear();
      _socket?.off('user_active_status_changed');
    }
  }

  static void onMessagesRead(Function(Map<String, dynamic> data) callback) {
    _socket?.off('messages_read');
    _socket?.on('messages_read', (data) {
      if (data is Map) {
        callback(Map<String, dynamic>.from(data));
      }
    });
  }

  static void sendMarkRead({required String conversationId, required String userId}) {
    if (conversationId.isEmpty || userId.isEmpty) return;
    _socket?.emit('mark_read', {
      'conversationId': conversationId,
      'userId': userId,
    });
  }

  static final List<Function(Map<String, dynamic>)> _friendRequestReceivedCallbacks = [];
  static final List<Function(Map<String, dynamic>)> _followRequestReceivedCallbacks = [];
  static final List<Function(Map<String, dynamic>)> _friendRequestCancelledCallbacks = [];
  static final List<Function(Map<String, dynamic>)> _friendRequestAcceptedCallbacks = [];
  static final List<Function(Map<String, dynamic>)> _friendRequestRejectedCallbacks = [];
  static final List<Function(Map<String, dynamic>)> _friendRemovedCallbacks = [];
  static final List<Function(Map<String, dynamic>)> _followerAddedCallbacks = [];
  static final List<Function(Map<String, dynamic>)> _followerRemovedCallbacks = [];
  static final List<Function(Map<String, dynamic>)> _followingAddedCallbacks = [];
  static final List<Function(Map<String, dynamic>)> _followingRemovedCallbacks = [];

  static void onFollowRequestReceived(Function(Map<String, dynamic> data) callback) {
    if (!_followRequestReceivedCallbacks.contains(callback)) {
      _followRequestReceivedCallbacks.add(callback);
    }
    _socket?.off('follow_request_received');
    _socket?.on('follow_request_received', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_followRequestReceivedCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offFollowRequestReceived(Function(Map<String, dynamic> data) callback) {
    _followRequestReceivedCallbacks.remove(callback);
  }

  static void onFriendRequestReceived(Function(Map<String, dynamic> data) callback) {
    if (!_friendRequestReceivedCallbacks.contains(callback)) {
      _friendRequestReceivedCallbacks.add(callback);
    }
    _socket?.off('friend_request_received');
    _socket?.on('friend_request_received', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_friendRequestReceivedCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offFriendRequestReceived(Function(Map<String, dynamic> data) callback) {
    _friendRequestReceivedCallbacks.remove(callback);
  }

  static void onFriendRequestCancelled(Function(Map<String, dynamic> data) callback) {
    if (!_friendRequestCancelledCallbacks.contains(callback)) {
      _friendRequestCancelledCallbacks.add(callback);
    }
    _socket?.off('friend_request_cancelled');
    _socket?.on('friend_request_cancelled', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_friendRequestCancelledCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offFriendRequestCancelled(Function(Map<String, dynamic> data) callback) {
    _friendRequestCancelledCallbacks.remove(callback);
  }

  static void onFriendRequestAccepted(Function(Map<String, dynamic> data) callback) {
    if (!_friendRequestAcceptedCallbacks.contains(callback)) {
      _friendRequestAcceptedCallbacks.add(callback);
    }
    _socket?.off('friend_request_accepted');
    _socket?.on('friend_request_accepted', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_friendRequestAcceptedCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offFriendRequestAccepted(Function(Map<String, dynamic> data) callback) {
    _friendRequestAcceptedCallbacks.remove(callback);
  }

  static void onFriendRequestRejected(Function(Map<String, dynamic> data) callback) {
    if (!_friendRequestRejectedCallbacks.contains(callback)) {
      _friendRequestRejectedCallbacks.add(callback);
    }
    _socket?.off('friend_request_rejected');
    _socket?.on('friend_request_rejected', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_friendRequestRejectedCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offFriendRequestRejected(Function(Map<String, dynamic> data) callback) {
    _friendRequestRejectedCallbacks.remove(callback);
  }

  static void onFriendRemoved(Function(Map<String, dynamic> data) callback) {
    if (!_friendRemovedCallbacks.contains(callback)) {
      _friendRemovedCallbacks.add(callback);
    }
    _socket?.off('friend_removed');
    _socket?.on('friend_removed', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_friendRemovedCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offFriendRemoved(Function(Map<String, dynamic> data) callback) {
    _friendRemovedCallbacks.remove(callback);
  }

  static void onFollowerAdded(Function(Map<String, dynamic> data) callback) {
    if (!_followerAddedCallbacks.contains(callback)) {
      _followerAddedCallbacks.add(callback);
    }
    _socket?.off('follower_added');
    _socket?.on('follower_added', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_followerAddedCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offFollowerAdded(Function(Map<String, dynamic> data) callback) {
    _followerAddedCallbacks.remove(callback);
  }

  static void onFollowerRemoved(Function(Map<String, dynamic> data) callback) {
    if (!_followerRemovedCallbacks.contains(callback)) {
      _followerRemovedCallbacks.add(callback);
    }
    _socket?.off('follower_removed');
    _socket?.on('follower_removed', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_followerRemovedCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offFollowerRemoved(Function(Map<String, dynamic> data) callback) {
    _followerRemovedCallbacks.remove(callback);
  }

  static void onFollowingAdded(Function(Map<String, dynamic> data) callback) {
    if (!_followingAddedCallbacks.contains(callback)) {
      _followingAddedCallbacks.add(callback);
    }
    _socket?.off('following_added');
    _socket?.on('following_added', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_followingAddedCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offFollowingAdded(Function(Map<String, dynamic> data) callback) {
    _followingAddedCallbacks.remove(callback);
  }

  static void onFollowingRemoved(Function(Map<String, dynamic> data) callback) {
    if (!_followingRemovedCallbacks.contains(callback)) {
      _followingRemovedCallbacks.add(callback);
    }
    _socket?.off('following_removed');
    _socket?.on('following_removed', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_followingRemovedCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offFollowingRemoved(Function(Map<String, dynamic> data) callback) {
    _followingRemovedCallbacks.remove(callback);
  }

  static final List<Function(Map<String, dynamic> data)> _newNotificationCallbacks = [];

  static void onNewNotification(Function(Map<String, dynamic> data) callback) {
    if (!_newNotificationCallbacks.contains(callback)) {
      _newNotificationCallbacks.add(callback);
    }
    _socket?.off('new_notification');
    _socket?.on('new_notification', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_newNotificationCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offNewNotification(Function(Map<String, dynamic> data) callback) {
    _newNotificationCallbacks.remove(callback);
  }

  static final List<Function(Map<String, dynamic> data)> _statsUpdatedCallbacks = [];

  static void onStatsUpdated(Function(Map<String, dynamic> data) callback) {
    if (!_statsUpdatedCallbacks.contains(callback)) {
      _statsUpdatedCallbacks.add(callback);
    }
    _socket?.off('stats_updated');
    _socket?.on('stats_updated', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_statsUpdatedCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offStatsUpdated(Function(Map<String, dynamic> data) callback) {
    _statsUpdatedCallbacks.remove(callback);
  }

  static final List<Function(Map<String, dynamic> data)> _userNoteUpdatedCallbacks = [];

  static void onUserNoteUpdated(Function(Map<String, dynamic> data) callback) {
    if (!_userNoteUpdatedCallbacks.contains(callback)) {
      _userNoteUpdatedCallbacks.add(callback);
    }
    _socket?.off('user_note_updated');
    _socket?.on('user_note_updated', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_userNoteUpdatedCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offUserNoteUpdated(Function(Map<String, dynamic> data) callback) {
    _userNoteUpdatedCallbacks.remove(callback);
  }

  static void sendUpdateNote({required String userId, required String note}) {
    if (userId.isEmpty) return;
    _socket?.emit('update_note', {
      'userId': userId,
      'note': note,
    });
  }

  static void joinPost(String postId) {
    if (postId.isEmpty) return;
    _socket?.emit('join_post', postId);
    debugPrint('[Socket] Joined post room: $postId');
  }

  static void leavePost(String postId) {
    if (postId.isEmpty) return;
    _socket?.emit('leave_post', postId);
    debugPrint('[Socket] Left post room: $postId');
  }

  static final List<Function(Map<String, dynamic> data)> _newCommentCallbacks = [];
  static void onNewComment(Function(Map<String, dynamic> data) callback) {
    if (!_newCommentCallbacks.contains(callback)) {
      _newCommentCallbacks.add(callback);
    }
    _bindNewCommentListener();
  }

  static void _bindNewCommentListener() {
    if (_socket == null) return;
    _socket?.off('new_comment');
    _socket?.on('new_comment', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_newCommentCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offNewComment(Function(Map<String, dynamic> data) callback) {
    _newCommentCallbacks.remove(callback);
  }

  static final List<Function(Map<String, dynamic> data)> _commentLikedCallbacks = [];
  static void onCommentLiked(Function(Map<String, dynamic> data) callback) {
    if (!_commentLikedCallbacks.contains(callback)) {
      _commentLikedCallbacks.add(callback);
    }
    _bindCommentLikedListener();
  }

  static void _bindCommentLikedListener() {
    if (_socket == null) return;
    _socket?.off('comment_liked');
    _socket?.on('comment_liked', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_commentLikedCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offCommentLiked(Function(Map<String, dynamic> data) callback) {
    _commentLikedCallbacks.remove(callback);
  }

  static final List<Function(Map<String, dynamic> data)> _postCommentsCountUpdatedCallbacks = [];
  static void onPostCommentsCountUpdated(Function(Map<String, dynamic> data) callback) {
    if (!_postCommentsCountUpdatedCallbacks.contains(callback)) {
      _postCommentsCountUpdatedCallbacks.add(callback);
    }
    _bindPostCommentsCountListener();
  }

  static void _bindPostCommentsCountListener() {
    if (_socket == null) return;
    _socket?.off('post_comments_count_updated');
    _socket?.on('post_comments_count_updated', (data) {
      debugPrint('[Socket] Received post_comments_count_updated: $data');
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_postCommentsCountUpdatedCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offPostCommentsCountUpdated(Function(Map<String, dynamic> data) callback) {
    _postCommentsCountUpdatedCallbacks.remove(callback);
  }

  static final List<Function(Map<String, dynamic> data)> _postLikedCallbacks = [];
  static void onPostLiked(Function(Map<String, dynamic> data) callback) {
    if (!_postLikedCallbacks.contains(callback)) {
      _postLikedCallbacks.add(callback);
    }
    _bindPostLikedListener();
  }

  static void _bindPostLikedListener() {
    if (_socket == null) return;
    _socket?.off('post_liked');
    _socket?.on('post_liked', (data) {
      debugPrint('[Socket] Broadcast post_liked received: $data');
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_postLikedCallbacks)) {
          try {
            cb(map);
          } catch (e) {
            debugPrint('[Socket] Error in post_liked callback: $e');
          }
        }
      }
    });
  }

  static void _bindAllPersistentListeners() {
    _bindPostLikedListener();
    _bindPostCommentsCountListener();
    _bindNewCommentListener();
    _bindCommentLikedListener();
    _bindLiveCommentListener();
    _bindLiveReactionListener();
    _bindLiveViewersListener();
    _bindLiveViewersListListener();
    _bindLiveCommentBlockedListener();
    _bindKickedFromLiveListener();
    _bindLiveEndedListener();
    _bindNewLiveStartedListener();
    _bindIncomingCallListener();
    _bindCallAcceptedListener();
    _bindCallDeclinedListener();
    _bindCallEndedListener();
    _bindCallCancelledListener();
    _bindCallMissedListener();
    _bindCallRingingListener();
    _bindCallMediaStateListener();
    _bindUserOnlineListener();
    _bindUserOfflineListener();
    _bindUserActiveStatusChangedListener();
  }

  static String? get currentUserId => _currentUserId;

  static void emitLikePost({required String postId, String? reaction, String? userId}) {
    if (postId.isEmpty) return;
    final uId = userId ?? _currentUserId;
    _socket?.emit('like_post', {
      'postId': postId,
      if (reaction != null && reaction.isNotEmpty) 'reaction': reaction,
      if (uId != null && uId.isNotEmpty) 'userId': uId,
    });
  }

  static void offPostLiked(Function(Map<String, dynamic> data) callback) {
    _postLikedCallbacks.remove(callback);
  }

  static final List<Function(Map<String, dynamic> data)> _liveCommentCallbacks = [];
  static final List<Function(Map<String, dynamic> data)> _liveReactionCallbacks = [];
  static final List<Function(Map<String, dynamic> data)> _liveViewersCallbacks = [];
  static final List<Function(Map<String, dynamic> data)> _liveViewersListCallbacks = [];
  static final List<Function(Map<String, dynamic> data)> _liveCommentBlockedCallbacks = [];
  static final List<Function(Map<String, dynamic> data)> _kickedFromLiveCallbacks = [];
  static final List<Function(Map<String, dynamic> data)> _liveEndedCallbacks = [];
  static final List<Function(Map<String, dynamic> data)> _newLiveStartedCallbacks = [];

  static void joinLive(String liveId, {String? userId, String? userName, String? userAvatar}) {
    if (liveId.isEmpty) return;
    _socket?.emit('join_live', {
      'liveId': liveId,
      'userId': userId ?? _currentUserId,
      'userName': userName,
      'userAvatar': userAvatar,
    });
  }

  static void leaveLive(String liveId, {String? userId}) {
    if (liveId.isEmpty) return;
    _socket?.emit('leave_live', {
      'liveId': liveId,
      'userId': userId ?? _currentUserId,
    });
  }

  static void getLiveViewers(String liveId) {
    if (liveId.isEmpty) return;
    _socket?.emit('get_live_viewers', {'liveId': liveId});
  }

  static void blockLiveComment({
    required String liveId,
    required String userId,
    required bool isBlocked,
  }) {
    if (liveId.isEmpty || userId.isEmpty) return;
    _socket?.emit('block_live_comment', {
      'liveId': liveId,
      'userId': userId,
      'isBlocked': isBlocked,
    });
  }

  static void kickLiveViewer({
    required String liveId,
    required String userId,
  }) {
    if (liveId.isEmpty || userId.isEmpty) return;
    _socket?.emit('kick_live_viewer', {
      'liveId': liveId,
      'userId': userId,
    });
  }

  static void sendLiveComment({
    required String liveId,
    required String comment,
    String? userId,
    String? userName,
    String? userAvatar,
  }) {
    if (liveId.isEmpty || comment.trim().isEmpty) return;
    _socket?.emit('send_live_comment', {
      'liveId': liveId,
      'comment': comment.trim(),
      'userId': userId ?? _currentUserId,
      'userName': userName,
      'userAvatar': userAvatar,
    });
  }

  static void sendLiveReaction({
    required String liveId,
    String reaction = 'heart',
    String? userId,
  }) {
    if (liveId.isEmpty) return;
    _socket?.emit('send_live_reaction', {
      'liveId': liveId,
      'reaction': reaction,
      'userId': userId ?? _currentUserId,
    });
  }

  static void onLiveComment(Function(Map<String, dynamic> data) callback) {
    if (!_liveCommentCallbacks.contains(callback)) {
      _liveCommentCallbacks.add(callback);
    }
    _bindLiveCommentListener();
  }

  static void _bindLiveCommentListener() {
    if (_socket == null) return;
    _socket?.off('new_live_comment');
    _socket?.on('new_live_comment', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_liveCommentCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offLiveComment(Function(Map<String, dynamic> data) callback) {
    _liveCommentCallbacks.remove(callback);
  }

  static void onLiveReaction(Function(Map<String, dynamic> data) callback) {
    if (!_liveReactionCallbacks.contains(callback)) {
      _liveReactionCallbacks.add(callback);
    }
    _bindLiveReactionListener();
  }

  static void _bindLiveReactionListener() {
    if (_socket == null) return;
    _socket?.off('new_live_reaction');
    _socket?.on('new_live_reaction', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_liveReactionCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offLiveReaction(Function(Map<String, dynamic> data) callback) {
    _liveReactionCallbacks.remove(callback);
  }

  static void onLiveViewersUpdated(Function(Map<String, dynamic> data) callback) {
    if (!_liveViewersCallbacks.contains(callback)) {
      _liveViewersCallbacks.add(callback);
    }
    _bindLiveViewersListener();
  }

  static void _bindLiveViewersListener() {
    if (_socket == null) return;
    _socket?.off('live_viewers_updated');
    _socket?.on('live_viewers_updated', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_liveViewersCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offLiveViewersUpdated(Function(Map<String, dynamic> data) callback) {
    _liveViewersCallbacks.remove(callback);
  }

  static void onLiveEnded(Function(Map<String, dynamic> data) callback) {
    if (!_liveEndedCallbacks.contains(callback)) {
      _liveEndedCallbacks.add(callback);
    }
    _bindLiveEndedListener();
  }

  static void _bindLiveEndedListener() {
    if (_socket == null) return;
    _socket?.off('live_ended');
    _socket?.on('live_ended', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_liveEndedCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offLiveEnded(Function(Map<String, dynamic> data) callback) {
    _liveEndedCallbacks.remove(callback);
  }

  static void onNewLiveStarted(Function(Map<String, dynamic> data) callback) {
    if (!_newLiveStartedCallbacks.contains(callback)) {
      _newLiveStartedCallbacks.add(callback);
    }
    _bindNewLiveStartedListener();
  }

  static void _bindNewLiveStartedListener() {
    if (_socket == null) return;
    _socket?.off('new_live_started');
    _socket?.on('new_live_started', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_newLiveStartedCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offNewLiveStarted(Function(Map<String, dynamic> data) callback) {
    _newLiveStartedCallbacks.remove(callback);
  }

  static void onLiveViewersList(Function(Map<String, dynamic> data) callback) {
    if (!_liveViewersListCallbacks.contains(callback)) {
      _liveViewersListCallbacks.add(callback);
    }
    _bindLiveViewersListListener();
  }

  static void _bindLiveViewersListListener() {
    if (_socket == null) return;
    _socket?.off('live_viewers_list');
    _socket?.on('live_viewers_list', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_liveViewersListCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offLiveViewersList(Function(Map<String, dynamic> data) callback) {
    _liveViewersListCallbacks.remove(callback);
  }

  static void onLiveCommentBlocked(Function(Map<String, dynamic> data) callback) {
    if (!_liveCommentBlockedCallbacks.contains(callback)) {
      _liveCommentBlockedCallbacks.add(callback);
    }
    _bindLiveCommentBlockedListener();
  }

  static void _bindLiveCommentBlockedListener() {
    if (_socket == null) return;
    _socket?.off('live_comment_blocked');
    _socket?.on('live_comment_blocked', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_liveCommentBlockedCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offLiveCommentBlocked(Function(Map<String, dynamic> data) callback) {
    _liveCommentBlockedCallbacks.remove(callback);
  }

  static void onKickedFromLive(Function(Map<String, dynamic> data) callback) {
    if (!_kickedFromLiveCallbacks.contains(callback)) {
      _kickedFromLiveCallbacks.add(callback);
    }
    _bindKickedFromLiveListener();
  }

  static void _bindKickedFromLiveListener() {
    if (_socket == null) return;
    _socket?.off('kicked_from_live');
    _socket?.on('kicked_from_live', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_kickedFromLiveCallbacks)) {
          cb(map);
        }
      }
    });
  }

  static void offKickedFromLive(Function(Map<String, dynamic> data) callback) {
    _kickedFromLiveCallbacks.remove(callback);
  }

  // ==================== CALL EVENTS ====================

  static final List<Function(Map<String, dynamic> data)> _incomingCallCallbacks = [];
  static final List<Function(Map<String, dynamic> data)> _callAcceptedCallbacks = [];
  static final List<Function(Map<String, dynamic> data)> _callDeclinedCallbacks = [];
  static final List<Function(Map<String, dynamic> data)> _callEndedCallbacks = [];
  static final List<Function(Map<String, dynamic> data)> _callCancelledCallbacks = [];
  static final List<Function(Map<String, dynamic> data)> _callMissedCallbacks = [];
  static final List<Function(Map<String, dynamic> data)> _callRingingCallbacks = [];
  static final List<Function(Map<String, dynamic> data)> _callMediaStateCallbacks = [];

  static void onIncomingCall(Function(Map<String, dynamic> data) callback) {
    if (!_incomingCallCallbacks.contains(callback)) {
      _incomingCallCallbacks.add(callback);
    }
    _bindIncomingCallListener();
  }

  static void _bindIncomingCallListener() {
    if (_socket == null) return;
    _socket?.off('incoming_call');
    _socket?.on('incoming_call', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_incomingCallCallbacks)) {
          try {
            cb(map);
          } catch (e) {
            debugPrint('[Socket] incoming_call cb error: $e');
          }
        }
      }
    });
  }

  static void offIncomingCall(Function(Map<String, dynamic> data) callback) {
    _incomingCallCallbacks.remove(callback);
  }

  static void onCallAccepted(Function(Map<String, dynamic> data) callback) {
    if (!_callAcceptedCallbacks.contains(callback)) {
      _callAcceptedCallbacks.add(callback);
    }
    _bindCallAcceptedListener();
  }

  static void _bindCallAcceptedListener() {
    if (_socket == null) return;
    _socket?.off('call_accepted');
    _socket?.on('call_accepted', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_callAcceptedCallbacks)) {
          try {
            cb(map);
          } catch (e) {
            debugPrint('[Socket] call_accepted cb error: $e');
          }
        }
      }
    });
  }

  static void offCallAccepted(Function(Map<String, dynamic> data) callback) {
    _callAcceptedCallbacks.remove(callback);
  }

  static void onCallDeclined(Function(Map<String, dynamic> data) callback) {
    if (!_callDeclinedCallbacks.contains(callback)) {
      _callDeclinedCallbacks.add(callback);
    }
    _bindCallDeclinedListener();
  }

  static void _bindCallDeclinedListener() {
    if (_socket == null) return;
    _socket?.off('call_declined');
    _socket?.on('call_declined', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_callDeclinedCallbacks)) {
          try {
            cb(map);
          } catch (e) {
            debugPrint('[Socket] call_declined cb error: $e');
          }
        }
      }
    });
  }

  static void offCallDeclined(Function(Map<String, dynamic> data) callback) {
    _callDeclinedCallbacks.remove(callback);
  }

  static void onCallEnded(Function(Map<String, dynamic> data) callback) {
    if (!_callEndedCallbacks.contains(callback)) {
      _callEndedCallbacks.add(callback);
    }
    _bindCallEndedListener();
  }

  static void _bindCallEndedListener() {
    if (_socket == null) return;
    _socket?.off('call_ended');
    _socket?.on('call_ended', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_callEndedCallbacks)) {
          try {
            cb(map);
          } catch (e) {
            debugPrint('[Socket] call_ended cb error: $e');
          }
        }
      }
    });
  }

  static void offCallEnded(Function(Map<String, dynamic> data) callback) {
    _callEndedCallbacks.remove(callback);
  }

  static void onCallCancelled(Function(Map<String, dynamic> data) callback) {
    if (!_callCancelledCallbacks.contains(callback)) {
      _callCancelledCallbacks.add(callback);
    }
    _bindCallCancelledListener();
  }

  static void _bindCallCancelledListener() {
    if (_socket == null) return;
    _socket?.off('call_cancelled');
    _socket?.on('call_cancelled', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_callCancelledCallbacks)) {
          try {
            cb(map);
          } catch (e) {
            debugPrint('[Socket] call_cancelled cb error: $e');
          }
        }
      }
    });
  }

  static void offCallCancelled(Function(Map<String, dynamic> data) callback) {
    _callCancelledCallbacks.remove(callback);
  }

  static void onCallMissed(Function(Map<String, dynamic> data) callback) {
    if (!_callMissedCallbacks.contains(callback)) {
      _callMissedCallbacks.add(callback);
    }
    _bindCallMissedListener();
  }

  static void _bindCallMissedListener() {
    if (_socket == null) return;
    _socket?.off('call_missed');
    _socket?.on('call_missed', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_callMissedCallbacks)) {
          try {
            cb(map);
          } catch (e) {
            debugPrint('[Socket] call_missed cb error: $e');
          }
        }
      }
    });
  }

  static void offCallMissed(Function(Map<String, dynamic> data) callback) {
    _callMissedCallbacks.remove(callback);
  }

  static void onCallRinging(Function(Map<String, dynamic> data) callback) {
    if (!_callRingingCallbacks.contains(callback)) {
      _callRingingCallbacks.add(callback);
    }
    _bindCallRingingListener();
  }

  static void _bindCallRingingListener() {
    if (_socket == null) return;
    _socket?.off('call_ringing');
    _socket?.on('call_ringing', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_callRingingCallbacks)) {
          try {
            cb(map);
          } catch (e) {
            debugPrint('[Socket] call_ringing cb error: $e');
          }
        }
      }
    });
  }

  static void offCallRinging(Function(Map<String, dynamic> data) callback) {
    _callRingingCallbacks.remove(callback);
  }

  static void onCallMediaState(Function(Map<String, dynamic> data) callback) {
    if (!_callMediaStateCallbacks.contains(callback)) {
      _callMediaStateCallbacks.add(callback);
    }
    _bindCallMediaStateListener();
  }

  static void _bindCallMediaStateListener() {
    if (_socket == null) return;
    _socket?.off('call_media_state');
    _socket?.on('call_media_state', (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (var cb in List.from(_callMediaStateCallbacks)) {
          try {
            cb(map);
          } catch (e) {
            debugPrint('[Socket] call_media_state cb error: $e');
          }
        }
      }
    });
  }

  static void offCallMediaState(Function(Map<String, dynamic> data) callback) {
    _callMediaStateCallbacks.remove(callback);
  }

  static void emitCallRinging({required String callId, required String callerId}) {
    if (callId.isEmpty || callerId.isEmpty) return;
    _socket?.emit('call_ringing', {
      'callId': callId,
      'callerId': callerId,
      'userId': _currentUserId,
    });
  }

  static void emitCallAccept({
    required String callId,
    String? callDocId,
    String? userId,
  }) {
    if (callId.isEmpty && (callDocId == null || callDocId.isEmpty)) return;
    _socket?.emit('call_accept', {
      'callId': callId,
      if (callDocId != null && callDocId.isNotEmpty) 'callDocId': callDocId,
      'userId': userId ?? _currentUserId,
    });
  }

  static void emitCallDecline({
    required String callId,
    String? callDocId,
    String? userId,
  }) {
    if (callId.isEmpty && (callDocId == null || callDocId.isEmpty)) return;
    _socket?.emit('call_decline', {
      'callId': callId,
      if (callDocId != null && callDocId.isNotEmpty) 'callDocId': callDocId,
      'userId': userId ?? _currentUserId,
    });
  }

  static void emitCallCancel({
    required String callId,
    String? callDocId,
    String? userId,
  }) {
    if (callId.isEmpty && (callDocId == null || callDocId.isEmpty)) return;
    _socket?.emit('call_cancel', {
      'callId': callId,
      if (callDocId != null && callDocId.isNotEmpty) 'callDocId': callDocId,
      'userId': userId ?? _currentUserId,
    });
  }

  static void emitCallEnd({
    required String callId,
    String? callDocId,
    String? userId,
    bool endForAll = false,
  }) {
    if (callId.isEmpty && (callDocId == null || callDocId.isEmpty)) return;
    _socket?.emit('call_end', {
      'callId': callId,
      if (callDocId != null && callDocId.isNotEmpty) 'callDocId': callDocId,
      'userId': userId ?? _currentUserId,
      'endForAll': endForAll,
    });
  }

  static void emitCallMediaState({
    required String callId,
    required List<String> targetUserIds,
    required bool isVideoOn,
    required bool isAudioMuted,
  }) {
    if (callId.isEmpty || targetUserIds.isEmpty) return;
    _socket?.emit('call_media_state', {
      'callId': callId,
      'targetUserIds': targetUserIds,
      'userId': _currentUserId,
      'isVideoOn': isVideoOn,
      'isAudioMuted': isAudioMuted,
    });
  }

  static void emitCallHeartbeat({
    required String callId,
    String? callDocId,
  }) {
    if (callId.isEmpty && (callDocId == null || callDocId.isEmpty)) return;
    _socket?.emit('call_heartbeat', {
      'callId': callId,
      if (callDocId != null && callDocId.isNotEmpty) 'callDocId': callDocId,
      'userId': _currentUserId,
    });
  }

  static void disconnect() {
    final oldSocket = _socket;
    _socket = null;
    _isConnected = false;
    final oldUserId = _currentUserId;
    _currentUserId = null;
    try {
      if (oldUserId != null && oldSocket != null) {
        oldSocket.emit('leave_user', oldUserId);
      }
      oldSocket?.disconnect();
      oldSocket?.dispose();
    } catch (_) {}
  }
}
