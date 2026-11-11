import '../../l10n/language.dart';
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../services/contact_service.dart';
import '../../services/message_service.dart';
import '../../widgets/toast/app_toast.dart';
import '../../widgets/app_avatar.dart';

class ShareScreen extends StatefulWidget {
  final String postAuthor;
  final String postContent;

  const ShareScreen({
    super.key,
    required this.postAuthor,
    required this.postContent,
  });

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  List<Map<String, dynamic>> _targets = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  int _selectedFilter = 0;

  static const List<Color> _avatarColors = [
    AppColors.blue,
    AppColors.purple,
    AppColors.pink,
    AppColors.orange,
    AppColors.teal,
  ];

  Color _getColor(dynamic id, int fallbackIndex) {
    if (id is String && id.isNotEmpty) {
      return _avatarColors[id.hashCode.abs() % _avatarColors.length];
    }
    return _avatarColors[fallbackIndex % _avatarColors.length];
  }

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  Future<void> _loadTargets() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ContactService.fetchContacts(),
        MessageService.fetchConversations(),
      ]);
      if (!mounted) return;
      final l10n = context.l10n;

      final contactData = results[0] as Map<String, dynamic>?;
      final conversations = results[1] as List<Map<String, dynamic>>?;

      final Map<String, String> userConvMap = {};
      final Map<String, String> groupConvMap = {};

      if (conversations != null) {
        for (final conv in conversations) {
          final cId = conv['id']?.toString() ?? '';
          if (conv['isGroup'] == true) {
            final name = conv['name']?.toString() ?? '';
            if (name.isNotEmpty) groupConvMap[name] = cId;
          } else {
            final otherUserId = conv['otherUserId']?.toString();
            if (otherUserId != null && otherUserId.isNotEmpty) {
              userConvMap[otherUserId] = cId;
            }
          }
        }
      }

      final List<Map<String, dynamic>> loadedTargets = [];
      final Set<String> addedFriendIds = {};
      final Set<String> addedGroupIds = {};

      if (contactData != null && contactData['friends'] is List) {
        final rawFriends = contactData['friends'] as List;
        for (int i = 0; i < rawFriends.length; i++) {
          final f = rawFriends[i] as Map<String, dynamic>;
          final id = f['id']?.toString() ?? '';
          if (id.isEmpty || addedFriendIds.contains(id)) continue;
          addedFriendIds.add(id);

          final name = f['name']?.toString() ?? '';
          final avatar = f['avatar']?.toString() ?? (name.isNotEmpty ? name[0].toUpperCase() : 'U');

          loadedTargets.add({
            'id': id,
            'type': 'friend',
            'name': name,
            'avatar': avatar,
            'color': _getColor(id, i),
            'subtitle': l10n.friends,
            'conversationId': userConvMap[id],
            'sent': false,
          });
        }
      }

      if (contactData != null && contactData['groups'] is List) {
        final rawGroups = contactData['groups'] as List;
        for (int i = 0; i < rawGroups.length; i++) {
          final g = rawGroups[i] as Map<String, dynamic>;
          final id = g['id']?.toString() ?? '';
          if (id.isEmpty || addedGroupIds.contains(id)) continue;
          addedGroupIds.add(id);

          final name = g['name']?.toString() ?? '';
          final membersCount = g['membersCount'] is int ? g['membersCount'] : 1;
          final avatar = g['avatar']?.toString() ?? (name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'GR');

          loadedTargets.add({
            'id': id,
            'type': 'group',
            'name': name,
            'avatar': avatar,
            'color': _getColor(id, i),
            'subtitle': l10n.groupMembersCountSubtitle(membersCount),
            'conversationId': groupConvMap[name] ?? id,
            'sent': false,
          });
        }
      }

      if (conversations != null) {
        for (int i = 0; i < conversations.length; i++) {
          final conv = conversations[i];
          final isGroup = conv['isGroup'] == true;
          final name = conv['name']?.toString() ?? '';
          final cId = conv['id']?.toString() ?? '';
          final otherUserId = conv['otherUserId']?.toString();

          if (isGroup) {
            if (!addedGroupIds.contains(cId) && !loadedTargets.any((t) => t['name'] == name)) {
              addedGroupIds.add(cId);
              loadedTargets.add({
                'id': cId,
                'type': 'group',
                'name': name,
                'avatar': conv['avatar']?.toString() ?? (name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'GR'),
                'color': _getColor(cId, i),
                'subtitle': l10n.chatGroup,
                'conversationId': cId,
                'sent': false,
              });
            }
          } else {
            if (otherUserId != null && otherUserId.isNotEmpty && !addedFriendIds.contains(otherUserId)) {
              addedFriendIds.add(otherUserId);
              loadedTargets.add({
                'id': otherUserId,
                'type': 'friend',
                'name': name,
                'avatar': conv['avatar']?.toString() ?? (name.isNotEmpty ? name[0].toUpperCase() : 'U'),
                'color': _getColor(otherUserId, i),
                'subtitle': l10n.friends,
                'conversationId': cId,
                'sent': false,
              });
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _targets = loadedTargets;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('_loadTargets error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _sendShare(Map<String, dynamic> target) async {
    setState(() {
      target['sent'] = true;
    });

    final String author = widget.postAuthor.isNotEmpty ? widget.postAuthor : l10n.postLabel;
    final String content = widget.postContent.isNotEmpty
        ? l10n.sharedPostOfAuthorWithContent(author, widget.postContent)
        : l10n.sharedPostOfAuthor(author);

    try {
      if (target['type'] == 'group') {
        await MessageService.sendMessage(
          content: content,
          conversationId: target['conversationId'] ?? target['id'],
        );
      } else {
        await MessageService.sendMessage(
          content: content,
          receiverId: target['id'],
          conversationId: target['conversationId'],
        );
      }
    } catch (e) {
      debugPrint('ShareScreen _sendShare error: $e');
    }

    if (mounted) {
      AppToast.success(context, '${l10n.sharedPostToTarget} ${target['name']}!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filteredTargets = _targets.where((item) {
      if (_selectedFilter == 1 && item['type'] != 'friend') return false;
      if (_selectedFilter == 2 && item['type'] != 'group') return false;

      final name = item['name'].toString().toLowerCase();
      final sub = item['subtitle'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || sub.contains(query);
    }).toList();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.sharePostTitle,
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: false,
          titleSpacing: 0,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Column(
          children: [

            if (widget.postContent.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderTheme),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_rounded, color: AppColors.blue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.postAuthor.isNotEmpty ? widget.postAuthor : l10n.post,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.postContent,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: context.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 6.0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                style: TextStyle(color: context.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: l10n.searchFriendsOrGroups,
                  hintStyle: TextStyle(color: context.textMuted, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: context.textMuted, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  filled: true,
                  fillColor: context.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: context.isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: context.isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Row(
                children: [
                  _buildFilterChip(0, l10n.allWithCount(_targets.length)),
                  const SizedBox(width: 8),
                  _buildFilterChip(1, l10n.friends),
                  const SizedBox(width: 8),
                  _buildFilterChip(2, l10n.groups),
                ],
              ),
            ),

            const SizedBox(height: 4),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.blue,
                        strokeWidth: 2.5,
                      ),
                    )
                  : filteredTargets.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: context.textMuted.withValues(alpha: 0.4)),
                              const SizedBox(height: 10),
                              Text(
                                l10n.noFriendsOrGroupsFound,
                                style: TextStyle(color: context.textMuted, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredTargets.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final target = filteredTargets[index];
                        final isGroup = target['type'] == 'group';
                        final isSent = target['sent'] == true;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: context.contactCardShadow,
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  AppAvatar(
                                    avatar: target['avatar'],
                                    name: target['name'],
                                    color: target['color'] as Color?,
                                    radius: 24,
                                    fontSize: 16,
                                  ),
                                  if (isGroup)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: AppColors.blue,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: context.cardBg, width: 1.5),
                                        ),
                                        child: const Icon(Icons.groups_rounded, size: 10, color: Colors.white),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      target['name'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      target['subtitle'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: 36,
                                child: isSent
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.green.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.check_rounded, color: AppColors.green, size: 16),
                                            const SizedBox(width: 4),
                                            Text(
                                              l10n.sent,
                                              style: const TextStyle(
                                                color: AppColors.green,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ElevatedButton(
                                        onPressed: () => _sendShare(target),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.blue,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 18),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: Text(
                                          l10n.send,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            Divider(height: 1, thickness: 0.5, color: context.borderTheme),

            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildShortcutItem(
                      context,
                      icon: Icons.link_rounded,
                      label: l10n.copyLink,
                      onTap: () {
                        AppToast.success(context, l10n.postLinkCopied);
                      },
                    ),
                    _buildShortcutItem(
                      context,
                      icon: Icons.bookmark_border_rounded,
                      label: l10n.savePost,
                      onTap: () {
                        AppToast.info(context, l10n.postSavedToCollection);
                      },
                    ),
                    _buildShortcutItem(
                      context,
                      icon: Icons.share_rounded,
                      label: l10n.moreShares,
                      onTap: () {
                        AppToast.info(context, l10n.openingShareMenu);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue : context.actionPillBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : context.textMuted,
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.isDark ? const Color(0xFF1E1E2C) : Colors.grey.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: context.textPrimary, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: context.textMuted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
