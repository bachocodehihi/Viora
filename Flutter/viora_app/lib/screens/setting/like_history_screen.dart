import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../services/profile_service.dart';
import '../../widgets/app_avatar.dart';

class LikeHistoryScreen extends StatefulWidget {
  const LikeHistoryScreen({super.key});

  @override
  State<LikeHistoryScreen> createState() => _LikeHistoryScreenState();
}

class _LikeHistoryScreenState extends State<LikeHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _likedItems = [];

  @override
  void initState() {
    super.initState();
    _loadLikeHistory();
  }

  Future<void> _loadLikeHistory() async {
    setState(() => _isLoading = true);
    final items = await ProfileService.getLikeHistory();
    if (mounted) {
      setState(() {
        _likedItems = items;
        _isLoading = false;
      });
    }
  }

  IconData _getReactionIcon(String type) {
    switch (type.toLowerCase()) {
      case 'love':
        return Icons.favorite_rounded;
      case 'haha':
        return Icons.sentiment_very_satisfied_rounded;
      case 'wow':
        return Icons.sentiment_neutral_rounded;
      case 'sad':
        return Icons.sentiment_dissatisfied_rounded;
      case 'angry':
        return Icons.sentiment_very_dissatisfied_rounded;
      default:
        return Icons.thumb_up_rounded;
    }
  }

  Color _getReactionColor(String type) {
    switch (type.toLowerCase()) {
      case 'love':
        return AppColors.red;
      case 'haha':
      case 'wow':
        return Colors.amber;
      case 'sad':
        return Colors.orange;
      case 'angry':
        return Colors.deepOrange;
      default:
        return AppColors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.likeHistory,
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 19,
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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadLikeHistory,
          color: AppColors.blue,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
              : _likedItems.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.red.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.favorite_rounded,
                                  size: 48,
                                  color: AppColors.red,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.noLikedPosts,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 40),
                                child: Text(
                                  l10n.noLikedPostsDesc,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: context.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _likedItems.length,
                      itemBuilder: (context, index) {
                        final item = _likedItems[index];
                        final post = item['post'] is Map ? item['post'] as Map<String, dynamic> : <String, dynamic>{};
                        final authorName = post['authorName']?.toString() ?? l10n.user;
                        final authorAvatar = post['authorAvatar']?.toString() ?? '';
                        final content = post['content']?.toString() ?? '';
                        final images = post['images'] is List ? post['images'] as List : [];
                        final reactionType = item['reactionType']?.toString() ?? 'like';
                        final timeAgo = post['timeAgo']?.toString() ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: context.borderTheme),
                            boxShadow: [
                              BoxShadow(
                                color: context.settingsCardBg,
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.postDetail,
                                arguments: {
                                  'post': post,
                                  'userName': authorName,
                                  'userAvatar': authorAvatar,
                                },
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      AppAvatar(
                                        avatar: authorAvatar,
                                        name: authorName,
                                        color: AppColors.blue,
                                        radius: 18,
                                        enableViewer: false,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              authorName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: context.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              timeAgo,
                                              style: TextStyle(fontSize: 11, color: context.textMuted),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getReactionColor(reactionType).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getReactionIcon(reactionType),
                                              color: _getReactionColor(reactionType),
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              reactionType.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: _getReactionColor(reactionType),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (content.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      content,
                                      style: TextStyle(fontSize: 13.5, color: context.textPrimary, height: 1.35),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  if (images.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: AspectRatio(
                                        aspectRatio: 16 / 9,
                                        child: Image.network(
                                          images.first.toString(),
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Icon(Icons.favorite_rounded, size: 14, color: AppColors.red),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${post['likesCount'] ?? 0}',
                                        style: TextStyle(fontSize: 11.5, color: context.textMuted),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(Icons.chat_bubble_outline_rounded, size: 14, color: context.textMuted),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${post['commentsCount'] ?? 0}',
                                        style: TextStyle(fontSize: 11.5, color: context.textMuted),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
