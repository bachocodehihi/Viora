import '../../l10n/language.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../services/contact_service.dart';
import '../../services/group_service.dart';
import '../../services/post_service.dart';
import '../../services/session_service.dart';
import '../../widgets/toast/app_toast.dart';
import '../../widgets/app_avatar.dart';
import '../chat/chat_detail_screen.dart';
import '../post/group_create_post_screen.dart';
import '../post/post_detail_screen.dart';
import '../../utils/time_formatter.dart';

class ProfileGroupScreen extends StatefulWidget {
  final String name;
  final String avatar;
  final Color? color;
  final int membersCount;
  final String? description;
  final String? conversationId;
  final String? groupId;
  final String? privacy;

  const ProfileGroupScreen({
    super.key,
    this.name = '',
    this.avatar = '',
    this.color,
    this.membersCount = 8,
    this.description,
    this.conversationId,
    this.groupId,
    this.privacy,
  });

  @override
  State<ProfileGroupScreen> createState() => _ProfileGroupScreenState();
}

class _ProfileGroupScreenState extends State<ProfileGroupScreen> {
  bool _isActionLoading = false;

  late String _groupName;
  late String _groupAvatar;
  late String _groupPrivacy;
  late int _membersCount;
  late String _description;
  String? _conversationId;
  String _groupQrCode = '';

  bool _isMember = true;
  bool _isAdmin = false;
  bool _hasRequested = false;
  int _pendingRequestsCount = 0;
  List<Map<String, dynamic>> _members = [];

  String? _myAvatar;
  String? _myName;
  String? _myUserId;
  String? _myEmail;
  List<Map<String, dynamic>> _groupPosts = [];
  bool _isLoadingPosts = false;

  @override
  void initState() {
    super.initState();
    _groupName = widget.name.isNotEmpty ? widget.name : 'Group';
    _groupAvatar = widget.avatar;
    _groupPrivacy = widget.privacy ?? 'public';
    _membersCount = widget.membersCount;
    _description = widget.description ?? '';
    _conversationId = widget.conversationId;

    _fetchGroupDetails();
    _loadMySession();
    _fetchGroupPosts();
  }

  Future<void> _loadMySession() async {
    final av = await SessionService.getAvatar();
    final name = await SessionService.getUsername();
    final uid = await SessionService.getUserId();
    final mail = await SessionService.getUserEmail();
    if (mounted) {
      setState(() {
        _myAvatar = av;
        _myName = name;
        _myUserId = uid;
        _myEmail = mail;
      });
    }
  }

  Future<void> _fetchGroupPosts() async {
    final gId = widget.groupId;
    if (gId == null || gId.isEmpty) return;

    setState(() => _isLoadingPosts = true);
    try {
      final posts = await PostService.getGroupPosts(gId);
      if (mounted) {
        setState(() {
          _groupPosts = posts;
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPosts = false);
      }
    }
  }

  Future<void> _openGroupCreatePost() async {
    final gId = widget.groupId;
    if (gId == null || gId.isEmpty) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupCreatePostScreen(
          groupId: gId,
          groupName: _groupName,
          groupAvatar: _groupAvatar,
          userAvatar: _myAvatar,
          userName: _myName,
        ),
      ),
    );

