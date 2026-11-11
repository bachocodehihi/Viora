import '../../../services/socket_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../config/app_colors.dart';
import '../../../config/theme_helper.dart';
import '../../../l10n/language.dart';
import '../../../widgets/app_avatar.dart';

class ChatPollBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final String messageId;
  final String currentUserId;
  final void Function(String optionId) onVote;
  final List<Map<String, dynamic>> Function(Map<String, dynamic> option) resolveVoters;

  const ChatPollBubble({
    super.key,
    required this.msg,
    required this.isMe,
    required this.messageId,
    required this.currentUserId,
    required this.onVote,
    required this.resolveVoters,
  });

  void _showSingleOptionVotersSheet(BuildContext context, String optionText, List<Map<String, dynamic>> voters) {
    final l10n = context.l10n;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: 0.7.sh),
          decoration: BoxDecoration(
            color: ctx.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    margin: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      color: ctx.dividerTheme.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(6.r),
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(Icons.how_to_vote_rounded, size: 18.r, color: AppColors.blue),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              optionText,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                                color: ctx.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              '${voters.length} ${l10n.pollVotesCount}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: ctx.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                Divider(height: 1, color: ctx.dividerTheme.withValues(alpha: 0.3)),
                if (voters.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 36.h, horizontal: 20.w),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 40.r, color: ctx.textMuted),
                          SizedBox(height: 10.h),
                          Text(
                            l10n.noVotesYet,
                            style: TextStyle(
                              fontSize: 13.5.sp,
                              color: ctx.textMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      itemCount: voters.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 12.h,
                        thickness: 0.5,
                        color: ctx.dividerTheme.withValues(alpha: 0.25),
                      ),
                      itemBuilder: (c, idx) {
                        final v = voters[idx];
                        final vName = (v['username'] ?? '').toString();
                        final vAvatar = (v['avatar'] ?? '').toString();
                        final effectiveMyId = currentUserId.isNotEmpty ? currentUserId : (SocketService.currentUserId ?? '');
                        final bool isMyVote = v['id']?.toString() == effectiveMyId;

                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 4.h),
                          child: Row(
                            children: [
                              AppAvatar(
                                avatar: vAvatar,
                                name: vName,
                                radius: 18.r,
                                fontSize: 13.sp,
                                enableViewer: false,
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  isMyVote ? '$vName (${l10n.you})' : vName,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: isMyVote ? FontWeight.bold : FontWeight.w500,
                                    color: ctx.textPrimary,
                                  ),
                                ),
                              ),
                              if (isMyVote)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                  decoration: BoxDecoration(
                                    color: AppColors.blue.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Text(
                                    l10n.you,
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.blue,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                SizedBox(height: 12.h),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final poll = msg['poll'] is Map ? Map<String, dynamic>.from(msg['poll']) : <String, dynamic>{};
    final String question = (poll['question'] ?? msg['text'] ?? msg['content'] ?? '').toString();
    final bool isMultiple = poll['multipleAnswers'] == true;
    final bool isClosed = poll['isClosed'] == true;
    final rawOptions = poll['options'] is List ? (poll['options'] as List) : [];
    final List<Map<String, dynamic>> options = rawOptions.map((o) => Map<String, dynamic>.from(o is Map ? o : {})).toList();
    final int totalVotes = (poll['totalVotes'] as num?)?.toInt() ??
        options.fold<int>(0, (sum, o) => sum + ((o['voterIds'] as List?)?.length ?? (o['voteCount'] as num?)?.toInt() ?? 0));
    final String myId = currentUserId;

    return Container(
      padding: EdgeInsets.all(14.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.poll_rounded, color: AppColors.blue, size: 16.r),
              ),
              SizedBox(width: 8.w),
              Text(
                l10n.poll,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.blue,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: context.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  isMultiple ? l10n.pollSelectMultiple : l10n.pollSelectOne,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    color: context.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          Text(
            question,
            style: TextStyle(
              fontSize: 14.5.sp,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
              height: 1.3,
            ),
          ),
          SizedBox(height: 12.h),

          ...options.asMap().entries.map((entry) {
            final int optIdx = entry.key;
            final opt = entry.value;
            final bool isLast = optIdx == options.length - 1;
            final String optId = opt['id']?.toString() ?? '';
            final String optText = opt['text']?.toString() ?? '';

            final Set<String> voterIdSet = {};
            if (opt['voterIds'] is List) {
              for (var v in opt['voterIds']) {
                if (v is Map) {
                  final id = (v['id'] ?? v['_id'])?.toString();
                  if (id != null && id.isNotEmpty) voterIdSet.add(id);
                } else if (v != null) {
                  voterIdSet.add(v.toString());
                }
              }
            }
            if (opt['voters'] is List) {
              for (var v in opt['voters']) {
                if (v is Map) {
                  final id = (v['id'] ?? v['_id'])?.toString();
                  if (id != null && id.isNotEmpty) voterIdSet.add(id);
                } else if (v != null) {
                  voterIdSet.add(v.toString());
                }
              }
            }

            final effectiveMyId = myId.isNotEmpty ? myId : (SocketService.currentUserId ?? '');
            final bool hasVoted = effectiveMyId.isNotEmpty && voterIdSet.contains(effectiveMyId);
            final int voteCount = voterIdSet.isNotEmpty ? voterIdSet.length : ((opt['voteCount'] as num?)?.toInt() ?? 0);
            final double percent = totalVotes > 0 ? (voteCount / totalVotes) : 0.0;
            final int percentInt = (percent * 100).round();

            return Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 8.h),
              decoration: BoxDecoration(
                color: hasVoted
                    ? AppColors.blue.withValues(alpha: 0.08)
                    : (context.isDark ? const Color(0xFF262638) : Colors.grey.withValues(alpha: 0.08)),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: hasVoted
                      ? AppColors.blue
                      : context.dividerTheme.withValues(alpha: 0.5),
                  width: hasVoted ? 1.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11.r),
                child: InkWell(
                  onTap: isClosed ? null : () => onVote(optId),
                  child: Stack(
                    children: [
                      if (totalVotes > 0)
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: percent.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: (hasVoted ? AppColors.blue : context.textMuted).withValues(alpha: 0.14),
                              ),
                            ),
                          ),
                        ),

                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                        child: Row(
                          children: [
                            Icon(
                              hasVoted
                                  ? (isMultiple ? Icons.check_box_rounded : Icons.radio_button_checked_rounded)
                                  : (isMultiple ? Icons.check_box_outline_blank_rounded : Icons.radio_button_off_rounded),
                              size: 18.r,
                              color: hasVoted ? AppColors.blue : context.textMuted,
                            ),
                            SizedBox(width: 10.w),

                            Expanded(
                              child: Text(
                                optText,
                                style: TextStyle(
                                  fontSize: 13.5.sp,
                                  fontWeight: hasVoted ? FontWeight.w600 : FontWeight.normal,
                                  color: hasVoted ? AppColors.blue : context.textPrimary,
                                ),
                              ),
                            ),

                            if (totalVotes > 0) ...[
                              Text(
                                '$percentInt%',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                  color: hasVoted ? AppColors.blue : context.textMuted,
                                ),
                              ),
                              SizedBox(width: 4.w),
                            ],

                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                final resolved = resolveVoters(opt);
                                _showSingleOptionVotersSheet(context, optText, resolved);
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 2.h),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20.r,
                                  color: context.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

