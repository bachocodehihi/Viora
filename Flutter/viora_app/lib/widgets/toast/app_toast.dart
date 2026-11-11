import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';

class AppToast {
  static OverlayEntry? _currentEntry;

  static void clear() {
    if (_currentEntry != null && _currentEntry!.mounted) {
      _currentEntry!.remove();
      _currentEntry = null;
    }
  }

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    IconData? icon,
    Color? customColor,
    Color? color,
    Duration duration = const Duration(seconds: 2),
  }) {
    clear();

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final effectiveColor = customColor ?? color ?? (isError ? AppColors.red : AppColors.green);
    final toastIcon = icon ?? (isError ? Icons.error_outline_rounded : Icons.check_circle_rounded);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        bottom: 90,
        left: 20,
        right: 20,
        child: IgnorePointer(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.85 + (0.15 * value),
                    child: Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: effectiveColor.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: effectiveColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(toastIcon, color: effectiveColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          message,
                          style: TextStyle(
                            color: ctx.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    Future.delayed(duration, () {
      if (_currentEntry == entry) {
        if (entry.mounted) {
          entry.remove();
        }
        _currentEntry = null;
      }
    });
  }

  static void success(BuildContext context, String message, {IconData? icon, Color? color}) {
    show(
      context,
      message,
      isError: false,
      icon: icon ?? Icons.check_circle_rounded,
      customColor: color ?? AppColors.green,
    );
  }

  static void error(BuildContext context, String message, {IconData? icon, Color? color}) {
    show(
      context,
      message,
      isError: true,
      icon: icon ?? Icons.cancel_rounded,
      customColor: color ?? AppColors.red,
    );
  }

  static void info(BuildContext context, String message, {IconData? icon, Color? color}) {
    show(
      context,
      message,
      isError: false,
      icon: icon ?? Icons.info_outline_rounded,
      customColor: color ?? AppColors.blue,
    );
  }

  static void warning(BuildContext context, String message, {IconData? icon, Color? color}) {
    show(
      context,
      message,
      isError: false,
      icon: icon ?? Icons.warning_amber_rounded,
      customColor: color ?? AppColors.orange,
    );
  }
}