    if (result == true) {
      _fetchGroupPosts();
    }
  }

  Future<void> _fetchGroupDetails() async {
    final gId = widget.groupId;
    if (gId == null || gId.isEmpty) return;

    final data = await GroupService.getGroupDetail(gId);
    if (!mounted) return;

    if (data != null) {
      setState(() {
        _groupName = data['name']?.toString() ?? _groupName;
        _groupAvatar = data['avatar']?.toString() ?? _groupAvatar;
        _groupPrivacy = data['privacy']?.toString() ?? _groupPrivacy;
        _membersCount = (data['membersCount'] as num?)?.toInt() ?? _membersCount;
        _description = data['description']?.toString() ?? _description;
        _conversationId = data['conversationId']?.toString() ?? _conversationId;
        _groupQrCode = data['qrCode']?.toString() ?? _groupQrCode;

        _isMember = data['isMember'] == true;
        _isAdmin = data['isAdmin'] == true;
        _hasRequested = data['hasRequested'] == true;
        _pendingRequestsCount = (data['pendingRequestsCount'] as num?)?.toInt() ?? 0;

        if (data['members'] is List) {
          _members = List<Map<String, dynamic>>.from(data['members']);
        }
      });
    }
  }

  Color get _themeColor {
    if (_groupPrivacy == 'public') return AppColors.blue;
    if (_groupPrivacy == 'private') return Colors.orangeAccent;
    return Colors.purpleAccent;
  }

  String get _privacyLabel {
    if (_groupPrivacy == 'public') return l10n.public.toUpperCase();
    if (_groupPrivacy == 'private') return l10n.privateAccount.toUpperCase();
    return l10n.groupInternalSecret.toUpperCase();
  }


  IconData get _privacyIcon {
    if (_groupPrivacy == 'public') return Icons.public_rounded;
    if (_groupPrivacy == 'private') return Icons.lock_outline_rounded;
    return Icons.visibility_off_outlined;
  }

  Future<void> _handleJoinPublicGroup() async {
    final gId = widget.groupId;
    if (gId == null) return;

    setState(() => _isActionLoading = true);
    final res = await GroupService.joinGroup(gId);
    if (!mounted) return;
    setState(() => _isActionLoading = false);

    if (res != null && res['success'] == true) {
      AppToast.success(context, res['message']?.toString() ?? l10n.joinedGroupSuccess);
      _fetchGroupDetails();
    } else {
      AppToast.error(context, l10n.errorFromCode(res?['code'], fallbackMessage: res?['message']?.toString() ?? l10n.requestConnectionError));
    }
  }

  Future<void> _handleRequestJoinPrivateGroup() async {
    final gId = widget.groupId;
    if (gId == null) return;

    final messageController = TextEditingController(text: l10n.permissionJoinGroupDefaultMsg);
    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: Colors.orangeAccent, size: 22),
            const SizedBox(width: 8),
            Text(l10n.requestToJoinGroup, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.groupPrivateApprovalRequired,
              style: TextStyle(color: context.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: messageController,
              maxLines: 2,
              style: TextStyle(color: context.textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: l10n.sendAdminNoteHint,
                hintStyle: TextStyle(color: context.textMuted.withValues(alpha: 0.6)),
                filled: true,
                fillColor: context.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel, style: TextStyle(color: context.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(l10n.sendRequest, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldSend == true && mounted) {
      setState(() => _isActionLoading = true);
      final res = await GroupService.requestJoinGroup(gId, message: messageController.text.trim());
      if (!mounted) return;
      setState(() => _isActionLoading = false);

      if (res != null && res['success'] == true) {
        AppToast.success(context, res['message']?.toString() ?? l10n.joinRequestSent);
        setState(() => _hasRequested = true);
      } else {
        AppToast.error(context, l10n.errorFromCode(res?['code'], fallbackMessage: res?['message']?.toString() ?? l10n.requestConnectionError));
      }
    }
  }

  Future<void> _handleCancelRequest() async {
    final gId = widget.groupId;
    if (gId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.cancelJoinGroupTitle, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(l10n.cancelJoinGroupConfirm, style: TextStyle(color: context.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.no, style: TextStyle(color: context.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(l10n.cancelRequest, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isActionLoading = true);
      final ok = await GroupService.cancelJoinRequest(gId);
      if (!mounted) return;
      setState(() => _isActionLoading = false);

      if (ok) {
        AppToast.info(context, l10n.cancelJoinGroupRequestSuccess);
        setState(() => _hasRequested = false);
      }
    }
  }

  Future<void> _showInviteFriendsBottomSheet() async {
    final gId = widget.groupId;
    if (gId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteFriendsModal(
        groupId: gId,
        groupName: _groupName,
        groupPrivacy: _groupPrivacy,
        existingMemberIds: _members.map((m) => m['id']?.toString() ?? '').toList(),
      ),
    );
  }

  Future<void> _showManageRequestsBottomSheet() async {
    final gId = widget.groupId;
    if (gId == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManageRequestsModal(
        groupId: gId,
        groupName: _groupName,
        onProcessed: () => _fetchGroupDetails(),
      ),
    );
    _fetchGroupDetails();
  }

  Future<void> _handleLeaveGroup() async {
    final gId = widget.groupId;
    if (gId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.leaveGroupConfirmTitle, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(l10n.leaveGroupPrompt(_groupName), style: TextStyle(color: context.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel, style: TextStyle(color: context.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(l10n.leaveGroupBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isActionLoading = true);
      final ok = await GroupService.leaveGroup(gId);
      if (!mounted) return;
      setState(() => _isActionLoading = false);

      if (ok) {
        AppToast.success(context, l10n.leftGroupSuccess);
        Navigator.pop(context);
      }
    }
  }

  void _showGroupQrCodeModal() {
    final groupColor = _themeColor;
    final qrPayload = jsonEncode({
      'type': 'group',
      'groupId': widget.groupId ?? '',
      'name': _groupName,
      'privacy': _groupPrivacy,
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.borderTheme,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                AppAvatar(
                  avatar: _groupAvatar,
                  name: _groupName,
                  color: groupColor,
                  radius: 24,
                  fontSize: 16,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _groupName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(_privacyIcon, size: 12, color: groupColor),
                          const SizedBox(width: 4),
                          Text(
                            _privacyLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: groupColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• $_membersCount ${l10n.members}',
                            style: TextStyle(fontSize: 11, color: context.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: groupColor.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: QrImageView(
                data: qrPayload,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: groupColor,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: Color(0xFF1E1E2C),
                ),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              _groupPrivacy == 'public'
                  ? l10n.qrScanToJoinInstantly
                  : _groupPrivacy == 'private'
                      ? l10n.qrScanToRequestJoin
                      : l10n.qrInternalOnly,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.textMuted,
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.actionPillBg,
                  foregroundColor: context.textPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(l10n.close, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groupColor = _themeColor;
    final groupHandle = '@${_groupName.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}';

    return Scaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [

            SizedBox(
              height: 232,
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [groupColor, groupColor.withValues(alpha: 0.65)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),

                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    left: 16,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.25),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    right: _isMember ? 64 : 16,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.25),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_rounded, color: Colors.white, size: 20),
                          onPressed: _showGroupQrCodeModal,
                        ),
                      ),
                    ),
                  ),

                  if (_isMember)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 10,
                      right: 16,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.25),
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
                            onSelected: (val) {
                              if (val == 'members') _showMembersBottomSheet();
                              if (val == 'leave') _handleLeaveGroup();
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'members',
                                child: Row(
                                  children: [
                                    Icon(Icons.people_outline_rounded, color: context.textPrimary, size: 18),
                                    const SizedBox(width: 8),
                                    Text(l10n.viewMemberList, style: TextStyle(color: context.textPrimary)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'leave',
                                child: Row(
                                  children: [
                                    const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                                    const SizedBox(width: 8),
                                    Text(l10n.leaveGroupBtn, style: const TextStyle(color: Colors.redAccent)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: context.profileShadow,
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: AppAvatar(
                              avatar: _groupAvatar,
                              name: _groupName,
                              color: groupColor,
                              radius: 50,
                              fontSize: 36,
                            ),
                          ),
                          Positioned(
                            right: 4,
                            bottom: 4,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: groupColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2.5),
                              ),
                              child: Icon(_privacyIcon, size: 15, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                _groupName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 4),

            Text(
              groupHandle,
              style: TextStyle(fontSize: 13, color: context.textMuted),
            ),
            const SizedBox(height: 18),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _buildActionButtons(),
            ),

            if (_isAdmin && _pendingRequestsCount > 0) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _showManageRequestsBottomSheet,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.orangeAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.pendingJoinCount(_pendingRequestsCount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: Colors.orangeAccent,
                              ),
                            ),
                            Text(
                              l10n.clickToReviewMembers,
                              style: TextStyle(fontSize: 11.5, color: context.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.orangeAccent),
                    ],
                  ),
                ),
              ),
            ],

            if (_isMember || _groupPrivacy == 'public') ...[
              const SizedBox(height: 18),
              _buildCreatePostTrigger(),
              const SizedBox(height: 10),
              _buildGroupFeed(),
            ] else ...[

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.borderTheme),
                ),
                child: Column(
                  children: [
                    Icon(
                      _groupPrivacy == 'private' ? Icons.lock_outline_rounded : Icons.visibility_off_outlined,
                      size: 40,
                      color: groupColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _groupPrivacy == 'private'
                          ? l10n.groupContentProtected
                          : l10n.groupInternalSecret,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _groupPrivacy == 'private'
                          ? l10n.groupApprovalProtectedDesc
                          : l10n.groupSecretDesc,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: context.textMuted, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatePostTrigger() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
      child: GestureDetector(
        onTap: _openGroupCreatePost,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [

            _myAvatar != null && _myAvatar!.isNotEmpty
                ? AppAvatar(
                    avatar: _myAvatar,
                    name: _myName ?? 'Me',
                    radius: 20,
                    fontSize: 14,
                  )
                : Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person,
                      size: 24,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
            const SizedBox(width: 12),

            Expanded(
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  l10n.whatAreYouThinking,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupFeed() {
    if (_isLoadingPosts) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    if (_groupPosts.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.borderTheme),
        ),
        child: Column(
          children: [
            Icon(Icons.feed_outlined, size: 42, color: context.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 10),
            Text(
              l10n.noPostsYet,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.beFirstToShareInGroup,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: context.textMuted),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _groupPosts.map((post) => _buildGroupPostItem(post)).toList(),
    );
  }

  Widget _buildGroupPostItem(Map<String, dynamic> post) {
    final isAnon = post['isAnonymous'] == true;
    final author = post['author'] is Map ? Map<String, dynamic>.from(post['author']) : <String, dynamic>{};
    final authorName = isAnon
        ? (author['name']?.toString() ?? l10n.anonymousMember)
        : (author['name']?.toString() ?? post['userName']?.toString() ?? l10n.user);
    final authorAvatar = isAnon ? null : (author['avatar']?.toString() ?? post['userAvatar']?.toString());
    final content = post['content']?.toString() ?? '';
    final createdAt = post['createdAt'];
    final timeStr = _formatTimeAgo(createdAt);

    final rawLikes = post['likes'];
    int likesCount = (post['likesCount'] as num?)?.toInt() ?? 0;
    if (likesCount == 0 && rawLikes is List) {
      likesCount = rawLikes.length;
    }
    bool isLiked = post['isLiked'] == true;
    if (!isLiked && rawLikes is List && _myUserId != null) {
      isLiked = rawLikes.any((l) => (l is Map ? l['_id']?.toString() : l.toString()) == _myUserId);
    }

    final commentsCount = (post['commentsCount'] as num?)?.toInt() ?? 0;
    final images = post['images'] is List ? List<dynamic>.from(post['images']) : [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderTheme),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openPostDetail(post),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Row(
                children: [
                  if (isAnon)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.masks_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    )
                  else
                    AppAvatar(
                      avatar: authorAvatar,
                      name: authorName,
                      radius: 20,
                      fontSize: 14,
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                authorName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: context.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isAnon) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orangeAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.orangeAccent.withValues(alpha: 0.4),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  l10n.anonymous,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orangeAccent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (content.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: context.textPrimary,
                  ),
                ),
              ],

              if (images.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      images.first.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                if (images.length > 1) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.otherImagesCount(images.length - 1),
                    style: TextStyle(fontSize: 11.5, color: context.textMuted),
                  ),
                ],
              ],

              const SizedBox(height: 14),
              Divider(height: 1, color: context.dividerTheme),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                    onTap: () => _toggleLikePost(post),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                      child: Row(
                        children: [
                          Icon(
                            isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 19,
                            color: isLiked ? Colors.redAccent : context.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            likesCount > 0 ? '$likesCount' : l10n.like,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isLiked ? FontWeight.bold : FontWeight.w500,
                              color: isLiked ? Colors.redAccent : context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _openPostDetail(post),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 18,
                            color: context.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            commentsCount > 0 ? '$commentsCount ${l10n.comments}' : l10n.comment,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPostDetail(Map<String, dynamic> post) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          post: post,
          userEmail: _myEmail,
          userName: _myName,
          userAvatar: _myAvatar,
          onPostUpdated: (updated) {
            setState(() {
              final idx = _groupPosts.indexWhere(
                (p) => (p['_id'] ?? p['id']) == (updated['_id'] ?? updated['id']),
              );
              if (idx != -1) {
                _groupPosts[idx] = updated;
              }
            });
          },
        ),
      ),
    );
    _fetchGroupPosts();
  }

  Future<void> _toggleLikePost(Map<String, dynamic> post) async {
    final postId = post['_id']?.toString() ?? post['id']?.toString();
    if (postId == null || postId.isEmpty) return;

    final wasLiked = post['isLiked'] == true;
    final currentLikes = (post['likesCount'] as num?)?.toInt() ?? 0;

    setState(() {
      post['isLiked'] = !wasLiked;
      post['likesCount'] = wasLiked ? (currentLikes > 0 ? currentLikes - 1 : 0) : currentLikes + 1;
    });

    try {
      final res = await PostService.likePost(postId);
      if (res != null && res['success'] == true) {
        if (mounted) {
          setState(() {
            if (res['likesCount'] != null) {
              post['likesCount'] = res['likesCount'];
            }
            if (res['isLiked'] != null) {
              post['isLiked'] = res['isLiked'];
            }
          });
        }
      }
    } catch (_) {}
  }

  String _formatTimeAgo(dynamic timestamp) {
    return TimeFormatter.formatTimeAgo(context, timestamp);
  }

  void _showMembersBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.groupMembersWithCount(_membersCount),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: _buildMembersList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isActionLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isMember) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                final convId = _conversationId ?? widget.groupId;
                if (convId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatDetailScreen(
                        conversationId: convId,
                        name: _groupName,
                        avatar: _groupAvatar,
                        color: _themeColor,
                        isGroup: true,
                        initialMessages: const [],
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.chat_bubble_rounded, size: 18, color: Colors.white),
              label: Text(l10n.groupChat, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _showInviteFriendsBottomSheet,
            icon: Icon(Icons.person_add_rounded, size: 18, color: context.textPrimary),
            label: Text(l10n.inviteFriends, style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: BorderSide(color: context.borderTheme),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      );
    }

    if (_groupPrivacy == 'public') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _handleJoinPublicGroup,
          icon: const Icon(Icons.group_add_rounded, size: 18, color: Colors.white),
          label: Text(l10n.joinGroupNow, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blue,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      );
    }

    if (_groupPrivacy == 'private') {
      if (_hasRequested) {
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _handleCancelRequest,
            icon: const Icon(Icons.access_time_rounded, size: 18, color: Colors.orangeAccent),
            label: Text(l10n.requestPendingApproval, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: const BorderSide(color: Colors.orangeAccent, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        );
      }

      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _handleRequestJoinPrivateGroup,
          icon: const Icon(Icons.lock_open_rounded, size: 18, color: Colors.white),
          label: Text(l10n.requestToJoinGroupWithParens, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orangeAccent,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.purpleAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_clock_rounded, size: 18, color: Colors.purpleAccent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              l10n.onlyInvitedMembersCanJoin,
              style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    final list = _members.isNotEmpty
        ? _members
        : [
            {'name': l10n.groupOwner, 'role': 'owner'},
          ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: list.map((m) {
          final mName = m['name']?.toString() ?? l10n.groupMember;
          final mRole = m['role']?.toString() ?? 'member';
          final isOwner = mRole == 'owner';
          final isAdmin = mRole == 'admin';

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderTheme),
            ),
            child: Row(
              children: [
                AppAvatar(
                  avatar: m['avatar']?.toString(),
                  name: mName,
                  radius: 18,
                  fontSize: 13,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        isOwner ? l10n.groupOwner : isAdmin ? l10n.groupAdmin : l10n.groupMember,
                        style: TextStyle(
                          fontSize: 11,
                          color: isOwner ? AppColors.blue : isAdmin ? Colors.orangeAccent : context.textMuted,
                          fontWeight: isOwner || isAdmin ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _InviteFriendsModal extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String groupPrivacy;
  final List<String> existingMemberIds;

  const _InviteFriendsModal({
    required this.groupId,
    required this.groupName,
    required this.groupPrivacy,
    required this.existingMemberIds,
  });

  @override
  State<_InviteFriendsModal> createState() => _InviteFriendsModalState();
}

class _InviteFriendsModalState extends State<_InviteFriendsModal> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _friends = [];
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final data = await ContactService.fetchContacts();
    if (!mounted) return;

    if (data != null && data['friends'] is List) {
      final raw = data['friends'] as List;
      final list = raw.map((f) => f as Map<String, dynamic>).where((f) {
        final id = f['id']?.toString() ?? '';
        return !widget.existingMemberIds.contains(id);
      }).toList();

      setState(() {
        _friends = list;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendInvites() async {
    if (_selectedIds.isEmpty) return;

    setState(() => _isSubmitting = true);
    final res = await GroupService.inviteMembers(widget.groupId, userIds: _selectedIds.toList());
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res != null && res['success'] == true) {
      Navigator.pop(context);
      AppToast.success(context, res['message']?.toString() ?? l10n.inviteSentSuccess);
    } else {
      AppToast.error(context, l10n.errorFromCode(res?['code'], fallbackMessage: res?['message']?.toString() ?? l10n.requestConnectionError));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderTheme, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.inviteFriendsToGroup, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: context.textPrimary)),
                    Text(l10n.selectFriendsToInviteDesc(widget.groupName), style: TextStyle(fontSize: 12, color: context.textMuted)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _friends.isEmpty
                    ? Center(child: Text(l10n.noNewFriendsToInvite, style: TextStyle(color: context.textMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _friends.length,
                        itemBuilder: (ctx, i) {
                          final f = _friends[i];
                          final id = f['id']?.toString() ?? '';
                          final isSelected = _selectedIds.contains(id);

                          return ListTile(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedIds.remove(id);
                                } else {
                                  _selectedIds.add(id);
                                }
                              });
                            },
                            leading: AppAvatar(avatar: f['avatar']?.toString(), name: f['name']?.toString() ?? 'U', radius: 20),
                            title: Text(f['name']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.textPrimary)),
                            trailing: Checkbox(
                              value: isSelected,
                              activeColor: AppColors.blue,
                              onChanged: (_) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedIds.remove(id);
                                  } else {
                                    _selectedIds.add(id);
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _selectedIds.isEmpty || _isSubmitting ? null : _sendInvites,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(l10n.sendInviteWithCount(_selectedIds.length), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageRequestsModal extends StatefulWidget {
  final String groupId;
  final String groupName;
  final VoidCallback onProcessed;

  const _ManageRequestsModal({
    required this.groupId,
    required this.groupName,
    required this.onProcessed,
  });

  @override
  State<_ManageRequestsModal> createState() => _ManageRequestsModalState();
}

class _ManageRequestsModalState extends State<_ManageRequestsModal> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final list = await GroupService.getJoinRequests(widget.groupId);
    if (!mounted) return;
    setState(() {
      _requests = list;
      _isLoading = false;
    });
  }

  Future<void> _handleAction(String targetUserId, String action) async {
    final ok = await GroupService.handleJoinRequest(widget.groupId, targetUserId: targetUserId, action: action);
    if (!mounted) return;

    if (ok) {
      AppToast.success(context, action == 'approve' ? l10n.approvedMemberToast : l10n.rejectedRequestToast);
      setState(() {
        _requests.removeWhere((r) => r['userId']?.toString() == targetUserId);
      });
      widget.onProcessed();
    } else {
      AppToast.error(context, l10n.errorProcessingRequest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderTheme, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.groupJoinRequests, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: context.textPrimary)),
                    Text(l10n.approveMembersDesc(widget.groupName), style: TextStyle(fontSize: 12, color: context.textMuted)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _requests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.green),
                            const SizedBox(height: 10),
                            Text(l10n.noPendingRequests, style: TextStyle(color: context.textMuted, fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _requests.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final r = _requests[i];
                          final uId = r['userId']?.toString() ?? '';
                          final name = r['name']?.toString() ?? l10n.user;
                          final message = r['message']?.toString() ?? '';

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.actionPillBg,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                AppAvatar(avatar: r['avatar']?.toString(), name: name, radius: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.textPrimary)),
                                      if (message.isNotEmpty)
                                        Text('"$message"', style: TextStyle(fontSize: 12, color: context.textMuted, fontStyle: FontStyle.italic)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () => _handleAction(uId, 'reject'),
                                  icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 22),
                                ),
                                ElevatedButton(
                                  onPressed: () => _handleAction(uId, 'approve'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: Text(l10n.approve, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
