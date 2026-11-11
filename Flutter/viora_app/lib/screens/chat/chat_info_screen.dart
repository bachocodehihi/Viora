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
  });

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  Language get l10n => context.l10n;
  bool _readReceiptsEnabled = true;
  String _quickEmoji = '👍';
  String? _nickname;
  int? _groupMembersCount;
  String? _groupQrCode;
  List<Map<String, dynamic>> _groupMembers = [];

  @override
  void initState() {
    super.initState();
    if (widget.isGroup == true) {
      _loadGroupData();
    }
  }

  Future<void> _loadGroupData() async {
    final targetId = widget.conversationId;
    if (targetId == null || targetId.isEmpty) return;
    try {
      final data = await GroupService.getGroupDetail(targetId);
      if (data != null && mounted) {
        setState(() {
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

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
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
                    icon: Icons.notifications_rounded,
                    label: l10n.notifications,
                    onTap: () {},
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
                trailingText: _quickEmoji,
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
                    onConfirm: () {
                      Navigator.pop(context);
                      AppToast.info(context, l10n.chatHistoryClearedToast);
                    },
                  );
                },
              ),
            ]),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final bgColor = context.isDark
        ? (isActive ? AppColors.blue.withValues(alpha: 0.25) : const Color(0xFF232234))
        : (isActive ? AppColors.blue.withValues(alpha: 0.15) : const Color(0xFFE4E6EB));

    final iconColor = isActive ? AppColors.blue : context.textPrimary;

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

  void _showEmojiPicker() {
    final emojis = ['👍', '❤️', '🔥', '🎉', '👏', '😍', '😂', '⭐', '🤝', '💯'];
    showModalBottomSheet(
      context: context,
      backgroundColor: context.isDark ? const Color(0xFF222030) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.chooseQuickEmoji, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 16.h),
            Wrap(
              spacing: 12.w,
              runSpacing: 12.h,
              children: emojis.map((emoji) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _quickEmoji = emoji;
                    });
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: _quickEmoji == emoji
                          ? AppColors.blue.withValues(alpha: 0.2)
                          : (context.isDark ? Colors.white10 : const Color(0xFFF2F4F7)),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(emoji, style: TextStyle(fontSize: 24.sp)),
                  ),
                );
              }).toList(),
            ),
          ],
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
      backgroundColor: context.isDark ? const Color(0xFF222030) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.chooseChatTheme, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 16.h),
            ...themes.map((t) {
              final color = t['color'] as Color;
              final name = t['name'] as String;
              return ListTile(
                leading: CircleAvatar(backgroundColor: color, radius: 14.r),
                title: Text(name, style: TextStyle(fontSize: 14.5.sp)),
                onTap: () {
                  Navigator.pop(ctx);
                  AppToast.info(context, '${l10n.themeSelectedToast}: $name');
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
