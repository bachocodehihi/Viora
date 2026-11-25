import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'session_service.dart';

class LivestreamService {

  static Future<Map<String, dynamic>?> createLive({
    required String title,
    required String mode,
    String? thumbnail,
    String privacy = 'public',
    String? groupId,
    List<String>? allowedViewers,
  }) async {
    try {
      final token = await SessionService.getToken();
      final myUserId = await SessionService.getUserId();

      final uri = Uri.parse(ApiConfig.createLive);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = <String, dynamic>{
        'title': title,
        'mode': mode,
        'privacy': privacy,
        if (thumbnail != null) 'thumbnail': thumbnail,
        if (myUserId != null) 'userId': myUserId,
        if (groupId != null) 'groupId': groupId,
        if (allowedViewers != null && allowedViewers.isNotEmpty) 'allowedViewers': allowedViewers,
      };

      final response = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded;
        }
      }
      return null;
    } catch (e) {
      debugPrint('LivestreamService.createLive error: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getActiveLives() async {
    try {
      final token = await SessionService.getToken();
      final uri = Uri.parse(ApiConfig.getActiveLives);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          final list = decoded['lives'];
          if (list is List) {
            return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        }
      }
      return [];
    } catch (e) {
      debugPrint('LivestreamService.getActiveLives error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getLiveDetail(String id) async {
    try {
      final token = await SessionService.getToken();

      final uri = Uri.parse(ApiConfig.getLiveDetail(id));
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 403) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
      return null;
    } catch (e) {
      debugPrint('LivestreamService.getLiveDetail error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> endLive(
    String id, {
    bool saveAsPost = false,
    String? caption,
    String? privacy,
  }) async {
    try {
      final token = await SessionService.getToken();
      final myUserId = await SessionService.getUserId();

      final uri = Uri.parse(ApiConfig.endLive(id));
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = <String, dynamic>{
        'saveAsPost': saveAsPost,
        'caption': ?caption,
        'privacy': ?privacy,
        'userId': ?myUserId,
      };

      final response = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded;
        }
      }
      return null;
    } catch (e) {
      debugPrint('LivestreamService.endLive error: $e');
      return null;
    }
  }
}
