import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'session_service.dart';

class PostPublishResult {
  final bool success;
  final String message;
  final String? code;
  final Map<String, dynamic>? post;

  PostPublishResult({
    required this.success,
    required this.message,
    this.code,
    this.post,
  });
}

class PostService {
  static Future<PostPublishResult> publishPost({
    required String content,
    String privacy = 'public',
    List<File>? imageFiles,
    String? groupId,
    bool isAnonymous = false,
    String? email,
    String? userName,
    List<String>? allowedFriends,
    List<String>? exceptedFriends,
  }) async {
    try {
      final token = await SessionService.getToken();
      final myUserId = await SessionService.getUserId();
      final userEmail = (email != null && email.isNotEmpty)
          ? email
          : await SessionService.getUserEmail();
      final username = (userName != null && userName.isNotEmpty)
          ? userName
          : await SessionService.getUsername();

      final uri = Uri.parse(ApiConfig.publishPost);

      if (imageFiles != null && imageFiles.isNotEmpty) {
        final request = http.MultipartRequest('POST', uri);

        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }
        request.headers['Accept'] = 'application/json';

        request.fields['content'] = content;
        request.fields['privacy'] = privacy;
        if (isAnonymous) {
          request.fields['isAnonymous'] = 'true';
        }

        if (myUserId != null && myUserId.isNotEmpty) {
          request.fields['userId'] = myUserId;
          request.fields['myUserId'] = myUserId;
        }
        if (userEmail != null && userEmail.isNotEmpty) {
          request.fields['email'] = userEmail;
          request.fields['userEmail'] = userEmail;
        }
        if (username != null && username.isNotEmpty) {
          request.fields['username'] = username;
          request.fields['userName'] = username;
        }
        if (groupId != null && groupId.isNotEmpty) {
          request.fields['group'] = groupId;
        }
        if (allowedFriends != null && allowedFriends.isNotEmpty) {
          request.fields['allowedFriends'] = jsonEncode(allowedFriends);
        }
        if (exceptedFriends != null && exceptedFriends.isNotEmpty) {
          request.fields['exceptedFriends'] = jsonEncode(exceptedFriends);
        }

        for (final file in imageFiles) {
          if (await file.exists()) {
            final multipartFile = await http.MultipartFile.fromPath(
              'images',
              file.path,
            );
            request.files.add(multipartFile);
          }
        }

        final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
        final response = await http.Response.fromStream(streamedResponse);

        Map<String, dynamic>? decoded;
        try {
          decoded = jsonDecode(response.body);
        } catch (_) {}

        if (response.statusCode == 200 || response.statusCode == 201) {
          if (decoded != null && decoded['success'] == true) {
            return PostPublishResult(
              success: true,
              message: decoded['message']?.toString() ?? 'Post published successfully',
              code: decoded['code']?.toString(),
              post: decoded['post'] as Map<String, dynamic>?,
            );
          }
        }

        final errorMsg = decoded?['message']?.toString() ??
            'Post publishing failed (${response.statusCode})';
        return PostPublishResult(
          success: false,
          message: errorMsg,
          code: decoded?['code']?.toString(),
        );
      } else {
        final headers = <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        };

        final body = <String, dynamic>{
          'content': content,
          'privacy': privacy,
          if (myUserId != null && myUserId.isNotEmpty) ...{
            'userId': myUserId,
            'myUserId': myUserId,
          },
          if (userEmail != null && userEmail.isNotEmpty) ...{
            'email': userEmail,
            'userEmail': userEmail,
          },
          if (username != null && username.isNotEmpty) ...{
            'username': username,
            'userName': username,
          },
          if (groupId != null && groupId.isNotEmpty) 'group': groupId,
          if (isAnonymous) 'isAnonymous': true,
          if (allowedFriends != null && allowedFriends.isNotEmpty) 'allowedFriends': allowedFriends,
          if (exceptedFriends != null && exceptedFriends.isNotEmpty) 'exceptedFriends': exceptedFriends,
        };

        final response = await http
            .post(
              uri,
              headers: headers,
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 20));

        Map<String, dynamic>? decoded;
        try {
          decoded = jsonDecode(response.body);
        } catch (_) {}

        if (response.statusCode == 200 || response.statusCode == 201) {
          if (decoded != null && decoded['success'] == true) {
            return PostPublishResult(
              success: true,
              message: decoded['message']?.toString() ?? 'Post published successfully',
              code: decoded['code']?.toString(),
              post: decoded['post'] as Map<String, dynamic>?,
            );
          }
        }

