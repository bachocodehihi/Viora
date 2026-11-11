import 'package:flutter/material.dart';
import 'app_colors.dart';

extension ThemeHelper on BuildContext {
  ThemeData get theme => Theme.of(this);
  bool get isDark => theme.brightness == Brightness.dark;

  Color get textPrimary => isDark ? Colors.white : Colors.black87;
  Color get textMuted => isDark ? Colors.white54 : Colors.black54;
  Color get textSubtle => isDark ? Colors.white38 : Colors.black38;
  Color get textPlaceholder => isDark ? Colors.white30 : Colors.black38;

  Color get cardBg => isDark ? const Color(0xFF161522) : Colors.white;
  Color get borderTheme => isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03);
  Color get actionPillBg => isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03);
  Color get scaffoldBg => theme.scaffoldBackgroundColor;

  Color get navBarShadow => Colors.black.withValues(alpha: isDark ? 0.4 : 0.08);
  Color get navBarBorder => isDark ? const Color(0xFF2D2B3D) : AppColors.gray.withValues(alpha: 0.2);
  Color get languageTrackBg => isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05);
  Color get settingCardBg => isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01);

  Color get homeShadow => Colors.black.withValues(alpha: isDark ? 0.1 : 0.02);
  Color get dividerTheme => isDark ? Colors.white24 : Colors.black12;
  Color get activeFriendBg => isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05);
  Color get momentShadow => Colors.black.withValues(alpha: isDark ? 0.12 : 0.02);

  Color get settingsCardBg => isDark ? Colors.black.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.01);
  Color get profileShadow => Colors.black.withValues(alpha: isDark ? 0.2 : 0.06);
  Color get profileCardBg => isDark ? Colors.black.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.01);

  Color get notificationShadow => Colors.black.withValues(alpha: isDark ? 0.1 : 0.03);
  Color get contactCardShadow => Colors.black.withValues(alpha: isDark ? 0.1 : 0.03);

  Color get chatBubbleShadow => Colors.black.withValues(alpha: isDark ? 0.15 : 0.04);
  Color get chatInputShadow => Colors.black.withValues(alpha: isDark ? 0.2 : 0.05);
  Color get chatAttachBtnBg => isDark ? const Color(0xFF2D2B3D) : Colors.grey.withValues(alpha: 0.1);
}
