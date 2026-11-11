import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../services/post_service.dart';
import '../../services/session_service.dart';
import '../../services/socket_service.dart';
import '../app_avatar.dart';
import '../app_mention_text.dart';
import '../toast/app_toast.dart';
import '../../utils/time_formatter.dart';

RegExp getCommentMentionRegex([String? localizedAnonymous]) => Language.getCommentMentionRegex();
bool isAnonymousMention(String mention, [String? localizedAnonymous]) => Language.isAnonymousMention(mention);
String getLocalizedMentionDisplay(String rawMention, Language l10n) => Language.getLocalizedMentionDisplay(rawMention, l10n);

class CommentTextEditingController extends TextEditingController {
  final Color mentionColor;

  CommentTextEditingController({
    super.text,
    this.mentionColor = AppColors.blue,
  });

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final fullText = value.text;
    final regex = getCommentMentionRegex(context.l10n.anonymousMember);
    final matches = regex.allMatches(fullText);

    if (matches.isEmpty) {
      return TextSpan(text: fullText, style: style);
    }

    final List<InlineSpan> children = [];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        children.add(TextSpan(
          text: fullText.substring(lastEnd, match.start),
          style: style,
        ));
      }
      children.add(TextSpan(
        text: match.group(0),
        style: (style ?? const TextStyle()).copyWith(
          color: mentionColor,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
          fontFamilyFallback: const ['Inter', 'Roboto', 'sans-serif'],
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < fullText.length) {
      children.add(TextSpan(
        text: fullText.substring(lastEnd),
        style: style,
      ));
    }

    return TextSpan(style: style, children: children);
  }
}

class AppCommentBottomSheet extends StatefulWidget {
  final String? postId;
  final String postAuthor;
  final int initialCommentCount;
  final Function(int count)? onCommentCountChanged;
  final String? userEmail;
  final String? userName;
  final String? userAvatar;
  final bool isGroupPost;

  const AppCommentBottomSheet({
    super.key,
    this.postId,
    required this.postAuthor,
    this.initialCommentCount = 0,
    this.onCommentCountChanged,
    this.userEmail,
    this.userName,
    this.userAvatar,
    this.isGroupPost = false,
  });

  static Future<void> show(
    BuildContext context, {
    String? postId,
    required String postAuthor,
    int initialCommentCount = 0,
    Function(int count)? onCommentCountChanged,
    String? userEmail,
    String? userName,
    String? userAvatar,
    bool isGroupPost = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppCommentBottomSheet(
        postId: postId,
        postAuthor: postAuthor,
        initialCommentCount: initialCommentCount,
        onCommentCountChanged: onCommentCountChanged,
        userEmail: userEmail,
        userName: userName,
        userAvatar: userAvatar,
        isGroupPost: isGroupPost,
      ),
    );
  }

  @override
  State<AppCommentBottomSheet> createState() => _AppCommentBottomSheetState();
}

class _AppCommentBottomSheetState extends State<AppCommentBottomSheet> {
  Language get l10n => context.l10n;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  String? _myAvatar;
  String? _myUsername;
  String? _myEmail;
  String? _myUserId;

  bool _isGroupPost = false;
  bool _isAnonymousComment = false;

  bool _commentsDisabled = false;
  bool _canComment = true;
  String _commentRestrictionReason = '';
  bool _isOwner = false;

  String? _replyingToCommentId;
  String? _replyingToName;

  final Map<String, int> _visibleRepliesCount = {};
  final Set<String> _expandedCommentTextIds = {};

  final CommentTextEditingController _commentController = CommentTextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _isGroupPost = widget.isGroupPost;
    _myAvatar = widget.userAvatar;
    _myUsername = widget.userName;
    _myEmail = widget.userEmail;
    _loadUserInfo();
    _loadComments();

