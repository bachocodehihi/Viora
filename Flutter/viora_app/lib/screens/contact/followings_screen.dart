import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../widgets/app_avatar.dart';
import 'contact_screen.dart';

class FollowingsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> following;
  final String searchQuery;
  final Function(Map<String, dynamic>) onToggleFollow;
  final VoidCallback? onRefresh;

  const FollowingsScreen({
    super.key,
    required this.following,
    required this.searchQuery,
    required this.onToggleFollow,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filteredFollowing = following.where((user) {
      final name = (user['name'] ?? '').toString().toLowerCase();
      final handle = (user['handle'] ?? '').toString().toLowerCase();
      final bio = (user['bio'] ?? '').toString().toLowerCase();
      final query = searchQuery.toLowerCase();
      return name.contains(query) || handle.contains(query) || bio.contains(query);
    }).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 6.0, bottom: 110.0),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${l10n.followingListTitle} (${filteredFollowing.length})',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filteredFollowing.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.person_outline_rounded, size: 48, color: context.textMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 10),
                Text(
                  l10n.noFollowingFound,
                  style: TextStyle(color: context.textMuted, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          )
        else
          ...filteredFollowing.map((user) {
            final isFollowing = user['isFollowing'] == true;
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
                onTap: () async {
                  await Navigator.pushNamed(
                    context,
                    AppRoutes.profileAccount,
                    arguments: {
                      'id': user['id'],
                      'name': user['name'],
                      'avatar': user['avatar'],
                      'color': user['color'],
                      'status': user['bio'] ?? '',
                    },
                  );
                  onRefresh?.call();
                  ContactScreen.triggerRefresh();
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: AppAvatar(
                  avatar: user['avatar'],
                  name: user['name'],
                  color: user['color'] as Color? ?? AppColors.purple,
                  radius: 24,
                  fontSize: 16,
                  enableViewer: true,
                ),
                title: Text(
                  user['name'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: context.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: GestureDetector(
                  onTap: () => onToggleFollow(user),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isFollowing ? context.actionPillBg : AppColors.blue,
                      borderRadius: BorderRadius.circular(20),
                      border: isFollowing
                          ? Border.all(color: context.textMuted.withValues(alpha: 0.25), width: 1)
                          : null,
                    ),
                    child: Text(
                      isFollowing ? l10n.following : l10n.follow,
                      style: TextStyle(
                        color: isFollowing ? context.textPrimary : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
