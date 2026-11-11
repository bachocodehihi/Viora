import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../config/app_colors.dart';
import '../../../config/theme_helper.dart';
import '../../../l10n/language.dart';
import '../../../widgets/reaction/fb_reaction_box.dart';

class ChatMessageContextMenu {
  static void show({
    required BuildContext context,
    required Map<String, dynamic> msg,
    required int index,
    required Offset tapPosition,
    RenderBox? renderBox,
    required bool isPinned,
    required Widget bubbleWidget,
    required ValueChanged<String> onReactionSelected,
    required VoidCallback onReply,
    required VoidCallback onCopy,
    required VoidCallback onForward,
    required VoidCallback onTogglePin,
    required VoidCallback onRecall,
    required VoidCallback onDelete,
  }) {
    if (msg['type'] == 'system') return;
    HapticFeedback.mediumImpact();

    final isMe = msg['isMe'] == true;
    final text = (msg['text'] ?? '').toString();

    Offset bubbleOffset = tapPosition;
    Size bubbleSize = const Size(200, 50);

    if (renderBox != null && renderBox.hasSize) {
      bubbleOffset = renderBox.localToGlobal(Offset.zero);
      bubbleSize = renderBox.size;
    }

    final currentReactionId = msg['reaction']?.toString();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogCtx, anim1, anim2) {
        final screenWidth = 1.sw;
        final screenHeight = 1.sh;

        final double reactionBarWidth = (324.w).clamp(280.0, 360.0);
        final double reactionBarHeight = 52.h;
        final double menuWidth = (216.w).clamp(200.0, 260.0);

        final bool isPoll = msg['type'] == 'poll' || msg['poll'] != null;
        final bool isCall = msg['type'] == 'call' || msg['call'] != null;
        final bool canCopy = !isCall && msg['isRecalled'] != true;
        final bool canForward = !isCall && msg['isRecalled'] != true;
        final bool canRecall = isMe && msg['isRecalled'] != true && !isCall;
        final int menuItemCount = isPoll
            ? 1
            : (1 + // reply
                (canCopy ? 1 : 0) +
                (canForward ? 1 : 0) +
                1 + // pin
                (canRecall ? 1 : 0) +
                1); // delete
        final double itemHeight = 40.h;
        final double menuHeight = menuItemCount * itemHeight + (menuItemCount - 1) * 1.0;

        final double bubbleTop = bubbleOffset.dy;
        final double bubbleBottom = bubbleTop + bubbleSize.height;

        final mediaQuery = MediaQuery.of(context);
        final double topSafeArea = mediaQuery.padding.top + kToolbarHeight + 8.h;
        final double bottomSafeArea = screenHeight - mediaQuery.padding.bottom - 65.h;

        final double reactionBarLeft = (screenWidth - reactionBarWidth) / 2;
        final double spacing = 10.h;

        final bool canFitMenuBelow = (bubbleBottom + spacing + menuHeight) <= bottomSafeArea;
        final bool canFitReactionAbove = (bubbleTop - spacing - reactionBarHeight) >= topSafeArea;

        double reactionBarTop;
        double menuTop;

        if (canFitMenuBelow) {
          menuTop = bubbleBottom + spacing;
          if (canFitReactionAbove) {
            reactionBarTop = bubbleTop - reactionBarHeight - spacing;
          } else {
            reactionBarTop = bubbleBottom + spacing;
            menuTop = reactionBarTop + reactionBarHeight + spacing;
          }
        } else {
          reactionBarTop = bubbleTop - reactionBarHeight - spacing;
          menuTop = reactionBarTop - menuHeight - spacing;

          if (menuTop < topSafeArea) {
            menuTop = topSafeArea;
            reactionBarTop = menuTop + menuHeight + spacing;
          }
        }

        double menuLeft;
        if (isMe) {
          menuLeft = (bubbleOffset.dx + bubbleSize.width) - menuWidth;
        } else {
          menuLeft = bubbleOffset.dx;
        }
        menuLeft = menuLeft.clamp(16.w, screenWidth - menuWidth - 16.w);

        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.pop(dialogCtx),
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),

              Positioned(
                top: bubbleTop,
                left: bubbleOffset.dx,
                child: IgnorePointer(
                  child: SizedBox(
                    width: bubbleSize.width,
                    child: bubbleWidget,
                  ),
                ),
              ),

              if (!isPoll)
                Positioned(
                  top: reactionBarTop,
                  left: reactionBarLeft,
                  child: _buildFloatingReactionBar(
                    context: context,
                    dialogCtx: dialogCtx,
                    currentReactionId: currentReactionId,
                    barWidth: reactionBarWidth,
                    onReactionSelected: onReactionSelected,
                  ),
                ),

