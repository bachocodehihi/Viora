import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../l10n/language.dart';

class LiveReactionType {
  final String id;
  final String assetPath;
  final String label;

  const LiveReactionType({
    required this.id,
    required this.assetPath,
    required this.label,
  });
}

const List<LiveReactionType> kLiveReactions = [
  LiveReactionType(id: 'love', assetPath: 'assets/icons/heart.png', label: 'Yêu thích'),
  LiveReactionType(id: 'like', assetPath: 'assets/icons/like.png', label: 'Thích'),
  LiveReactionType(id: 'care', assetPath: 'assets/icons/care.png', label: 'Thương thương'),
  LiveReactionType(id: 'haha', assetPath: 'assets/icons/haha.png', label: 'Haha'),
  LiveReactionType(id: 'wow', assetPath: 'assets/icons/wow.png', label: 'Wow'),
  LiveReactionType(id: 'sad', assetPath: 'assets/icons/cry.png', label: 'Buồn'),
  LiveReactionType(id: 'angry', assetPath: 'assets/icons/angry.png', label: 'Phẫn nộ'),
];

String getLiveReactionAsset(String reactionId) {
  final clean = reactionId.trim().toLowerCase();
  for (final r in kLiveReactions) {
    if (r.id == clean) return r.assetPath;
  }
  if (clean == 'heart') return 'assets/icons/heart.png';
  if (clean == 'cry') return 'assets/icons/cry.png';
  return 'assets/icons/heart.png';
}

String formatLiveCount(int count) {
  if (count < 1000) {
    return '$count';
  } else if (count < 1000000) {
    final k = count / 1000.0;
    final formatted = k.toStringAsFixed(1).replaceAll('.', ',');
    if (formatted.endsWith(',0')) {
      return '${formatted.substring(0, formatted.length - 2)}K';
    }
    return '${formatted}K';
  } else {
    final m = count / 1000000.0;
    final formatted = m.toStringAsFixed(1).replaceAll('.', ',');
    if (formatted.endsWith(',0')) {
      return '${formatted.substring(0, formatted.length - 2)}M';
    }
    return '${formatted}M';
  }
}

class LiveReactionBar extends StatelessWidget {
  final void Function(String reactionId) onSelect;
  final VoidCallback? onClose;

  const LiveReactionBar({
    super.key,
    required this.onSelect,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: kLiveReactions.map((r) {
          return _LiveReactionItem(
            reaction: r,
            onTap: () => onSelect(r.id),
          );
        }).toList(),
      ),
    );
  }
}


class LiveReactionStatsBar extends StatelessWidget {
  final Map<String, int> reactionsCount;
  final VoidCallback? onClose;

  const LiveReactionStatsBar({
    super.key,
    required this.reactionsCount,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {

    final activeReactions = kLiveReactions.where((r) {
      final count = reactionsCount[r.id] ?? 0;
      return count > 0;
    }).toList();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: activeReactions.isEmpty
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/icons/like.png',
                  width: 18.r,
                  height: 18.r,
                  filterQuality: FilterQuality.high,
                ),
                SizedBox(width: 6.w),
                Text(
                  context.l10n.noReactionsYet,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: activeReactions.map((r) {
                final count = reactionsCount[r.id] ?? 0;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        r.assetPath,
                        width: 21.r,
                        height: 21.r,
                        filterQuality: FilterQuality.high,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        formatLiveCount(count),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _LiveReactionItem extends StatefulWidget {
  final LiveReactionType reaction;
  final VoidCallback onTap;

  const _LiveReactionItem({
    required this.reaction,
    required this.onTap,
  });

  @override
  State<_LiveReactionItem> createState() => _LiveReactionItemState();
}

class _LiveReactionItemState extends State<_LiveReactionItem> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 140),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    _animCtrl.forward().then((_) => _animCtrl.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Image.asset(
            widget.reaction.assetPath,
            width: 32.r,
            height: 32.r,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

class LiveFloatingParticle extends StatefulWidget {
  final String reactionId;
  final VoidCallback onComplete;

  const LiveFloatingParticle({
    super.key,
    required this.reactionId,
    required this.onComplete,
  });

  @override
  State<LiveFloatingParticle> createState() => _LiveFloatingParticleState();
}

class _LiveFloatingParticleState extends State<LiveFloatingParticle> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _translateY;
  late Animation<double> _opacity;
  late Animation<double> _scale;
  late double _startX;
  late double _swayAmplitude;
  late double _swayFrequency;

  @override
  void initState() {
    super.initState();
    final random = math.Random();
    _startX = (random.nextDouble() * 30 - 15).w;
    _swayAmplitude = (random.nextDouble() * 12 + 8).w;
    _swayFrequency = (random.nextDouble() * 1.5 + 2.5);

    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1700),
      vsync: this,
    );

    _translateY = Tween<double>(begin: 0, end: -180.h).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.55, 1.0)),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.4, end: 1.25).chain(CurveTween(curve: Curves.easeOutBack)), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 1.25, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 15),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 60),
    ]).animate(_ctrl);

    _ctrl.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = getLiveReactionAsset(widget.reactionId);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, child) {
        final sway = math.sin(_ctrl.value * math.pi * _swayFrequency) * _swayAmplitude;
        return Transform.translate(
          offset: Offset(_startX + sway, _translateY.value),
          child: Opacity(
            opacity: _opacity.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: _scale.value,
              child: Image.asset(
                assetPath,
                width: 32.r,
                height: 32.r,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        );
      },
    );
  }
}

