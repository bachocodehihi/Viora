import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../widgets/app_avatar.dart';
import '../../utils/time_formatter.dart';
import 'contact_screen.dart';

class RequestsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final String searchQuery;
  final Function(Map<String, dynamic>) onAcceptFriend;
  final Function(Map<String, dynamic>) onDeclineFriend;
  final Function(Map<String, dynamic>)? onAcceptFollow;
  final Function(Map<String, dynamic>)? onDeclineFollow;
  final Function(Map<String, dynamic>) onAcceptGroup;
  final Function(Map<String, dynamic>) onDeclineGroup;

  const RequestsScreen({
    super.key,
    required this.requests,
    required this.searchQuery,
    required this.onAcceptFriend,
    required this.onDeclineFriend,
    this.onAcceptFollow,
    this.onDeclineFollow,
    required this.onAcceptGroup,
    required this.onDeclineGroup,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filteredRequests = requests.where((req) {
      final name = req['name'].toString().toLowerCase();
      final inviter = (req['inviter'] ?? '').toString().toLowerCase();
      final query = searchQuery.toLowerCase();
      return name.contains(query) || inviter.contains(query);
    }).toList();

    final followReqs = filteredRequests.where((r) => r['type'] == 'follow').toList();
    final friendReqs = filteredRequests.where((r) => r['type'] == 'friend' || (r['type'] != 'group' && r['type'] != 'follow')).toList();
    final groupInvites = filteredRequests.where((r) => r['type'] == 'group').toList();

    if (filteredRequests.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 6.0, bottom: 110.0),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 48),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.mark_email_read_outlined, size: 48, color: context.textMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 10),
                Text(
                  l10n.noFriendRequests,
                  style: TextStyle(color: context.textMuted, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 6.0, bottom: 110.0),
      children: [
        if (followReqs.isNotEmpty) ...[
          Text(
            '${l10n.followRequestsTitle} (${followReqs.length})',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...followReqs.map((req) => _buildRequestCard(context, req, isGroup: false)),
          const SizedBox(height: 16),
        ],

        if (friendReqs.isNotEmpty) ...[
          Text(
            '${l10n.friendRequestsTitle} (${friendReqs.length})',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...friendReqs.map((req) => _buildRequestCard(context, req, isGroup: false)),
          const SizedBox(height: 16),
        ],

        if (groupInvites.isNotEmpty) ...[
          Text(
            '${l10n.groupInvitesTitle} (${groupInvites.length})',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...groupInvites.map((req) => _buildRequestCard(context, req, isGroup: true)),
        ],
      ],
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> req, {required bool isGroup}) {
    final l10n = context.l10n;
    final bool isFollow = req['type'] == 'follow';

    final rawTime = req['createdAt'] ?? req['time'];
    final timeStr = TimeFormatter.formatTimeAgo(context, rawTime);

    final String subtitleText = isGroup
        ? '${req['inviter']} ${l10n.invitedBy} • ${req['membersCount']} ${l10n.members} • $timeStr'
        : isFollow
            ? '${l10n.followRequestsTitle} • $timeStr'
            : '${req['mutualFriends']} ${l10n.mutualFriends} • $timeStr';

    void navigateToProfile() {
      if (isGroup) {
        Navigator.pushNamed(
          context,
          AppRoutes.profileGroup,
          arguments: {
            'id': req['groupId'] ?? req['id'],
            'name': req['name'],
            'avatar': req['avatar'],
            'color': req['color'],
            'membersCount': req['membersCount'],
          },
        );
      } else {
        Navigator.pushNamed(
          context,
          AppRoutes.profileAccount,
          arguments: {
            'id': req['senderId'] ?? req['id'],
            'userId': req['senderId'] ?? req['id'],
            'requestId': req['id'],
            'hasFriendRequest': !isFollow,
            'name': req['name'],
            'avatar': req['avatar'],
            'color': req['color'],
            'mutualFriends': req['mutualFriends'] ?? 0,
          },
        ).then((_) => ContactScreen.triggerRefresh());
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.contactCardShadow,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: navigateToProfile,
            behavior: HitTestBehavior.opaque,
            child: AppAvatar(
              avatar: req['avatar'],
              name: req['name'],
              color: req['color'] as Color? ?? (isFollow ? AppColors.purple : AppColors.blue),
              radius: 26,
              fontSize: 18,
              badge: isGroup
                  ? Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.cardBg, width: 2),
                      ),
                      child: const Icon(Icons.groups_rounded, size: 12, color: Colors.white),
                    )
                  : isFollow
                      ? Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.purple,
                            shape: BoxShape.circle,
                            border: Border.all(color: context.cardBg, width: 2),
                          ),
                          child: const Icon(Icons.person_add_rounded, size: 12, color: Colors.white),
                        )
                      : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: navigateToProfile,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req['name'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitleText,
                        style: TextStyle(fontSize: 12, color: context.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: () {
                            if (isGroup) {
                              onAcceptGroup(req);
                            } else if (isFollow) {
                              if (onAcceptFollow != null) {
                                onAcceptFollow!(req);
                              } else {
                                onAcceptFriend(req);
                              }
                            } else {
                              onAcceptFriend(req);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFollow ? AppColors.purple : AppColors.blue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              l10n.accept,
                              maxLines: 1,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: OutlinedButton(
                          onPressed: () {
                            if (isGroup) {
                              onDeclineGroup(req);
                            } else if (isFollow) {
                              if (onDeclineFollow != null) {
                                onDeclineFollow!(req);
                              } else {
                                onDeclineFriend(req);
                              }
                            } else {
                              onDeclineFriend(req);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.textMuted,
                            side: BorderSide(color: context.borderTheme),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              l10n.decline,
                              maxLines: 1,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
