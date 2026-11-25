import '../../l10n/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/theme_helper.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_switch.dart';
import '../contact/create_group_screen.dart';
import '../../services/contact_service.dart';
import '../../services/group_service.dart';
import '../../widgets/toast/app_toast.dart';
import 'chat_media_screen.dart';
import 'group_members_screen.dart';
import 'package:flutter/services.dart';
import '../../services/message_service.dart';
import 'group_qr_screen.dart';

class ChatInfoScreen extends StatefulWidget {
  final String name;
  final String avatar;
  final Color color;
  final String? conversationId;
  final String? receiverId;
  final List<Map<String, dynamic>> messages;
  final Map<String, dynamic>? pinnedMessage;
  final List<Map<String, dynamic>> pinnedMessages;
  final bool? isGroup;
  final bool? isOnline;
  final bool? isMuted;
  final String? quickEmoji;

  const ChatInfoScreen({
    super.key,
    required this.name,
    required this.avatar,
    required this.color,
    this.conversationId,
    this.receiverId,
    this.messages = const [],
    this.pinnedMessage,
    this.pinnedMessages = const [],
    this.isGroup,
    this.isOnline,
    this.isMuted,
    this.quickEmoji,
  });

  static String? getReactionAsset(String? text) {
    if (text == null || text.isEmpty) return null;
    final clean = text.trim().toLowerCase();
    switch (clean) {
      case 'like':
      case '👍':
        return 'assets/icons/like.png';
      case 'love':
      case 'heart':
      case '❤️':
      case '❤':
        return 'assets/icons/heart.png';
      case 'care':
      case '🥰':
        return 'assets/icons/care.png';
      case 'haha':
      case '😂':
      case '😆':
        return 'assets/icons/haha.png';
      case 'wow':
      case '😮':
      case '😲':
        return 'assets/icons/wow.png';
      case 'sad':
      case 'cry':
      case '😢':
      case '😭':
        return 'assets/icons/cry.png';
      case 'angry':
      case '😡':
      case '👿':
        return 'assets/icons/angry.png';
      default:
        return null;
    }
  }

