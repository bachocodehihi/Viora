import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../services/contact_service.dart';
import '../../services/message_service.dart';
import '../../services/post_service.dart';
import '../../services/session_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/reaction/fb_reaction_box.dart';
import '../../widgets/toast/app_toast.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/post/post_card.dart';
import '../../services/profile_service.dart';
import '../chat/chat_detail_screen.dart';
import '../contact/contact_screen.dart';
import '../message/messages_screen.dart';
import '../report/report_screen.dart';

class ProfileAccountScreen extends StatefulWidget {
  final String email;
  final String? name;
  final String? avatar;
  final Color? color;
  final String? status;
  final int? mutualFriends;
  final String? userId;
  final bool isMe;
  final bool hasFriendRequest;
  final String? requestId;
  final bool isFriend;
  final bool hasSentRequest;

  const ProfileAccountScreen({
    super.key,
    this.userId,
    required this.email,
    this.name,
    this.avatar,
    this.color,
    this.status,
    this.mutualFriends,
    this.isMe = false,
    this.hasFriendRequest = false,
    this.requestId,
    this.isFriend = false,
    this.hasSentRequest = false,
  });

  @override
  State<ProfileAccountScreen> createState() => _ProfileAccountScreenState();
}

class _ProfileAccountScreenState extends State<ProfileAccountScreen> {
  bool _friendRequestSent = false;
  bool _isSendingRequest = false;
  bool _isIncomingRequest = false;
  String? _incomingRequestId;
  bool _isFriend = false;
  bool _isFollowing = false;
  bool _isPrivate = false;
  bool _canViewProfilePosts = true;
  bool _hasSentFollowRequest = false;
  bool _isBlockedByViewer = false;
  bool _isBlockedByTarget = false;
  String? _existingConversationId;
  List<Map<String, dynamic>> _cachedMessages = [];
  String? _resolvedUserId;
  String? _sentRequestId;
  int _targetFollowingCount = 0;
  int _targetFollowersCount = 0;
  int _targetFriendsCount = 0;
  int _targetGroupsCount = 0;
  int _targetPostsCount = 0;

  List<Map<String, dynamic>> _targetPosts = [];
  bool _isLoadingTargetPosts = true;

  bool _isLoadingProfile = true;
  String? _targetUsername;
  String? _targetEmail;
  String? _targetAvatar;
  String? _targetCoverImage;
  String? _targetBio;
  String? _targetGender;
  String? _targetBirthday;
  String? _targetPhone;
  String? _targetAddress;
  String? _targetJob;
  String? _targetNationality;
  String? _targetHobby;
  String? _targetHomeTown;
  List<Map<String, dynamic>> _targetPlacesLived = [];
  bool _isPlacesLivedExpanded = false;

  String? get _effectiveUserId =>
      (widget.userId != null && widget.userId!.isNotEmpty)
          ? widget.userId
          : _resolvedUserId;

  late final Function(Map<String, dynamic>) _onFriendRequestAccepted;
  late final Function(Map<String, dynamic>) _onFriendRequestRejected;
  late final Function(Map<String, dynamic>) _onFriendRequestReceived;
  late final Function(Map<String, dynamic>) _onFriendRequestCancelled;
  late final Function(Map<String, dynamic>) _onFriendRemoved;
  late final Function(Map<String, dynamic>) _onPostLiked;

  @override
  void initState() {
    super.initState();
    _isIncomingRequest = widget.hasFriendRequest;
    _incomingRequestId = widget.requestId;
    _isFriend = widget.isFriend;
    _friendRequestSent = widget.hasSentRequest;
    if (widget.hasSentRequest && widget.requestId != null) {
      _sentRequestId = widget.requestId;
    }
    if (widget.mutualFriends != null) {
      _targetFriendsCount = widget.mutualFriends!;
    }
    _initSocketListeners();
    _checkRelationship();
    _loadTargetProfile();
  }

