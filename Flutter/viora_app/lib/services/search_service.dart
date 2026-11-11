import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'session_service.dart';

class SearchService {
  static String _getHistoryStorageKey(String userId) => 'viora_search_history_$userId';

  static Future<Map<String, dynamic>> loadSearchHistory() async {
    final userId = await SessionService.getUserId() ?? await SessionService.getUserEmail();
    List<String> cachedHistory = [];

    if (userId != null && userId.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        cachedHistory = prefs.getStringList(_getHistoryStorageKey(userId)) ?? [];
      } catch (_) {}
    }

    try {
      final token = await SessionService.getToken();
      final body = <String, dynamic>{};
      if (userId != null && userId.isNotEmpty) body['userId'] = userId;

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.loadSearchHistory),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          final List<dynamic> rawHistory = data['history'] ?? [];
          final List<String> serverHistory = rawHistory.map((e) => e.toString()).toList();

          final List<dynamic> rawTrending = data['trending'] ?? [];
          final List<String> trending = rawTrending.map((e) => e.toString()).toList();

          if (userId != null && userId.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setStringList(_getHistoryStorageKey(userId), serverHistory);
          }

          return {
            'history': serverHistory,
            'trending': trending,
          };
        }
      }
    } catch (e) {
      debugPrint('SearchService.loadSearchHistory error: $e');
    }

    return {
      'history': cachedHistory,
      'trending': [
        '#VioraApp',
        'Alex Carter',
        'Travel Moments',
        'Sarah Jenkins',
        'Design System',
        'Flutter Dev',
      ],
    };
  }

  static Future<bool> deleteSearchItem(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return false;

    final userId = await SessionService.getUserId() ?? await SessionService.getUserEmail();

    if (userId != null && userId.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final list = prefs.getStringList(_getHistoryStorageKey(userId)) ?? [];
        list.remove(trimmed);
        await prefs.setStringList(_getHistoryStorageKey(userId), list);
      } catch (_) {}
    }

    try {
      final token = await SessionService.getToken();
      final body = <String, dynamic>{'query': trimmed};
      if (userId != null && userId.isNotEmpty) body['userId'] = userId;

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.deleteSearchHistory),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 6));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('SearchService.deleteSearchItem error: $e');
      return true;
    }
  }

  static Future<bool> clearSearchHistory() async {
    final userId = await SessionService.getUserId() ?? await SessionService.getUserEmail();

    if (userId != null && userId.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_getHistoryStorageKey(userId));
      } catch (_) {}
    }

    try {
      final token = await SessionService.getToken();
      final body = <String, dynamic>{};
      if (userId != null && userId.isNotEmpty) body['userId'] = userId;

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.clearSearchHistory),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 6));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('SearchService.clearSearchHistory error: $e');
      return true;
    }
  }

  static Future<Map<String, dynamic>> search(
    String query, {
    String type = 'all',
    String sort = 'latest',
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return {'users': [], 'groups': [], 'posts': []};
    }

    final userId = await SessionService.getUserId() ?? await SessionService.getUserEmail();

    if (userId != null && userId.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final list = prefs.getStringList(_getHistoryStorageKey(userId)) ?? [];
        list.remove(trimmed);
        list.insert(0, trimmed);
        if (list.length > 15) list.removeLast();
        await prefs.setStringList(_getHistoryStorageKey(userId), list);
      } catch (_) {}
    }

    try {
      final token = await SessionService.getToken();
      final body = <String, dynamic>{
        'query': trimmed,
        'type': type,
        'sort': sort,
        'saveHistory': true,
      };
      if (userId != null && userId.isNotEmpty) body['userId'] = userId;

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(
            Uri.parse(ApiConfig.search),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          return {
            'users': data['users'] ?? [],
            'groups': data['groups'] ?? [],
            'posts': data['posts'] ?? [],
          };
        }
      }
    } catch (e) {
      debugPrint('SearchService.search error: $e');
    }

    return {'users': [], 'groups': [], 'posts': []};
  }
}
