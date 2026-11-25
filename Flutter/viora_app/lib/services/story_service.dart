import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/story_model.dart';
import 'session_service.dart';

class StoryService {
  static Future<List<UserStoryGroup>> getStoriesFeed() async {
    try {
      final token = await SessionService.getToken();
      final userId = await SessionService.getUserId();

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = <String, dynamic>{
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.getStoriesFeed),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['feed'] is List) {
          final feedRaw = data['feed'] as List;
          return feedRaw
              .whereType<Map>()
              .map((m) => UserStoryGroup.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('StoryService.getStoriesFeed error: $e');
      return [];
    }
  }

  static Future<bool> createStory({
    File? mediaFile,
    String? content,
    String mediaType = 'image',
    String backgroundColor = '#1A1A24',
    String privacy = 'friends',
  }) async {
    try {
      final token = await SessionService.getToken();
      final userId = await SessionService.getUserId();

      final uri = Uri.parse(ApiConfig.createStory);

      if (mediaFile != null && await mediaFile.exists()) {
        final request = http.MultipartRequest('POST', uri);
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }
        if (userId != null && userId.isNotEmpty) {
          request.fields['userId'] = userId;
        }
        if (content != null && content.isNotEmpty) {
          request.fields['content'] = content;
        }
        request.fields['mediaType'] = mediaType;
        request.fields['backgroundColor'] = backgroundColor;
        request.fields['privacy'] = privacy;

        final multipartFile = await http.MultipartFile.fromPath('media', mediaFile.path);
        request.files.add(multipartFile);

        final streamed = await request.send().timeout(const Duration(seconds: 30));
        final response = await http.Response.fromStream(streamed);
        return response.statusCode == 200 || response.statusCode == 201;
      } else {
        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        };

        final body = {
          if (userId != null && userId.isNotEmpty) 'userId': userId,
          if (content != null && content.isNotEmpty) 'content': content,
          'mediaType': 'text',
          'backgroundColor': backgroundColor,
          'privacy': privacy,
        };

        final response = await http
            .post(uri, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 15));

        return response.statusCode == 200 || response.statusCode == 201;
      }
    } catch (e) {
      debugPrint('StoryService.createStory error: $e');
      return false;
    }
  }

  static Future<bool> viewStory(String storyId) async {
    try {
      final token = await SessionService.getToken();
      final userId = await SessionService.getUserId();

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = {
        'storyId': storyId,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      };

      final response = await http
          .post(
            Uri.parse('${ApiConfig.viewStory}/$storyId'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('StoryService.viewStory error: $e');
      return false;
    }
  }

  static Future<bool> deleteStory(String storyId) async {
    try {
      final token = await SessionService.getToken();
      final userId = await SessionService.getUserId();

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = {
        'storyId': storyId,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      };

      final response = await http
          .post(
            Uri.parse('${ApiConfig.deleteStory}/$storyId'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('StoryService.deleteStory error: $e');
      return false;
    }
  }

  static Future<bool> reactStory(String storyId, String reaction) async {
    try {
      final token = await SessionService.getToken();
      final userId = await SessionService.getUserId();

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = {
        'storyId': storyId,
        'reaction': reaction,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.reactStory),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('StoryService.reactStory error: $e');
      return false;
    }
  }
}
