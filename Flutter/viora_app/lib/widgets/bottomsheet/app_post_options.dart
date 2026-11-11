import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../services/contact_service.dart';
import '../../services/post_service.dart';
import '../../services/session_service.dart';
import '../app_avatar.dart';
import '../toast/app_toast.dart';

class AppPostOptionsBottomSheet extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onNotInterested;
  final VoidCallback? onPostDeleted;
  final Function(bool commentsDisabled)? onCommentsStatusChanged;
  final Function(Map<String, dynamic> newSettings)? onCommentSettingsChanged;
  final BuildContext? parentContext;

  const AppPostOptionsBottomSheet({
    super.key,
    required this.post,
    this.onNotInterested,
    this.onPostDeleted,
    this.onCommentsStatusChanged,
    this.onCommentSettingsChanged,
    this.parentContext,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> post,
    VoidCallback? onNotInterested,
    VoidCallback? onPostDeleted,
    Function(bool commentsDisabled)? onCommentsStatusChanged,
    Function(Map<String, dynamic> newSettings)? onCommentSettingsChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppPostOptionsBottomSheet(
        post: post,
        onNotInterested: onNotInterested,
        onPostDeleted: onPostDeleted,
        onCommentsStatusChanged: onCommentsStatusChanged,
        onCommentSettingsChanged: onCommentSettingsChanged,
        parentContext: context,
      ),
    );
  }

  @override
  State<AppPostOptionsBottomSheet> createState() => _AppPostOptionsBottomSheetState();
}

