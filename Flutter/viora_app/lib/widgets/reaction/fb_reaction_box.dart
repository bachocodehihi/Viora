import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';

enum FbReaction {
  like('like', 'Like', 'assets/icons/like.png', Color(0xFF1877F2)),
  love('love', 'Love', 'assets/icons/heart.png', Color(0xFFF02849)),
  care('care', 'Care', 'assets/icons/care.png', Color(0xFFF7B125)),
  haha('haha', 'Haha', 'assets/icons/haha.png', Color(0xFFF7B125)),
  wow('wow', 'Wow', 'assets/icons/wow.png', Color(0xFFF7B125)),
  sad('sad', 'Sad', 'assets/icons/cry.png', Color(0xFFF7B125)),
  angry('angry', 'Angry', 'assets/icons/angry.png', Color(0xFFE53935));

  final String id;
  final String label;
  final String iconPath;
  final Color color;

  const FbReaction(this.id, this.label, this.iconPath, this.color);

  static FbReaction? fromId(String? id) {
    if (id == null) return null;
    for (final r in FbReaction.values) {
      if (r.id == id) return r;
    }
    return null;
  }
}

class FbReactionPicker {
  static FbReactionPickerHandle show({
    required BuildContext context,
    required GlobalKey targetKey,
    ValueNotifier<Offset?>? pointerPositionNotifier,
    ValueNotifier<bool>? pointerActiveNotifier,
    required ValueChanged<FbReaction> onSelected,
  }) {
    final renderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return FbReactionPickerHandle.noop();

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final overlayState = Overlay.of(context);
    final screenSize = MediaQuery.of(context).size;

    const barWidth = 318.0;
    const barHeight = 52.0;

    double left = offset.dx;
    if (left + barWidth > screenSize.width - 12) {
      left = screenSize.width - barWidth - 12;
    }
    if (left < 12) {
      left = 12;
    }

    double top = offset.dy - barHeight - 16;
    if (top < MediaQuery.of(context).padding.top + 10) {
      top = offset.dy + size.height + 8;
    }

    OverlayEntry? entry;
    bool isClosed = false;

    void dismiss() {
      if (isClosed) return;
      isClosed = true;
      entry?.remove();
      entry = null;
    }

    entry = OverlayEntry(
      builder: (ctx) => _FbReactionOverlayWidget(
        position: Offset(left, top),
        pointerPositionNotifier: pointerPositionNotifier,
        pointerActiveNotifier: pointerActiveNotifier,
        onSelect: (reaction) {
          onSelected(reaction);
          dismiss();
        },
        onDismiss: dismiss,
      ),
    );

    overlayState.insert(entry!);
    return FbReactionPickerHandle(dismiss: dismiss);
  }
}

class FbReactionPickerHandle {
  final VoidCallback dismiss;
  const FbReactionPickerHandle({required this.dismiss});
  factory FbReactionPickerHandle.noop() => FbReactionPickerHandle(dismiss: () {});
}

class _FbReactionOverlayWidget extends StatefulWidget {
  final Offset position;
  final ValueChanged<FbReaction> onSelect;
  final VoidCallback onDismiss;
  final ValueNotifier<Offset?>? pointerPositionNotifier;
  final ValueNotifier<bool>? pointerActiveNotifier;

  const _FbReactionOverlayWidget({
    required this.position,
    required this.onSelect,
    required this.onDismiss,
    this.pointerPositionNotifier,
    this.pointerActiveNotifier,
  });

  @override
  State<_FbReactionOverlayWidget> createState() => _FbReactionOverlayWidgetState();
}

