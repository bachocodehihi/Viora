import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../l10n/language.dart';
import 'session_service.dart';

class SocialNotificationService {
  static Future<Map<String, String>> _getHeaders() async {
    final token = await SessionService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>?> fetchNotifications() async {
    try {
      final userId = await SessionService.getUserId();
      if (userId == null || userId.isEmpty) return null;

      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse(ApiConfig.getNotifications),
            headers: headers,
            body: jsonEncode({'userId': userId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          return data;
        }
      }
      return null;
    } catch (e) {
      debugPrint('SocialNotificationService.fetchNotifications error: $e');
      return null;
    }
  }

  static Future<bool> markAsRead(String notificationId) async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.markNotificationRead),
        headers: headers,
        body: jsonEncode({
          'userId': userId,
          'notificationId': notificationId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('SocialNotificationService.markAsRead error: $e');
      return false;
    }
  }

  static Future<bool> markAllAsRead() async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.markAllNotificationsRead),
        headers: headers,
        body: jsonEncode({'userId': userId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('SocialNotificationService.markAllAsRead error: $e');
      return false;
    }
  }

  static Future<bool> clearAll() async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.clearNotifications),
        headers: headers,
        body: jsonEncode({'userId': userId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('SocialNotificationService.clearAll error: $e');
      return false;
    }
  }

  static Future<bool> updateStatus(String notificationId, String status) async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.updateNotificationStatus),
        headers: headers,
        body: jsonEncode({
          'userId': userId,
          'notificationId': notificationId,
          'status': status,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('SocialNotificationService.updateStatus error: $e');
      return false;
    }
  }

  static Future<bool> acceptFriendRequest({String? requestId, String? senderId}) async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();
      final body = <String, dynamic>{
        'userId': userId,
      };
      if (requestId != null && requestId.isNotEmpty) body['requestId'] = requestId;
      if (senderId != null && senderId.isNotEmpty) body['senderId'] = senderId;

      final response = await http.post(
        Uri.parse(ApiConfig.acceptFriendRequest),
        headers: headers,
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        return res['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('SocialNotificationService.acceptFriendRequest error: $e');
      return false;
    }
  }

  static Future<bool> rejectFriendRequest({String? requestId, String? senderId}) async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();
      final body = <String, dynamic>{
        'userId': userId,
      };
      if (requestId != null && requestId.isNotEmpty) body['requestId'] = requestId;
      if (senderId != null && senderId.isNotEmpty) body['senderId'] = senderId;

      final response = await http.post(
        Uri.parse(ApiConfig.rejectFriendRequest),
        headers: headers,
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        return res['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('SocialNotificationService.rejectFriendRequest error: $e');
      return false;
    }
  }

  static String getNotificationActionText(Map<String, dynamic> notification, [Language? l10n]) {
    final status = notification['status']?.toString();
    if (status == 'accepted') {
      return l10n?.friendRequestAccepted ?? Language.translateStatic('friendRequestAccepted');
    }
    if (status == 'declined') {
      return l10n?.friendRequestDeclined ?? Language.translateStatic('friendRequestDeclined');
    }

    final type = notification['type']?.toString() ?? 'system';
    final rawContent = (notification['content'] ?? '').toString().trim();
    final reaction = notification['reaction']?.toString().toLowerCase().trim();
    final hasComment = notification['comment'] != null ||
        notification['commentId'] != null ||
        (notification['data'] is Map &&
            (notification['data']['commentId'] != null || notification['data']['comment'] != null));

    switch (type) {
      case 'friend_live':
      case 'livestream':
        final liveTitle = (notification['liveTitle'] ?? rawContent).toString();
        final defaultTitle = l10n?.liveStreamTitleDefault ?? Language.translateStatic('liveStreamTitleDefault');
        final effectiveLiveTitle = liveTitle.isNotEmpty ? liveTitle : defaultTitle;
        if (l10n != null) {
          return l10n.notifLiveStreaming(effectiveLiveTitle);
        }
        return Language.translateStatic('notifLiveStreaming').replaceAll('{title}', effectiveLiveTitle);

      case 'friend_post':
        if (rawContent.isNotEmpty) {
          if (l10n != null) {
            return l10n.notifPostedNewPostWithContent(rawContent);
          }
          return Language.translateStatic('notifPostedNewPostWithContent').replaceAll('{content}', rawContent);
        }
        return l10n?.notifPostedNewPost ?? Language.translateStatic('notifPostedNewPost');

      case 'friend_story':
        return l10n?.notifSharedNewStory ?? Language.translateStatic('notifSharedNewStory');

      case 'friend_request':
        return l10n?.notifSentFriendRequest ?? Language.translateStatic('notifSentFriendRequest');

      case 'friend_accept':
        return l10n?.notifAcceptedFriendRequest ?? Language.translateStatic('notifAcceptedFriendRequest');

      case 'group_invite':
        return l10n?.notifInvitedToGroup ?? Language.translateStatic('notifInvitedToGroup');

      case 'group_post':
        return l10n?.notifGroupPostedNewPost ?? Language.translateStatic('notifGroupPostedNewPost');

      case 'like':
        final effectiveReaction = (reaction != null && reaction.isNotEmpty)
            ? reaction
            : _detectReaction(rawContent);
        if (hasComment) {
          return l10n?.notifLikedYourComment ?? Language.translateStatic('notifLikedYourComment');
        }
        switch (effectiveReaction) {
          case 'love':
            return l10n?.notifReactedLovePost ?? Language.translateStatic('notifReactedLovePost');
          case 'haha':
            return l10n?.notifReactedHahaPost ?? Language.translateStatic('notifReactedHahaPost');
          case 'wow':
            return l10n?.notifReactedWowPost ?? Language.translateStatic('notifReactedWowPost');
          case 'sad':
            return l10n?.notifReactedSadPost ?? Language.translateStatic('notifReactedSadPost');
          case 'angry':
            return l10n?.notifReactedAngryPost ?? Language.translateStatic('notifReactedAngryPost');
          default:
            return l10n?.notifLikedYourPost ?? Language.translateStatic('notifLikedYourPost');
        }

      case 'comment':
        final snippet = _extractCommentSnippet(rawContent);
        if (snippet.isNotEmpty) {
          if (l10n != null) {
            return l10n.notifCommentedYourPostWithContent(snippet);
          }
          return Language.translateStatic('notifCommentedYourPostWithContent').replaceAll('{content}', snippet);
        }
        return l10n?.notifCommentedYourPost ?? Language.translateStatic('notifCommentedYourPost');

      case 'follow':
        return l10n?.notifStartedFollowingYou ?? Language.translateStatic('notifStartedFollowingYou');

      default:
        if (rawContent.isNotEmpty && !rawContent.contains('Viora')) return rawContent;
        return l10n?.notifDefault ?? Language.translateStatic('notifDefault');
    }
  }

  static String _detectReaction(String content) {
    final lower = content.toLowerCase().trim();
    for (final r in ['love', 'haha', 'wow', 'sad', 'angry']) {
      if (lower.contains(r)) return r;
    }
    for (final trans in Language.getAllTranslationsOf('notifReactedLovePost')) {
      if (lower.contains(trans.toLowerCase())) return 'love';
    }
    for (final trans in Language.getAllTranslationsOf('notifReactedHahaPost')) {
      if (lower.contains(trans.toLowerCase())) return 'haha';
    }
    for (final trans in Language.getAllTranslationsOf('notifReactedWowPost')) {
      if (lower.contains(trans.toLowerCase())) return 'wow';
    }
    for (final trans in Language.getAllTranslationsOf('notifReactedSadPost')) {
      if (lower.contains(trans.toLowerCase())) return 'sad';
    }
    for (final trans in Language.getAllTranslationsOf('notifReactedAngryPost')) {
      if (lower.contains(trans.toLowerCase())) return 'angry';
    }
    return 'like';
  }

  static String _extractCommentSnippet(String content) {
    if (content.isEmpty) return '';
    final quoteMatch = RegExp(r'["“](.+?)["”]').firstMatch(content);
    if (quoteMatch != null) {
      return quoteMatch.group(1)?.trim() ?? '';
    }
    return content.length > 50 ? '${content.substring(0, 47)}...' : content;
  }
}
