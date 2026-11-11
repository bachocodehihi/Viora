import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../services/social_notification_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/toast/app_toast.dart';
import '../../utils/time_formatter.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  Language get l10n => context.l10n;
  final List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  late final Function(Map<String, dynamic>) _onNewNotification;
  late final Function(Map<String, dynamic>) _onFriendRequestAccepted;
  late final Function(Map<String, dynamic>) _onFriendRequestRejected;
  late final Function(Map<String, dynamic>) _onFriendRequestCancelled;

  @override
  void initState() {
    super.initState();
    _initSocketListeners();
    _loadNotifications();
  }

  void _initSocketListeners() {

    _onNewNotification = (data) {
      if (!mounted) return;
      final type = data['type']?.toString();

      if (type == 'message') return;

      final mappedItem = _mapNotificationItem(data);
      setState(() {

        _notifications.removeWhere((n) => n['id'] == mappedItem['id']);
        _notifications.insert(0, mappedItem);
      });
    };

    _onFriendRequestAccepted = (data) {
      if (!mounted) return;
      final reqId = data['requestId']?.toString();
      final uId = data['userId']?.toString();
      setState(() {
        for (var n in _notifications) {
          if ((reqId != null && n['requestId'] == reqId) ||
              (uId != null && n['senderId'] == uId && n['type'] == 'friend_request')) {
            n['status'] = 'accepted';
          }
        }
      });
    };

    _onFriendRequestRejected = (data) {
      if (!mounted) return;
      final reqId = data['requestId']?.toString();
      final receiverId = data['receiverId']?.toString();
      setState(() {
        for (var n in _notifications) {
          if ((reqId != null && n['requestId'] == reqId) ||
              (receiverId != null && n['senderId'] == receiverId && n['type'] == 'friend_request')) {
            n['status'] = 'declined';
          }
        }
      });
    };

    _onFriendRequestCancelled = (data) {
      if (!mounted) return;
      final senderId = data['senderId']?.toString();
      final reqId = data['requestId']?.toString();
      setState(() {
        _notifications.removeWhere((n) =>
            (reqId != null && reqId.isNotEmpty && n['requestId'] == reqId) ||
            (senderId != null && n['senderId'] == senderId && n['type'] == 'friend_request'));
      });
    };

    SocketService.onNewNotification(_onNewNotification);
    SocketService.onFriendRequestAccepted(_onFriendRequestAccepted);
    SocketService.onFriendRequestRejected(_onFriendRequestRejected);
    SocketService.onFriendRequestCancelled(_onFriendRequestCancelled);
  }

  @override
  void dispose() {
    SocketService.offNewNotification(_onNewNotification);
    SocketService.offFriendRequestAccepted(_onFriendRequestAccepted);
    SocketService.offFriendRequestRejected(_onFriendRequestRejected);
    SocketService.offFriendRequestCancelled(_onFriendRequestCancelled);
    super.dispose();
  }

  String _formatTime(dynamic dateValue) {
    return TimeFormatter.formatTimeAgo(context, dateValue);
  }

  Map<String, dynamic> _mapNotificationItem(Map<String, dynamic> item) {
    final sender = item['sender'] is Map ? Map<String, dynamic>.from(item['sender']) : null;
    final group = item['group'] is Map ? Map<String, dynamic>.from(item['group']) : null;
    final request = item['request'] is Map ? Map<String, dynamic>.from(item['request']) : null;
    final live = item['livestream'] is Map ? Map<String, dynamic>.from(item['livestream']) : null;
    final type = item['type']?.toString() ?? 'system';

    String title = sender?['username']?.toString() ?? 'Viora';
    if ((type == 'group_post' || type == 'group_invite') && group != null) {
      title = group['name']?.toString() ?? title;
    }

    final rawContent = (item['content'] ?? '').toString().trim();

    dynamic avatar = sender?['avatar'];
    if ((type == 'group_post' || type == 'group_invite') && group?['avatar'] != null) {
      avatar = group?['avatar'];
    }

    final isRead = item['isRead'] == true;
    String status = item['status']?.toString() ?? (isRead ? 'read' : 'unread');
    if (type == 'friend_request' && status == 'none') {
      status = 'pending';
    }

    final liveId = live?['_id']?.toString() ??
        live?['id']?.toString() ??
        item['livestream']?.toString() ??
        item['liveId']?.toString();
    final liveTitle = live?['title']?.toString() ?? (rawContent.isNotEmpty ? rawContent : '');

    return {
      'id': item['_id']?.toString() ?? item['id']?.toString() ?? '',
      'type': type,
      'title': title,
      'content': rawContent,
      'avatar': avatar,
      'senderId': sender?['_id']?.toString() ?? item['senderId']?.toString(),
      'senderName': sender?['username']?.toString(),
      'groupId': group?['_id']?.toString(),
      'groupName': group?['name']?.toString(),
      'postId': item['post'] is Map ? item['post']['_id']?.toString() : item['post']?.toString(),
      'commentId': item['comment'] is Map ? item['comment']['_id']?.toString() : item['comment']?.toString(),
      'reaction': item['reaction']?.toString(),
      'liveId': liveId,
      'liveTitle': liveTitle,
      'channelName': live?['channelName']?.toString() ?? item['channelName']?.toString(),
      'requestId': request?['_id']?.toString() ?? item['requestId']?.toString(),
      'status': status,
      'isRead': isRead,
      'time': _formatTime(item['createdAt']),
      'raw': item,
    };
  }

  String _getNotificationDesc(BuildContext context, Map<String, dynamic> notification) {
    return SocialNotificationService.getNotificationActionText(notification, l10n);
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final data = await SocialNotificationService.fetchNotifications();
    if (!mounted) return;

    if (data != null && data['notifications'] is List) {
      final list = (data['notifications'] as List)
          .map((n) => _mapNotificationItem(Map<String, dynamic>.from(n)))
          .toList();

      setState(() {
        _notifications.clear();
        _notifications.addAll(list);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptRequest(Map<String, dynamic> notification) async {
    final senderId = notification['senderId']?.toString();
    final requestId = notification['requestId']?.toString();

    setState(() {
      notification['status'] = 'accepted';
    });

    final success = await SocialNotificationService.acceptFriendRequest(
      requestId: requestId,
      senderId: senderId,
    );

    if (notification['id'] != null && notification['id'].toString().isNotEmpty) {
      SocialNotificationService.updateStatus(notification['id'].toString(), 'accepted');
    }

    if (!success && mounted) {
      AppToast.error(context, l10n.errorProcessingFriendRequest);
    }
  }

  Future<void> _declineRequest(Map<String, dynamic> notification) async {
    final senderId = notification['senderId']?.toString();
    final requestId = notification['requestId']?.toString();

    setState(() {
      notification['status'] = 'declined';
    });

    final success = await SocialNotificationService.rejectFriendRequest(
      requestId: requestId,
      senderId: senderId,
    );

    if (notification['id'] != null && notification['id'].toString().isNotEmpty) {
      SocialNotificationService.updateStatus(notification['id'].toString(), 'declined');
    }

    if (!success && mounted) {
      AppToast.error(context, l10n.errorRejectingFriendRequest);
    }
  }

  Future<void> _clearAll() async {
    setState(() {
      _notifications.clear();
    });
    await SocialNotificationService.clearAll();
  }

  void _onNotificationTap(Map<String, dynamic> notification) {

    if (notification['isRead'] == false && notification['id'].toString().isNotEmpty) {
      notification['isRead'] = true;
      SocialNotificationService.markAsRead(notification['id'].toString());
      setState(() {});
    }

    final type = notification['type']?.toString();
    final senderId = notification['senderId']?.toString();
    final senderName = notification['senderName'] ?? notification['title'];
    final groupId = notification['groupId']?.toString();

    if (type == 'friend_live' || type == 'livestream') {
      final liveId = notification['liveId']?.toString();
      if (liveId != null && liveId.isNotEmpty) {
        Navigator.pushNamed(
          context,
          AppRoutes.liveAudience,
          arguments: {
            'liveId': liveId,
            'initialTitle': notification['liveTitle'] ?? l10n.liveStreamTitleDefault,
            'hostName': senderName,
            'hostAvatar': notification['avatar'],
          },
        );
      } else if (senderId != null && senderId.isNotEmpty) {
        Navigator.pushNamed(
          context,
          AppRoutes.profileAccount,
          arguments: {
            'userId': senderId,
            'name': senderName,
            'avatar': notification['avatar'],
          },
        );
      }
    } else if (type == 'friend_post' || type == 'like' || type == 'comment') {
      final postId = notification['postId']?.toString();
      if (postId != null && postId.isNotEmpty) {
        final rawPost = notification['raw']?['post'];
        Map<String, dynamic> postMap;
        if (rawPost is Map) {
          postMap = Map<String, dynamic>.from(rawPost);
          if (!postMap.containsKey('id') && !postMap.containsKey('_id')) {
            postMap['_id'] = postId;
          }
        } else {
          postMap = {'_id': postId, 'id': postId};
        }

        Navigator.pushNamed(
          context,
          AppRoutes.postDetail,
          arguments: {
            'post': postMap,
          },
        );
      } else if (senderId != null && senderId.isNotEmpty) {
        Navigator.pushNamed(
          context,
          AppRoutes.profileAccount,
          arguments: {
            'userId': senderId,
            'name': senderName,
            'avatar': notification['avatar'],
          },
        );
      }
    } else if (type == 'friend_request' || type == 'friend_accept' || type == 'follow') {
      if (senderId != null && senderId.isNotEmpty) {
        Navigator.pushNamed(
          context,
          AppRoutes.profileAccount,
          arguments: {
            'userId': senderId,
            'name': senderName,
            'avatar': notification['avatar'],
          },
        );
      }
    } else if (type == 'group_invite' || type == 'group_post') {
      if (groupId != null && groupId.isNotEmpty) {
        Navigator.pushNamed(
          context,
          AppRoutes.profileGroup,
          arguments: {
            'groupId': groupId,
            'name': notification['groupName'] ?? notification['title'],
            'avatar': notification['avatar'] ?? '',
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          l10n.notifications,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: context.textPrimary,
          ),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: const Text(
                'Clear All',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.blue),
            )
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              color: AppColors.blue,
              child: _notifications.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: AppColors.blue.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.notifications_off_outlined,
                                  size: 36,
                                  color: AppColors.blue,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No new notifications',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        right: 16.0,
                        top: 8.0,
                        bottom: 110.0,
                      ),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        final isUnread = notification['status'] == 'unread' ||
                            notification['status'] == 'pending' ||
                            notification['isRead'] == false;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          padding: const EdgeInsets.all(14.0),
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: context.notificationShadow,
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ],
                            border: isUnread
                                ? Border.all(
                                    color: AppColors.blue.withValues(alpha: 0.2),
                                    width: 1.5,
                                  )
                                : null,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => _onNotificationTap(notification),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    AppAvatar(
                                      avatar: notification['avatar'],
                                      name: notification['title'],
                                      radius: 20,
                                      fontSize: 14,
                                    ),
                                    if (notification['type'] == 'friend_live' || notification['type'] == 'livestream')
                                      Positioned(
                                        bottom: -2,
                                        right: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF3366),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: context.cardBg,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: const Icon(Icons.videocam_rounded, size: 9, color: Colors.white),
                                        ),
                                      )
                                    else if (notification['type'] == 'friend_post')
                                      Positioned(
                                        bottom: -2,
                                        right: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: AppColors.blue,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: context.cardBg,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: const Icon(Icons.edit_note_rounded, size: 9, color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () => _onNotificationTap(notification),
                                      child: Text.rich(
                                        TextSpan(
                                          style: TextStyle(
                                            color: context.textPrimary,
                                            fontSize: 14,
                                            fontFamily: 'Inter',
                                            fontFamilyFallback: const ['Inter', 'Roboto', 'sans-serif'],
                                          ),
                                          children: [
                                            TextSpan(
                                              text: '${notification['title']} ',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            TextSpan(text: _getNotificationDesc(context, notification)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      notification['time'] ?? '',
                                      style: TextStyle(color: context.textMuted, fontSize: 11),
                                    ),

                                    if (notification['type'] == 'friend_request' &&
                                        notification['status'] == 'pending') ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          ElevatedButton(
                                            onPressed: () => _acceptRequest(notification),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.blue,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 18,
                                                vertical: 8,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                            child: const Text(
                                              'Accept',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          OutlinedButton(
                                            onPressed: () => _declineRequest(notification),
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                color: context.textMuted.withValues(alpha: 0.3),
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 18,
                                                vertical: 8,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                            child: Text(
                                              'Decline',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: context.textMuted,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    ] else if (notification['status'] == 'accepted') ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                                          const SizedBox(width: 4),
                                          Text(
                                            l10n.accepted,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.green,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else if (notification['status'] == 'declined') ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.remove_circle_outline_rounded,
                                              size: 14, color: context.textMuted),
                                          const SizedBox(width: 4),
                                          Text(
                                            l10n.declined,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: context.textMuted,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else if ((notification['type'] == 'friend_live' ||
                                            notification['type'] == 'livestream') &&
                                        notification['liveId'] != null &&
                                        notification['liveId'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      InkWell(
                                        onTap: () => _onNotificationTap(notification),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFFFF3366), Color(0xFFFF5E3A)],
                                            ),
                                            borderRadius: BorderRadius.circular(10),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFFFF3366).withValues(alpha: 0.35),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.sensors_rounded, size: 15, color: Colors.white),
                                              const SizedBox(width: 6),
                                              Text(
                                                l10n.watchLiveStream,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ] else if (notification['type'] == 'friend_post' &&
                                        notification['postId'] != null &&
                                        notification['postId'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      InkWell(
                                        onTap: () => _onNotificationTap(notification),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.blue.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: AppColors.blue.withValues(alpha: 0.25),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.article_rounded, size: 14, color: AppColors.blue),
                                              const SizedBox(width: 6),
                                              Text(
                                                l10n.viewPost,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.blue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
