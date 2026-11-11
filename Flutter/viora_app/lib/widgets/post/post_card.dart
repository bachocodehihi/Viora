import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../services/socket_service.dart';
import '../../utils/time_formatter.dart';
import '../app_avatar.dart';
import '../app_mention_text.dart';
import '../bottomsheet/app_comment.dart';
import '../bottomsheet/app_post_options.dart';
import '../reaction/fb_reaction_box.dart';
import 'post_images_grid.dart';

class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final String? currentUserEmail;
  final String? currentUserName;
  final String? currentUserAvatar;
  final Color? defaultAvatarColor;
  final VoidCallback? onPostTap;
  final VoidCallback? onLikeTap;
  final ValueChanged<FbReaction>? onReactionSelected;
  final ValueChanged<int>? onCommentCountChanged;
  final VoidCallback? onPostDeleted;
  final VoidCallback? onNotInterested;
  final ValueChanged<bool>? onCommentsStatusChanged;
  final ValueChanged<Map<String, dynamic>>? onCommentSettingsChanged;
  final VoidCallback? onShareTap;

  const PostCard({
    super.key,
    required this.post,
    this.currentUserEmail,
    this.currentUserName,
    this.currentUserAvatar,
    this.defaultAvatarColor,
    this.onPostTap,
    this.onLikeTap,
    this.onReactionSelected,
    this.onCommentCountChanged,
    this.onPostDeleted,
    this.onNotInterested,
    this.onCommentsStatusChanged,
    this.onCommentSettingsChanged,
    this.onShareTap,
  });

  void _defaultOpenPostDetail(BuildContext context) {
    Navigator.pushNamed(
      context,
      AppRoutes.postDetail,
      arguments: {
        'post': post,
        'userEmail': currentUserEmail,
        'userName': currentUserName,
        'userAvatar': currentUserAvatar,
        'onPostUpdated': (updatedPost) {
          post['likes'] = updatedPost['likes'];
          post['likesCount'] = updatedPost['likes'];
          post['isLiked'] = updatedPost['isLiked'];
          post['reaction'] = updatedPost['reaction'];
          post['comments'] = updatedPost['comments'];
          post['commentsCount'] = updatedPost['comments'];
          if (onCommentCountChanged != null) {
            final c = (updatedPost['comments'] as num?)?.toInt() ?? 0;
            onCommentCountChanged!(c);
          }
        },
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final bool isAnon = post['isAnonymous'] == true ||
        Language.isAnonymousMemberName(post['userName']?.toString());
    final groupData = post['group'] is Map ? Map<String, dynamic>.from(post['group'] as Map) : null;
    final bool isGroupPost = (post['postType'] == 'group' || groupData != null) &&
        (groupData != null && (groupData['name']?.toString().trim().isNotEmpty ?? false));
    final String groupName = isGroupPost ? (groupData!['name']?.toString() ?? '') : '';
    final String? groupAvatar = isGroupPost ? groupData!['avatar']?.toString() : null;
    final String? groupId = isGroupPost ? (groupData!['id'] ?? groupData!['_id'])?.toString() : null;

    final postAuthorId = (post['author'] is Map ? post['author']['_id'] : post['author'])?.toString() ??
        post['userId']?.toString();
    final myUserId = SocketService.currentUserId;
    final isMyPost = (myUserId != null && postAuthorId != null && postAuthorId == myUserId) ||
        post['isOwner'] == true;

    final authorName = isAnon
        ? (isMyPost ? '${l10n.anonymousMember} (${l10n.you})' : l10n.anonymousMember)
        : (post['userName'] ??
                (post['author'] is Map ? post['author']['username'] : null) ??
                l10n.user)
            .toString();
    final avatarUrl = isAnon
        ? null
        : (post['avatar']?.toString() ??
            (post['author'] is Map ? post['author']['avatar']?.toString() : null));
    final rawTime = post['createdAt'] ?? post['time'];
    final timeStr = TimeFormatter.formatTimeAgo(context, rawTime);
    final contentStr = (post['content'] ?? '').toString();
    final postId = (post['id'] ?? post['_id'] ?? '').toString();
    final likesCount = (post['likes'] as num?)?.toInt() ??
        (post['likesCount'] as num?)?.toInt() ??
        0;
    final commentsCount = (post['comments'] as num?)?.toInt() ??
        (post['commentsCount'] as num?)?.toInt() ??
        0;
    final isLiked = post['isLiked'] == true;
    final reactionStr = post['reaction'] as String?;
    final postImages = post['images'] is List ? (post['images'] as List) : [];
    final avatarColor = (post['color'] as Color?) ?? defaultAvatarColor;

    final handlePostTap = onPostTap ?? () => _defaultOpenPostDetail(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.momentShadow,
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: context.borderTheme,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: isGroupPost
                    ? Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (groupId != null && groupId.isNotEmpty) {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.profileGroup,
                                  arguments: {
                                    'id': groupId,
                                    'groupId': groupId,
                                    'name': groupName,
                                    'avatar': groupAvatar ?? '',
                                  },
                                );
                              }
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                AppAvatar(
                                  avatar: groupAvatar,
                                  name: groupName,
                                  radius: 20,
                                  fontSize: 14,
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: isAnon ? const Color(0xFF242429) : context.cardBg,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isAnon ? Colors.orangeAccent : context.borderTheme,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: isAnon
                                        ? const Icon(
                                            Icons.visibility_off_rounded,
                                            size: 10,
                                            color: Colors.orangeAccent,
                                          )
                                        : AppAvatar(
                                            avatar: avatarUrl,
                                            name: authorName,
                                            radius: 8,
                                            fontSize: 7,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: GestureDetector(
                                        onTap: () {
                                          if (groupId != null && groupId.isNotEmpty) {
                                            Navigator.pushNamed(
                                              context,
                                              AppRoutes.profileGroup,
                                              arguments: {
                                                'id': groupId,
                                                'groupId': groupId,
                                                'name': groupName,
                                                'avatar': groupAvatar ?? '',
                                              },
                                            );
                                          }
                                        },
                                        child: Text(
                                          groupName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14.5,
                                            color: context.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: AppColors.blue.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: AppColors.blue.withValues(alpha: 0.3),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.groups_rounded, size: 10, color: AppColors.blue),
                                          const SizedBox(width: 3),
                                          Text(
                                            l10n.group,
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              color: AppColors.blue,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (isAnon) ...[
                                      Text(
                                        authorName,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: context.textSubtle,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.orangeAccent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          l10n.anonymous,
                                          style: const TextStyle(
                                            fontSize: 9,
                                            color: Colors.orangeAccent,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.pushNamed(
                                            context,
                                            AppRoutes.profileAccount,
                                            arguments: {
                                              'id': post['userId'] ?? postId,
                                              'email': post['userEmail'],
                                              'name': authorName,
                                              'avatar': avatarUrl,
                                              'color': avatarColor,
                                            },
                                          );
                                        },
                                        child: Text(
                                          authorName,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: context.textSubtle,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                    Text(
                                      ' • $timeStr',
                                      style: TextStyle(
                                        color: context.textSubtle,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.profileAccount,
                            arguments: {
                              'id': post['userId'] ?? postId,
                              'email': post['userEmail'],
                              'name': authorName,
                              'avatar': avatarUrl,
                              'color': avatarColor,
                            },
                          );
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: [
                            AppAvatar(
                              avatar: avatarUrl,
                              name: authorName,
                              color: avatarColor,
                              radius: 18,
                              fontSize: 13,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authorName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    color: context.textSubtle,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
              IconButton(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  size: 20,
                  color: context.textMuted,
                ),
                onPressed: () {
                  AppPostOptionsBottomSheet.show(
                    context,
                    post: post,
                    onNotInterested: onNotInterested ?? () {},
                    onPostDeleted: onPostDeleted ?? () {},
                    onCommentsStatusChanged: onCommentsStatusChanged ?? (_) {},
                    onCommentSettingsChanged: onCommentSettingsChanged ?? (_) {},
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (contentStr.isNotEmpty) ...[
            GestureDetector(
              onTap: handlePostTap,
              child: AppMentionText(
                text: contentStr,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: context.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (postImages.isNotEmpty) ...[
            PostImagesGrid(
              images: postImages,
              onImageTap: handlePostTap,
            ),
            const SizedBox(height: 14),
          ],

          Row(
            children: [
              FbReactionLikeButton(
                count: likesCount,
                isLiked: isLiked,
                reaction: reactionStr,
                onTap: onLikeTap ?? () {},
                onReactionSelected: onReactionSelected ?? (_) {},
              ),
              const SizedBox(width: 22),

              GestureDetector(
                onTap: () {
                  AppCommentBottomSheet.show(
                    context,
                    postId: postId,
                    postAuthor: authorName,
                    initialCommentCount: commentsCount,
                    userEmail: currentUserEmail,
                    userName: currentUserName,
                    userAvatar: currentUserAvatar,
                    isGroupPost: isGroupPost,
                    onCommentCountChanged: (newCount) {
                      post['comments'] = newCount;
                      post['commentsCount'] = newCount;
                      if (onCommentCountChanged != null) {
                        onCommentCountChanged!(newCount);
                      }
                    },
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 23,
                        color: context.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$commentsCount',
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),

              GestureDetector(
                onTap: onShareTap ??
                    () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.share,
                        arguments: {
                          'postAuthor': authorName,
                          'postContent': contentStr,
                        },
                      );
                    },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.share_outlined,
                    size: 23,
                    color: context.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

