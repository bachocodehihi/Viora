import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../config/app_colors.dart';
import '../../../config/theme_helper.dart';
import '../../../l10n/language.dart';
import 'chat_call_bubble.dart';

class ChatPinnedBanner extends StatelessWidget {
  final List<Map<String, dynamic>> pinnedMessages;
  final String? currentUserId;
  final String defaultOtherName;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onTapMessage;
  final VoidCallback onOpenPinList;
  final ValueChanged<Map<String, dynamic>> onUnpinMessage;

  const ChatPinnedBanner({
    super.key,
    required this.pinnedMessages,
    this.currentUserId,
    required this.defaultOtherName,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onTapMessage,
    required this.onOpenPinList,
    required this.onUnpinMessage,
  });

  static String formatPinnedPreviewText(BuildContext context, Map<String, dynamic> msg) {
    final l10n = context.l10n;
    final type = msg['type']?.toString() ?? 'text';
    final rawText = (msg['text'] ?? msg['content'] ?? '').toString().trim();
    final lowerText = rawText.toLowerCase();

    if (msg['isRecalled'] == true) {
      return l10n.messageHasBeenRecalled;
    }

    final hasAttachments = (msg['attachments'] is List && (msg['attachments'] as List).isNotEmpty) ||
        msg['imageUrl'] != null;

    if (type == 'image' || hasAttachments) {
      final bool hasCaption = rawText.isNotEmpty && !Language.isImagePlaceholder(rawText);
      return hasCaption ? rawText : l10n.imageCaptionPlaceholder;
    }

    if (type == 'poll') {
      final question = (msg['poll'] is Map ? msg['poll']['question'] : null) ?? rawText;
      return '[${l10n.poll}] $question';
    }

    if (type == 'location') {
      final loc = msg['location'];
      final locName = (loc is Map) ? (loc['name'] ?? loc['address'] ?? '') : '';
      return '${l10n.locationPrefix} ${locName.isNotEmpty ? locName : (rawText.isNotEmpty ? rawText : l10n.sharedLocation)}';
    }

    if (type == 'call' || msg['call'] != null) {
      return ChatCallBubble.formatSummary(
        context,
        msg,
        isMe: msg['isMe'] == true,
      );
    }

    return rawText;
  }

  @override
  Widget build(BuildContext context) {
    if (pinnedMessages.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final latest = pinnedMessages.last;
    final String senderId = (latest['senderId'] ?? '').toString();
    final bool isPinnedFromMe = (senderId.isNotEmpty && currentUserId != null && senderId == currentUserId) ||
        (latest['isMe'] == true && (senderId.isEmpty || currentUserId == null));
    final String senderName = isPinnedFromMe
        ? l10n.you
        : ((latest['senderName'] ?? '').toString().isNotEmpty
            ? (latest['senderName']).toString()
            : defaultOtherName);
    final int count = pinnedMessages.length;

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 6.h),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: context.isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.35 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12.r),
              onTap: () {
                final latestId = (latest['id'] ?? latest['_id'])?.toString();
                if (latestId != null) onTapMessage(latestId);
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6.r),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.push_pin_rounded,
                        size: 15.r,
                        color: AppColors.blue,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                count > 1 ? '${l10n.pinnedMessageTitle} ($count)' : l10n.pinnedMessageTitle,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.blue,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Flexible(
                                child: Text(
                                  '• $senderName',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: context.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            formatPinnedPreviewText(context, latest),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: context.isDark ? Colors.white.withValues(alpha: 0.85) : context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 4.w),
                    if (count > 1)
                      GestureDetector(
                        onTap: onToggleExpanded,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: EdgeInsets.all(4.r),
                          child: Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 20.r,
                            color: AppColors.blue,
                          ),
                        ),
                      ),
                    GestureDetector(
                      onTap: onOpenPinList,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: EdgeInsets.all(4.r),
                        child: Icon(
                          Icons.format_list_bulleted_rounded,
                          size: 17.r,
                          color: context.textMuted,
                        ),
                      ),
                    ),
                    SizedBox(width: 2.w),
                    GestureDetector(
                      onTap: () => onUnpinMessage(latest),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: EdgeInsets.all(4.r),
                        decoration: BoxDecoration(
                          color: context.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14.r,
                          color: context.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded && count > 1) ...[
            Divider(height: 1, color: context.dividerTheme),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 180.h),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: pinnedMessages.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: context.dividerTheme),
                itemBuilder: (context, idx) {
                  final msg = pinnedMessages[pinnedMessages.length - 1 - idx];
                  final mSenderId = (msg['senderId'] ?? '').toString();
                  final mIsMe = (mSenderId.isNotEmpty && currentUserId != null && mSenderId == currentUserId) ||
                      (msg['isMe'] == true && (mSenderId.isEmpty || currentUserId == null));
                  final mSenderName = mIsMe
                      ? l10n.you
                      : ((msg['senderName'] ?? '').toString().isNotEmpty
                          ? msg['senderName'].toString()
                          : defaultOtherName);
                  final mTime = (msg['time'] ?? '').toString();
                  final msgId = (msg['id'] ?? msg['_id'])?.toString();

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8.r),
                      onTap: () {
                        if (msgId != null) {
                          onTapMessage(msgId);
                        }
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 8.h),
                        child: Row(
                          children: [
                            Icon(
                              Icons.push_pin_rounded,
                              size: 13.r,
                              color: AppColors.blue.withValues(alpha: 0.7),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        mSenderName,
                                        style: TextStyle(
                                          fontSize: 11.5.sp,
                                          fontWeight: FontWeight.bold,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                      if (mTime.isNotEmpty) ...[
                                        SizedBox(width: 4.w),
                                        Text(
                                          '• $mTime',
                                          style: TextStyle(
                                            fontSize: 10.sp,
                                            color: context.textMuted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    formatPinnedPreviewText(context, msg),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5.sp,
                                      color: context.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 6.w),
                            GestureDetector(
                              onTap: () => onUnpinMessage(msg),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: EdgeInsets.all(4.r),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 14.r,
                                  color: context.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

