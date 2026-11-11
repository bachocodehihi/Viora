import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../services/contact_service.dart';
import '../../services/group_service.dart';
import '../../widgets/toast/app_toast.dart';
import 'create_group_screen.dart';
import 'followers_screen.dart';
import 'followings_screen.dart';
import 'friends_screen.dart';
import 'groups_screen.dart';
import 'requests_screen.dart';
import '../../services/socket_service.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  static VoidCallback? _globalRefreshCallback;
  static void triggerRefresh() {
    try {
      _globalRefreshCallback?.call();
    } catch (_) {}
  }

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final PageController _pageController;
  final ScrollController _tabScrollController = ScrollController();
  final List<GlobalKey> _tabKeys = List.generate(5, (_) => GlobalKey());
  bool _isPageAnimating = false;

  String _searchQuery = "";
  int _selectedTabIndex = 0;
  bool _isLoading = false;

  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _friendRequests = [];
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _following = [];
  List<Map<String, dynamic>> _followers = [];

  static const List<Color> _avatarColors = [
    AppColors.blue,
    AppColors.purple,
    AppColors.pink,
    AppColors.orange,
    AppColors.teal,
  ];

  Color _getColor(dynamic id, int fallbackIndex) {
    if (id is String && id.isNotEmpty) {
      return _avatarColors[id.hashCode.abs() % _avatarColors.length];
    }
    return _avatarColors[fallbackIndex % _avatarColors.length];
  }

  late final Function(Map<String, dynamic>) _onFriendRequestReceived;
  late final Function(Map<String, dynamic>) _onFollowRequestReceived;
  late final Function(Map<String, dynamic>) _onFriendRequestCancelled;
  late final Function(Map<String, dynamic>) _onFriendRequestAccepted;
  late final Function(Map<String, dynamic>) _onFriendRemoved;
  late final Function(Map<String, dynamic>) _onFollowerAdded;
  late final Function(Map<String, dynamic>) _onFollowerRemoved;
  late final Function(Map<String, dynamic>) _onFollowingAdded;
  late final Function(Map<String, dynamic>) _onFollowingRemoved;
  late final Function(String) _onUserOnline;
  late final Function(String) _onUserOffline;
  late final Function(Map<String, dynamic>) _onUserActiveStatusChanged;

  @override
  void initState() {
    super.initState();
    ContactScreen._globalRefreshCallback = () => _fetchContactData(isRefresh: true);
    _pageController = PageController(initialPage: _selectedTabIndex);
    _initSocketListeners();
    _fetchContactData();
  }

  void _initSocketListeners() {
    SocketService.init();

    _onFriendRequestReceived = (data) {
      if (!mounted) return;
      setState(() {
        final senderId = data['senderId']?.toString();
        final reqId = data['id']?.toString() ?? data['requestId']?.toString() ?? '';
        _friendRequests.removeWhere((r) =>
            r['id'] == reqId || (senderId != null && r['senderId'] == senderId));

        _friendRequests.insert(0, {
          'id': reqId,
          'type': data['type']?.toString() ?? 'friend',
          'senderId': senderId,
          'name': data['name']?.toString() ?? '',
          'avatar': data['avatar']?.toString() ?? (data['name'] != null && data['name'].toString().isNotEmpty ? data['name'][0].toUpperCase() : 'U'),
          'color': _getColor(reqId, 0),
          'mutualFriends': data['mutualFriends'] is int ? data['mutualFriends'] : 0,
          'membersCount': 1,
          'time': data['time']?.toString() ?? 'just_now',
        });
      });
    };
    SocketService.onFriendRequestReceived(_onFriendRequestReceived);

    _onFollowRequestReceived = (data) {
      if (!mounted) return;
      setState(() {
        final sender = data['sender'] is Map ? data['sender'] as Map : {};
        final senderId = sender['id']?.toString() ?? data['senderId']?.toString();
        final reqId = data['requestId']?.toString() ?? data['id']?.toString() ?? '';
        final senderName = sender['name']?.toString() ?? data['name']?.toString() ?? '';
        final avatar = sender['avatar']?.toString() ?? data['avatar']?.toString();
        _friendRequests.removeWhere((r) =>
            r['id'] == reqId || (senderId != null && r['senderId'] == senderId));

        _friendRequests.insert(0, {
          'id': reqId,
          'type': 'follow',
          'senderId': senderId,
          'name': senderName,
          'avatar': avatar ?? (senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U'),
          'color': _getColor(reqId, 0),
          'mutualFriends': 0,
          'membersCount': 1,
          'time': 'just_now',
        });
      });
    };
    SocketService.onFollowRequestReceived(_onFollowRequestReceived);

    _onFriendRequestCancelled = (data) {
      if (!mounted) return;
      final senderId = data['senderId']?.toString();
      final reqId = data['requestId']?.toString();
      setState(() {
        _friendRequests.removeWhere((r) =>
            (reqId != null && reqId.isNotEmpty && r['id'] == reqId) ||
            (senderId != null && r['senderId'] == senderId));
      });
    };
    SocketService.onFriendRequestCancelled(_onFriendRequestCancelled);

    _onFriendRequestAccepted = (data) {
      if (!mounted) return;
      final otherUserId = data['userId']?.toString();
      final otherName = data['name']?.toString() ?? '';
      final reqId = data['requestId']?.toString();
      setState(() {
        _friendRequests.removeWhere((r) =>
            (reqId != null && reqId.isNotEmpty && r['id'] == reqId) ||
            (otherUserId != null && r['senderId'] == otherUserId));

        if (otherUserId != null && !_contacts.any((c) => c['id'] == otherUserId)) {
          final bool showActive = data['showActiveStatus'] == true;
          final bool isOnline = showActive && (data['online'] == true);
          _contacts.insert(0, {
            'id': otherUserId,
            'name': otherName,
            'avatar': data['avatar']?.toString() ?? (otherName.isNotEmpty ? otherName[0].toUpperCase() : 'U'),
            'color': _getColor(otherUserId, 0),
            'status': data['bio']?.toString() ?? 'friends',
            'showActiveStatus': showActive,
            'online': isOnline,
            'messages': <Map<String, dynamic>>[],
          });
        }
      });
    };
    SocketService.onFriendRequestAccepted(_onFriendRequestAccepted);

    _onFriendRemoved = (data) {
      if (!mounted) return;
      final removedUserId = data['userId']?.toString();
      if (removedUserId != null) {
        setState(() {
          _contacts.removeWhere((c) => c['id'] == removedUserId);
        });
      }
    };
    SocketService.onFriendRemoved(_onFriendRemoved);

    _onFollowerAdded = (data) {
      if (!mounted) return;
      final userData = data['user'];
      if (userData is Map) {
        final fid = userData['id']?.toString();
        if (fid != null && !_followers.any((f) => f['id'] == fid)) {
          setState(() {
            _followers.insert(0, {
              'id': fid,
              'name': userData['name']?.toString() ?? '',
              'avatar': userData['avatar']?.toString() ?? (userData['name'] != null && userData['name'].toString().isNotEmpty ? userData['name'][0].toUpperCase() : 'U'),
              'color': _getColor(fid, 0),
              'handle': userData['handle']?.toString() ?? '@${(userData['name']?.toString() ?? '').toLowerCase().replaceAll(' ', '_')}',
              'bio': userData['bio']?.toString() ?? '',
              'isFollowing': userData['isFollowing'] == true,
            });
          });
        }
      }
    };
    SocketService.onFollowerAdded(_onFollowerAdded);

    _onFollowerRemoved = (data) {
      if (!mounted) return;
      final fid = data['userId']?.toString();
      if (fid != null) {
        setState(() {
          _followers.removeWhere((f) => f['id'] == fid);
        });
      }
    };
    SocketService.onFollowerRemoved(_onFollowerRemoved);

    _onFollowingAdded = (data) {
      if (!mounted) return;
      final userData = data['user'];
      if (userData is Map) {
        final fid = userData['id']?.toString();
        if (fid != null) {
          setState(() {
            _following.removeWhere((f) => f['id'] == fid);
            _following.insert(0, {
              'id': fid,
              'name': userData['name']?.toString() ?? '',
              'avatar': userData['avatar']?.toString() ?? (userData['name'] != null && userData['name'].toString().isNotEmpty ? userData['name'][0].toUpperCase() : 'U'),
              'color': _getColor(fid, 0),
              'handle': userData['handle']?.toString() ?? '@${(userData['name']?.toString() ?? '').toLowerCase().replaceAll(' ', '_')}',
              'bio': userData['bio']?.toString() ?? '',
              'isFollowing': true,
            });
          });
        }
      }
    };
    SocketService.onFollowingAdded(_onFollowingAdded);

    _onFollowingRemoved = (data) {
      if (!mounted) return;
      final fid = data['userId']?.toString();
      if (fid != null) {
        setState(() {
          _following.removeWhere((f) => f['id'] == fid);
        });
      }
    };
    SocketService.onFollowingRemoved(_onFollowingRemoved);

    _onUserOnline = (userId) {
      if (!mounted || userId.isEmpty) return;
      setState(() {
        for (var c in _contacts) {
          if (c['id']?.toString() == userId && c['showActiveStatus'] != false) {
            c['online'] = true;
          }
        }
      });
    };
    SocketService.onUserOnline(_onUserOnline);

    _onUserOffline = (userId) {
      if (!mounted || userId.isEmpty) return;
      setState(() {
        for (var c in _contacts) {
          if (c['id']?.toString() == userId) {
            c['online'] = false;
          }
        }
      });
    };
    SocketService.onUserOffline(_onUserOffline);

    _onUserActiveStatusChanged = (data) {
      if (!mounted) return;
      final uid = data['userId']?.toString() ?? '';
      if (uid.isEmpty) return;
      final bool show = data['showActiveStatus'] != false;
      final bool online = show && (data['isOnline'] == true || data['online'] == true);
      setState(() {
        for (var c in _contacts) {
          if (c['id']?.toString() == uid) {
            c['showActiveStatus'] = show;
            c['online'] = online;
          }
        }
      });
    };
    SocketService.onUserActiveStatusChanged(_onUserActiveStatusChanged);
  }

  @override
  void dispose() {
    if (ContactScreen._globalRefreshCallback != null) {
      ContactScreen._globalRefreshCallback = null;
    }
    SocketService.offFriendRequestReceived(_onFriendRequestReceived);
    SocketService.offFollowRequestReceived(_onFollowRequestReceived);
    SocketService.offFriendRequestCancelled(_onFriendRequestCancelled);
    SocketService.offFriendRequestAccepted(_onFriendRequestAccepted);
    SocketService.offFriendRemoved(_onFriendRemoved);
    SocketService.offFollowerAdded(_onFollowerAdded);
    SocketService.offFollowerRemoved(_onFollowerRemoved);
    SocketService.offFollowingAdded(_onFollowingAdded);
    SocketService.offFollowingRemoved(_onFollowingRemoved);
    SocketService.offUserOnline(_onUserOnline);
    SocketService.offUserOffline(_onUserOffline);
    SocketService.offUserActiveStatusChanged(_onUserActiveStatusChanged);
    _pageController.dispose();
    _tabScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchContactData({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() => _isLoading = true);
    }
    try {
      final results = await Future.wait([
        ContactService.fetchContacts(),
        GroupService.getMyGroups(),
      ]);
      final data = results[0] as Map<String, dynamic>?;
      final serverMyGroups = results[1] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          if (serverMyGroups.isNotEmpty) {
            _groups = serverMyGroups;
          }

          if (data != null) {

          if (data['friendRequests'] is List) {
            final rawRequests = data['friendRequests'] as List;
            _friendRequests = rawRequests.asMap().entries.map((entry) {
              final idx = entry.key;
              final r = entry.value as Map<String, dynamic>;
              return {
                'id': r['id']?.toString() ?? '',
                'type': r['type']?.toString() ?? 'friend',
                'senderId': r['senderId']?.toString(),
                'groupId': r['groupId']?.toString(),
                'name': r['name']?.toString() ?? '',
                'inviter': r['inviter']?.toString() ?? '',
                'avatar': r['avatar']?.toString() ?? (r['name'] != null && r['name'].toString().isNotEmpty ? r['name'][0].toUpperCase() : 'U'),
                'color': _getColor(r['id'], idx),
                'mutualFriends': r['mutualFriends'] is int ? r['mutualFriends'] : 0,
                'membersCount': r['membersCount'] is int ? r['membersCount'] : 1,
                'time': r['time']?.toString() ?? 'just_now',
              };
            }).toList();
          } else {
            _friendRequests = [];
          }

          if (data['friends'] is List) {
            final rawFriends = data['friends'] as List;
            _contacts = rawFriends.asMap().entries.map((entry) {
              final idx = entry.key;
              final f = entry.value as Map<String, dynamic>;
              final bool showActive = f['showActiveStatus'] != false;
              return {
                'id': f['id']?.toString() ?? '',
                'name': f['name']?.toString() ?? '',
                'avatar': f['avatar']?.toString() ?? (f['name'] != null && f['name'].toString().isNotEmpty ? f['name'][0].toUpperCase() : 'U'),
                'color': _getColor(f['id'], idx),
                'status': f['status']?.toString() ?? '',
                'showActiveStatus': showActive,
                'online': showActive && (f['online'] == true),
                'messages': f['messages'] is List ? List<Map<String, dynamic>>.from(f['messages']) : <Map<String, dynamic>>[],
              };
            }).toList();
          } else {
            _contacts = [];
          }

          if (data['following'] is List) {
            final rawFollowing = data['following'] as List;
            _following = rawFollowing.asMap().entries.map((entry) {
              final idx = entry.key;
              final u = entry.value as Map<String, dynamic>;
              return {
                'id': u['id']?.toString() ?? '',
                'name': u['name']?.toString() ?? '',
                'avatar': u['avatar']?.toString() ?? (u['name'] != null && u['name'].toString().isNotEmpty ? u['name'][0].toUpperCase() : 'U'),
                'color': _getColor(u['id'], idx),
                'handle': u['handle']?.toString() ?? '@${(u['name']?.toString() ?? '').toLowerCase().replaceAll(' ', '_')}',
                'bio': u['bio']?.toString() ?? '',
                'isFollowing': true,
              };
            }).toList();
          } else {
            _following = [];
          }

          if (data['followers'] is List) {
            final rawFollowers = data['followers'] as List;
            _followers = rawFollowers.asMap().entries.map((entry) {
              final idx = entry.key;
              final u = entry.value as Map<String, dynamic>;
              return {
                'id': u['id']?.toString() ?? '',
                'name': u['name']?.toString() ?? '',
                'avatar': u['avatar']?.toString() ?? (u['name'] != null && u['name'].toString().isNotEmpty ? u['name'][0].toUpperCase() : 'U'),
                'color': _getColor(u['id'], idx),
                'handle': u['handle']?.toString() ?? '@${(u['name']?.toString() ?? '').toLowerCase().replaceAll(' ', '_')}',
                'bio': u['bio']?.toString() ?? '',
                'isFollowing': u['isFollowing'] == true,
              };
            }).toList();
          } else {
            _followers = [];
          }

          }
        });
      }
    } catch (e) {
      debugPrint('_fetchContactData error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToSearchScreen() {
    Navigator.pushNamed(context, AppRoutes.search);
  }

  Future<void> _navigateToCreateGroupScreen() async {
    final l10n = context.l10n;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateGroupScreen(contacts: _contacts),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _groups.insert(0, result);
      });
      AppToast.success(
        context,
        '${l10n.createGroup} "${result['name']}"!',
      );

      final memberIds = (result['memberIds'] as List<dynamic>?)?.map((e) => e.toString()).toList();
      final privacy = result['privacy']?.toString() ?? 'public';

      GroupService.createGroup(
        name: result['name'] ?? '',
        privacy: privacy,
        memberIds: memberIds,
      ).then((res) {
        final serverGroup = res?['group'];
        if (serverGroup != null && mounted) {
          setState(() {
            final idx = _groups.indexWhere((g) => g['id'] == result['id']);
            if (idx != -1) {
              _groups[idx]['id'] = serverGroup['id'];
              _groups[idx]['conversationId'] = serverGroup['conversationId'];
              _groups[idx]['privacy'] = serverGroup['privacy'];
            }
          });
        }
      });
    }
  }

  void _acceptFriendRequest(Map<String, dynamic> req) {
    final l10n = context.l10n;
    final requestId = req['id']?.toString() ?? '';
    final senderId = req['senderId']?.toString();

    setState(() {
      _friendRequests.removeWhere((r) => r['id'] == req['id']);
      _contacts.add({
        'id': senderId ?? req['id'],
        'name': req['name'],
        'avatar': req['avatar'],
        'color': req['color'],
        'status': l10n.friends,
        'showActiveStatus': false,
        'online': false,
        'messages': [],
      });
    });

    AppToast.success(
      context,
      '${l10n.acceptedFriendToast} ${req['name']}!',
    );

    if (requestId.isNotEmpty) {
      ContactService.acceptFriendRequest(requestId, senderId: senderId).then((success) {
        if (success) {
          if (mounted) _fetchContactData(isRefresh: true);
        } else {
          debugPrint('Backend acceptFriendRequest failed');
        }
      });
    }
  }

  void _declineFriendRequest(Map<String, dynamic> req) {
    final l10n = context.l10n;
    final requestId = req['id']?.toString() ?? '';
    final senderId = req['senderId']?.toString();

    setState(() {
      _friendRequests.removeWhere((r) => r['id'] == req['id']);
    });

    AppToast.error(
      context,
      '${l10n.declinedFriendToast} ${req['name']}',
    );

    if (requestId.isNotEmpty) {
      ContactService.declineFriendRequest(requestId, senderId: senderId).then((success) {
        if (!success) {
          debugPrint('Backend declineFriendRequest failed');
        }
      });
    }
  }

  void _acceptFollowRequest(Map<String, dynamic> req) {
    final l10n = context.l10n;
    final requestId = req['id']?.toString() ?? '';
    final senderId = req['senderId']?.toString();

    setState(() {
      _friendRequests.removeWhere((r) => r['id'] == req['id']);
      if (senderId != null && !_followers.any((f) => f['id'] == senderId)) {
        _followers.insert(0, {
          'id': senderId,
          'name': req['name'] ?? '',
          'avatar': req['avatar'],
          'color': req['color'],
          'handle': '@${(req['name'] ?? '').toLowerCase().replaceAll(' ', '_')}',
          'bio': '',
          'isFollowing': false,
        });
      }
    });

    AppToast.success(
      context,
      '${l10n.acceptedFollowToast} ${req['name']}!',
    );

    if (requestId.isNotEmpty) {
      ContactService.acceptFollowRequest(requestId).then((success) {
        if (!success) {
          debugPrint('Backend acceptFollowRequest failed');
        }
      });
    }
  }

  void _declineFollowRequest(Map<String, dynamic> req) {
    final l10n = context.l10n;
    final requestId = req['id']?.toString() ?? '';

    setState(() {
      _friendRequests.removeWhere((r) => r['id'] == req['id']);
    });

    AppToast.error(
      context,
      '${l10n.declinedFollowToast} ${req['name']}',
    );

    if (requestId.isNotEmpty) {
      ContactService.rejectFollowRequest(requestId).then((success) {
        if (!success) {
          debugPrint('Backend rejectFollowRequest failed');
        }
      });
    }
  }

  void _acceptGroupInvite(Map<String, dynamic> req) {
    final l10n = context.l10n;
    final requestId = req['id']?.toString() ?? '';
    final groupId = req['groupId']?.toString();

    setState(() {
      _friendRequests.removeWhere((r) => r['id'] == req['id']);
      _groups.insert(0, {
        'id': groupId ?? req['id'],
        'name': req['name'],
        'avatar': req['avatar'],
        'color': req['color'],
        'membersCount': (req['membersCount'] ?? 1) + 1,
        'lastMessage': l10n.joinedGroupSuccess,
        'time': 'just_now',
      });
    });

    AppToast.success(
      context,
      '${l10n.joinedGroupToast} "${req['name']}"!',
    );

    if (requestId.isNotEmpty) {
      ContactService.acceptGroupInvite(requestId, groupId: groupId).then((success) {
        if (!success) {
          debugPrint('Backend acceptGroupInvite failed');
        }
      });
    }
  }

  void _declineGroupInvite(Map<String, dynamic> req) {
    final l10n = context.l10n;
    final requestId = req['id']?.toString() ?? '';
    final groupId = req['groupId']?.toString();

    setState(() {
      _friendRequests.removeWhere((r) => r['id'] == req['id']);
    });

    AppToast.error(
      context,
      '${l10n.declinedFriendToast} ${req['name']}',
    );

    if (requestId.isNotEmpty) {
      ContactService.declineGroupInvite(requestId, groupId: groupId).then((success) {
        if (!success) {
          debugPrint('Backend declineGroupInvite failed');
        }
      });
    }
  }

  void _toggleFollow(Map<String, dynamic> user) {
    final l10n = context.l10n;
    final isCurrentlyFollowing = user['isFollowing'] == true;
    final nextFollowing = !isCurrentlyFollowing;
    final userId = user['id']?.toString() ?? '';
    final targetName = (user['name'] ?? '').toString().trim().toLowerCase();

    bool isSameUser(Map<String, dynamic> u) {
      final uId = u['id']?.toString() ?? '';
      final uName = (u['name'] ?? '').toString().trim().toLowerCase();
      if (userId.isNotEmpty && uId.isNotEmpty) {
        return userId == uId;
      }
      if (targetName.isNotEmpty && uName.isNotEmpty) {
        return targetName == uName;
      }
      return false;
    }

    setState(() {
      user['isFollowing'] = nextFollowing;

      for (var f in _followers) {
        if (isSameUser(f)) {
          f['isFollowing'] = nextFollowing;
        }
      }

      if (nextFollowing) {
        final existingIdx = _following.indexWhere(isSameUser);
        if (existingIdx != -1) {
          _following[existingIdx]['isFollowing'] = true;
        } else {
          _following.insert(0, {
            ...user,
            'isFollowing': true,
          });
        }
      } else {
        _following.removeWhere(isSameUser);
      }
    });

    if (nextFollowing) {
      AppToast.success(context, '${l10n.followedToast} ${user['name']}!');
    } else {
      AppToast.info(context, '${l10n.unfollowedToast} ${user['name']}');
    }

    if (userId.isNotEmpty) {
      ContactService.toggleFollow(userId, isCurrentlyFollowing).then((success) {
        if (!success) {
          debugPrint('Backend toggleFollow failed');
        }
      });
    }
  }

  void _onTabTapped(int index) {
    if (_selectedTabIndex == index) return;
    setState(() {
      _selectedTabIndex = index;
      _searchQuery = "";
      _searchController.clear();
    });

    _scrollToTab(index);
    _fetchContactData(isRefresh: true);

    if (_pageController.hasClients) {
      _isPageAnimating = true;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ).then((_) {
        _isPageAnimating = false;
      });
    }
  }

  void _onPageChanged(int index) {
    if (_isPageAnimating) return;
    if (_selectedTabIndex == index) return;
    setState(() {
      _selectedTabIndex = index;
      _searchQuery = "";
      _searchController.clear();
    });
    _scrollToTab(index);
    _fetchContactData(isRefresh: true);
  }

  void _scrollToTab(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (index >= 0 && index < _tabKeys.length) {
        final keyContext = _tabKeys[index].currentContext;
        if (keyContext != null) {
          Scrollable.ensureVisible(
            keyContext,
            alignment: 0.5,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            l10n.contacts,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: context.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _selectedTabIndex == 4 ? Icons.group_add_rounded : Icons.person_add_alt_1_rounded,
                color: context.textPrimary,
                size: 24,
              ),
              onPressed: _selectedTabIndex == 4 ? _navigateToCreateGroupScreen : _navigateToSearchScreen,
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 6.0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: _selectedTabIndex == 0
                      ? l10n.searchRequests
                      : _selectedTabIndex == 1
                          ? l10n.searchFriends
                          : _selectedTabIndex == 2
                              ? l10n.searchFollowing
                              : _selectedTabIndex == 3
                                  ? l10n.searchFollowers
                                  : l10n.searchGroups,
                  hintStyle: TextStyle(color: context.textMuted, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = "";
                            });
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  fillColor: context.cardBg,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: context.isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: context.isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildTabBar(),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _fetchContactData(isRefresh: true),
                color: AppColors.blue,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.blue),
                      )
                    : PageView(
                        controller: _pageController,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: _onPageChanged,
                        children: [
                          RequestsScreen(
                            requests: _friendRequests,
                            searchQuery: _searchQuery,
                            onAcceptFriend: _acceptFriendRequest,
                            onDeclineFriend: _declineFriendRequest,
                            onAcceptFollow: _acceptFollowRequest,
                            onDeclineFollow: _declineFollowRequest,
                            onAcceptGroup: _acceptGroupInvite,
                            onDeclineGroup: _declineGroupInvite,
                          ),
                          FriendsScreen(
                            contacts: _contacts,
                            searchQuery: _searchQuery,
                          ),
                          FollowingsScreen(
                            following: _following,
                            searchQuery: _searchQuery,
                            onToggleFollow: _toggleFollow,
                            onRefresh: () => _fetchContactData(isRefresh: true),
                          ),
                          FollowersScreen(
                            followers: _followers,
                            searchQuery: _searchQuery,
                            onToggleFollow: _toggleFollow,
                            onRefresh: () => _fetchContactData(isRefresh: true),
                          ),
                          GroupsScreen(
                            groups: _groups,
                            searchQuery: _searchQuery,
                            onRefresh: () => _fetchContactData(isRefresh: true),
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

  Widget _buildTabBar() {
    final l10n = context.l10n;
    final tabs = [
      l10n.requests,
      l10n.friends,
      l10n.following,
      l10n.followers,
      l10n.groups,
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16.0, 6.0, 16.0, 6.0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: SingleChildScrollView(
        controller: _tabScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(tabs.length, (index) {
            final isSelected = _selectedTabIndex == index;
            final title = tabs[index];

            return GestureDetector(
              key: _tabKeys[index],
              onTap: () => _onTabTapped(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 13,
                      color: isSelected ? Colors.white : context.textMuted,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
