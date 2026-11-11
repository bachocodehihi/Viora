import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../services/post_service.dart';
import '../../services/session_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/post/post_card.dart';
import '../../widgets/reaction/fb_reaction_box.dart';
import 'qr_code_screen.dart';
import '../edit/edit_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String email;
  const ProfileScreen({super.key, required this.email});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _username;
  String? _email;
  String? _avatar;
  String? _coverImage;
  String? _bio;
  String? _gender;
  String? _birthday;
  String? _phone;
  String? _address;
  String? _job;
  String? _nationality;
  String? _hobby;
  String? _qrCode;
  String? _userId;
  String? _homeTown;
  List<Map<String, dynamic>> _placesLived = [];
  bool _isPlacesLivedExpanded = false;
  int _followingCount = 0;
  int _followersCount = 0;
  int _friendsCount = 0;
  int _groupsCount = 0;
  int _postsCount = 0;
  bool _isPrivate = false;

  List<Map<String, dynamic>> _posts = [];
  bool _isLoadingPosts = true;

  late final Function(Map<String, dynamic>) _onStatsUpdated;
  late final Function(Map<String, dynamic>) _onFriendRequestAccepted;
  late final Function(Map<String, dynamic>) _onFriendRemoved;
  late final Function(Map<String, dynamic>) _onFollowerAdded;
  late final Function(Map<String, dynamic>) _onFollowerRemoved;
  late final Function(Map<String, dynamic>) _onPostLiked;

  @override
  void initState() {
    super.initState();
    _email = widget.email;
    _initSocketListeners();
    _loadProfileData();
  }

  void _initSocketListeners() {
    SocketService.init();

    _onStatsUpdated = (data) {
      if (!mounted) return;
      setState(() {
        if (data['friendsCount'] is int) _friendsCount = data['friendsCount'] as int;
        if (data['followersCount'] is int) _followersCount = data['followersCount'] as int;
        if (data['followingCount'] is int) _followingCount = data['followingCount'] as int;
        if (data['groupsCount'] is int) _groupsCount = data['groupsCount'] as int;
        if (data['postsCount'] is int) _postsCount = data['postsCount'] as int;
      });
    };
    SocketService.onStatsUpdated(_onStatsUpdated);

    _onFriendRequestAccepted = (data) {
      if (!mounted) return;
      setState(() {
        if (data['friendsCount'] is int) {
          _friendsCount = data['friendsCount'] as int;
        } else {
          _friendsCount++;
        }
      });
    };
    SocketService.onFriendRequestAccepted(_onFriendRequestAccepted);

    _onFriendRemoved = (data) {
      if (!mounted) return;
      setState(() {
        if (data['friendsCount'] is int) {
          _friendsCount = data['friendsCount'] as int;
        } else if (_friendsCount > 0) {
          _friendsCount--;
        }
      });
    };
    SocketService.onFriendRemoved(_onFriendRemoved);

    _onFollowerAdded = (data) {
      if (!mounted) return;
      setState(() {
        if (data['followersCount'] is int) {
          _followersCount = data['followersCount'] as int;
        } else {
          _followersCount++;
        }
      });
    };
    SocketService.onFollowerAdded(_onFollowerAdded);

    _onFollowerRemoved = (data) {
      if (!mounted) return;
      setState(() {
        if (data['followersCount'] is int) {
          _followersCount = data['followersCount'] as int;
        } else if (_followersCount > 0) {
          _followersCount--;
        }
      });
    };
    SocketService.onFollowerRemoved(_onFollowerRemoved);

    _onPostLiked = (data) {
      if (!mounted) return;
      final postId = data['postId']?.toString();
      if (postId == null) return;
      final count = (data['likesCount'] as num?)?.toInt();
      final userId = data['userId']?.toString();
      final isLiked = data['isLiked'] == true;
      final reaction = data['reaction']?.toString();
      final myUserId = SocketService.currentUserId;

      setState(() {
        for (final p in _posts) {
          final id = (p['id'] ?? p['_id'])?.toString();
          if (id == postId) {
            if (count != null) {
              p['likes'] = count;
              p['likesCount'] = count;
            }
            if (myUserId != null && userId == myUserId) {
              p['isLiked'] = isLiked;
              p['reaction'] = reaction;
            }
            break;
          }
        }
      });
    };
    SocketService.onPostLiked(_onPostLiked);
  }

  @override
  void dispose() {
    SocketService.offStatsUpdated(_onStatsUpdated);
    SocketService.offFriendRequestAccepted(_onFriendRequestAccepted);
    SocketService.offFriendRemoved(_onFriendRemoved);
    SocketService.offFollowerAdded(_onFollowerAdded);
    SocketService.offFollowerRemoved(_onFollowerRemoved);
    SocketService.offPostLiked(_onPostLiked);
    super.dispose();
  }

  Future<void> _loadProfileData() async {

    final cachedEmail = widget.email.isNotEmpty ? widget.email : await SessionService.getUserEmail();
    final cachedUsername = await SessionService.getUsername();
    final cachedAvatar = await SessionService.getAvatar();
    final cachedQrCode = await SessionService.getQrCode();
    final cachedUserId = await SessionService.getUserId();

    if (mounted) {
      setState(() {
        _email = cachedEmail;
        _username = cachedUsername;
        _avatar = cachedAvatar;
        _qrCode = cachedQrCode;
        _userId = cachedUserId;
      });
    }

    try {
      final token = await SessionService.getToken();
      final body = <String, dynamic>{};
      if (_userId != null && _userId!.isNotEmpty) {
        body['userId'] = _userId;
      }
      if (_email != null && _email!.isNotEmpty) {
        body['email'] = _email;
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(
            Uri.parse(ApiConfig.loadProfile),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['account'] != null) {
          final account = data['account'] as Map<String, dynamic>;

          if (mounted) {
            setState(() {
              _username = account['username']?.toString() ?? _username;
              _email = account['email']?.toString() ?? _email;
              _avatar = account['avatar']?.toString() ?? _avatar;
              _coverImage = account['coverImage']?.toString() ?? _coverImage;
              _bio = account['bio']?.toString() ?? _bio;
              _gender = account['gender']?.toString() ?? _gender;
              _birthday = account['birthday']?.toString() ?? _birthday;
              _phone = account['phone']?.toString() ?? _phone;
              _address = account['address']?.toString() ?? _address;
              _homeTown = account['homeTown']?.toString() ?? _homeTown;
              _job = account['job']?.toString() ?? _job;
              _nationality = account['nationality']?.toString() ?? _nationality;
              _hobby = account['hobby']?.toString() ?? _hobby;
              _qrCode = account['qrCode']?.toString() ?? _qrCode;
              _userId = account['_id']?.toString() ?? account['id']?.toString() ?? _userId;

              if (account['placesLived'] is List) {
                _placesLived = List<Map<String, dynamic>>.from(
                  (account['placesLived'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
                );
              } else {
                _placesLived = [];
              }

              if (account['followingCount'] is int) {
                _followingCount = account['followingCount'] as int;
              } else if (account['following'] is List) {
                _followingCount = (account['following'] as List).length;
              }

              if (account['followersCount'] is int) {
                _followersCount = account['followersCount'] as int;
              } else if (account['followers'] is List) {
                _followersCount = (account['followers'] as List).length;
              }

              if (account['friendsCount'] is int) {
                _friendsCount = account['friendsCount'] as int;
              } else if (account['friends'] is List) {
                _friendsCount = (account['friends'] as List).length;
              }

              if (account['groupsCount'] is int) {
                _groupsCount = account['groupsCount'] as int;
              }

              if (account['postsCount'] is int) {
                _postsCount = account['postsCount'] as int;
              }
              _isPrivate = account['isPrivate'] == true;
            });
          }

          await SessionService.updateProfile(
            username: _username,
            avatar: _avatar,
            qrCode: _qrCode,
          );
        }
      }
    } catch (e) {
      debugPrint('Profile fetch error: $e');
    }

    try {
      final posts = await PostService.getUserPosts(
        userId: _userId,
        email: _email ?? widget.email,
      );
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      debugPrint('User posts fetch error: $e');
      if (mounted) {
        setState(() => _isLoadingPosts = false);
      }
    }
  }

  Future<void> _toggleLike(String postId, {String? reactionId}) async {
    final idx = _posts.indexWhere((p) => (p['id'] ?? p['_id'])?.toString() == postId);
    if (idx == -1) return;

    final post = _posts[idx];
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

    if (!postId.startsWith('temp_')) {
      PostService.likePost(postId, reaction: nextReaction).then((res) {
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

  void _openPostDetail(Map<String, dynamic> post) {
    Navigator.pushNamed(
      context,
      AppRoutes.postDetail,
      arguments: {
        'post': post,
        'userEmail': _email,
        'userName': _username,
        'userAvatar': _avatar,
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



  String _formatDate(BuildContext context, String? raw) {
    if (raw == null || raw.isEmpty) return l10n.notUpdated;
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')} - ${dt.month.toString().padLeft(2, '0')} - ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  String _formatGender(BuildContext context, String? raw) {
    if (raw == null || raw.isEmpty) return l10n.notUpdated;
    final lower = raw.toLowerCase().trim();
    if (lower == 'male') return l10n.male;
    if (lower == 'female') return l10n.female;
    if (lower == 'other') return l10n.other;
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final displayName = (_username != null && _username!.isNotEmpty)
        ? _username!
        : ((_email != null && _email!.isNotEmpty)
            ? _email!.split('@')[0]
            : 'User');

    final displayEmail = (_email != null && _email!.isNotEmpty) ? _email! : '';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    final hasCoverImage = _coverImage != null &&
        _coverImage!.isNotEmpty &&
        (_coverImage!.startsWith('http://') || _coverImage!.startsWith('https://'));

    final hasAvatarImage = _avatar != null &&
        _avatar!.isNotEmpty &&
        (_avatar!.startsWith('http://') || _avatar!.startsWith('https://'));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadProfileData,
        color: AppColors.blue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: Column(
            children: [

              SizedBox(
                height: 232,
                width: double.infinity,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: hasCoverImage
                            ? null
                            : const LinearGradient(
                                colors: [AppColors.blue, Color(0xFF1565C0)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                      ),
                      child: hasCoverImage
                          ? Image.network(
                              _coverImage!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 180,
                              errorBuilder: (context, error, stackTrace) => Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppColors.blue, Color(0xFF1565C0)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),

                    Positioned(
                      top: MediaQuery.of(context).padding.top + 10,
                      right: 16,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Material(
                              color: Colors.black.withValues(alpha: 0.2),
                              child: IconButton(
                                icon: const Icon(Icons.qr_code_rounded, color: Colors.white, size: 22),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => QrCodeScreen(
                                        name: displayName,
                                        email: displayEmail,
                                        avatar: _avatar,
                                        qrCode: _qrCode,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Material(
                              color: Colors.black.withValues(alpha: 0.2),
                              child: IconButton(
                                icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 22),
                                onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.avatarViewer,
                              arguments: {
                                'imageUrl': _avatar,
                                'title': displayName,
                                'fallbackText': initial,
                                'heroTag': 'profile_avatar_main',
                              },
                            );
                          },
                          child: Hero(
                            tag: 'profile_avatar_main',
                            createRectTween: (begin, end) =>
                                MaterialRectCenterArcTween(begin: begin, end: end),
                            child: Material(
                              type: MaterialType.transparency,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.profileShadow,
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: hasAvatarImage
                                    ? ClipOval(
                                        child: Image.network(
                                          _avatar!,
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, progress) {
                                            if (progress == null) return child;
                                            return Container(
                                              width: 100,
                                              height: 100,
                                              color: context.cardBg,
                                              child: const Center(
                                                child: SizedBox(
                                                  width: 28,
                                                  height: 28,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: AppColors.blue,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) => CircleAvatar(
                                            radius: 50,
                                            backgroundColor: context.cardBg,
                                            child: Text(
                                              initial,
                                              style: const TextStyle(
                                                fontSize: 48,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.blue,
                                                decoration: TextDecoration.none,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : CircleAvatar(
                                        radius: 50,
                                        backgroundColor: context.cardBg,
                                        child: Text(
                                          initial,
                                          style: const TextStyle(
                                            fontSize: 48,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.blue,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  if (_isPrivate) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_rounded, size: 16, color: AppColors.blue),
                    ),
                  ],
                ],
              ),

              if (_bio != null && _bio!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Text(
                    _bio!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatItem(context, l10n.following, '$_followingCount'),
                    _buildStatVerticalDivider(context),
                    _buildStatItem(context, l10n.followers, '$_followersCount'),
                    _buildStatVerticalDivider(context),
                    _buildStatItem(context, l10n.friends, '$_friendsCount'),
                    _buildStatVerticalDivider(context),
                    _buildStatItem(context, l10n.groups, '$_groupsCount'),
                    _buildStatVerticalDivider(context),
                    _buildStatItem(context, l10n.posts, '$_postsCount'),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          l10n.personalInformation,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: context.textMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        InkWell(
                          onTap: _openEditProfile,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit_outlined, size: 14, color: AppColors.blue),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.edit,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: context.borderTheme),
                        boxShadow: [
                          BoxShadow(
                            color: context.profileCardBg,
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: () {
                          final infoRows = <Widget>[];

                          void addRow(IconData icon, String label, String value) {
                            if (infoRows.isNotEmpty) {
                              infoRows.add(_buildDivider(context));
                            }
                            infoRows.add(_buildInfoRow(context, icon, label, value));
                          }

                          if (displayEmail.isNotEmpty) {
                            addRow(Icons.email_outlined, l10n.email, displayEmail);
                          }

                          if (_gender != null && _gender!.trim().isNotEmpty) {
                            addRow(Icons.person_outline, l10n.gender, _formatGender(context, _gender));
                          }

                          if (_birthday != null && _birthday!.trim().isNotEmpty) {
                            addRow(Icons.cake_outlined, l10n.birthday, _formatDate(context, _birthday));
                          }

                          if (_address != null && _address!.trim().isNotEmpty) {
                            addRow(Icons.location_on_outlined, l10n.address, _address!.trim());
                          }

                          if (_homeTown != null && _homeTown!.trim().isNotEmpty) {
                            addRow(Icons.cottage_outlined, l10n.hometown, _homeTown!.trim());
                          }

                          if (_placesLived.isNotEmpty) {
                            final validPlaces = _placesLived
                                .map((p) => p['address']?.toString().trim() ?? '')
                                .where((s) => s.isNotEmpty)
                                .toList();
                            if (validPlaces.isNotEmpty) {
                              if (infoRows.isNotEmpty) {
                                infoRows.add(_buildDivider(context));
                              }
                              infoRows.add(_buildPlacesLivedRow(context, validPlaces));
                            }
                          }

                          if (_phone != null && _phone!.trim().isNotEmpty) {
                            addRow(Icons.phone_outlined, l10n.phoneNumber, _phone!.trim());
                          }

                          if (_nationality != null && _nationality!.trim().isNotEmpty) {
                            addRow(Icons.flag_outlined, l10n.nationality, _nationality!.trim());
                          }

                          if (_job != null && _job!.trim().isNotEmpty) {
                            addRow(Icons.work_outline, l10n.job, _job!.trim());
                          }

                          if (_hobby != null && _hobby!.trim().isNotEmpty) {
                            addRow(Icons.palette_outlined, l10n.hobbies, _hobby!.trim());
                          }

                          return infoRows.isNotEmpty
                              ? infoRows
                              : [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Center(
                                      child: Text(
                                        l10n.noInfoAvailable,
                                        style: TextStyle(fontSize: 13, color: context.textMuted),
                                      ),
                                    ),
                                  ),
                                ];
                        }(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.allPosts,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: context.textMuted,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_isLoadingPosts && _posts.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.blue,
                          ),
                        ),
                      )
                    else if (_posts.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                        decoration: BoxDecoration(
                          color: context.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.borderTheme),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.blue.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.article_outlined,
                                size: 28,
                                color: AppColors.blue,
                              ),
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
                            const SizedBox(height: 4),
                            Text(
                              l10n.sharedPostsAppearHere,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
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
                            currentUserEmail: _email,
                            currentUserName: _username,
                            currentUserAvatar: _avatar,
                            onPostTap: () => _openPostDetail(post),
                            onLikeTap: () => _toggleLike(postId),
                            onReactionSelected: (FbReaction reaction) => _toggleLike(postId, reactionId: reaction.id),
                            onCommentCountChanged: (newCount) {
                              setState(() {
                                post['comments'] = newCount;
                                post['commentsCount'] = newCount;
                              });
                            },
                            onPostDeleted: () {
                              setState(() {
                                _posts.removeWhere((p) =>
                                    (p['id'] ?? p['_id'] ?? '').toString() == postId);
                              });
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 110),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 24,
            child: Center(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 28,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: context.textSubtle,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatVerticalDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.only(top: 8),
      color: context.borderTheme,
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.blue.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.blue, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: context.textSubtle,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 24,
      thickness: 0.5,
      color: context.borderTheme,
    );
  }

  Widget _buildPlacesLivedRow(BuildContext context, List<String> validPlaces) {
    const initialLimit = 1;
    final hasMore = validPlaces.length > initialLimit;
    final displayPlaces = (_isPlacesLivedExpanded || !hasMore)
        ? validPlaces
        : validPlaces.sublist(0, initialLimit);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.blue.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.home_work_outlined, color: AppColors.blue, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.livedIn,
                style: TextStyle(
                  color: context.textSubtle,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              ...displayPlaces.map((place) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6, right: 8),
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        place,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
              if (hasMore) ...[
                InkWell(
                  onTap: () {
                    setState(() {
                      _isPlacesLivedExpanded = !_isPlacesLivedExpanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isPlacesLivedExpanded
                              ? l10n.collapse
                              : l10n.viewMorePlacesCount(validPlaces.length - initialLimit),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blue,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _isPlacesLivedExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: AppColors.blue,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _openEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditScreen(
          username: _username,
          bio: _bio,
          gender: _gender,
          birthday: _birthday,
          phone: _phone,
          address: _address,
          homeTown: _homeTown,
          job: _job,
          nationality: _nationality,
          hobby: _hobby,
          avatar: _avatar,
          coverImage: _coverImage,
          placesLived: _placesLived,
        ),
      ),
    ).then((_) {
      _loadProfileData();
    });
  }
}
