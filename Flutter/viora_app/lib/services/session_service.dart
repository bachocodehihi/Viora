import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'activity_tracker_service.dart';
import 'socket_service.dart';

class SessionService {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserEmail = 'user_email';
  static const String _keyToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUsername = 'user_name';
  static const String _keyAvatar = 'user_avatar';
  static const String _keyQrCode = 'user_qr_code';
  static const String _keyUserNote = 'user_status_note';
  static const String _keySavedAccounts = 'saved_accounts_list';

  static Future<void> saveSession(
    String email, {
    String? token,
    String? userId,
    String? username,
    String? avatar,
    String? qrCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUserEmail, email);
    if (token != null) await prefs.setString(_keyToken, token);
    if (userId != null) await prefs.setString(_keyUserId, userId);
    if (username != null) await prefs.setString(_keyUsername, username);
    if (avatar != null) await prefs.setString(_keyAvatar, avatar);
    if (qrCode != null) await prefs.setString(_keyQrCode, qrCode);

    await saveAccountToSavedList(
      email: email,
      userId: userId,
      username: username,
      avatar: avatar,
      token: token,
      qrCode: qrCode,
    );

    final activeId = (userId != null && userId.isNotEmpty) ? userId : email;
    unawaited(ActivityTrackerService.instance.onUserLoggedIn(activeId));
  }

  static Future<void> updateProfile({
    String? username,
    String? avatar,
    String? qrCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (username != null) await prefs.setString(_keyUsername, username);
    if (avatar != null) await prefs.setString(_keyAvatar, avatar);
    if (qrCode != null) await prefs.setString(_keyQrCode, qrCode);
  }

  static Future<void> saveQrCode(String qrCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyQrCode, qrCode);
  }

  static Future<void> clearSession({bool removeFromSaved = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_keyUserEmail);

    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyAvatar);
    await prefs.remove(_keyQrCode);
    await prefs.remove(_keyUserNote);

    if (removeFromSaved && email != null && email.isNotEmpty) {
      await removeSavedAccount(email);
    }

    SocketService.disconnect();

    await ActivityTrackerService.instance.onUserLoggedOut();
  }

  static Future<bool> validateSessionWithServer() async {
    try {
      final token = await getToken();
      final userId = await getUserId();
      final email = await getUserEmail();

      if (token == null && userId == null && email == null) {
        return false;
      }

      final body = <String, dynamic>{};
      if (userId != null && userId.isNotEmpty) body['userId'] = userId;
      if (email != null && email.isNotEmpty) body['email'] = email;

      final res = await http.post(
        Uri.parse(ApiConfig.loadProfile),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 404 || res.statusCode == 401) {

        await clearSession(removeFromSaved: true);
        return false;
      }

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == false || data['account'] == null) {
          await clearSession(removeFromSaved: true);
          return false;
        }
        return true;
      }
    } catch (e) {

      return true;
    }
    return true;
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  static Future<String?> getAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAvatar);
  }

  static Future<String?> getQrCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyQrCode);
  }

  static Future<void> saveUserNote(String note) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserNote, note);
  }

  static Future<String?> getUserNote() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserNote);
  }

  static Future<void> clearUserNote() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserNote);
  }

  static Future<void> saveAccountToSavedList({
    required String email,
    String? userId,
    String? username,
    String? avatar,
    String? token,
    String? qrCode,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keySavedAccounts);
      List<Map<String, dynamic>> list = [];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }

      final normalizedEmail = email.trim().toLowerCase();
      final existingIndex = list.indexWhere(
        (item) => (item['email'] as String? ?? '').trim().toLowerCase() == normalizedEmail,
      );

      final displayName = (username != null && username.isNotEmpty)
          ? username
          : (existingIndex != -1 ? (list[existingIndex]['name'] ?? list[existingIndex]['username']) : email.split('@').first);

      final accountData = {
        'id': userId ?? (existingIndex != -1 ? list[existingIndex]['id'] : 'acc_${DateTime.now().millisecondsSinceEpoch}'),
        'email': normalizedEmail,
        'name': displayName,
        'username': displayName,
        'avatar': avatar ?? (existingIndex != -1 ? list[existingIndex]['avatar'] : ''),
        'token': token ?? (existingIndex != -1 ? list[existingIndex]['token'] : ''),
        'qrCode': qrCode ?? (existingIndex != -1 ? list[existingIndex]['qrCode'] : ''),
        'lastActive': DateTime.now().toIso8601String(),
      };

      if (existingIndex != -1) {
        list[existingIndex] = accountData;
      } else {
        list.add(accountData);
      }

      await prefs.setString(_keySavedAccounts, jsonEncode(list));
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> getSavedAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keySavedAccounts);
      List<Map<String, dynamic>> list = [];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }

      final currentEmail = prefs.getString(_keyUserEmail);
      if (currentEmail != null && currentEmail.isNotEmpty) {
        final normalizedCurrent = currentEmail.trim().toLowerCase();
        final exists = list.any(
          (item) => (item['email'] as String? ?? '').trim().toLowerCase() == normalizedCurrent,
        );
        if (!exists) {
          final currentUsername = prefs.getString(_keyUsername) ?? currentEmail.split('@').first;
          final currentAvatar = prefs.getString(_keyAvatar) ?? '';
          final currentUserId = prefs.getString(_keyUserId) ?? '';
          final currentToken = prefs.getString(_keyToken) ?? '';

          list.insert(0, {
            'id': currentUserId,
            'email': normalizedCurrent,
            'name': currentUsername,
            'username': currentUsername,
            'avatar': currentAvatar,
            'token': currentToken,
            'lastActive': DateTime.now().toIso8601String(),
          });
          await prefs.setString(_keySavedAccounts, jsonEncode(list));
        }
      }

      return list;
    } catch (e) {
      return [];
    }
  }

  static Future<void> removeSavedAccount(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keySavedAccounts);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final normalizedEmail = email.trim().toLowerCase();
        final filtered = decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((item) => (item['email'] as String? ?? '').trim().toLowerCase() != normalizedEmail)
            .toList();
        await prefs.setString(_keySavedAccounts, jsonEncode(filtered));
      }
    } catch (_) {}
  }
}
