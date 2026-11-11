import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../services/profile_service.dart';
import '../../widgets/app_avatar.dart';

class CommentHistoryScreen extends StatefulWidget {
  const CommentHistoryScreen({super.key});

  @override
  State<CommentHistoryScreen> createState() => _CommentHistoryScreenState();
}

class _CommentHistoryScreenState extends State<CommentHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _commentItems = [];

  @override
  void initState() {
    super.initState();
    _loadCommentHistory();
  }

  Future<void> _loadCommentHistory() async {
    setState(() => _isLoading = true);
    final items = await ProfileService.getCommentHistory();
    if (mounted) {
      setState(() {
        _commentItems = items;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.commentHistory,
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
          onRefresh: _loadCommentHistory,
          color: AppColors.blue,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
              : _commentItems.isEmpty
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
                                  color: AppColors.blue.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 48,
                                  color: AppColors.blue,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.noCommentsYet,
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
                                  l10n.noCommentsDesc,
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
                      itemCount: _commentItems.length,
                      itemBuilder: (context, index) {
                        final item = _commentItems[index];
                        final post = item['post'] is Map ? item['post'] as Map<String, dynamic> : <String, dynamic>{};
                        final authorName = post['authorName']?.toString() ?? l10n.user;
                        final authorAvatar = post['authorAvatar']?.toString() ?? '';
                        final postContent = post['content']?.toString() ?? '';
                        final commentContent = item['content']?.toString() ?? '';
                        final timeAgo = item['timeAgo']?.toString() ?? '';

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
                                        radius: 16,
                                        fontSize: 12,
                                        enableViewer: false,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text.rich(
                                          TextSpan(
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontFamilyFallback: const ['Inter', 'Roboto', 'sans-serif'],
                                              fontSize: 12.5,
                                              color: context.textMuted,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: l10n.youCommentedOn,
                                              ),
                                              TextSpan(
                                                text: authorName,
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontFamilyFallback: const ['Inter', 'Roboto', 'sans-serif'],
                                                  fontWeight: FontWeight.bold,
                                                  color: context.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        timeAgo,
                                        style: TextStyle(fontSize: 11, color: context.textSubtle),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: context.isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : Colors.grey.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          size: 16,
                                          color: AppColors.blue,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            commentContent,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w500,
                                              color: context.textPrimary,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (postContent.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(
                                        '${l10n.postLabel}: "$postContent"',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.textSubtle,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
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
