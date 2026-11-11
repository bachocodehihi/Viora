import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../services/activity_tracker_service.dart';
import '../../services/session_service.dart';

enum ActivityViewMode { day, week, month }

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final GlobalKey _dropdownKey = GlobalKey();
  ActivityViewMode _viewMode = ActivityViewMode.week;
  int _periodOffset = 0;
  int _selectedBarIndex = 0;

  String? _userId;
  bool _isLoading = true;

  DailyActivity? _currentDayActivity;
  DailyActivity? _prevDayActivity;

  List<DailyActivity> _currentPeriodActivities = [];
  List<DailyActivity> _prevPeriodActivities = [];

  Timer? _liveRefreshDebounce;

  @override
  void initState() {
    super.initState();
    _resetDefaultSelectedIndex();
    _initData();
    ActivityTrackerService.instance.currentSessionSecondsNotifier.addListener(_onLiveTick);
  }

  @override
  void dispose() {
    _liveRefreshDebounce?.cancel();
    ActivityTrackerService.instance.currentSessionSecondsNotifier.removeListener(_onLiveTick);
    super.dispose();
  }

  void _onLiveTick() {
    if (!mounted) return;

    if (_periodOffset == 0) {
      if (_liveRefreshDebounce?.isActive ?? false) return;
      _liveRefreshDebounce = Timer(const Duration(seconds: 2), () {
        if (mounted && _periodOffset == 0) {
          _loadPeriodData(silent: true);
        }
      });
    }
  }

  Future<void> _initData() async {
    _userId = await SessionService.getUserId() ?? await SessionService.getUserEmail();
    await _loadPeriodData();
  }

  Future<void> _loadPeriodData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final now = DateTime.now();

    if (_viewMode == ActivityViewMode.day) {
      final targetDate = DateTime(now.year, now.month, now.day).add(Duration(days: _periodOffset));
      final prevDate = targetDate.subtract(const Duration(days: 1));

      final cur = await ActivityTrackerService.instance.getDayActivity(userId, targetDate);
      final prev = await ActivityTrackerService.instance.getDayActivity(userId, prevDate);

      if (mounted) {
        setState(() {
          _currentDayActivity = cur;
          _prevDayActivity = prev;
          _isLoading = false;
        });
      }
    } else if (_viewMode == ActivityViewMode.week) {
      final todayMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      final weekStart = todayMonday.add(Duration(days: _periodOffset * 7));
      final prevWeekStart = weekStart.subtract(const Duration(days: 7));

      final cur = await ActivityTrackerService.instance.getWeekActivity(userId, weekStart);
      final prev = await ActivityTrackerService.instance.getWeekActivity(userId, prevWeekStart);

      if (mounted) {
        setState(() {
          _currentPeriodActivities = cur;
          _prevPeriodActivities = prev;
          _isLoading = false;
        });
      }
    } else {
      int targetYear = now.year;
      int targetMonth = now.month + _periodOffset;
      while (targetMonth < 1) {
        targetMonth += 12;
        targetYear -= 1;
      }
      while (targetMonth > 12) {
        targetMonth -= 12;
        targetYear += 1;
      }

      int prevYear = targetYear;
      int prevMonth = targetMonth - 1;
      if (prevMonth < 1) {
        prevMonth = 12;
        prevYear -= 1;
      }

      final cur = await ActivityTrackerService.instance.getMonthActivity(userId, targetYear, targetMonth);
      final prev = await ActivityTrackerService.instance.getMonthActivity(userId, prevYear, prevMonth);

      if (mounted) {
        setState(() {
          _currentPeriodActivities = cur;
          _prevPeriodActivities = prev;
          _isLoading = false;
        });
      }
    }
  }

  void _resetDefaultSelectedIndex() {
    final now = DateTime.now();
    setState(() {
      if (_viewMode == ActivityViewMode.day) {
        _selectedBarIndex = _periodOffset == 0 ? (now.hour ~/ 4).clamp(0, 5) : 3;
      } else if (_viewMode == ActivityViewMode.week) {
        _selectedBarIndex = _periodOffset == 0 ? (now.weekday - 1).clamp(0, 6) : 3;
      } else {
        _selectedBarIndex = _periodOffset == 0 ? ((now.day - 1) ~/ 7).clamp(0, 4) : 0;
      }
    });
  }

  void _changeViewMode(ActivityViewMode newMode) {
    if (_viewMode == newMode) return;
    setState(() {
      _viewMode = newMode;
      _periodOffset = 0;
      _resetDefaultSelectedIndex();
    });
    _loadPeriodData();
  }

  void _navigatePeriod(int delta) {
    setState(() {
      _periodOffset += delta;
      if (_periodOffset > 0) _periodOffset = 0;
      _resetDefaultSelectedIndex();
    });
    _loadPeriodData();
  }

  String _monthName(int month, Language l10n) {
    if (LanguageManager.isEnglish()) {
      const en = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return en[(month - 1).clamp(0, 11)];
    } else {
      return 'Th${month.toString().padLeft(2, '0')}';
    }
  }

  String _getPeriodTitle(Language l10n) {
    final now = DateTime.now();
    final isEn = LanguageManager.isEnglish();

    if (_viewMode == ActivityViewMode.day) {
      final target = now.add(Duration(days: _periodOffset));
      final dayStr = target.day.toString().padLeft(2, '0');
      final monthStr = _monthName(target.month, l10n);

      if (_periodOffset == 0) {
        return isEn ? '${l10n.today}, $monthStr $dayStr' : '${l10n.today}, $dayStr $monthStr';
      }
      if (_periodOffset == -1) {
        return isEn ? '${l10n.yesterday}, $monthStr $dayStr' : '${l10n.yesterday}, $dayStr $monthStr';
      }
      return isEn ? '$monthStr $dayStr, ${target.year}' : '$dayStr $monthStr, ${target.year}';
    } else if (_viewMode == ActivityViewMode.week) {
      final todayMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      final weekStart = todayMonday.add(Duration(days: _periodOffset * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));

      final startDay = weekStart.day.toString().padLeft(2, '0');
      final endDay = weekEnd.day.toString().padLeft(2, '0');
      final monthStr = _monthName(weekEnd.month, l10n);

      if (_periodOffset == 0) {
        return '${l10n.thisWeek} ($startDay - $endDay $monthStr)';
      }
      if (_periodOffset == -1) {
        return '${l10n.lastWeek} ($startDay - $endDay $monthStr)';
      }
      return '${-_periodOffset} ${l10n.weeksAgo} ($startDay - $endDay $monthStr)';
    } else {
      int targetYear = now.year;
      int targetMonth = now.month + _periodOffset;
      while (targetMonth < 1) {
        targetMonth += 12;
        targetYear -= 1;
      }
      while (targetMonth > 12) {
        targetMonth -= 12;
        targetYear += 1;
      }

      final formattedMonth = l10n.formatMonthYear(targetMonth, targetYear);
      if (_periodOffset == 0) {
        return '${l10n.thisMonth} ($formattedMonth)';
      }
      if (_periodOffset == -1) {
        return '${l10n.lastMonth} ($formattedMonth)';
      }
      return formattedMonth;
    }
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0m';
    int h = totalSeconds ~/ 3600;
    int m = (totalSeconds % 3600) ~/ 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  List<Map<String, dynamic>> _getChartItems() {
    final now = DateTime.now();

    if (_viewMode == ActivityViewMode.day) {
      final act = _currentDayActivity ?? DailyActivity(date: '');
      final hourly = act.hourlySeconds;

      final buckets = [
        {'label': '00-04h', 'start': 0, 'end': 3},
        {'label': '04-08h', 'start': 4, 'end': 7},
        {'label': '08-12h', 'start': 8, 'end': 11},
        {'label': '12-16h', 'start': 12, 'end': 15},
        {'label': '16-20h', 'start': 16, 'end': 19},
        {'label': '20-24h', 'start': 20, 'end': 23},
      ];

      final currentBucketIdx = now.hour ~/ 4;

      return List.generate(buckets.length, (i) {
        final b = buckets[i];
        int sec = 0;
        for (int h = (b['start'] as int); h <= (b['end'] as int); h++) {
          if (h < hourly.length) sec += hourly[h];
        }
        final double hours = sec / 3600.0;
        final bool isToday = _periodOffset == 0 && (i == currentBucketIdx);

        return {
          'label': b['label'],
          'hours': hours,
          'seconds': sec,
          'detail': _formatDuration(sec),
          'isToday': isToday,
        };
      });
    } else if (_viewMode == ActivityViewMode.week) {
      final daysVi = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
      final daysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final todayWeekdayIdx = now.weekday - 1;

      return List.generate(7, (i) {
        DailyActivity? act;
        if (i < _currentPeriodActivities.length) {
          act = _currentPeriodActivities[i];
        }
        final sec = act?.totalSeconds ?? 0;
        final double hours = sec / 3600.0;
        final bool isToday = _periodOffset == 0 && (i == todayWeekdayIdx);

        return {
          'labelEn': daysEn[i],
          'labelVi': daysVi[i],
          'hours': hours,
          'seconds': sec,
          'detail': _formatDuration(sec),
          'isToday': isToday,
        };
      });
    } else {

      final totalDays = _currentPeriodActivities.length;
      final weekChunks = <Map<String, dynamic>>[];
      final todayChunkIdx = (now.day - 1) ~/ 7;

      for (int w = 0; w < 5; w++) {
        final startDay = w * 7;
        if (startDay >= totalDays) break;
        final endDay = (startDay + 7).clamp(0, totalDays);

        int chunkSeconds = 0;
        for (int d = startDay; d < endDay; d++) {
          chunkSeconds += _currentPeriodActivities[d].totalSeconds;
        }

        final double hours = chunkSeconds / 3600.0;
        final weekNum = w + 1;
        final bool isToday = _periodOffset == 0 && (w == todayChunkIdx);

        weekChunks.add({
          'weekNum': weekNum,
          'hours': hours,
          'seconds': chunkSeconds,
          'detail': '${hours.toStringAsFixed(1)}h',
          'isToday': isToday,
        });
      }
      return weekChunks;
    }
  }

  int _getCurrentPeriodTotalSeconds() {
    if (_viewMode == ActivityViewMode.day) {
      return _currentDayActivity?.totalSeconds ?? 0;
    }
    return _currentPeriodActivities.fold(0, (sum, a) => sum + a.totalSeconds);
  }

  int _getPrevPeriodTotalSeconds() {
    if (_viewMode == ActivityViewMode.day) {
      return _prevDayActivity?.totalSeconds ?? 0;
    }
    return _prevPeriodActivities.fold(0, (sum, a) => sum + a.totalSeconds);
  }

  String _getTotalTimeString() {
    int total = _getCurrentPeriodTotalSeconds();
    if (total <= 0) return '0h 00m';
    int h = total ~/ 3600;
    int m = (total % 3600) ~/ 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  String _getBannerTitle(Language l10n) {
    if (_viewMode == ActivityViewMode.day) {
      return _periodOffset == 0 ? l10n.todayScreenTime : '${l10n.viewDay}: ${l10n.pastPeriod}';
    } else if (_viewMode == ActivityViewMode.week) {
      return _periodOffset == 0 ? l10n.weeklyUsage : '${l10n.viewWeek}: ${l10n.pastPeriod}';
    } else {
      return _periodOffset == 0 ? '${l10n.viewMonth} ${l10n.currentPeriod}' : '${l10n.viewMonth}: ${l10n.pastPeriod}';
    }
  }

  Map<String, dynamic> _getComparisonStats() {
    final current = _getCurrentPeriodTotalSeconds();
    final prev = _getPrevPeriodTotalSeconds();

    if (prev == 0 && current == 0) {
      return {'isUp': false, 'text': '0%'};
    }
    if (prev == 0 && current > 0) {
      return {'isUp': true, 'text': '100%'};
    }
    double diff = ((current - prev) / prev) * 100.0;
    return {
      'isUp': diff >= 0,
      'text': '${diff.abs().round()}%',
    };
  }

  String _getAverageText(Language l10n) {
    final totalSec = _getCurrentPeriodTotalSeconds();

    if (_viewMode == ActivityViewMode.day) {
      return l10n.usageRateNormal;
    } else if (_viewMode == ActivityViewMode.week) {
      final avg = totalSec / 7;
      final dur = _formatDuration(avg.round());
      return '${l10n.weeklyAverage}: $dur / ${l10n.perDay}';
    } else {
      final daysCount = _currentPeriodActivities.isEmpty ? 30 : _currentPeriodActivities.length;
      final avg = totalSec / daysCount;
      final dur = _formatDuration(avg.round());
      return '${l10n.monthlyAverage}: $dur / ${l10n.perDay}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text(
          l10n.activity,
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTodayBannerCard(context, l10n),
                  const SizedBox(height: 24),
                  _buildWeeklyChartCard(context, l10n),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildTodayBannerCard(BuildContext context, Language l10n) {
    final comp = _getComparisonStats();
    final bool isUp = comp['isUp'] as bool;
    final String percentText = comp['text'] as String;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.blue, AppColors.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.timer_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _getBannerTitle(l10n),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      percentText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _getTotalTimeString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 38,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _getAverageText(l10n),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChartCard(BuildContext context, Language l10n) {
    final items = _getChartItems();
    if (_selectedBarIndex >= items.length) {
      _selectedBarIndex = items.isNotEmpty ? items.length - 1 : 0;
    }

    final double maxHours = items.isEmpty
        ? 1.0
        : items.map((e) => (e['hours'] as num).toDouble()).reduce((a, b) => a > b ? a : b).clamp(0.1, 100.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderTheme),
        boxShadow: [
          BoxShadow(
            color: context.settingsCardBg,
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _viewMode == ActivityViewMode.day
                    ? l10n.todayScreenTime
                    : (_viewMode == ActivityViewMode.week ? l10n.weeklyUsage : l10n.viewMonth),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              _buildViewModeDropdown(context, l10n),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _periodOffset > -12 ? () => _navigatePeriod(-1) : null,
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    color: _periodOffset > -12 ? context.textPrimary : context.textMuted.withValues(alpha: 0.4),
                    size: 22,
                  ),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
                Flexible(
                  child: Text(
                    _getPeriodTitle(l10n),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blue,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _periodOffset < 0 ? () => _navigatePeriod(1) : null,
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: _periodOffset < 0 ? context.textPrimary : context.textMuted.withValues(alpha: 0.4),
                    size: 22,
                  ),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (items.isNotEmpty && _selectedBarIndex < items.length)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  items[_selectedBarIndex]['detail']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.blue,
                  ),
                ),
              ),
            ),
          SizedBox(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final double hours = (item['hours'] as num).toDouble();
                final bool isSelected = _selectedBarIndex == index;
                final bool isToday = item['isToday'] == true;
                final double barHeightFactor = hours <= 0 ? 0.08 : (hours / maxHours).clamp(0.12, 1.0);

                String labelText = item['label']?.toString() ?? '';
                if (labelText.isEmpty && item['weekNum'] != null) {
                  labelText = l10n.formatWeek(item['weekNum'] as int);
                } else if (labelText.isEmpty) {
                  labelText = item['labelEn']?.toString() ?? '';
                }

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedBarIndex = index;
                    });
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutQuad,
                        width: isSelected ? 22 : 18,
                        height: 100 * barHeightFactor,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.blue
                              : (isToday
                                  ? AppColors.teal
                                  : (context.isDark
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : Colors.black.withValues(alpha: 0.08))),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.blue.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        labelText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? AppColors.blue
                              : (isToday ? context.textPrimary : context.textMuted),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeDropdown(BuildContext context, Language l10n) {
    String getModeName(ActivityViewMode mode) {
      switch (mode) {
        case ActivityViewMode.day:
          return l10n.viewDay;
        case ActivityViewMode.week:
          return l10n.viewWeek;
        case ActivityViewMode.month:
          return l10n.viewMonth;
      }
    }

    return GestureDetector(
      key: _dropdownKey,
      onTap: () => _showViewModeMenu(context, l10n),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              getModeName(_viewMode),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.blue,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  void _showViewModeMenu(BuildContext context, Language l10n) {
    final RenderBox? renderBox = _dropdownKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Offset buttonOffset = renderBox.localToGlobal(Offset.zero);
    final Size buttonSize = renderBox.size;
    final Size screenSize = MediaQuery.of(context).size;

    const double menuWidth = 115;
    final double menuRight = (screenSize.width - (buttonOffset.dx + buttonSize.width))
        .clamp(12.0, screenSize.width - menuWidth - 12.0);
    final double menuTop = buttonOffset.dy + buttonSize.height + 6;

    String getModeName(ActivityViewMode mode) {
      switch (mode) {
        case ActivityViewMode.day:
          return l10n.viewDay;
        case ActivityViewMode.week:
          return l10n.viewWeek;
        case ActivityViewMode.month:
          return l10n.viewMonth;
      }
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DismissViewModeMenu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogCtx, anim1, anim2) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(dialogCtx),
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              right: menuRight,
              top: menuTop,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  width: menuWidth,
                  decoration: BoxDecoration(
                    color: context.isDark ? const Color(0xFF1E1E2C) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: context.isDark ? 0.45 : 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < ActivityViewMode.values.length; i++) ...[
                          if (i > 0)
                            Divider(height: 1, thickness: 0.8, color: context.dividerTheme),
                          _buildViewModeMenuItem(
                            dialogCtx: dialogCtx,
                            mode: ActivityViewMode.values[i],
                            title: getModeName(ActivityViewMode.values[i]),
                            isSelected: _viewMode == ActivityViewMode.values[i],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (dialogCtx, anim, secAnim, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            ),
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildViewModeMenuItem({
    required BuildContext dialogCtx,
    required ActivityViewMode mode,
    required String title,
    required bool isSelected,
  }) {
    return Material(
      color: isSelected
          ? AppColors.blue.withValues(alpha: dialogCtx.isDark ? 0.12 : 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(dialogCtx);
          if (_viewMode != mode) {
            _changeViewMode(mode);
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppColors.blue : dialogCtx.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
