import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'session_service.dart';

class ContactService {
  static Future<Map<String, dynamic>?> fetchContacts() async {
    try {
      final userId = await SessionService.getUserId();
      final token = await SessionService.getToken();

      final body = <String, dynamic>{};
      if (userId != null && userId.isNotEmpty) body['userId'] = userId;

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.getContacts),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as Map<String, dynamic>?;
        }
      }
      return null;
    } catch (e) {
      debugPrint('ContactService.fetchContacts error: $e');
      return null;
    }
  }

  static Future<bool> sendFriendRequest(String receiverId) async {
    try {
      final userId = await SessionService.getUserId();
      final token = await SessionService.getToken();

      final body = <String, dynamic>{
        'receiverId': receiverId,
      };
      if (userId != null) body['userId'] = userId;

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.sendFriendRequest),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }

      if (response.statusCode == 400) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map &&
              (decoded['code'] == 'FRIEND_REQUEST_ALREADY_SENT' ||
                  decoded['message'] == 'Friend request already sent' ||
                  decoded['alreadySent'] == true)) {
            return true;
          }
        } catch (_) {}
      }

      return false;
    } catch (e) {
      debugPrint('ContactService.sendFriendRequest error: $e');
      return false;
    }
  }

  static Future<bool> cancelFriendRequest(String receiverId, {String? requestId}) async {
    try {
      final userId = await SessionService.getUserId();
      final token = await SessionService.getToken();

      final body = <String, dynamic>{};
      if (requestId != null) body['requestId'] = requestId;
      if (receiverId.isNotEmpty) body['receiverId'] = receiverId;
      if (userId != null) body['userId'] = userId;

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.cancelFriendRequest),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ContactService.cancelFriendRequest error: $e');
      return false;
    }
  }

  static Future<bool> removeFriend(String friendId) async {
    try {
      final userId = await SessionService.getUserId();
      final token = await SessionService.getToken();

      final body = <String, dynamic>{
        'friendId': friendId,
      };
      if (userId != null) body['userId'] = userId;

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.removeFriend),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ContactService.removeFriend error: $e');
      return false;
    }
  }

  static Future<bool> acceptFriendRequest(String requestId, {String? senderId}) async {
    try {
      final userId = await SessionService.getUserId();
      final token = await SessionService.getToken();

      final body = <String, dynamic>{
        'requestId': requestId,
      };
      if (senderId != null) body['senderId'] = senderId;
      if (userId != null) body['userId'] = userId;

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.acceptFriendRequest),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ContactService.acceptFriendRequest error: $e');
      return false;
    }
  }

  static Future<bool> declineFriendRequest(String requestId, {String? senderId}) async {
    try {
      final userId = await SessionService.getUserId();
      final token = await SessionService.getToken();

      final body = <String, dynamic>{
        'requestId': requestId,
      };
      if (senderId != null) body['senderId'] = senderId;
      if (userId != null) body['userId'] = userId;

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.rejectFriendRequest),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ContactService.declineFriendRequest error: $e');
      return false;
    }
  }

  static Future<bool> acceptGroupInvite(String requestId, {String? groupId}) async {
    try {
      final userId = await SessionService.getUserId();
      final token = await SessionService.getToken();

      final body = <String, dynamic>{
        'requestId': requestId,
      };
      if (groupId != null) body['groupId'] = groupId;
      if (userId != null) body['userId'] = userId;

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.acceptGroupInvite),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ContactService.acceptGroupInvite error: $e');
      return false;
    }
  }

  static Future<bool> declineGroupInvite(String requestId, {String? groupId}) async {
    try {
      final userId = await SessionService.getUserId();
      final token = await SessionService.getToken();

      final body = <String, dynamic>{
        'requestId': requestId,
      };
      if (groupId != null) body['groupId'] = groupId;
      if (userId != null) body['userId'] = userId;

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.rejectGroupInvite),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ContactService.declineGroupInvite error: $e');
      return false;
    }
  }

  static Future<bool> toggleFollow(String targetUserId, bool currentIsFollowing) async {
    final result = await toggleFollowDetailed(targetUserId, currentIsFollowing);
    return result != null && result['success'] == true;
  }

  static Future<Map<String, dynamic>?> toggleFollowDetailed(String targetUserId, bool currentIsFollowing) async {
    try {
      final userId = await SessionService.getUserId();
      final token = await SessionService.getToken();

      final url = currentIsFollowing ? ApiConfig.unfollowAccount : ApiConfig.followAccount;
      final body = <String, dynamic>{
        'targetUserId': targetUserId,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      };

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
      return null;
    } catch (e) {
      debugPrint('ContactService.toggleFollowDetailed error: $e');
      return null;
    }
  }

  static Future<bool> acceptFollowRequest(String requestId) async {
    try {
      final userId = await SessionService.getUserId();
      final token = await SessionService.getToken();

      final body = <String, dynamic>{
        'requestId': requestId,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      };

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.acceptFollowRequest),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ContactService.acceptFollowRequest error: $e');
      return false;
    }
  }

  static Future<bool> rejectFollowRequest(String requestId) async {
    try {
      final userId = await SessionService.getUserId();
      final token = await SessionService.getToken();

      final body = <String, dynamic>{
        'requestId': requestId,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      };

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.rejectFollowRequest),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ContactService.rejectFollowRequest error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> createGroup({
    required String name,
    List<String>? memberIds,
    String? description,
  }) async {
    try {
      final userId = await SessionService.getUserId();
      final token = await SessionService.getToken();

      final body = <String, dynamic>{
        'name': name,
      };
      if (memberIds != null) body['memberIds'] = memberIds;
      if (description != null) body['description'] = description;
      if (userId != null) body['userId'] = userId;

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.createGroup),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['group'] != null) {
          return decoded['group'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      debugPrint('ContactService.createGroup error: $e');
      return null;
    }
  }
}
