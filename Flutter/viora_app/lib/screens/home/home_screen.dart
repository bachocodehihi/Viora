import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../services/post_service.dart';
import '../../services/profile_service.dart';
import '../../services/session_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/post/post_card.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/reaction/fb_reaction_box.dart';
import '../post/post_account_screen.dart';
import '../../widgets/bottomsheet/app_livestream_setup_bottomsheet.dart';
import '../../services/livestream_service.dart';
import '../live/livestream_audience_screen.dart';

class HomeScreen extends StatefulWidget {
  final String email;
  final String? userAvatar;
  final String? userName;
  final VoidCallback? onMenuPressed;
  const HomeScreen({
    super.key,
    required this.email,
    this.userAvatar,
    this.userName,
    this.onMenuPressed,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _userAvatar;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _userAvatar = widget.userAvatar;
    _userName = widget.userName;
    _loadUserProfile();
    _loadFeed();

    SocketService.init();
    SocketService.onPostCommentsCountUpdated(_onSocketPostCommentsCountUpdated);
    SocketService.onPostLiked(_onSocketPostLiked);
    SocketService.onNewLiveStarted((_) => _loadFeed());
    SocketService.onLiveEnded((_) => _loadFeed());
  }

  void _onSocketPostCommentsCountUpdated(Map<String, dynamic> data) {
    if (!mounted) return;
    final postId = data['postId']?.toString();
    final count = (data['commentsCount'] as num?)?.toInt();
    if (postId == null || count == null) return;

    final idx = _posts.indexWhere((p) => (p['id'] ?? p['_id'])?.toString() == postId);
    if (idx != -1) {
      setState(() {
        _posts[idx]['comments'] = count;
        _posts[idx]['commentsCount'] = count;
      });
    }
  }

  void _onSocketPostLiked(Map<String, dynamic> data) {
    if (!mounted) return;
    final postId = data['postId']?.toString();
    final count = (data['likesCount'] as num?)?.toInt();
    final userId = data['userId']?.toString();
    final isLiked = data['isLiked'] == true;
    final reaction = data['reaction']?.toString();

    debugPrint('[HomeScreen] _onSocketPostLiked: postId=$postId, count=$count, liker=$userId');

    if (postId == null || count == null) return;

    final myUserId = SocketService.currentUserId;

    final idx = _posts.indexWhere((p) {
      final pId = (p['id'] ?? p['_id'])?.toString();
      return pId != null && pId.isNotEmpty && pId == postId;
    });

    if (idx != -1 && mounted) {
      setState(() {
        _posts[idx]['likes'] = count;
        _posts[idx]['likesCount'] = count;
        if (myUserId != null && userId == myUserId) {
          _posts[idx]['isLiked'] = isLiked;
          _posts[idx]['reaction'] = reaction;
        }
      });
    }
  }

  @override
  void dispose() {
    SocketService.offPostCommentsCountUpdated(_onSocketPostCommentsCountUpdated);
    SocketService.offPostLiked(_onSocketPostLiked);
    super.dispose();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userAvatar != oldWidget.userAvatar || widget.userName != oldWidget.userName) {
      setState(() {
        _userAvatar = widget.userAvatar;
        _userName = widget.userName;
      });
    }
  }

  Future<void> _loadUserProfile() async {
    final cachedAvatar = await SessionService.getAvatar();
    final cachedUsername = await SessionService.getUsername();
    if (mounted && (cachedAvatar != null || cachedUsername != null)) {
      setState(() {
        _userAvatar = cachedAvatar ?? _userAvatar;
        _userName = cachedUsername ?? _userName;
      });
    }

    final profile = await ProfileService.getProfile(email: widget.email);
    if (profile != null && mounted) {
      setState(() {
        _userAvatar = profile['avatar']?.toString() ?? _userAvatar;
        _userName = profile['username']?.toString() ?? _userName;
      });
    }
  }

  bool _isLoadingFeed = true;
  final List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _activeLives = [];

  Future<void> _loadFeed() async {
    try {
      final feed = await PostService.getFeed(email: widget.email);
      final lives = await LivestreamService.getActiveLives();
      if (mounted) {
        setState(() {
          _posts.clear();
          _posts.addAll(feed);
          _activeLives = lives;
          _isLoadingFeed = false;
        });
      }
    } catch (e) {
      debugPrint('Load feed error: $e');
      if (mounted) {
        setState(() {
          _isLoadingFeed = false;
        });
      }
    }
  }

