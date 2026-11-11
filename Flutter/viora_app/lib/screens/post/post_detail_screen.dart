import '../../l10n/language.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../config/app_routes.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_mention_text.dart';
import '../../widgets/bottomsheet/app_post_options.dart';
import '../../widgets/bottomsheet/app_comment.dart';
import '../../widgets/reaction/fb_reaction_box.dart';
import '../../services/post_service.dart';
import '../../services/session_service.dart';
import '../../services/socket_service.dart';
import '../../utils/time_formatter.dart';

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final String? userEmail;
  final String? userName;
  final String? userAvatar;
  final Function(Map<String, dynamic> updatedPost)? onPostUpdated;

  const PostDetailScreen({
    super.key,
    required this.post,
    this.userEmail,
    this.userName,
    this.userAvatar,
    this.onPostUpdated,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Language get l10n => context.l10n;
  late Map<String, dynamic> _post;
  late int _likesCount;
  late bool _isLiked;
  late String? _reactionStr;
  late int _commentsCount;

  final CommentTextEditingController _commentController = CommentTextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _comments = [];
  bool _isLoadingComments = true;

  final Map<String, int> _visibleRepliesCount = {};
  String? _replyingToCommentId;
  String? _replyingToName;

  String? _myAvatar;
  String? _myName;
  String? _myEmail;
  bool _isAnonymousComment = false;

  @override
  void initState() {
    super.initState();
    _post = Map<String, dynamic>.from(widget.post);
    _likesCount = int.tryParse(_post['likes']?.toString() ?? '0') ?? 0;
    _isLiked = _post['isLiked'] == true;
    _reactionStr = _post['reaction']?.toString();
    _commentsCount = int.tryParse(_post['comments']?.toString() ?? '0') ?? 0;

    _myAvatar = widget.userAvatar;
    _myName = widget.userName;
    _myEmail = widget.userEmail;

    _loadUserSession();
    _loadComments();

    SocketService.onPostLiked(_onSocketPostLiked);
  }

  void _onSocketPostLiked(Map<String, dynamic> data) {
    if (!mounted) return;
    final postId = data['postId']?.toString();
    if (postId != _postId) return;

    final count = (data['likesCount'] as num?)?.toInt();
    final userId = data['userId']?.toString();
    final isLiked = data['isLiked'] == true;
    final reaction = data['reaction']?.toString();

    debugPrint('[PostDetailScreen] _onSocketPostLiked: postId=$postId, count=$count, liker=$userId');

    if (count == null) return;
    final myUserId = SocketService.currentUserId;

    setState(() {
      _likesCount = count;
      _post['likes'] = count;
      if (myUserId != null && userId == myUserId) {
        _isLiked = isLiked;
        _reactionStr = reaction;
        _post['isLiked'] = isLiked;
        _post['reaction'] = reaction;
      }
    });
    widget.onPostUpdated?.call(_post);
  }

  Future<void> _loadUserSession() async {
    if (_myAvatar != null && _myName != null && _myEmail != null) return;
    final av = _myAvatar ?? await SessionService.getAvatar();
    final un = _myName ?? await SessionService.getUsername();
    final em = _myEmail ?? await SessionService.getUserEmail();
    if (mounted && (av != _myAvatar || un != _myName || em != _myEmail)) {
      setState(() {
        _myAvatar = av;
        _myName = un;
        _myEmail = em;
      });
    }
  }

  @override
  void dispose() {
    SocketService.offPostLiked(_onSocketPostLiked);
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _postId =>
      _post['id']?.toString() ?? _post['_id']?.toString() ?? '';

  Future<void> _loadComments() async {
    if (_postId.isEmpty) {
      setState(() => _isLoadingComments = false);
      return;
    }

    final comments = await PostService.getComments(_postId);
    if (mounted) {
      setState(() {
        _comments = comments;
        _isLoadingComments = false;
        if (comments.isNotEmpty && comments.length > _commentsCount) {
          _commentsCount = comments.length;
          _post['comments'] = _commentsCount;
          widget.onPostUpdated?.call(_post);
        }
      });
    }
  }

  Future<void> _toggleLike({String? reactionId}) async {
    final wasLiked = _isLiked;
    final currentReaction = _reactionStr;
    final currentLikes = _likesCount;

    bool nextLiked;
    String? nextReaction;
    int nextLikes;

    if (reactionId != null) {
      if (wasLiked && currentReaction == reactionId) {
        nextLiked = false;
        nextReaction = null;
        nextLikes = (currentLikes - 1).clamp(0, 999999);
      } else {
        nextLiked = true;
        nextReaction = reactionId;
        nextLikes = wasLiked ? currentLikes : currentLikes + 1;
      }
    } else {
      if (wasLiked) {
        nextLiked = false;
        nextReaction = null;
        nextLikes = (currentLikes - 1).clamp(0, 999999);
      } else {
        nextLiked = true;
        nextReaction = 'like';
        nextLikes = currentLikes + 1;
      }
    }

    setState(() {
      _isLiked = nextLiked;
      _reactionStr = nextReaction;
      _likesCount = nextLikes;
      _post['likes'] = _likesCount;
      _post['isLiked'] = _isLiked;
      _post['reaction'] = _reactionStr;
    });

    widget.onPostUpdated?.call(_post);

    if (!_postId.startsWith('temp_')) {
      PostService.likePost(_postId, reaction: nextReaction).then((res) {
        if (res != null && mounted) {
          setState(() {
            if (res['likesCount'] is int) {
              _likesCount = res['likesCount'];
              _post['likes'] = _likesCount;
            }
            if (res['isLiked'] is bool) {
              _isLiked = res['isLiked'];
              _post['isLiked'] = _isLiked;
            }
            _reactionStr = res['reaction']?.toString();
            _post['reaction'] = _reactionStr;
          });
          widget.onPostUpdated?.call(_post);
        }
      });
    }
  }

  void _startReply(Map<String, dynamic> comment) {
    final author = comment['author'];
    final rawName = comment['name']?.toString() ??
        (author is Map ? author['username']?.toString() : null) ??
        comment['userName']?.toString() ??
        l10n.user;
    final isAnon = comment['isAnonymous'] == true ||
        Language.isAnonymousMemberName(rawName);

    final replyName = isAnon ? l10n.anonymousMember : rawName;
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
    _commentFocusNode.requestFocus();
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

  Future<void> _toggleLikeComment(Map<String, dynamic> item) async {
    final isLiked = item['isLiked'] as bool? ?? false;
    final currentLikes = (item['likes'] as num?)?.toInt() ??
        (item['likesCount'] as num?)?.toInt() ??
        int.tryParse(item['likes']?.toString() ?? item['likesCount']?.toString() ?? '0') ??
        0;

    setState(() {
      item['isLiked'] = !isLiked;
      item['likes'] = isLiked ? (currentLikes - 1).clamp(0, 999999) : currentLikes + 1;
      item['likesCount'] = item['likes'];
    });

    final commentId = (item['id'] ?? item['_id'])?.toString();
    if (commentId != null && !commentId.startsWith('temp_')) {
      await PostService.likeComment(commentId);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final parentId = _replyingToCommentId;

    final newCommentItem = <String, dynamic>{
      'id': tempId,
      '_id': tempId,
      'name': _isAnonymousComment ? '${l10n.anonymousMember} (${l10n.you})' : (_myName ?? l10n.you),
      'avatar': _isAnonymousComment ? null : _myAvatar,
      'color': AppColors.blue,
      'text': text,
      'time': 'just_now',
      'likes': 0,
      'isLiked': false,
      'isAnonymous': _isAnonymousComment,
      'parentComment': parentId,
      'createdAt': DateTime.now().toIso8601String(),
    };

    setState(() {
      if (parentId == null) {
        _comments.insert(0, newCommentItem);
      } else {
        _comments.add(newCommentItem);
        _visibleRepliesCount[parentId] =
            (_visibleRepliesCount[parentId] ?? 0) + 5;
      }
      _commentsCount += 1;
      _post['comments'] = _commentsCount;
      _replyingToCommentId = null;
      _replyingToName = null;
    });

    _commentController.clear();
    widget.onPostUpdated?.call(_post);

    final res = await PostService.commentPost(
      postId: _postId,
      content: text,
      parentComment: parentId,
      userName: _myName,
      email: _myEmail,
      isAnonymous: _isAnonymousComment,
    );

    if (mounted) {
      if (res != null && res['comment'] != null) {
        final realComment = Map<String, dynamic>.from(res['comment']);
        setState(() {
          final idx = _comments.indexWhere((c) => (c['id'] ?? c['_id']) == tempId);
          if (idx != -1) {
            _comments[idx] = realComment;
          }
        });
        widget.onPostUpdated?.call(_post);
      }
    }
  }

  bool get _isAnonymousPost => _post['isAnonymous'] == true;
  bool get _isGroupPost => _post['group'] != null || _post['postType'] == 'group';

  Map<String, dynamic>? get _groupMap =>
      _post['group'] is Map ? (_post['group'] as Map<String, dynamic>) : null;
  String? get _groupName => _groupMap?['name']?.toString();
  String? get _groupAvatar => _groupMap?['avatar']?.toString();
  String? get _groupId => (_groupMap?['id'] ?? _groupMap?['_id'])?.toString();

  Map<String, dynamic>? get _authorMap =>
      _post['author'] is Map ? (_post['author'] as Map<String, dynamic>) : null;

  String get _authorName {
    if (_isAnonymousPost) {
      final myId = SocketService.currentUserId;
      final uid = _authorUserId;
      if (myId != null && uid != null && myId == uid) {
        return '${l10n.anonymousMember} (${l10n.you})';
      }
      return l10n.anonymousMember;
    }
    final name = _post['userName'] ??
        _authorMap?['username'] ??
        _authorMap?['name'] ??
        (_post['author'] is String ? _post['author'] : null);
    if (name != null && name.toString().trim().isNotEmpty) {
      return name.toString();
    }
    return l10n.user;
  }

  String? get _authorAvatar {
    if (_isAnonymousPost) return null;
    final av = _post['avatar'] ?? _authorMap?['avatar'];
    return av?.toString();
  }

  String? get _authorEmail {
    final em = _post['userEmail'] ?? _authorMap?['email'];
    return em?.toString();
  }

  String? get _authorUserId {
    final uid = _post['userId'] ?? _authorMap?['_id'] ?? _authorMap?['id'];
    return uid?.toString();
  }

  void _openFullscreenViewer(int initialIndex) {
    final images = _post['images'];
    if (images is! List || images.isEmpty) return;

    Navigator.pushNamed(
      context,
      AppRoutes.postImageViewer,
      arguments: {
        'images': images.map((e) => e.toString()).toList(),
        'initialIndex': initialIndex,
        'authorName': _authorName,
        'authorAvatar': _authorAvatar,
        'postTime': _post['time']?.toString(),
        'postContent': _post['content']?.toString(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authorName = _authorName;
    final avatarUrl = _authorAvatar;
    final rawTime = _post['createdAt'] ?? _post['time'];
    final timeStr = TimeFormatter.formatTimeAgo(context, rawTime);
    final contentStr = _post['content']?.toString() ?? '';
    final postImages = _post['images'] is List ? (_post['images'] as List) : [];
    final authorColor = _post['color'] as Color?;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        appBar: AppBar(
          backgroundColor: context.scaffoldBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: context.textPrimary,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.more_horiz_rounded,
                color: context.textMuted,
              ),
              onPressed: () {
                AppPostOptionsBottomSheet.show(
                  context,
                  post: _post,
                  onNotInterested: () {
                    Navigator.pop(context);
                  },
                  onPostDeleted: () {
                    Navigator.pop(context);
                  },
                  onCommentsStatusChanged: (disabled) {
                    setState(() {
                      _post['commentsDisabled'] = disabled;
                    });
                    widget.onPostUpdated?.call(_post);
                  },
                  onCommentSettingsChanged: (newSettings) {
                    setState(() {
                      _post.addAll(newSettings);
                    });
                    widget.onPostUpdated?.call(_post);
                  },
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [

            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  padding: const EdgeInsets.all(16),
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
                          if (_isGroupPost && _groupName != null && _groupName!.trim().isNotEmpty) ...[
                            GestureDetector(
                              onTap: () {
                                if (_groupId != null && _groupId!.isNotEmpty) {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.profileGroup,
                                    arguments: {
                                      'id': _groupId,
                                      'groupId': _groupId,
                                      'name': _groupName,
                                      'avatar': _groupAvatar ?? '',
                                    },
                                  );
                                }
                              },
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  AppAvatar(
                                    avatar: _groupAvatar,
                                    name: _groupName!,
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
                                        color: _isAnonymousPost ? const Color(0xFF242429) : context.cardBg,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _isAnonymousPost ? Colors.orangeAccent : context.borderTheme,
                                          width: 1.2,
                                        ),
                                      ),
                                      child: _isAnonymousPost
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
                                            if (_groupId != null && _groupId!.isNotEmpty) {
                                              Navigator.pushNamed(
                                                context,
                                                AppRoutes.profileGroup,
                                                arguments: {
                                                  'id': _groupId,
                                                  'groupId': _groupId,
                                                  'name': _groupName,
                                                  'avatar': _groupAvatar ?? '',
                                                },
                                              );
                                            }
                                          },
                                          child: Text(
                                            _groupName!,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
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
                                            Icon(Icons.groups_rounded, size: 10, color: AppColors.blue),
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
                                      if (_isAnonymousPost) ...[
                                        Text(
                                          authorName,
                                          style: TextStyle(
                                            fontSize: 12,
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
                                                'id': _authorUserId ?? _post['userId'] ?? _postId,
                                                'email': _authorEmail ?? _post['userEmail'],
                                                'name': authorName,
                                                'avatar': avatarUrl,
                                                'color': authorColor,
                                              },
                                            );
                                          },
                                          child: Text(
                                            authorName,
                                            style: TextStyle(
                                              fontSize: 12,
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
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            if (_isAnonymousPost)
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF242429),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.orangeAccent.withValues(alpha: 0.6),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.visibility_off_rounded,
                                  color: Colors.orangeAccent,
                                  size: 20,
                                ),
                              )
                            else
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.profileAccount,
                                    arguments: {
                                      'id': _authorUserId ?? _post['userId'] ?? _postId,
                                      'email': _authorEmail ?? _post['userEmail'],
                                      'name': authorName,
                                      'avatar': avatarUrl,
                                      'color': authorColor,
                                    },
                                  );
                                },
                                child: AppAvatar(
                                  avatar: avatarUrl,
                                  name: authorName,
                                  color: authorColor,
                                  radius: 20,
                                  fontSize: 14,
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
                                        child: Text(
                                          authorName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: context.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (_isAnonymousPost) ...[
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
                                      color: context.textSubtle,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),

                      if (contentStr.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        SelectableText(
                          contentStr,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: context.textPrimary,
                          ),
                        ),
                      ],

                      if (postImages.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        for (int i = 0; i < postImages.length; i++) ...[
                          GestureDetector(
                            onTap: () => _openFullscreenViewer(i),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _buildVerticalImage(postImages[i].toString()),
                            ),
                          ),
                          if (i < postImages.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          if (_likesCount > 0)
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.thumb_up_rounded,
                                    size: 11,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$_likesCount',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.textSubtle,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          const Spacer(),
                          Text(
                            l10n.commentsCount(_commentsCount),
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textSubtle,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      Divider(
                        color: context.dividerTheme,
                        thickness: 0.6,
                      ),
                      const SizedBox(height: 4),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          FbReactionLikeButton(
                            count: _likesCount,
                            isLiked: _isLiked,
                            reaction: _reactionStr,
                            onTap: () => _toggleLike(),
                            onReactionSelected: (reaction) =>
                                _toggleLike(reactionId: reaction.id),
                          ),
                          GestureDetector(
                            onTap: () {
                              _commentFocusNode.requestFocus();
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 21,
                                    color: context.textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.comment,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: context.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
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
                              padding: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 12),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.share_outlined,
                                    size: 21,
                                    color: context.textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.share,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: context.textMuted,
                                      fontWeight: FontWeight.w600,
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

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    l10n.commentsCountTitle(_commentsCount),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                ),

                if (_isLoadingComments)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 42,
                            color: context.textSubtle,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l10n.noCommentsYet,
                            style: TextStyle(
                              color: context.textSubtle,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.beFirstToComment,
                            style: TextStyle(
                              color: context.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Builder(
                    builder: (context) {
                      final topLevelComments = _comments
                          .where((c) => c['parentComment'] == null)
                          .toList();
                      final parentIds = topLevelComments
                          .map((c) => (c['id'] ?? c['_id'])?.toString())
                          .toSet();
                      final orphanReplies = _comments
                          .where((c) =>
                              c['parentComment'] != null &&
                              !parentIds.contains(c['parentComment']?.toString()))
                          .toList();
                      topLevelComments.addAll(orphanReplies);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (int i = 0; i < topLevelComments.length; i++) ...[
                              _buildCommentWithReplies(topLevelComments[i]),
                              if (i < topLevelComments.length - 1)
                                const SizedBox(height: 16),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
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
                      name: _myName ?? l10n.you,
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
                        focusNode: _commentFocusNode,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submitComment(),
                        style: TextStyle(color: context.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          fillColor: Colors.transparent,
                          hintText: _replyingToName != null
                              ? '${l10n.replyingTo} @$_replyingToName...'
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
                    onPressed: _submitComment,
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

  Widget _buildCommentWithReplies(Map<String, dynamic> parent) {
    final parentId = (parent['id'] ?? parent['_id'])?.toString();
    final replies = _comments
        .where((c) => c['parentComment']?.toString() == parentId)
        .toList();
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
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: AppColors.blue),
                  ],
                ),
              ),
            )
          else ...[
            for (final reply in displayedReplies)
              Padding(
                padding: const EdgeInsets.only(left: 36.0, top: 10.0),
                child: _buildCommentItem(comment: reply, isReply: true),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 42.0, top: 8.0),
              child: Row(
                children: [
                  if (visibleRepliesLimit < replies.length) ...[
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _visibleRepliesCount[parentId!] =
                              visibleRepliesLimit + 5;
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
                          const Icon(Icons.keyboard_arrow_down_rounded,
                              size: 16, color: AppColors.blue),
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
                        Icon(Icons.keyboard_arrow_up_rounded,
                            size: 16, color: context.textMuted),
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
  }

  Widget _buildCommentItem({
    required Map<String, dynamic> comment,
    bool isReply = false,
  }) {
    final author = comment['author'];
    final rawName = comment['name']?.toString() ??
        (author is Map ? author['username']?.toString() : null) ??
        comment['userName']?.toString() ??
        comment['username']?.toString() ??
        l10n.user;
    final authorId = (author is Map ? author['_id'] : author)?.toString();
    final myUserId = SocketService.currentUserId;
    final isMyComment = (myUserId != null && authorId != null && authorId == myUserId) ||
        comment['canDelete'] == true ||
        Language.hasYouIndicator(rawName);

    final isAnonymous = comment['isAnonymous'] == true ||
        Language.isAnonymousMemberName(rawName);

    final commentName = isAnonymous
        ? (isMyComment ? '${l10n.anonymousMember} (${l10n.you})' : l10n.anonymousMember)
        : rawName;
    final commentAvatar = comment['avatar']?.toString() ??
        (author is Map ? author['avatar']?.toString() : null) ??
        comment['userAvatar']?.toString();
    final commentText = (comment['content'] ?? comment['text'])?.toString() ?? '';
    final rawCommentTime = comment['createdAt'] ?? comment['time'];
    final commentTime = TimeFormatter.formatTimeAgo(context, rawCommentTime);
    final likesCount = (comment['likes'] as num?)?.toInt() ??
        (comment['likesCount'] as num?)?.toInt() ??
        int.tryParse(comment['likes']?.toString() ?? comment['likesCount']?.toString() ?? '0') ??
        0;
    final isLiked = comment['isLiked'] == true;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isAnonymous)
          Container(
            width: (isReply ? 14 : 17) * 2,
            height: (isReply ? 14 : 17) * 2,
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
            avatar: commentAvatar,
            name: commentName,
            radius: isReply ? 14 : 17,
            fontSize: isReply ? 11 : 13,
            enableViewer: false,
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: context.isDark
                      ? const Color(0xFF232232)
                      : const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            commentName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isReply ? 12.5 : 13.5,
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
                    if (commentText.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      _buildCommentContent(commentText, context),
                    ],
                  ],
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentContent(String text, BuildContext context) {
    return AppMentionText(text: text);
  }

  Widget _buildVerticalImage(String imgUrl) {
    final isLocal = !imgUrl.startsWith('http');
    return isLocal
        ? Image.file(
            File(imgUrl),
            width: double.infinity,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          )
        : Image.network(
            imgUrl,
            width: double.infinity,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 240,
                color: Colors.white.withValues(alpha: 0.05),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.blue,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          );
  }
}