        final errorMsg = decoded?['message']?.toString() ??
            'Post publishing failed (${response.statusCode})';
        return PostPublishResult(
          success: false,
          message: errorMsg,
          code: decoded?['code']?.toString(),
        );
      }
    } catch (e) {
      debugPrint('PostService.publishPost error: $e');
      return PostPublishResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  static Future<List<Map<String, dynamic>>> getFeed({
    int page = 1,
    int limit = 20,
    String? email,
  }) async {
    try {
      final token = await SessionService.getToken();
      final myUserId = await SessionService.getUserId();
      final userEmail = (email != null && email.isNotEmpty)
          ? email
          : await SessionService.getUserEmail();

      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (myUserId != null && myUserId.isNotEmpty) 'userId': myUserId,
        if (userEmail != null && userEmail.isNotEmpty) 'email': userEmail,
      };

      final uri = Uri.parse(ApiConfig.getFeed).replace(queryParameters: queryParams);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true && decoded['posts'] is List) {
          return List<Map<String, dynamic>>.from(decoded['posts']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('PostService.getFeed error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getUserPosts({
    String? userId,
    String? email,
  }) async {
    try {
      final token = await SessionService.getToken();
      final myUserId = (userId != null && userId.isNotEmpty) ? userId : await SessionService.getUserId();
      final userEmail = (email != null && email.isNotEmpty) ? email : await SessionService.getUserEmail();

      final queryParams = <String, String>{
        if (myUserId != null && myUserId.isNotEmpty) 'userId': myUserId,
        if (userEmail != null && userEmail.isNotEmpty) 'email': userEmail,
      };

      final uri = Uri.parse(ApiConfig.getUserPosts).replace(queryParameters: queryParams);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true && decoded['posts'] is List) {
          return List<Map<String, dynamic>>.from(decoded['posts']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('PostService.getUserPosts error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getComments(String postId) async {
    try {
      final token = await SessionService.getToken();
      final myUserId = await SessionService.getUserId();
      final userEmail = await SessionService.getUserEmail();

      final uri = Uri.parse(
        '${ApiConfig.getComments}?postId=$postId'
        '${myUserId != null ? '&userId=$myUserId' : ''}'
        '${userEmail != null ? '&email=${Uri.encodeComponent(userEmail)}' : ''}',
      );
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true && decoded['comments'] is List) {
          return List<Map<String, dynamic>>.from(decoded['comments']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('PostService.getComments error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getCommentsWithDetails(String postId) async {
    try {
      final token = await SessionService.getToken();
      final myUserId = await SessionService.getUserId();
      final userEmail = await SessionService.getUserEmail();

      final uri = Uri.parse(
        '${ApiConfig.getComments}?postId=$postId'
        '${myUserId != null ? '&userId=$myUserId' : ''}'
        '${userEmail != null ? '&email=${Uri.encodeComponent(userEmail)}' : ''}',
      );
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded;
        }
      }
      return null;
    } catch (e) {
      debugPrint('PostService.getCommentsWithDetails error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> commentPost({
    required String postId,
    required String content,
    String? parentCommentId,
    String? parentComment,
    String? email,
    String? userName,
    bool isAnonymous = false,
  }) async {
    try {
      final token = await SessionService.getToken();
      final myUserId = await SessionService.getUserId();
      final userEmail = (email != null && email.isNotEmpty) ? email : await SessionService.getUserEmail();
      final username = (userName != null && userName.isNotEmpty) ? userName : await SessionService.getUsername();
      final pId = parentCommentId ?? parentComment;

      final uri = Uri.parse(ApiConfig.commentPost);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = <String, dynamic>{
        'postId': postId,
        'content': content,
        if (isAnonymous) 'isAnonymous': true,
        if (pId != null && pId.isNotEmpty) ...{
          'parentComment': pId,
        },
        if (myUserId != null && myUserId.isNotEmpty) ...{
          'userId': myUserId,
        },
        if (userEmail != null && userEmail.isNotEmpty) ...{
          'email': userEmail,
        },
        if (username != null && username.isNotEmpty) ...{
          'username': username,
        },
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
      debugPrint('PostService.commentPost error: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getGroupPosts(String groupId) async {
    try {
      final token = await SessionService.getToken();
      final myUserId = await SessionService.getUserId();
      final userEmail = await SessionService.getUserEmail();

      final uri = Uri.parse(
        '${ApiConfig.getGroupPosts}?groupId=$groupId'
        '${myUserId != null ? '&userId=$myUserId' : ''}'
        '${userEmail != null ? '&email=${Uri.encodeComponent(userEmail)}' : ''}',
      );
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true && decoded['posts'] is List) {
          return List<Map<String, dynamic>>.from(decoded['posts']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('PostService.getGroupPosts error: $e');
      return [];
    }
  }

  static Future<bool> likeComment(String commentId) async {
    try {
      final token = await SessionService.getToken();
      final myUserId = await SessionService.getUserId();
      final userEmail = await SessionService.getUserEmail();

      final uri = Uri.parse(ApiConfig.likeComment);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = <String, dynamic>{
        'commentId': commentId,
        if (myUserId != null && myUserId.isNotEmpty) 'userId': myUserId,
        if (userEmail != null && userEmail.isNotEmpty) 'email': userEmail,
      };

      final response = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> && decoded['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('PostService.likeComment error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> likePost(String postId, {String? reaction}) async {
    try {
      final token = await SessionService.getToken();
      final myUserId = await SessionService.getUserId();
      final userEmail = await SessionService.getUserEmail();

      final uri = Uri.parse(ApiConfig.likePost);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = <String, dynamic>{
        'postId': postId,
        if (reaction != null && reaction.isNotEmpty) 'reaction': reaction,
        if (myUserId != null && myUserId.isNotEmpty) 'userId': myUserId,
        if (userEmail != null && userEmail.isNotEmpty) 'email': userEmail,
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
      debugPrint('PostService.likePost error: $e');
      return null;
    }
  }

  static Future<bool> deletePost(String postId) async {
    try {
      final token = await SessionService.getToken();
      final myUserId = await SessionService.getUserId();

      final uri = Uri.parse(ApiConfig.deletePost);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = <String, dynamic>{
        'postId': postId,
        if (myUserId != null && myUserId.isNotEmpty) 'userId': myUserId,
      };

      final response = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> && decoded['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('PostService.deletePost error: $e');
      return false;
    }
  }

  static Future<bool> reportPost({
    required String postId,
    required String reason,
    String? details,
  }) async {
    try {
      final token = await SessionService.getToken();
      final myUserId = await SessionService.getUserId();

      final uri = Uri.parse(ApiConfig.reportPost);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = <String, dynamic>{
        'postId': postId,
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
        if (myUserId != null && myUserId.isNotEmpty) 'userId': myUserId,
      };

      final response = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> && decoded['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('PostService.reportPost error: $e');
      return false;
    }
  }

  static Future<bool> notInterestedPost(String postId) async {
    try {
      final token = await SessionService.getToken();
      final myUserId = await SessionService.getUserId();

      final uri = Uri.parse(ApiConfig.notInterestedPost);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = <String, dynamic>{
        'postId': postId,
        if (myUserId != null && myUserId.isNotEmpty) 'userId': myUserId,
      };

      final response = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> && decoded['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('PostService.notInterestedPost error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> toggleComments(String postId, {bool? commentsDisabled}) async {
    try {
      final token = await SessionService.getToken();
      final myUserId = await SessionService.getUserId();

      final uri = Uri.parse(ApiConfig.toggleComments);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = <String, dynamic>{
        'postId': postId,
        'commentsDisabled': ?commentsDisabled,
        if (myUserId != null && myUserId.isNotEmpty) 'userId': myUserId,
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
      debugPrint('PostService.toggleComments error: $e');
      return null;
    }
  }

  static Future<bool> updateCommentSettings({
    required String postId,
    bool? commentsDisabled,
    String? commentPermission,
    List<String>? allowedCommenters,
    List<String>? blockedCommenters,
  }) async {
    try {
      final token = await SessionService.getToken();
      final myUserId = await SessionService.getUserId();

      final uri = Uri.parse(ApiConfig.commentSettings);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = <String, dynamic>{
        'postId': postId,
        'commentsDisabled': ?commentsDisabled,
        'commentPermission': ?commentPermission,
        'allowedCommenters': ?allowedCommenters,
        'blockedCommenters': ?blockedCommenters,
        if (myUserId != null && myUserId.isNotEmpty) 'userId': myUserId,
      };

      final response = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> && decoded['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('PostService.updateCommentSettings error: $e');
      return false;
    }
  }

  static Future<bool> blockCommenter({
    required String postId,
    required String targetUserId,
  }) async {
    try {
      final token = await SessionService.getToken();
      final myUserId = await SessionService.getUserId();

      final uri = Uri.parse(ApiConfig.blockCommenter);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = <String, dynamic>{
        'postId': postId,
        'targetUserId': targetUserId,
        if (myUserId != null && myUserId.isNotEmpty) 'userId': myUserId,
      };

      final response = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> && decoded['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('PostService.blockCommenter error: $e');
      return false;
    }
  }

  static Future<bool> unblockCommenter({
    required String postId,
    required String targetUserId,
  }) async {
    try {
      final token = await SessionService.getToken();
      final myUserId = await SessionService.getUserId();

      final uri = Uri.parse(ApiConfig.unblockCommenter);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = <String, dynamic>{
        'postId': postId,
        'targetUserId': targetUserId,
        if (myUserId != null && myUserId.isNotEmpty) 'userId': myUserId,
      };

      final response = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> && decoded['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('PostService.unblockCommenter error: $e');
      return false;
    }
  }

  static Future<bool> deleteComment(String commentId) async {
    try {
      final token = await SessionService.getToken();
      final myUserId = await SessionService.getUserId();

      final uri = Uri.parse(ApiConfig.deleteComment);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = <String, dynamic>{
        'commentId': commentId,
        if (myUserId != null && myUserId.isNotEmpty) 'userId': myUserId,
      };

      final response = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> && decoded['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('PostService.deleteComment error: $e');
      return false;
    }
  }
}
