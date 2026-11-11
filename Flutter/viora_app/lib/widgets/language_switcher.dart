import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/theme_helper.dart';
import '../l10n/language.dart';

class LanguageSwitcher extends StatefulWidget {
  final double width;
  final double height;

  const LanguageSwitcher({
    super.key,
    this.width = 104.0,
    this.height = 36.0,
  });

  @override
  State<LanguageSwitcher> createState() => _LanguageSwitcherState();
}

class _LanguageSwitcherState extends State<LanguageSwitcher> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  static const double _margin = 3.0;

  double get _innerWidth => widget.width - 2.0;
  double get _innerHeight => widget.height - 2.0;
  double get _pillWidth => (_innerWidth - (_margin * 2)) / 2;
  double get _pillHeight => _innerHeight - (_margin * 2);
  double get _maxOffset => _pillWidth;

  @override
  void initState() {
    super.initState();
    final isEn = LanguageManager.isEnglish();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: isEn ? 1.0 : 0.0,
    );
    LanguageManager.localeNotifier.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() {
    final isEn = LanguageManager.isEnglish();
    final target = isEn ? 1.0 : 0.0;
    if ((_controller.value - target).abs() > 0.01 && !_controller.isAnimating) {
      _controller.animateTo(target, curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    LanguageManager.localeNotifier.removeListener(_onLocaleChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTapUp(TapUpDetails details) {
    final dx = details.localPosition.dx;
    final target = dx >= (widget.width / 2) ? 1.0 : 0.0;
    _animateAndSetLanguage(target);
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _controller.stop();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? details.delta.dx;
    _controller.value = (_controller.value + delta / _maxOffset).clamp(0.0, 1.0);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    double target;
    if (velocity.abs() > 200) {
      target = velocity > 0 ? 1.0 : 0.0;
    } else {
      target = _controller.value >= 0.5 ? 1.0 : 0.0;
    }
    _animateAndSetLanguage(target);
  }

  void _animateAndSetLanguage(double target) {
    _controller.animateTo(target, curve: Curves.easeOutCubic);
    final newLang = target == 1.0 ? 'en' : 'vi';
    if (LanguageManager.localeNotifier.value.languageCode != newLang) {
      LanguageManager.changeLanguage(newLang);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final inactiveColor = isDark ? AppColors.white.withValues(alpha: 0.45) : Colors.black45;

    return GestureDetector(
      onTapUp: _onTapUp,
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withValues(alpha: 0.35)
              : Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(widget.height / 2),
          border: Border.all(
            color: isDark
                ? AppColors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Positioned(
                  left: _margin + (_controller.value * _maxOffset),
                  top: _margin,
                  width: _pillWidth,
                  height: _pillHeight,
                  child: child!,
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(_pillHeight / 2),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final t = _controller.value;
                    final viProgress = (1.0 - t).clamp(0.0, 1.0);
                    final enProgress = t.clamp(0.0, 1.0);

                    final viColor = Color.lerp(inactiveColor, AppColors.white, viProgress)!;
                    final enColor = Color.lerp(inactiveColor, AppColors.white, enProgress)!;

                    final viScale = 0.94 + 0.12 * viProgress;
                    final enScale = 0.94 + 0.12 * enProgress;

                    return Row(
                      children: [
                        Expanded(
                          child: Center(
                            child: Transform.scale(
                              scale: viScale,
                              child: Text(
                                'VI',
                                style: TextStyle(
                                  color: viColor,
                                  fontWeight: viProgress > 0.5 ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 12.5,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Transform.scale(
                              scale: enScale,
                              child: Text(
                                'EN',
                                style: TextStyle(
                                  color: enColor,
                                  fontWeight: enProgress > 0.5 ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 12.5,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