class _FbReactionOverlayWidgetState extends State<_FbReactionOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  int _hoveredIndex = -1;
  bool _hasMovedPointer = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _animController.forward();

    widget.pointerPositionNotifier?.addListener(_onGlobalPointerChanged);
    widget.pointerActiveNotifier?.addListener(_onGlobalPointerActiveChanged);
  }

  @override
  void dispose() {
    widget.pointerPositionNotifier?.removeListener(_onGlobalPointerChanged);
    widget.pointerActiveNotifier?.removeListener(_onGlobalPointerActiveChanged);
    _animController.dispose();
    super.dispose();
  }

  void _onGlobalPointerChanged() {
    final pos = widget.pointerPositionNotifier?.value;
    if (pos == null) return;

    final barLeft = widget.position.dx;
    final barTop = widget.position.dy;
    const barHeight = 52.0;

    final dy = pos.dy;
    final isWithinY = (dy >= barTop - 50 && dy <= barTop + barHeight + 130);

    if (!isWithinY) {
      if (_hoveredIndex != -1) {
        setState(() => _hoveredIndex = -1);
      }
      return;
    }

    _hasMovedPointer = true;

    const horizontalPadding = 10.0;
    const itemWidth = 42.0;
    final localDx = pos.dx - barLeft - horizontalPadding;

    if (localDx < -15 || localDx > (FbReaction.values.length * itemWidth) + 15) {
      if (_hoveredIndex != -1) {
        setState(() => _hoveredIndex = -1);
      }
      return;
    }

    final newIndex = (localDx / itemWidth).floor().clamp(0, FbReaction.values.length - 1);
    if (newIndex != _hoveredIndex) {
      setState(() => _hoveredIndex = newIndex);
    }
  }

  void _onGlobalPointerActiveChanged() {
    final isActive = widget.pointerActiveNotifier?.value ?? false;
    if (!isActive) {
      if (_hoveredIndex >= 0 && _hoveredIndex < FbReaction.values.length) {
        final reaction = FbReaction.values[_hoveredIndex];
        _close(() => widget.onSelect(reaction));
      } else if (_hasMovedPointer) {
        _close();
      }
    }
  }

  void _close([VoidCallback? onDone]) {
    _animController.reverse().then((_) {
      widget.onDismiss();
      onDone?.call();
    });
  }

  void _updateHoveredByDx(double localDx) {
    const horizontalPadding = 10.0;
    const itemWidth = 42.0;
    final effectiveDx = localDx - horizontalPadding;

    if (effectiveDx < -15 || effectiveDx > (FbReaction.values.length * itemWidth) + 15) {
      if (_hoveredIndex != -1) {
        setState(() => _hoveredIndex = -1);
      }
      return;
    }

    final newIndex = (effectiveDx / itemWidth).floor().clamp(0, FbReaction.values.length - 1);
    if (newIndex != _hoveredIndex) {
      setState(() => _hoveredIndex = newIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF2D2B3D)
        : Colors.black.withValues(alpha: 0.06);

    return Stack(
      children: [

        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _close(),
            onPanDown: (_) => _close(),
            child: const SizedBox.expand(),
          ),
        ),

        Positioned(
          left: widget.position.dx,
          top: widget.position.dy,
          child: ScaleTransition(
            scale: _scaleAnimation,
            alignment: Alignment.bottomLeft,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onPanUpdate: (details) => _updateHoveredByDx(details.localPosition.dx),
                  onPanEnd: (_) {
                    if (_hoveredIndex >= 0 && _hoveredIndex < FbReaction.values.length) {
                      final reaction = FbReaction.values[_hoveredIndex];
                      _close(() => widget.onSelect(reaction));
                    } else {
                      _close();
                    }
                  },
                  child: Container(
                    clipBehavior: Clip.none,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: borderColor, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                        if (isDark)
                          BoxShadow(
                            color: AppColors.blue.withValues(alpha: 0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(FbReaction.values.length, (index) {
                        final reaction = FbReaction.values[index];
                        return _buildReactionItem(reaction, index);
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReactionItem(FbReaction reaction, int index) {

    double scale = 1.0;
    double translateY = 0.0;
    double rotation = 0.0;

    if (_hoveredIndex != -1) {
      final int dist = (index - _hoveredIndex).abs();
      if (dist == 0) {

        scale = 1.75;
        translateY = -18.0;
        rotation = (index % 2 == 0) ? -0.05 : 0.05;
      } else if (dist == 1) {

        scale = 1.25;
        translateY = -8.0;
        rotation = (index < _hoveredIndex) ? -0.025 : 0.025;
      } else if (dist == 2) {

        scale = 1.08;
        translateY = -3.0;
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _close(() => widget.onSelect(reaction));
      },
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _hoveredIndex = index);
        },
        onExit: (_) {
          if (_hoveredIndex == index) {
            setState(() => _hoveredIndex = -1);
          }
        },
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutBack,
              transform: Matrix4.translationValues(0.0, translateY, 0.0)
                ..rotateZ(rotation),
              child: AnimatedScale(
                scale: scale,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutBack,
                child: Image.asset(
                  reaction.iconPath,
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FbReactionLikeButton extends StatefulWidget {
  final int count;
  final bool isLiked;
  final String? reaction;
  final VoidCallback onTap;
  final ValueChanged<FbReaction> onReactionSelected;

  const FbReactionLikeButton({
    super.key,
    required this.count,
    required this.isLiked,
    this.reaction,
    required this.onTap,
    required this.onReactionSelected,
  });

  @override
  State<FbReactionLikeButton> createState() => _FbReactionLikeButtonState();
}

class _FbReactionLikeButtonState extends State<FbReactionLikeButton> {
  final GlobalKey _buttonKey = GlobalKey();

  ValueNotifier<Offset?>? _pointerPositionNotifier;
  ValueNotifier<bool>? _pointerActiveNotifier;

  void _handleLongPressStart(LongPressStartDetails details) {
    _pointerPositionNotifier = ValueNotifier<Offset?>(details.globalPosition);
    _pointerActiveNotifier = ValueNotifier<bool>(true);

    FbReactionPicker.show(
      context: context,
      targetKey: _buttonKey,
      pointerPositionNotifier: _pointerPositionNotifier,
      pointerActiveNotifier: _pointerActiveNotifier,
      onSelected: widget.onReactionSelected,
    );
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    _pointerPositionNotifier?.value = details.globalPosition;
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    _pointerPositionNotifier?.value = details.globalPosition;
    _pointerActiveNotifier?.value = false;
  }

  void _handleLongPressCancel() {
    _pointerActiveNotifier?.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final currentReaction = FbReaction.fromId(widget.reaction);
    final isReacted = widget.isLiked && currentReaction != null;
    final Color activeColor = isReacted ? currentReaction.color : AppColors.red;

    return GestureDetector(
      key: _buttonKey,
      onTap: widget.onTap,
      onLongPressStart: _handleLongPressStart,
      onLongPressMoveUpdate: _handleLongPressMoveUpdate,
      onLongPressEnd: _handleLongPressEnd,
      onLongPressCancel: _handleLongPressCancel,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIconOrEmoji(currentReaction),
            const SizedBox(width: 8),
            Text(
              '${widget.count}',
              style: TextStyle(
                color: widget.isLiked ? activeColor : context.textMuted,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconOrEmoji(FbReaction? reaction) {
    if (!widget.isLiked) {
      return Icon(
        Icons.favorite_border_rounded,
        size: 24,
        color: context.textMuted,
      );
    }

    final r = reaction ?? FbReaction.like;
    return Image.asset(
      r.iconPath,
      width: 24,
      height: 24,
      fit: BoxFit.contain,
    );
  }
}
