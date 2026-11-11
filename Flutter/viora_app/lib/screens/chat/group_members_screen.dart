import '../../l10n/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../services/group_service.dart';
import '../../widgets/app_avatar.dart';
import '../profile/profile_account_screen.dart';

class GroupMembersScreen extends StatefulWidget {
  final String groupName;
  final String? groupAvatar;
  final Color? groupColor;
  final String? groupId;
  final String? conversationId;
  final List<Map<String, dynamic>> initialMembers;

  const GroupMembersScreen({
    super.key,
    required this.groupName,
    this.groupAvatar,
    this.groupColor,
    this.groupId,
    this.conversationId,
    this.initialMembers = const [],
  });

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  Language get l10n => context.l10n;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _members = List.from(widget.initialMembers);
    _loadGroupMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupMembers() async {
    final targetId = widget.groupId ?? widget.conversationId;
    if (targetId == null || targetId.isEmpty) return;

    if (_members.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final data = await GroupService.getGroupDetail(targetId);
      if (data != null && data['members'] is List) {
        final list = List<Map<String, dynamic>>.from(data['members']);
        if (mounted) {
          setState(() {
            _members = list;
          });
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredMembers {
    if (_searchQuery.trim().isEmpty) return _members;
    final q = _searchQuery.trim().toLowerCase();
    return _members.where((m) {
      final name = (m['name'] ?? m['username'] ?? '').toString().toLowerCase();
      final role = (m['role'] ?? '').toString().toLowerCase();
      return name.contains(q) || role.contains(q);
    }).toList();
  }

  Color _parseColor(dynamic c, String? name) {
    if (c is Color) return c;
    if (c is String && c.startsWith('#')) {
      try {
        return Color(int.parse(c.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return AppAvatar.getColorForName(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filtered = _filteredMembers;
    final totalCount = _members.length;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        titleSpacing: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          totalCount > 0 ? '${l10n.members} ($totalCount)' : l10n.groupMembers,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [

          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 12.h),
            child: Container(
              height: 42.h,
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: context.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(fontSize: 13.5.sp, color: context.textPrimary),
                decoration: InputDecoration(
                  hintText: l10n.searchMembersHint,
                  hintStyle: TextStyle(fontSize: 13.sp, color: context.textMuted),
                  prefixIcon: Icon(Icons.search_rounded, size: 20.r, color: context.textMuted),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: Icon(Icons.close_rounded, size: 18.r, color: context.textMuted),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                ),
              ),
            ),
          ),

          Expanded(
            child: _isLoading && _members.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_search_rounded, size: 48.r, color: context.textMuted),
                            SizedBox(height: 12.h),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? l10n.noMatchingMembers
                                  : l10n.noMembersYet,
                              style: TextStyle(fontSize: 14.sp, color: context.textMuted),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadGroupMembers,
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            thickness: 0.5,
                            color: context.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                          ),
                          itemBuilder: (context, index) {
                            final m = filtered[index];
                            final memberId = m['id']?.toString() ?? m['userId']?.toString();
                            final name = (m['name'] ?? m['username'] ?? l10n.groupMember).toString();
                            final avatar = m['avatar']?.toString();
                            final role = (m['role'] ?? 'member').toString().toLowerCase();

                            final bool isOwner = role == 'owner';
                            final bool isAdmin = role == 'admin';

                            String roleLabel = l10n.groupMember;
                            Color roleColor = context.textMuted;
                            Color roleBg = Colors.transparent;

                            if (isOwner) {
                              roleLabel = l10n.groupOwner;
                              roleColor = const Color(0xFFF59E0B);
                              roleBg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
                            } else if (isAdmin) {
                              roleLabel = l10n.groupAdmin;
                              roleColor = AppColors.blue;
                              roleBg = AppColors.blue.withValues(alpha: 0.12);
                            }

                            return InkWell(
                              onTap: () {
                                if (memberId != null && memberId.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProfileAccountScreen(
                                        userId: memberId,
                                        email: '',
                                        name: name,
                                        avatar: avatar,
                                        color: _parseColor(null, name),
                                        status: '${l10n.groupMemberStatusPrefix} ${widget.groupName}',
                                      ),
                                    ),
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(10.r),
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 4.w),
                                child: Row(
                                  children: [
                                    AppAvatar(
                                      avatar: avatar,
                                      name: name,
                                      color: _parseColor(null, name),
                                      radius: 22.r,
                                      fontSize: 14.sp,
                                      enableViewer: false,
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 14.5.sp,
                                              fontWeight: FontWeight.w600,
                                              color: context.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (isOwner || isAdmin) ...[
                                            SizedBox(height: 3.h),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                              decoration: BoxDecoration(
                                                color: roleBg,
                                                borderRadius: BorderRadius.circular(6.r),
                                              ),
                                              child: Text(
                                                roleLabel,
                                                style: TextStyle(
                                                  fontSize: 10.5.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: roleColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20.r,
                                      color: context.textMuted.withValues(alpha: 0.5),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
