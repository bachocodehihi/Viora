import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../l10n/language.dart';
import 'session_service.dart';

class MessageService {
  static String? lastErrorMessage;
  static String? lastErrorCode;
  static Future<Map<String, String>> _getHeaders() async {
    final token = await SessionService.getToken();
    final lang = LanguageManager.localeNotifier.value.languageCode;
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Accept-Language': lang,
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<List<Map<String, dynamic>>?> fetchConversations() async {
    try {
      final userId = await SessionService.getUserId();
      final body = <String, dynamic>{};
      if (userId != null && userId.isNotEmpty) body['userId'] = userId;

      final headers = await _getHeaders();

      final response = await http
          .post(
            Uri.parse(ApiConfig.getConversations),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          final list = decoded['data'];
          if (list is List) {
            return List<Map<String, dynamic>>.from(list);
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('MessageService.fetchConversations error: $e');
      return null;
    }
  }


  static Future<Map<String, dynamic>?> loadMessages({
    String? conversationId,
    String? receiverId,
    int? limit,
    String? before,
    String? beforeId,
  }) async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();

      final body = <String, dynamic>{};
      if (conversationId != null && conversationId.isNotEmpty) {
        body['conversationId'] = conversationId;
      }
      if (receiverId != null && receiverId.isNotEmpty) {
        body['receiverId'] = receiverId;
      }
      if (userId != null && userId.isNotEmpty) {
        body['userId'] = userId;
      }
      if (limit != null && limit > 0) {
        body['limit'] = limit;
      }
      if (before != null && before.isNotEmpty) {
        body['before'] = before;
      }
      if (beforeId != null && beforeId.isNotEmpty) {
        body['beforeId'] = beforeId;
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.loadMessages),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded;
        }
      }
      return null;
    } catch (e) {
      debugPrint('MessageService.loadMessages error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> sendMessage({
    required String content,
    String? conversationId,
    String? receiverId,
    String? replyToId,
    String type = 'text',
    Map<String, dynamic>? location,
    Map<String, dynamic>? poll,
    List<File>? imageFiles,
  }) async {
    try {
      final userId = await SessionService.getUserId();
      final token = await SessionService.getToken();

      if (imageFiles != null && imageFiles.isNotEmpty) {
        final request = http.MultipartRequest('POST', Uri.parse(ApiConfig.sendMessage));
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }
        request.headers['Accept'] = 'application/json';

        request.fields['content'] = content;
        request.fields['type'] = 'image';
        if (conversationId != null) request.fields['conversationId'] = conversationId;
        if (receiverId != null) request.fields['receiverId'] = receiverId;
        if (replyToId != null) request.fields['replyToId'] = replyToId;
        if (userId != null && userId.isNotEmpty) request.fields['userId'] = userId;

        for (final file in imageFiles) {
          if (await file.exists()) {
            final multipartFile = await http.MultipartFile.fromPath('images', file.path);
            request.files.add(multipartFile);
          }
        }

        final streamedResponse = await request.send().timeout(const Duration(seconds: 40));
        final response = await http.Response.fromStream(streamedResponse);

        lastErrorMessage = null;
        lastErrorCode = null;
        if (response.statusCode == 200 || response.statusCode == 201) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['success'] == true) {
            return decoded['data'] as Map<String, dynamic>?;
          }
        } else {
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map<String, dynamic>) {
              lastErrorMessage = decoded['message']?.toString();
              lastErrorCode = decoded['code']?.toString();
            }
          } catch (_) {}
        }
        return null;
      }

      final headers = await _getHeaders();

      final body = <String, dynamic>{
        'content': content,
      };
      if (conversationId != null) body['conversationId'] = conversationId;
      if (receiverId != null) body['receiverId'] = receiverId;
      if (replyToId != null) body['replyToId'] = replyToId;
      if (userId != null && userId.isNotEmpty) body['userId'] = userId;
      if (type != 'text') body['type'] = type;
      if (location != null) body['location'] = location;
      if (poll != null) body['poll'] = poll;

      lastErrorMessage = null;
      lastErrorCode = null;

      final response = await http
          .post(
            Uri.parse(ApiConfig.sendMessage),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['data'] as Map<String, dynamic>?;
        }
      } else {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            lastErrorMessage = decoded['message']?.toString();
            lastErrorCode = decoded['code']?.toString();
          }
        } catch (_) {}
      }
      return null;
    } catch (e) {
      debugPrint('MessageService.sendMessage error: $e');
      return null;
    }
  }

  static Future<bool> deleteMessage({
    required String messageId,
    bool deleteForEveryone = false,
  }) async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();

      final body = <String, dynamic>{
        'messageId': messageId,
        'deleteForEveryone': deleteForEveryone,
      };
      if (userId != null && userId.isNotEmpty) {
        body['userId'] = userId;
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.deleteMessage),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> && decoded['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('MessageService.deleteMessage error: $e');
      return false;
    }
  }

  static Future<bool> recallMessage({
    required String messageId,
  }) async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();

      final body = <String, dynamic>{
        'messageId': messageId,
      };
      if (userId != null && userId.isNotEmpty) {
        body['userId'] = userId;
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.recallMessage),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> && decoded['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('MessageService.recallMessage error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> pinMessage({
    required String messageId,
    String? conversationId,
  }) async {
    try {
      final userId = await SessionService.getUserId();
      final headers = await _getHeaders();

      final body = <String, dynamic>{
        'messageId': messageId,
      };
      if (conversationId != null) body['conversationId'] = conversationId;
      if (userId != null && userId.isNotEmpty) body['userId'] = userId;

      final response = await http
          .post(
            Uri.parse(ApiConfig.pinMessage),
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
      debugPrint('MessageService.pinMessage error: $e');
      return null;
    }
  }

  static Future<bool> unPinMessage({
    String? conversationId,
    String? messageId,
  }) async {
    try {
      final headers = await _getHeaders();

      final body = <String, dynamic>{};
      if (conversationId != null) body['conversationId'] = conversationId;
      if (messageId != null) body['messageId'] = messageId;

      final response = await http
          .post(
            Uri.parse(ApiConfig.unPinMessage),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> && decoded['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('MessageService.unPinMessage error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> reactMessage({
    required String messageId,
    required String reaction,
    String? conversationId,
  }) async {
    try {
      final headers = await _getHeaders();
      final userId = await SessionService.getUserId();
      final body = <String, dynamic>{
        'messageId': messageId,
        'reaction': reaction,
      };
      if (conversationId != null && conversationId.isNotEmpty) {
        body['conversationId'] = conversationId;
      }
      if (userId != null && userId.isNotEmpty) {
        body['userId'] = userId;
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.reactMessage),
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
      debugPrint('MessageService.reactMessage error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> stopShareLocation({
    String? messageId,
    String? conversationId,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};
      if (messageId != null) body['messageId'] = messageId;
      if (conversationId != null) body['conversationId'] = conversationId;

      final response = await http
          .post(
            Uri.parse(ApiConfig.stopShareLocation),
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
      debugPrint('MessageService.stopShareLocation error: $e');
      return null;
    }
  }

  static Future<bool> updateLiveLocation({
    String? messageId,
    String? conversationId,
    required double latitude,
    required double longitude,
    String? address,
    String? name,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
      };
      if (messageId != null) body['messageId'] = messageId;
      if (conversationId != null) body['conversationId'] = conversationId;
      if (address != null) body['address'] = address;
      if (name != null) body['name'] = name;

      final response = await http
          .post(
            Uri.parse(ApiConfig.updateLiveLocation),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> && decoded['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('MessageService.updateLiveLocation error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> votePoll({
    required String messageId,
    required String optionId,
    String? userId,
  }) async {
    try {
      final headers = await _getHeaders();
      final effectiveUserId = (userId != null && userId.isNotEmpty)
          ? userId
          : await SessionService.getUserId();
      final body = <String, dynamic>{
        'messageId': messageId,
        'optionId': optionId,
      };
      if (effectiveUserId != null && effectiveUserId.isNotEmpty) {
        body['userId'] = effectiveUserId;
      }
      final response = await http
          .post(
            Uri.parse(ApiConfig.votePoll),
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
      debugPrint('MessageService.votePoll error: $e');
      return null;
    }
  }
}