  Future<void> _loadTargetProfile() async {
    try {
      final targetId = _effectiveUserId;
      final targetEmail = widget.email;
      final targetName = widget.name;
      if ((targetId == null || targetId.isEmpty) &&
          targetEmail.isEmpty &&
          (targetName == null || targetName.isEmpty)) {
        if (mounted) setState(() => _isLoadingProfile = false);
        return;
      }

      final token = await SessionService.getToken();
      final currentUserId = await SessionService.getUserId();
      final body = <String, dynamic>{};
      if (targetId != null && targetId.isNotEmpty) {
        body['userId'] = targetId;
      } else if (targetEmail.isNotEmpty) {
        body['email'] = targetEmail;
      } else if (targetName != null && targetName.isNotEmpty) {
        body['username'] = targetName;
      }
      if (currentUserId != null && currentUserId.isNotEmpty) {
        body['myUserId'] = currentUserId;
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
              _isLoadingProfile = false;
              _targetUsername = account['username']?.toString() ?? _targetUsername;
              _targetEmail = account['email']?.toString() ?? _targetEmail;
              _targetAvatar = account['avatar']?.toString() ?? _targetAvatar;
              _targetCoverImage = account['coverImage']?.toString() ?? _targetCoverImage;
              _targetBio = account['bio']?.toString() ?? _targetBio;
              _targetGender = account['gender']?.toString() ?? _targetGender;
              _targetBirthday = account['birthday']?.toString() ?? _targetBirthday;
              _targetPhone = account['phone']?.toString() ?? _targetPhone;
              _targetAddress = account['address']?.toString() ?? _targetAddress;
              _targetHomeTown = account['homeTown']?.toString() ?? _targetHomeTown;
              _targetJob = account['job']?.toString() ?? _targetJob;
              _targetNationality = account['nationality']?.toString() ?? _targetNationality;
              _targetHobby = account['hobby']?.toString() ?? _targetHobby;
              if (account['placesLived'] is List) {
                _targetPlacesLived = List<Map<String, dynamic>>.from(
                  (account['placesLived'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
                );
              } else {
                _targetPlacesLived = [];
              }
              _resolvedUserId = account['_id']?.toString() ?? account['id']?.toString() ?? _resolvedUserId;

              if (account['followingCount'] is int) {
                _targetFollowingCount = account['followingCount'] as int;
              } else if (account['following'] is List) {
                _targetFollowingCount = (account['following'] as List).length;
              }

              if (account['followersCount'] is int) {
                _targetFollowersCount = account['followersCount'] as int;
              } else if (account['followers'] is List) {
                _targetFollowersCount = (account['followers'] as List).length;
              }

              if (account['friendsCount'] is int) {
                _targetFriendsCount = account['friendsCount'] as int;
              } else if (account['friends'] is List) {
                _targetFriendsCount = (account['friends'] as List).length;
              }

              if (account['groupsCount'] is int) {
                _targetGroupsCount = account['groupsCount'] as int;
              }

              if (account['postsCount'] is int) {
                _targetPostsCount = account['postsCount'] as int;
              }

              if (account['isFriend'] is bool) {
                _isFriend = account['isFriend'] as bool;
              }
              if (account['hasFriendRequest'] is bool) {
                _isIncomingRequest = account['hasFriendRequest'] as bool;
                if (_isIncomingRequest && account['requestId'] != null) {
                  _incomingRequestId = account['requestId'].toString();
                }
              }
              if (account['hasSentRequest'] is bool) {
                _friendRequestSent = account['hasSentRequest'] as bool;
                if (_friendRequestSent && account['requestId'] != null) {
                  _sentRequestId = account['requestId'].toString();
                }
              }
              if (account['isFollowing'] is bool) {
                _isFollowing = account['isFollowing'] as bool;
              }
              if (account['isPrivate'] is bool) {
                _isPrivate = account['isPrivate'] as bool;
              }
              if (account['hasSentFollowRequest'] is bool) {
                _hasSentFollowRequest = account['hasSentFollowRequest'] as bool;
              }
              if (account['isBlockedByViewer'] is bool) {
                _isBlockedByViewer = account['isBlockedByViewer'] as bool;
              }
              if (account['isBlockedByTarget'] is bool) {
                _isBlockedByTarget = account['isBlockedByTarget'] as bool;
              }
              if (_isBlockedByViewer || _isBlockedByTarget) {
                _canViewProfilePosts = false;
              } else if (account['canViewProfilePosts'] is bool) {
                _canViewProfilePosts = account['canViewProfilePosts'] as bool;
              } else {
                _canViewProfilePosts = !_isPrivate || _isFriend || _isFollowing || widget.isMe;
              }
            });
          }
        } else {
          if (mounted) setState(() => _isLoadingProfile = false);
        }
      } else {
        if (mounted) setState(() => _isLoadingProfile = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProfile = false);
    }

