import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/theme_helper.dart';
import '../../widgets/app_avatar.dart';
import '../chat/chat_detail_screen.dart';
import '../../l10n/language.dart';

class GroupsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> groups;
  final String searchQuery;
  final VoidCallback? onRefresh;

  const GroupsScreen({
    super.key,
    required this.groups,
    required this.searchQuery,
    this.onRefresh,
  });

  Color _getPrivacyColor(String? privacy) {
    if (privacy == 'public') return AppColors.blue;
    if (privacy == 'private') return Colors.orangeAccent;
    return Colors.purpleAccent;
  }

  String _getPrivacyName(BuildContext context, String? privacy) {
    final l10n = context.l10n;
    if (privacy == 'public') return l10n.public;
    if (privacy == 'private') return l10n.pendingApproval;
    return l10n.groupInternalSecret;
  }

  IconData _getPrivacyIcon(String? privacy) {
    if (privacy == 'public') return Icons.public_rounded;
    if (privacy == 'private') return Icons.lock_outline_rounded;
    return Icons.visibility_off_outlined;
  }

  Color _resolveColor(dynamic val, Color fallback) {
    if (val is Color) return val;
    if (val is String && val.startsWith('#')) {
      final hex = val.replaceFirst('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final filteredGroups = groups.where((grp) {
      final name = (grp['name'] ?? '').toString().toLowerCase();
      final query = searchQuery.toLowerCase();
      return name.contains(query);
    }).toList();

    if (filteredGroups.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 80, bottom: 110),
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.groups_outlined,
                  size: 48,
                  color: context.textMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  searchQuery.isNotEmpty
                      ? l10n.noMatchingGroups
                      : l10n.notInAnyGroupYet,
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 110.0),
      itemCount: filteredGroups.length,
      itemBuilder: (ctx, i) {
        final grp = filteredGroups[i];
        final gPrivacy = grp['privacy']?.toString() ?? 'public';
        final privacyColor = _getPrivacyColor(gPrivacy);
        final pendingReqs = (grp['pendingRequestsCount'] as num?)?.toInt() ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: context.contactCardShadow,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.profileGroup,
                arguments: {
                  'id': grp['id'],
                  'groupId': grp['id'],
                  'name': grp['name'],
                  'avatar': grp['avatar'],
                  'color': _resolveColor(grp['color'], privacyColor),
                  'membersCount': grp['membersCount'],
                  'privacy': gPrivacy,
                  'description': grp['description'] ?? grp['lastMessage'],
                  'conversationId': grp['conversationId']?.toString() ?? grp['id']?.toString(),
                },
              ).then((_) => onRefresh?.call());
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Stack(
              children: [
                AppAvatar(
                  avatar: grp['avatar'],
                  name: grp['name'],
                  color: _resolveColor(grp['color'], privacyColor),
                  radius: 24,
                  fontSize: 15,
                  enableViewer: true,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: privacyColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.cardBg, width: 2),
                    ),
                    child: Icon(_getPrivacyIcon(gPrivacy), size: 9, color: Colors.white),
                  ),
                ),
              ],
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    grp['name'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: context.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: privacyColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getPrivacyName(context, gPrivacy),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: privacyColor,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    grp['lastMessage'] ?? '',
                    style: TextStyle(color: context.textMuted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.people_alt_outlined, size: 13, color: AppColors.blue),
                      const SizedBox(width: 4),
                      Text(
                        '${grp['membersCount']} ${l10n.members}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (pendingReqs > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$pendingReqs ${l10n.pendingApproval}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.orangeAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.blue, size: 20),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatDetailScreen(
                      conversationId: grp['conversationId']?.toString() ?? grp['id']?.toString(),
                      name: grp['name'] ?? '',
                      avatar: grp['avatar'] ?? '',
                      color: _resolveColor(grp['color'], privacyColor),
                      isGroup: true,
                      initialMessages: const [],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
