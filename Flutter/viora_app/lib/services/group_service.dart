import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'session_service.dart';

class GroupService {
  static Future<Map<String, String>> _getHeaders() async {
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

  static Future<Map<String, dynamic>?> createGroup({
    required String name,
    String privacy = 'public',
    String? avatar,
    String? coverImage,
    String? description,
    List<String>? memberIds,
  }) async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();

      final body = <String, dynamic>{
        'name': name.trim(),
        'privacy': privacy,
        'avatar': avatar ?? '',
        'coverImage': coverImage ?? '',
        'description': description ?? '',
        'memberIds': memberIds ?? [],
      };
      if (userId != null) body['userId'] = userId;

      final res = await http.post(
        Uri.parse(ApiConfig.createGroup),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>?;
      } else {
        return jsonDecode(res.body) as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('GroupService.createGroup error: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getMyGroups() async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();

      final body = <String, dynamic>{};
      if (userId != null) body['userId'] = userId;

      final res = await http.post(
        Uri.parse(ApiConfig.getMyGroups),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true && decoded['groups'] is List) {
          return List<Map<String, dynamic>>.from(decoded['groups']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('GroupService.getMyGroups error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getDiscoverGroups() async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();

      final url = Uri.parse(ApiConfig.getDiscoverGroups).replace(
        queryParameters: userId != null ? {'userId': userId} : null,
      );

      final res = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true && decoded['groups'] is List) {
          return List<Map<String, dynamic>>.from(decoded['groups']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('GroupService.getDiscoverGroups error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> searchGroups(String query) async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();

      final params = <String, String>{'q': query.trim()};
      if (userId != null) params['userId'] = userId;

      final url = Uri.parse(ApiConfig.searchGroups).replace(queryParameters: params);
      final res = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true && decoded['groups'] is List) {
          return List<Map<String, dynamic>>.from(decoded['groups']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('GroupService.searchGroups error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getGroupDetail(String groupId) async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();

      final url = Uri.parse(ApiConfig.getGroupDetail(groupId)).replace(
        queryParameters: userId != null ? {'userId': userId} : null,
      );

      final res = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true) {
          return decoded['group'] as Map<String, dynamic>?;
        }
      } else {
        return jsonDecode(res.body) as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('GroupService.getGroupDetail error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> joinGroup(String groupId) async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();

      final body = <String, dynamic>{};
      if (userId != null) body['userId'] = userId;

      final res = await http.post(
        Uri.parse(ApiConfig.joinGroup(groupId)),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(res.body) as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('GroupService.joinGroup error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> requestJoinGroup(String groupId, {String? message}) async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();

      final body = <String, dynamic>{
        'message': message ?? 'Request to join group',
      };
      if (userId != null) body['userId'] = userId;

      final res = await http.post(
        Uri.parse(ApiConfig.requestJoinGroup(groupId)),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(res.body) as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('GroupService.requestJoinGroup error: $e');
      return null;
    }
  }

  static Future<bool> cancelJoinRequest(String groupId) async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();

      final body = <String, dynamic>{};
      if (userId != null) body['userId'] = userId;

      final res = await http.post(
        Uri.parse(ApiConfig.cancelJoinRequest(groupId)),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        return decoded['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('GroupService.cancelJoinRequest error: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getJoinRequests(String groupId) async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();

      final url = Uri.parse(ApiConfig.getJoinRequests(groupId)).replace(
        queryParameters: userId != null ? {'userId': userId} : null,
      );

      final res = await http.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true && decoded['requests'] is List) {
          return List<Map<String, dynamic>>.from(decoded['requests']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('GroupService.getJoinRequests error: $e');
      return [];
    }
  }

  static Future<bool> handleJoinRequest(
    String groupId, {
    required String targetUserId,
    required String action,
  }) async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();

      final body = <String, dynamic>{
        'targetUserId': targetUserId,
        'action': action,
      };
      if (userId != null) body['userId'] = userId;

      final res = await http.post(
        Uri.parse(ApiConfig.handleJoinRequest(groupId)),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        return decoded['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('GroupService.handleJoinRequest error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> inviteMembers(
    String groupId, {
    required List<String> userIds,
  }) async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();

      final body = <String, dynamic>{
        'userIds': userIds,
      };
      if (userId != null) body['userId'] = userId;

      final res = await http.post(
        Uri.parse(ApiConfig.inviteGroupMembers(groupId)),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(res.body) as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('GroupService.inviteMembers error: $e');
      return null;
    }
  }

  static Future<bool> respondToInvitation(
    String groupId, {
    required String action,
  }) async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();

      final body = <String, dynamic>{'action': action};
      if (userId != null) body['userId'] = userId;

      final res = await http.post(
        Uri.parse(ApiConfig.respondGroupInvite(groupId)),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        return decoded['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('GroupService.respondToInvitation error: $e');
      return false;
    }
  }

  static Future<bool> leaveGroup(String groupId) async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();

      final body = <String, dynamic>{};
      if (userId != null) body['userId'] = userId;

      final res = await http.post(
        Uri.parse(ApiConfig.leaveGroup(groupId)),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        return decoded['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('GroupService.leaveGroup error: $e');
      return false;
    }
  }
}