    if (_canViewProfilePosts) {
      try {
        final posts = await PostService.getUserPosts(
          userId: _effectiveUserId,
          email: widget.email,
        );
        if (mounted) {
          setState(() {
            _targetPosts = posts;
            _isLoadingTargetPosts = false;
          });
        }
      } catch (e) {
        debugPrint('Target user posts fetch error: $e');
        if (mounted) {
          setState(() => _isLoadingTargetPosts = false);
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _targetPosts = [];
          _isLoadingTargetPosts = false;
        });
      }
    }
  }

  Future<void> _toggleLike(String postId, {String? reactionId}) async {
    final idx = _targetPosts.indexWhere((p) => (p['id'] ?? p['_id'])?.toString() == postId);
    if (idx == -1) return;

    final post = _targetPosts[idx];
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



  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      return '$day/$month/$year';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatGender(BuildContext context, String? gender) {
    if (gender == null || gender.trim().isEmpty) return '';
    final g = gender.trim().toLowerCase();
    final l10n = context.l10n;
    if (g == 'male') return l10n.male;
    if (g == 'female') return l10n.female;
    if (g == 'other') return l10n.other;
    return gender;
  }

  void _initSocketListeners() {
    SocketService.init();

    _onFriendRequestAccepted = (data) {
      if (!mounted) return;
      final otherUserId = data['userId']?.toString();
      final currentTargetId = _effectiveUserId;
      if (currentTargetId != null && otherUserId == currentTargetId) {
        setState(() {
          _isFriend = true;
          _friendRequestSent = false;
          _isIncomingRequest = false;
          if (data['friendsCount'] is int) {
            _targetFriendsCount = data['friendsCount'] as int;
          } else {
            _targetFriendsCount++;
          }
        });
      }
    };
    SocketService.onFriendRequestAccepted(_onFriendRequestAccepted);

    _onFriendRequestRejected = (data) {
      if (!mounted) return;
      final receiverId = data['receiverId']?.toString();
      final currentTargetId = _effectiveUserId;
      if (currentTargetId != null && receiverId == currentTargetId) {
        setState(() {
          _friendRequestSent = false;
          _sentRequestId = null;
        });
      }
    };
    SocketService.onFriendRequestRejected(_onFriendRequestRejected);

    _onFriendRequestReceived = (data) {
      if (!mounted) return;
      final senderId = data['senderId']?.toString();
      final currentTargetId = _effectiveUserId;
      if (currentTargetId != null && senderId == currentTargetId) {
        setState(() {
          _isIncomingRequest = true;
          _incomingRequestId = data['id']?.toString() ?? data['requestId']?.toString();
          _friendRequestSent = false;
        });
      }
    };
    SocketService.onFriendRequestReceived(_onFriendRequestReceived);

    _onFriendRequestCancelled = (data) {
      if (!mounted) return;
      final senderId = data['senderId']?.toString();
      final currentTargetId = _effectiveUserId;
      if (currentTargetId != null && senderId == currentTargetId) {
        setState(() {
          _isIncomingRequest = false;
          _incomingRequestId = null;
        });
      }
    };
    SocketService.onFriendRequestCancelled(_onFriendRequestCancelled);

    _onFriendRemoved = (data) {
      if (!mounted) return;
      final otherUserId = data['userId']?.toString();
      final currentTargetId = _effectiveUserId;
      if (currentTargetId != null && otherUserId == currentTargetId) {
        setState(() {
          _isFriend = false;
          _friendRequestSent = false;
          if (data['friendsCount'] is int) {
            _targetFriendsCount = data['friendsCount'] as int;
          } else if (_targetFriendsCount > 0) {
            _targetFriendsCount--;
          }
        });
      }
    };
    SocketService.onFriendRemoved(_onFriendRemoved);

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
        for (final p in _targetPosts) {
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
    SocketService.offFriendRequestAccepted(_onFriendRequestAccepted);
    SocketService.offFriendRequestRejected(_onFriendRequestRejected);
    SocketService.offFriendRequestReceived(_onFriendRequestReceived);
    SocketService.offFriendRequestCancelled(_onFriendRequestCancelled);
    SocketService.offFriendRemoved(_onFriendRemoved);
    SocketService.offPostLiked(_onPostLiked);
    super.dispose();
  }

  Future<void> _checkRelationship() async {
    if (widget.isMe) return;
    try {
      final results = await Future.wait([
        MessageService.fetchConversations(),
        ContactService.fetchContacts(),
      ]);

      if (!mounted) return;

      final conversations = results[0] as List<dynamic>?;
      final data = results[1] as Map<String, dynamic>?;

      if (conversations != null && mounted) {
        for (var c in conversations) {
          final cUserId = c['otherUserId']?.toString();
          final cName = (c['name'] ?? '').toString().trim().toLowerCase();
          final targetName = (widget.name ?? '').toString().trim().toLowerCase();

          if ((widget.userId != null && cUserId == widget.userId) ||
              (targetName.isNotEmpty && cName == targetName)) {
            setState(() {
              if (cUserId != null && cUserId.isNotEmpty) {
                _resolvedUserId = cUserId;
              }
              _existingConversationId = c['id']?.toString();
              if (c['messages'] is List) {
                _cachedMessages = List<Map<String, dynamic>>.from(c['messages']);
              }
            });
            break;
          }
        }
      }

      if (data != null && mounted) {
        final currentTargetId = _effectiveUserId;
        final currentTargetName = widget.name?.trim().toLowerCase();
        final currentTargetEmail = widget.email.trim().toLowerCase();

        if (data['friendRequests'] is List) {
          final reqs = data['friendRequests'] as List;
          final matchReq = reqs.firstWhere(
            (r) =>
                (r is Map) &&
                ((currentTargetId != null &&
                        (r['senderId']?.toString() == currentTargetId ||
                            r['id']?.toString() == currentTargetId)) ||
                    (currentTargetName != null &&
                        currentTargetName.isNotEmpty &&
                        r['name']?.toString().trim().toLowerCase() ==
                            currentTargetName) ||
                    (currentTargetEmail.isNotEmpty &&
                        r['email']?.toString().trim().toLowerCase() ==
                            currentTargetEmail)),
            orElse: () => null,
          );
          if (matchReq != null) {
            setState(() {
              _isIncomingRequest = true;
              _incomingRequestId = matchReq['id']?.toString() ?? widget.requestId;
              if (_resolvedUserId == null && matchReq['senderId'] != null) {
                _resolvedUserId = matchReq['senderId'].toString();
                _loadTargetProfile();
              }
            });
            return;
          }
        }

        if (data['friends'] is List) {
          final friends = data['friends'] as List;
          final matchFriend = friends.firstWhere(
            (f) =>
                (f is Map) &&
                ((currentTargetId != null && f['id']?.toString() == currentTargetId) ||
                    (currentTargetName != null &&
                        currentTargetName.isNotEmpty &&
                        f['name']?.toString().trim().toLowerCase() ==
                            currentTargetName) ||
                    (currentTargetEmail.isNotEmpty &&
                        f['email']?.toString().trim().toLowerCase() ==
                            currentTargetEmail)),
            orElse: () => null,
          );
          if (matchFriend != null) {
            setState(() {
              _isFriend = true;
              _isIncomingRequest = false;
              if (_resolvedUserId == null && matchFriend['id'] != null) {
                _resolvedUserId = matchFriend['id'].toString();
                _loadTargetProfile();
              }
            });
          }
        }

        if (data['following'] is List) {
          final followingList = data['following'] as List;
          final isFol = followingList.any(
            (u) =>
                (u is Map) &&
                ((currentTargetId != null && u['id']?.toString() == currentTargetId) ||
                    (currentTargetName != null &&
                        currentTargetName.isNotEmpty &&
                        u['name']?.toString().trim().toLowerCase() ==
                            currentTargetName)),
          );
          if (isFol) {
            setState(() {
              _isFollowing = true;
            });
          }
        }

        if (!_isFriend && !_isIncomingRequest) {
          final sentList = (data['sentFriendRequests'] as List?) ??
              (data['sentFriendRequestIds'] as List?);
          if (sentList != null) {
            final matchSent = sentList.firstWhere((item) {
              if (item is String) {
                return currentTargetId != null && item == currentTargetId;
              } else if (item is Map) {
                final rId = item['receiverId']?.toString() ?? item['id']?.toString();
                final rName = item['receiverName']?.toString().trim().toLowerCase();
                return (currentTargetId != null && rId == currentTargetId) ||
                    (currentTargetName != null &&
                        currentTargetName.isNotEmpty &&
                        rName == currentTargetName);
              }
              return false;
            }, orElse: () => null);

            if (matchSent != null) {
              setState(() {
                _friendRequestSent = true;
                if (matchSent is Map) {
                  _sentRequestId = matchSent['requestId']?.toString();
                  if (_resolvedUserId == null && matchSent['receiverId'] != null) {
                    _resolvedUserId = matchSent['receiverId'].toString();
                    _loadTargetProfile();
                  }
                }
              });
            }
          }
        }
      }
      if (mounted) {
        _loadTargetProfile();
      }
    } catch (_) {}
  }

  Future<void> _handleFriendRequest() async {
    if (_friendRequestSent || _isSendingRequest) return;

    setState(() {
      _isSendingRequest = true;
    });

    final targetId = _effectiveUserId;
    if (targetId != null && targetId.isNotEmpty) {
      final success = await ContactService.sendFriendRequest(targetId);
      if (mounted) {
        setState(() {
          _isSendingRequest = false;
          if (success) {
            _friendRequestSent = true;
          }
        });
        if (success) {
          AppToast.success(context, l10n.friendRequestSent);
        } else {
          AppToast.error(context, l10n.friendRequestFailed);
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isSendingRequest = false;
          _friendRequestSent = true;
        });
        AppToast.success(context, l10n.friendRequestSent);
      }
    }
  }

  Future<void> _handleCancelFriendRequest(String userName) async {
    if (_isSendingRequest) return;

    setState(() {
      _isSendingRequest = true;
    });

    final targetId = _effectiveUserId;
    if (targetId != null && targetId.isNotEmpty) {
      final success = await ContactService.cancelFriendRequest(
        targetId,
        requestId: _sentRequestId,
      );
      if (mounted) {
        setState(() {
          _isSendingRequest = false;
          if (success) {
            _friendRequestSent = false;
            _sentRequestId = null;
          }
        });
        if (success) {
          AppToast.success(context, l10n.friendRequestCancelled);
        } else {
          AppToast.error(context, l10n.cancelFriendRequestFailed);
        }
      }
    } else {
      setState(() {
        _isSendingRequest = false;
        _friendRequestSent = false;
        _sentRequestId = null;
      });
      AppToast.success(context, l10n.friendRequestCancelled);
    }
  }

  Future<void> _handleRemoveFriend(String userName) async {
    final targetId = _effectiveUserId;
    if (targetId != null && targetId.isNotEmpty) {
      final success = await ContactService.removeFriend(targetId);
      if (mounted) {
        if (success) {
          setState(() {
            _isFriend = false;
            _friendRequestSent = false;
          });
          AppToast.success(context, '${l10n.unfriendedUser} $userName');
        } else {
          AppToast.error(context, l10n.unfriendFailed);
        }
      }
    } else {
      setState(() {
        _isFriend = false;
        _friendRequestSent = false;
      });
      AppToast.success(context, '${l10n.unfriendedUser} $userName');
    }
  }

  Future<void> _handleToggleFollow(String userName) async {
    final targetId = _effectiveUserId;
    if (targetId == null || targetId.isEmpty) {
      setState(() {
        _isFollowing = !_isFollowing;
      });
      AppToast.success(context, _isFollowing ? '${l10n.followedUserToast} $userName' : '${l10n.unfollowedUserToast} $userName');
      return;
    }

    final isCurrentlyFollowing = _isFollowing;
    final result = await ContactService.toggleFollowDetailed(targetId, isCurrentlyFollowing);
    if (mounted) {
      if (result != null && result['success'] == true) {
        final isPending = result['isPending'] == true;
        final isNowFollowing = result['isFollowing'] == true;

        setState(() {
          if (isPending) {
            _hasSentFollowRequest = true;
            _isFollowing = false;
          } else {
            _hasSentFollowRequest = false;
            _isFollowing = isNowFollowing;
            if (_isFollowing) {
              _targetFollowersCount++;
            } else if (_targetFollowersCount > 0 && isCurrentlyFollowing) {
              _targetFollowersCount--;
            }
          }
        });

        ContactScreen.triggerRefresh();

        if (isPending) {
          AppToast.success(context, '${l10n.followRequestSentTo} $userName');
        } else if (_isFollowing) {
          AppToast.success(context, '${l10n.followedUserToast} $userName');
        } else {
          AppToast.success(context, '${l10n.unfollowedUserToast} $userName');
        }
      } else {
        AppToast.error(context, l10n.followActionFailed);
      }
    }
  }

  Future<void> _handleAcceptRequest(String userName) async {
    if (_isSendingRequest) return;

    setState(() {
      _isSendingRequest = true;
    });

    final reqId = _incomingRequestId ?? widget.requestId ?? widget.userId;
    if (reqId != null && reqId.isNotEmpty) {
      final success = await ContactService.acceptFriendRequest(
        reqId,
        senderId: widget.userId,
      );
      if (mounted) {
        setState(() {
          _isSendingRequest = false;
          if (success) {
            _isIncomingRequest = false;
            _isFriend = true;
            _targetFriendsCount++;
          }
        });
        if (success) {
          AppToast.success(context, '${l10n.acceptedFriendRequestWithUser} $userName');
        } else {
          AppToast.error(context, l10n.acceptFriendRequestFailed);
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isSendingRequest = false;
          _isIncomingRequest = false;
          _isFriend = true;
        });
        AppToast.success(context, '${l10n.acceptedFriendRequestWithUser} $userName');
      }
    }
  }

  void _handleReportAccount(String userName) {
    final targetId = _effectiveUserId ?? '';
    ReportScreen.showReportModal(
      context,
      targetUserId: targetId,
      targetName: userName,
    );
  }

  void _confirmBlockAccount(String userName) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.blockUserTitle(userName),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
            fontSize: 18,
          ),
        ),
        content: Text(
          l10n.blockUserWarningDesc(userName),
          style: TextStyle(
            color: context.textMuted,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: context.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _executeBlock(userName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(l10n.block, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeBlock(String userName) async {
    final targetId = _effectiveUserId;
    if (targetId == null || targetId.isEmpty) {
      AppToast.show(context, l10n.userIdNotFoundError, isError: true);
      return;
    }

    final success = await ProfileService.blockAccount(targetId);
    if (!mounted) return;

    if (success) {
      setState(() {
        _isBlockedByViewer = true;
        _isFriend = false;
        _friendRequestSent = false;
        _isFollowing = false;
        _canViewProfilePosts = false;
        _targetPosts = [];
      });
      AppToast.show(context, '${l10n.blockedUserToast} $userName');
    } else {
      AppToast.show(context, l10n.errorBlockingUser, isError: true);
    }
  }

  void _confirmUnblockAccount(String userName) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.unblockUserTitle(userName),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
            fontSize: 18,
          ),
        ),
        content: Text(
          l10n.unblockUserWarningDesc(userName),
          style: TextStyle(
            color: context.textMuted,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: context.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _executeUnblock(userName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(l10n.unblock, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeUnblock(String userName) async {
    final targetId = _effectiveUserId;
    if (targetId == null || targetId.isEmpty) {
      AppToast.show(context, l10n.cannotIdentifyUserId, isError: true);
      return;
    }

    final success = await ProfileService.unblockAccount(targetId);
    if (!mounted) return;

    if (success) {
      setState(() {
        _isBlockedByViewer = false;
      });
      AppToast.show(context, '${l10n.unblockedSuccess}: $userName');
      _loadTargetProfile();
      _checkRelationship();
    } else {
      AppToast.show(context, l10n.errorUnblockingUser, isError: true);
    }
  }

  void _showActionBottomSheet(BuildContext context, String userName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final cardBg = isDark ? const Color(0xFF1E202B) : Colors.white;
            final textColor = isDark ? Colors.white : Colors.black87;
            final subTextColor = isDark ? Colors.white60 : Colors.black54;

            return Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                top: 12,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  Center(
                    child: Container(
                      width: 40,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      AppAvatar(
                        avatar: widget.avatar ?? (userName.isNotEmpty ? userName[0].toUpperCase() : 'U'),
                        name: userName,
                        color: widget.color ?? AppColors.blue,
                        radius: 22,
                        fontSize: 16,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              l10n.interactionOptions,
                              style: TextStyle(
                                fontSize: 12,
                                color: subTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06), height: 1),
                  const SizedBox(height: 8),

                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (_isFollowing || _hasSentFollowRequest)
                            ? Colors.redAccent.withValues(alpha: 0.12)
                            : AppColors.blue.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isFollowing
                            ? Icons.person_remove_rounded
                            : (_hasSentFollowRequest ? Icons.hourglass_top_rounded : Icons.person_add_alt_1_rounded),
                        color: (_isFollowing || _hasSentFollowRequest) ? Colors.redAccent : AppColors.blue,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      _isFollowing
                          ? l10n.unfollow
                          : (_hasSentFollowRequest ? l10n.cancelFollowRequest : l10n.follow),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: (_isFollowing || _hasSentFollowRequest) ? Colors.redAccent : textColor,
                      ),
                    ),
                    subtitle: Text(
                      _isFollowing
                          ? l10n.unfollowDesc(userName)
                          : (_hasSentFollowRequest
                              ? l10n.cancelFollowDesc(userName)
                              : (_isPrivate ? l10n.sendFollowRequestDesc : l10n.followDesc(userName))),
                      style: TextStyle(fontSize: 12, color: subTextColor),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, color: subTextColor, size: 20),
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _handleToggleFollow(userName);
                    },
                  ),

                  if (_isIncomingRequest)
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.how_to_reg_rounded, color: AppColors.blue, size: 20),
                      ),
                      title: Text(
                        l10n.confirmFriendRequest,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: textColor),
                      ),
                      subtitle: Text(
                        l10n.userSentYouFriendRequest(userName),
                        style: TextStyle(fontSize: 12, color: subTextColor),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: subTextColor, size: 20),
                      onTap: () {
                        Navigator.pop(bottomSheetContext);
                        _handleAcceptRequest(userName);
                      },
                    )
                  else if (_isFriend)
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_off_rounded, color: Colors.redAccent, size: 20),
                      ),
                      title: Text(
                        l10n.unfriend,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.redAccent),
                      ),
                      subtitle: Text(
                        l10n.removeUserFromFriends(userName),
                        style: TextStyle(fontSize: 12, color: subTextColor),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: subTextColor, size: 20),
                      onTap: () {
                        Navigator.pop(bottomSheetContext);
                        _handleRemoveFriend(userName);
                      },
                    )
                  else if (_friendRequestSent)
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 20),
                      ),
                      title: Text(
                        l10n.cancelFriendRequest,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.redAccent),
                      ),
                      subtitle: Text(
                        l10n.revokeFriendRequest(userName),
                        style: TextStyle(fontSize: 12, color: subTextColor),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: subTextColor, size: 20),
                      onTap: () {
                        Navigator.pop(bottomSheetContext);
                        _handleCancelFriendRequest(userName);
                      },
                    )
                  else
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_add_rounded, color: AppColors.blue, size: 20),
                      ),
                      title: Text(
                        l10n.sendFriendRequest,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: textColor),
                      ),
                      subtitle: Text(
                        l10n.sendFriendRequestTo(userName),
                        style: TextStyle(fontSize: 12, color: subTextColor),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: subTextColor, size: 20),
                      onTap: () {
                        Navigator.pop(bottomSheetContext);
                        _handleFriendRequest();
                      },
                    ),

                  const SizedBox(height: 6),
                  Divider(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06), height: 1),
                  const SizedBox(height: 6),

                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.flag_outlined, color: Colors.orange, size: 20),
                    ),
                    title: Text(
                      l10n.reportUser(userName),
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: textColor),
                    ),
                    subtitle: Text(
                      l10n.reportViolationSubtitle,
                      style: TextStyle(fontSize: 12, color: subTextColor),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, color: subTextColor, size: 20),
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _handleReportAccount(userName);
                    },
                  ),

                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.block_rounded, color: Colors.red, size: 20),
                    ),
                    title: Text(
                      _isBlockedByViewer ? l10n.unblockUserTitle(userName) : l10n.blockUserTitle(userName),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.red),
                    ),
                    subtitle: Text(
                      _isBlockedByViewer
                          ? l10n.allowUserInteractAgain
                          : l10n.userCannotFindYou,
                      style: TextStyle(fontSize: 12, color: subTextColor),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, color: subTextColor, size: 20),
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      if (_isBlockedByViewer) {
                        _confirmUnblockAccount(userName);
                      } else {
                        _confirmBlockAccount(userName);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLeftActionBtn(BuildContext context, String userName) {
    VoidCallback? tapAction;
    IconData btnIcon;
    String btnText;
    Color btnBg;
    Color btnFg = Colors.white;

    if (_isIncomingRequest) {
      btnIcon = Icons.how_to_reg_rounded;
      btnText = l10n.confirm;
      btnBg = AppColors.blue;
      tapAction = _isSendingRequest ? null : () => _handleAcceptRequest(userName);
    } else if (_isFriend) {
      btnIcon = Icons.people_alt_rounded;
      btnText = l10n.friends;
      btnBg = context.isDark ? const Color(0xFF1E202B) : const Color(0xFFF0F4F8);
      btnFg = context.isDark ? Colors.white : Colors.black87;
      tapAction = () => _showActionBottomSheet(context, userName);
    } else if (_friendRequestSent) {
      btnIcon = Icons.person_remove_rounded;
      btnText = l10n.cancelRequest;
      btnBg = context.isDark ? const Color(0xFF352226) : const Color(0xFFFFECEC);
      btnFg = Colors.redAccent;
      tapAction = _isSendingRequest ? null : () => _handleCancelFriendRequest(userName);
    } else {
      btnIcon = Icons.person_add_rounded;
      btnText = l10n.addFriend;
      btnBg = AppColors.blue;
      btnFg = Colors.white;
      tapAction = _isSendingRequest ? null : _handleFriendRequest;
    }

    return ElevatedButton.icon(
      onPressed: tapAction,
      onLongPress: () => _showActionBottomSheet(context, userName),
      icon: _isSendingRequest
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: btnFg,
              ),
            )
          : Icon(btnIcon, size: 18, color: btnFg),
      label: Text(
        btnText,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: btnFg,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: btnBg,
        disabledBackgroundColor: btnBg,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: _friendRequestSent
              ? BorderSide(
                  color: Colors.redAccent.withValues(alpha: context.isDark ? 0.35 : 0.25),
                )
              : _isFriend
                  ? BorderSide(
                      color: context.isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                    )
                  : BorderSide.none,
        ),
        elevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final userName = _targetUsername ??
        widget.name ??
        (_targetEmail != null && _targetEmail!.isNotEmpty
            ? _targetEmail!.split('@')[0]
            : (widget.email.isNotEmpty ? widget.email.split('@')[0] : 'User'));
    final userAvatar = (_targetAvatar != null && _targetAvatar!.isNotEmpty)
        ? _targetAvatar!
        : (widget.avatar ?? (userName.isNotEmpty ? userName[0].toUpperCase() : 'U'));
    final userColor = widget.color ?? AppColors.blue;
    final userBio = (_targetBio != null && _targetBio!.trim().isNotEmpty)
        ? _targetBio!.trim()
        : (widget.status ?? '');
    final userEmail = (_targetEmail != null && _targetEmail!.isNotEmpty)
        ? _targetEmail!
        : widget.email;
    final canPop = Navigator.canPop(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadTargetProfile();
          await _checkRelationship();
        },
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
                    if (_targetCoverImage != null &&
                        _targetCoverImage!.isNotEmpty &&
                        _targetCoverImage!.startsWith('http'))
                      Positioned.fill(
                        child: ClipRect(
                          child: Image.network(
                            _targetCoverImage!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [userColor, userColor.withValues(alpha: 0.7)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [userColor, userColor.withValues(alpha: 0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),

                  if (canPop)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 10,
                      left: 16,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.2),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                    ),

                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    right: 16,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.2),
                        child: IconButton(
                          icon: Icon(
                            widget.isMe ? Icons.settings_rounded : Icons.more_vert_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          onPressed: () {
                            if (widget.isMe) {
                              Navigator.pushNamed(context, AppRoutes.settings);
                            } else {
                              _showActionBottomSheet(context, userName);
                            }
                          },
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 120,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          final isNetworkImage = userAvatar.startsWith('http://') || userAvatar.startsWith('https://');
                          Navigator.pushNamed(
                            context,
                            AppRoutes.avatarViewer,
                            arguments: {
                              'imageUrl': isNetworkImage ? userAvatar : null,
                              'title': userName,
                              'fallbackText': userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                              'fallbackColor': userColor,
                              'heroTag': 'account_avatar_$userName',
                            },
                          );
                        },
                        child: Hero(
                          tag: 'account_avatar_$userName',
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
                              child: AppAvatar(
                                avatar: userAvatar,
                                name: userName,
                                color: userColor,
                                radius: 50,
                                fontSize: 48,
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
                  userName,
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
            if (userBio.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Text(
                  userBio,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
            ],

            if (!widget.isMe && _isBlockedByViewer) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.block_rounded, color: Colors.red, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.youBlockedUser(userName),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: context.textPrimary,
                              ),
                            ),
                            Text(
                              l10n.unblockToViewInfo,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _confirmUnblockAccount(userName),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.blue,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        child: Text(l10n.unblock),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (!widget.isMe) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [

                    Expanded(
                      child: _buildLeftActionBtn(context, userName),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final effectiveReceiverId = widget.userId ?? (widget.email.isNotEmpty ? widget.email : userName);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatDetailScreen(
                                name: userName,
                                avatar: userAvatar,
                                color: userColor,
                                conversationId: _existingConversationId,
                                receiverId: effectiveReceiverId,
                                isFriend: _isFriend,
                                initialMessages: _cachedMessages,
                              ),
                            ),
                          );
                          MessagesScreen.triggerRefresh();
                        },
                        icon: Icon(
                          Icons.chat_bubble_rounded,
                          size: 18,
                          color: context.isDark ? Colors.white : Colors.black87,
                        ),
                        label: Text(
                          l10n.messageAction,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: context.isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.isDark
                              ? const Color(0xFF1E202B)
                              : const Color(0xFFF0F4F8),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: context.isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.08),
                            ),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Material(
                      color: context.isDark ? const Color(0xFF1E202B) : const Color(0xFFF0F4F8),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _showActionBottomSheet(context, userName),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: context.isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Icon(
                            Icons.more_horiz_rounded,
                            color: context.isDark ? Colors.white : Colors.black87,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatItem(context, l10n.following, '$_targetFollowingCount'),
                  _buildStatVerticalDivider(context),
                  _buildStatItem(context, l10n.followers, '$_targetFollowersCount'),
                  _buildStatVerticalDivider(context),
                  _buildStatItem(context, l10n.friends, '$_targetFriendsCount'),
                  _buildStatVerticalDivider(context),
                  _buildStatItem(context, l10n.groups, '$_targetGroupsCount'),
                  _buildStatVerticalDivider(context),
                  _buildStatItem(context, l10n.posts, '$_targetPostsCount'),
                ],
              ),
            ),

            const SizedBox(height: 28),

            if (_isBlockedByViewer)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.block_flipped, size: 56, color: context.textMuted.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text(
                        l10n.youBlockedUser(userName),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.postsAndInfoHidden,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_isBlockedByTarget)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.person_off_rounded, size: 56, color: context.textMuted.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text(
                        l10n.profileUnavailable,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_isPrivate && !_canViewProfilePosts)
              _buildPrivateAccountNotice(context)
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        if (_isLoadingProfile &&
                            (_targetEmail == null &&
                                _targetGender == null &&
                                _targetBirthday == null &&
                                _targetAddress == null &&
                                _targetPhone == null)) {
                          return [
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20.0),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                          ];
                        }

                        final infoRows = <Widget>[];

                        void addRow(IconData icon, String label, String value) {
                          if (infoRows.isNotEmpty) {
                            infoRows.add(_buildDivider(context));
                          }
                          infoRows.add(_buildInfoRow(context, icon, label, value));
                        }

                        if (userEmail.isNotEmpty) {
                          addRow(Icons.email_outlined, l10n.email, userEmail);
                        }

                        if (_targetGender != null && _targetGender!.trim().isNotEmpty) {
                          addRow(Icons.person_outline, l10n.gender, _formatGender(context, _targetGender));
                        }

                        if (_targetBirthday != null && _targetBirthday!.trim().isNotEmpty) {
                          addRow(Icons.cake_outlined, l10n.birthday, _formatDate(_targetBirthday));
                        }

                        if (_targetAddress != null && _targetAddress!.trim().isNotEmpty) {
                          addRow(Icons.location_on_outlined, l10n.address, _targetAddress!.trim());
                        }

                        if (_targetHomeTown != null && _targetHomeTown!.trim().isNotEmpty) {
                          addRow(Icons.cottage_outlined, l10n.hometown, _targetHomeTown!.trim());
                        }

                        if (_targetPlacesLived.isNotEmpty) {
                          final validPlaces = _targetPlacesLived
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

                        if (_targetPhone != null && _targetPhone!.trim().isNotEmpty) {
                          addRow(Icons.phone_outlined, l10n.phoneNumber, _targetPhone!.trim());
                        }

                        if (_targetNationality != null && _targetNationality!.trim().isNotEmpty) {
                          addRow(Icons.flag_outlined, l10n.nationality, _targetNationality!.trim());
                        }

                        if (_targetJob != null && _targetJob!.trim().isNotEmpty) {
                          addRow(Icons.work_outline, l10n.job, _targetJob!.trim());
                        }

                        if (_targetHobby != null && _targetHobby!.trim().isNotEmpty) {
                          addRow(Icons.sports_esports_outlined, l10n.hobbies, _targetHobby!.trim());
                        }

                        if (infoRows.isEmpty) {
                          return [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              child: Center(
                                child: Text(
                                  l10n.noPersonalInfo,
                                  style: TextStyle(
                                    color: context.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ];
                        }

                        return infoRows;
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
                    if (_isLoadingTargetPosts && _targetPosts.isEmpty)
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
                    else if (_targetPosts.isEmpty)
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
                        itemCount: _targetPosts.length,
                        itemBuilder: (ctx, index) {
                          final post = _targetPosts[index];
                          final postId = (post['id'] ?? post['_id'] ?? '').toString();
                          return PostCard(
                            post: post,
                            currentUserEmail: _targetEmail ?? widget.email,
                            currentUserName: _targetUsername ?? widget.name,
                            currentUserAvatar: _targetAvatar ?? widget.avatar,
                            defaultAvatarColor: widget.color,
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
                                _targetPosts.removeWhere((p) =>
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
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildPrivateAccountNotice(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_rounded,
              size: 44,
              color: AppColors.blue,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.accountIsPrivate,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.accountIsPrivateDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: context.textMuted,
              height: 1.4,
            ),
          ),
          if (_hasSentFollowRequest) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hourglass_top_rounded, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    l10n.followRequestPending,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
}
