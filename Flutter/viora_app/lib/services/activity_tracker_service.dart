import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'session_service.dart';

class DailyActivity {
  final String date;
  int totalSeconds;
  List<int> hourlySeconds;

  DailyActivity({
    required this.date,
    this.totalSeconds = 0,
    List<int>? hourlySeconds,
  }) : hourlySeconds = hourlySeconds ?? List<int>.filled(24, 0);

  double get totalHours => totalSeconds / 3600.0;

  Map<String, dynamic> toJson() => {
    'date': date,
    'totalSeconds': totalSeconds,
    'hourlySeconds': hourlySeconds,
  };

  factory DailyActivity.fromJson(Map<String, dynamic> json) {
    List<int> parsedHourly = List<int>.filled(24, 0);
    if (json['hourlySeconds'] is List) {
      final list = json['hourlySeconds'] as List;
      for (int i = 0; i < 24 && i < list.length; i++) {
        parsedHourly[i] = (list[i] as num?)?.toInt() ?? 0;
      }
    }
    return DailyActivity(
      date: json['date']?.toString() ?? '',
      totalSeconds: (json['totalSeconds'] as num?)?.toInt() ?? 0,
      hourlySeconds: parsedHourly,
    );
  }

  DailyActivity copy() {
    return DailyActivity(
      date: date,
      totalSeconds: totalSeconds,
      hourlySeconds: List<int>.from(hourlySeconds),
    );
  }
}

class ActivityTrackerService with WidgetsBindingObserver {
  static final ActivityTrackerService instance = ActivityTrackerService._internal();

  ActivityTrackerService._internal();

  String? _currentUserId;
  bool _isForeground = true;
  Timer? _tickerTimer;
  Timer? _flushTimer;

  final ValueNotifier<int> currentSessionSecondsNotifier = ValueNotifier<int>(0);

  DailyActivity? _cachedTodayActivity;
  String _cachedDateKey = '';

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _getStorageKey(String userId, String dateKey) {
    return 'viora_activity_${userId}_$dateKey';
  }

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    await _checkAndSyncActiveUser();

    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), _onSecondTick);

    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(seconds: 15), (_) => flush());
  }

  Future<void> _checkAndSyncActiveUser() async {
    final loggedIn = await SessionService.isLoggedIn();
    if (!loggedIn) {
      if (_currentUserId != null) {
        await flush();
      }
      _currentUserId = null;
      _cachedTodayActivity = null;
      return;
    }

    final userId = await SessionService.getUserId() ?? await SessionService.getUserEmail();
    if (userId != null && userId.isNotEmpty) {
      if (_currentUserId != userId) {
        if (_currentUserId != null) {
          await flush();
        }
        _currentUserId = userId;
        await _loadTodayActivity();
      }
    } else {
      _currentUserId = null;
      _cachedTodayActivity = null;
    }
  }

  Future<void> onUserLoggedIn(String userId) async {
    if (_currentUserId == userId && _cachedTodayActivity != null) return;
    if (_currentUserId != null && _currentUserId != userId) {
      await flush();
    }
    _currentUserId = userId;
    await _loadTodayActivity();
  }

  Future<void> onUserLoggedOut() async {
    await flush();
    _currentUserId = null;
    _cachedTodayActivity = null;
    currentSessionSecondsNotifier.value = 0;
  }

  String? get currentUserId => _currentUserId;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _isForeground = true;
        unawaited(_checkAndSyncActiveUser());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _isForeground = false;
        flush();
        break;
    }
  }

  void _onSecondTick(Timer timer) {
    if (!_isForeground) return;
    if (_currentUserId == null || _currentUserId!.isEmpty) return;

    final todayStr = _formatDate(DateTime.now());
    if (_cachedTodayActivity == null || _cachedDateKey != todayStr) {
      _cachedDateKey = todayStr;
      _cachedTodayActivity = DailyActivity(date: todayStr);
      unawaited(_loadTodayActivity());
      return;
    }

    final activity = _cachedTodayActivity!;
    activity.totalSeconds += 1;

    final hour = DateTime.now().hour;
    if (hour >= 0 && hour < 24) {
      activity.hourlySeconds[hour] += 1;
    }

    currentSessionSecondsNotifier.value = activity.totalSeconds;
  }

  Future<void> _loadTodayActivity() async {
    if (_currentUserId == null) return;
    final todayStr = _formatDate(DateTime.now());
    _cachedDateKey = todayStr;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(_currentUserId!, todayStr);
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> json = jsonDecode(raw);
        _cachedTodayActivity = DailyActivity.fromJson(json);
      } else {
        _cachedTodayActivity = DailyActivity(date: todayStr);
      }
      currentSessionSecondsNotifier.value = _cachedTodayActivity!.totalSeconds;
    } catch (e) {
      debugPrint('Error loading today activity: $e');
      _cachedTodayActivity ??= DailyActivity(date: todayStr);
    }
  }

  Future<void> flush() async {
    final userId = _currentUserId;
    final activity = _cachedTodayActivity;
    if (userId == null || activity == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(userId, activity.date);
      final jsonStr = jsonEncode(activity.toJson());
      await prefs.setString(key, jsonStr);

      final datesKey = 'viora_activity_dates_$userId';
      final datesList = prefs.getStringList(datesKey) ?? [];
      if (!datesList.contains(activity.date)) {
        datesList.add(activity.date);
        await prefs.setStringList(datesKey, datesList);
      }

      _syncToBackend(userId, activity);
    } catch (e) {
      debugPrint('Error flushing activity data: $e');
    }
  }

  void _syncToBackend(String userId, DailyActivity activity) async {
    try {
      final token = await SessionService.getToken();
      await http.post(
        Uri.parse(ApiConfig.recordActivity),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'userId': userId,
          'date': activity.date,
          'totalSeconds': activity.totalSeconds,
          'hourlySeconds': activity.hourlySeconds,
        }),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {

    }
  }

  Future<DailyActivity> getDayActivity(String userId, DateTime date) async {
    final dateStr = _formatDate(date);

    if (userId == _currentUserId && dateStr == _cachedDateKey && _cachedTodayActivity != null) {
      return _cachedTodayActivity!.copy();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(userId, dateStr);
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        return DailyActivity.fromJson(jsonDecode(raw));
      }
    } catch (e) {
      debugPrint('Error getting day activity: $e');
    }
    return DailyActivity(date: dateStr);
  }

  Future<List<DailyActivity>> getWeekActivity(String userId, DateTime startOfWeek) async {
    final List<DailyActivity> week = [];
    for (int i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      final act = await getDayActivity(userId, day);
      week.add(act);
    }
    return week;
  }

  Future<List<DailyActivity>> getMonthActivity(String userId, int year, int month) async {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final List<DailyActivity> monthActivities = [];
    for (int d = 1; d <= daysInMonth; d++) {
      final day = DateTime(year, month, d);
      final act = await getDayActivity(userId, day);
      monthActivities.add(act);
    }
    return monthActivities;
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tickerTimer?.cancel();
    _flushTimer?.cancel();
  }
}