class _AppPostOptionsBottomSheetState extends State<AppPostOptionsBottomSheet> {
  bool _isOwner = false;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _checkOwnership();
  }

  Future<void> _checkOwnership() async {
    _myUserId = await SessionService.getUserId();
    final postUserId = widget.post['userId']?.toString() ??
        (widget.post['author'] is Map ? widget.post['author']['_id']?.toString() : null) ??
        widget.post['author']?.toString();

    final isOwnerFlag = widget.post['isOwner'] == true;
    final idMatches = _myUserId != null && postUserId != null && _myUserId == postUserId;

    if (mounted) {
      setState(() {
        _isOwner = isOwnerFlag || idMatches;
      });
    }
  }

  String get _postId => (widget.post['id'] ?? widget.post['_id'] ?? '').toString();
  bool get _commentsDisabled => widget.post['commentsDisabled'] == true;
  String get _commentPermission => widget.post['commentPermission']?.toString() ?? 'everyone';

  Future<void> _handleNotInterested() async {
    final rootContext = widget.parentContext ?? context;
    final l10n = rootContext.l10n;
    Navigator.pop(context);

    widget.onNotInterested?.call();
    if (rootContext.mounted) {
      AppToast.show(
        rootContext,
        l10n.postHiddenToast,
      );
    }

    await PostService.notInterestedPost(_postId);
  }

  void _openReportDialog() {
    final rootContext = widget.parentContext ?? context;
    final l10n = context.l10n;
    Navigator.pop(context);

    final reasons = [
      l10n.postReportReasonSpam,
      l10n.postReportReasonHarassment,
      l10n.postReportReasonFalseInfo,
      l10n.postReportReasonViolence,
      l10n.postReportReasonNudity,
      l10n.postReportReasonPrivacy,
      l10n.postReportReasonOther,
    ];

    int selectedIndex = 0;
    final detailsController = TextEditingController();

    showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.textMuted.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.flag_rounded, color: AppColors.red, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        l10n.reportPost,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.reportReasonPrompt,
                    style: TextStyle(fontSize: 13, color: context.textMuted),
                  ),
                  const SizedBox(height: 14),
                  ...List.generate(reasons.length, (idx) {
                    final isSelected = selectedIndex == idx;
                    return InkWell(
                      onTap: () => setModalState(() => selectedIndex = idx),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.blue.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.blue : context.borderTheme,
                            width: isSelected ? 1.5 : 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              size: 18,
                              color: isSelected ? AppColors.blue : context.textMuted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                reasons[idx],
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected ? AppColors.blue : context.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  TextField(
                    controller: detailsController,
                    style: TextStyle(fontSize: 13.5, color: context.textPrimary),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: l10n.reportDetailsHint,
                      hintStyle: TextStyle(fontSize: 13, color: context.textMuted),
                      filled: true,
                      fillColor: context.isDark ? const Color(0xFF1B1B26) : Colors.grey.withValues(alpha: 0.08),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: context.borderTheme),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: context.borderTheme),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final reason = reasons[selectedIndex];
                        final details = detailsController.text.trim();
                        final success = await PostService.reportPost(
                          postId: _postId,
                          reason: reason,
                          details: details.isNotEmpty ? details : null,
                        );
                        if (rootContext.mounted) {
                          if (success) {
                            AppToast.show(
                              rootContext,
                              l10n.reportSubmittedReview,
                            );
                          } else {
                            AppToast.show(
                              rootContext,
                              l10n.reportFailedToast,
                              isError: true,
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        l10n.submitReport,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleToggleComments() async {
    Navigator.pop(context);
    final l10n = context.l10n;
    final targetState = !_commentsDisabled;

    final res = await PostService.toggleComments(_postId, commentsDisabled: targetState);
    if (res != null && res['success'] == true) {
      widget.post['commentsDisabled'] = targetState;
      widget.onCommentsStatusChanged?.call(targetState);
      if (mounted) {
        AppToast.show(
          context,
          targetState ? l10n.commentsDisabledToast : l10n.commentsEnabledToast,
        );
      }
    } else {
      if (mounted) {
        AppToast.show(
          context,
          l10n.failedToUpdateCommentStatus,
          isError: true,
        );
      }
    }
  }

  void _openCommentSettings() {
    Navigator.pop(context);
    final l10n = context.l10n;

    String currentPermission = _commentPermission;
    List<String> allowedCommenters = List<String>.from(widget.post['allowedCommenters'] ?? []);
    List<String> blockedCommenters = List<String>.from(widget.post['blockedCommenters'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.textMuted.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: AppColors.blue, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        l10n.commentSettings,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.chooseWhoCanComment,
                    style: TextStyle(fontSize: 13, color: context.textMuted),
                  ),
                  const SizedBox(height: 14),

                  _buildAudienceTile(
                    title: l10n.everyone,
                    subtitle: l10n.everyoneDesc,
                    icon: Icons.public_rounded,
                    isSelected: currentPermission == 'everyone',
                    onTap: () => setModalState(() => currentPermission = 'everyone'),
                  ),

                  _buildAudienceTile(
                    title: l10n.friends,
                    subtitle: l10n.friendsDesc,
                    icon: Icons.people_alt_rounded,
                    isSelected: currentPermission == 'friends',
                    onTap: () => setModalState(() => currentPermission = 'friends'),
                  ),

                  _buildAudienceTile(
                    title: l10n.selectedAccountsOnly,
                    subtitle: allowedCommenters.isEmpty
                        ? l10n.tapToSelectCommenters
                        : l10n.accountsSelectedCount.replaceAll('{count}', allowedCommenters.length.toString()),
                    icon: Icons.checklist_rounded,
                    isSelected: currentPermission == 'selected',
                    trailing: currentPermission == 'selected'
                        ? TextButton(
                            onPressed: () => _openSelectFriendsDialog(
                              initialSelected: allowedCommenters,
                              onSaved: (newList) {
                                setModalState(() => allowedCommenters = newList);
                              },
                            ),
                            child: Text(l10n.selectPerson),
                          )
                        : null,
                    onTap: () {
                      setModalState(() => currentPermission = 'selected');
                      if (allowedCommenters.isEmpty) {
                        _openSelectFriendsDialog(
                          initialSelected: allowedCommenters,
                          onSaved: (newList) {
                            setModalState(() => allowedCommenters = newList);
                          },
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 12),
                  Divider(color: context.borderTheme, height: 1),
                  const SizedBox(height: 12),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.block_rounded, color: Colors.red, size: 20),
                    ),
                    title: Text(
                      l10n.blockedCommenters,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      blockedCommenters.isEmpty
                          ? l10n.noOneBlocked
                          : l10n.accountsBlockedCount.replaceAll('{count}', blockedCommenters.length.toString()),
                      style: TextStyle(fontSize: 12, color: context.textMuted),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.textMuted),
                    onTap: () => _openManageBlockedDialog(
                      initialBlocked: blockedCommenters,
                      onSaved: (newList) {
                        setModalState(() => blockedCommenters = newList);
                      },
                    ),
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final success = await PostService.updateCommentSettings(
                          postId: _postId,
                          commentPermission: currentPermission,
                          allowedCommenters: allowedCommenters,
                          blockedCommenters: blockedCommenters,
                        );
                        if (context.mounted) {
                          if (success) {
                            widget.post['commentPermission'] = currentPermission;
                            widget.post['allowedCommenters'] = allowedCommenters;
                            widget.post['blockedCommenters'] = blockedCommenters;
                            widget.onCommentSettingsChanged?.call({
                              'commentPermission': currentPermission,
                              'allowedCommenters': allowedCommenters,
                              'blockedCommenters': blockedCommenters,
                            });
                            AppToast.show(
                              context,
                              l10n.commentSettingsUpdatedSuccess,
                            );
                          } else {
                            AppToast.show(
                              context,
                              l10n.failedToUpdateCommentStatus,
                              isError: true,
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        l10n.saveChanges,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAudienceTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.blue : context.borderTheme,
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: isSelected ? AppColors.blue : context.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.blue : context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: context.textMuted),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_off,
                  size: 20,
                  color: isSelected ? AppColors.blue : context.textMuted,
                ),
          ],
        ),
      ),
    );
  }

  void _openSelectFriendsDialog({
    required List<String> initialSelected,
    required Function(List<String>) onSaved,
  }) async {
    final l10n = context.l10n;
    final contactsData = await ContactService.fetchContacts();
    final friendsList = (contactsData?['friends'] as List?) ?? [];

    if (!mounted) return;

    final selected = Set<String>.from(initialSelected);

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: context.cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              l10n.selectAllowedCommenters,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: friendsList.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noFriendsFound,
                        style: TextStyle(color: context.textMuted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: friendsList.length,
                      itemBuilder: (context, idx) {
                        final friend = friendsList[idx] as Map<String, dynamic>;
                        final fId = (friend['_id'] ?? friend['id'] ?? '').toString();
                        final fName = friend['username'] ?? friend['name'] ?? l10n.user;
                        final fAvatar = friend['avatar'];
                        final isChecked = selected.contains(fId);

                        return CheckboxListTile(
                          value: isChecked,
                          onChanged: (val) {
                            setDlgState(() {
                              if (val == true) {
                                selected.add(fId);
                              } else {
                                selected.remove(fId);
                              }
                            });
                          },
                          secondary: AppAvatar(avatar: fAvatar, name: fName, radius: 18),
                          title: Text(
                            fName,
                            style: TextStyle(fontSize: 14, color: context.textPrimary, fontWeight: FontWeight.w600),
                          ),
                          activeColor: AppColors.blue,
                          contentPadding: EdgeInsets.zero,
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: Text(l10n.cancel, style: TextStyle(color: context.textMuted)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dlgCtx);
                  onSaved(selected.toList());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('${l10n.confirm} (${selected.length})'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openManageBlockedDialog({
    required List<String> initialBlocked,
    required Function(List<String>) onSaved,
  }) async {
    final l10n = context.l10n;
    final contactsData = await ContactService.fetchContacts();
    final friendsList = (contactsData?['friends'] as List?) ?? [];

    if (!mounted) return;
    final blocked = Set<String>.from(initialBlocked);

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: context.cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              l10n.blockCommentersTitle,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.blockCommentersDesc,
                    style: TextStyle(fontSize: 12, color: context.textMuted),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: friendsList.isEmpty
                        ? Center(
                            child: Text(
                              l10n.noFriendsList,
                              style: TextStyle(color: context.textMuted),
                            ),
                          )
                        : ListView.builder(
                            itemCount: friendsList.length,
                            itemBuilder: (context, idx) {
                              final friend = friendsList[idx] as Map<String, dynamic>;
                              final fId = (friend['_id'] ?? friend['id'] ?? '').toString();
                              final fName = friend['username'] ?? friend['name'] ?? l10n.user;
                              final fAvatar = friend['avatar'];
                              final isBlocked = blocked.contains(fId);

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: AppAvatar(avatar: fAvatar, name: fName, radius: 18),
                                title: Text(
                                  fName,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () {
                                    setDlgState(() {
                                      if (isBlocked) {
                                        blocked.remove(fId);
                                      } else {
                                        blocked.add(fId);
                                      }
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isBlocked ? Colors.grey.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.1),
                                    foregroundColor: isBlocked ? context.textPrimary : Colors.red,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: Size.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: Text(
                                    isBlocked ? l10n.unblock : l10n.block,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: Text(l10n.cancel, style: TextStyle(color: context.textMuted)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dlgCtx);
                  onSaved(blocked.toList());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleDeletePost() {
    final rootContext = widget.parentContext ?? context;
    final l10n = rootContext.l10n;
    Navigator.pop(context);

    showDialog(
      context: rootContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.deletePostTitle,
          style: TextStyle(color: ctx.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          l10n.deletePostConfirm,
          style: TextStyle(color: ctx.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel, style: TextStyle(color: ctx.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              widget.onPostDeleted?.call();
              final success = await PostService.deletePost(_postId);
              if (rootContext.mounted) {
                if (success) {
                  AppToast.show(rootContext, l10n.deletePostSuccess);
                } else {
                  AppToast.show(rootContext, l10n.deletePostFailed, isError: true);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.only(bottom: 24, top: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: context.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.postOptions,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: context.textMuted, size: 22),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, thickness: 0.5, color: context.borderTheme),
          const SizedBox(height: 8),

          if (!_isOwner) ...[

            _buildOptionItem(
              icon: Icons.visibility_off_outlined,
              title: l10n.notInterested,
              subtitle: l10n.notInterestedDesc,
              onTap: _handleNotInterested,
            ),

            _buildOptionItem(
              icon: Icons.flag_outlined,
              title: l10n.reportPost,
              subtitle: l10n.reportPostDesc,
              iconColor: Colors.orange,
              onTap: _openReportDialog,
            ),
          ] else ...[

            _buildOptionItem(
              icon: _commentsDisabled ? Icons.chat_bubble_outline_rounded : Icons.comments_disabled_outlined,
              title: _commentsDisabled ? l10n.turnOnCommenting : l10n.turnOffCommenting,
              subtitle: _commentsDisabled ? l10n.turnOnCommentingSub : l10n.turnOffCommentingSub,
              iconColor: _commentsDisabled ? AppColors.blue : Colors.orange,
              onTap: _handleToggleComments,
            ),

            _buildOptionItem(
              icon: Icons.tune_rounded,
              title: l10n.whoCanComment,
              subtitle: _commentPermission == 'everyone'
                  ? l10n.everyoneDesc
                  : (_commentPermission == 'friends'
                      ? l10n.friendsOnly
                      : l10n.selectedAccountsOnly),
              iconColor: AppColors.blue,
              onTap: _openCommentSettings,
            ),

            _buildOptionItem(
              icon: Icons.delete_outline_rounded,
              title: l10n.deletePost,
              subtitle: l10n.deletePostSub,
              iconColor: AppColors.red,
              titleColor: AppColors.red,
              onTap: _handleDeletePost,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (iconColor ?? context.textPrimary).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor ?? context.textPrimary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: titleColor ?? context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.textMuted.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
