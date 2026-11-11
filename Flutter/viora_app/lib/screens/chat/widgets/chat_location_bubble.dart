import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../config/app_colors.dart';
import '../../../config/theme_helper.dart';
import '../../../l10n/language.dart';

class ChatLocationBubble extends StatelessWidget {
  final bool isMe;
  final double? lat;
  final double? lng;
  final String name;
  final String address;
  final bool isPinned;
  final bool isLive;
  final VoidCallback? onTap;

  const ChatLocationBubble({
    super.key,
    required this.isMe,
    required this.lat,
    required this.lng,
    required this.name,
    required this.address,
    required this.isPinned,
    required this.isLive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String statusLabel = isLive ? l10n.sharingLive : l10n.stoppedSharingLocation;
    final String subLabel = isLive
        ? (address.isNotEmpty ? address : (name.isNotEmpty ? name : l10n.realtimeUpdates))
        : l10n.liveLocationSessionEnded;

    final content = Padding(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                isLive ? Icons.share_location_rounded : Icons.location_off_rounded,
                size: 16.r,
                color: isLive
                    ? (isMe ? Colors.white : const Color(0xFF00C853))
                    : (isMe ? Colors.white70 : const Color(0xFFE53935)),
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.white : context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            subLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5.sp,
              height: 1.25,
              color: isMe ? Colors.white.withValues(alpha: 0.85) : context.textMuted,
            ),
          ),
          if (isLive) ...[
            SizedBox(height: 10.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 7.5.h),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.22)
                    : AppColors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.35)
                      : AppColors.blue.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.near_me_rounded,
                    size: 14.r,
                    color: isMe ? Colors.white : AppColors.blue,
                  ),
                  SizedBox(width: 5.w),
                  Text(
                    l10n.viewLiveLocation,
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: isMe ? Colors.white : AppColors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isPinned)
            Padding(
              padding: EdgeInsets.only(top: 6.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.push_pin_rounded,
                    size: 11.r,
                    color: isMe ? Colors.white70 : AppColors.blue,
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    l10n.pinned,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: isMe ? Colors.white70 : AppColors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    return GestureDetector(
      onTap: isLive ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}

