import 'package:flutter/material.dart';
import '../l10n/language.dart';

class TimeFormatter {

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final asInt = int.tryParse(trimmed);
      if (asInt != null && trimmed.length >= 10) {
        return DateTime.fromMillisecondsSinceEpoch(
          trimmed.length == 10 ? asInt * 1000 : asInt,
        ).toLocal();
      }
      return DateTime.tryParse(trimmed)?.toLocal();
    }
    return null;
  }

  static bool _matchesKey(String text, String key) {
    final clean = text.trim().toLowerCase();
    if (clean.isEmpty) return false;
    final rawKey = key.toLowerCase();
    if (clean == rawKey || clean == rawKey.replaceAll('_', '')) return true;
    for (final trans in Language.getAllTranslationsOf(key)) {
      if (clean == trans.toLowerCase()) return true;
    }
    return false;
  }

  static String formatTimeAgo(
    BuildContext context,
    dynamic dateValue,
  ) {
    final l10n = context.l10n;
    if (dateValue == null) return l10n.justNow;

    final dt = _parseDateTime(dateValue);
    if (dt == null) {
      final s = dateValue.toString().trim();
      final lower = s.toLowerCase();
      if (lower.isEmpty || _matchesKey(lower, 'justNow')) {
        return l10n.justNow;
      }
      return s;
    }

    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.isNegative || diff.inSeconds < 60) return l10n.justNow;
    if (diff.inMinutes < 60) return '${diff.inMinutes} ${l10n.minutesAgo}';
    if (diff.inHours < 24) return '${diff.inHours} ${l10n.hoursAgo}';
    if (diff.inDays == 1) return l10n.yesterday;
    if (diff.inDays < 7) return '${diff.inDays} ${l10n.daysAgo}';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  static String formatChatTime(
    BuildContext context, {
    dynamic date,
    String? fallbackTime,
  }) {
    final l10n = context.l10n;

    final d = _parseDateTime(date) ?? _parseDateTime(fallbackTime);

    if (d != null) {
      final now = DateTime.now();
      final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
      if (isToday) {
        final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
        final minute = d.minute.toString().padLeft(2, '0');
        final ampm = d.hour >= 12 ? 'PM' : 'AM';
        return '$hour:$minute $ampm';
      }

      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final isYesterday = d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day;
      if (isYesterday) {
        return l10n.yesterday;
      }

      final diffDays = now.difference(d).inDays;
      if (diffDays < 7 && now.weekday != d.weekday) {
        switch (d.weekday) {
          case DateTime.monday:
            return l10n.monday;
          case DateTime.tuesday:
            return l10n.tuesday;
          case DateTime.wednesday:
            return l10n.wednesday;
          case DateTime.thursday:
            return l10n.thursday;
          case DateTime.friday:
            return l10n.friday;
          case DateTime.saturday:
            return l10n.saturday;
          case DateTime.sunday:
            return l10n.sunday;
        }
      }

      return '${d.day}/${d.month}';
    }

    final raw = (fallbackTime ?? '').trim();
    if (raw.isEmpty) return '';

    if (_matchesKey(raw, 'yesterday')) return l10n.yesterday;
    if (_matchesKey(raw, 'monday')) return l10n.monday;
    if (_matchesKey(raw, 'tuesday')) return l10n.tuesday;
    if (_matchesKey(raw, 'wednesday')) return l10n.wednesday;
    if (_matchesKey(raw, 'thursday')) return l10n.thursday;
    if (_matchesKey(raw, 'friday')) return l10n.friday;
    if (_matchesKey(raw, 'saturday')) return l10n.saturday;
    if (_matchesKey(raw, 'sunday')) return l10n.sunday;
    if (_matchesKey(raw, 'justNow')) return l10n.justNow;
    return raw;
  }
}