              Positioned(
                top: menuTop,
                left: menuLeft,
                child: _buildActionMenuCard(
                  context: context,
                  dialogCtx: dialogCtx,
                  text: text,
                  isMe: isMe,
                  isPoll: isPoll,
                  canCopy: canCopy,
                  canForward: canForward,
                  isPinned: isPinned,
                  canRecall: canRecall,
                  menuWidth: menuWidth,
                  onReply: onReply,
                  onCopy: onCopy,
                  onForward: onForward,
                  onTogglePin: onTogglePin,
                  onRecall: onRecall,
                  onDelete: onDelete,
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (dialogCtx, anim, secAnim, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  static Widget _buildFloatingReactionBar({
    required BuildContext context,
    required BuildContext dialogCtx,
    required String? currentReactionId,
    required double barWidth,
    required ValueChanged<String> onReactionSelected,
  }) {
    return Container(
      width: barWidth,
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(
          color: context.isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.45 : 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: FbReaction.values.map((reaction) {
          final isSelected = currentReactionId == reaction.id;

          return Expanded(
            child: _ReactionItemButton(
              reaction: reaction,
              isSelected: isSelected,
              barWidth: barWidth,
              onTap: () {
                Navigator.pop(dialogCtx);
                HapticFeedback.lightImpact();
                onReactionSelected(reaction.id);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  static Widget _buildActionMenuCard({
    required BuildContext context,
    required BuildContext dialogCtx,
    required String text,
    required bool isMe,
    required bool isPoll,
    required bool canCopy,
    required bool canForward,
    required bool isPinned,
    required bool canRecall,
    required double menuWidth,
    required VoidCallback onReply,
    required VoidCallback onCopy,
    required VoidCallback onForward,
    required VoidCallback onTogglePin,
    required VoidCallback onRecall,
    required VoidCallback onDelete,
  }) {
    final l10n = context.l10n;

    if (isPoll) {
      return Container(
        width: menuWidth,
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xFF1E1E2C) : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: context.isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.4 : 0.16),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: buildMenuItem(
            context: context,
            icon: isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            title: isPinned ? l10n.unpinMessage : l10n.pinMessage,
            onTap: () {
              Navigator.pop(dialogCtx);
              onTogglePin();
            },
          ),
        ),
      );
    }

    return Container(
      width: menuWidth,
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: context.isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.4 : 0.16),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildMenuItem(
              context: context,
              icon: Icons.reply_rounded,
              title: l10n.reply,
              onTap: () {
                Navigator.pop(dialogCtx);
                onReply();
              },
            ),
            if (canCopy) ...[
              Divider(height: 1, color: context.dividerTheme),
              buildMenuItem(
                context: context,
                icon: Icons.copy_rounded,
                title: l10n.copy,
                onTap: () {
                  Navigator.pop(dialogCtx);
                  onCopy();
                },
              ),
            ],
            if (canForward) ...[
              Divider(height: 1, color: context.dividerTheme),
              buildMenuItem(
                context: context,
                icon: Icons.forward_rounded,
                title: l10n.forward,
                onTap: () {
                  Navigator.pop(dialogCtx);
                  onForward();
                },
              ),
            ],
            Divider(height: 1, color: context.dividerTheme),
            buildMenuItem(
              context: context,
              icon: isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              title: isPinned ? l10n.unpinMessage : l10n.pinMessage,
              onTap: () {
                Navigator.pop(dialogCtx);
                onTogglePin();
              },
            ),
            Divider(height: 1, color: context.dividerTheme),
            if (canRecall) ...[
              buildMenuItem(
                context: context,
                icon: Icons.undo_rounded,
                title: l10n.recallMessage,
                isDestructive: true,
                onTap: () {
                  Navigator.pop(dialogCtx);
                  onRecall();
                },
              ),
              Divider(height: 1, color: context.dividerTheme),
            ],
            buildMenuItem(
              context: context,
              icon: Icons.delete_outline_rounded,
              title: isMe ? l10n.deleteForMe : l10n.deleteMessage,
              isDestructive: true,
              onTap: () {
                Navigator.pop(dialogCtx);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final Color itemColor = isDestructive ? AppColors.red : context.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 40.h,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Icon(icon, size: 20.r, color: itemColor),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w500,
                      color: itemColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReactionItemButton extends StatefulWidget {
  final FbReaction reaction;
  final bool isSelected;
  final VoidCallback onTap;
  final double barWidth;

  const _ReactionItemButton({
    required this.reaction,
    required this.isSelected,
    required this.onTap,
    required this.barWidth,
  });

  @override
  State<_ReactionItemButton> createState() => _ReactionItemButtonState();
}

class _ReactionItemButtonState extends State<_ReactionItemButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final double iconSize = (widget.barWidth / 10.5).clamp(26.r, 32.r);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedScale(
          scale: _isHovered ? 1.35 : (widget.isSelected ? 1.15 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: Container(
            padding: EdgeInsets.all(4.r),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? widget.reaction.color.withValues(alpha: 0.18)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              widget.reaction.iconPath,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