    SocketService.init();
    if (widget.postId != null && widget.postId!.isNotEmpty) {
      SocketService.joinPost(widget.postId!);
      SocketService.onNewComment(_onSocketNewComment);
      SocketService.onCommentLiked(_onSocketCommentLiked);
    }
  }

  void _onSocketNewComment(Map<String, dynamic> data) {
    if (!mounted) return;
    final incomingPostId = data['postId']?.toString();
    if (incomingPostId != widget.postId) return;

    final commentData = data['comment'];
    if (commentData is! Map) return;

    final newComment = Map<String, dynamic>.from(commentData);
    final commentId = (newComment['id'] ?? newComment['_id'])?.toString();

    final existingIdx = _comments.indexWhere((c) {
      final cId = (c['id'] ?? c['_id'])?.toString();
      if (cId != null && cId == commentId) return true;
      if (cId != null && cId.startsWith('temp_') && c['text'] == newComment['text']) return true;
      return false;
    });

    setState(() {
      if (existingIdx != -1) {
        _comments[existingIdx]['id'] = commentId;
        _comments[existingIdx]['_id'] = commentId;
        if (newComment['parentComment'] != null) {
          _comments[existingIdx]['parentComment'] = newComment['parentComment'].toString();
        }
      } else {
        final parentId = newComment['parentComment']?.toString();
        if (parentId == null) {
          _comments.insert(0, newComment);
        } else {
          _comments.add(newComment);
          _visibleRepliesCount[parentId] = (_visibleRepliesCount[parentId] ?? 0) + 5;
        }
      }
    });

    final commentsCount = data['commentsCount'];
    if (commentsCount is num) {
      widget.onCommentCountChanged?.call(commentsCount.toInt());
    } else {
      widget.onCommentCountChanged?.call(_comments.length);
    }
  }

  void _onSocketCommentLiked(Map<String, dynamic> data) {
    if (!mounted) return;
    final incomingPostId = data['postId']?.toString();
    if (incomingPostId != null && incomingPostId != widget.postId) return;

    final targetCommentId = data['commentId']?.toString();
    final likesCount = data['likesCount'] as num?;
    if (targetCommentId == null) return;

    final idx = _comments.indexWhere((c) => (c['id'] ?? c['_id'])?.toString() == targetCommentId);
    if (idx != -1) {
      setState(() {
        if (likesCount != null) {
          _comments[idx]['likes'] = likesCount.toInt();
        }
      });
    }
  }

  Future<void> _loadUserInfo() async {
    final avatar = await SessionService.getAvatar();
    final username = await SessionService.getUsername();
    final email = await SessionService.getUserEmail();
    final userId = await SessionService.getUserId();
    if (mounted) {
      setState(() {
        _myAvatar = avatar ?? _myAvatar;
        _myUsername = username ?? _myUsername ?? '';
        _myEmail = email ?? _myEmail;
        _myUserId = userId;
      });
    }
  }

  Future<void> _loadComments() async {
    if (widget.postId == null || widget.postId!.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    final res = await PostService.getCommentsWithDetails(widget.postId!);
    if (mounted) {
      if (res != null) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(res['comments'] ?? []);
          _commentsDisabled = res['commentsDisabled'] == true;
          _canComment = res['canComment'] != false;
          _commentRestrictionReason = res['commentRestrictionReason']?.toString() ?? '';
          _isOwner = res['isOwner'] == true;
          if (res['isGroupPost'] == true) {
            _isGroupPost = true;
          }
          _isLoading = false;
        });
      } else {
        final comments = await PostService.getComments(widget.postId!);
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    if (widget.postId != null && widget.postId!.isNotEmpty) {
      SocketService.leavePost(widget.postId!);
      SocketService.offNewComment(_onSocketNewComment);
      SocketService.offCommentLiked(_onSocketCommentLiked);
    }
    _commentController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startReply(Map<String, dynamic> comment) {
    final l10n = context.l10n;
    final rawName = comment['name']?.toString() ??
        (comment['author'] is Map ? comment['author']['username']?.toString() : null) ??
        comment['userName']?.toString() ??
        l10n.user;
    final isAnon = comment['isAnonymous'] == true ||
        Language.isAnonymousMemberName(rawName);

    final String replyName = isAnon ? l10n.anonymousMember : rawName;
    final parentId = comment['parentComment'] != null
        ? comment['parentComment'].toString()
        : (comment['id'] ?? comment['_id'])?.toString();

    setState(() {
      _replyingToCommentId = parentId;
      _replyingToName = replyName;
      _commentController.text = '@$replyName ';
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commentController.text.length),
      );
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToName = null;
      if (_commentController.text.startsWith('@')) {
        _commentController.clear();
      }
    });
  }

  Future<void> _addComment() async {
    final l10n = context.l10n;
    if (_commentsDisabled) {
      AppToast.show(
        context,
        l10n.commentsDisabledNotice,
        isError: true,
      );
      return;
    }
    if (!_canComment) {
      AppToast.show(
        context,
        _commentRestrictionReason == 'blocked'
            ? l10n.commentBlockedNotice
            : l10n.commentNoPermissionNotice,
        isError: true,
      );
      return;
    }

    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final parentId = _replyingToCommentId;

    final newCommentItem = <String, dynamic>{
      'id': tempId,
      '_id': tempId,
      'name': _isAnonymousComment
          ? '${l10n.anonymousMember} (${l10n.you})'
          : ((_myUsername != null && _myUsername!.isNotEmpty) ? _myUsername : l10n.you),
      'avatar': _isAnonymousComment ? null : _myAvatar,
      'color': AppColors.blue,
      'text': text,
      'time': 'just_now',
      'likes': 0,
      'isLiked': false,
      'isAnonymous': _isAnonymousComment,
      'canDelete': true,
      'parentComment': parentId,
      'createdAt': DateTime.now().toIso8601String(),
    };

    setState(() {
      if (parentId == null) {
        _comments.insert(0, newCommentItem);
      } else {
        _comments.add(newCommentItem);
        _visibleRepliesCount[parentId] = (_visibleRepliesCount[parentId] ?? 0) + 5;
      }
      _replyingToCommentId = null;
      _replyingToName = null;
    });

    widget.onCommentCountChanged?.call(_comments.length);
    _commentController.clear();

    if (_scrollController.hasClients && parentId == null) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    if (widget.postId != null && widget.postId!.isNotEmpty) {
      final res = await PostService.commentPost(
        postId: widget.postId!,
        content: text,
        parentCommentId: parentId,
        parentComment: parentId,
        email: _myEmail,
        userName: _myUsername,
        isAnonymous: _isAnonymousComment,
      );
      if (res != null && res['comment'] != null && mounted) {
        final serverComment = res['comment'] as Map<String, dynamic>;
        setState(() {
          final idx = _comments.indexWhere((c) => (c['id'] ?? c['_id']) == tempId);
          if (idx != -1) {
            _comments[idx]['id'] = serverComment['id'] ?? serverComment['_id'] ?? tempId;
            _comments[idx]['_id'] = serverComment['id'] ?? serverComment['_id'] ?? tempId;
            if (serverComment['parentComment'] != null) {
              _comments[idx]['parentComment'] = serverComment['parentComment'].toString();
            }
          }
        });
      }
    }
  }

  Future<void> _toggleLikeComment(Map<String, dynamic> item) async {
    final isLiked = item['isLiked'] as bool? ?? false;
    final currentLikes = (item['likes'] as num?)?.toInt() ?? 0;

    setState(() {
      item['isLiked'] = !isLiked;
      item['likes'] = isLiked ? (currentLikes - 1).clamp(0, 999999) : currentLikes + 1;
    });

    final commentId = (item['id'] ?? item['_id'])?.toString();
    if (commentId != null && !commentId.startsWith('temp_')) {
      await PostService.likeComment(commentId);
    }
  }

  void _showCommentOptionsMenu(Map<String, dynamic> comment) {
    final l10n = context.l10n;
    final commentId = (comment['id'] ?? comment['_id'])?.toString();
    if (commentId == null || commentId.startsWith('temp_')) return;

    final commentAuthorId = (comment['author'] is Map
            ? comment['author']['_id']
            : comment['author'])
        ?.toString();
    final commentName = comment['name']?.toString() ??
        (comment['author'] is Map ? comment['author']['username'] : null) ??
        l10n.user;
    final isMyComment = _myUserId != null && commentAuthorId == _myUserId;
    final canDelete = isMyComment || _isOwner;
    final canBlock = _isOwner && !isMyComment && commentAuthorId != null && commentAuthorId.isNotEmpty;

    if (!canDelete && !canBlock) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: context.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Text(
                    l10n.commentOptions,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: context.borderTheme),
            const SizedBox(height: 8),

            if (canDelete)
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 20),
                ),
                title: Text(
                  l10n.deleteComment,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.red,
                  ),
                ),
                subtitle: Text(
                  l10n.deleteCommentSub,
                  style: TextStyle(fontSize: 12, color: context.textMuted),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteComment(commentId);
                },
              ),

            if (canBlock)
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block_rounded, color: Colors.orange, size: 20),
                ),
                title: Text(
                  l10n.blockNameFromCommenting.replaceAll('{name}', commentName),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                subtitle: Text(
                  l10n.blockUserCommentSub,
                  style: TextStyle(fontSize: 12, color: context.textMuted),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _blockUser(commentAuthorId, commentName);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteComment(String commentId) async {
    final l10n = context.l10n;
    setState(() {
      _comments.removeWhere((c) =>
          (c['id'] ?? c['_id'])?.toString() == commentId ||
          c['parentComment']?.toString() == commentId);
    });
    widget.onCommentCountChanged?.call(_comments.length);

    final success = await PostService.deleteComment(commentId);
    if (mounted) {
      if (success) {
        AppToast.show(context, l10n.commentDeleted);
      } else {
        AppToast.show(context, l10n.failedToDeleteComment, isError: true);
      }
    }
  }

  Future<void> _blockUser(String targetUserId, String targetName) async {
    if (widget.postId == null || widget.postId!.isEmpty) return;
    final l10n = context.l10n;

    final success = await PostService.blockCommenter(
      postId: widget.postId!,
      targetUserId: targetUserId,
    );
    if (mounted) {
      if (success) {
        AppToast.show(
          context,
          l10n.blockedTargetCommenting.replaceAll('{name}', targetName),
        );
      } else {
        AppToast.show(context, l10n.failedToBlockCommenter, isError: true);
      }
    }
  }

  Widget _buildCommentContent(String text, BuildContext context, {String? commentId}) {
    final isExpanded = commentId != null && _expandedCommentTextIds.contains(commentId);
    return AppMentionText(
      text: text,
      maxLength: 140,
      isExpanded: isExpanded,
      onToggleExpand: commentId != null
          ? () {
              setState(() {
                if (isExpanded) {
                  _expandedCommentTextIds.remove(commentId);
                } else {
                  _expandedCommentTextIds.add(commentId);
                }
              });
            }
          : null,
    );
  }

  Widget _buildCommentItem({
    required Map<String, dynamic> comment,
    required bool isReply,
  }) {
    final commentId = (comment['id'] ?? comment['_id'])?.toString();
    final isLiked = comment['isLiked'] as bool? ?? false;
    final likesCount = (comment['likes'] as num?)?.toInt() ?? 0;
    final rawName = comment['name']?.toString() ??
        (comment['author'] is Map ? comment['author']['username']?.toString() : null) ??
        comment['userName']?.toString() ??
        l10n.user;
    final commentText = comment['text']?.toString() ?? '';
    final rawTime = comment['createdAt'] ?? comment['time'];
    final commentTime = TimeFormatter.formatTimeAgo(context, rawTime);

    final commentAuthorId = (comment['author'] is Map
            ? comment['author']['_id']
            : comment['author'])
        ?.toString();
    final isMyComment = (_myUserId != null && commentAuthorId == _myUserId) ||
        comment['canDelete'] == true ||
        Language.hasYouIndicator(rawName);
    final canDelete = isMyComment || _isOwner;
    final canBlock = _isOwner && !isMyComment && commentAuthorId != null && commentAuthorId.isNotEmpty;

    final isAnonymous = comment['isAnonymous'] == true ||
        Language.isAnonymousMemberName(rawName);

    final String displayName = isAnonymous
        ? (isMyComment ? '${l10n.anonymousMember} (${l10n.you})' : l10n.anonymousMember)
        : rawName;

    return Padding(
      padding: EdgeInsets.only(
        left: isReply ? 42.0 : 0.0,
        top: isReply ? 8.0 : 0.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAnonymous)
            Container(
              width: (isReply ? 14 : 18) * 2,
              height: (isReply ? 14 : 18) * 2,
              decoration: BoxDecoration(
                color: const Color(0xFF242429),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.6), width: 1.2),
              ),
              child: Icon(
                Icons.visibility_off_rounded,
                color: Colors.orangeAccent,
                size: isReply ? 13 : 16,
              ),
            )
          else
            AppAvatar(
              avatar: comment['avatar'],
              name: displayName,
              color: comment['color'] as Color?,
              radius: isReply ? 14 : 18,
              fontSize: isReply ? 11 : 13,
              enableViewer: false,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: () => _showCommentOptionsMenu(comment),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isReply ? 12 : 14,
                      vertical: isReply ? 8 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: context.isDark ? const Color(0xFF1B1B26) : Colors.grey.withValues(alpha: 0.08),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isReply ? 12 : 13,
                                  color: context.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isAnonymous) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.orangeAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.orangeAccent.withValues(alpha: 0.4),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  l10n.anonymous,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orangeAccent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        _buildCommentContent(commentText, context, commentId: commentId),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Row(
                    children: [
                      Text(
                        commentTime,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => _toggleLikeComment(comment),
                        child: Row(
                          children: [
                            Icon(
                              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 13,
                              color: isLiked ? Colors.red : context.textMuted,
                            ),
                            if (likesCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '$likesCount',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isLiked ? FontWeight.bold : FontWeight.normal,
                                  color: isLiked ? Colors.red : context.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => _startReply(comment),
                        child: Text(
                          l10n.reply,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.textMuted,
                          ),
                        ),
                      ),
                      if (canDelete || canBlock) ...[
                        const SizedBox(width: 14),
                        GestureDetector(
                          onTap: () => _showCommentOptionsMenu(comment),
                          child: Icon(
                            Icons.more_horiz_rounded,
                            size: 16,
                            color: context.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    final topLevelComments = _comments.where((c) => c['parentComment'] == null).toList();
    final parentIds = topLevelComments.map((c) => (c['id'] ?? c['_id'])?.toString()).toSet();
    final orphanReplies = _comments
        .where((c) => c['parentComment'] != null && !parentIds.contains(c['parentComment']?.toString()))
        .toList();
    topLevelComments.addAll(orphanReplies);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: screenHeight * 0.75 + keyboardHeight,
        margin: EdgeInsets.only(bottom: keyboardHeight),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: context.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        l10n.comment,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_comments.length}',
                          style: const TextStyle(
                            color: AppColors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: context.textMuted, size: 22),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Divider(height: 1, thickness: 0.5, color: context.borderTheme),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.blue,
                      ),
                    )
                  : _comments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 48, color: context.textMuted.withValues(alpha: 0.4)),
                              const SizedBox(height: 10),
                              Text(
                                l10n.noCommentsYet,
                                style: TextStyle(color: context.textMuted, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          physics: const ClampingScrollPhysics(),
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.all(16),
                          itemCount: topLevelComments.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final parent = topLevelComments[index];
                            final parentId = (parent['id'] ?? parent['_id'])?.toString();
                            final replies = _comments.where((c) => c['parentComment']?.toString() == parentId).toList();
                            final visibleRepliesLimit = _visibleRepliesCount[parentId] ?? 0;
                            final displayedReplies = replies.take(visibleRepliesLimit).toList();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCommentItem(comment: parent, isReply: false),
                                if (replies.isNotEmpty) ...[
                                  if (visibleRepliesLimit == 0)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 42.0, top: 6.0),
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _visibleRepliesCount[parentId!] = 5;
                                          });
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 24,
                                              height: 1.2,
                                              color: AppColors.blue.withValues(alpha: 0.5),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              l10n.viewRepliesCount(replies.length),
                                              style: const TextStyle(
                                                color: AppColors.blue,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.blue),
                                          ],
                                        ),
                                      ),
                                    )
                                  else ...[
                                    for (final reply in displayedReplies)
                                      _buildCommentItem(comment: reply, isReply: true),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 42.0, top: 8.0),
                                      child: Row(
                                        children: [
                                          if (replies.length > visibleRepliesLimit) ...[
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _visibleRepliesCount[parentId!] = visibleRepliesLimit + 5;
                                                });
                                              },
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 20,
                                                    height: 1.2,
                                                    color: AppColors.blue.withValues(alpha: 0.5),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    l10n.viewMoreRepliesCount(replies.length - visibleRepliesLimit > 5 ? 5 : replies.length - visibleRepliesLimit),
                                                    style: const TextStyle(
                                                      color: AppColors.blue,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 2),
                                                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.blue),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                          ],
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _visibleRepliesCount[parentId!] = 0;
                                              });
                                            },
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 16,
                                                  height: 1.2,
                                                  color: context.textMuted.withValues(alpha: 0.4),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  l10n.collapse,
                                                  style: TextStyle(
                                                    color: context.textMuted,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(width: 2),
                                                Icon(Icons.keyboard_arrow_up_rounded, size: 16, color: context.textMuted),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            );
                          },
                        ),
            ),

            if (_replyingToName != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                color: context.isDark ? const Color(0xFF1B1B26) : Colors.grey.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded, size: 16, color: AppColors.blue),
                    const SizedBox(width: 6),
                    Text(
                      l10n.replyingToPrefix,
                      style: TextStyle(fontSize: 12, color: context.textMuted),
                    ),
                    Text(
                      '@$_replyingToName',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.blue,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _cancelReply,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(Icons.close_rounded, size: 16, color: context.textMuted),
                      ),
                    ),
                  ],
                ),
              ),

            Divider(height: 1, thickness: 0.5, color: context.borderTheme),

            if (_commentsDisabled)
              SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  color: context.isDark ? const Color(0xFF1B1B26) : Colors.grey.withValues(alpha: 0.08),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.comments_disabled_outlined, size: 18, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        l10n.commentsDisabledNotice,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (!_canComment)
              SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  color: context.isDark ? const Color(0xFF1B1B26) : Colors.grey.withValues(alpha: 0.08),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _commentRestrictionReason == 'blocked' ? Icons.block_rounded : Icons.lock_outline_rounded,
                        size: 18,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _commentRestrictionReason == 'blocked'
                            ? l10n.commentBlockedNotice
                            : (_commentRestrictionReason == 'friends_only'
                                ? l10n.onlyFriendsCanComment
                                : l10n.onlySelectedCanComment),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Row(
                    children: [
                      if (_isAnonymousComment)
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF242429),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.orangeAccent, width: 1.5),
                          ),
                          child: const Icon(Icons.visibility_off_rounded, color: Colors.orangeAccent, size: 18),
                        )
                      else
                        AppAvatar(
                          avatar: _myAvatar,
                          name: (_myUsername != null && _myUsername!.isNotEmpty) ? _myUsername : l10n.you,
                          radius: 18,
                          fontSize: 13,
                          enableViewer: false,
                        ),
                      if (_isGroupPost) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          icon: Icon(
                            _isAnonymousComment ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: _isAnonymousComment ? Colors.orangeAccent : context.textMuted,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 18,
                          onPressed: () {
                            setState(() {
                              _isAnonymousComment = !_isAnonymousComment;
                            });
                          },
                        ),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.isDark ? const Color(0xFF1E1E2C) : Colors.grey.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _isAnonymousComment
                                  ? Colors.orangeAccent.withValues(alpha: 0.5)
                                  : (context.isDark
                                      ? Colors.white.withValues(alpha: 0.18)
                                      : Colors.black.withValues(alpha: 0.15)),
                              width: 1.2,
                            ),
                          ),
                          child: TextField(
                            controller: _commentController,
                            focusNode: _focusNode,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _addComment(),
                            style: TextStyle(color: context.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              fillColor: Colors.transparent,
                              hintText: _replyingToName != null
                                  ? '${l10n.replyToPrefix} @$_replyingToName...'
                                  : (_isAnonymousComment ? l10n.anonymousCommentHint : l10n.writeCommentHint),
                              hintStyle: TextStyle(
                                color: _isAnonymousComment ? Colors.orangeAccent.withValues(alpha: 0.7) : context.textMuted,
                                fontSize: 13.5,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addComment,
                        icon: Icon(
                          Icons.send_rounded,
                          color: _isAnonymousComment ? Colors.orangeAccent : AppColors.blue,
                          size: 26,
                        ),
                        splashRadius: 22,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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
}
