import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../services/contact_service.dart';
import '../../services/group_service.dart';
import '../../services/search_service.dart';
import '../../services/session_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/toast/app_toast.dart';
import '../chat/chat_detail_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String query;

  const SearchResultsScreen({
    super.key,
    required this.query,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late TextEditingController _searchController;
  late String _searchQuery;
  int _selectedCategoryIndex = 0;

  String _selectedSort = 'latest';
  String _selectedTime = 'all';

  String? _currentUserId;
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _groups = [];

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.query;
    _searchController = TextEditingController(text: widget.query);
    _loadCurrentUserId();
    _performSearch();
  }

  Future<void> _loadCurrentUserId() async {
    final uid = await SessionService.getUserId();
    if (mounted) {
      setState(() {
        _currentUserId = uid;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchQuery.trim();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _users = [];
          _posts = [];
          _groups = [];
          _isLoading = false;
        });
      }
      return;
    }

    setState(() => _isLoading = true);

    String type = 'all';
    if (_selectedCategoryIndex == 1) type = 'users';
    if (_selectedCategoryIndex == 2) type = 'posts';
    if (_selectedCategoryIndex == 3) type = 'groups';

    final results = await SearchService.search(
      query,
      type: type,
      sort: _selectedSort,
    );

    if (mounted) {
      setState(() {
        _users = List<Map<String, dynamic>>.from(results['users'] ?? []);
        _posts = List<Map<String, dynamic>>.from(results['posts'] ?? []);
        _groups = List<Map<String, dynamic>>.from(results['groups'] ?? []);
        _isLoading = false;
      });
    }
  }

  void _onSearchSubmitted(String query) {
    final trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      setState(() {
        _searchQuery = trimmed;
      });
      _performSearch();
    } else {
      Navigator.pop(context);
    }
  }

  void _navigateToChat(
    String name,
    String avatar,
    Color color, {
    String? userId,
    bool isFriend = false,
    bool isOnline = false,
    bool showActiveStatus = false,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          name: name,
          avatar: avatar,
          color: color,
          receiverId: userId,
          isFriend: isFriend,
          isOnline: showActiveStatus ? isOnline : false,
          showActiveStatus: showActiveStatus,
          initialMessages: const [],
        ),
      ),
    );
  }

  void _showFilterBottomSheet() {
    final l10n = context.l10n;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        String tempSort = _selectedSort;
        String tempTime = _selectedTime;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.textSubtle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.filterTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempSort = 'latest';
                            tempTime = 'all';
                          });
                        },
                        child: Text(
                          l10n.reset,
                          style: const TextStyle(
                            color: AppColors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.sortBy,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: context.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        label: l10n.sortLatest,
                        isSelected: tempSort == 'latest',
                        onTap: () => setModalState(() => tempSort = 'latest'),
                      ),
                      _buildFilterChip(
                        label: l10n.sortPopular,
                        isSelected: tempSort == 'popular',
                        onTap: () => setModalState(() => tempSort = 'popular'),
                      ),
                      _buildFilterChip(
                        label: l10n.sortOldest,
                        isSelected: tempSort == 'oldest',
                        onTap: () => setModalState(() => tempSort = 'oldest'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.timeRange,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: context.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        label: l10n.timeAll,
                        isSelected: tempTime == 'all',
                        onTap: () => setModalState(() => tempTime = 'all'),
                      ),
                      _buildFilterChip(
                        label: l10n.timeToday,
                        isSelected: tempTime == 'today',
                        onTap: () => setModalState(() => tempTime = 'today'),
                      ),
                      _buildFilterChip(
                        label: l10n.timeWeek,
                        isSelected: tempTime == 'week',
                        onTap: () => setModalState(() => tempTime = 'week'),
                      ),
                      _buildFilterChip(
                        label: l10n.timeMonth,
                        isSelected: tempTime == 'month',
                        onTap: () => setModalState(() => tempTime = 'month'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedSort = tempSort;
                          _selectedTime = tempTime;
                        });
                        Navigator.pop(ctx);
                        _performSearch();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        l10n.applyFilter,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.blue
              : (context.isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.blue
                : (context.isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : context.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          titleSpacing: 12,
          title: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: context.textPrimary,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  onSubmitted: _onSearchSubmitted,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14.5,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.searchPlaceholder,
                    hintStyle: TextStyle(
                      color: context.textPlaceholder,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: context.textMuted,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: context.textMuted,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = "";
                              });
                              _performSearch();
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
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  Icons.tune_rounded,
                  color: context.textPrimary,
                  size: 22,
                ),
                onPressed: _showFilterBottomSheet,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 8),

            _buildCategoryTabs(context),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.blue),
                    )
                  : _buildSearchResultsContent(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs(BuildContext context) {
    final l10n = context.l10n;
    final categories = [
      l10n.all,
      l10n.users,
      l10n.posts,
      l10n.groups,
    ];

    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedCategoryIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategoryIndex = index;
                });
                _performSearch();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.blue
                      : (context.isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04)),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.blue
                        : (context.isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.08)),
                  ),
                ),
                child: Center(
                  child: Text(
                    categories[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : context.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResultsContent(BuildContext context) {
    final l10n = context.l10n;

    final hasUsers = (_selectedCategoryIndex == 0 || _selectedCategoryIndex == 1) && _users.isNotEmpty;
    final hasPosts = (_selectedCategoryIndex == 0 || _selectedCategoryIndex == 2) && _posts.isNotEmpty;
    final hasGroups = (_selectedCategoryIndex == 0 || _selectedCategoryIndex == 3) && _groups.isNotEmpty;

    if (!hasUsers && !hasPosts && !hasGroups) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.noResultsFound,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.trySearchingAgain,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (hasUsers) ...[
          _buildSectionHeader(l10n.users, _users.length),
          const SizedBox(height: 8),
          ..._users.map((user) => _buildUserTile(user)),
          const SizedBox(height: 16),
        ],

        if (hasPosts) ...[
          _buildSectionHeader(l10n.posts, _posts.length),
          const SizedBox(height: 8),
          ..._posts.map((post) => _buildPostTile(post)),
          const SizedBox(height: 16),
        ],

        if (hasGroups) ...[
          _buildSectionHeader(l10n.groups, _groups.length),
          const SizedBox(height: 8),
          ..._groups.map((group) => _buildGroupTile(group)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.blue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.blue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    const Color color = AppColors.blue;
    final userId = user['id']?.toString() ?? user['userId']?.toString() ?? '';
    final bool isMe = (user['isMe'] == true) || (_currentUserId != null && _currentUserId == userId);
    final bool isFriend = user['isFriend'] == true;
    final bool hasSentRequest = user['hasSentFriendRequest'] == true;
    final bool hasReceivedRequest = user['hasReceivedFriendRequest'] == true;
    final bool isSending = user['isSending'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: () async {
          await Navigator.pushNamed(
            context,
            AppRoutes.profileAccount,
            arguments: {
              'id': userId,
              'userId': userId,
              'email': user['email'] ?? '',
              'name': user['name'] ?? '',
              'avatar': user['avatar'] ?? '',
              'bio': user['bio'] ?? '',
              'isMe': isMe,
              'isFriend': isFriend,
              'hasFriendRequest': hasReceivedRequest,
              'hasSentRequest': hasSentRequest,
              'color': color,
            },
          );
          if (mounted) {
            _performSearch();
          }
        },
        leading: AppAvatar(
          avatar: user['avatar'],
          name: user['name']?.toString(),
          color: color,
          radius: 22,
          isOnline: (!isMe && isFriend && user['showActiveStatus'] == true)
              ? (user['isOnline'] == true)
              : null,
          enableViewer: false,
        ),
        title: Text(
          user['name']?.toString() ?? '',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14.5,
            color: context.textPrimary,
          ),
        ),
        subtitle: (user['bio'] ?? '').toString().isNotEmpty
            ? Text(
                user['bio'].toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.textSubtle,
                ),
              )
            : null,
        trailing: _buildUserTrailingAction(
          user,
          userId: userId,
          isMe: isMe,
          isFriend: isFriend,
          hasSentRequest: hasSentRequest,
          hasReceivedRequest: hasReceivedRequest,
          isSending: isSending,
          color: color,
        ),
      ),
    );
  }

  Widget _buildUserTrailingAction(
    Map<String, dynamic> user, {
    required String userId,
    required bool isMe,
    required bool isFriend,
    required bool hasSentRequest,
    required bool hasReceivedRequest,
    required bool isSending,
    required Color color,
  }) {
    final l10n = context.l10n;

    if (isMe) {
      return const SizedBox.shrink();
    }

    if (isFriend) {
      final bool showActive = user['showActiveStatus'] == true;
      return ElevatedButton(
        onPressed: () {
          _navigateToChat(
            user['name']?.toString() ?? '',
            user['avatar']?.toString() ?? '',
            color,
            userId: userId,
            isFriend: isFriend,
            showActiveStatus: showActive,
            isOnline: showActive && (user['isOnline'] == true),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          l10n.messageAction,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      );
    }

    if (hasSentRequest) {
      return OutlinedButton(
        onPressed: () async {
          final success = await ContactService.cancelFriendRequest(userId);
          if (success && mounted) {
            setState(() {
              user['hasSentFriendRequest'] = false;
            });
            AppToast.info(context, l10n.friendRequestCancelled);
          }
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: context.textMuted,
          side: BorderSide(color: context.borderTheme),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          l10n.requestSent,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    }

    if (hasReceivedRequest) {
      return ElevatedButton(
        onPressed: () async {
          await Navigator.pushNamed(
            context,
            AppRoutes.profileAccount,
            arguments: {
              'id': userId,
              'userId': userId,
              'email': user['email'] ?? '',
              'name': user['name'] ?? '',
              'avatar': user['avatar'] ?? '',
              'bio': user['bio'] ?? '',
              'isFriend': false,
              'hasFriendRequest': true,
              'color': color,
            },
          );
          if (mounted) _performSearch();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          l10n.accept,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      );
    }

    return ElevatedButton(
      onPressed: isSending
          ? null
          : () async {
              setState(() {
                user['isSending'] = true;
              });
              final success = await ContactService.sendFriendRequest(userId);
              if (mounted) {
                setState(() {
                  user['isSending'] = false;
                  if (success) {
                    user['hasSentFriendRequest'] = true;
                  }
                });
                if (success) {
                  AppToast.success(
                    context,
                    l10n.sendFriendRequestSuccessTo(user['name']?.toString() ?? ''),
                  );
                } else {
                  AppToast.error(
                    context,
                    l10n.cannotSendFriendRequest,
                  );
                }
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: isSending
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              l10n.addFriend,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
    );
  }

  Widget _buildPostTile(Map<String, dynamic> post) {
    const Color color = AppColors.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                avatar: post['avatar'],
                name: post['userName']?.toString(),
                color: color,
                radius: 16,
                fontSize: 13,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post['userName']?.toString() ?? l10n.user,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      post['time']?.toString() ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textSubtle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post['content']?.toString() ?? '',
            style: TextStyle(
              fontSize: 13.5,
              color: context.textPrimary,
              height: 1.35,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.favorite_rounded, size: 14, color: AppColors.red.withValues(alpha: 0.8)),
              const SizedBox(width: 4),
              Text(
                '${post['likes'] ?? 0}',
                style: TextStyle(fontSize: 12, color: context.textMuted),
              ),
              const SizedBox(width: 16),
              Icon(Icons.chat_bubble_outline_rounded, size: 14, color: context.textMuted),
              const SizedBox(width: 4),
              Text(
                '${post['comments'] ?? 0}',
                style: TextStyle(fontSize: 12, color: context.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getGroupPrivacyColor(String? privacy) {
    if (privacy == 'public') return AppColors.blue;
    if (privacy == 'private') return Colors.orangeAccent;
    return Colors.purpleAccent;
  }

  String _getGroupPrivacyName(String? privacy) {
    if (privacy == 'public') return l10n.public;
    if (privacy == 'private') return l10n.pendingApproval;
    return l10n.groupInternalSecret;
  }

  Widget _buildGroupTile(Map<String, dynamic> group) {
    final gPrivacy = group['privacy']?.toString() ?? 'public';
    final privacyColor = _getGroupPrivacyColor(gPrivacy);
    final bool isMember = group['isMember'] == true;
    final bool hasRequested = group['hasRequested'] == true;
    final bool isJoining = group['isJoining'] == true;
    final groupId = group['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () async {
          await Navigator.pushNamed(
            context,
            AppRoutes.profileGroup,
            arguments: {
              'id': groupId,
              'groupId': groupId,
              'name': group['name'] ?? '',
              'avatar': group['avatar'] ?? '',
              'privacy': gPrivacy,
              'description': group['description'] ?? '',
              'membersCount': (group['members'] as num?)?.toInt() ?? 1,
            },
          );
          if (mounted) _performSearch();
        },
        leading: AppAvatar(
          avatar: group['avatar'],
          name: group['name']?.toString(),
          color: privacyColor,
          radius: 22,
          fontSize: 16,
          enableViewer: false,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                group['name']?.toString() ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                  color: context.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: privacyColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _getGroupPrivacyName(gPrivacy),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: privacyColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((group['description'] ?? '').toString().isNotEmpty)
                Text(
                  group['description'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.textMuted,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                '${group['members'] ?? 0} ${l10n.members}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        trailing: isMember
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: context.actionPillBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  l10n.joined,
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : gPrivacy == 'public'
                ? ElevatedButton(
                    onPressed: isJoining
                        ? null
                        : () async {
                            setState(() => group['isJoining'] = true);
                            final res = await GroupService.joinGroup(groupId);
                            if (mounted) {
                              setState(() {
                                group['isJoining'] = false;
                                if (res != null && res['success'] == true) {
                                  group['isMember'] = true;
                                  group['members'] = (group['members'] as num? ?? 0).toInt() + 1;
                                }
                              });
                              if (res != null && res['success'] == true) {
                                AppToast.success(context, '${l10n.joinedGroupSuccessPrefix} "${group['name']}"!');
                              } else {
                                AppToast.error(context, l10n.errorFromCode(res?['code'], fallbackMessage: res?['message']?.toString() ?? l10n.requestConnectionError));
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: isJoining
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            l10n.join,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5),
                          ),
                  )
                : hasRequested
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          l10n.pendingApproval,
                          style: const TextStyle(color: Colors.orangeAccent, fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: isJoining
                            ? null
                            : () async {
                                setState(() => group['isJoining'] = true);
                                final res = await GroupService.requestJoinGroup(groupId);
                                if (mounted) {
                                  setState(() {
                                    group['isJoining'] = false;
                                    if (res != null && res['success'] == true) {
                                      group['hasRequested'] = true;
                                    }
                                  });
                                  if (res != null && res['success'] == true) {
                                    AppToast.success(context, l10n.joinGroupRequestSentPending);
                                  } else {
                                    AppToast.error(context, l10n.errorFromCode(res?['code'], fallbackMessage: res?['message']?.toString() ?? l10n.requestConnectionError));
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: isJoining
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                l10n.requestJoin,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5),
                              ),
                      ),
      ),
    );
  }
}
