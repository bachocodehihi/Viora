import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'session_service.dart';

class ProfileService {
  static Future<bool> updateSingleField({
    required String fieldKey,
    required dynamic value,
  }) async {
    try {
      final userId = await SessionService.getUserId();
      final userEmail = await SessionService.getUserEmail();
      final token = await SessionService.getToken();

      final body = <String, dynamic>{
        fieldKey: value,
      };

      if (userId != null && userId.isNotEmpty) body['userId'] = userId;
      if (userEmail != null && userEmail.isNotEmpty) body['email'] = userEmail;

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.updateProfile),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      if (fieldKey == 'username' && value is String) {
        await SessionService.updateProfile(username: value);
      } else if (fieldKey == 'avatar' && value is String) {
        await SessionService.updateProfile(avatar: value);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['account'] != null) {
          final account = data['account'] as Map<String, dynamic>;
          await SessionService.updateProfile(
            username: account['username']?.toString(),
            avatar: account['avatar']?.toString(),
            qrCode: account['qrCode']?.toString(),
          );
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('ProfileService.updateSingleField error: $e');
      if (fieldKey == 'username' && value is String) {
        await SessionService.updateProfile(username: value);
      }
      return true;
    }
  }

  static Future<bool> updateFields(Map<String, dynamic> fields) async {
    try {
      final userId = await SessionService.getUserId();
      final userEmail = await SessionService.getUserEmail();
      final token = await SessionService.getToken();

      final body = <String, dynamic>{
        ...fields,
      };

      if (userId != null && userId.isNotEmpty) body['userId'] = userId;
      if (userEmail != null && userEmail.isNotEmpty) body['email'] = userEmail;

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.updateProfile),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('ProfileService.updateFields error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getProfile({String? email}) async {
    try {
      final cachedEmail = await SessionService.getUserEmail();
      final cachedUserId = await SessionService.getUserId();

      final userId = cachedUserId;
      final userEmail = email ?? cachedEmail;
      final token = await SessionService.getToken();

      final body = <String, dynamic>{};
      if (userId != null && userId.isNotEmpty) body['userId'] = userId;
      if (userEmail != null && userEmail.isNotEmpty) body['email'] = userEmail;

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.loadProfile),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['account'] != null) {
          final account = data['account'] as Map<String, dynamic>;
          await SessionService.updateProfile(
            username: account['username']?.toString(),
            avatar: account['avatar']?.toString(),
            qrCode: account['qrCode']?.toString(),
          );
          return account;
        }
      }

      if (response.statusCode == 404 || response.statusCode == 401) {

        await SessionService.clearSession(removeFromSaved: true);
        return null;
      }

