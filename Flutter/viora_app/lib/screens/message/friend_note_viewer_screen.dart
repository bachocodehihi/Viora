import '../../l10n/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/toast/app_toast.dart';

class FriendNoteViewerScreen extends StatefulWidget {
  final Map<String, dynamic> friend;
  final VoidCallback onOpenChat;
  final Future<bool> Function(String message)? onSendReply;

  const FriendNoteViewerScreen({
    super.key,
    required this.friend,
    required this.onOpenChat,
    this.onSendReply,
  });

  static Future<void> open({
    required BuildContext context,
    required Map<String, dynamic> friend,
    required VoidCallback onOpenChat,
    Future<bool> Function(String message)? onSendReply,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendNoteViewerScreen(
          friend: friend,
          onOpenChat: onOpenChat,
          onSendReply: onSendReply,
        ),
      ),
    );
  }

  @override
  State<FriendNoteViewerScreen> createState() => _FriendNoteViewerScreenState();
}

class _FriendNoteViewerScreenState extends State<FriendNoteViewerScreen> {
  late final TextEditingController _replyController;
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;
  String? _selectedEmoji;

  static const List<String> _quickReactions = ['\u{2764}\u{FE0F}', '😂', '😮', '😢', '🔥', '👏'];

  @override
  void initState() {
    super.initState();
    _replyController = TextEditingController();
    _replyController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _replyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSend(String text) async {
    final clean = text.trim();
    if (clean.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    final friendName = (widget.friend['name'] ?? l10n.friend).toString();

    bool success = false;
    if (widget.onSendReply != null) {
      success = await widget.onSendReply!(clean);
    }

    if (!mounted) return;
    setState(() {
      _isSending = false;
      _replyController.clear();
    });

    if (success) {
      AppToast.success(context, '${l10n.replySentTo} $friendName');
    } else {
      AppToast.error(context, l10n.cannotSendReply);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final friendName = (widget.friend['name'] ?? l10n.friend).toString();
    final displayName = friendName.isNotEmpty ? friendName.split(' ')[0] : l10n.you;
    final note = (widget.friend['note'] ?? '').toString().trim();
    final avatar = widget.friend['avatar'];
    final color = widget.friend['color'] as Color?;
    final showActiveStatus = widget.friend['showActiveStatus'] != false;
    final isOnline = widget.friend['online'] == true;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        appBar: AppBar(
          backgroundColor: context.scaffoldBg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: context.textPrimary,
              size: 20.r,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          titleSpacing: 0,
          title: Text(
            friendName,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          centerTitle: false,
        ),
        body: SafeArea(
          child: Column(
            children: [

              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        Container(
                          constraints: BoxConstraints(
                            minWidth: 140.w,
                            maxWidth: 320.w,
                            minHeight: 64.h,
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 16.h),
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            borderRadius: BorderRadius.circular(26.r),
                            border: Border.all(
                              color: AppColors.blue.withValues(alpha: 0.6),
                              width: 1.6,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.blue.withValues(alpha: 0.14),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              note.isNotEmpty ? note : '...',
                              style: TextStyle(
                                fontSize: 19.sp,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                        SizedBox(height: 5.h),
                        Container(
                          width: 10.r,
                          height: 10.r,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.cardBg,
                            border: Border.all(
                              color: AppColors.blue.withValues(alpha: 0.6),
                              width: 1.3,
                            ),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Container(
                          width: 6.r,
                          height: 6.r,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.cardBg,
                            border: Border.all(
                              color: AppColors.blue.withValues(alpha: 0.6),
                              width: 1.1,
                            ),
                          ),
                        ),

                        SizedBox(height: 10.h),

                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            widget.onOpenChat();
                          },
                          child: Column(
                            children: [
                              AppAvatar(
                                avatar: avatar,
                                name: friendName,
                                color: color,
                                radius: 44.r,
                                fontSize: 24.sp,
                                isOnline: showActiveStatus ? isOnline : null,
                                enableViewer: false,
                              ),
                              SizedBox(height: 10.h),
                              Text(
                                friendName,
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 3.h),
                              Text(
                                l10n.sharingThought24h,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: context.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 14.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _quickReactions.map((emoji) {
                        final isSelected = _selectedEmoji == emoji;
                        return GestureDetector(
                          onTap: _isSending
                              ? null
                              : () {
                                  setState(() => _selectedEmoji = emoji);
                                  _handleSend(emoji);
                                },
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedScale(
                            scale: isSelected ? 1.25 : 1.0,
                            duration: const Duration(milliseconds: 150),
                            child: SizedBox(
                              width: 44.r,
                              height: 44.r,
                              child: Center(
                                child: Text(
                                  emoji,
                                  style: TextStyle(fontSize: 26.sp),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    SizedBox(height: 12.h),

                    Row(
                      children: [

                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            focusNode: _focusNode,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: context.textPrimary,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: context.cardBg,
                              hintText: '${l10n.messageToPrefix} $displayName...',
                              hintStyle: TextStyle(
                                fontSize: 14.sp,
                                color: context.textMuted,
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24.r),
                                borderSide: BorderSide(
                                  color: context.borderTheme.withValues(alpha: 0.6),
                                  width: 1.2,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24.r),
                                borderSide: BorderSide(
                                  color: context.borderTheme.withValues(alpha: 0.6),
                                  width: 1.2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24.r),
                                borderSide: const BorderSide(
                                  color: AppColors.blue,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            onSubmitted: _handleSend,
                          ),
                        ),

                        SizedBox(width: 4.w),

                        if (_isSending)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10.w),
                            child: SizedBox(
                              width: 24.r,
                              height: 24.r,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.blue,
                              ),
                            ),
                          )
                        else
                          IconButton(
                            icon: Icon(
                              Icons.send_rounded,
                              color: AppColors.blue,
                              size: 28.r,
                            ),
                            splashRadius: 24.r,
                            onPressed: () {
                              final text = _replyController.text.trim();
                              if (text.isNotEmpty) {
                                _handleSend(text);
                              }
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserNoteOptionsSheet extends StatelessWidget {
  final String note;
  final String? userAvatar;
  final String userName;
  final VoidCallback onEditNote;
  final VoidCallback onDeleteNote;

  const UserNoteOptionsSheet({
    super.key,
    required this.note,
    this.userAvatar,
    required this.userName,
    required this.onEditNote,
    required this.onDeleteNote,
  });

  static Future<void> show({
    required BuildContext context,
    required String note,
    String? userAvatar,
    required String userName,
    required VoidCallback onEditNote,
    required VoidCallback onDeleteNote,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => UserNoteOptionsSheet(
        note: note,
        userAvatar: userAvatar,
        userName: userName,
        onEditNote: onEditNote,
        onDeleteNote: onDeleteNote,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
        border: Border.all(
          color: context.borderTheme.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10.h),
            Center(
              child: Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: context.textMuted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.yourNote,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: context.textMuted, size: 22.r),
                    splashRadius: 20.r,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            SizedBox(height: 6.h),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Container(
                constraints: BoxConstraints(
                  minWidth: 120.w,
                  maxWidth: 300.w,
                  minHeight: 52.h,
                ),
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: context.scaffoldBg,
                  borderRadius: BorderRadius.circular(22.r),
                  border: Border.all(
                    color: AppColors.blue.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.blue.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    note,
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                      height: 1.25,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

            SizedBox(height: 4.h),
            Container(
              width: 8.r,
              height: 8.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.scaffoldBg,
                border: Border.all(
                  color: AppColors.blue.withValues(alpha: 0.6),
                  width: 1.2,
                ),
              ),
            ),
            SizedBox(height: 3.h),
            Container(
              width: 5.r,
              height: 5.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.scaffoldBg,
                border: Border.all(
                  color: AppColors.blue.withValues(alpha: 0.6),
                  width: 1.0,
                ),
              ),
            ),

            SizedBox(height: 6.h),

            AppAvatar(
              avatar: userAvatar,
              name: userName,
              radius: 34.r,
              fontSize: 20.sp,
              enableViewer: false,
            ),
            SizedBox(height: 6.h),
            Text(
              userName,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            Text(
              l10n.noteWillExpireIn24h,
              style: TextStyle(
                fontSize: 11.5.sp,
                color: context.textMuted,
              ),
            ),

            SizedBox(height: 20.h),
            Divider(color: context.borderTheme.withValues(alpha: 0.5), height: 1),

            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.edit_note_rounded, color: AppColors.blue, size: 22.r),
              ),
              title: Text(
                l10n.leaveNewNote,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              subtitle: Text(
                l10n.updateCurrentThought,
                style: TextStyle(fontSize: 11.5.sp, color: context.textMuted),
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: context.textMuted),
              onTap: () {
                Navigator.pop(context);
                onEditNote();
              },
            ),

            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22.r),
              ),
              title: Text(
                l10n.deleteNote,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent,
                ),
              ),
              subtitle: Text(
                l10n.removeSharedThought,
                style: TextStyle(fontSize: 11.5.sp, color: context.textMuted),
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: context.textMuted),
              onTap: () {
                Navigator.pop(context);
                onDeleteNote();
              },
            ),

            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }
}
