import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../../l10n/language.dart';
class AppAvatar extends StatelessWidget {
  final dynamic avatar;

  final String? name;

  final Color? color;

  final double radius;

  final double? fontSize;

  final Color textColor;

  final bool enableViewer;

  final VoidCallback? onTap;

  final String? heroTag;

  final bool? isOnline;

  final Widget? badge;

  final Alignment badgeAlignment;

  final BoxBorder? border;

  final List<BoxShadow>? boxShadow;

  const AppAvatar({
    super.key,
    required this.avatar,
    this.name,
    this.color,
    this.radius = 20,
    this.fontSize,
    this.textColor = Colors.white,
    this.enableViewer = false,
    this.onTap,
    this.heroTag,
    this.isOnline,
    this.badge,
    this.badgeAlignment = Alignment.bottomRight,
    this.border,
    this.boxShadow,
  });

  static const List<Color> _defaultColors = [
    AppColors.blue,
    AppColors.teal,
    AppColors.purple,
    AppColors.pink,
    AppColors.orange,
    AppColors.green,
    AppColors.red,
    AppColors.brown,
  ];

  static Color getColorForName(String? name) {
    if (name == null || name.trim().isEmpty) return AppColors.blue;
    final int hash = name.trim().codeUnits.fold(0, (prev, curr) => prev + curr);
    return _defaultColors[hash % _defaultColors.length];
  }

  static String getInitial(dynamic avatar, String? name) {
    final avatarStr = avatar?.toString().trim() ?? '';

    if (avatarStr.isNotEmpty &&
        avatarStr.length <= 3 &&
        !avatarStr.startsWith('http') &&
        !avatarStr.startsWith('assets/')) {
      return avatarStr.toUpperCase();
    }

    if (name != null && name.trim().isNotEmpty) {
      return name.trim()[0].toUpperCase();
    }
    return '?';
  }

  void _handleTap(BuildContext context, String? imageUrl, String initial, Color bgColor) {
    if (onTap != null) {
      onTap!();
      return;
    }

    if (enableViewer) {
      final effectiveHeroTag = heroTag ?? 'avatar_${name ?? initial}_${DateTime.now().millisecondsSinceEpoch}';
      Navigator.pushNamed(
        context,
        AppRoutes.avatarViewer,
        arguments: {
          'imageUrl': imageUrl,
          'title': name ?? (imageUrl != null ? context.l10n.avatar : initial),
          'fallbackText': initial,
          'fallbackColor': bgColor,
          'heroTag': effectiveHeroTag,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    final avatarStr = avatar?.toString().trim() ?? '';
    final isUrl = avatarStr.startsWith('http://') || avatarStr.startsWith('https://');
    final isAsset = avatarStr.startsWith('assets/');
    final initial = getInitial(avatar, name);
    final effectiveColor = color ?? getColorForName(name ?? avatarStr);
    final effectiveFontSize = fontSize ?? (radius * 0.78).clamp(10.0, 48.0);
    final effectiveHeroTag = heroTag ?? (enableViewer ? 'avatar_${name ?? initial}' : null);

    Widget imageWidget;

    if (isUrl) {
      imageWidget = Image.network(
        avatarStr,
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: diameter,
            height: diameter,
            color: effectiveColor.withValues(alpha: 0.15),
            child: Center(
              child: SizedBox(
                width: radius * 0.8,
                height: radius * 0.8,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: effectiveColor,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackCircle(diameter, effectiveColor, initial, effectiveFontSize);
        },
      );
    } else if (isAsset) {
      imageWidget = Image.asset(
        avatarStr,
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackCircle(diameter, effectiveColor, initial, effectiveFontSize);
        },
      );
    } else {
      imageWidget = _buildFallbackCircle(diameter, effectiveColor, initial, effectiveFontSize);
    }

    Widget content = ClipOval(
      child: imageWidget,
    );

    if (border != null || boxShadow != null) {
      content = Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: border,
          boxShadow: boxShadow,
        ),
        child: content,
      );
    }

    if (effectiveHeroTag != null) {
      content = Hero(
        tag: effectiveHeroTag,
        createRectTween: (begin, end) =>
            MaterialRectCenterArcTween(begin: begin, end: end),
        child: Material(
          type: MaterialType.transparency,
          child: content,
        ),
      );
    }

    if (onTap != null || enableViewer) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleTap(context, isUrl ? avatarStr : null, initial, effectiveColor),
        child: content,
      );
    }

    if (isOnline == null && badge == null) {
      return content;
    }

    final double badgeSize = (radius * 0.55).clamp(10.0, 18.0);
    Widget? activeBadge = badge;

    if (activeBadge == null && isOnline != null) {
      activeBadge = Container(
        width: badgeSize,
        height: badgeSize,
        decoration: BoxDecoration(
          color: isOnline! ? AppColors.green : Colors.grey,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).cardColor,
            width: 2,
          ),
        ),
      );
    }

    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: content),
          if (activeBadge != null)
            Align(
              alignment: badgeAlignment,
              child: activeBadge,
            ),
        ],
      ),
    );
  }

  Widget _buildFallbackCircle(double diameter, Color bgColor, String text, double fontSize) {
    return Container(
      width: diameter,
      height: diameter,
      color: bgColor,
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