  final List<Map<String, dynamic>> _onlineFriends = [
    {
      'name': 'Alex',
      'avatar': 'A',
      'color': AppColors.blue,
      'online': true,
      'messages': [
        {'text': 'Hey! Are we meeting up today?', 'isMe': false, 'time': '10:45 AM'}
      ]
    },
    {
      'name': 'Sarah',
      'avatar': 'S',
      'color': AppColors.pink,
      'online': true,
      'messages': [
        {'text': 'Check out this photo I just took! 🌅', 'isMe': false, 'time': '5:10 PM'}
      ]
    },
    {
      'name': 'Emma',
      'avatar': 'E',
      'color': AppColors.purple,
      'online': true,
      'messages': [
        {'text': 'Loved the logo update!', 'isMe': false, 'time': 'Sunday'}
      ]
    },
    {
      'name': 'David',
      'avatar': 'D',
      'color': AppColors.orange,
      'online': false,
      'messages': <Map<String, dynamic>>[]
    },
  ];

  Future<void> _toggleLike(String id, {String? reactionId}) async {
    final index = _posts.indexWhere((p) => (p['id'] ?? p['_id'])?.toString() == id);
    if (index == -1) return;
    final post = _posts[index];

    final wasLiked = post['isLiked'] == true;
    final currentReaction = post['reaction']?.toString();
    final currentLikes = (post['likes'] as num?)?.toInt() ?? 0;

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
      post['isLiked'] = nextLiked;
      post['reaction'] = nextReaction;
      post['likes'] = nextLikes;
      post['likesCount'] = nextLikes;
    });

    if (!id.startsWith('temp_')) {
      PostService.likePost(id, reaction: nextReaction).then((res) {
        if (res != null && mounted) {
          setState(() {
            if (res['likesCount'] is int) {
              post['likes'] = res['likesCount'];
              post['likesCount'] = res['likesCount'];
            }
            if (res['isLiked'] is bool) {
              post['isLiked'] = res['isLiked'];
            }
            post['reaction'] = res['reaction']?.toString();
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          l10n.home,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: context.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: context.textPrimary, size: 24),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.search);
            },
          ),

          IconButton(
            icon: Icon(Icons.qr_code_scanner_rounded, color: context.textPrimary, size: 22),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.scanQr);
            },
          ),
          IconButton(
            icon: Icon(Icons.menu_rounded, color: context.textPrimary, size: 24),
            onPressed: widget.onMenuPressed,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFeed,
        color: AppColors.blue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
          padding: const EdgeInsets.only(
            left: 20.0,
            right: 20.0,
            top: 12.0,
            bottom: 110.0,
          ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _buildCreatePostBar(context),
            const SizedBox(height: 28),

            _buildActiveFriendsSection(context),
            const SizedBox(height: 32),

            _buildRecentMomentsSection(context),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildCreatePostBar(BuildContext context) {
    final l10n = Language.of(context);

    return Row(
      children: [
        AppAvatar(
          avatar: _userAvatar,
          name: _userName ?? widget.email,
          radius: 24,
          fontSize: 18,
          onTap: _openCreatePostScreen,
        ),
        const SizedBox(width: 14),

        Expanded(
          child: GestureDetector(
            onTap: _openCreatePostScreen,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: context.isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.1),
                  width: 1.2,
                ),
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.whatsOnYourMind,
                style: TextStyle(
                  color: context.textPlaceholder,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        GestureDetector(
          onTap: () {
            AppLivestreamSetupBottomSheet.show(
              context,
              userAvatar: _userAvatar,
              userName: _userName,
            );
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF416C).withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sensors_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Text(
                  l10n.liveBadge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openCreatePostScreen() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => PostAccountScreen(
          email: widget.email,
          userAvatar: _userAvatar,
          userName: _userName,
        ),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _posts.insert(0, result);
    });
  }

  Widget _buildActiveFriendsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.activeFriendsHeader,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: context.textMuted,
                letterSpacing: 1.2,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_onlineFriends.where((f) => f['online'] == true).length} ${l10n.onlineCountLabel}',
                style: const TextStyle(
                  color: AppColors.blue,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 85,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _activeLives.length + _onlineFriends.length + 1,
            itemBuilder: (ctx, index) {
              if (index == 0) {
                return GestureDetector(
                  onTap: () {
                    AppLivestreamSetupBottomSheet.show(
                      context,
                      userAvatar: _userAvatar,
                      userName: _userName,
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.dividerTheme,
                              width: 1.5,
                            ),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: CircleAvatar(
                            backgroundColor: context.actionPillBg,
                            child: const Icon(
                              Icons.videocam_rounded,
                              color: Colors.redAccent,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.goLive,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (index <= _activeLives.length) {
                final live = _activeLives[index - 1];
                final host = live['host'] as Map<String, dynamic>? ?? {};
                final hostName = host['name']?.toString() ?? l10n.liveBadge;
                final hostAvatar = host['avatar']?.toString();

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LivestreamAudienceScreen(
                          liveId: live['id']?.toString() ?? '',
                          initialTitle: live['title']?.toString(),
                          hostName: hostName,
                          hostAvatar: hostAvatar,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.redAccent, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.redAccent.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(2.5),
                              child: AppAvatar(
                                avatar: hostAvatar,
                                name: hostName,
                                radius: 22,
                                fontSize: 15,
                              ),
                            ),
                            Positioned(
                              bottom: -4,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    l10n.liveBadge.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        SizedBox(
                          width: 60,
                          child: Text(
                            hostName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final friend = _onlineFriends[index - 1 - _activeLives.length];
              final isOnline = friend['online'] == true;

              return GestureDetector(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.profileAccount,
                    arguments: {
                      'id': friend['id'] ?? friend['userId'],
                      'email': friend['email'],
                      'name': friend['name'],
                      'avatar': friend['avatar'],
                      'color': friend['color'],
                    },
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: isOnline
                                ? [AppColors.blue, AppColors.teal]
                                : [Colors.transparent, Colors.transparent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: !isOnline
                              ? Border.all(
                                  color: context.activeFriendBg,
                                  width: 1.5,
                                )
                              : null,
                        ),
                        padding: const EdgeInsets.all(2.5),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).scaffoldBackgroundColor,
                          ),
                          padding: const EdgeInsets.all(2.5),
                          child: AppAvatar(
                            avatar: friend['avatar'],
                            name: friend['name'],
                            color: friend['color'] as Color?,
                            radius: 20,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        friend['name'],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentMomentsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.recentMomentsHeader,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: context.textMuted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoadingFeed && _posts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36.0),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.blue,
              ),
            ),
          )
        else if (_posts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.borderTheme,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 48,
                  color: context.textMuted.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.noPostsYet,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.shareFirstMoment,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _posts.length,
            itemBuilder: (ctx, index) {
              final post = _posts[index];
              final postId = (post['id'] ?? post['_id'] ?? '').toString();
              return PostCard(
                post: post,
                currentUserEmail: widget.email,
                currentUserName: _userName,
                currentUserAvatar: _userAvatar,
                onPostTap: () => _openPostDetail(post),
                onLikeTap: () => _toggleLike(postId),
                onReactionSelected: (FbReaction reaction) => _toggleLike(postId, reactionId: reaction.id),
                onCommentCountChanged: (newCount) {
                  setState(() {
                    post['comments'] = newCount;
                  });
                },
                onPostDeleted: () {
                  setState(() {
                    _posts.removeWhere((p) =>
                        (p['id'] ?? p['_id'] ?? '').toString() == postId);
                  });
                },
                onNotInterested: () {
                  setState(() {
                    _posts.removeWhere((p) =>
                        (p['id'] ?? p['_id'] ?? '').toString() == postId);
                  });
                },
                onCommentsStatusChanged: (disabled) {
                  setState(() {
                    post['commentsDisabled'] = disabled;
                  });
                },
                onCommentSettingsChanged: (newSettings) {
                  setState(() {
                    post.addAll(newSettings);
                  });
                },
              );
            },
          ),
      ],
    );
  }

  void _openPostDetail(Map<String, dynamic> post) {
    Navigator.pushNamed(
      context,
      AppRoutes.postDetail,
      arguments: {
        'post': post,
        'userEmail': widget.email,
        'userName': _userName,
        'userAvatar': _userAvatar,
        'onPostUpdated': (updatedPost) {
          setState(() {
            post['likes'] = updatedPost['likes'];
            post['isLiked'] = updatedPost['isLiked'];
            post['reaction'] = updatedPost['reaction'];
            post['comments'] = updatedPost['comments'];
          });
        },
      },
    );
  }


}

