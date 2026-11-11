import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../config/app_colors.dart';
import '../../../config/theme_helper.dart';
import '../../../l10n/language.dart';

class ChatCallBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final bool isPinned;
  final void Function(bool isVideo)? onCallBack;
  final VoidCallback? onJoinCall;

  const ChatCallBubble({
    super.key,
    required this.msg,
    required this.isMe,
    this.isPinned = false,
    this.onCallBack,
    this.onJoinCall,
  });

  static Map<String, dynamic> _extractCallMap(Map<String, dynamic> msg) {
    final raw = msg['call'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }

  static String formatDuration(BuildContext context, int seconds) {
    final l10n = context.l10n;
    final safeSecs = seconds < 0 ? 0 : seconds;
    final hrs = safeSecs ~/ 3600;
    final mins = (safeSecs % 3600) ~/ 60;
    final secs = safeSecs % 60;

    final bool compactEn = l10n.callDurationSecUnit.length == 1;
    final hUnit = l10n.callDurationHourUnit;
    final mUnit = l10n.callDurationMinUnit;
    final sUnit = l10n.callDurationSecUnit;
    final sp = compactEn ? '' : ' ';

    if (hrs > 0) {
      if (mins > 0) return '$hrs$sp$hUnit $mins$sp$mUnit';
      return '$hrs$sp$hUnit';
    }
    if (mins > 0) {
      if (secs > 0) return '$mins$sp$mUnit $secs$sp$sUnit';
      return '$mins$sp$mUnit';
    }
    return '$secs$sp$sUnit';
  }

  static ({String title, String subtitle, bool isMissedAccent, bool isOngoing, bool isVideo}) describeCall(
    BuildContext context,
    Map<String, dynamic> msg, {
    required bool isMe,
  }) {
    final l10n = context.l10n;
    final call = _extractCallMap(msg);
    final isVideo = call['callType']?.toString() == 'video';
    final status = call['status']?.toString() ?? 'completed';
    final duration = int.tryParse(call['duration']?.toString() ?? '') ?? 0;

    if (status == 'ringing' || status == 'ongoing') {
      return (
        title: isVideo ? l10n.videoCallTitle : l10n.voiceCallTitle,
        subtitle: l10n.callOngoingShort,
        isMissedAccent: false,
        isOngoing: true,
        isVideo: isVideo,
      );
    }

    if (status == 'completed') {
      return (
        title: isVideo ? l10n.videoCallTitle : l10n.voiceCallTitle,
        subtitle: formatDuration(context, duration),
        isMissedAccent: false,
        isOngoing: false,
        isVideo: isVideo,
      );
    }

    if (status == 'declined') {
      if (isMe) {
        return (
          title: isVideo ? l10n.videoCallTitle : l10n.voiceCallTitle,
          subtitle: l10n.callDeclinedShort,
          isMissedAccent: false,
          isOngoing: false,
          isVideo: isVideo,
        );
      }
      return (
        title: isVideo ? l10n.videoCallTitle : l10n.voiceCallTitle,
        subtitle: l10n.youDeclinedCall,
        isMissedAccent: true,
        isOngoing: false,
        isVideo: isVideo,
      );
    }

    if (status == 'cancelled') {
      if (isMe) {
        return (
          title: isVideo ? l10n.videoCallTitle : l10n.voiceCallTitle,
          subtitle: l10n.callCancelledShort,
          isMissedAccent: false,
          isOngoing: false,
          isVideo: isVideo,
        );
      }
      return (
        title: isVideo ? l10n.missedVideoCall : l10n.missedVoiceCall,
        subtitle: l10n.tapToCallBack,
        isMissedAccent: true,
        isOngoing: false,
        isVideo: isVideo,
      );
    }

    // 'missed' (or unknown fallback)
    if (isMe) {
      return (
        title: isVideo ? l10n.videoCallTitle : l10n.voiceCallTitle,
        subtitle: l10n.callNoAnswerStatus,
        isMissedAccent: false,
        isOngoing: false,
        isVideo: isVideo,
      );
    }
    return (
      title: isVideo ? l10n.missedVideoCall : l10n.missedVoiceCall,
      subtitle: l10n.tapToCallBack,
      isMissedAccent: true,
      isOngoing: false,
      isVideo: isVideo,
    );
  }

  static String formatSummary(
    BuildContext context,
    Map<String, dynamic> msg, {
    required bool isMe,
  }) {
    final desc = describeCall(context, msg, isMe: isMe);
    final call = _extractCallMap(msg);
    final status = call['status']?.toString() ?? 'completed';
    if ((status == 'missed' || status == 'cancelled') && !isMe) {
      return desc.title;
    }
    return '${desc.title} • ${desc.subtitle}';
  }

  static String formatListPreview(
    BuildContext context,
    Map<String, dynamic> msg, {
    required bool isMe,
    required bool isGroup,
    String? senderName,
  }) {
    final l10n = context.l10n;
    final call = _extractCallMap(msg);
    final isVideo = call['callType']?.toString() == 'video';
    final status = call['status']?.toString() ?? 'completed';
    final duration = int.tryParse(call['duration']?.toString() ?? '') ?? 0;

    final String prefix = isGroup
        ? (isMe
            ? '${l10n.you}: '
            : ((senderName != null && senderName.trim().isNotEmpty)
                ? '${senderName.trim()}: '
                : ''))
        : (isMe ? '${l10n.you}: ' : '');

    if (status == 'ringing' || status == 'ongoing') {
      final title = isVideo ? l10n.videoCallTitle : l10n.voiceCallTitle;
      return '$prefix$title • ${l10n.callOngoingShort}';
    }

    if (status == 'completed') {
      final title = isVideo ? l10n.videoCallTitle : l10n.voiceCallTitle;
      return '$prefix$title • ${formatDuration(context, duration)}';
    }

    if (status == 'declined') {
      if (!isMe && !isGroup) {
        return isVideo ? l10n.declinedVideoCall : l10n.declinedVoiceCall;
      }
      final title = isVideo ? l10n.videoCallTitle : l10n.voiceCallTitle;
      return '$prefix$title • ${l10n.callDeclinedShort}';
    }

    if (status == 'cancelled') {
      if (!isMe) {
        final missed = isVideo ? l10n.missedVideoCall : l10n.missedVoiceCall;
        return isGroup ? '$prefix$missed' : missed;
      }
      final title = isVideo ? l10n.videoCallTitle : l10n.voiceCallTitle;
      return '$prefix$title • ${l10n.callCancelledShort}';
    }

    // missed
    if (!isMe) {
      final missed = isVideo ? l10n.missedVideoCall : l10n.missedVoiceCall;
      return isGroup ? '$prefix$missed' : missed;
    }
    final title = isVideo ? l10n.videoCallTitle : l10n.voiceCallTitle;
    return '$prefix$title • ${l10n.callNoAnswerStatus}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final desc = describeCall(context, msg, isMe: isMe);

    final IconData iconData;
    if (desc.isOngoing) {
      iconData = desc.isVideo ? Icons.videocam_rounded : Icons.phone_in_talk_rounded;
    } else if (desc.isMissedAccent && !isMe) {
      iconData = desc.isVideo ? Icons.missed_video_call_rounded : Icons.phone_missed_rounded;
    } else if (desc.isVideo) {
      iconData = Icons.videocam_rounded;
    } else if (isMe) {
      iconData = Icons.call_made_rounded;
    } else {
      iconData = Icons.call_received_rounded;
    }

    final Color badgeBgColor = desc.isOngoing
        ? (isMe ? Colors.white.withValues(alpha: 0.24) : const Color(0xFF22C55E).withValues(alpha: 0.16))
        : (isMe
            ? Colors.white.withValues(alpha: 0.22)
            : (desc.isMissedAccent
                ? AppColors.red.withValues(alpha: 0.14)
                : AppColors.blue.withValues(alpha: 0.12)));

    final Color badgeIconColor = desc.isOngoing
        ? (isMe ? Colors.white : const Color(0xFF16A34A))
        : (isMe
            ? Colors.white
            : (desc.isMissedAccent ? AppColors.red : AppColors.blue));

    final Color titleColor = isMe
        ? Colors.white
        : (desc.isMissedAccent ? AppColors.red : context.textPrimary);

    final Color subtitleColor = desc.isOngoing
        ? (isMe ? Colors.white.withValues(alpha: 0.92) : const Color(0xFF16A34A))
        : (isMe ? Colors.white.withValues(alpha: 0.85) : context.textMuted);

    final Color buttonBgColor = desc.isOngoing
        ? (isMe ? Colors.white : const Color(0xFF22C55E))
        : (isMe
            ? Colors.white.withValues(alpha: 0.20)
            : (desc.isMissedAccent
                ? AppColors.red.withValues(alpha: 0.10)
                : (context.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05))));

    final Color buttonFgColor = desc.isOngoing
        ? (isMe ? const Color(0xFF15803D) : Colors.white)
        : (isMe
            ? Colors.white
            : (desc.isMissedAccent ? AppColors.red : context.textPrimary));

    final VoidCallback? actionCallback = desc.isOngoing
        ? onJoinCall
        : (onCallBack != null ? () => onCallBack!(desc.isVideo) : null);

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38.r,
                height: 38.r,
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconData,
                  size: 19.r,
                  color: badgeIconColor,
                ),
              ),
              SizedBox(width: 10.w),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      desc.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (desc.isOngoing) ...[
                          Container(
                            width: 6.r,
                            height: 6.r,
                            decoration: BoxDecoration(
                              color: isMe ? const Color(0xFF86EFAC) : const Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 5.w),
                        ],
                        Flexible(
                          child: Text(
                            desc.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5.sp,
                              color: subtitleColor,
                              fontWeight: desc.isOngoing ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actionCallback != null) ...[
            SizedBox(height: 10.h),
            Material(
              color: buttonBgColor,
              borderRadius: BorderRadius.circular(10.r),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(10.r),
                onTap: actionCallback,
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 7.5.h, horizontal: 10.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          desc.isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                          size: 14.r,
                          color: buttonFgColor,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          desc.isOngoing ? l10n.joinCall : l10n.callBack,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: buttonFgColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
  }
}