      return null;
    } catch (e) {
      debugPrint('ProfileService.getProfile error: $e');
      final cachedAvatar = await SessionService.getAvatar();
      final cachedUsername = await SessionService.getUsername();
      if (cachedAvatar != null || cachedUsername != null) {
        return {
          'avatar': cachedAvatar,
          'username': cachedUsername,
        };
      }
      return null;
    }
  }

  static Future<bool?> togglePrivateAccount([bool? isPrivate]) async {
    try {
      final token = await SessionService.getToken();
      final userId = await SessionService.getUserId();

      final body = <String, dynamic>{
        'isPrivate': ?isPrivate,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      };

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.togglePrivateAccount),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          return data['isPrivate'] == true;
        }
      }
      return null;
    } catch (e) {
      debugPrint('ProfileService.togglePrivateAccount error: $e');
      return null;
    }
  }

  static Future<bool> updateWhoCanMessage(String whoCanMessage) async {
    try {
      final token = await SessionService.getToken();
      final userId = await SessionService.getUserId();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final body = <String, dynamic>{
        'whoCanMessage': whoCanMessage,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.updatePrivacy),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('ProfileService.updateWhoCanMessage error: $e');
      return false;
    }
  }

  static Future<bool?> updateActiveStatus(bool showActiveStatus) async {
    try {
      final token = await SessionService.getToken();
      final userId = await SessionService.getUserId();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final body = <String, dynamic>{
        'showActiveStatus': showActiveStatus,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.updatePrivacy),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return decoded['showActiveStatus'] != false;
        }
      }
      return null;
    } catch (e) {
      debugPrint('ProfileService.updateActiveStatus error: $e');
      return null;
    }
  }

  static Future<bool?> toggleTwoFactor([bool? twoFactorEnabled]) async {
    try {
      final token = await SessionService.getToken();
      final userId = await SessionService.getUserId();

      final body = <String, dynamic>{
        'twoFactorEnabled': ?twoFactorEnabled,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      };

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.toggleTwoFactor),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          return data['twoFactorEnabled'] == true;
        }
      }
      return null;
    } catch (e) {
      debugPrint('ProfileService.toggleTwoFactor error: $e');
      return null;
    }
  }

  static Future<bool> updateNote(String note) async {
    try {
      final userId = await SessionService.getUserId();
      final token = await SessionService.getToken();

      final body = <String, dynamic>{
        'note': note.trim(),
      };
      if (userId != null && userId.isNotEmpty) body['userId'] = userId;

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.updateNote),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (note.trim().isNotEmpty) {
          await SessionService.saveUserNote(note.trim());
        } else {
          await SessionService.clearUserNote();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('ProfileService.updateNote error: $e');
      if (note.trim().isNotEmpty) {
        await SessionService.saveUserNote(note.trim());
      } else {
        await SessionService.clearUserNote();
      }
      return false;
    }
  }

  static Future<Map<String, dynamic>?> scanUserQr(String qrData) async {
    try {
      final token = await SessionService.getToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final currentUserId = await SessionService.getUserId();
      final body = <String, dynamic>{'qrData': qrData};
      if (currentUserId != null && currentUserId.isNotEmpty) {
        body['myUserId'] = currentUserId;
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.scanQr),
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
      debugPrint('ProfileService.scanUserQr error: $e');
      return null;
    }
  }

  static Future<bool> blockAccount(String targetUserId) async {
    try {
      final token = await SessionService.getToken();
      final userId = await SessionService.getUserId();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final body = <String, dynamic>{
        'targetUserId': targetUserId,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.blockAccount),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('ProfileService.blockAccount error: $e');
      return false;
    }
  }

  static Future<bool> unblockAccount(String targetUserId) async {
    try {
      final token = await SessionService.getToken();
      final userId = await SessionService.getUserId();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final body = <String, dynamic>{
        'targetUserId': targetUserId,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.unblockAccount),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('ProfileService.unblockAccount error: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> loadBlockedAccounts() async {
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
            Uri.parse(ApiConfig.loadBlock),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          final list = decoded['blockedUsers'] as List? ?? [];
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('ProfileService.loadBlockedAccounts error: $e');
      return [];
    }
  }

  static Future<bool> reportAccount(String targetUserId, String reason, [String details = '']) async {
    try {
      final token = await SessionService.getToken();
      final userId = await SessionService.getUserId();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final body = <String, dynamic>{
        'targetUserId': targetUserId,
        'reason': reason,
        'details': details,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.reportAccount),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('ProfileService.reportAccount error: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getLikeHistory({int page = 1, int limit = 20}) async {
    try {
      final token = await SessionService.getToken();
      final userId = await SessionService.getUserId();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final body = <String, dynamic>{
        'page': page,
        'limit': limit,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.getLikeHistory),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          final list = decoded['likes'] as List? ?? [];
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('ProfileService.getLikeHistory error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getCommentHistory({int page = 1, int limit = 20}) async {
    try {
      final token = await SessionService.getToken();
      final userId = await SessionService.getUserId();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final body = <String, dynamic>{
        'page': page,
        'limit': limit,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.getCommentHistory),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          final list = decoded['comments'] as List? ?? [];
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('ProfileService.getCommentHistory error: $e');
      return [];
    }
  }
}