  static String getEmojiSymbol(String? text) {
    if (text == null || text.isEmpty) return '👍';
    final clean = text.trim().toLowerCase();
    switch (clean) {
      case 'like':
        return '👍';
      case 'love':
      case 'heart':
        return '❤️';
      case 'care':
        return '🥰';
      case 'haha':
        return '😆';
      case 'wow':
        return '😮';
      case 'sad':
      case 'cry':
        return '😢';
      case 'angry':
        return '😡';
      default:
        return text;
    }
  }

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  Language get l10n => context.l10n;
  bool _readReceiptsEnabled = true;
  String _quickEmoji = '👍';
  List<String> _customEmojis = [];
  String? _nickname;
  int? _groupMembersCount;
  String? _groupQrCode;
  String? _actualGroupId;
  List<Map<String, dynamic>> _groupMembers = [];
  bool _isMuted = false;
  DateTime? _mutedUntil;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.isMuted ?? false;
    if (widget.quickEmoji != null && widget.quickEmoji!.isNotEmpty) {
      _quickEmoji = widget.quickEmoji!;
    }
    _checkMuteStatus();
    _loadQuickEmoji();
    if (widget.isGroup == true) {
      _loadGroupData();
    }
  }

  Future<void> _loadQuickEmoji() async {
    final convId = widget.conversationId;
    final recId = widget.receiverId;
    if ((convId == null || convId.isEmpty) && (recId == null || recId.isEmpty)) return;
    try {
      final res = await MessageService.loadMessages(
        conversationId: convId,
        receiverId: recId,
        limit: 1,
      );
      if (res != null && mounted) {
        setState(() {
          if (res['quickEmoji'] != null && res['quickEmoji'].toString().isNotEmpty) {
            _quickEmoji = res['quickEmoji'].toString();
          }
          if (res['customEmojis'] is List) {
            _customEmojis = List<String>.from(res['customEmojis'].map((e) => e.toString()));
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _checkMuteStatus() async {
    final convId = widget.conversationId;
    final recId = widget.receiverId;
    if ((convId == null || convId.isEmpty) && (recId == null || recId.isEmpty)) return;
    try {
      final res = await MessageService.getMuteStatus(
        conversationId: convId,
        receiverId: recId,
      );
      if (res != null && mounted) {
        setState(() {
          _isMuted = res['isMuted'] == true;
          if (res['mutedUntil'] != null) {
            _mutedUntil = DateTime.tryParse(res['mutedUntil'].toString());
          } else {
            _mutedUntil = null;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadGroupData() async {
    final targetId = widget.conversationId;
    if (targetId == null || targetId.isEmpty) return;
    try {
      final data = await GroupService.getGroupDetail(targetId);
      if (data != null && mounted) {
        setState(() {
          _actualGroupId = data['id']?.toString() ?? data['groupId']?.toString();
          _groupQrCode = data['qrCode']?.toString();
          if (data['members'] is List) {
            _groupMembers = List<Map<String, dynamic>>.from(data['members']);
            _groupMembersCount = _groupMembers.length;
          } else if (data['membersCount'] != null) {
            _groupMembersCount = int.tryParse(data['membersCount'].toString());
          }
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final displayName = _nickname ?? widget.name;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _quickEmoji);
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        appBar: AppBar(
          backgroundColor: context.scaffoldBg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.pop(context, _quickEmoji),
          ),
        ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Column(
          children: [

            Center(
              child: Column(
                children: [
                  AppAvatar(
                    avatar: widget.avatar,
                    name: widget.name,
                    color: widget.color,
                    radius: 46.r,
                    fontSize: 32.sp,
                    enableViewer: true,
                    heroTag: 'chat_info_avatar_${widget.conversationId ?? widget.name}',
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.isGroup != true && widget.isOnline == true) ...[
                    SizedBox(height: 4.h),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8.r,
                          height: 8.r,
                          decoration: const BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          l10n.activeNow,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: context.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 24.h),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.search_rounded,
                    label: l10n.searchInChat,
                    onTap: () {},
                  ),
                ),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.text_fields_rounded,
                    label: l10n.nickname,
                    onTap: () {},
                  ),
                ),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: _isMuted ? Icons.notifications_off_rounded : Icons.notifications_rounded,
                    label: _isMuted ? l10n.mutedStatus : l10n.notifications,
                    customIconColor: _isMuted ? Colors.orangeAccent : null,
                    onTap: _handleNotificationTap,
                  ),
                ),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.tune_rounded,
                    label: l10n.customization,
                    onTap: () {},
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),

            _buildSectionHeader(l10n.customization),
            _buildCardGroup([
              _buildSettingTile(
                icon: Icons.color_lens_rounded,
                iconColor: widget.color,
                title: l10n.theme,
                trailingText: l10n.defaultTheme,
                onTap: () {
                  _showThemePicker();
                },
              ),
              _buildSettingTile(
                icon: Icons.thumb_up_rounded,
                iconColor: AppColors.blue,
                title: l10n.quickEmoji,
                trailingWidget: _buildEmojiItem(_quickEmoji, size: 22.r),
                onTap: () {
                  _showEmojiPicker();
                },
              ),
              _buildSettingTile(
                icon: Icons.text_fields_rounded,
                iconColor: Colors.purpleAccent,
                title: l10n.nickname,
                trailingText: _nickname ?? l10n.notSet,
                onTap: () {
                  _showNicknameDialog();
                },
              ),
            ]),
            SizedBox(height: 18.h),

            _buildSectionHeader(l10n.chatActivity),
            _buildCardGroup([
              if (widget.isGroup == true) ...[
                _buildSettingTile(
                  icon: Icons.people_alt_rounded,
                  iconColor: Colors.deepPurpleAccent,
                  title: l10n.groupMembers,
                  trailingText: _groupMembersCount != null ? '$_groupMembersCount ${l10n.membersCountUnit}' : l10n.viewMemberList,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupMembersScreen(
                          groupName: widget.name,
                          groupAvatar: widget.avatar,
                          groupColor: widget.color,
                          conversationId: widget.conversationId,
                          initialMembers: _groupMembers,
                        ),
                      ),
                    );
                  },
                ),
                _buildSettingTile(
                  icon: Icons.qr_code_2_rounded,
                  iconColor: Colors.indigoAccent,
                  title: l10n.groupQrCode,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupQrScreen(
                          groupName: widget.name,
                          groupAvatar: widget.avatar,
                          groupColor: widget.color,
                          groupId: _actualGroupId ?? widget.conversationId,
                          conversationId: widget.conversationId,
                          qrCode: _groupQrCode,
                        ),
                      ),
                    );
                  },
                ),
              ],
              _buildSettingTile(
                icon: Icons.push_pin_rounded,
                iconColor: AppColors.blue,
                title: l10n.pinnedMessageTitle,
                trailingText: _allPinned.isNotEmpty ? '${_allPinned.length} ${l10n.pinned}' : l10n.zeroMessages,
                onTap: () {
                  _showPinnedMessageDialog();
                },
              ),
              _buildSettingTile(
                icon: Icons.photo_library_rounded,
                iconColor: Colors.teal,
                title: l10n.mediaAndLinks,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatMediaScreen(
                        conversationName: widget.name,
                        conversationAvatar: widget.avatar,
                        conversationColor: widget.color,
                        conversationId: widget.conversationId,
                        initialMessages: widget.messages,
                      ),
                    ),
                  );
                },
              ),
              if (widget.isGroup != true)
                _buildSettingTile(
                  icon: Icons.group_add_rounded,
                  iconColor: Colors.orange,
                  title: '${l10n.createGroupWith} ${widget.name}',
                  onTap: () async {
                    final result = await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateGroupScreen(
                          preselectedContact: {
                            'id': widget.receiverId ?? widget.name,
                            'name': widget.name,
                            'avatar': widget.avatar,
                            'color': widget.color,
                            'status': l10n.friend,
                          },
                        ),
                      ),
                    );

                    if (!context.mounted) return;
                    if (result != null) {
                      AppToast.success(context, '${l10n.groupCreatedSuccess} "${result['name']}"!');
                      final memberIds = (result['memberIds'] as List<dynamic>?)?.map((e) => e.toString()).toList();
                      ContactService.createGroup(
                        name: result['name'] ?? '',
                        memberIds: memberIds,
                      );
                    }
                  },
                ),
            ]),
            SizedBox(height: 18.h),

            _buildSectionHeader(l10n.privacyAndSupport),
            _buildCardGroup([
              _buildSettingTile(
                icon: _isMuted ? Icons.notifications_off_rounded : Icons.notifications_rounded,
                iconColor: _isMuted ? Colors.orangeAccent : AppColors.blue,
                title: l10n.notifications,
                trailingText: _isMuted ? l10n.mutedStatus : l10n.enabledState,
                onTap: _handleNotificationTap,
              ),
              _buildSettingTile(
                icon: Icons.done_all_rounded,
                iconColor: AppColors.blue,
                title: l10n.readReceipts,
                trailingText: _readReceiptsEnabled ? l10n.enabledState : l10n.disabledState,
                trailingWidget: AppSwitch(
                  value: _readReceiptsEnabled,
                  onChanged: (val) {
                    setState(() {
                      _readReceiptsEnabled = val;
                    });
                    AppToast.info(
                      context,
                      _readReceiptsEnabled
                          ? l10n.readReceiptsEnabledToast
                          : l10n.readReceiptsDisabledToast,
                    );
                  },
                ),
                onTap: _showReadReceiptsBottomSheet,
              ),
              if (widget.isGroup != true)
                _buildSettingTile(
                  icon: Icons.block_rounded,
                  iconColor: AppColors.red,
                  title: '${l10n.blockUser} ${widget.name}',
                  isDestructive: true,
                  onTap: () {
                    _showConfirmDialog(
                      title: l10n.blockUserConfirmTitle,
                      content: l10n.blockUserConfirmDesc,
                      confirmText: l10n.blockUser,
                      isDestructive: true,
                      onConfirm: () {
                        Navigator.pop(context);
                        AppToast.info(context, '${l10n.blockedUserToast} ${widget.name}');
                      },
                    );
                  },
                )
              else
                _buildSettingTile(
                  icon: Icons.exit_to_app_rounded,
                  iconColor: AppColors.red,
                  title: l10n.leaveGroup,
                  isDestructive: true,
                  onTap: () {
                    _showConfirmDialog(
                      title: l10n.leaveGroupConfirmTitle,
                      content: l10n.leaveGroupConfirmDesc,
                      confirmText: l10n.leaveGroupBtn,
                      isDestructive: true,
                      onConfirm: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                        AppToast.info(context, '${l10n.leftGroupToast} ${widget.name}');
                      },
                    );
                  },
                ),
              _buildSettingTile(
                icon: Icons.report_problem_rounded,
                iconColor: Colors.orangeAccent,
                title: l10n.reportConversation,
                isDestructive: false,
                onTap: () {
                  _showConfirmDialog(
                    title: l10n.reportConversationTitle,
                    content: l10n.reportConversationDesc,
                    confirmText: l10n.sendReport,
                    isDestructive: false,
                    onConfirm: () {
                      AppToast.info(context, l10n.reportSentToast);
                    },
                  );
                },
              ),
              _buildSettingTile(
                icon: Icons.delete_outline_rounded,
                iconColor: AppColors.red,
                title: l10n.clearChatHistory,
                isDestructive: true,
                onTap: () {
                  _showConfirmDialog(
                    title: l10n.clearChatHistoryTitle,
                    content: l10n.clearChatHistoryDesc,
                    confirmText: l10n.delete,
                    isDestructive: true,
                    onConfirm: () async {
                      Navigator.pop(context);
                      final convId = widget.conversationId;
                      final recId = widget.receiverId;
                      await MessageService.deleteConversation(
                        conversationId: convId,
                        receiverId: recId,
                      );
                      if (mounted) {
                        AppToast.success(context, l10n.chatHistoryClearedToast);
                        Navigator.pop(context, true);
                      }
                    },
                  );
                },
              ),
            ]),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    Color? customIconColor,
  }) {
    final bgColor = context.isDark
        ? (isActive ? AppColors.blue.withValues(alpha: 0.25) : const Color(0xFF232234))
        : (isActive ? AppColors.blue.withValues(alpha: 0.15) : const Color(0xFFE4E6EB));

    final iconColor = customIconColor ?? (isActive ? AppColors.blue : context.textPrimary);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 2.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Ink(
                width: 50.r,
                height: 50.r,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(icon, size: 22.r, color: iconColor),
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: context.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(left: 8.w, bottom: 8.h),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w700,
            color: context.textMuted,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }

  Widget _buildCardGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1B1B28) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: context.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                Divider(
                  height: 1,
                  thickness: 0.6,
                  indent: 52.w,
                  color: context.dividerTheme,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? trailingText,
    Widget? trailingWidget,
    bool isDestructive = false,
    bool showArrow = true,
    required VoidCallback onTap,
  }) {
    final titleColor = isDestructive ? AppColors.red : context.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            children: [
              Container(
                width: 32.r,
                height: 32.r,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18.r, color: iconColor),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5.sp,
                    fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w500,
                    color: titleColor,
                  ),
                ),
              ),
              if (trailingWidget != null) ...[
                trailingWidget,
              ] else ...[
                if (trailingText != null) ...[
                  Text(
                    trailingText,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: context.textMuted,
                    ),
                  ),
                  SizedBox(width: 6.w),
                ],
                if (showArrow)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13.r,
                    color: context.textMuted.withValues(alpha: 0.5),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleNotificationTap() {
    if (_isMuted) {
      _showUnmuteConfirmDialog();
    } else {
      _showMuteOptionsDialog();
    }
  }

  void _showMuteOptionsDialog() {
    int selectedDuration = 15;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final options = [
            {'title': l10n.in15Minutes, 'duration': 15},
            {'title': l10n.in1Hour, 'duration': 60},
            {'title': l10n.in8Hours, 'duration': 480},
            {'title': l10n.in24Hours, 'duration': 1440},
            {'title': l10n.untilITurnBackOn, 'duration': -1},
          ];

          return AlertDialog(
            backgroundColor: context.cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
            titlePadding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 8.h),
            contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            actionsPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.notifications_off_rounded, color: Colors.orangeAccent, size: 20.r),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        l10n.muteNotifications,
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Text(
                  l10n.muteChatFor,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: context.textMuted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.map((opt) {
                final duration = opt['duration'] as int;
                final isSelected = selectedDuration == duration;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12.r),
                    onTap: () {
                      setDialogState(() {
                        selectedDuration = duration;
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            color: isSelected ? AppColors.blue : context.textMuted,
                            size: 20.r,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              opt['title'] as String,
                              style: TextStyle(
                                fontSize: 14.5.sp,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                color: isSelected ? context.textPrimary : context.textPrimary.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: Text(
                  l10n.cancel,
                  style: TextStyle(
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w600,
                    color: context.textMuted,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                onPressed: () async {
                  Navigator.pop(dlgCtx);
                  await _applyMute(selectedDuration);
                },
                child: Text(
                  l10n.muteBtn,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUnmuteConfirmDialog() {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.notifications_active_rounded, color: AppColors.blue, size: 20.r),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                l10n.unmuteConfirmTitle,
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '${l10n.unmuteConfirmDesc} ${widget.name}.',
          style: TextStyle(fontSize: 13.5.sp, color: context.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(
              l10n.cancel,
              style: TextStyle(
                fontSize: 14.5.sp,
                fontWeight: FontWeight.w600,
                color: context.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            onPressed: () async {
              Navigator.pop(dlgCtx);
              await _applyUnmute();
            },
            child: Text(
              l10n.unmuteConfirmBtn,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyMute(int duration) async {
    final convId = widget.conversationId;
    final recId = widget.receiverId;
    if ((convId == null || convId.isEmpty) && (recId == null || recId.isEmpty)) return;

    setState(() {
      _isMuted = true;
    });

    try {
      final res = await MessageService.muteConversation(
        conversationId: convId,
        receiverId: recId,
        durationMinutes: duration,
      );
      if (!mounted) return;
      if (res != null && res['success'] == true) {
        HapticFeedback.mediumImpact();
        AppToast.success(context, l10n.mutedToast);
        setState(() {
          _isMuted = true;
          if (res['mutedUntil'] != null) {
            _mutedUntil = DateTime.tryParse(res['mutedUntil'].toString());
          } else {
            _mutedUntil = null;
          }
        });
      } else {
        setState(() {
          _isMuted = false;
        });
        AppToast.error(context, l10n.requestConnectionError);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isMuted = false;
        });
        AppToast.error(context, l10n.requestConnectionError);
      }
    }
  }

  Future<void> _applyUnmute() async {
    final convId = widget.conversationId;
    final recId = widget.receiverId;
    if ((convId == null || convId.isEmpty) && (recId == null || recId.isEmpty)) return;

    setState(() {
      _isMuted = false;
    });

    try {
      final res = await MessageService.unmuteConversation(
        conversationId: convId,
        receiverId: recId,
      );
      if (!mounted) return;
      if (res != null && res['success'] == true) {
        HapticFeedback.mediumImpact();
        AppToast.success(context, l10n.unmutedToast);
        setState(() {
          _isMuted = false;
          _mutedUntil = null;
        });
      } else {
        setState(() {
          _isMuted = true;
        });
        AppToast.error(context, l10n.requestConnectionError);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isMuted = true;
        });
        AppToast.error(context, l10n.requestConnectionError);
      }
    }
  }

  void _showNicknameDialog() {
    final controller = TextEditingController(text: _nickname ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.isDark ? const Color(0xFF222030) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(l10n.setNickname, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '${l10n.enterNicknameFor} ${widget.name}',
            filled: true,
            fillColor: context.isDark ? Colors.white10 : const Color(0xFFF2F4F7),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel, style: TextStyle(color: context.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
            ),
            onPressed: () {
              setState(() {
                _nickname = controller.text.trim().isEmpty ? null : controller.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: Text(l10n.save, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiItem(String item, {double size = 26}) {
    final asset = ChatInfoScreen.getReactionAsset(item);
    if (asset != null) {
      return Image.asset(asset, width: size, height: size, fit: BoxFit.contain);
    }
    return Text(item, style: TextStyle(fontSize: size));
  }

  Future<void> _setQuickEmoji(String emoji) async {
    setState(() {
      _quickEmoji = emoji;
      if (!_customEmojis.contains(emoji)) {
        _customEmojis.add(emoji);
      }
    });
    HapticFeedback.lightImpact();
    AppToast.success(
      context,
      LanguageManager.isEnglish()
          ? 'Quick emoji updated'
          : 'Đã cập nhật biểu tượng nhanh',
    );
    final convId = widget.conversationId;
    final recId = widget.receiverId;
    try {
      await MessageService.updateQuickEmoji(
        conversationId: convId,
        receiverId: recId,
        emoji: emoji,
      );
    } catch (e) {
      debugPrint('updateQuickEmoji error: ');
    }
  }

  void _showEmojiPicker() {
    final defaultReactions = [
      {'id': 'like', 'asset': 'assets/icons/like.png'},
      {'id': 'love', 'asset': 'assets/icons/heart.png'},
      {'id': 'care', 'asset': 'assets/icons/care.png'},
      {'id': 'haha', 'asset': 'assets/icons/haha.png'},
      {'id': 'wow', 'asset': 'assets/icons/wow.png'},
      {'id': 'sad', 'asset': 'assets/icons/cry.png'},
      {'id': 'angry', 'asset': 'assets/icons/angry.png'},
    ];

    final customList = _customEmojis.where((e) {
      final a = ChatInfoScreen.getReactionAsset(e);
      return !defaultReactions.any((r) => r['id'] == e || r['asset'] == a);
    }).toList();

    final currentAsset = ChatInfoScreen.getReactionAsset(_quickEmoji);
    if (currentAsset == null && _quickEmoji.isNotEmpty && !customList.contains(_quickEmoji)) {
      customList.add(_quickEmoji);
    }

    final int totalCount = defaultReactions.length + customList.length + 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: EdgeInsets.only(
          top: 12.h,
          bottom: 24.h + MediaQuery.of(ctx).padding.bottom,
          left: 20.w,
          right: 20.w,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38.w,
                height: 4.5.h,
                decoration: BoxDecoration(
                  color: context.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.chooseQuickEmoji,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: EdgeInsets.all(4.r),
                    decoration: BoxDecoration(
                      color: context.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20.r,
                      color: context.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 12.h,
                crossAxisSpacing: 12.w,
                childAspectRatio: 1.0,
              ),
              itemCount: totalCount,
              itemBuilder: (context, index) {
                if (index < defaultReactions.length) {
                  final item = defaultReactions[index];
                  final itemId = item['id']!;
                  final itemAsset = item['asset']!;
                  final isSelected = _quickEmoji.toLowerCase() == itemId ||
                      ChatInfoScreen.getReactionAsset(_quickEmoji) == itemAsset;

                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _setQuickEmoji(itemId);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.blue.withValues(alpha: 0.2)
                            : (context.isDark ? Colors.white10 : const Color(0xFFF2F4F7)),
                        borderRadius: BorderRadius.circular(14.r),
                        border: isSelected
                            ? Border.all(color: AppColors.blue, width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Image.asset(
                          itemAsset,
                          width: 34.r,
                          height: 34.r,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                } else if (index < defaultReactions.length + customList.length) {
                  final customEmoji = customList[index - defaultReactions.length];
                  final isSelected = _quickEmoji == customEmoji;

                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _setQuickEmoji(customEmoji);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.blue.withValues(alpha: 0.2)
                            : (context.isDark ? Colors.white10 : const Color(0xFFF2F4F7)),
                        borderRadius: BorderRadius.circular(14.r),
                        border: isSelected
                            ? Border.all(color: AppColors.blue, width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          customEmoji,
                          style: TextStyle(fontSize: 26.sp),
                        ),
                      ),
                    ),
                  );
                } else {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showAddCustomEmojiDialog();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.isDark ? Colors.white10 : const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: context.isDark ? Colors.white24 : Colors.black12,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.add_rounded,
                          size: 26.r,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCustomEmojiDialog() {
    final popularEmojis = [
      '🥳', '😎', '🤔', '🥺', '🚀', '✨', '💡', '💖',
      '🤩', '☕', '🙌', '🎈', '⚡', '🎯', '🐱', '🌸',
      '🍕', '🍻', '💪', '🏆', '👀', '🤫', '🤤', '😴',
    ];
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) => Container(
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 12.h,
            bottom: MediaQuery.of(dlgCtx).viewInsets.bottom + 24.h + MediaQuery.of(dlgCtx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38.w,
                  height: 4.5.h,
                  decoration: BoxDecoration(
                    color: context.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    LanguageManager.isEnglish() ? 'Add Custom Emoji' : 'Thêm biểu tượng cảm xúc',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(dlgCtx),
                    child: Container(
                      padding: EdgeInsets.all(4.r),
                      decoration: BoxDecoration(
                        color: context.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20.r,
                        color: context.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: false,
                      style: TextStyle(fontSize: 18.sp, color: context.textPrimary),
                      decoration: InputDecoration(
                        hintText: LanguageManager.isEnglish() ? 'Type or paste emoji...' : 'Nhập hoặc dán emoji...',
                        hintStyle: TextStyle(fontSize: 14.sp, color: context.textMuted),
                        filled: true,
                        fillColor: context.isDark ? Colors.white10 : const Color(0xFFF2F4F7),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: BorderSide.none),
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
                      elevation: 0,
                    ),
                    onPressed: controller.text.trim().isEmpty
                        ? null
                        : () {
                            final custom = controller.text.trim();
                            Navigator.pop(dlgCtx);
                            _setQuickEmoji(custom);
                          },
                    child: Text(
                      l10n.save,
                      style: TextStyle(fontSize: 14.sp, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18.h),
              Text(
                LanguageManager.isEnglish() ? 'Suggested emojis' : 'Gợi ý biểu tượng',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: context.textMuted),
              ),
              SizedBox(height: 12.h),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 10.h,
                  crossAxisSpacing: 10.w,
                  childAspectRatio: 1.0,
                ),
                itemCount: popularEmojis.length,
                itemBuilder: (context, index) {
                  final emoji = popularEmojis[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12.r),
                    onTap: () {
                      Navigator.pop(dlgCtx);
                      _setQuickEmoji(emoji);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.isDark ? Colors.white10 : const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Center(
                        child: Text(emoji, style: TextStyle(fontSize: 22.sp)),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showThemePicker() {
    final themes = [
      {'name': l10n.defaultThemeVioraBlue, 'color': AppColors.blue},
      {'name': l10n.purpleNeonTheme, 'color': Colors.purpleAccent},
      {'name': l10n.sakuraPinkTheme, 'color': Colors.pinkAccent},
      {'name': l10n.emeraldTealTheme, 'color': Colors.teal},
      {'name': l10n.sunsetOrangeTheme, 'color': Colors.deepOrangeAccent},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: EdgeInsets.only(
          top: 12.h,
          bottom: 24.h + MediaQuery.of(ctx).padding.bottom,
          left: 20.w,
          right: 20.w,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38.w,
                height: 4.5.h,
                decoration: BoxDecoration(
                  color: context.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.chooseChatTheme,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: EdgeInsets.all(4.r),
                    decoration: BoxDecoration(
                      color: context.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20.r,
                      color: context.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            ...themes.map((t) {
              final color = t['color'] as Color;
              final name = t['name'] as String;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(backgroundColor: color, radius: 14.r),
                title: Text(name, style: TextStyle(fontSize: 14.5.sp, color: context.textPrimary)),
                trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14.r, color: context.textMuted),
                onTap: () {
                  Navigator.pop(ctx);
                  AppToast.info(context, ': ');
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _allPinned {
    if (widget.pinnedMessages.isNotEmpty) return widget.pinnedMessages;
    if (widget.pinnedMessage != null) return [widget.pinnedMessage!];
    return const [];
  }

  void _showPinnedMessageDialog() {
    Navigator.pushNamed(
      context,
      AppRoutes.pinMessage,
      arguments: {
        'conversationId': widget.conversationId,
        'pinnedMessages': _allPinned,
      },
    );
  }

  void _showConfirmDialog({
    required String title,
    required String content,
    required String confirmText,
    required bool isDestructive,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.isDark ? const Color(0xFF222030) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
        content: Text(content, style: TextStyle(fontSize: 14.sp, color: context.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel, style: TextStyle(color: context.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? AppColors.red : AppColors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text(confirmText, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showReadReceiptsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.isDark ? const Color(0xFF222030) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: context.textMuted.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 18.h),
                    Row(
                      children: [
                        Container(
                          width: 40.r,
                          height: 40.r,
                          decoration: BoxDecoration(
                            color: AppColors.blue.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.done_all_rounded, color: AppColors.blue, size: 22.r),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.readReceipts,
                                style: TextStyle(
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                _readReceiptsEnabled ? l10n.currentlyEnabled : l10n.currentlyDisabled,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: _readReceiptsEnabled ? AppColors.blue : context.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppSwitch(
                          value: _readReceiptsEnabled,
                          onChanged: (val) {
                            setSheetState(() {
                              _readReceiptsEnabled = val;
                            });
                            setState(() {
                              _readReceiptsEnabled = val;
                            });
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Container(
                      padding: EdgeInsets.all(14.r),
                      decoration: BoxDecoration(
                        color: context.isDark ? Colors.white10 : const Color(0xFFF5F7FB),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 20.r, color: context.textMuted),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              l10n.readReceiptsDescription,
                              style: TextStyle(
                                fontSize: 13.sp,
                                height: 1.4,
                                color: context.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          AppToast.info(
                            context,
                            _readReceiptsEnabled
                                ? l10n.readReceiptsEnabledToast
                                : l10n.readReceiptsDisabledToast,
                          );
                        },
                        child: Text(
                          l10n.close,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
